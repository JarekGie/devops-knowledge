# Maspex UAT — Load Test Analysis — 2026-05-05 19:00 CEST

---

## 1. Executive Summary

Test był **trójfalowy, ~90 minut aktywnego ruchu**, z łącznym wolumenem prawie 3× większym niż test 12:00 CEST tego samego dnia. Środowisko **nie wykazało degradacji HTTP** — zero 5xx, doskonałe czasy odpowiedzi ALB, brak unhealthy hosts, brak task churn.

- **CloudFront** absorbował ~51% żądań przez caching statycznych assetów. Cały dynamiczny ruch (API) trafiał do ALB.
- **ALB/ECS** zachowały się bez zarzutu: avg response time 12–16 ms, p99 45–65 ms, zero 5xx przez cały test.
- **Autoscaling nie wyzwolił scale-out** — CPU avg peak 18.1% (próg 60%), memory peak avg 57% (próg 75%). MinCapacity=9 ustawione na stałe.
- **Redis write-through path był całkowicie uszkodzony przez cały test**: 924,582 błędów `VOTE_CACHE_WRITETHROUGH_FAIL` w 79 minutach. Błędy perfektnie korelują z falami ruchu. Redis infrastructure (CloudWatch) był zdrowy — problem jest app-level.
- **Memory climbing**: ze startu przy 17% (poziom potest-12:00) do 57% na koniec wave 3. Trend wzrostowy przez cały test, bez recovery między falami. Gdyby test trwał dłużej lub był 4. wave, memory zbliżyłaby się do progu autoscaling (75%).

**Najbardziej prawdopodobny bottleneck**: Ścieżka write-through Redis (`VOTE_CACHE_WRITETHROUGH`). Zerwanie połączenia Redis na początku testu otworzyło circuit breaker, który nie zamknął się przez cały test. Sprawność warstwy HTTP/ECS była dobra — problem nie wpływał na widoczność użytkownika, ale wszystkie zapisy do Redis cache były gubione.

---

## 2. Scope i time window

| Zakres | UTC | CEST |
|---|---|---|
| Planowane | 17:00–18:00 | 19:00–20:00 |
| Faktyczne (z pre-rampu i cooldown) | 16:55–18:25 | 18:55–20:25 |
| Wave 1 | 17:04–17:21 | 19:04–19:21 |
| Wave 2 | 17:29–17:51 | 19:29–19:51 |
| Wave 3 | 18:07–18:23 | 20:07–20:23 |

Źródła danych:

| Źródło | Status |
|---|---|
| ECS service state/events | zebrane |
| Application Auto Scaling targets/policies/activities | zebrane |
| CloudWatch metrics: ECS (CPU/Memory) | zebrane |
| CloudWatch metrics: ALB (RequestCount, ResponseTime, 4xx/5xx, UnHealthy) | zebrane |
| CloudWatch metrics: CloudFront (Requests, Bytes, 4xx/5xx, TotalError) | zebrane |
| CloudWatch metrics: ElastiCache (CPU, Memory, Connections, Evictions, Swap) | zebrane |
| CloudWatch Logs Insights: `/maspex/uat/contest-service` | zebrane |
| CloudWatch Logs Insights: `/maspex/uat/bot` | zebrane |
| ElastiCache Redis logs: `/aws/elasticache/maspex-uat/redis` | zebrane (0 eventów) |
| Application Auto Scaling activities | zebrane |

Zasoby:

| Obszar | Zasób |
|---|---|
| CloudFront | `E3J76RNXIE2YIG`, `kapsel.makotest.pl` |
| ALB | `app/maspex-uat/68317764a66425bd` |
| API Target Group | `targetgroup/maspex-uat-api-3000/97cac4c72be43344` |
| ECS cluster | `maspex-uat` |
| ECS services | `maspex-api`, `maspex-admin-panel`, `maspex-bot` |
| ElastiCache | `maspex-uat` (cache.t3.medium, Redis single-node) |

---

## 3. Timeline

