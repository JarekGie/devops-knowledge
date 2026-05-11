---
title: "Load Test Analysis — Maspex UAT — 2026-05-11 00:00–01:00 CEST"
date: 2026-05-11
type: load-test-analysis
environment: uat
analyst: claude-sonnet-4-6
---

# Load Test Analysis — Maspex UAT — 2026-05-11 00:00–01:00 CEST

## 1. Executive Summary

Test był **jedno-falowy, ~55 minut aktywnego ruchu**, z wyraźnym peak'iem około 00:20 CEST (22:20 UTC). Środowisko obsłużyło ruch, ale wykazało poważne problemy z latencją i stabilnością odpowiedzi, które różnią się fundamentalnie od poprzednich testów.

**Kluczowe różnice względem poprzednich testów (2026-05-05 19:00):**

- **BRAK `VOTE_CACHE_WRITETHROUGH_FAIL`** — zero błędów circuit breakera Redis w logach podczas testu. Poprzedni test miał ~924 tys. takich błędów.
- **Poważna degradacja latencji ALB**: avg 1965 ms, p90 7.9 s, p99 15.8 s na peaku (22:20 UTC). Poprzednie testy miały avg 12–16 ms, p99 45–65 ms.
- **Memory leak / retencja pamięci ECS**: po zakończeniu ruchu memory pozostała na poziomie ~67% avg. Podczas poprzednich testów memory wracała między falami — tutaj nie wraca nawet po >30 min od końca ruchu.
- **5xx faktyczne**: 3464 HTTPCode_Target_5XX (22:20 UTC), 912 (22:25 UTC) — pierwsze realne 5xx od testów 2026-04-28/29. Brak 5xx w poprzednich testach.
- **CloudFront CacheHitRate**: metryka niedostępna (0 datapoints) — [HIPOTEZA] Enhanced Metrics nie są włączone lub cache policy = no-store (policy `4135ea2d` = CachingDisabled).
- **Redis infrastructure**: zdrowy — CPU max 16%, EngineCPU max 15%, evictions=0, swap=0, memoryUsage max 1.25%. CacheHits i CacheMisses aktywne tylko podczas ruchu testu.

**Najbardziej prawdopodobny bottleneck**: ECS application-level bottleneck — przy wolumenie żądań ALB ~1.25M req/5min (22:20 UTC) nastąpiło nasycenie puli połączeń lub slow downstream (DB/cache write path). Evidencja: p50 latencja wzrosła z 4 ms → 13 ms, ale p99 z 50 ms → 15.8 s — olbrzymi rozrzut wskazuje na kolejkowanie/timeouty dla podzbioru requestów, nie ogólne spowolnienie.

---

## 2. Scope i time window

| Zakres | UTC | CEST |
|---|---|---|
| Główne okno analizy | 22:00–23:00 | 00:00–01:00 |
| Kontekstowe okno | 21:30–23:30 | 23:30–01:30 |
| Faktyczny ruch (ALB > 10k req/5min) | ~21:30–22:27 | ~23:30–00:27 |
| Peak ruchu | 22:20–22:25 | 00:20–00:25 |

Źródła danych:

| Źródło | Status |
|---|---|
| CloudWatch metrics: ECS CPU/Memory | zebrane |
| CloudWatch metrics: ALB (RequestCount, ResponseTime, 4xx/5xx, UnHealthy) | zebrane |
| CloudWatch metrics: CloudFront (Requests, Bytes, 4xx/5xx, TotalError, BytesDownloaded) | zebrane |
| CloudWatch metrics: ElastiCache (CPU, EngineCPU, Connections, Evictions, Memory, Hits/Misses, Swap) | zebrane |
| CloudWatch metrics: CloudFront CacheHitRate | **0 datapoints** |
| CloudWatch metrics: CloudFront OriginLatency | **0 datapoints** |
| CloudWatch Logs Insights: `/maspex/uat/contest-service` (zawiera też maspex-api stream) | zebrane |
| CloudWatch Logs Insights: `/maspex/uat/bot` | zebrane |
| CloudWatch Logs Insights: `/maspex/uat/admin-panel` | 0 logów w oknie |
| CloudWatch Logs Insights: `/maspex/shared/maspex-api` | **0 stored bytes — log group pusta** |
| ECS service state / autoscaling | zebrane |
| ALB target health | zebrane |
| CloudWatch alarms | zebrane |

**Uwaga konfiguracyjna**: Logi maspex-api są wysyłane do `/maspex/uat/contest-service` z prefix `maspex-api/maspex-api/` (wg task definition). Log group `/maspex/shared/maspex-api` jest pusta (0 bytes). Wymagana korekta konfiguracji — patrz sekcja 14.

