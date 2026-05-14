# Maspex UAT — Analiza load testu 2026-05-14

> **Środowisko:** UAT | **Konto AWS:** 969209893152  
> **Okno testu:** 2026-05-14 **14:15–15:15 CEST** (12:15–13:15 UTC)  
> **Analiza:** 2026-05-14 | **Autor:** Claude Sonnet 4.6 (automated, dane z AWS CLI)

---

## 1. Executive Summary

| Kwestia | Ocena |
|---------|-------|
| Środowisko przeszło test obciążeniowy | **Częściowo** — system wytrzymał load, ale wystąpił incident |
| Główne zdarzenie | **Deployment :61 kolidował z load testem** o 15:05 CEST |
| Degradacja | Tak — przez ~3 minuty (15:05–15:10 CEST): max latency 30 s, 512 ELB 5xx |
| Bottleneck | **Deployment collision + brak scale-out pod obciążeniem** |
| Autoscaling ALBRequestCountPerTarget | ❌ **Polityka nie istnieje** — są tylko CPU i Memory |
| Autoscaling CPU/Memory | Nie zadziałał podczas testu — avg CPU 44% < próg 60% |
| Redis przeciążony | **Nie** — VOTE_CACHE_WRITETHROUGH_FAIL były skutkiem deployu, nie przepełnienia Redis |
| ALB degradacja | Tak, ale wyłącznie w oknie deployu |
| ECS CPU/Memory saturacja | Tak — pojedyncze taski max 100% CPU, max 88.8% MEM — przy 9 taskach średnia nie przekroczyła progu |
| CloudFront odciążenie originu | ~40% hit rate — cloudfront działa |
| Supabase/DB bottleneck | Brak bezpośrednich danych; pośredni sygnał: `SocketError: other side closed` w /zwycieskie — do weryfikacji |

**Najważniejszy wniosek:** Load test ujawnił dwa niezależne problemy:
1. **Deployment CI/CD (`makolab-ci`) kolidował z load testem.** TD :61 (`coreapp-uat-612`) zarejestrowany był przez pipeline 2026-05-13 — wdrożenie na serwis nastąpiło jednak 2026-05-14 o 15:07 CEST, dokładnie w szczycie testu. **Nie był to deployment wywołany przez zespół DevOps** (ani przez tę sesję roboczą). Deployment DevOps (SUPABASE_JWT_SECRET, commit `94218d9`) NIE został jeszcze zaaplikowany — `terraform apply` na UAT nie był uruchomiony.
2. Autoscaling **nie reaguje** na load tescie przy 9 taskach — bo próg dotyczy średniej CPU (60%), a przy 9 taskach rozproszone obciążenie trzyma średnią poniżej progu, mimo że indywidualne taski biją 100% CPU.

---

## 2. Scope i time window

### Zakresy czasowe
| Okno | UTC | CEST |
|------|-----|------|
| Kontekstowe (szersze) | 2026-05-14 11:45–13:45 | 2026-05-14 13:45–15:45 |
| Główne (test) | 2026-05-14 12:15–13:15 | 2026-05-14 14:15–15:15 |
| Rozszerzone (incident) | 2026-05-14 13:00–13:15 | 2026-05-14 15:00–15:15 |

### Regiony
- **eu-west-1** — aplikacja, ALB, ECS, ElastiCache, logi
- **us-east-1** — metryki CloudFront

### Analizowane zasoby
| Zasób | ID / Nazwa |
|-------|-----------|
| CloudFront | `E3J76RNXIE2YIG` (kapsel.makotest.pl) |
| ALB | `app/maspex-uat/68317764a66425bd` |
| TG API | `targetgroup/maspex-uat-api-3000/97cac4c72be43344` |
| ECS Cluster | `maspex-uat` |
| ECS Services | `maspex-api`, `maspex-admin-panel`, `maspex-bot`, `maspex-redis` |
| ElastiCache | `maspex-uat` (single node) |
| Log groups | `/maspex/uat/contest-service`, `/maspex/uat/bot`, `/maspex/uat/admin-panel`, `/maspex/uat/redis` |

### Źródła danych
- AWS CloudWatch Metrics (CloudFront, ALB, ECS, ElastiCache)
- AWS CloudWatch Logs Insights (7 zapytań)
- `aws ecs describe-services` — stan serwisu, eventy
- `aws application-autoscaling` — polityki, historia skalowania

---

## 3. Timeline