| Timestamp UTC | CEST | Komponent | Zdarzenie | Znaczenie |
|---|---|---|---|---|
| 16:30–16:55 | 18:30–18:55 | ALB/CF | Baseline: 0 req/min | Środowisko idle przed testem |
| **16:55** | **18:55** | **App logs** | **Pierwsze `VOTE_CACHE_WRITETHROUGH_FAIL: Connection is closed`** | **Redis connection zerwane przed rampu-up** |
| **16:56** | **18:56** | **App logs** | **`Redis circuit open` — circuit breaker wyzwolony** | **Otworzył się ~1s po pierwszym błędzie** |
| 16:56 | 18:56 | ALB | 304 req/min — początek ramp-up | Niski ruch, circuit breaker już otwarty |
| 17:04 | 19:04 | CF/ALB | CF: 25,458 req/min; ALB: 12,415 req/min | Wave 1 — szybki ramp-up |
| **17:08** | **19:08** | **CF/ALB** | **CF: 70,072 req/min; ALB: 32,757 req/min** | **Wave 1 — pierwszy peak** |
| 17:09–17:13 | 19:09–19:13 | CF/ALB | CF/ALB dip (19:09–19:12), CF: 22k, ALB: 10k | Wave 1 dip / chwilowe zwolnienie |
| **17:14–17:20** | **19:14–19:20** | **CF/ALB** | **CF: 129k–154k req/min; ALB: 63k–76k req/min** | **Wave 1 burst — peak 17:15 UTC** |
| **17:15** | **19:15** | **CF/ALB/App** | **CF: 154,376 req/min; ALB: 75,867 req/min; Redis errors: ~28k/min** | **Wave 1 szczyt** |
| **17:15** | **19:15** | **ECS** | **CPU avg: 16.12%, max: 23.94%** | CPU daleko poniżej progu 60% |
| 17:21–17:25 | 19:21–19:25 | CF/ALB | Ruch spada do zera | Gap między wave 1 i wave 2 |
| 17:29–17:33 | 19:29–19:33 | CF/ALB | Ramp-up wave 2: CF: 6k–12k req/min | Wave 2 start |
| 17:38 | 19:38 | ALB | 33,030 req/min — wave 2 mid | Wave 2 buduje się |
| **17:45** | **19:45** | **CF/ALB/App** | **CF: 156,314 req/min; ALB: 76,360 req/min; Redis errors: ~28k/min** | **Wave 2 szczyt** |
| **17:47–17:50** | **19:47–19:50** | **ECS** | **Memory avg: 40.93–43.57%; CPU avg: 15–16%** | Memory przekroczyła 40% po raz pierwszy |
| 17:51–17:57 | 19:51–19:57 | CF/ALB | Ruch spada do zera | Gap między wave 2 i wave 3 |
| 17:51–17:55 | 19:51–19:55 | ECS | Memory avg: 43–44% — nie spada podczas gap | **Memory nie odzyskuje się między falami** |
| 18:07 | 20:07 | CF/ALB | Ramp-up wave 3: CF: 38k, ALB: 18k req/min | Wave 3 start |
| **18:18** | **20:18** | **CF/ALB** | **CF: 159,222 req/min; ALB: 76,785 req/min** | **ABSOLUTNY PEAK testu** |
| **18:18–18:21** | **20:18–20:21** | **ALB** | **4xx: 2,109–2,332/min; Response time avg: 14–16ms** | 4xx spika na peaku, latency nadal niska |
| **18:18–18:22** | **20:18–20:22** | **ECS** | **Memory avg: 50.90–56.74%; CPU avg: 17.5–15%** | **Memory przekracza 50% po raz pierwszy** |
| 18:23 | 20:23 | CF/ALB | Gwałtowny koniec wave 3; ruch spada do zera | Test zakończony |
| 18:23+ | 20:23+ | ECS | Memory zatrzymuje się na ~57%, CPU wraca do baseline | Memory nie odzyskuje po zakończeniu testu |

---

## 4. ECS / Auto Scaling

### Stan usług (snapshot po teście)

| Service | Desired | Running | Pending | Status |
|---|---:|---:|---:|---|
| `maspex-api` | 9 | 9 | 0 | ACTIVE, steady state |
| `maspex-admin-panel` | 1 | 1 | 0 | ACTIVE, steady state |
| `maspex-bot` | 1 | 1 | 0 | ACTIVE (health check failures 2026-05-06, niezwiązane) |

### Autoscaling

| Parametr | Wartość |
|---|---|
| Min capacity | 9 |
| Max capacity | 15 |
| CPU policy target | 60% (TargetTracking) |
| Memory policy target | 75% (TargetTracking) |
| Scale-out cooldown | 60s |
| Scale-in cooldown | 300s |
| Scale-out triggered? | **NIE** |

MinCapacity=9 ustawione `2026-04-28T08:46`. Jedyna historyczna aktywność autoscaling. Brak jakichkolwiek scale-out/scale-in events od tamtej pory.

**Dlaczego autoscaling nie wyzwolił:** CPU avg peak = 18.1% (próg 60%), Memory avg peak = 57% (próg 75%). Oba metryki poniżej progów. Memory zbliżyła się najbardziej — przy 4. fali lub dłuższym teście próg 75% byłby realnie zagrożony.

### maspex-api — CPU / Memory (kluczowe punkty)

