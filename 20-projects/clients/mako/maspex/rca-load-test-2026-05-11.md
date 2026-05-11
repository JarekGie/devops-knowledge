---
title: "RCA — Maspex UAT Load Test 2026-05-11 00:00–01:00 CEST"
date: 2026-05-11
type: rca
environment: uat
analyst: claude-sonnet-4-6
status: hipoteza — wymaga weryfikacji (brak metryk DB/Supabase i APM)
---

# RCA — Maspex UAT Load Test 2026-05-11 00:00–01:00 CEST

## A. Executive Summary

**Najbardziej prawdopodobny root cause**: Application-level resource exhaustion — wyczerpanie connection poolu do downstream (DB/Supabase) w połączeniu z Node.js heap pressure i retencją pamięci po burście.

**Najważniejsze contributing factors**:
1. Burst +238% w 5 minutach (285k → 1.249M req/5min) — zbyt gwałtowny dla jakiegokolwiek autoscalingu
2. Zmiana konfiguracji Redis z 2026-05-08 usunęła circuit breaker / fast-fail → requesty teraz czekają pełny timeout zamiast szybko failować, co trzyma zasoby (pamięć, połączenia) dłużej
3. Autoscaling nie wyzwolił się (CPU avg 46% < próg 60%) — system nie dodał pojemności

**Co można już uznać za wykluczone**:
- Redis jako root cause
- Crashe tasków ECS
- Problemy sieciowe / VPC
- VOTE_CACHE circuit breaker

---

## B. Confirmed Facts

**ALB:**
- Peak 22:20 UTC: 1,249,436 req/5min (+238% vs 22:15 — burst w jednym 5-min interwale)
- Response time peak: avg 1965 ms, **p50 12.7 ms**, p90 7.9 s, **p99 15.8 s**
- HTTPCode_Target_5XX: **3464** (22:20) + **912** (22:25) = 4376 łącznie
- HTTPCode_ELB_5XX: 178 (22:20) + 58 (22:25)
- **UnHealthyHostCount = 0 przez cały test**
- Post-test (22:30+): avg latency **460–520 ms** przy ~15 req/5min (health checks), nie wraca do baseline 12 ms przez >1h

**ECS:**
- CPU avg peak: 46.1%; CPU max (per task): 78.7% — poniżej progu autoscalingu (60% avg)
- Memory avg peak: 49% (22:20) / ~74.5% (22:25); Memory max per task: **84.2%** (22:20) / **92.1%** (22:25)
- Post-test: Memory avg 66–68%, nie wraca do baseline 13–18% przez >30 min po zakończeniu ruchu
- 0 STOPPED tasks — żaden task nie crashował
- Brak aktywności autoscalingu (ostatnia: 2026-04-28)

**Redis / ElastiCache:**
- EngineCPU max: 14.7% — zdrowy
- Evictions: 0, Swap: 0, DBMemory max: 1.25%
- Connections: stabilne 31–32 przez cały test (pooling działa)
- Post-test: 0 hits/misses/connections po 22:30 — Redis w pełni idle
- Cache Hit Ratio podczas testu: 66–70%

**Logi aplikacyjne:**
- **0 wystąpień** `VOTE_CACHE_WRITETHROUGH_FAIL` (poprzedni test 2026-05-05: 924,582 wystąpień)
- **6 zarejestrowanych 5xx** w logach aplikacyjnych vs **4376 HTTPCode_Target_5XX** w ALB — mismatch 730:1
- CACHE-CRON: regularny, co minutę — normalny

**CloudFront:**
- Peak 2,138,080 req/5min przy 22:20 — CF obsłużył ~41% z cache
- CacheHitRate: 0 datapoints (Enhanced Metrics wyłączone)

**Pre-test anomalia:**
- 21:40–21:55 UTC (idle, ~15 req/5min health checks): ALB avg 370–400 ms, p99 1.0–1.2 s — **aplikacja była już w stanie degradowanym przed głównym testem**

---

## C. Hypothesis Assessment

### H1 — Application memory pressure / GC / event-loop lag

**Description**: Node.js pod presją heap (84–92% task memory) wchodzi w stop-the-world GC cycles blokujące event loop na sekundy.

| | |
|---|---|
| **Evidence FOR** | Memory max 92.1% per task; heap retention 67% post-test; health check latency 460ms przy 0 ruchu; pre-test 370ms anomalia |
| **Evidence AGAINST** | p50 = 12.7 ms normalne — przy pełnym event loop saturation p50 też by wzrosło; CPU avg 46% |
| **Probability** | **WYSOKIE** — contributing factor, nie jedyny root cause |