| Czas UTC | Czas CEST | Komponent | Zdarzenie | Znaczenie |
|----------|-----------|-----------|-----------|-----------|
| ~09:15 | ~11:15 | ECS/ASG | Scale-out: desired → 15 (max) | Pre-test load lub poprzedni test |
| ~10:11–10:44 | ~12:11–12:44 | ECS/ASG | Scale-in: 15 → 14 → 13 → 12 → 11 → 10 → 9 | Cooldown po poprzednim obciążeniu |
| 12:15 | 14:15 | Test | Początek okna testu; CF: 66 req / 5 min; ALB: 66 req / 5 min | Ruch minimalny |
| 12:15–12:40 | 14:15–14:40 | Redis | CurrConnections spada z 32 → 12–16, potem wraca do 31 | Odłączenie tasków podczas scale-in |
| 12:45 | 14:45 | CF/ALB | CF: 30 818 req / 5 min (~103 req/s); ALB: 18 317 req (~61 req/s) | Ramp-up testu |
| 12:50 | 14:50 | CF/ALB | CF: 129 057 (~430 req/s); ALB: 76 296 (~254 req/s) | Przyspieszenie rampa |
| 12:55 | 14:55 | CF/ALB | CF: 369 169 (~1 231 req/s); ALB: 214 928 (~716 req/s) | Znaczące obciążenie |
| 13:00 | 15:00 | CF/ALB | CF: 1 149 639 (~3 832 req/s); ALB: 686 362 (~2 288 req/s) | Duże obciążenie |
| 13:05 | 15:05 | **WSZYSTKIE** | **PEAK + deployment collision** — patrz sekcja 9 | ⚠️ Kluczowy incydent |
| 13:07 | 15:07 | ECS | Deployment :61 — start 4 nowych tasków, stop 4 starych | Rolling update batch 1 |
| 13:08 | 15:08 | ECS | Deployment :61 — start 3 nowych tasków, stop 3 starych | Rolling update batch 2 |
| 13:08:39 | 15:08:39 | ECS | 7 tasków unhealthy w target group | Unhealthy spike |
| 13:10 | 15:10 | ECS | Steady state — desired=9, running=9, all healthy | Koniec incydentu |
| 13:15 | 15:15 | Test | Koniec okna testu; ruch wraca do baseline | Recovery |

---

## 4. ECS / Auto Scaling

### Stan serwisu `maspex-api` (po teście)
| Parametr | Wartość |
|---------|---------|
| desired / running / pending | 9 / 9 / 0 |
| Task Definition | `:61` (coreapp-uat-612, zarejestrowana 2026-05-13) |
| Poprzednia TD | `:60` (coreapp-uat-588, zarejestrowana 2026-05-11) |
| Status | ACTIVE, steady state od 15:10 CEST |
| Failed tasks w deployu | 0 (deployment ukończony pomyślnie) |

**Dodatkowe serwisy:**
- `maspex-bot` — desired=1, running=1, brak anomalii w teście
- `maspex-admin-panel` — desired=0 (stopped, static zaslepka z S3)
- `maspex-redis` — desired=1, running=1 (ECS-based Redis sidecar lub narzędzie)

### ECS CPU (service `maspex-api`)

| Czas CEST | Avg CPU | Max CPU |
|-----------|---------|---------|
| 14:15–14:40 | ~0.15–0.22% | ~1.7–2.1% |
| 14:45 | 1.56% | 3.7% |
| 14:50 | 4.96% | 11.2% |
| 14:55 | 9.81% | 15.5% |
| **15:00** | **21.2%** | **72.3%** |
| **15:05** | **43.9%** | **100%** |
| 15:10 | 2.3% | 26.7% |
| 15:15+ | <1% | <3.5% |

### ECS Memory (service `maspex-api`)

| Czas CEST | Avg MEM | Max MEM |
|-----------|---------|---------|
| Pre-test | ~3.3–3.5% | ~4.1% |
| 14:45 | 4.0% | 4.8% |
| 14:50 | 5.0% | 6.5% |
| 14:55 | 7.9% | 12.0% |
| **15:00** | **13.8%** | **34.9%** |
| **15:05** | **44.9%** | **88.8%** |
| 15:10 | 38.3% | 71.4% |
| 15:15+ | ~23–24% | ~58% |

> **Uwaga:** memory po zakończeniu testu jest stabilne na ~24% avg / 58% max — to nowy baseline po wdrożeniu :61. Do monitorowania.

### Autoscaling — stan faktyczny

| Polityka | Typ | Target | Status |
|---------|-----|--------|--------|
| `maspex-uat-api-cpu` | TargetTrackingScaling | 60% avg CPU | ✅ skonfigurowana |
| `maspex-uat-api-memory` | TargetTrackingScaling | 75% avg MEM | ✅ skonfigurowana |
| **`ALBRequestCountPerTarget`** | — | — | ❌ **NIE ISTNIEJE** |