| Timestamp CEST | CPU avg | CPU max | Memory avg | Memory max |
|---|---:|---:|---:|---:|
| 18:30–18:55 (baseline) | ~0.70% | ~0.93% | ~16.93% | ~17.48% |
| 19:08 (wave 1 peak 1) | 8.58% | 13.09% | ~19.5% | ~20.5% |
| **19:15 (wave 1 peak 2)** | **16.12%** | **23.94%** | **24.72%** | **26.47%** |
| 19:21 (wave 1 koniec) | 5.03% | 16.52% | 31.60% | 32.34% |
| 19:25 (gap 1) | 1.36% | 1.88% | 30.09% | 31.53% |
| **19:45 (wave 2 peak)** | **16.91%** | **30.17%** | **36.61%** | **38.71%** |
| 19:50 (wave 2 koniec) | 14.36% | 26.73% | 43.57% | 45.53% |
| 19:55 (gap 2) | 1.68% | 2.17% | 43.19% | 44.35% |
| **20:18 (wave 3 peak)** | **17.48%** | **28.56%** | **50.90%** | **53.45%** |
| **20:21 (wave 3 last peak)** | **18.12%** | **30.91%** | **55.64%** | **57.07%** |
| 20:23 (koniec) | 5.66% | 20.64% | 57.00% | 58.64% |
| 20:29+ (cooldown) | 2.29% | 3.37% | 55.81% | 56.86% |

**Kluczowa obserwacja memory:** Trend wyłącznie wzrostowy. CPU wraca do baseline natychmiast po każdej fali. Memory NIE wraca — akumuluje się przez cały test.

### maspex-bot — CPU

Skokowy profil ~co 7-8 minut (cron pattern). Brak korelacji z falami ruchu. Peak: 19:08 CEST avg=13.0%, max=51.97%. Niezwiązane z load testem.

### maspex-admin-panel

Praktycznie idle przez cały test (CPU <0.6%, Memory ~4.1%). Brak wpływu load testu.

### Task churn

Zero stopped tasks dla `maspex-api` i `maspex-admin-panel` w oknie testu. Brak health check failures, brak ECS replacements.

---

## 5. ALB

### Request volume (maspex-uat-api-3000, per-minute)

| Timestamp CEST | RequestCount/min |
|---|---:|
| 18:56 (pre-test) | 304 |
| 19:04 | 12,415 |
| 19:08 (wave 1 local peak) | 32,757 |
| **19:15 (wave 1 burst peak)** | **75,867** |
| 19:21 (wave 1 end) | 9,597 |
| 19:22–19:25 (gap) | 0 |
| **19:45 (wave 2 peak)** | **76,360** |
| 19:52 (wave 2 end) | 61 |
| **20:18 (wave 3 peak)** | **76,785** |
| 20:23 (wave 3 end) | 4,812 |
| 20:24+ | 0 |

Peak łączny: **76,785 req/min** (~1,280 RPS) o 20:18 CEST.

### Target Response Time

| Zakres | Avg | p99 |
|---|---|---|
| Baseline (pre-test) | 13–14 ms | 50–56 ms |
| Wave 1 (ramp i peak) | 12–16 ms | 46–53 ms |
| Wave 1 koniec (19:21) | 23 ms | 63 ms |
| Wave 2 (peak) | 13–16 ms | 48–59 ms |
| Wave 2 koniec (19:52) | 35 ms | 87 ms |
| Wave 3 (peak) | 14–17 ms | 53–62 ms |
| Wave 3 koniec (20:23) | 22 ms | 68 ms |

**Response time pozostawał stabilny przez cały test.** Jedyne wyraźne spike to końce fal (gdy ruch nagłe spada, ALB przetwarza ostatnie requesty z wyższą latencją). Peak p99 = 87 ms przy 19:52 — nie jest to degradacja.

### Errors

| Metryka | Wartość |
|---|---|
| TargetConnectionErrorCount | **0** — brak |
| UnHealthyHostCount | **0** — brak |
| HTTPCode_Target_5XX_Count | **0** — brak |
| HTTPCode_ELB_5XX_Count | **4 łącznie** (1 per: 19:16, 19:29, 19:45, 20:20) |
| HTTPCode_Target_4XX_Count peak | 2,332/min (20:21 CEST) |
| HTTPCode_Target_4XX_Count total | ~24,000 est. przez cały test |

ELB-level 5xx = 4 przez 90 minut. Absolutnie bez znaczenia. Target 5xx = 0. Backend nie zwrócił ani jednego 5xx przez cały test.

4xx rate: 1–3% przy peak (2,332/76,785 = 3.0% w najgorszej minucie). Normalny poziom dla aplikacji web (missing assets, 404, etc.).

---

## 6. CloudFront

### Cache behaviors (konfiguracja live)

