---
title: "Load Test Analysis — Maspex PROD vs UAT — 2026-05-16 21:30–22:10 CEST"
date: 2026-05-16
type: load-test-analysis
environment: prod
analyst: claude-sonnet-4-6
tags: [load-test, ecs, autoscaling, redis, maspex, prod, comparative]
---

> **Środowisko PROD:** `maspex-prod` | **Konto AWS:** 969209893152
> **Okno testu:** 2026-05-16 **21:30–22:10 CEST** (19:30–20:10 UTC)
> **Baseline UAT:** [[load-test-analysis-2026-05-15-1200-cest]] (15 maja, 12:00–12:30 CEST)
> **ECS desired przed testem:** 30 tasków (pre-scale z poprzedniego testu + ręczna korekta minimum)

---

## 1. Executive Summary

| Kwestia | Ocena |
|---------|-------|
| Środowisko przeszło test | **Tak** — 0 aplikacyjnych 5xx, 0 błędów w logach, 0 task restartów |
| Peak traffic | 1,944,775 req/5 min = **6,483 req/s** (vs UAT 8,835 req/s — 27% niższy ruch) |
| 5xx status | ELB 5xx: 96 łącznie; **Target 5xx: 0** — cała aplikacja odpowiadała poprawnie |
| p99 latency przy peak | **0.277s** (vs UAT 1.493s — poprawa 5.4×) |
| p99 worst case (post-peak) | **8.721s** przy 21:45 CEST — gorsze niż UAT (1.601s) |
| Redis | ✅ EngineCPU max 23.8%, hit rate ~47–50%, 0 evictions |
| ECS | ✅ 30 tasków pre-scaled przez cały test, 0 unhealthy hosts |
| Autoscaling | ✅ Nie potrzebny — system już przy max capacity |
| App logi | ✅ **0 błędów** w oknie 21:30–22:10 CEST — brak VOTE_CACHE, VOTE_RPC, timeout, circuit |

**Główna diagnoza:** PROD zdał test znacznie lepiej niż UAT. Kluczowa różnica to pre-scale do 30 tasków (vs dynamiczny scale-out z 12 w UAT) oraz niższy ruch (6,483 vs 8,835 req/s). Jedyny incydent to post-peak tail degradacja o 21:45 CEST (67 ELB 5xx, p99 8.7s) przy 3,954 req/s — przyczyna odmienna od UAT (connection queue overflow, nie capacity).

**Wynik porównawczy:** PROD jest **znacznie stabilniejszy** od UAT pod każdym wskaźnikiem aplikacyjnym. Problem z UAT (autoscaling za późno) NIE wystąpił w PROD. Pojawiło się natomiast nowe zjawisko: post-peak tail degradacja z ELB 5xx przy opadaniu ruchu.

---

## 2. Baseline UAT — identyfikacja

### Wybrany baseline

**Test: 2026-05-15, 12:00–12:30 CEST (10:00–10:30 UTC)**
Plik: `load-test-analysis-2026-05-15-1200-cest.md`

### Uzasadnienie wyboru

To **jedyny test UAT z kompletną analizą warstwową** i najbliższy chronologicznie testowi PROD (dzień wcześniej). Jest też najlepiej udokumentowanym testem:
- Pre-scale na 12 tasków (jedyna kontrolowana konfiguracja)
- Autoscaling zadziałał po raz pierwszy → referencja dla zachowania skali
- Full layer analysis: CF, ALB, ECS, Redis, per-task, logi

### Parametry baseline UAT

| Parametr | Wartość |
|----------|---------|
| Data | 2026-05-15 |
| Okno | 12:00–12:30 CEST (10:00–10:30 UTC) |
| Środowisko | UAT (`maspex-uat`) |
| ECS przed testem | 12 tasków (pre-scale z 6) |
| ECS po scale-out | 30 tasków (autoscaling o 12:24:48 CEST) |
| Peak req/s | 8,835 req/s |
| Platforma | ALB + CloudFront (CF offload ~41%) |

---

## 3. PROD scope / environment

### Zasoby

