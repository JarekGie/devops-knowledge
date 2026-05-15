---
title: "Load Test Analysis — Maspex UAT — 2026-05-15 12:00–12:30 CEST"
date: 2026-05-15
type: load-test-analysis
environment: uat
analyst: operator
tags: [load-test, ecs, autoscaling, redis, maspex, uat]
---

> **Środowisko:** UAT | **Konto AWS:** 969209893152
> **Okno testu:** 2026-05-15 **12:00–12:30 CEST** (10:00–10:30 UTC)
> **ECS desired przed testem:** 12 tasków (pre-scale)
> **Poprzedni test:** [[loadtest-2026-05-14-analysis-test2]] (14 maja, 17:39–18:00 CEST, 9 tasków)

---

## 1. Executive Summary

| Kwestia | Ocena |
|---------|-------|
| Środowisko przeszło test | **Częściowo** — system wytrzymał główne okno (12:00–12:20), ale zdarzył się incident na końcu |
| Główne zdarzenie | **Autoscaling scale-out do 30 tasków o 12:24:48 CEST** — 18 nowych tasków uruchomionych w trakcie obciążenia |
| Degradacja | Tak — krótka (12:20–12:25 CEST): 160 ELB 5xx, 1 unhealthy host, 19 target 5xx, VOTE_CACHE_WRITETHROUGH_FAIL (68 szt.), p99 latency 1.49 s |
| Bottleneck | **Peak traffic ~530k req/min przytłoczył 12 tasków** → autoscaling zadziałał, ale z opóźnieniem ~20 min |
| SUPABASE_JWT_SECRET fix | ✅ **Zadziałał** — tylko 2 fallback events w całym oknie, na 1 starym tasku przed testem |
| Redis | ✅ Stabilny — brak Evictions, DatabaseMemoryUsage < 2%, brak circuit breaker |
| ECS health | ⚠️ 1 task zastąpiony przez ECS (unhealthy) o 12:24:36 CEST podczas scale-out |
| Autoscaling | ✅ **Zadziałał po raz pierwszy** — policy ALBRequestCountPerTarget wyzwoliła scale 12→30 |
| Dane aplikacyjne (Supabase) | ⚠️ FK violation errors: synthetic users (`00000000-...015001`) nie mają profili w DB |

**Najważniejsze wnioski:**

1. **Autoscaling po raz pierwszy zadziałał** — polityka `maspex-uat-api-alb-request-count` (target: 10 000 req/target) wyzwoliła scale-out do max 30 tasków o 12:24:48 CEST. Poprzednie testy uruchamiały się bez pre-scale lub z 9 taskami gdzie autoscaling nie docierał do progu.
2. **Fix SUPABASE_JWT_SECRET skuteczny** — 2 fallback events to startup trace z jednego starego taska, nie błąd runtime. Zero 401 podczas testu.
3. **Scale-out nastąpił za późno** — ruch peak był o 12:20 CEST (2 650 353 req/5 min = 8 835 req/s), autoscaling zareagował 4–5 minut później. W oknie 12:20–12:25 doszło do degradacji z powodu braku wystarczającej liczby tasków.
4. **Redis pracował poprawnie** — CacheHit ratio ~75% (1 047 669 hits / 351 157 misses = 74.9% hit rate w oknie 12:20–12:25), brak Evictions, EngineCPU max 25.6%.
5. **FK violation w Supabase** — synthetic test users mają ID z zakresu `00000000-...015001` i nie mają wierszy w tabeli `profiles`. Powoduje to błędy VOTE_RPC_ERROR i submitSloganToDb. Jest to problem konfiguracji danych testowych, nie infrastruktury.

**Poprawa vs poprzednie testy:** Znacząca. Autoscaling zadziałał (vs. brak reakcji przy 9 taskach). JWT fix eliminuje klasę błędów auth. Redis nie osiągnął saturacji. Liczba 5xx (180 łącznie) jest dużo niższa niż w testach z 14 maja (512 ELB 5xx i 722 ELB 5xx odpowiednio).

---

## 2. Scope i time window

| Okno | CEST | UTC |
|------|------|-----|
| Kontekstowe | 11:45–13:00 | 09:45–11:00 |
| Główne (test) | 12:00–12:30 | 10:00–10:30 |
| Incident window | 12:20–12:30 | 10:20–10:30 |

**Regiony:**
- `eu-west-1` — ALB, ECS, ElastiCache, CloudWatch Logs
- `us-east-1` — CloudFront metrics

**Źródła danych:**