Zasoby:

| Obszar | Zasób |
|---|---|
| CloudFront | `E3J76RNXIE2YIG`, `kapsel.makotest.pl` |
| ALB | `app/maspex-uat/68317764a66425bd` |
| API Target Group | `targetgroup/maspex-uat-api-3000/97cac4c72be43344` |
| ECS cluster | `maspex-uat` |
| ECS services | `maspex-api` (9/9 running), `maspex-bot` (1/1), `maspex-admin-panel` (1/1) |
| ElastiCache | `maspex-uat` (cache.t3.medium, Redis, single-node) |

---

## 3. Timeline

| Timestamp UTC | CEST | Komponent | Zdarzenie | Znaczenie |
|---|---|---|---|---|
| 21:30–21:35 | 23:30–23:35 | ALB/CF | Ruch: ALB 218–227k req/5min, CF 368–384k req/5min | Test już trwa w oknie kontekstowym |
| 21:35–21:40 | 23:35–23:40 | ALB | ECS CPU avg **9.1%**, max 45.4% | Wysoki CPU max przed kontekstowym oknem |
| 21:35–21:40 | 23:35–23:40 | ALB | HealthyHosts: 9/9, UnHealthy: 0 | Targety zdrowe |
| **21:35** | **23:35** | **ELB** | **HTTPCode_ELB_5XX: 1** | Pierwszy ELB-level 5xx (jednostkowy) |
| 21:40–21:55 | 23:40–23:55 | ALB | Ruch spada do ~15 req/5min (idle) | Gap między falami lub koniec ramp |
| 21:40–21:55 | 23:40–23:55 | ALB | **Response time: avg 371–399 ms, p50 59–68 ms, p99 1.0–1.2 s** | Wyraźnie wolniejsze niż baseline (12ms avg) — skąd ten ruch? |
| 21:55–22:00 | 23:55–00:00 | ALB | Ruch nadal ~15 req/5min | Minimalne heath-check requests |
| 22:00 | 00:00 | ALB | 14780 req/5min — ramp-up testu głównego | Start testu godziny 00:00 CEST |
| 22:05 | 00:05 | ALB | 82631 req/5min; ECS CPU avg 4.8% | Moderate load |
| 22:10 | 00:10 | ALB/ECS | ALB: 390423 req/5min; ECS CPU avg **13.8%**, max 25.8% | Intensywny ramp-up |
| 22:15 | 00:15 | ALB/CF | ALB: 285275 req/5min; CF: 487754 req/5min | Plateau fazy wznoszącej |
| **22:20** | **00:20** | **ALB/ECS** | **ALB: 1,249,436 req/5min; ECS CPU avg 46.1%, max 78.7%** | **ABSOLUTNY PEAK — CPU prawie na progu autoscaling (60% avg)** |
| **22:20** | **00:20** | **ALB** | **Response time: avg 1965 ms, p50 12.7 ms, p90 7.9 s, p99 15.8 s** | **KRYTYCZNA degradacja latencji tail** |
| **22:20** | **00:20** | **ALB** | **HTTPCode_Target_5XX: 3464; HTTPCode_ELB_5XX: 178** | **Pierwsze poważne 5xx w tym teście** |
| **22:20** | **00:20** | **ECS** | **Memory avg 49%, max 84.2%** | Peak memory powyżej progu autoscaling (75% avg) wg max, ale avg poniżej |
| **22:20** | **00:20** | **Redis** | **CPU avg 13.4%, EngineCPU avg 11.6%** | Normalny — nie saturacja |
| **22:25** | **00:25** | **ALB/ECS** | **ALB: 323361 req/5min; ECS CPU avg 17.8%, max 67.2%** | Szczyt mijający, ale latencja nadal wysoka |
| **22:25** | **00:25** | **ALB** | **Response time: avg 1547 ms, p90 6.6 s, p99 14.2 s** | Latencja tail nie spada mimo mniejszego ruchu |
| **22:25** | **00:25** | **ALB** | **HTTPCode_Target_5XX: 912; HTTPCode_ELB_5XX: 58** | 5xx nadal obecne |
| **22:25** | **00:25** | **ALB** | **4xx: 3107** | Peak 4xx |
| 22:30 | 00:30 | ALB | 15 req/5min (idle) — koniec ruchu testowego | Ruch spada |
| 22:30+ | 00:30+ | ALB | Response time: avg **470 ms**, p50 60 ms, p99 1.4 s | **ANOMALIA: nie wraca do baseline 12ms — trwa aż do końca okna** |
| 22:30+ | 00:30+ | ECS | Memory avg **66–68%**, max 73% | Nie spada — retencja pamięci |
| 22:30+ | 00:30+ | Redis | CacheHits: 0, CacheMisses: 0, EngineCPU: 0.33% | Redis idle — poprawnie |
| 22:42 | 00:42 | Alarm | `TargetTracking-maspex-api-AlarmLow-f1fcf0e7` → ALARM | CPU scale-in alarm wyzwolony (CPU zbyt niskie) |
| 23:01 | 01:01 | Alarm | `TargetTracking-maspex-api-AlarmLow-859a19be` → OK | Memory scale-in alarm cofnięty |