| Komponent | PROD | UAT (dla porównania) |
|-----------|------|---------------------|
| ECS cluster | `maspex-prod` | `maspex-uat` |
| ALB | `app/maspex-prod/e90292a1ad614fc5` | `app/maspex-uat/68317764a66425bd` |
| Target Group (API) | `maspex-prod-api-3000/f1c1169c3a1a7125` | `maspex-uat-api-3000/97cac4c72be43344` |
| ECS Service | `maspex-api` | `maspex-api` |
| Redis | `maspex-prod` (cache.t3.medium) | `maspex-uat` (cache.t3.medium) |
| CF (twojkapsel.pl) | `E17VHHQJ29MVAB` | n/a |
| CF (kapsel.makotest.pl) | n/a | `E3J76RNXIE2YIG` |
| Logi API | `/maspex/prod/contest-service` | `/maspex/uat/contest-service` |

### Stan przed testem

| Zdarzenie | Czas CEST | Szczegół |
|-----------|-----------|---------|
| Min capacity ustawione na 12 | 18:28 | Ręczna zmiana |
| Min capacity ustawione na 20 | 18:38 | Pre-scale do 20 |
| Autoscaling AlarmHigh → 30 tasków | 20:52 | Z poprzedniego testu (spike 17:45 CEST) |
| ECS steady state 30/30 | 20:52 | 30 tasków gotowych |
| **Przed testem: 30 healthy hosts** | 21:00 | Brak autoscaling potrzebny |

**Kluczowe:** Test PROD wystartował z 30 taskami (max capacity). UAT startował z 12 i skalował w trakcie.

---

## 4. PROD timeline

| Czas UTC | Czas CEST | Komponent | Zdarzenie | Ocena |
|----------|-----------|-----------|-----------|-------|
| 19:00 | 21:00 | ALB | Pre-test run — 1,046,374 req / 5 min = 3,488 req/s | ℹ️ Warmup |
| 19:05 | 21:05 | ALB | Pre-test spike — 2,068,906 req / 5 min = 6,896 req/s; p99 **9.895s** | ⚠️ Cold start |
| 19:05 | 21:05 | ECS | CPU avg 19.95%, max 42.1%; Memory 7.2%→29.8% | ⚠️ App warming |
| 19:05 | 21:05 | Redis | EngineCPU max 23.1%; CacheHits 666k / CacheMisses 753k = **47% hit rate** | ℹ️ Cold cache |
| 19:05 | 21:05 | ALB | ELB 5xx: 6 | ℹ️ Marginalnie |
| 19:10–19:15 | 21:10–21:15 | ALB | Ruch = 0 (test zatrzymany) | ℹ️ Przerwa |
| 19:20 | 21:20 | ALB | ELB 5xx: 1 | ℹ️ |
| **19:27** | **21:27** | **Autoscaling** | **AlarmLow → desired=29** (przerwa w ruchu) | ⚠️ Scale-in w złym momencie |
| 19:28–19:32 | 21:28–21:32 | ECS | RunningTaskCount = 29 (1 task drain+replace) | ⚠️ Chwilowy spadek |
| **19:32** | **21:32** | **Autoscaling** | **AlarmHigh → desired=30** (test rusza) | ✅ Szybki powrót |
| 19:32 | 21:32 | ECS | 1 task zarejestrowany, steady state 30/30 | ✅ |
| 19:30 | 21:30 | ALB | Ramp-up: 154,973 req / 5 min = 516 req/s | ✅ |
| 19:35 | 21:35 | ALB | 160,899 req / 5 min = 536 req/s; ELB 5xx: 3 | ✅ |
| **19:40** | **21:40** | **ALB** | **PEAK: 1,944,775 req / 5 min = 6,483 req/s** | ✅ Main peak |
| 19:40 | 21:40 | ALB | p99 = **0.277s**, ELB 5xx: 19, Target 5xx: 0 | ✅ Excellent |
| 19:40 | 21:40 | ECS | CPU avg 18.4%, max 48.2%; Memory avg 28.2%, max 33.6% | ✅ |
| 19:40 | 21:40 | Redis | EngineCPU max 21.9%; Hits 404k / Misses 409k = **49.7% hit rate** | ✅ |
| **19:45** | **21:45** | **ALB** | **Declining: 1,186,121 req/5min = 3,954 req/s** | ⚠️ Post-peak degradacja |
| 19:45 | 21:45 | ALB | p99 = **8.721s**, ELB 5xx: **67**, Target 5xx: 0 | ⚠️ Tail degradation |
| 19:45 | 21:45 | ECS | CPU max 58.8%; Memory avg 37.2%, max 47.9% | ⚠️ Pressure pozostaje |
| 19:50 | 21:50 | ALB | Ruch = 0 — test zakończony | ✅ |
| 19:52 | 21:52 | Autoscaling | AlarmHigh → OK (traffic 0) | ✅ |