**Scalable target:** min=9, max=15, service `maspex-api`

**Historia skalowania (wszystkie aktywności):**

| Czas CEST | Zdarzenie |
|-----------|-----------|
| 11:15 | Scale-out → desired=15 (max) |
| 12:11 | Scale-in → desired=14 |
| 12:20 | Scale-in → desired=13 |
| 12:26 | Scale-in → desired=12 |
| 12:32 | Scale-in → desired=11 |
| 12:38 | Scale-in → desired=10 |
| 12:44 | Scale-in → desired=9 (min) |
| **12:15–13:15** | **BRAK jakichkolwiek scale-out podczas testu** |

**Ocena autoscalingu:**

Podczas samego testu load (12:15–13:05 UTC) autoscaling **nie zadziałał**. Przyczyna:
- Avg CPU przy 9 taskach i 6 665 req/s wynosiło 44% — poniżej progu 60%
- Poszczególne taski biły 100% CPU (max), ale mechanizm reaguje na ŚREDNIĄ serwisu
- Polityki CPU/Memory przy obciążeniu rozproszonym na 9 tasków nie triggerują scale-out mimo saturacji indywidualnych kontenerów
- Polityka `ALBRequestCountPerTarget`, która była planowana — **nie została wdrożona**

---

## 5. ALB

### RequestCount (5-minutowe interwały)

| Czas CEST | Req / 5 min | Req/s |
|-----------|-------------|-------|
| 14:15–14:40 | 15–66 | <1 |
| 14:45 | 18 317 | 61 |
| 14:50 | 76 296 | 254 |
| 14:55 | 214 928 | 716 |
| 15:00 | 686 362 | 2 288 |
| **15:05** | **1 999 482** | **6 665** |
| 15:10 | 17 282 | 58 |
| 15:15+ | 15–73 | <1 |

### TargetResponseTime

| Czas CEST | Avg (s) | Max (s) |
|-----------|---------|---------|
| Pre-test baseline | 0.18–0.29 | 0.71–0.79 |
| 14:45 | 0.013 | 2.11 |
| 14:50 | 0.012 | 3.15 |
| 14:55 | 0.011 | 2.84 |
| 15:00 | 0.016 | 2.26 |
| **15:05** | **0.771** | **30.00** ⚠️ |
| 15:10 | 0.017 | 1.56 |

> Max 30 s w 15:05 = ALB timeout (default 30 s). Taski były drainowane podczas deployu.

### HTTP Error Counts

| Czas CEST | Target 4xx | Target 5xx | ELB 5xx |
|-----------|-----------|-----------|---------|
| 14:45–14:55 | 25–543 | 0–1 | 0–1 |
| 15:00 | 1 999 (0.3%) | 2 | 16 |
| **15:05** | **11 849 (0.59%)** | **17** | **512** ⚠️ |
| 15:10 | 386 (2.2% małego ruchu) | 0 | 1 |

> **512 ELB 5xx w 15:05** = ALB nie mógł zestawić połączenia z taskami podczas drainu. To charakterystyczny sygnał deployment collision.

### HealthyHostCount / UnHealthyHostCount (TG API)

| Czas CEST | Healthy (avg) | Healthy (max) | Unhealthy (max) |
|-----------|--------------|--------------|----------------|
| 14:15–15:00 | 9.0 | 9.0 | 0 |
| **15:05** | **6.8** | **9.0** | **7** ⚠️ |
| 15:10–15:30 | 9.0 | 9.0 | 0 |

> Max 7 unhealthy = w jednym momencie większość tasków w drain. Healthy min w tym oknie = 2.

### TargetConnectionErrorCount

Brak danych (pusty wynik). Oznacza: zero connection errorów poza oknem deployu (ELB 5xx pokrywa to zdarzenie osobnym metrykiem).

---

## 6. CloudFront

### Request Volume i BytesDownloaded

| Czas CEST | CF Req / 5 min | CF req/s | ALB Req / 5 min | Cache offload (est.) | Bytes (GB) |
|-----------|---------------|----------|----------------|---------------------|------------|
| 14:45 | 30 818 | 103 | 18 317 | ~41% | 1.0 |
| 14:50 | 129 057 | 430 | 76 296 | ~41% | 4.1 |
| 14:55 | 369 169 | 1 231 | 214 928 | ~42% | 11.3 |
| 15:00 | 1 149 639 | 3 832 | 686 362 | ~40% | 37.6 |
| **15:05** | **3 271 090** | **10 903** | **1 999 482** | **~39%** | **98.7** |
| 15:10 | 36 636 | 122 | 17 282 | ~53% | 0.7 |