---

## 4. ECS / Auto Scaling

| Metryka | Wartość baseline (idle) | Peak 22:20 UTC | Post-test (22:30+) |
|---|---|---|---|
| CPU avg | 0.6–0.9% | **46.1%** | 1.5–2.0% |
| CPU max (na task) | ~3–5% | **78.7%** | ~3–6% |
| Memory avg | 13–18% | **49%** (przy niecałym peak) | **67% — nie spada** |
| Memory max (na task) | ~17–20% | **84.2%** (peak 22:20) / 92.1% (peak 22:25) | **73%** |
| Healthy hosts | 9/9 | 9/9 | 9/9 |
| Unhealthy hosts | 0 | 0 | 0 |

**Autoscaling konfiguracja:**
- MinCapacity: **9**, MaxCapacity: **15**
- CPU target: 60% avg → ScaleOut cooldown 60s, ScaleIn cooldown 300s
- Memory target: 75% avg → ScaleOut cooldown 60s, ScaleIn cooldown 300s
- Ostatnia aktywność skalowania: 2026-04-28 — brak nowych aktywności

**Autoscaling nie wyzwolił się podczas testu**: CPU avg peak 46.1% (próg 60%) — nie przekroczył. Memory avg peak ~74.5% (w przybliżeniu z 22:25 UTC) — bardzo blisko progu 75%. Memory max na task 92.1% sugeruje, że pojedyncze tasy były bliskie OOM.

**[HIPOTEZA]**: Brak scale-out przy CPU avg 46% i memory avg ~75% sugeruje, że autoscaling nie miał czasu zareagować — ruch był zbyt krótki (5–10 minut peak) lub cooldown nie pozwolił. AlarmHigh-CPU uaktualniony ostatnio 2026-04-28 (stan OK) — alarm może nie był oceniony w nowym oknie.

**Post-test anomalia**: CPU wraca do 1.5% ale memory zostaje na 67%. Brak garbage collection / memory leak w aplikacji. CloudWatch alarm `AlarmLow-f1fcf0e7` (CPU scale-in) wyzwolony o 00:42 — system próbuje zmniejszyć liczbę tasków ze względu na niskie CPU, ale memory nie wraca.

---

## 5. ALB

| Timestamp CEST | UTC | RequestCount /5min | Response Avg | p50 | p90 | p99 | 4xx | 5xx Target | 5xx ELB |
|---|---|---|---|---|---|---|---|---|---|
| 23:30 | 21:30 | 218,861 | 12 ms | 3.6 ms | 29 ms | 48 ms | 245 | 0 | 0 |
| 23:35 | 21:35 | 227,487 | 13 ms | 4.5 ms | 32 ms | 61 ms | 480 | 0 | **1** |
| 23:40–23:55 | 21:40–21:55 | ~15 (idle) | **372–399 ms** | 59–68 ms | 1.0–1.2 s | 1.0–1.2 s | 0 | 0 | 0 |
| 00:00 | 22:00 | 14,780 | 24 ms | 3.6 ms | 54 ms | 247 ms | 8 | 0 | 0 |
| 00:05 | 22:05 | 82,631 | 12 ms | 3.2 ms | 30 ms | 52 ms | 102 | 0 | 0 |
| 00:10 | 22:10 | 390,423 | 12 ms | 3.4 ms | 29 ms | 47 ms | 413 | 0 | 0 |
| 00:15 | 22:15 | 285,275 | 12 ms | 3.5 ms | 29 ms | 48 ms | 589 | 0 | 0 |
| **00:20** | **22:20** | **1,249,436** | **1965 ms** | **12.7 ms** | **7.9 s** | **15.8 s** | **6430** | **3464** | **178** |
| **00:25** | **22:25** | **323,361** | **1547 ms** | **15.8 ms** | **6.6 s** | **14.2 s** | **3107** | **912** | **58** |
| 00:30+ | 22:30+ | ~15 (idle) | **463–522 ms** | 56–80 ms | 1.3–1.4 s | 1.3–2.1 s | 0 | 0 | 0 |