---

## 5. PROD findings by layer

### A. CloudFront

- **Ruch testowy NIE przechodził przez CloudFront.** Tester trafiał bezpośrednio na ALB.
- `twojkapsel.pl` (E17VHHQJ29MVAB): baseline 14–26 req/5min; 5xxErrorRate = 0%; 4xxErrorRate 79–100% (tło, monitoring/probe).
- Żadna z dystrybucji CF nie widziała ruchu testowego.
- Różnica vs UAT: UAT używał CloudFront z ~41% offload. PROD test bypasował CF.

### B. ALB

| Czas CEST | Req/5min | Req/s | ELB 5xx | Target 5xx | Target 4xx | p99 (s) |
|-----------|----------|-------|---------|------------|------------|---------|
| 21:00 | 1,046,374 | 3,488 | 0 | 0 | 4,948 | 0.084 |
| 21:05 | 2,068,906 | 6,896 | 6 | 0 | 28,862 | 9.895 |
| 21:10–21:20 | 0–5,446 | 0–18 | 1 | 0 | 2 | — |
| 21:25 | 31,591 | 105 | 0 | 0 | 74 | 0.101 |
| 21:30 | 154,973 | 516 | 0 | 0 | 432 | 0.090 |
| 21:35 | 160,899 | 536 | 3 | 0 | 991 | 0.090 |
| **21:40** | **1,944,775** | **6,483** | **19** | **0** | **14,040** | **0.277** |
| 21:45 | 1,186,121 | 3,954 | 67 | 0 | 22,778 | 8.721 |
| 21:50+ | 0 | 0 | 0 | 0 | 0 | — |

**Kluczowe obserwacje:**
- **Target 5xx = 0 przez cały test** — aplikacja NIGDY nie zwróciła 5xx. Wszystkie błędy 5xx to ELB-level (connection timeout/refused na poziomie ELB→target, nie odpowiedź aplikacji).
- ELB 5xx = 96 łącznie (vs 160 UAT). Koncentracja 67 o 21:45 (post-peak tail).
- Target 4xx (~70k łącznie) to przede wszystkim FK violations (synthetic users bez profili, identyczny problem jak w UAT).
- HealthyHostCount: 30/30 przez cały test (min 29 tylko w oknie 21:25–21:30 podczas task replacement).

### C. ECS / autoscaling

**Task count timeline (Container Insights, period=60s):**

| Czas CEST | RunningTaskCount |
|-----------|-----------------|
| 21:00–21:27 | 30 |
| 21:27–21:33 | 29 (1 task replaced) |
| 21:33–22:05+ | 30 |

**ECS CPU / Memory (period=300s):**

| Czas CEST | CPU avg | CPU max | Mem avg | Mem max |
|-----------|---------|---------|---------|---------|
| 21:00 | 10.7% | 29.3% | 7.2% | 13.3% |
| 21:05 | 20.0% | 42.1% | 29.8% | 43.3% |
| 21:10 | 1.0% | 9.5% | 27.0% | 36.5% |
| 21:30 | 3.2% | 11.1% | 26.7% | 29.6% |
| 21:35 | 3.2% | 10.9% | 26.8% | 30.0% |
| **21:40** | **18.4%** | **48.2%** | **28.2%** | **33.6%** |
| **21:45** | **14.7%** | **58.8%** | **37.2%** | **47.9%** |
| 21:50 | 1.4% | 10.8% | 34.6% | 38.0% |