| Path Pattern | Caching Policy | Metoda |
|---|---|---|
| `/api/slogan` | Custom (custom TTL) | HEAD, GET |
| `/_next/image*` | Custom (custom TTL) | HEAD, GET, OPTIONS |
| `/_next/static/*` | Custom (long TTL) | HEAD, GET, OPTIONS |
| `/landing/*` | Custom (long TTL) | HEAD, GET, OPTIONS |
| `/email/*` | Custom (long TTL) | HEAD, GET, OPTIONS |
| `/favicon.ico` | Custom (long TTL) | HEAD, GET, OPTIONS |
| **default** | **CachingDisabled** | HEAD, GET i wszystkie metody |

Domyślne zachowanie (`CachingDisabled`) oznacza, że cały ruch API i dynamiczny jest przekazywany do ALB. Wyłącznie ścieżki statyczne (`/_next/static/`, `/landing/`, `/email/`) i `/api/slogan` mają caching.

### Request volume

| Timestamp CEST | CF req/min |
|---|---:|
| 18:56–18:59 (pre-test) | 533–6,702 (ramp-up) |
| 19:05 | 37,814 |
| **19:08 (wave 1 local peak)** | 70,072 |
| **19:15 (wave 1 burst peak)** | **154,376** |
| 19:21–19:28 (gap 1) | <5,000 |
| **19:45 (wave 2 peak)** | **156,314** |
| 19:52–20:06 (gap 2) | <8,900 |
| **20:18 (wave 3 peak)** | **159,222** |
| 20:23+ | <14,000 → 0 |

**Absolutny peak: 159,222 req/min** o 20:18 CEST.

### Error rates

| Metryka | Zakres podczas load |
|---|---|
| 5xxErrorRate | **0.00%–0.016%** — efektywnie zero |
| 4xxErrorRate | 0.43%–3.14% (normalny poziom) |

Brak anomalii w error rates.

### Bytes downloaded

Peak egress: **~7.02 GB/min** o 19:45 CEST (156,314 req/min → ~45 KB/req średnio). Łączny egress przez test — szacunkowo 400–500 GB.

### Cache effectiveness (obliczone z CF/ALB ratio)

| Wave | CF peak req/min | ALB peak req/min | % do ALB | % absorbowane przez CF |
|---|---:|---:|---:|---:|
| Wave 1 | 154,376 | 75,867 | 49.1% | **50.9%** |
| Wave 2 | 156,314 | 76,360 | 48.8% | **51.2%** |
| Wave 3 | 159,222 | 76,785 | 48.2% | **51.8%** |

CloudFront absorbuje ~51% żądań. Te 51% to statyczne assety: JS/CSS bundles, obrazy, landing pages. Wszystkie żądania API (default behavior z CachingDisabled) przechodzą do ALB.

### Metryki niedostępne

| Metryka | Powód |
|---|---|
| `CacheHitRate` | Enhanced metrics nie włączone na dystrybucji |
| `OriginLatency` | Enhanced metrics nie włączone |
| `OriginRequests` | Enhanced metrics nie włączone |

Metryki origin-level wymagają włączenia "Additional metrics" w CloudFront ($). Analiza na podstawie CF/ALB ratio jest wystarczająca.

**Access logi CloudFront:** Włączone. S3: `maspex-uat-access-logs-969209893152` / prefix `cloudfront/maspex-uat/api`. Mogą posłużyć do per-path cache hit analizy.

---

## 7. Redis / ElastiCache

### Metryki CloudWatch (maspex-uat, cache.t3.medium)

| Metryka | Min | Max | Typowo |
|---|---|---|---|
| CPUUtilization | 1.59% | 2.93% | ~2.0–2.5% |
| EngineCPUUtilization | 0.217% | 0.250% | ~0.23% |
| DatabaseMemoryUsagePercentage | 0.3206% | 0.3212% | flat |
| CurrConnections | 4 | 5 | flat |
| NewConnections | 0 | 0 | zero przez cały test |
| Evictions | 0 | 0 | zero |
| SwapUsage | 0 bytes | 0 bytes | zero |

**Redis infrastructure jest zdrowy przez cały test.** Brak presji CPU, brak presji memory, brak ewiction, brak swap. Metryki były flat i nie reagowały na fale load.

### Paradoks: zdrowa infrastruktura vs masowe błędy aplikacyjne

ElastiCache CloudWatch pokazuje Redis jako zupełnie nieobciążony, ale aplikacja wygenerowała 924,582 błędów write-through. Możliwe wyjaśnienia:

1. **Zerwanie połączenia pre-test** (16:55 UTC): Redis connection closed przed rampu-up, przy bardzo niskim obciążeniu. CloudWatch ElastiCache ma minimalną rozdzielczość 1 min i może nie uchwycić sub-minutowego zdarzenia (np. Redis restart trwający <10s). Redis log group (`/aws/elasticache/maspex-uat/redis`) — **0 eventów w oknie testu** (nie zidentyfikowano restartu w logach).
2. **Connection pool exhaustion**: przy 9 taskach maspex-api z własnym pool, peak 1,280 RPS generuje wysoką konkurencję na połączeniach Redis. Visible connections: tylko 4–5 (podejrzanie mało dla 9 tasków). Możliwe: klient Redis stosuje single-connection per process lub pool o rozmiarze 1.
3. **Circuit breaker nie zamknął się**: po otwarciu na początku testu, circuit breaker utrzymał stan "open" przez 79+ minut. W tym czasie każda próba zapisu do Redis fast-failuje natychmiast z "Redis circuit open", zamiast próbować reconnect. Brak recovery sugeruje długi timeout half-open state lub nieefektywną konfigurację circuit breaker.

**Konkluzja**: Redis infrastruktura nie jest bottleneckiem. Problem leży w app-level: konfiguracji circuit breaker i/lub connection pooling.

---

## 8. Logi aplikacyjne

### Log groups przeszukane

| Log group | Rozmiar | Retention |
|---|---|---|
| `/maspex/uat/contest-service` | 1.2 GB | 30 dni |
| `/maspex/uat/bot` | 17 MB | 30 dni |
| `/maspex/uat/admin-panel` | 43 KB | 30 dni |

### Wyniki przeszukiwania

| Pattern | Count (okno 16:30–18:30 UTC) | Uwagi |
|---|---|---|
| `VOTE_CACHE_WRITETHROUGH_FAIL` | **924,582** | Saturuje. Oba subtypes obecne |
| `Redis circuit open` | **≥100** (limit reached) | Subtype VOTE_CACHE_WRITETHROUGH_FAIL |
| `Connection is closed` | **≥100** (limit reached) | Subtype VOTE_CACHE_WRITETHROUGH_FAIL |
| `timeout` | **0** | Brak |
| `pool timeout` | **0** | Brak |
| `statement timeout` | **0** | Brak |
| `502` | **0** | Brak |
| `aborted` | **0** | Brak |
| `GET_SLOGANS_COUNT` | **0** | Brak |
| `CACHE-CRON` | **0** | Brak |
| `AuthApiError` | **0** | Brak |
| `QUEUE` | **0** | Brak |

### Dystrybucja VOTE_CACHE_WRITETHROUGH_FAIL (5-min buckety)

| Okno UTC | Okno CEST | Błędy w 5 min | Kontekst |
|---|---|---:|---|
| 16:55–17:00 | 18:55–19:00 | 3,060 | Pre-ramp, circuit otworzył się |
| 17:00–17:05 | 19:00–19:05 | 15,062 | Wave 1 start |
| 17:05–17:10 | 19:05–19:10 | 63,724 | Wave 1 buduje się |
| 17:10–17:15 | 19:10–19:15 | 59,398 | Wave 1 kontynuacja |
| **17:15–17:20** | **19:15–19:20** | **142,730** | **Wave 1 burst peak** |
| 17:20–17:25 | 19:20–19:25 | 32,432 | Wave 1 wygaszanie |
| 17:25–17:30 | 19:25–19:30 | 2,518 | Gap 1 — niski ruch, błędy minimalne |
| 17:30–17:35 | 19:30–19:35 | 13,136 | Wave 2 start |
| 17:35–17:40 | 19:35–19:40 | 59,830 | Wave 2 buduje się |
| 17:40–17:45 | 19:40–19:45 | 52,142 | Wave 2 kontynuacja |
| **17:45–17:50** | **19:45–19:50** | **141,080** | **Wave 2 burst peak** |
| 17:50–17:55 | 19:50–19:55 | 35,048 | Wave 2 wygaszanie |
| 17:55–18:00 | 19:55–20:00 | 582 | Gap 2 — minimalny ruch |
| 18:00–18:05 | 20:00–20:05 | 7,918 | Wave 3 start |
| 18:05–18:10 | 20:05–20:10 | 39,574 | Wave 3 buduje się |
| 18:10–18:15 | 20:10–20:15 | 48,982 | Wave 3 kontynuacja |
| **18:15–18:20** | **20:15–20:20** | **117,486** | **Wave 3 burst peak** |
| 18:20–18:25 | 20:20–20:25 | 89,880 | Wave 3 kończenie |
| **ŁĄCZNIE** | | **924,582** | **79 minut z błędami** |

**Obserwacja**: błędy w 5-min bucketach perfektnie korelują z falami requestów w ALB i CF. Przy braku ruchu (gapsy) błędy maleją do zera / minimum. To potwierdza, że błędy są generowane przez żądania użytkowników (trafienia w endpoint vote), a nie przez background job.