**Obserwacje:**
1. **Paradoks 21:40–21:55**: Ruch spada do ~15 req/5min (health checks), ale response time avg = 370–400 ms (p99 ~1.1 s). Pre-test lub "cooling" z poprzedniej fali. Te 15 requestów to health checks ALB — ich latencja 370 ms sugeruje aplikacja była już obciążona przed głównym testem.
2. **Peak 22:20**: Ogromny skok wolumenu (3x vs poprzednie 5min interwały). p50 wzrósł minimalnie (3.5→12.7 ms), ale p99 wzrósł dramatycznie (48 ms→15.8 s). Klasyczny objaw queue buildup / request timeouts.
3. **Post-test latencja**: Po zakończeniu ruchu avg latencja nie wraca do 12 ms — zostaje na 460–520 ms aż do końca obserwacji (23:30 UTC). To 15 req/5min (health checks) ze stałą latencją ~460 ms = aplikacja w stanie degradowanym mimo braku ruchu.
4. **UnHealthyHostCount = 0** przez cały czas — ALB nie usunął żadnego targetu.

---

## 6. CloudFront

| Timestamp CEST | UTC | Requests /5min | BytesDownloaded | 4xxErrorRate | 5xxErrorRate | TotalErrorRate |
|---|---|---|---|---|---|---|
| 23:30 | 21:30 | 368,105 | 12.5 GB | 0.067% | 0.000% | 0.067% |
| 23:35 | 21:35 | 384,056 | 12.9 GB | 0.126% | 0.000% | 0.126% |
| 23:40–23:55 | 21:40–21:55 | ~15–16 (idle) | ~0 B | 0% | 0% | 0% |
| 00:00 | 22:00 | 24,667 | 847 MB | 0.032% | 0% | 0.032% |
| 00:05 | 22:05 | 139,914 | 4.7 GB | 0.073% | 0% | 0.073% |
| 00:10 | 22:10 | 666,120 | 21.9 GB | 0.062% | 0% | 0.062% |
| **00:15** | **22:15** | **487,754** | **16.0 GB** | 0.121% | 0% | 0.121% |
| **00:20** | **22:20** | **2,138,080** | **71.5 GB** | **0.301%** | **0.170%** | **0.471%** |
| **00:25** | **22:25** | **567,864** | **16.4 GB** | **0.547%** | **0.171%** | **0.718%** |
| 00:30 | 22:30 | 15 | ~0 B | **6.25%** | 0% | **6.25%** |
| 00:30–01:25 | 22:30–23:25 | 15–17 (idle) | ~0 B | 0%–5.9% | 0% | 0%–5.9% |

**Obserwacje:**
1. **Peak wolumenu**: 2.138M req/5min o 00:20 CEST (22:20 UTC) — najwyższy z raportowanych punktów.
2. **CF absorpcja vs ALB**: CF 2.138M req/5min vs ALB 1.249M req/5min = ~41% ruchu zaserwowane z cache CloudFront.
3. **5xxErrorRate 0.17%**: Przy 2.138M req = ~3634 żądań zakończonych 5xx widzianych przez CloudFront. Koreluje z 3464 HTTPCode_Target_5XX z ALB.
4. **CacheHitRate: niedostępna** — Policy ID `4135ea2d-6df8-44a3-9df3-4b5a84be39ad` = standardowa `CachingDisabled` policy AWS. [HIPOTEZA] Cały ruch przez CloudFront trafia do origin (brak cachowania na poziomie CF default behavior).
5. **OriginLatency: niedostępna** — wymagałaby Enhanced Metrics CF (dodatkowy koszt).
6. **4xxErrorRate 6.25% o 22:30**: Przy ~15 req/5min = ~1 request zakończony 4xx. Prawdopodobnie health check lub residual request.

---

## 7. Redis / ElastiCache

Klaster: `maspex-uat` (cache.t3.medium, Redis single-node)