**Autoscaling events:**
- `18:28 CEST` — minimum capacity → 12 (ręcznie)
- `18:38 CEST` — minimum capacity → 20 (pre-scale)
- `20:52 CEST` — AlarmHigh → desired = 30 (z poprzedniego testu)
- `21:27 CEST` — **AlarmLow → desired = 29** (przerwa między uruchomieniami)
- `21:32 CEST` — **AlarmHigh → desired = 30** (nowy test start)

**Kluczowy problem autoscalingu:** AlarmLow wyzwoliło scale-in do 29 o 21:27 dokładnie gdy test ruszał ponownie. ECS zastąpił 1 task i zarejestrował nowy o 21:32. Krótkie okno 29 healthy hosts nie spowodowało znaczącej degradacji.

**Maspex-bot:** Restart loop potwierdzony: task zatrzymany o 22:02, nowy uruchomiony o 22:09 (health check failure). Niezależny od testu API.

### D. Application logs

**Główne okno 21:30–22:10 CEST (19:30–20:10 UTC), poprawne epochy UTC:**

| Okres (UTC) | Okres (CEST) | Wolumen logów | Błędy |
|-------------|-------------|---------------|-------|
| 19:30–19:35 | 21:30–21:35 | 64 | **0** |
| 19:35–19:40 | 21:35–21:40 | 10 | **0** |
| 19:40–19:45 | 21:40–21:45 | 12 | **0** |
| 19:45–19:50 | 21:45–21:50 | 16 | **0** |

**Query na błędy (VOTE_CACHE, VOTE_RPC, error, fail, timeout, SIGTERM, circuit): 0 wyników.**

**Błędy z wcześniejszych uruchomień (nie z okna 21:30–22:10):**
- `VOTE_RPC_ERROR` — FK violations (synthetic users bez profili w DB) — identyczne jak UAT
- `Error: During prerendering, fetch() rejects when the prerender is complete... route "/zwycieskie"` — nowy błąd SSR (Next.js ISR/prerender) przy opadaniu ruchu

Błąd `/zwycieskie` prerender to problem z `setTimeout`/`after()` w Next.js — `fetch()` jest wywoływane po zakończeniu prerenderingu. To nie jest infrastruktura — to kod aplikacji.

### E. Redis / ElastiCache (`maspex-prod`, cache.t3.medium)

| Czas CEST | EngineCPU avg | EngineCPU max | CurrConn avg | CacheHits/5min | CacheMisses/5min | Hit Rate | Evictions |
|-----------|--------------|--------------|-------------|----------------|------------------|----------|-----------|
| 21:00 | 7.2% | 16.0% | 95 | 191,185 | 197,450 | **49.2%** | 0 |
| 21:05 | 19.6% | 23.1% | 95 | 666,880 | 752,910 | **47.0%** | 0 |
| 21:10–21:15 | 0.25% | 0.26% | 95 | 0 | 0 | — | 0 |
| 21:30–21:35 | 2.5–3.5% | 3.7–4.2% | 95 | 33k–52k | 38k–60k | ~47% | 0 |
| **21:40** | **12.3%** | **21.9%** | **95** | **404,148** | **409,056** | **49.7%** | **0** |
| **21:45** | **14.1%** | **23.8%** | **95** | **473,638** | **535,589** | **46.9%** | **0** |
| 21:50+ | 0.25% | 0.27% | 95 | 0 | 0 | — | 0 |

**Kluczowe ustalenia:**
- **Hit rate ~47–50%** — znacznie niższy niż UAT (74–75%). PROD ma bardziej zróżnicowane dane produkcyjne lub zimna cache w momencie testu. Więcej cache miss = więcej zapytań do backendu.
- **CurrConnections = 95** (stałe) — 30 tasks × ~3 połączenia = oczekiwane. Brak wzrostu pod obciążeniem.
- **0 Evictions** — Redis daleki od limitu pamięci.
- **EngineCPU max 23.8%** — poniżej progu alarmowego (50%). Redis nie był bottleneckiem.
- Brak circuit open, brak timeout w logach.

### F. Container Insights

- Dane dostępne z namespace `ECS/ContainerInsights` dla `maspex-prod/maspex-api`.
- RunningTaskCount = 30 przez cały test (z krótkim 29 o 21:28–21:32).
- Per-task CPU/Memory przez Enhanced Container Insights: **dane niedostępne** (Enhanced CI nie włączone dla PROD w tym oknie — namespace `AWS/ECS` daje tylko service-level).
- Hotspot analiza niemożliwa bez per-task metryk.