### Błąd pre-ramp

Pierwsze błędy: **16:56:31 UTC**, przy zaledwie 304 req/min na ALB. Oznacza to, że Redis connection closed nastąpiło PRZED znaczącym obciążeniem. Możliwa przyczyna: Redis brief restart lub timeout połączenia w trakcie niskiej aktywności.

---

## 9. Korelacja sygnałów

### Co się nakładało w czasie

```
16:55 UTC: Redis "Connection is closed" (304 req/min ALB — bardzo niski ruch)
16:56 UTC: Redis circuit breaker otworzył się
17:00–17:21: Wave 1 (CF: 154k req/min peak, ALB: 76k req/min peak)
  → 16% avg CPU, 26% peak CPU per task
  → Memory: 17% → 32%
  → VOTE_CACHE_WRITETHROUGH_FAIL: ~28,000/min w peaku
  → ALB response time: 12–23 ms avg (bez degradacji)
17:21–17:29: Gap 1 — ruch zero
  → Memory: 32% → ZATRZYMUJE SIĘ (nie odchodzi)
17:29–17:51: Wave 2 (CF: 156k req/min peak, ALB: 76k req/min peak)
  → Memory: 30% → 45%
  → VOTE_CACHE_WRITETHROUGH_FAIL: ~28,000/min w peaku
  → ALB response time: bez zmian
17:51–18:07: Gap 2 — ruch zero
  → Memory: 44% → ZATRZYMUJE SIĘ
18:07–18:23: Wave 3 (CF: 159k req/min peak, ALB: 76k req/min peak)
  → Memory: 44% → 57%
  → VOTE_CACHE_WRITETHROUGH_FAIL: ~23,000/min w peaku
  → ALB response time: 14–22 ms avg (bez degradacji)
```

### Przyczyna

**Redis connection closed o 16:55 UTC** otworzył circuit breaker, który nie zamknął się przez cały test. Infrastruktura Redis była zdrowa — problem leży w aplikacyjnej obsłudze reconnection lub w konfiguracji circuit breaker (zbyt długi timeout, brak agresywnego half-open retry).

### Skutek

Każde głosowanie użytkownika generowało błąd write-through cache. Głosowanie prawdopodobnie było nadal rejestrowane w bazie głównej (circuit breaker nie blokuje writes do DB, tylko do Redis cache), ale stan cache był nieaktualny przez cały test.

### Szum

- Skokowy profil CPU bota (~co 7-8 min) — to cron job, niezwiązany z load testem
- 4 ELB-level 5xx przez 90 minut — poniżej progu istotności
- 4xx rate 1–3% — normalna dla aplikacji web

---

## 10. Najbardziej prawdopodobny bottleneck

**Bottleneck: App-level Redis write-through path (circuit breaker)**

Dowód:
- 924,582 błędów `VOTE_CACHE_WRITETHROUGH_FAIL` w 79 minutach
- Circuit breaker otworzył się 1 minutę przed znaczącym ruchem (przy 304 req/min ALB)
- Po otwarciu nie zamknął się przez 79+ minut
- Redis infrastruktura wyglądała zdrowo przez cały test
- Wzorzec błędów idealnie koreluje z falami request (ON gdy ruch, OFF gdy gap)

**Co NIE było bottleneckiem:**
- ECS CPU — peak avg 18.1%, próg 60%
- ECS Memory — peak avg 57%, próg 75% (ale trend wzrostowy jest niepokojący)
- ALB — zero connection errors, zero 5xx, response time 12–22 ms avg
- Redis infrastruktura (CloudWatch) — flatline

**Potencjalny przyszły bottleneck:**
- Memory: 17% → 57% w ciągu 90 minut aktywnego testu. Nie odchodzi między falami. Jeszcze jedna sesja testowa bez redeploymentu mogłaby zepchnąć average powyżej progu autoscaling 75%.

---

## 11. Co wykluczono

| Co | Na podstawie |
|---|---|
| ALB saturation | TargetResponseTime avg 12–22 ms, p99 45–87 ms przez cały test |
| ECS CPU bottleneck | CPU avg peak 18.1%, max 30.9% per task; próg autoscaling 60% nigdy nie osiągnięty |
| ECS task churn / instability | 0 stopped tasks, 0 replacement events dla maspex-api i maspex-admin-panel |
| Redis infrastructure failure | CloudWatch: CPU <3%, Memory <0.4%, 4–5 connections, 0 evictions, 0 swap, 0 nowych połączeń |
| 5xx errors / HTTP failures | HTTPCode_Target_5XX = 0, HTTPCode_ELB_5XX = 4 łącznie |
| Autoscaling failure | Autoscaling nie powinno się wyzwolić — metryki były poniżej progów |
| Unhealthy hosts | UnHealthyHostCount = 0 przez cały test |
| CloudFront misconfiguration | Cache behaviors zgodne z oczekiwaniami; static assets cached; API prawidłowo pass-through |