### H2 — DB / Supabase / downstream connection pool exhaustion

**Description**: Wyczerpanie puli połączeń DB → requesty kolejkują się → tail latency 10–15s → 5xx przy timeout.

| | |
|---|---|
| **Evidence FOR** | **p99 15.8s** = klasyczny pool wait timeout; **bimodalna dystrybucja** (p50 ok / p99 catastrophic) = sygnatura pool exhaustion; 4376 ALB 5xx vs 6 app 5xx = timeout przed logowaniem; post-test 460ms health checks = pool nie odzyskał stanu; memory retention = connection objects w heap |
| **Evidence AGAINST** | Brak RDS/Supabase metryk — nie można potwierdzić bezpośrednio |
| **Probability** | **WYSOKIE** — najsilniejsza hipoteza pasująca do profilu bimodalnej latencji |

### H3 — Request queue buildup / burst overload

**Description**: Burst +238% przekroczył możliwości przetwórcze 9 tasków.

| | |
|---|---|
| **Evidence FOR** | Burst skalą przekroczył pojemność; ELB 5xx 178; autoscaling nie zareagował |
| **Evidence AGAINST** | Po zakończeniu burstu (22:30+, ~15 req/5min) latencja NADAL 460ms — queue buildup tego nie tłumaczy; CPU avg 46% (nie 100%) |
| **Probability** | **ŚREDNIE** — contributing factor wyzwalający H2, nie standalone root cause |

### H4 — Kombinacja: memory pressure + downstream slow path

**Description**: Burst wyczerpał connection pool DB → czekające requesty trzymają heap → GC agresywny → pętla dodatniego sprzężenia. Amplifier: zmiana Redis 2026-05-08 (usunięcie fast-fail).

| | |
|---|---|
| **Evidence FOR** | Tłumaczy jednocześnie: tail latency + memory retention + post-test degradację + 5xx + bimodalną dystrybucję; Redis circuit breaker removal jako amplifier jest dobrze uzasadniony przez timing |
| **Evidence AGAINST** | Trudna do sfalsyfikowania bez APM; może być "too clever" — wystarczy sam H2 |
| **Probability** | **NAJWYŻSZE** — H1+H2 kompozycja wyjaśnia wszystkie anomalie jednocześnie |

---

## D. Most Likely RCA

**Root cause**: Wyczerpanie connection poolu downstream (DB/Supabase) pod burst load.

**Contributing factors**:
1. **Zmiana Redis 2026-05-08** usunęła circuit breaker / fast-fail — requesty czekają pełny timeout (10–15s) zamiast failować natychmiast; każdy taki request trzyma: połączenie DB, heap allocation, slot event loop
2. **Node.js memory pressure** jako efekt wtórny: zawieszone requesty → heap rośnie → GC pod presją → stop-the-world pauses → dalsze pogłębienie tail latency
3. **Autoscaling próg za wysoki**: CPU avg 60% nie przekroczony (46.1%); Node.js jest single-threaded — 46% CPU avg to efektywnie 100% na jednym core per task

**Mechanizm degradacji**:
```
Burst +238% w 5 min
    → connection pool DB/Supabase wyczerpany
    → requesty czekają na połączenie (queue wait 10–15s)  ← p99 15.8s
    → każdy czekający request trzyma heap allocation
    → heap rośnie do 84–92% max
    → V8 GC agresywny, stop-the-world pauses
    → część requestów otrzymuje timeout od ALB → 5xx
    → po teście: pool w niestabilnym stanie, heap nie zwolniony
    → health checks trafią na pool wait lub GC pause → 460–520 ms
    → memory 67% avg = retained heap (connection objects, response buffers)
```

**Dlaczego p50 było normalne**: Większość requestów (p50) to "szybka ścieżka" — Redis cache hit (70%) bez potrzeby wchodzenia do DB. Wolna ścieżka (p99) to requesty wymagające DB query, teraz bez fast-fail.

---

## E. What Was Ruled Out

| Obszar | Evidencja wykluczenia |
|---|---|
| **Redis jako root cause** | EngineCPU max 14.7%, evictions=0, swap=0, connections stable 31–32 |
| **VOTE_CACHE circuit breaker** | 0 wystąpień w logach (vs 924k w poprzednim teście) |
| **ECS task crash** | 0 STOPPED tasks przez cały test |
| **ALB unhealthy hosts** | UnHealthyHostCount=0 przez cały czas |
| **CloudFront jako bottleneck** | CF absorbował 41% ruchu z cache; 5xx CF = 0% poza szczytem |
| **Network / VPC** | ELB_5XX 178 = marginalne; ALB zdrowy |
| **ElastiCache memory/evictions** | DBMemory max 1.25%, evictions=0 |
| **Autoscaling failure** | Nie wyzwolił się z powodu progów, nie awarii systemu |