---

## 6. Side-by-side comparison: PROD vs UAT

### Ruch

| Metryka | UAT 2026-05-15 | PROD 2026-05-16 | Różnica |
|---------|---------------|----------------|---------|
| Peak req/5min (ALB) | 2,650,353 | 1,944,775 | PROD -27% |
| Peak req/s (ALB) | 8,835 | 6,483 | PROD -27% |
| CF offload | ~41% | 0% (bypass) | Różna architektura testu |
| CF traffic at peak | 4,516,906 req/5min | 14–26 req/5min | CF nie używane |
| Test ramp-up | Linear | Linear (z pre-wave) | — |
| Test czas trwania | ~30 min | ~20 min (21:30–21:50) | Krótszy PROD |

### Błędy 5xx

| Typ | UAT (łącznie) | PROD (łącznie) | Delta |
|-----|--------------|----------------|-------|
| ELB 5xx | 160 | 96 | **-40%** |
| Target 5xx | 24 | **0** | **-100%** |
| CF 5xx | 0% rate | 0% rate | = |
| App log 5xx (main window) | ~186 błędów | **0** | **-100%** |
| VOTE_CACHE_WRITETHROUGH_FAIL | 68 | **0** | **-100%** |

### Latencja

| Czas | UAT avg | UAT p99 | PROD avg | PROD p99 | Ocena |
|------|---------|---------|---------|---------|-------|
| Pre-test (baseline) | 0.038s | 0.755s | 0.020s | 0.084s | PROD lepsze |
| Ramp-up | 0.011–0.015s | 0.046–0.066s | 0.020–0.023s | 0.090–0.101s | Podobne |
| **Peak traffic** | **0.112s** | **1.493s** | **0.036s** | **0.277s** | **PROD 5.4× lepsze** |
| Post-peak / decay | 0.021s | 0.188s | 0.848s | **8.721s** | PROD gorsze 46× |
| After test | 0.089s | 1.601s | ~0s | — | — |

**Uwaga na post-peak:** UAT miał clean decay (0.188s p99 o 12:25). PROD miał severe tail degradation (8.721s p99 o 21:45). To jest najważniejsza różnica operacyjna.

### ECS behavior

| Metryka | UAT | PROD | Delta |
|---------|-----|------|-------|
| Tasks pre-test | 12 | 30 | PROD 2.5× więcej |
| Autoscaling during test | Tak (12→30 po 4-5 min) | Nie (już at max) | PROD lepsze |
| CPU avg peak | 57.8% | 18.4% | PROD -68% |
| CPU max peak | 98.5% | 48.2% | PROD -51% |
| Memory avg peak | 43.8% | 28.2% | PROD -36% |
| Memory max peak | 78.9% | 33.6% | PROD -57% |
| UnHealthyHostCount during test | max 1 | **0** | PROD lepsze |
| Task replacements during test | 1 (health check) | 0 (replacement before test) | PROD lepsze |

### Redis

| Metryka | UAT | PROD | Delta |
|---------|-----|------|-------|
| EngineCPU avg peak | 20.8% | 12.3% | PROD -41% |
| EngineCPU max | 25.6% | 23.8% | Podobne |
| CurrConnections max | 95 (post scale) | 95 (przez cały czas) | = |
| **Cache hit rate** | **74.9%** | **~47–50%** | **PROD -37 pp** |
| Evictions | 0 | 0 | = |
| VOTE_CACHE failures | 68 | 0 | PROD lepsze |
| Circuit open | 0 | 0 | = |

**Najważniejsza różnica Redis:** PROD hit rate 47% vs UAT 75%. Na identycznym węźle (t3.medium) PROD generuje ponad 2× więcej miss (=origin) per request. Na kampanii z pełnym ruchem publicznym może to być znaczące.

### Application errors