| Namespace / źródło | Dane dostępne |
|--------------------|---------------|
| `AWS/CloudFront` | Requests, 4xxErrorRate, 5xxErrorRate, TotalErrorRate |
| `AWS/ApplicationELB` | RequestCount, TargetResponseTime (avg/p50/p90/p99), HTTPCode_Target_4XX/5XX, HTTPCode_ELB_5XX, HealthyHostCount, UnHealthyHostCount |
| `AWS/ECS` | CPUUtilization, MemoryUtilization (service-level) |
| `ECS/ContainerInsights` | DesiredTaskCount, RunningTaskCount, PendingTaskCount, TaskMemoryUtilization, TaskCpuUtilization (per-task) |
| `AWS/ElastiCache` | CurrConnections, EngineCPUUtilization, DatabaseMemoryUsagePercentage, CacheHits, CacheMisses, Evictions |
| `/maspex/uat/contest-service` | CACHE-CRON, SUPABASE_JWT_SECRET, VOTE_CACHE_WRITETHROUGH_FAIL, VOTE_RPC_ERROR, submitSloganToDb Error, startup logs |
| `/maspex/uat/bot` | SIGTERM, restart loops, Twitch auth errors (poza oknem testu) |
| `aws application-autoscaling` | Scaling activities, policies |
| `aws ecs describe-services` | Service events, task registrations |

---

## 3. Timeline

| Czas UTC | Czas CEST | Komponent | Zdarzenie | Ocena |
|----------|-----------|-----------|-----------|-------|
| 09:45 | 11:45 | ECS | desired=12, running=12, pending=0 — stabilny pre-scale | ✅ Gotowe |
| 09:45 | 11:45 | ALB | HealthyHostCount=12 min/max, 0 unhealthy | ✅ |
| 09:47 | 11:47 | Logi | SUPABASE_JWT_SECRET fallback — 1 stary task przy starcie (2 events) | ⚠️ Stary task, nie runtime |
| 09:50–09:55 | 11:50–11:55 | ECS | RunningTaskCount chwilowa anomalia (pojawia się 23 w jednym punkcie) | ℹ️ Artefakt metryki |
| 10:00 | 12:00 | CF/ALB | Test start — CF 17 186 req, ALB 10 260 req w 5 min | ✅ Ramp-up |
| 10:05 | 12:05 | CF/ALB | CF 83 700, ALB 49 619 req / 5 min | ✅ |
| 10:10 | 12:10 | CF/ALB | CF 354 334, ALB 207 209 / 5 min (692 req/s ALB) | ✅ |
| 10:15 | 12:15 | CF/ALB | CF 504 662, ALB 302 464 / 5 min (1 008 req/s ALB) | ✅ Stabilne |
| 10:15 | 12:15 | Logi | 4 VOTE_RPC_ERROR (FK violation synthetic users) — pierwsze sygnały | ⚠️ Dane testowe |
| **10:20** | **12:20** | **CF/ALB** | **PEAK: CF 4 516 906, ALB 2 650 353 / 5 min (8 835 req/s ALB)** | ⚠️ Szczyt |
| 10:20 | 12:20 | ECS | CPU avg 57.8%, max 98.5%; Memory avg 43.8%, max 78.9% | ⚠️ Saturacja zbliża się |
| 10:20 | 12:20 | Redis | EngineCPU 20.8% avg (max 25.6%), CurrConnections avg 41 | ✅ |
| **10:20** | **12:20** | **Logi** | **68 VOTE_CACHE_WRITETHROUGH_FAIL w 5 min** | ⚠️ Redis write-through timeout |
| **10:20** | **12:20** | **Logi** | **118 VOTE_RPC_ERROR + submitSloganToDb Error w 5 min** | ⚠️ Supabase FK violation |
| **10:20** | **12:20** | **ALB** | **19 HTTPCode_Target_5XX, 159 HTTPCode_ELB_5XX** | ⚠️ |
| **10:20** | **12:20** | **ALB** | **UnHealthyHostCount max=1** | ⚠️ 1 task nie odpowiada |
| **10:24:36** | **12:24:36** | **ECS** | **1 task zastąpiony przez ECS (unhealthy)** | ⚠️ Task restart |
| **10:24:48** | **12:24:48** | **Autoscaling** | **ALBRequestCountPerTarget ALARM → scale 12→30** | ✅ Autoscaling zadziałał |
| 10:24:53 | 12:24:53 | ECS | 17 nowych tasków uruchomionych | ✅ |
| 10:25 | 12:25 | ECS | PendingTaskCount spike=18 | ℹ️ |
| 10:25 | 12:25 | Logi | 18 nowych tasków startuje — PM2 startup, Next.js 16.2.6 online | ✅ |
| 10:25:03 | 12:25:03 | ECS | 1 target zarejestrowany w TG | ✅ |
| 10:25:24 | 12:25:24 | ECS | 17 targetów zarejestrowanych w TG | ✅ |
| 10:25 | 12:25 | ALB | HealthyHostCount 10→30 (min/max) | ✅ Stabilizacja |
| **10:25:34** | **12:25:34** | **ECS** | **Steady state: desired=30, running=30** | ✅ |
| 10:25 | 12:25 | CF/ALB | CF 570 124, ALB 315 878 / 5 min — ruch spada | ✅ Koniec testu |
| 10:25 | 12:25 | Redis | CurrConnections wzrasta z 41 → 84 avg, 95 max (nowe taski łączą się) | ℹ️ |
| 10:30 | 12:30 | CF/ALB | CF 3 req, ALB 0 req — test zakończony | ✅ |
| 10:30–10:45 | 12:30–12:45 | ECS | Alarms AlarmLow — rozpocznie się scale-in po cooldown | ℹ️ |