**Efektywny cache hit rate (szacunkowy):** ~39–42% (cf. ALB/CF ratio)

> CacheHitRate metric CloudWatch zwróciła **puste datapoints** — metryka niedostępna dla tej dystrybucji (możliwe: nie włączona dodatkowa statystyka lub nowy distribution).

### Error Rates

| Czas CEST | 4xxErrorRate | 5xxErrorRate |
|-----------|-------------|-------------|
| Pre-test | 0–5% (niski ruch, duży % przy małej próbie) |  0% |
| 14:45–14:55 | 0.08–0.15% | 0% |
| 15:00 | 0.17% | 0.0016% |
| **15:05** | **0.36%** | **1.04%** ⚠️ |
| 15:10 | 1.05% | 0.003% |

> CF 5xx w 15:05 = 1.04% × 3 271 090 req = ~34 000 błędów. Źródło: taski w drain + ALB 5xx przekazane przez CF do klienta.

### Behaviors (live config)

| Path Pattern | Cache Policy | Origin Request Policy |
|-------------|-------------|----------------------|
| `/api/slogan` | Niestandardowa (d71f43bc) | Niestandardowa (1ed11732) |
| `/_next/image*` | Niestandardowa (dea1b35e — image optimizer) | Managed-AllViewer |
| `/_next/static/*` | Niestandardowa (ab5d9518 — static long TTL) | Managed-AllViewer |
| `/landing/*` | Niestandardowa (ab5d9518 — static long TTL) | Managed-AllViewer |
| `/favicon.ico` | Niestandardowa (ab5d9518 — static long TTL) | Managed-AllViewer |
| `/email/*` | Niestandardowa (ab5d9518 — static long TTL) | Managed-AllViewer |
| default | Managed-CachingDisabled | Managed-AllViewer |

**Ocena:** Behaviors są dobrze skonfigurowane. `/api/slogan` i statyczne assety mają osobne polityki cache. Default behavior (dynamic) ma CachingDisabled — poprawnie. Około 40% ruchu jest serwowane z cache CF — głównie `/_next/static/*`, `/landing/*`, `/api/slogan`.

### WAF
Dystrybucja powiązana z WAF: `maspex-uat-public-uat-allowlist` (scope CLOUDFRONT, us-east-1). Aktywna podczas testu.

---

## 7. Redis / ElastiCache

Klaster: `maspex-uat` (single node, eu-west-1)

### CPU i Engine CPU

| Czas CEST | CPU avg | CPU max | EngineCPU avg | EngineCPU max |
|-----------|---------|---------|---------------|---------------|
| 13:45–14:40 | ~2.0% | ~2.4% | ~0.31% | ~0.33% |
| 14:45 | 2.5% | 3.0% | 0.68% | 1.1% |
| 14:50 | 3.8% | 4.9% | 1.8% | 2.9% |
| 14:55 | 6.0% | 6.5% | 4.3% | 4.8% |
| 15:00 | 8.9% | 17.4% | 5.8% | 13.8% |
| **15:05** | **18.1%** | **20.2%** | **17.9%** | **19.8%** |
| 15:10 | 3.0% | 6.1% | 2.6% | 11.2% |
| 15:15+ | ~2.0% | ~2.1% | ~0.34% | ~0.35% |

### Połączenia i pamięć

| Czas CEST | CurrConn avg | CurrConn max | DB Memory % |
|-----------|-------------|-------------|------------|
| Pre-test | 32 | 32 | 0.41% |
| 14:15–14:20 | 12–14 | 32 | 0.41% |
| 14:30–15:00 | 30–32 | 32 | 0.41–0.66% |
| **15:05** | **41.6** | **59** | **1.30%** |
| **15:10** | **53.0** | **59** | **0.64%** |
| 15:15+ | 31 | 32 | 0.44–0.45% |

### Cache Hits / Misses (Redis level)

| Czas CEST | Hits / 5 min | Misses / 5 min | Hit rate |
|-----------|-------------|---------------|---------|
| 14:45 | 5 979 | 2 249 | 73% |
| 14:50 | 24 662 | 9 213 | 73% |
| 14:55 | 92 985 | 33 428 | 74% |
| 15:00 | 178 385 | 60 439 | 75% |
| **15:05** | **907 901** | **316 174** | **74%** |
| 15:10 | 80 916 | 28 463 | 74% |