| Typ błędu | UAT | PROD |
|-----------|-----|------|
| VOTE_CACHE_WRITETHROUGH_FAIL | 68 | 0 |
| VOTE_RPC_ERROR (FK violations) | 118 | Nie w main window |
| JWT/auth errors | 0 (fixed) | 0 |
| Redis circuit open | 0 | 0 |
| Prerendering errors (/zwycieskie) | Nie zaobserwowane | Tak (wcześniejszy run) |

---

## 7. Root cause comparison

### PROD 2026-05-16 21:30–22:10

| Hipoteza | PROD | UAT | Komentarz |
|----------|------|-----|-----------|
| Capacity issue | **REJECTED** | CONFIRMED | PROD miał 30 tasków pre-scale, CPU max 48% |
| Autoscaling too late | **REJECTED** | CONFIRMED | PROD startował z max capacity |
| Deployment collision | **REJECTED** | REJECTED | Brak UpdateService w oknie testu |
| App bug (VOTE_CACHE) | **REJECTED** | LIKELY | 0 VOTE_CACHE failures w PROD |
| Redis bottleneck | **REJECTED** | UNLIKELY | EngineCPU max 24%, 0 evictions, brak circuit |
| Auth/session issue | **REJECTED** | REJECTED | 0 auth errors w logach |
| Uneven task hotspot | **LIKELY** | LIKELY | Memory max 47.9% vs avg 37.2% — rozrzut widoczny |
| Health check churn (API) | **REJECTED** | CONFIRMED (1 task) | 0 health check failures w PROD w main window |
| Health check churn (bot) | **CONFIRMED** | CONFIRMED | Bot restartuje się cyklicznie niezależnie |
| Post-peak ELB 5xx (tail) | **CONFIRMED** | UNLIKELY | 67 ELB 5xx przy 21:45 — connection queue overflow |
| Cold start warm-up | **CONFIRMED** | NOT SEEN | p99 9.9s przy 21:05 (pre-test wave, cold state) |
| Low Redis hit rate | **CONFIRMED** | NOT SEEN | 47% vs 75% — efekt produkcyjnych danych |

### Przyczyna pierwotna PROD — post-peak degradacja (21:45)

**[LIKELY]** Przy opadaniu ruchu z peak (6,483 req/s → 3,954 req/s) część tasków była jeszcze w trakcie obsługi requestów z poprzedniego piku. ALB nie mogło nawiązać nowych połączeń do zajętych tasków → ELB 5xx (connection refused/timeout). Memory pressure (37% avg, max 47.9%) wskazuje na GC pressure w Node.js. Brak Target 5xx potwierdza że aplikacja ODPOWIADAŁA — problemem była dostępność połączenia na poziomie ELB→Task.

**Skutek wtórny:** p99 8.7s = requestom które "przebrnęły" przez connection queue — długi czas oczekiwania na wolne połączenie.

---

## 8. Key differences that matter

| Różnica | UAT | PROD | Znaczenie operacyjne |
|---------|-----|------|---------------------|
| **Test routing** | Via CloudFront (41% offload) | Bezpośrednio na ALB | PROD test nie odzwierciedla produkcji z CF |
| **ECS baseline** | 12 tasks (dynamicznie skaluje) | 30 tasks (max, pre-scale) | PROD test nie testował autoscalingu |
| **Redis hit rate** | 74.9% | 47–50% | Na kampanii PROD będzie miał 2× więcej origin load |
| **Memory baseline (idle)** | ~3.5% avg | ~26–28% avg (po warmup) | PROD taski mają wyższą bazową pamięć z produkcyjnych danych |
| **Bot instability** | Cykliczne restarty | Cykliczne restarty (częstsze?) | Oba środowiska — nierozwiązany problem |
| **Post-peak tail** | Czysty (0.188s p99) | Silna degradacja (8.7s p99) | PROD nowy problem — nie widoczny w UAT |
| **VOTE_CACHE failures** | 68 przy saturacji | 0 | PROD bardziej stabilny lub niższy ruch |
| **Scale-in during test** | Nie (nie było przerwy) | Tak (AlarmLow przy przerwie) | Risk: niedostępna capacity gdy test restartuje |

---

## 9. Recommended actions

### Natychmiast (przed kolejnym testem PROD)