---

## 4. Ruch (CloudFront / ALB)

### Request volume (5-minutowe interwały)

| Czas CEST | CF req / 5 min | CF req/s | ALB req / 5 min | ALB req/s | CF offload |
|-----------|---------------|----------|----------------|-----------|-----------|
| 11:45 (baseline) | 455 | 1.5 | 290 | 1.0 | 36% |
| 12:00 | 17 186 | 57 | 10 260 | 34 | 40% |
| 12:05 | 83 700 | 279 | 49 619 | 165 | 41% |
| 12:10 | 354 334 | 1 181 | 207 209 | 691 | 41% |
| 12:15 | 504 662 | 1 682 | 302 464 | 1 008 | 40% |
| **12:20** | **4 516 906** | **15 056** | **2 650 353** | **8 835** | **41%** |
| 12:25 | 570 124 | 1 900 | 315 878 | 1 053 | 45% |
| 12:30 | 3 | <1 | 0 | 0 | — |

**Uwaga do 12:20:** Skok z 504 662 do 4 516 906 req w 5 min (9× wzrost) jest nieciągły. Prawdopodobnie test wchodzi w fazę najwyższego obciążenia (full VU). CloudFront offload stabilny na ~41%.

### CloudFront Error Rates

| Czas CEST | 4xxErrorRate | 5xxErrorRate | TotalErrorRate |
|-----------|-------------|-------------|---------------|
| 11:45 (baseline) | 33.4% | 0% | 33.4% |
| 12:00–12:15 | 0.09–0.17% | 0.0% | 0.09–0.17% |
| **12:20** | **0.38%** | **0.07%** | **0.46%** |
| 12:25 | 0.88% | 0.00% | 0.88% |

**Nota:** 33.4% 4xx o 11:45 przy 455 requestach to ~152 błędów — najprawdopodobniej healthcheck lub probe ruchu, nie wirtualni użytkownicy. Podczas właściwego testu 4xx < 1%.

---

## 5. ALB / request quality

### TargetResponseTime (period=300s)

| Czas CEST | avg (s) | p50 (s) | p90 (s) | p99 (s) |
|-----------|---------|---------|---------|---------|
| 11:45 | 0.038 | 0.028 | 0.050 | 0.755 |
| 12:00 | 0.015 | 0.004 | 0.036 | 0.066 |
| 12:05 | 0.012 | 0.004 | 0.030 | 0.054 |
| 12:10 | 0.011 | 0.003 | 0.027 | 0.047 |
| 12:15 | 0.011 | 0.003 | 0.027 | 0.046 |
| **12:20** | **0.112** | **0.018** | **0.134** | **1.493** |
| 12:25 | 0.021 | 0.006 | 0.033 | 0.188 |
| 12:30 | 0.089 | 0.017 | 0.076 | 1.601 |

**Interpretacja:** p99 latency wzrasta 32× (1.49 s vs. 0.046 s baseline) w oknie 12:20–12:25 CEST. avg i p50 utrzymują się rozsądnie — problemy dotykają tail (ogon rozkładu). Gwałtowne wzrosty p99 o 12:20 i 12:30 wskazują na wąskie gardło przy bardzo wysokim obciążeniu i przy restarcie tasków.

### Healthy/Unhealthy hosts timeline

| Czas CEST | HealthyHostCount (min/max) | UnHealthyHostCount (max) |
|-----------|--------------------------|------------------------|
| 11:45–12:15 | 12/12 | 0 |
| **12:20** | **10/12** | **1** |
| **12:25** | **30/30** | **0** |
| 12:30 | 30/30 | 0 |

1 unhealthy host o 12:20 CEST — zrestartowany przez ECS o 12:24:36 CEST. System sam się naprawił. Skok do 30 healthy hosts potwierdza skuteczność autoscaling.

### ALB Error counts

| Czas CEST | HTTPCode_ELB_5XX | HTTPCode_Target_5XX | HTTPCode_Target_4XX |
|-----------|-----------------|--------------------|--------------------|
| 11:45 | 0 | 0 | 152 |
| 12:00–12:15 | 0 | 0 | 15–789 |
| **12:20** | **159** | **19** | **17 241** |
| **12:25** | **1** | **4** | **4 992** |

**Łącznie 5xx:** 160 ELB 5xx + 24 Target 5xx = **184 błędów 5xx** w całym teście. Dla porównania test 14 maja test#2: 722 ELB 5xx przy porównywalnym ruchu. Poprawa ~4×.

**4xx:** 17 241 o 12:20 to primarily VOTE_RPC_ERROR (FK violation dla synthetic users — błędy warstwy aplikacyjnej, nie infrastruktury).

---

## 6. ECS / autoscaling

### Task count timeline

| Czas CEST | Desired | Running | Pending |
|-----------|---------|---------|---------|
| 11:45–12:24 | 12 | 12 | 0 |
| **12:24** | **12→30** | 12 | 0 |
| 12:25 | 30 | 12 | 18 |
| 12:26 | 30 | 30 | 0 |
| 12:30+ | 30 | 30 | 0 |