---

## 12. Recommended next steps

1. **Zbadaj konfigurację Redis circuit breaker w contest-service**: Jaki jest `halfOpenTimeout`? Dlaczego nie próbuje zamknąć circuit breakera przez 79+ minut? Jeśli circuit nie testuje recovery, każdy event Redis (nawet 1-sekundowy blip) blokuje write-through do końca sesji. Rozważ agresywny half-open z retry co 5–10 sekund.

2. **Zbadaj przyczynę initial Redis connection drop o 16:55 UTC**: Redis log group (0 eventów) nie ujawniło restartu. Sprawdź: czy były scheduled maintenance events dla cache.t3.medium, czy load balancer timeout był osiągnięty podczas idle (keepalive?), lub czy poprzedni test (12:00 CEST) pozostawił connection state w złym stanie.

3. **Wyjaśnij 4–5 CurrConnections przy 9 taskach**: Oczekiwane byłoby ~9+ połączeń. Jeśli aplikacja używa single-connection per task (nie pool), każdy peak concurrency w ramach jednego taska może generować queue i backpressure, co wyjaśniałoby "Connection is closed" przy niskim obciążeniu infrastruktury.

4. **Monitoruj trend memory przed kolejnym testem**: Memory po teście 19:00 CEST = ~57% (9 tasków). Jeśli planowany jest kolejny test bez redeploymentu, pamięć startuje przy 57% i może przekroczyć próg autoscaling (75%) w trakcie testu. Rozważ restart maspex-api lub co najmniej monitoring memory alarm w CloudWatch.

5. **Włącz enhanced CloudFront metrics** (koszt): `OriginLatency` i `CacheHitRate` per-distribution dałyby pełny obraz zachowania origin. Alternatywnie — zacznij analizować access logi w S3 (`maspex-uat-access-logs-969209893152/cloudfront/maspex-uat/api`) dla per-path cache hit rate.

6. **Weryfikacja: czy głosy użytkowników trafiały do DB podczas otwartego circuit breakera**: 924k błędów write-through nie oznacza automatycznie utraty głosów — zależy od kolejności operacji (DB write → Redis write vs Redis write → DB write). Jeśli DB write był przed Redis write, głosy są w bazie. Wymagana weryfikacja z developerami.

7. **Rozważ obniżenie MinCapacity=9 po testach**: Jeśli środowisko UAT nie jest używane poza load testami, 9 tasków przez całą dobę to koszt. Poza oknem testowym baseline UAT to ~2–3 taski.

---

## 13. Evidence

### Komendy AWS CLI użyte (via subagent + główna sesja)

```bash
# ECS
aws ecs describe-services --cluster maspex-uat --services maspex-api maspex-admin-panel maspex-bot --profile maspex-cli --region eu-west-1

# Autoscaling
aws application-autoscaling describe-scalable-targets --service-namespace ecs --profile maspex-cli --region eu-west-1
aws application-autoscaling describe-scaling-policies --service-namespace ecs --profile maspex-cli --region eu-west-1
aws application-autoscaling describe-scaling-activities --service-namespace ecs --profile maspex-cli --region eu-west-1

# ALB discovery
aws elbv2 describe-load-balancers --profile maspex-cli --region eu-west-1
aws elbv2 describe-target-groups --profile maspex-cli --region eu-west-1

# ALB metrics (eu-west-1, ns AWS/ApplicationELB, period 60s)
# RequestCount, TargetResponseTime, TargetConnectionErrorCount, UnHealthyHostCount
# HTTPCode_Target_4XX_Count, HTTPCode_Target_5XX_Count, HTTPCode_ELB_5XX_Count

# ECS metrics (eu-west-1, ns AWS/ECS, period 60s)
# CPUUtilization, MemoryUtilization per service

# ElastiCache discovery + metrics (eu-west-1, ns AWS/ElastiCache, period 60s)
# CPUUtilization, EngineCPUUtilization, DatabaseMemoryUsagePercentage
# CurrConnections, NewConnections, Evictions, SwapUsage

# CloudFront config + metrics (us-east-1, ns AWS/CloudFront, period 60s)
# Requests, BytesDownloaded, BytesUploaded, 4xxErrorRate, 5xxErrorRate, TotalErrorRate

# CloudWatch Logs
aws logs filter-log-events --profile maspex-cli --region eu-west-1 \
  --log-group-name /maspex/uat/contest-service \
  --start-time 1777998600000 --end-time 1778005800000 \
  --filter-pattern "VOTE_CACHE_WRITETHROUGH_FAIL" --limit 100

aws logs start-query --profile maspex-cli --region eu-west-1 \
  --log-group-name /maspex/uat/contest-service \
  --start-time 1777998600 --end-time 1778005800 \
  --query-string 'filter @message like /VOTE_CACHE_WRITETHROUGH_FAIL/ | stats count(*) as total, count_distinct(bin(1m)) as minutes_with_errors'

aws logs start-query --profile maspex-cli --region eu-west-1 \
  --log-group-name /maspex/uat/contest-service \
  --start-time 1777998600 --end-time 1778005800 \
  --query-string 'filter @message like /VOTE_CACHE_WRITETHROUGH_FAIL/ | stats count(*) as errors by datefloor(@timestamp, 5m) as t | sort t asc'
```