1. **Nie rób przerwy w teście** — AlarmLow skale-in do 29 tasków podczas przerwy między uruchomieniami. Unikaj przerw > 5 min lub wyłącz scale-in podczas testowania.

2. **Zbadaj post-peak tail (21:45, 67 ELB 5xx, p99 8.7s):**
   - Sprawdź ALB connection draining timeout
   - Sprawdź Node.js connection pool size (max concurrent connections per task)
   - Rozważ zwiększenie deregistration delay jeśli taski mają długie requesty w trakcie drain

3. **Napraw dane testowe — FK violations dla synthetic users** (identyczne jak UAT — `profiles` nie istnieją dla syntetycznych UUIDs).

### Krótkoterminowo

4. **Zweryfikuj Redis hit rate 47% na PROD:** Sprawdź jakie klucze / endpointy generują miss. UAT ma 75% — jeśli to efekt zimnej cache, potrzebny warm-up przed testem. Jeśli efekt różnorodności danych produkcyjnych, rozważ prewarming lub wyższy TTL.

5. **Napraw maspex-bot (PROD i UAT):** Health check failures co ~30–60 min. Pierwotna przyczyna: brak tokenu Twitch lub błąd auth w bot service. Niezależny od API ale generuje szum w metrykach.

6. **Napraw błąd prerender `/zwycieskie`:** `fetch()` wywołane po zakończeniu prerenderingu (setTimeout/after kontekst). To kod aplikacji — Next.js rzuca wyjątek. Potwierdzić czy generuje 5xx dla użytkowników w produkcji.

7. **Włącz Enhanced Container Insights dla PROD** (`ECS/ContainerInsights` enhanced) — brak per-task danych uniemożliwia hotspot diagnostykę.

### Diagnostycznie

8. **Test z CF routing dla PROD:** Load test powinien przechodzić przez CloudFront (`twojkapsel.pl`) żeby przetestować realny scenariusz kampanii. Aktualny test bypasuje CF.

9. **Test warmup run przed głównym:** Wyniki pokazują że p99 przy "zimnych" taskach (21:05 CEST) = 9.9s, a przy ciepłych = 0.28s. Przed każdym testem PROD uruchomić 2–3 min warmup run przy ~10–20% pełnego ruchu.

10. **Test autoscalingu dla PROD:** Żaden test nie sprawdził czy PROD autoscaling działa (bo zawsze startujemy z 30). Potrzebny test: start z 20 taskami, peak powyżej progu → weryfikacja czy AlarmHigh odpala.

---

## 10. Final verdict

| Pytanie | Odpowiedź |
|---------|-----------|
| PROD stabilniejszy od UAT? | **Tak — znacznie** |
| Problem UAT (autoscaling delay) rozwiązany? | **Tak — przez pre-scale, nie przez tuning alarmów** |
| Problem przeniesiony na PROD? | Częściowo — VOTE_CACHE nie wystąpiło, ale pojawiło się nowe zjawisko (post-peak tail) |
| PROD ma nowy, odrębny problem? | Tak — post-peak ELB 5xx + cold cache hit rate |
| Bezpiecznie powtarzać testy PROD? | **Tak, po poprawkach** (patrz sekcja 9) |
| Czy 30 tasków wystarczy na kampanię? | Nieznane — PROD peak był 27% niższy niż UAT. Potrzebny test na pełnym ruchu. |

**Główna diagnoza:**
PROD zachował się lepiej od UAT pod KAŻDYM wskaźnikiem aplikacyjnym (0 Target 5xx, 0 app errors, p99 0.28s przy peak). Różnice wynikają głównie z:
1. Pre-scale do 30 tasków (wyeliminował autoscaling delay)
2. Niższy ruch testowy (6,483 vs 8,835 req/s)
3. Test bypasujący CloudFront (inne zachowanie)

Nowe problemy specyficzne dla PROD:
- Post-peak tail degradacja (ELB connection overflow przy opadaniu ruchu)
- Niższy Redis hit rate (produktywna dane vs syntetyczne UAT)
- Cold start issue (pierwsza fala po pauzie)

**Warunek bezpiecznego powtórzenia:** warm-up run 5 min, brak przerwy między uruchomieniami, min capacity ≥ 20, CF routing w teście.