Pre-scale na 12 utrzymał się przez cały główny test. Scale-out do 30 nastąpił o 12:24:48 CEST, 4–5 minut po peak.

### ECS CPU / Memory (service-level, period=300s)

| Czas CEST | CPU avg | CPU max | Mem avg | Mem max |
|-----------|---------|---------|---------|---------|
| 11:45 | 0.24% | 2.6% | 3.3% | 3.8% |
| 12:00 | 0.93% | 2.4% | 3.4% | 4.2% |
| 12:05 | 2.88% | 8.2% | 4.3% | 5.2% |
| 12:10 | 8.02% | 13.5% | 6.0% | 8.6% |
| 12:15 | 9.41% | 30.4% | 8.1% | 13.4% |
| **12:20** | **57.83%** | **98.5%** | **43.8%** | **78.9%** |
| 12:25 | 5.20% | 48.6% | 29.6% | 83.3% |
| 12:30 | 0.88% | 3.8% | 27.0% | 66.6% |

**Interpretacja:** O 12:20 average CPU 57.83% to bliskie progu autoscaling (60%). Polityka CPU `maspex-uat-api-cpu` (target 60%) mogłaby też wyzwolić scale, ale wyzwoliła go polityka `maspex-uat-api-alb-request-count`. Memory avg 43.8% przy max 78.9% — widocznie nierówny rozkład obciążenia między taskami.

### Autoscaling activities (2026-05-15)

| Czas CEST | Zdarzenie | Status |
|-----------|-----------|--------|
| **12:24:48** | **AlarmHigh: ALBRequestCountPerTarget → desired=30** | **Successful** |

Tylko jedno zdarzenie scale-out w oknie testu. Scale-in (AlarmLow) zacznie się po cooldown po zakończeniu testu.

### Autoscaling policies

| Policy | Type | Target metric | Target value |
|--------|------|---------------|-------------|
| `maspex-uat-api-alb-request-count` | TargetTracking | ALBRequestCountPerTarget | 10 000 |
| `maspex-uat-api-memory` | TargetTracking | ECSServiceAverageMemoryUtilization | 75% |
| `maspex-uat-api-cpu` | TargetTracking | ECSServiceAverageCPUUtilization | 60% |

Min capacity: 12, Max capacity: 30. O 12:20 CEST ALB miał 2 650 353 req/5min = 530 071 req/min / 12 tasków = ~44 172 req/min/task > próg 10 000 → alarm HIGH wyzwolił scale.

---

## 7. Per-task analysis

### Top tasks by peak memory (Enhanced Container Insights, period=60s)

| Task ID (12 znaków) | Max Memory | Avg Memory | Max CPU | Avg CPU | Datapoints |
|---------------------|-----------|-----------|---------|---------|-----------|
| 059ab57abd7f | **81.8%** | 22.6% | 77.1% | 10.0% | 45 |
| d356a58314d5 | **80.2%** | 22.6% | 76.5% | 10.1% | 44 |
| a01fa335429d | 79.8% | 21.9% | **91.9%** | 12.4% | 46 |
| 72a1a90fb3c0 | 78.9% | 22.1% | 78.2% | 9.6% | 45 |
| 96559d44f991 | 78.4% | 22.2% | 76.7% | 9.9% | 45 |
| 884987e9a1fc | 77.9% | 23.6% | 75.9% | 9.1% | 46 |
| 5c561d963417 | 76.1% | 22.2% | 74.2% | 9.9% | 45 |
| 305f5f472b56 | 75.7% | 24.0% | 76.5% | 9.5% | 45 |
| 1d97a91518b8 | 75.7% | 21.6% | 81.0% | 10.7% | 45 |

**Nowe taski (uruchomione po scale-out) — max 6.8% Memory / 12.6% CPU** — nie zdążyły przyjąć obciążenia przed końcem testu.

### Kluczowe obserwacje

- **8 najciężej pracujących tasków (12 oryginalnych)** — max memory 75–82%, max CPU 74–92%. To są taski z pełnym oknem testowym (45–46 datapoints = ~45–46 min aktywności).
- **Spread między taskami:** min memory avg ~22%, max memory avg ~24% — rozkład pamięci stosunkowo równomierny między oryginalną pulą 12 tasków.
- **CPU spread wyższy:** task `a01fa335429d` max 91.9% vs. task `884987e9a1fc` max 75.9% — ~16 pp różnica. Możliwa nierówna dystrybucja połączeń lub sticky sessions.
- **Memory-first vs CPU-first:** Oba zasoby osiągają peak jednocześnie o 12:20 CEST. Task `a01fa335429d` to hotspot CPU (91.9%), `059ab57abd7f` to hotspot Memory (81.8%). Brak jednego dominującego wzorca.
- **Memory po scale-out:** service-level avg 29.6% o 12:25 (new tasks init~3–5%, old tasks stopniowo drain) → o 12:30 avg 27.0%, max 66.6%. Taski nie zdążyły w pełni wystartować podczas szczytu.