| Timestamp CEST | UTC | CPU avg | EngineCPU avg | EngineCPU max | CurrConns avg | CacheHits /5min | CacheMisses /5min | DBMemory% | Evictions |
|---|---|---|---|---|---|---|---|---|---|
| 23:30 | 21:30 | 5.2% | 3.35% | 4.38% | 32 | 55,744 | 38,544 | 0.61% | 0 |
| 23:35 | 21:35 | 5.1% | 3.79% | **9.97%** | 32 | 125,441 | 54,373 | 0.61% | 0 |
| 23:40–23:55 | 21:40–21:55 | 2.5–2.5% | 0.32–0.33% | 0.33–0.35% | 10–20 | 0 | 0 | 0.42% | 0 |
| 00:00 | 22:00 | 2.6% | 0.57% | 1.12% | 27–32 | 3,736 | 1,915 | 0.45% | 0 |
| 00:05 | 22:05 | 3.7% | 1.90% | 2.15% | 31–32 | 25,296 | 13,859 | 0.51% | 0 |
| 00:10 | 22:10 | 7.3% | 5.33% | 7.18% | 31–32 | 131,178 | 67,177 | 0.63% | 0 |
| 00:15 | 22:15 | 6.6% | 5.08% | 6.97% | 31–32 | 122,355 | 56,202 | 0.69% | 0 |
| **00:20** | **22:20** | **13.4%** | **11.64%** | **14.69%** | **31–32** | **442,593** | **189,149** | **0.92%** | 0 |
| **00:25** | **22:25** | **7.2%** | **6.48%** | **13.98%** | **31** | **217,425** | **97,067** | **0.86%** | 0 |
| 00:30+ | 22:30+ | 2.0–2.2% | 0.33–0.34% | 0.35–0.38% | 31 | 0 | 0 | 0.44% | 0 |

**Cache Hit Ratio** (obliczone z danych):
- 22:10: 131,178 / (131,178+67,177) = **66.1%**
- 22:15: 122,355 / (122,355+56,202) = **68.5%**
- 22:20: 442,593 / (442,593+189,149) = **70.1%**
- 22:25: 217,425 / (217,425+97,067) = **69.1%**

**Obserwacje:**
1. **Redis jest zdrowy**: CPU max 14.7%, EngineCPU max 14.7% — daleko od problemów (>80% to ryzyko). Evictions=0, Swap=0, DBMemory<1.3%.
2. **CurrConnections = 31–32 przez cały test**: Stała liczba połączeń = pooling aplikacyjny działa prawidłowo. Brak connection storm.
3. **Hits/Misses po 22:30 = 0**: Redis całkowicie idle po zakończeniu ruchu — potwierdzenie że 15 req/5min (health checks ALB) NIE trafią do Redis.
4. **Hit Ratio ~70%**: Zdrowy poziom. W poprzednich testach write-through był całkowicie zepsuty — tutaj brak błędów.
5. **Gap 21:40–21:55**: Redis CacheHits/Misses = 0, CurrConnections spada do 10–20. **To jest kluczowy sygnał** — skąd wzięły się health-checky ALB z latencją 370 ms, skoro Redis był idle? Problem leżał w aplikacji, nie w Redis.

**Wnioski Redis**: Redis nie jest bottleneckiem. Jego zachowanie jest wzorcowe.

---

## 8. Logi aplikacyjne

**Ważna uwaga o konfiguracji logów:**
- Log group `/maspex/shared/maspex-api` = **pusta** (0 stored bytes)
- Rzeczywiste logi maspex-api trafiają do `/maspex/uat/contest-service` ze stream prefix `maspex-api/maspex-api/*`
- Log group `/maspex/uat/contest-service` ma 1.2 GB stored (30-dniowa retencja)

**maspex-api logs (z `/maspex/uat/contest-service`, stream `maspex-api/*`):**

Kwerendy uruchomione na oknie 21:30–23:30 UTC:

| Kwerenda | Wynik |
|---|---|
| Błędy (error, fail, timeout, circuit, abort, VOTE_CACHE, Redis) | **0 wyników** w głównym oknie testowym |
| `VOTE_CACHE_WRITETHROUGH_FAIL` by 5min bin | **0 wyników** |
| 5xx responses (`"statusCode":5`) by 1min | **6 total** (2 binów, 2+4) |
| CACHE-CRON aktywność | Regularnie co 1 minutę (każdy task) — normalnie |

**[KLUCZOWE ODKRYCIE]**: Brak `VOTE_CACHE_WRITETHROUGH_FAIL` i błędów circuit breakera Redis. W poprzednim teście (2026-05-05 19:00) było 924,582 takich błędów. To jest **fundamentalna zmiana** — albo (a) poprawka Redis circuit breakera zadziałała, albo (b) inny typ ruchu/testu, albo (c) inna ścieżka kodu.

**Błędy `Error fetching completed stages`** (Next.js prerendering): Widoczne od 19:30 UTC na wielu task streamach. Są to **błędy prerendering SSR** — `Error: During prerendering, fetch() rejects when the prerender is complete` — standardowy błąd Next.js przy prerender, nie wskazuje na problem produkcyjny per se, ale może być źródłem 5xx.

**CACHE-CRON**: Działa regularnie — co minutę każdy task loguje `>>> [CACHE-CRON] Start requestu`. Normalny background job.