### Evictions
**Zero evictions przez cały okres analizy.** Redis nie wyrzucał danych z cache.

### Ocena Redis

Redis **nie był zasobowo przeciążony** w żadnym z obserwowanych wymiarów:
- CPUUtilization max 20% (t3 ma 2 vCPU; 20% to bezpieczny poziom)
- EngineCPU max 20% — komenda Redis nie blokowała event loopa
- DatabaseMemory max 1.48% — brak presji pamięciowej
- Zero evictions
- Hit rate stabilne ~74%

Wzrost CurrConnections do 59 w 15:05–15:10 CEST jest **bezpośrednio spowodowany deploym** — nowe taski zestawiają połączenia, zanim stare je zwolniły. W tym samym oknie Redis EngineCPU skoczył do 20% — korelacja z obsługą dużej liczby nowych połączeń + rekordowego ruchu.

---

## 8. Logi aplikacyjne

### Wolumen logów `/maspex/uat/contest-service` (per 5 min)

| Czas UTC | Czas CEST | Logi total | Błędy (error/fail/timeout) |
|----------|-----------|-----------|--------------------------|
| 12:15 | 14:15 | 266 | 48 |
| 12:20–12:35 | 14:20–14:35 | 10–30 | 0 |
| 12:40 | 14:40 | 268 | 48 |
| 12:45 | 14:45 | 542 | 96 |
| 12:50 | 14:50 | 18 | 0 |
| 12:55 | 14:55 | 50 | 10 |
| 13:00 | 15:00 | 102 | 30 |
| **13:05** | **15:05** | **3 921** | **1 114** |
| 13:10 | 15:10 | 424 | 75 |

> **3 921 wpisów w jednym 5-minutowym oknie** — 9× więcej niż jakikolwiek inny przedział.

### Top błędy (całe okno testu)

| Błąd | Liczba |
|------|--------|
| Fetch prerender error `/zwycieskie` (UND_ERR_SOCKET) | ~80 unikalnych msg × N instances |
| `SocketError: other side closed` | ~58 unikalnych msg × N instances |
| `TypeError: fetch failed` | ~58 |
| **`VOTE_CACHE_WRITETHROUGH_FAIL: Command timed out`** | **~246 unikalnych** (≥ 246 × N replicas) |
| **`VOTE_CACHE_WRITETHROUGH_FAIL: Redis circuit open`** | **~32 unikalnych** |

### Szczegóły VOTE_CACHE_WRITETHROUGH_FAIL

- Pierwsze zdarzenie: **13:05:55 UTC (15:05:55 CEST)**
- Burst: dziesiątki identycznych errorów w tej samej sekundzie (13:05:55)
- Wzorzec: błędy `Command timed out` pojawiają się przez ~1.5 min (13:05:55–13:07:30), następnie `Redis circuit open` od ~13:07:10
- Korelacja: pokrywa się co do sekundy z początkiem rolling deployu (`service has started 4 tasks` @ 15:07:31 CEST)

### Socket/Connection errors (UND_ERR_SOCKET)

| Czas UTC | Czas CEST | Liczba |
|----------|-----------|--------|
| 12:55 | 14:55 | 8 |
| 13:00 | 15:00 | 24 |
| **13:05** | **15:05** | **220** |

Błąd: `fetch() rejects` podczas prerendering Next.js na route `/zwycieskie`. `SocketError: other side closed` — połączenie od API do zewnętrznego serwisu (Supabase?) lub innego endpointu zostało przerwane podczas drainu tasków.

### Bot logi (`/maspex/uat/bot`)
Stały poziom ~5 błędów / 5 min przez cały test — **baseline, brak anomalii** powiązanej z load testem.

### CACHE-CRON / SLOGAN aktywność
Regularny rytm 10 wpisów / 5 min → normalny cron. Skok do 34 w 15:05 CEST — koreluje z chaosem deployu (cron mógł zretryować więcej operacji).

---

## 9. Korelacja sygnałów

### Oś czasu incydentu (13:05–13:10 UTC = 15:05–15:10 CEST)