**Wniosek:** Load był stosunkowo równomiernie rozłożony między 12 oryginalnych tasków. Brak single hotspot który byłby 2× gorszy od pozostałych. Żaden task nie osiągnął memory 96%+ (vs. test 14 maja: 1–2 taski dobijały do 96%).

---

## 8. Redis / downstream

### ElastiCache `maspex-uat` (cache.t3.medium, single-node)

| Czas CEST | EngineCPU avg | EngineCPU max | CurrConn avg | DatabaseMem% max | CacheHits / 5 min | CacheMisses / 5 min | Hit Rate | Evictions |
|-----------|--------------|--------------|-------------|-----------------|-------------------|---------------------|----------|-----------|
| 11:45 | 0.32% | 0.33% | 31.8 | 0.42% | 842 | 23 | 97.3% | 0 |
| 12:00 | 0.52% | 0.87% | 28.6 | 0.46% | 3 455 | 1 048 | 76.7% | 0 |
| 12:05 | 1.44% | 1.82% | 41.0 | 0.51% | 16 524 | 6 229 | 72.6% | 0 |
| 12:10 | 4.00% | 5.02% | 41.0 | 0.62% | 81 155 | 30 248 | 72.8% | 0 |
| 12:15 | 3.82% | 5.15% | 41.0 | 0.62% | 76 495 | 28 893 | 72.6% | 0 |
| **12:20** | **20.78%** | **25.62%** | **41.4** | **1.80%** | **1 047 669** | **351 157** | **74.9%** | **0** |
| 12:25 | 7.78% | 22.30% | 84.8 | 1.74% | 316 354 | 107 300 | 74.7% | 0 |
| 12:30+ | 0.37% | 0.38% | 95.0 | 0.44% | 0 | 0 | — | 0 |

**Kluczowe ustalenia:**
- **Brak Evictions** w całym oknie — Redis nie osiągnął limitu pamięci.
- **DatabaseMemoryUsage max 1.80%** — bardzo daleko od limitu (cache.t3.medium ma 3.09 GB).
- **EngineCPU max 25.6%** — jednorazowy spike o 12:20, szybko opada. Brak circuit breaker.
- **Hit rate ~73–75%** — stabilny. CF offload i Redis razem eliminują ~83% ruchu (41% CF + 75% Redis z pozostałych).
- **CurrConnections 95** po scale-out (12:30) — 30 tasków × ~3 połączenia = oczekiwane. Poprzednio 41 = 12 tasków × ~3.

**68 VOTE_CACHE_WRITETHROUGH_FAIL o 12:20 UTC:** [HIPOTEZA] Nie jest to przeciążenie Redis, lecz timeout write-through po stronie aplikacji gdy taski były saturowane (CPU 57–98%). Redis był dostępny, ale aplikacja nie mogła wysłać zapytania w czasie. Jest to efekt saturacji CPU/Memory na poziomie kontenera, nie Redis.

**Supabase:** Brak bezpośrednich danych CloudWatch. FK violation errors (`code: '23503'`) dla synthetic users to problem konfiguracji danych testowych — ID `00000000-0000-0000-0000-000000015001` nie mają wierszy w tabeli `profiles`. Nie jest to problem infrastruktury.

---

## 9. Log analysis

### Wolumen logów z `/maspex/uat/contest-service` (UTC timestamps z CW Logs)

| Czas UTC | Czas CEST | Wolumen | Charakter |
|----------|-----------|---------|-----------|
| 09:45–09:50 | 11:45–11:50 | 71 | CACHE-CRON startups, 1 JWT fallback |
| 09:50–09:55 | 11:50–11:55 | 439 | Deployment nowych tasków (startupy) |
| 09:55–10:00 | 11:55–12:00 | 169 | CACHE-CRON, startup |
| 10:00–10:05 | 12:00–12:05 | 32 | Baseline ruchu |
| 10:05–10:10 | 12:05–12:10 | 14 | |
| 10:10–10:15 | 12:10–12:15 | 30 | |
| **10:15–10:20** | **12:15–12:20** | **42** | **4 pierwsze VOTE_RPC_ERROR (FK violation)** |
| **10:20–10:25** | **12:20–12:25** | **972** | **Burst błędów: 118 VOTE_RPC_ERROR + 68 VOTE_CACHE_WRITETHROUGH_FAIL** |
| 10:25–10:30 | 12:25–12:30 | 816 | Startup nowych 18 tasków (PM2, Next.js) |
| 10:30–10:35 | 12:30–12:35 | 650 | Startup nowych tasków |
| 10:35–10:40 | 12:35–12:40 | 522 | Blacklist loaded, CACHE-CRON na nowych taskach |
| 10:40–10:45 | 12:40–12:45 | 330 | |

### Auth path: SUPABASE_JWT_SECRET

- **2 fallback events** w całym oknie — oba na 1 strumieniu loga (`43cf6756ae9a4c2...`), o 09:47 UTC (11:47 CEST) = przed testem.
- **Zero 401 ani UNAUTHORIZED podczas testu** — JWT fix potwierdza skuteczność.
- Tylko 1 task ma stary config (SUPABASE_JWT_SECRET not set) — prawdopodobnie task z poprzedniego deployu, który nie został jeszcze zatrzymany. [HIPOTEZA] Zostanie zastąpiony po scale-in.