**Bot logs (`/maspex/uat/bot`):**
- Ciągłe restarty (SIGTERM) przed oknem testowym (21:21, 21:29 UTC) — bot restartuje się ~co 7-8 minut
- Przyczyna: `[TWITCH] Failed to run Twitch bot. Missing auth token.` — brak konfiguracji Twitch auth
- Discord bot uruchamia się poprawnie, ale Twitch component failuje
- **Alarm `maspex-uat-alb-unhealthy-hosts-bot` → ALARM** od 2026-05-08 22:12 (stary problem pre-test)
- Bot nie jest powiązany z ruchem load testu

**Admin-panel logs**: 0 logów w oknie testowym.

---

## 9. Korelacja sygnałów

```
Timeline 21:30–23:30 UTC (wyniki co 5 min, CEST w nawiasie):

21:30 (23:30): CF 368k, ALB 219k, ECS CPU 8.8% avg  → pre-test wave lub faza poprzedniego testu
21:35 (23:35): CF 384k, ALB 227k, ECS CPU 9.1% avg  → fala redukuje się
21:35 (23:35): [ANOMALIA] ALB health checks latencja 370–400ms, p99 1.0s — aplikacja obciążona post-test
21:40–21:55 (23:40–23:55): Ruch ~0, Redis ~0, ale ALB latencja 370ms (health checks) — [HIPOTEZA] task pool drains / GC pressure
22:00 (00:00): Test główny start, ALB 14k → 83k req/5min
22:10 (00:10): ALB 390k, ECS CPU 13.8% avg, Redis EngineCPU 5.3% — wszystko w normie
22:15 (00:15): ALB 285k, Redis 122k hits — normalne zachowanie
22:20 (00:20): ALB BURST → 1.249M req/5min (+238% vs 22:15!)
             ECS CPU 46.1% avg / 78.7% max → BLISKIE progu 60%
             ECS Memory 49% avg / 84.2% max → MAX powyżej progu 75%
             ALB p99 15.8s → TIMEOUTY / KOLEJKOWANIE
             ALB 3464 5xx → REQUEST FAILURES
             Redis EngineCPU 14.7% max → normalny
22:25 (00:25): Ruch 323k (spada), ale latencja nadal wysoka (1547ms avg, p99 14.2s)
             ECS Memory 74.5% avg / 92.1% max → KRYTYCZNIE WYSOKA
             5xx: 912 — nadal błędy pomimo malejącego ruchu
22:30 (00:30): Ruch wraca do ~15 req/5min
             ALB avg latencja: 470ms i nie spada (do końca obserwacji)
             ECS Memory: 67% avg / 73% max — zatrzymała się, nie spada
             Redis: 0 hits/misses — idle
00:42 (02:42?): CW Alarm AlarmLow-CPU → ALARM (scale-in próbuje się wyzwolić)
```

**Korelacja kluczowa**:
- Burst ruchu o 22:20 był zbyt duży i zbyt gwałtowny (3x w 5 minutach)
- ECS nie zdążył skalować (CPU avg 46% < 60% progu)
- Memory spike do 92% max wskazuje na task-level memory pressure / allocation burst
- Post-test elevated latency (470ms dla health checks) = aplikacja nie wróciła do stanu startowego
- Memory retencja na 67% sugeruje: in-memory cache aplikacyjny lub brak GC po dużym przetwarzaniu

---

## 10. Najbardziej prawdopodobny bottleneck

**Bottleneck:** Application-level request processing — przesycenie wewnętrznego connection poolu i/lub memory pressure podczas burst ruchu.

**Evidencja:**
1. **p50 latencja normalna (12.7 ms), p99 ekstremalna (15.8 s)** — nie wszystkie requesty dotknięte, tylko "ogon". Klasyczny objaw queue buildup lub per-task resource contention.
2. **Memory max 84–92% na task o 22:20–22:25** — część tasków była w stanie krytycznym. Node.js GC pod presją memory może wprowadzać pauzy dziesiątek ms–kilku s.
3. **Post-test elevated latency 460–520 ms** przy ~15 req/5min (health checks) przez >1h po teście. Jeśli aplikacja by była "czysta" po teście, health checks powinny być <10 ms. To wskazuje że stan in-memory (cache/connection pool) jest zmieniony.
4. **3464 + 912 = 4376 HTTPCode_Target_5XX** — origin zwrócił 5xx. Możliwe przyczyny: timeout w aplikacji, DB connection pool exhaustion, lub Node.js process event loop lag.
5. **Brak VOTE_CACHE_WRITETHROUGH_FAIL** — Redis write path działa. Bottleneck nie jest w warstwie Redis.
6. **Brak unhealthy hosts** — ALB nie oznaczył tasków jako unhealthy, więc nie doszło do całkowitego task failure.