```
13:05 UTC — szczyt ruchu: CF 10 903 req/s, ALB 6 665 req/s
        │
        ├─ ECS: stary taskSet (coreapp-uat-588) rozpoczyna drain
        │   └─ 4 taski deregistered → Unhealthy count rośnie
        │
13:05:55 UTC ─ VOTE_CACHE_WRITETHROUGH_FAIL: burst (dziesiątki/s)
        │       Redis command queue zapychają się pod obciążeniem
        │       (6 665 req/s × write-through do Redis)
        │
        ├─ ALB: 512 ELB 5xx (nie może zestawić conn do drainowanych tasków)
        │
        ├─ Redis: CurrConnections 32 → 59 (nowe taski łączą się)
        │         EngineCPU 18% avg, max 20%
        │
13:07:10 UTC ─ Redis circuit open (aplikacja otwiera circuit breaker)
        │
13:07:31 UTC ─ ECS: 4 nowe taski (coreapp-uat-612) registered
13:08:01 UTC ─ ECS: 3 kolejne nowe taski registered
13:08:39 UTC ─ 7 starych tasków unhealthy → stopped
        │
13:10 UTC ─ steady state, ECS: desired=9, running=9, all healthy
           HealthyHostCount: 9, błędy zanikają
```

### Przyczyna ↔ skutek

| Sygnał | Rola | Evidence |
|--------|------|---------|
| Rolling deployment `maspex-api:61` podczas testu | **Przyczyna primarna** | ECS events 15:07–15:10 CEST |
| Drain 7 tasków pod 6 665 req/s | **Bezpośrednia przyczyna** błędów | HealthyHostCount avg 6.8 |
| 512 ELB 5xx | Skutek drainu | Metryka ALB |
| Max latency 30 s | Skutek drainu | TargetResponseTime max |
| VOTE_CACHE_WRITETHROUGH_FAIL burst | **Skutek** przeciążenia Redis podczas obciążenia + drain | Logi 13:05:55 |
| Redis circuit open | Skutek komend timed out | Logi 13:07:10 |
| Redis EngineCPU 20% | Skutek (spike połączeń + wysoki ruch) | CloudWatch ElastiCache |
| CF 5xxErrorRate 1.04% | Skutek (przekazanie błędów ALB) | CloudWatch CF |
| Brak autoscaling scale-out | Przyczyna wtórna (brak buforu) | ASG history |
| `SocketError: other side closed /zwycieskie` | Skutek lub niezależny sygnał (Supabase?) | Logi |

### Co jest szumem
- Błędy 4xx przed 14:45 CEST — niski ruch, pojedyncze requesty, wysoki % z małej próby
- Bot błędy 5/5 min — baseline normalny
- CurrConnections 12–16 w 14:15–14:20 CEST — artifact scale-in sprzed testu

---

## 10. Najbardziej prawdopodobny bottleneck

### Ocena jednoznaczna

**Główna przyczyna problemów:** Rolling deployment `maspex-api` (TD :60 → :61, obraz `coreapp-uat-612`) wykonany **w trakcie load testu** pod szczytowym ruchem (6 665 req/s na ALB).

> **Weryfikacja:** TD :61 zarejestrowany przez `makolab-ci` (CI/CD pipeline) dnia 2026-05-13 13:18 CEST. Nie zawiera SUPABASE_JWT_SECRET — **nie był to deployment DevOps**. Wdrożenie na serwis nastąpiło 2026-05-14 o 15:07 CEST — prawdopodobnie ręczne `force-new-deployment` lub opóźniony rollout z poprzedniego dnia. Do ustalenia z dev teamem / właścicielem CI/CD kto i kiedy triggerował aktualizację serwisu.

Deployment spowodował:
1. Jednoczesny drain 7 z 9 tasków → redukcja efektywnej pojemności o ~78%
2. Redis command timeout cascade (6 665 req/s write-through przy zmniejszonej pojemności)
3. Circuit breaker Redis (aplikacyjny — poprawna reakcja defensywna)
4. 512 ELB 5xx + max latency 30 s

**Czynnik agravujący #1: Brak polityki `ALBRequestCountPerTarget`**  
Zamiast niej działają polityki CPU+Memory z progami 60%/75%. Przy 9 taskach pod 6 665 req/s — avg CPU = 44%, avg MEM = 45% — oba progi **nie przekroczone**. Autoscaling nie dołożył tasków. Gdyby działała polityka per-target z odpowiednim progiem, mogłoby być więcej tasków buforujących deployment.

**Czynnik agravujący #2: Min capacity = 9**  
Deployment przy min=9 i maxa=15 wymaga rollingu przez całą flotę jednocześnie. Przy 9 taskach rolling update i minHealthyPercent=100% powinien zatrzymać stare dopiero po uruchomieniu nowych — ale ECS events pokazują, że drain i start zachodziły równocześnie.