---

## Missing or unavailable data

| Brakujące dane | Wpływ na analizę |
|---|---|
| `CacheHitRate` (CloudFront enhanced metric) | Obliczono proxy metric z CF/ALB ratio (~51%). Wystarczające. |
| `OriginLatency` (CloudFront enhanced metric) | Nieznana latencja origin per-request. ALB TargetResponseTime pośrednio zastępuje. |
| Per-path breakdown requestów CF | Nieznana proporcja `/api/slogan` vs statycznych vs innych. Wymaga analizy S3 access logów. |
| CloudFront access logs (S3) | Dostępne ale nie przeanalizowane (`maspex-uat-access-logs-969209893152`). Mogą dać pełny per-path obraz. |
| Redis restart event (16:55 UTC) | Log group 0 eventów, CloudWatch nie uchwycił. Przyczyna initial "Connection is closed" nieustalona definitywnie. |
| Application source code dla circuit breaker | Nieznany `halfOpenTimeout` ani implementacja reconnect. Wymaga weryfikacji z developerami. |

---

## Różnice względem poprzednich load testów

### vs 2026-05-05 12:00–13:00 CEST (ten sam dzień, wcześniej)

| Parametr | 12:00 CEST | **19:00 CEST** |
|---|---|---|
| Czas trwania | ~25 min (1 fala) | **~90 min (3 fale)** |
| CF peak req/min | ~115,000 | **~159,000 (+38%)** |
| ALB peak req/min | ~51,000 | **~76,785 (+50%)** |
| VOTE_CACHE_WRITETHROUGH_FAIL | 305,000 | **924,582 (+203%)** |
| Czas otwarcia circuit breaker | 2s od startu | **>1 min przed rampu-up** |
| CurrConnections anomalia przed testem | 30→5 o 10:10 UTC | **brak anomalii (4–5 przez cały czas)** |
| Memory baseline (start) | ~3.8% | **~17% (residual post 12:00)** |
| Memory peak | ~17% | **~57%** |
| Memory recovery po teście | NIE (17% zostaje) | **NIE (57% zostaje)** |
| Autoscaling scale-out | NIE (CPU 11.6%) | **NIE (CPU 18.1%, Memory 57%)** |
| HTTP 5xx (ELB) | 0 | **4 (bez znaczenia)** |
| ALB response time | 13 ms avg | **12–16 ms avg (identycznie)** |
| Cache offload CF→ALB | ~55.7% | **~51% (-5pp, marginalnie gorszy)** |

**Kluczowa różnica**: Brak anomalii CurrConnections przed testem 19:00 (vs dip 30→5 o 10:10 w teście 12:00). Mimo to circuit breaker otworzył się jeszcze wcześniej (pre-ramp). To sugeruje inne wyzwalanie niż poprzednio.

**Memory accumulation across tests**: Test 12:00 pozostawił ~17% memory zamiast baseline ~4%. Test 19:00 startował od 17% i doszedł do 57%. Wyraźny trend wielosesyjny — memory rośnie kumulatywnie między testami tego samego dnia.

### vs 2026-04-29 13:00 CEST

| Parametr | 04-29 13:00 | **05-05 19:00** |
|---|---|---|
| HTTP 5xx (ELB) | ~105 | **4** |
| ALB tail latency max | 29.99s | **0.087s (p99)** |
| Degradacja HTTP | TAK (5xx, latency spikes) | **NIE** |
| Redis circuit open | 1,758 błędów (1 minuta) | **924,582 błędów (79 minut)** |
| Scale-out | Nie (lub pre-scaled?) | **NIE** |

Testy od April 29 pokazują stopniowe "uczenie się" środowiska: HTTP layer jest coraz stabilniejszy, ale Redis write-through problem jest nadal nierozwiązany i skaluje się z czasem trwania testu.