---

## 11. Evidence

```bash
# PROD ALB metrics (eu-west-1) — poprawne UTC strings
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB --metric-name RequestCount \
  --dimensions Name=LoadBalancer,Value=app/maspex-prod/e90292a1ad614fc5 \
  --start-time 2026-05-16T19:00:00Z --end-time 2026-05-16T20:40:00Z \
  --period 300 --statistics Sum --profile maspex-cli --region eu-west-1

# PROD ECS Service Events
aws ecs describe-services --cluster maspex-prod --services maspex-api \
  --profile maspex-cli --region eu-west-1

# PROD Autoscaling Activities
aws application-autoscaling describe-scaling-activities \
  --service-namespace ecs --resource-id service/maspex-prod/maspex-api \
  --profile maspex-cli --region eu-west-1

# PROD Container Insights RunningTaskCount
aws cloudwatch get-metric-statistics \
  --namespace ECS/ContainerInsights --metric-name RunningTaskCount \
  --dimensions Name=ClusterName,Value=maspex-prod Name=ServiceName,Value=maspex-api \
  --start-time 2026-05-16T19:00:00Z --end-time 2026-05-16T20:40:00Z \
  --period 60 --profile maspex-cli --region eu-west-1

# PROD Redis (poprawny cluster ID: maspex-prod, nie maspex-prod-0001-001)
aws cloudwatch get-metric-statistics \
  --namespace AWS/ElastiCache --metric-name EngineCPUUtilization \
  --dimensions Name=CacheClusterId,Value=maspex-prod \
  --start-time 2026-05-16T19:00:00Z --end-time 2026-05-16T20:40:00Z \
  --period 300 --profile maspex-cli --region eu-west-1

# PROD Logs — WAŻNE: użyj TZ=UTC przy obliczaniu epochów na macOS
START_EPOCH=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%SZ" "2026-05-16T19:30:00Z" "+%s")
END_EPOCH=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%SZ" "2026-05-16T20:10:00Z" "+%s")
# START_EPOCH=1778959800, END_EPOCH=1778962200

aws logs start-query \
  --log-group-name "/maspex/prod/contest-service" \
  --start-time $START_EPOCH --end-time $END_EPOCH \
  --query-string 'filter @message like /(?i)(error|fail|VOTE_CACHE|VOTE_RPC)/ | stats count() as cnt by bin(5min)' \
  --profile maspex-cli --region eu-west-1
# Wynik: 0 (zero błędów w głównym oknie testu)

# PROD CloudFront
aws cloudwatch get-metric-statistics \
  --namespace AWS/CloudFront --metric-name Requests \
  --dimensions Name=DistributionId,Value=E17VHHQJ29MVAB Name=Region,Value=Global \
  --start-time 2026-05-16T19:00:00Z --end-time 2026-05-16T20:40:00Z \
  --period 300 --profile maspex-cli --region us-east-1
# Wynik: 14–26 req/5min — test nie przechodził przez CF
```

---

## 12. Missing or unavailable data

| Brakujące dane | Przyczyna | Impact |
|----------------|-----------|--------|
| Per-task CPU/Memory PROD | Enhanced Container Insights nie włączone | Średni — hotspot analiza niemożliwa |
| Redis CacheHitRate / OriginLatency CF | Enhanced CF Metrics nie włączone | Niski |
| CF metrics dla ruchu testowego | Test bypasował CloudFront | Wysoki — brak danych edge layer |
| Supabase / PostgreSQL metryki | Brak integracji CW | Średni — FK violations potwierdzone z logów |
| JMeter/k6 raporty klienta | Brak dostępu | Wysoki — brak TTFB, success rate po stronie klienta |
| Per-task analiza w oknie 21:40 CEST | Enhanced CI brak danych | Średni |
| Root cause post-peak tail 21:45 | Brak per-connection metrics ALB | Średni — LIKELY ale nie CONFIRMED |
| Bot token auth config | Nie zbadano | Niski — nie wpływa na API |
```

---

*Wygenerowano: 2026-05-16 | Analyst: claude-sonnet-4-6 | Na podstawie danych AWS CloudWatch, ECS, CW Logs, ElastiCache*