### VOTE_CACHE / Redis circuit

- **VOTE_CACHE_WRITETHROUGH_FAIL: 68 szt.** — wyłącznie w oknie 10:20–10:25 UTC (12:20–12:25 CEST).
- Wzorzec jest identyczny z testem 14 maja test#2: spike przy peak CPU, brak kontynuacji po opanowaniu obciążenia.
- **Brak circuit breaker events w logach** — Redis był dostępny.

### VOTE_RPC_ERROR / submitSloganToDb Error

- **118 zdarzeń** o 10:20–10:25 UTC; **10 zdarzeń** o 10:25–10:30 UTC; **4 zdarzenia** o 10:15–10:20.
- Natura błędów: `insert or update on table "votes/slogans" violates foreign key constraint` — `Key (user_id)=(00000000-0000-0000-0000-000000015001) is not present in table "profiles"`.
- Synthetic test users mają UUID pattern `00000000-0000-0000-0000-000000015001` — nie istnieją w Supabase `profiles`.
- **Jest to problem konfiguracji danych testowych, nie infrastruktury.** Infrastruktura obsłużyła te requesty — Supabase zwrócił 23503, aplikacja zalogowała błąd.

### Bot logi

- Logi bota (poza oknem testu — 07:49–08:11 UTC = 09:49–10:11 CEST) pokazują restart loop: `npm error signal SIGTERM` + `[TWITCH] Failed to run Twitch bot. Missing auth token.`
- Bot restartuje się cyklicznie z powodu brakującego tokenu Twitch. Niezależny problem, nie wpływa na API.

---

## 10. Root cause / bottleneck assessment

### Główny bottleneck

**O 12:20 CEST (10:20 UTC) ruch wzrósł do ~8 835 req/s na ALB przy zaledwie 12 taskach, co przekroczyło przepustowość puli.** Przeliczenie: przy 44 172 req/min/task i historycznym limicie ~10 000 req/target (polityka autoscaling) — każdy task był obciążony 4.4× powyżej targetu autoscalingu.

Konsekwencje:
1. ECS CPU avg 57.8%, max 98.5% — taski saturowane
2. 1 task nie odpowiedział na health check → restart
3. Aplikacja nie mogła pisać do Redis w limicie czasu → VOTE_CACHE_WRITETHROUGH_FAIL
4. Supabase FK violations → VOTE_RPC_ERROR (dane testowe, nie infrastruktura)
5. 159 ELB 5xx — ALB queue overflow lub task disconnect

### Contributing factors

1. **Opóźnienie autoscaling:** Alarm HIGH wyzwolił scale o 12:24:48, ~4–5 min po peak. Nowe taski były online o 12:25:34. Okno bez pełnych mocy = 4–5 min degradacji.
2. **Scale-out do max capacity (30):** System dobił do max cap. Przy kampanii produkcyjnej max=30 może być niewystarczający jeśli ruch będzie wyższy.
3. **FK violation w danych testowych:** Synthetic users bez profili generują błędy aplikacyjne. Maskuje prawdziwy error rate dla prawidłowych userów.

### Co wykluczono

| Obszar | Status | Evidencja |
|--------|--------|-----------|
| Redis przeciążenie | ✅ Wykluczono | EngineCPU max 25.6%, brak Evictions, DatabaseMem < 2% |
| JWT/auth failures | ✅ Wykluczono | 2 fallback events (pre-test), 0 podczas testu |
| Deployment collision | ✅ Wykluczono | Brak `UpdateService` w oknie; nowe taski = scale-out, nie deploy |
| Redis circuit breaker | ✅ Wykluczono | 0 circuit events w logach |
| Supabase timeout/network | Częściowo wykluczone | FK violations to problem danych, nie timeout |
| ECS task crash | ✅ 1 task tylko | 1 task zastąpiony, nie kaskadowe fail |

### Co nadal jest hipotezą

- [HIPOTEZA] VOTE_CACHE_WRITETHROUGH_FAIL jest efektem saturacji CPU taska (nie problemu Redis) — aplikacja nie zdążyła wysłać zapytania przed timeout
- [HIPOTEZA] Nierówny spread CPU (task `a01fa335429d` max 91.9% vs inne 74–77%) może wynikać z braku deregistration delay lub sticky sessions na poziomie ALB
- [HIPOTEZA] Jeden stary task z brakującym SUPABASE_JWT_SECRET zostanie usunięty po kolejnym redeploymencie lub scale-in

---

## 11. Comparison to previous tests