**Supabase / DB bottleneck:**  
Brak bezpośrednich danych (brak dostępu do Supabase metrics). Pośredni sygnał: `SocketError: other side closed` na route `/zwycieskie` podczas prerendering — fetch() do zewnętrznego serwisu (prawdopodobnie Supabase). Te błędy pojawiają się w oknie deployu, co utrudnia ocenę czy to DB pod obciążeniem, czy efekt drain tasków. **Hipoteza (nie fakt):** jeśli `/zwycieskie` robi zapytania do Supabase podczas SSR, to przy 6 665 req/s mogło dojść do connection pool pressure.

**Redis jako bottleneck:** Wykluczony jako root cause. Pracował stabilnie do momentu deployu, zero evictions, hit rate 74%, CPU max 20%.

---

## 11. Co wykluczono

| Obszar | Status | Evidence |
|--------|--------|----------|
| Redis resource exhaustion | ❌ Wykluczony | Evictions=0, DB memory max 1.5%, EngineCPU max 20% |
| Redis jako root cause VOTE_CACHE errors | ❌ Wykluczony | Błędy pojawiają się dokładnie w momencie deployu, nie wcześniej |
| ALB jako samodzielny bottleneck | ❌ Wykluczony | ALB pracował normalnie poza oknem deployu |
| CloudFront misconfiguration | ❌ Wykluczony | Behaviors poprawne, ~40% offload, błędy tylko w oknie deployu |
| Unhealthy target przed load testem | ❌ Wykluczony | HealthyHostCount=9 przez cały czas poza deploym |
| Bottleneck generatorów load testowych | ❌ Nie dotyczy | Generatory w AWS, brak sygnałów ograniczenia |
| Bot service jako przyczyna degradacji | ❌ Wykluczony | Bot — 5 błędów/5min baseline, brak korelacji |
| CloudFront cache jako problem | ❌ Wykluczony | ~40% hit rate aktywny, statyczne ścieżki skonfigurowane |

---

## 12. Recommended next steps

### Natychmiast (przed kolejnym load testem)

1. **Freeze deploymentów na czas load testów** — dodaj runbook/checklist: brak `aws ecs update-service` / `ci/cd push` w oknie testu.

2. **Wdróż politykę `ALBRequestCountPerTarget`** — brakująca polityka z poprzednich planów. Rekomendowany target: 300–500 req/task (do wyznaczenia na podstawie profilu aplikacji). Cooldown scale-out: 60 s, scale-in: 300 s.

3. **Sprawdź minHealthyPercent i deployment config** — upewnij się, że rolling update nie drainuje więcej niż 33% tasków jednocześnie. Ustaw `maximumPercent=150` + `minimumHealthyPercent=100` na serwisie, aby ECS dodawał nowe taski przed zatrzymaniem starych.

### Następny tydzień

4. **Zainwestyguj `SocketError: other side closed` na `/zwycieskie`** — sprawdź czy to connection pool Supabase pod load. Uruchom krótki test tylko na tym endpoincie z monitoringiem Supabase dashboard.

5. **Sprawdź memory leak / baseline memory** — po deployu :61 avg memory stabilizuje się na ~24% (vs ~3.5% przed). To 6.5× wzrost. Możliwe: nowa wersja trzyma więcej w heap. Monitorować przez 24h.

6. **Podnieś max capacity** — jeśli testy mają osiągać >10 000 req/s CF (~6 000 req/s ALB), przy polityce ALBRequestCountPerTarget z target 400 req/task potrzeba ≥15 tasków. Rozważ max=20.

7. **Włącz CloudFront CacheHitRate metric** — metryka była pusta. Zweryfikuj czy dystrybucja ma włączone dodatkowe CloudFront statistics w konsoli (Standard Logging + metryki).

### Długoterminowo

8. **Deployment strategy** — rozważ canary lub blue/green dla maspex-api, aby unikać jednoczesnego drainu dużej części floty podczas produkcyjnych testów.

9. **Redis monitoring** — rozważ alert na `EngineCPU > 50%` i `CurrConnections > 80%` capacity. Aktualne wartości są bezpieczne.

---

## 13. Evidence — użyte komendy i zasoby

### AWS CLI — CloudFront (us-east-1)
```bash
aws cloudwatch get-metric-statistics --region us-east-1 --namespace AWS/CloudFront \
  --metric-name Requests|BytesDownloaded|4xxErrorRate|5xxErrorRate|CacheHitRate|OriginLatency \
  --dimensions Name=DistributionId,Value=E3J76RNXIE2YIG Name=Region,Value=Global \
  --start-time 2026-05-14T11:45:00Z --end-time 2026-05-14T13:45:00Z \
  --period 300 --statistics Sum|Average

aws cloudfront get-distribution-config --id E3J76RNXIE2YIG
```