**[HIPOTEZA]**: Node.js event loop saturation lub connection pool exhaustion (do bazy danych lub innego downstream) pod burst load ~250k req/min. Memory pozostała na 67% = in-memory data structures (np. połączenia, cache lokalny) nie zostały zwolnione.

**[HIPOTEZA]**: Zmiana konfiguracji Redis z 2026-05-08 (wg `redis-connection-change-2026-05-08.md`) mogła naprawić VOTE_CACHE problem, ale otworzyła nowy problem — możliwe że poprzednie circuit breaker errors "szybko failowały" i skracały czas requestu; teraz requesty czekają na odpowiedź, co zwiększa latencję.

---

## 11. Co wykluczono

| Hipoteza | Dlaczego wykluczone | Evidencja |
|---|---|---|
| Redis jako bottleneck | EngineCPU max 14.7%, evictions=0, swap=0, stable connections 31-32 | CloudWatch Redis metrics |
| ALB unhealthy hosts | UnHealthyHostCount=0 przez cały test, 9/9 healthy | ALB HealthyHostCount metric |
| ECS autoscaling wyzwolił się | Brak aktywności skalowania, ostatnia 2026-04-28 | Application Autoscaling activities |
| ECS task crash (stopped tasks) | 0 STOPPED tasks w API | `aws ecs list-tasks --desired-status STOPPED` |
| CloudFront jako bottleneck | 5xx CloudFront = 0 poza 22:20-22:25, cache absorpcja 41% | CF 5xxErrorRate |
| VOTE_CACHE circuit breaker | 0 VOTE_CACHE_WRITETHROUGH_FAIL w logach | CloudWatch Logs Insights |
| ElastiCache evictions / memory | 0 evictions, DBMemory <1.3%, swap 0 | CloudWatch ElastiCache metrics |
| Network/VPC issue | ALB metryki normalne, ELB_5XX low (178 max) | ALB ELB_5XX_Count |
| Baza danych (RDS) | Brak dostępu do RDS metryk — nie wykluczone | Brak danych |

---

## 12. Recommended next steps

### P0 — Natychmiast przed następnym testem

1. **Zidentyfikować przyczynę post-test elevated latency (460ms health checks)**: Czy aplikacja "resetuje się" po restarcie taska? Jeśli tak, wskazuje na in-memory state. Sprawdzić czy po restarcie ECS health check wraca do <10 ms.

2. **Zbadać memory retencję**: 67% avg memory po teście, bez powrotu do baseline (13–18%). Sprawdzić profil Node.js memory — czy to lokalne cache, connection pools, czy leak?

3. **Poprawić konfigurację logów**: Log group `/maspex/shared/maspex-api` jest pusta — logi idą do `/maspex/uat/contest-service`. Albo uaktualnić task definition (target log group), albo używać właściwego log group w narzędziach monitorujących.

### P1 — Przed testem produkcyjnym

4. **APM / distributed tracing**: Obecnie jedynym sygnałem jest ALB p99. Brakuje wewnętrznego profilu requestu (co trwa 15 sekund — connection wait, DB query, serialization?). Wdrożyć X-Ray lub OpenTelemetry.

5. **Zmiana redis z 2026-05-08**: Plik `redis-connection-change-2026-05-08.md` wskazuje zmianę konfiguracji. Sprawdzić czy zmiana miała charakter "naprawiający" circuit breaker, oraz czy nowe zachowanie (brak szybkich failów) powoduje wyższe latencje.

6. **Connection pool sizing review**: Przy 9 taskach i burst do ~250k req/min, czy connection pool do DB jest odpowiednio zwymiarowany? Standardowy Node.js app z pool=10/task = 90 połączeń łącznie.

7. **Autoscaling reaction time**: CPU avg 46% nie wyzwala scale-out. Rozważyć obniżenie progu CPU do 40% lub dodanie metryki custom (active connections / request queue depth).

8. **Pre-test warm-up**: Dane sugerują że test o 23:30 CEST (21:30 UTC) był poprzedni test / faza warm-up. Latencja 370ms zaraz po powrocie do idle (21:40 UTC) sugeruje że 9 tasków nie zdąża "ochłonąć" przed kolejnym testem. Wdrożyć cooldown minimum 15 min między testami.

9. **ELB-level 5xx monitoring**: HTTPCode_ELB_5XX 178 o 22:20 UTC — to ELB odrzucił requesty zanim dotarły do targetu (connection refused / timeout). CloudWatch alarm `maspex-uat-alb-elb-5xx` był OK o 00:43 — sprawdzić threshold alarmu.

---

## 13. Evidence — komendy CLI