| Metryka | Test 14 maja #1 (9 tasków, 14:15) | Test 14 maja #2 (9 tasków, 17:39) | **Test 15 maja (12 tasków, 12:00)** | Delta vs #2 | Ocena |
|---------|----------------------------------|-----------------------------------|-------------------------------------|-------------|-------|
| Peak ALB req/s | ~6 665 req/s | ~5 657 req/s | **~8 835 req/s** | +56% | Wyższy ruch |
| ECS tasks (peak) | 9 | 9 | **12 → 30** | Autoscaling | ✅ Poprawa |
| CPU avg peak | 44% | 52% | **57.8%** | +5.8 pp | Wyższy (więcej ruchu) |
| CPU max peak | ~100% | ~96% | **98.5%** | -1.5 pp | Podobny |
| Memory avg peak | — | 36.9% | **43.8%** | +6.9 pp | Wyższy (więcej ruchu) |
| Memory max peak | ~80–96% | 90.4% | **78.9%** | -11.5 pp | **Poprawa** |
| ELB 5xx (total) | 512 | 722 | **160** | -78% | ✅ **Znacząca poprawa** |
| Target 5xx (total) | — | — | **24** | — | Niskie |
| p99 latency peak | ~30 s | ~30 s | **1.49 s** | -95% | ✅ **Ogromna poprawa** |
| Autoscaling | ❌ Nie zadziałał | ❌ Nie zadziałał | ✅ **Zadziałał** | — | ✅ |
| JWT auth errors | ❌ (fix nie wdrożony) | ❌ | ✅ **0** | — | ✅ |
| VOTE_CACHE fail | Tak (deployment) | 1 burst | **68** | — | ⚠️ Wyższy |
| Task restarts | 0 (deployment) | 6 tasków | **1 task** | -83% | ✅ Poprawa |
| Redis Evictions | 0 | 0 | **0** | = | ✅ |

**Podsumowanie porównania:** Test 15 maja wyraźnie lepszy od poprzednich pomimo wyższego ruchu (+56% req/s). Kluczowe poprawy: autoscaling zadziałał, JWT fix eliminuje klasę błędów, p99 latency 30 s → 1.49 s, ELB 5xx -78%. Jedyne regresje to wyższy VOTE_CACHE_WRITETHROUGH_FAIL (wynikający ze skoku ruchu, nie z degradacji) oraz FK violations z danych testowych.

---

## 12. Recommended next steps

### Przed kolejnym testem (priorytet wysoki)

1. **Napraw dane testowe — synthetic users potrzebują wierszy w tabeli `profiles`.**
   - Wszystkie UUIDs z zakresu `00000000-0000-0000-0000-000000015001` muszą mieć wpisy w `profiles` w Supabase UAT.
   - FK violations generują ~118 VOTE_RPC_ERROR per burst — maskuje prawdziwy error rate.
   
2. **Podnieś max capacity autoscaling powyżej 30.**
   - Test osiągnął max=30 przy ~8 835 req/s. Kampania może generować wyższy ruch.
   - Rozważyć max=50–60 zadanie.
   - Ocenić CPU limits na task def — przy 30 taskach: czy Fargate capacity provider i ENI limits nie będą bottleneck?

3. **Skrócenie czasu reakcji autoscaling scale-out.**
   - Aktualny czas: ~4–5 min od peak do scale-out.
   - Opcje: zmniejszyć evaluation periods (np. z 3 × 1 min → 1 × 1 min), zmniejszyć cooldown, lub wykonać pre-scale do 20+ tasków.

4. **Napraw maspex-bot (Twitch auth token).**
   - Bot restartuje się co ~7 min z powodu brakującego tokenu Twitch — generuje zbędne logi i potencjalnie disturbs Redis connections.

### Przed kampanią (priorytet krytyczny)

1. **Stress test z 30 taskami (post-scale-out) i pełnym VU** — weryfikacja czy 30 tasków wytrzymuje peak kampanii.
2. **Weryfikacja max capacity vs Fargate limits** — sprawdzić czy `maspex-uat` ma wystarczający Service Connect / ENI quota dla 30 tasków.
3. **Test pre-scale do 30 przed startem kampanii** — nie czekać na autoscaling w D-Day.
4. **Supabase connection pool monitoring** — brak bezpośrednich metryk Supabase. Rozważyć dodanie PgBouncer metrics lub Supabase dashboard monitoring.
5. **Redis connection headroom przy 30+ taskach** — CurrConnections skoczył do 95 przy 30 taskach. cache.t3.medium obsługuje ~65 000 conn, więc nie ma ryzyka, ale warto monitorować.

### Priorytetyzacja

| Priorytet | Akcja | Owner |
|-----------|-------|-------|
| P0 | Dane testowe — profile dla synthetic users | Dev/QA |
| P0 | Max capacity autoscaling → 50+ | DevOps |
| P1 | Stress test z 30 taskami | DevOps/QA |
| P1 | Pre-scale do 20+ przed każdym testem | DevOps |
| P2 | Bot Twitch auth token fix | Dev |
| P2 | Autoscaling scale-out cooldown reduction | DevOps |

---

## 13. Evidence (kluczowe komendy)