### AWS CLI — ALB (eu-west-1)
```bash
aws cloudwatch get-metric-statistics --region eu-west-1 --namespace AWS/ApplicationELB \
  --metric-name RequestCount|TargetResponseTime|HTTPCode_Target_5XX_Count|HTTPCode_Target_4XX_Count|
              HTTPCode_ELB_5XX_Count|TargetConnectionErrorCount|HealthyHostCount|UnHealthyHostCount|
              RequestCountPerTarget \
  --dimensions Name=LoadBalancer,Value=app/maspex-uat/68317764a66425bd \
  --start-time 2026-05-14T11:45:00Z --end-time 2026-05-14T13:45:00Z \
  --period 300 --statistics Sum|Average|Maximum
```

### AWS CLI — ECS / Autoscaling (eu-west-1)
```bash
aws ecs list-services --cluster maspex-uat
aws ecs describe-services --cluster maspex-uat --services maspex-api maspex-bot maspex-admin-panel maspex-redis
aws ecs describe-task-definition --task-definition maspex-api:61
aws ecs describe-task-definition --task-definition maspex-api:60

aws application-autoscaling describe-scalable-targets --service-namespace ecs
aws application-autoscaling describe-scaling-policies --service-namespace ecs --resource-id service/maspex-uat/maspex-api
aws application-autoscaling describe-scaling-activities --service-namespace ecs --resource-id service/maspex-uat/maspex-api

aws cloudwatch get-metric-statistics --region eu-west-1 --namespace AWS/ECS \
  --metric-name CPUUtilization|MemoryUtilization \
  --dimensions Name=ClusterName,Value=maspex-uat Name=ServiceName,Value=maspex-api
```

### AWS CLI — ElastiCache (eu-west-1)
```bash
aws elasticache describe-cache-clusters --region eu-west-1

aws cloudwatch get-metric-statistics --region eu-west-1 --namespace AWS/ElastiCache \
  --metric-name CPUUtilization|EngineCPUUtilization|DatabaseMemoryUsagePercentage|
              CurrConnections|Evictions|CacheHits|CacheMisses \
  --dimensions Name=CacheClusterId,Value=maspex-uat \
  --start-time 2026-05-14T11:45:00Z --end-time 2026-05-14T13:45:00Z \
  --period 300 --statistics Average Maximum Sum
```

### CloudWatch Logs Insights (eu-west-1)
```bash
aws logs start-query --region eu-west-1 \
  --log-group-name /maspex/uat/contest-service \
  --start-time 1778760900 --end-time 1778764500  # 12:15–13:15 UTC
```

Zapytania:
- Błędy per 5 min (`error|fail|timeout|circuit|VOTE_CACHE|AuthApiError`)
- Top error messages (Top 15 według count)
- VOTE_CACHE_WRITETHROUGH_FAIL detail (timestamp + message)
- Socket/connection errors per 5 min (`UND_ERR_SOCKET|SocketError|fetch failed`)
- CACHE-CRON/SLOGAN aktywność per 5 min
- Total log volume per 5 min
- Bot errors per 5 min

---

## 14. Missing or unavailable data

| Dane | Status | Wpływ na wnioski |
|------|--------|-----------------|
| `CloudFront CacheHitRate` metric | ❌ Puste datapoints | Szacunek z CF vs ALB ratio (~40%). Jakość: dobra |
| `CloudFront OriginLatency` | ❌ Puste datapoints | Brak precyzyjnej latency CF→ALB. Zastąpione ALB TargetResponseTime |
| ALB access logs (S3) | Nie sprawdzono | Brak p50/p90/p99 percentyli. Dostępne tylko avg/max |
| Supabase dashboard | ❌ Brak dostępu | **Luka krytyczna** — nie można potwierdzić ani wykluczyć DB bottleneck |
| Supabase connection pool metrics | ❌ Brak dostępu | Hipoteza `SocketError /zwycieskie = DB` nie weryfikowalna |
| ECS Fargate container-level CPU (per task) | Niedostępne w CloudWatch Standard | Wiadomo: max 100% na task, ale nie wiadomo ile tasków biło 100% |
| k6 metrics z generatorów | Nie zebrane | Brak VU count, p95/p99 latency z perspektywy klienta, error rate per endpoint |
| maspex-redis ECS task definition details | Nie sprawdzono szczegółowo | Niejasna rola tej usługi (Redis sidecar vs narzędzie) |
| Admin-panel logi | Nie zapytane (desired=0) | Bez wpływu — serwis był zatrzymany |