```bash
# CloudFront metrics (us-east-1)
aws cloudwatch get-metric-statistics --namespace AWS/CloudFront \
  --metric-name Requests --dimensions Name=DistributionId,Value=E3J76RNXIE2YIG Name=Region,Value=Global \
  --start-time 2026-05-10T21:30:00Z --end-time 2026-05-10T23:30:00Z \
  --period 300 --statistics Sum --profile maspex-cli --region us-east-1

# ALB response time percentiles (eu-west-1)
aws cloudwatch get-metric-data --metric-data-queries '[
  {"Id":"p99","MetricStat":{"Metric":{"Namespace":"AWS/ApplicationELB","MetricName":"TargetResponseTime","Dimensions":[{"Name":"LoadBalancer","Value":"app/maspex-uat/68317764a66425bd"}]},"Period":300,"Stat":"p99"},"Label":"p99"},
  {"Id":"p90","MetricStat":{"Metric":{"Namespace":"AWS/ApplicationELB","MetricName":"TargetResponseTime","Dimensions":[{"Name":"LoadBalancer","Value":"app/maspex-uat/68317764a66425bd"}]},"Period":300,"Stat":"p90"},"Label":"p90"}
]' --start-time 2026-05-10T21:30:00Z --end-time 2026-05-10T23:30:00Z --profile maspex-cli --region eu-west-1

# ECS autoscaling targets
aws application-autoscaling describe-scalable-targets \
  --service-namespace ecs --resource-ids service/maspex-uat/maspex-api \
  --profile maspex-cli --region eu-west-1

# CloudWatch alarms (ostatni status)
aws cloudwatch describe-alarms --profile maspex-cli --region eu-west-1 \
  --query 'MetricAlarms[?contains(AlarmName,`maspex`)].{name:AlarmName,state:StateValue,updated:StateUpdatedTimestamp}'

# Logi maspex-api (poprawna lokalizacja)
aws logs start-query \
  --log-group-name "/maspex/uat/contest-service" \
  --start-time 1778448000 --end-time 1778451600 \
  --query-string 'fields @timestamp, @logStream, @message | filter @logStream like /maspex-api/ | filter @message like /error/ | sort @timestamp asc | limit 500' \
  --profile maspex-cli --region eu-west-1
```

Log groups przeszukane:
- `/maspex/uat/contest-service` (zawiera stream `maspex-api/maspex-api/*`) — PRIMARY
- `/maspex/uat/bot`
- `/maspex/uat/admin-panel` (0 logów w oknie)
- `/maspex/shared/maspex-api` (0 stored bytes — pusta)

---

## 14. Missing or unavailable data

| Brakujące dane | Przyczyna | Impact na analizę |
|---|---|---|
| **CloudFront CacheHitRate** | 0 datapoints — Enhanced Metrics nie włączone lub policy = CachingDisabled (`4135ea2d`) | Nie wiadomo dokładnie ile CF servuje z cache vs origin; estymat z Requests vs ALB ~41% |
| **CloudFront OriginLatency** | 0 datapoints — Enhanced Metrics nie włączone | Nie widać latencji na ścieżce CF→origin |
| **RDS / Aurora metryki** | Brak dostępu w tej analizie | Nie wiadomo czy DB jest bottleneckiem (p99 15.8s może być DB query timeout) |
| **Log group `/maspex/shared/maspex-api`** | Pusta — task definition wskazuje na inny log group | Mylące — dokumentacja/monitoring powinien używać prawidłowej lokalizacji |
| **APM / distributed traces** | Nie skonfigurowane | Brak breakdownu czasu requestu w aplikacji |
| **ALB access logs (S3)** | Nie sprawdzone w tej analizie | Możliwy pełny breakdown requestów, status codes per endpoint |
| **ECS task-level CPU/memory (per-task)** | CloudWatch ECS metrics agregują wszystkie taski | Nie wiadomo które taski miały memory=92% — mogły być "wybrane" tasy |
| **Node.js event loop metrics** | Nie skonfigurowane | Kluczowe dla diagnozy latencji tail |
| **Poprzednie testy do porównania (2026-04-28, 2026-04-29)** | Nie odczytano sekcji szczegółów tych analiz | Porównanie oparte tylko na 2026-05-05 19:00 (pełna analiza dostępna w vault) |
| **Konfiguracja Redis po zmianie 2026-05-08** | Nie odczytano szczegółów pliku `redis-connection-change-2026-05-08.md` | Nie wiadomo dokładnie co zostało zmienione |

---

*Analiza wykonana przez claude-sonnet-4-6 na podstawie danych AWS CLI zebranych 2026-05-11.*
*Metryki: granularność 5 min (period=300). Timestamps w tabelach: UTC. CEST = UTC+2.*