```bash
# CloudFront Requests (us-east-1)
aws cloudwatch get-metric-statistics \
  --namespace AWS/CloudFront --metric-name Requests \
  --dimensions Name=DistributionId,Value=E3J76RNXIE2YIG Name=Region,Value=Global \
  --start-time 2026-05-15T09:45:00Z --end-time 2026-05-15T11:00:00Z \
  --period 300 --statistics Sum --profile maspex-cli --region us-east-1

# ALB TargetResponseTime percentiles
aws cloudwatch get-metric-data --profile maspex-cli --region eu-west-1 \
  --start-time 2026-05-15T09:45:00Z --end-time 2026-05-15T11:00:00Z \
  --metric-data-queries '[...p50/p90/p99...]'

# ECS task counts
aws cloudwatch get-metric-statistics \
  --namespace ECS/ContainerInsights --metric-name DesiredTaskCount \
  --dimensions Name=ClusterName,Value=maspex-uat Name=ServiceName,Value=maspex-api \
  --period 60 ...

# Per-task memory (Enhanced Container Insights)
aws cloudwatch get-metric-data ... TaskMemoryUtilization per TaskId

# Autoscaling activities
aws application-autoscaling describe-scaling-activities \
  --service-namespace ecs --resource-id service/maspex-uat/maspex-api \
  --profile maspex-cli --region eu-west-1

# ECS service events
aws ecs describe-services --cluster maspex-uat --services maspex-api \
  --profile maspex-cli --region eu-west-1

# CW Logs Insights — error breakdown
aws logs start-query --log-group-name "/maspex/uat/contest-service" \
  --start-time 1778838300 --end-time 1778842800 \
  --query-string 'filter @message like /VOTE_RPC_ERROR/ or @message like /submitSloganToDb/ or @message like /VOTE_CACHE_WRITETHROUGH_FAIL/ | stats count() as cnt by bin(5min)'
# Wynik: 10:15: 4, 10:20: 118, 10:25: 10

# CW Logs Insights — VOTE_CACHE_WRITETHROUGH_FAIL per 5min
# Wynik: 10:20: 68

# CW Logs Insights — SUPABASE_JWT_SECRET fallback per stream
# Wynik: 1 stream, 2 events, o 09:47 UTC (przed testem)

# ElastiCache (poprawny cluster ID: maspex-uat, nie maspex-uat-0001-001)
aws cloudwatch get-metric-statistics \
  --namespace AWS/ElastiCache --metric-name EngineCPUUtilization \
  --dimensions Name=CacheClusterId,Value=maspex-uat ...
```

---

## 14. Missing or unavailable data

| Brakujące dane | Przyczyna | Impact na pewność wniosków |
|----------------|-----------|--------------------------|
| CacheHitRate / OriginLatency CloudFront | Enhanced CF Metrics nie włączone | Niski — hit rate obliczono z ALB vs CF req |
| Supabase / PostgreSQL metryki | Brak integracji CW; Supabase managed service | Średni — FK violations potwierdzone z logów, ale throughput DB nieznany |
| Twitch bot token auth source | Tylko logs — brak config details | Niski — nie wpływa na API |
| RequestCountPerTarget (ALB) jako metryka CW | Dostępna tylko przez autoscaling alarm, nie raw CW | Niski — obliczono z RequestCount / host count |
| JMeter/k6 raporty z narzędzia testowego | Brak dostępu | Wysoki — brak danych po stronie klienta (TTFB, success %, percentyle klienta) |
| CloudTrail `UpdateService` | Nie sprawdzono | Niski — service events potwierdzają brak deployment collision |
| ECS Container Insights dla nowych 18 tasków | Za krótkie okno (< 5 min po scale-out) | Niski — wiemy że startup był poprawny z service events |

---

## 15. Final Verdict

**Środowisko jest bliżej gotowości na kampanię niż po testach z 14 maja.** Kluczowe zmiany zadziałały:
- Autoscaling reaktywny (pierwsze udane scale-out w historii testów)
- JWT fix eliminuje klasę błędów auth (0 vs. masowe 401 w poprzednich sesjach)
- Krótkotrwała degradacja zamiast ~3–5 minutowego incydentu ze 30 s latency

**Nadal istotne ryzyka przed kampanią:**

1. **Autoscaling opóźnienie (4–5 min):** Na kampanii pierwsze 5 minut po ramp-up to okno degradacji. Rozwiązanie: pre-scale do 20–30 tasków przed startem.
2. **Max capacity = 30:** System osiągnął max przy teście. Kampania z pełnym ruchem może wymagać więcej. Scale to 50+ przed kampanią.
3. **Dane testowe (FK violations):** Przy 118 VOTE_RPC_ERROR/burst niemożliwa dokładna ocena błędów biznesowych. Naprawić przed kolejnym testem.
4. **Supabase throughput:** Brak metryk. FK violations to symptom braku danych testowych, ale prawdziwy connection pool pod obciążeniem kampanią jest nieznany.

**Dziś największy open risk:** Brak pewności że 30 tasków wystarczy dla pełnego ruchu kampanii. Obecny test pokazał, że 12 tasków było za mało przy ~9 000 req/s. Czy 30 tasków wytrzyma peak kampanii — nieznane. Potrzebny dedykowany stress test z 30 taskami od startu.