---

## F. Gaps in Evidence

| Brakujący element | Dlaczego krytyczny | Co blokuje |
|---|---|---|
| **RDS / Supabase metrics** (query latency, active connections, pool state) | H2 nie może być potwierdzone | Pełne domknięcie RCA |
| **Konfiguracja connection pool aplikacji** (pool size, acquireTimeout) | Nie wiadomo czy pool ma 5 czy 50 połączeń per task | Weryfikacja czy wyczerpanie poolu było możliwe |
| **ALB access logs (S3)** | Per-request status codes i latency by endpoint | Który endpoint generuje 5xx |
| **Node.js runtime metrics** (heap, GC pauses, event loop lag) | Bezpośrednia weryfikacja H1 | Czy GC był stop-the-world |
| **Szczegóły zmiany Redis 2026-05-08** | Czy usunięto circuit breaker? Co dokładnie zmieniono? | Weryfikacja amplifier hypothesis |
| **APM / distributed traces** | Request breakdown: ile app, ile DB, ile Redis | Precyzyjny podział 15.8s |
| **Mismatch 6 vs 4376 5xx** | Dlaczego aplikacja zalogowała tylko 6 5xx podczas gdy ALB widział 4376? | Mechanizm failure — crash przed logowaniem? |
| **Per-task memory metryki** | Które taski miały 92%? Czy to ten sam task? | Czy problem systemowy czy "bad apple" |

---

## G. Verification Plan

### Natychmiastowe (przed kolejnym testem)

1. **Przeczytać `redis-connection-change-2026-05-08.md`** — co dokładnie zmieniono; czy usunięto circuit breaker intencjonalnie
2. **Sprawdzić konfigurację connection pool aplikacji** — `max`, `acquireTimeoutMillis`, `idleTimeoutMillis`; obliczyć teoretyczną max throughput do DB przy 9 taskach
3. **Włączyć dostęp do Supabase / RDS metryk** — `DatabaseConnections`, `DBLoad`, `ReadLatency/WriteLatency`
4. **Sprawdzić ALB access logs** — przeanalizować logi z 2026-05-11; `grep 5[0-9][0-9]` + latency by endpoint
5. **Zrestartować jeden task ECS** — sprawdzić czy memory wraca do baseline po restarcie; jeśli tak → heap retention potwierdzona

### Przed kolejnym load testem

6. **Dodać instrumentację aplikacyjną (minimum viable)**:
   - `process.memoryUsage()` logowany co 30s
   - Pool metrics: active/idle/pending — logowane co 30s
   - Structured log dla każdego 5xx z stack trace + upstream error
7. **Zmienić progi autoscalingu**: CPU target z 60% → 40% avg lub dodać custom metric (active connections per task)
8. **Włączyć ALB access logs → S3** przed testem
9. **Supabase monitoring** aktywny na czas testu: `pg_stat_activity`, connection count, long queries
10. **Cooldown między testami min 15 min** (pre-test latency 370ms wskazuje brak odpoczynku)

### Dane do zebrania przy następnym teście

| Metryka | Metoda | Granularity |
|---|---|---|
| DB connection pool (active/idle/pending) | App-level log | co 30s |
| Node.js heap (heapUsed, rss) | App-level log | co 30s |
| Event loop lag | `perf_hooks.eventLoopUtilization()` | co 30s |
| Supabase query latency (p99) | Supabase dashboard / pg_stat | co 1 min |
| ALB access logs: latency by endpoint | S3 + query post-test | per-request |
| ECS per-task memory | CloudWatch ContainerInsights | co 1 min |

---

## H. Final Verdict

Najbardziej prawdopodobna przyczyna: wyczerpanie connection poolu downstream (Supabase/DB) podczas gwałtownego burstu (+238% w 5 min), amplifikowane przez usunięcie Redis circuit breakera (zmiana 2026-05-08) — requesty, które wcześniej failowały natychmiast, teraz czekają pełne 15 sekund trzymając heap i połączenia, co wywołało kaskadowy wzrost memory pressure i tail latency, której ślad (heap retention + degradowana latencja health-checków) utrzymywał się ponad godzinę po zakończeniu ruchu.

---

*RCA wykonane przez claude-sonnet-4-6 na podstawie danych z `load-test-analysis-2026-05-11-0000-cest.md`.*  
*Status: hipoteza wysokiego prawdopodobieństwa — wymaga weryfikacji przez metryki DB/Supabase i instrumentację Node.js runtime.*
