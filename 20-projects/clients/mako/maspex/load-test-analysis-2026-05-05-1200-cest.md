# Maspex UAT — Load Test Analysis — 2026-05-05 12:00–13:00 CEST

## 1. Executive Summary

Load test 2026-05-05 byl **lzejszy niz April 29** (~3x mniej requestow na ALB), ale wygenerowil **masywny i natychmiastowy cascade Redis circuit breaker** — 305K bledow `VOTE_CACHE_WRITETHROUGH_FAIL` w ciagu 25 minut. W poprzednim tescie byl to incydent jednominutowy (1,758 bledow).

Warstwy HTTP/ALB/ECS zachowaly sie **bez degradacji**:
- 0 `HTTPCode_ELB_5XX_Count` (vs 105 w April 29)
- 0 `HTTPCode_Target_5XX_Count`
- 0 unhealthy hostow
- Brak tail latency spike (max 0.8s vs 29.99s w April 29)
- Brak task churn dla `maspex-api`

Autoscaling nie wyzwolil scale-out — CPU avg peak to tylko 11.64% (prog 60%).

CloudFront odciazal origin lepiej niz poprzednio: delta CF/ALB = ~53% requestow obsluzone przez edge (vs 41.7% w April 29).

**Kluczowa roznica wzgledem April 29**: Tym razem API przezylo test bez HTTP-level awarii mimo **otartego Redis circuit przez cale 25 minut testu**. Aplikacja gracefully degradowala (write-through fails silently), co moze byc celowe lub moze oznaczac utrate danych votow. Wymaga weryfikacji po stronie kodu.

**Najbardziej prawdopodobny bottleneck**: App-level Redis circuit breaker dla sciezki `VOTE_CACHE_WRITETHROUGH`. Otworzyl sie w ciagu 2 sekund od startu testu, co sugeruje zbyt niski `maxConnections` lub `commandTimeout` / `connectionTimeout` w kliencie Redis — albo anomalnie niska liczba polaczen przed testem (30→5 o 10:10 UTC, na 10 minut przed startem).

---

## 2. Scope i time window

| Zakres | UTC | CEST |
|---|---:|---:|
| Glowne | `2026-05-05 10:00–11:00` | `2026-05-05 12:00–13:00` |
| Rozszerzone (faktyczne) | `2026-05-05 09:30–11:30` | `2026-05-05 11:30–13:30` |
| Faktyczne okno ruchu | `2026-05-05 10:19–10:45` | `2026-05-05 12:19–12:45` |

Zrodla danych:

| Zrodlo | Status |
|---|---|
| ECS service state/events | zebrane |
| Application Auto Scaling targets/policies/activities | zebrane |
| CloudWatch metrics: ECS (CPU/Memory) | zebrane |
| CloudWatch metrics: ALB (RequestCount, ResponseTime, 4xx/5xx, UnHealthy) | zebrane |
| CloudWatch metrics: CloudFront (Requests, Bytes, 4xx/5xx, CacheHit, Origin) | zebrane |
| CloudWatch metrics: ElastiCache (CPU, Memory, Connections, Evictions, Swap) | zebrane |
| CloudWatch Logs Insights: `/maspex/uat/contest-service` | zebrane |
| CloudWatch Logs Insights: `/maspex/uat/admin-panel` | zebrane |
| CloudWatch Logs Insights: `/maspex/uat/bot` | zebrane |
| ECS stopped tasks (maspex-api / maspex-bot) | zebrane |

Objete zasoby:

| Obszar | Zasob |
|---|---|
| CloudFront | `E3J76RNXIE2YIG`, `kapsel.makotest.pl` |
| ALB | `app/maspex-uat/68317764a66425bd` |
| API TG | `targetgroup/maspex-uat-api-3000/97cac4c72be43344` |
| ECS cluster | `maspex-uat` |
| ECS services | `maspex-api` (task def :53), `maspex-admin-panel` (:25), `maspex-bot` (:8) |
| ElastiCache | `maspex-uat` / node `0001` (cache.t3.medium, Redis 7.1.0) |

---

## 3. Timeline

| Timestamp UTC | Komponent | Zdarzenie | Znaczenie |
|---|---|---|---|
| 09:30–10:18 | ALB/CF | Baseline: <300 req/5min na ALB, ~300 req/5min na CF | Srodowisko przed testem praktycznie idle |
| 09:38–09:39 | App logs | 4x `GET_SLOGANS_ERROR` | Pre-test warmup; brak zwiazku z glownym testem |
| 09:50 | Admin panel | 4x `AuthApiError: Invalid Refresh Token` (Supabase) | Pre-test sesja admina; poza sciezka testowa |
| **10:10** | **ElastiCache** | **CurrConnections: 30→5 (z 12:10 CEST)** | **Anomalia: pool polaczen Redis zmniejszyl sie 6x przed startem testu** |
| **10:19:58** | **App logs** | **Pierwsze `VOTE_CACHE_WRITETHROUGH_FAIL Error: Connection is closed.`** | **Pierwsze uszkodzenie polaczenia Redis** |
| **10:20:00** | **App logs** | **`Redis circuit open` — circuit breaker wyzwolony** | **2 sekundy po pierwszym errore; circuit otwarty na caly czas testu** |
| 10:20 | CF/ALB | CF: 28,807 req/5min; ALB: 13,762 req/5min | Poczatek mierzalnego ruchu testowego |
| 10:25 | CF/ALB | CF: 118,924; ALB: 56,896 | Szybki ramp-up |
| 10:30 | CF/ALB | CF: 283,955; ALB: 132,710 | Wysoki ruch; brak degradacji HTTP |
| 10:35 | App logs | Dip w wolumenie logow (43K→26K logs/min) | Mozliwe: shedding requestow przez circuit breaker; ruch CF/ALB tez wolniejszy |
| **10:37–10:44** | **App logs** | **Drugi, wiekszy peak: 131K–218K logs/min** | **Druga fala ruchu testowego** |
| **10:38–10:39** | **App logs** | **Peak Redis circuit open: ~31,000/min** | **Najwyzsze natezenie bledow w trakcie testu** |
| **10:40** | **CF** | **Peak CloudFront: 575,340 req/5min** | **Szczyt testu** |
| **10:40** | **ALB** | **Peak ALB: 255,063 req/5min; TargetResponseTime avg 13.6ms, max 0.47s** | **Peak bez degradacji** |
| **10:40** | **ECS** | **CPU avg 11.64%, max 24.58%** | **Daleko ponizej progu skalowania 60%** |
| 10:45 | CF/ALB/App | CF: 1,790 req; ALB: 516 req; Redis errs: 430/min | Gwaltowny koniec testu |
| 10:45 | ElastiCache | CurrConnections utrzymuje sie na poziomie 5-6 | Brak powrotu polaczen Redis do poziomu 30 |
| 10:53 | ECS/bot | `maspex-bot` task 7a57704... zatrzymany; ELB health check | Crash loop bota — osobny problem |
| 10:53–13:20 | ECS/bot | Seryjne zatrzymania i replacementy taskow bota (exit code 1) | Kontynuacja osobnego problemu bota |

---

## 4. ECS / Auto Scaling

### Stan uslug

| Service | Desired | Running | Pending | Task definition | Deployment |
|---|---:|---:|---:|---|---|
| `maspex-api` | 9 | 9 | 0 | `maspex-api:53` | COMPLETED |
| `maspex-admin-panel` | 1 | 1 | 0 | `maspex-admin-panel:25` | COMPLETED |
| `maspex-bot` | 1 | 1 | 0 | `maspex-bot:8` | ACTIVE (crash loop) |

Uwaga: task def zmienila sie z `:52` (April 29) na `:53`. Deployment `:53` wdrozony `2026-04-29T15:15:51+02:00`, updatedAt `2026-05-03T15:58:56+02:00`.

### Autoscaling

| Parametr | Wartosc |
|---|---:|
| Min capacity | 9 |
| Max capacity | 15 |
| CPU target tracking | 60% |
| Memory target tracking | 75% |
| Scale-out cooldown | 60s |
| Scale-in cooldown | 300s |

Scaling activities w trakcie testu: **brak**. Jedyna aktywnosc to `Setting desired count to 9` z `2026-04-28T08:46:35 UTC`. Brak scale-out jest zgodny z pomierzonymi metrykami: CPU i memory nigdy nie zblizyly sie do progow.

### ECS CPU / Memory (`maspex-api`)

| Timestamp CEST | CPU avg | CPU max | Memory avg | Memory max |
|---|---:|---:|---:|---:|
| 11:30 (baseline) | 0.17% | 1.88% | 3.77% | 3.91% |
| 12:00 (pre-test) | 0.14% | 0.21% | 3.86% | 4.02% |
| **12:20 (start)** | **1.24%** | **3.63%** | **4.15%** | **4.82%** |
| **12:25** | **4.04%** | **10.15%** | **4.98%** | **5.93%** |
| **12:30** | **7.67%** | **12.46%** | **7.38%** | **8.56%** |
| **12:35** | **9.62%** | **21.61%** | **10.07%** | **14.26%** |
| **12:40 (peak)** | **11.64%** | **24.58%** | **16.23%** | **18.91%** |
| 12:45 (end) | 1.37% | 9.82% | 16.50% | 18.84% |
| 12:50 | 0.84% | 1.22% | 15.95% | 16.59% |
| 13:10 | 0.77% | 1.06% | 16.08% | 16.76% |

CPU wraca do baseline w ciagu kilku minut po tescie. **Memory nie wraca** — utrzymuje sie na ~16% zamiast baseline ~3.8%. To oznacza, ze aplikacja zaladowala dane do pamieci (np. slogan cache, vote counters) i je trzyma. Nie jest to wyciek pamieci, ale zmiana stanu applikacji pod obciazeniem.

### Task churn / service events

- `maspex-api`: **0 stopped tasks** w oknie testu. Brak ECS replacementow, brak health check failures.
- `maspex-admin-panel`: stabilny.
- `maspex-bot`: **crash loop** — 8 stopped tasks (TG: `maspex-uat-bot`), wszystkie z `exitCode: 1`, `Task failed ELB health checks`. Problem niezalezny od API load testu (Twitch auth token brakujacy w konfiguracji, restart co ~7 min). Crash zaczal sie o 10:53 UTC — po peaku testu.

---

## 5. ALB

### Request volume (API TG, 5-min buckets)

| Timestamp CEST | RequestCount |
|---|---:|
| 11:30–12:15 (baseline) | 0–171 / 5min |
| 12:20 | 13,762 |
| 12:25 | 56,896 |
| 12:30 | 132,710 |
| 12:35 | 213,434 |
| **12:40 (peak)** | **255,063** |
| 12:45 | 516 |
| 12:50–13:10 | 0–6 |

**Laczny ALB RequestCount w oknie testu: ~671,865**

### Response time (API TG)

| Timestamp CEST | Average | Maximum |
|---|---:|---:|
| Pre-test (11:35 anomalia) | 0.258s | 11.27s |
| 12:20 | 0.014s | 0.188s |
| 12:25 | 0.013s | 0.327s |
| **12:30** | **0.014s** | **0.799s** |
| **12:35** | **0.013s** | **0.487s** |
| **12:40 (peak)** | **0.014s** | **0.468s** |
| 12:45 | 0.032s | 0.126s |

**Anomalia pre-test**: o 11:35 CEST (09:35 UTC) — max 11.27s przy 104 requestach ALB. Jednorazowy outlier; prawie na pewno nie zwiazany z testem (moze pojedynczy long-running request lub warmup endpoint).

Podczas wlasciwego testu: **srednia 13-14ms, max 0.8s** — bardzo dobra latency. Brak tail latency problemu z poprzedniego testu.

### Errors i health

| Metryka | Wynik |
|---|---|
| `TargetConnectionErrorCount` | brak datapoints (0) |
| `UnHealthyHostCount` | 0 przez caly czas |
| `HTTPCode_Target_5XX_Count` | brak datapoints (0) |
| `HTTPCode_ELB_5XX_Count` | brak datapoints (0) |
| `HTTPCode_Target_4XX_Count` | ~3,378 total; peak 1,845 w 12:40 bucket (0.72% requestow) |
| Healthy targets post-test | 9 of 9 healthy |

4xx to normalny procent dla traffic generatora — 401/403/404 dla niezalogowanych requestow lub niedostepnych zasobow. Brak 5xx to **fundamentalna roznica wzgledem April 29**.

---

## 6. CloudFront

### Konfiguracja (sanity check)

| Precedence | Path pattern | Cache policy |
|---:|---|---|
| 1 | `/api/slogan` | custom: `d71f43bc...` (cacheable) |
| 2 | `/_next/image*` | custom: `dea1b35e...` (image optimizer) |
| 3 | `/_next/static/*` | custom: `ab5d9518...` (static long TTL) |
| 4 | `/landing/*` | custom: `ab5d9518...` (static long TTL) |
| 5 | `/favicon.ico` | custom: `ab5d9518...` (static long TTL) |
| **6 (NOWE)** | **`/email/*`** | **custom: `ab5d9518...` (static long TTL)** |
| default | `*` | `CachingDisabled` (passthrough do ALB) |

**Zmiana w konfiguracji**: dodana regula `/email/*` z cache policy. Nie wystepowala w analizach April 28/29.

### Request volume i bytes (5-min buckets)

| Timestamp CEST (UTC) | Requests | Bytes | GB |
|---|---:|---:|---:|
| 11:30–12:15 (baseline) | 15–267 / 5min | minimal | ~0 |
| 12:20 (10:20) | 28,807 | 1.25 GB | |
| 12:25 (10:25) | 118,924 | 4.80 GB | |
| 12:30 (10:30) | 283,955 | 11.06 GB | |
| 12:35 (10:35) | 433,566 | 18.29 GB | |
| **12:40 (10:40, peak)** | **575,340** | **21.54 GB** | |
| 12:45 | 1,790 | 0.024 GB | |

**Lacznie**: ~1,443,270 requestow, ~56.88 GB bytes downloaded

Peak: ~575,340 req/5min = ~1,917 req/s; throughput ~628 Mbit/s

### Errors

| Metryka | Wynik |
|---|---|
| `5xxErrorRate` | **0% przez caly czas** |
| `4xxErrorRate` podczas testu | 0.11%–1.62% (szum; 100% dla niskich wolumenow baseline) |

### Cache / origin behavior

CF vs ALB podczas testu (12:20–12:45 CEST):

| Bucket CEST | CF | ALB | Delta | CF offload % |
|---|---:|---:|---:|---:|
| 12:20 | 28,807 | 13,762 | 15,045 | 52% |
| 12:25 | 118,924 | 56,896 | 62,028 | 52% |
| 12:30 | 283,955 | 132,710 | 151,245 | 53% |
| 12:35 | 433,566 | 213,434 | 220,132 | 51% |
| 12:40 | 575,340 | 255,063 | 320,277 | **56%** |
| Suma | ~1,440,592 | ~671,865 | ~768,727 | **53%** |

**~53% requestow CloudFront nie dotarlo do ALB** — obsluzone przez edge (cache lub edge logic). To poprawa wzgledem April 29 (41.7%).

Nie mozna jednoznacznie przypisac tej roznicy do `/api/slogan` — brakuje `CacheHitRate`, `OriginRequests` (nie dostepne, patrz sekcja Missing data).

### Per-path assessment

| Path | Ocena |
|---|---|
| `/api/slogan` | Behavior istnieje; cache TTL 60s (default) / 600s (max); realny cache hit niepotwierdzony per-path |
| `/_next/image*` | Behavior istnieje; static-like policy; brak per-path danych |
| `/_next/static/*` | Behavior istnieje; dlugi TTL; brak per-path danych |
| `/landing/*` | Behavior istnieje; dlugi TTL; brak per-path danych |
| `/email/*` | **Nowa regula** — ten sam static cache policy; brak per-path danych |
| default `*` | CachingDisabled → wszystko idzie do ALB |

---

## 7. Redis / ElastiCache

Klaster: `maspex-uat`, `cache.t3.medium`, Redis 7.1.0, node `0001`, eu-west-1a.

| Metryka | Baseline (11:30–12:00 CEST) | Podczas testu (12:20–12:45) | Uwagi |
|---|---|---|---|
| `CPUUtilization` avg | 1.85% | 1.88–2.0% | Praktycznie bez zmiany |
| `CPUUtilization` max | ~2.1% | max 3.71% (12:10 CEST) | Nieistotny |
| `EngineCPUUtilization` avg | 0.24% | 0.23–0.41% | Lekkie podwyzszenie 12:25–12:40 |
| `EngineCPUUtilization` max | 0.25% | max 0.52% (12:35 CEST) | Odzwierciedla 5-6 polaczen pod obciazeniem |
| `DatabaseMemoryUsagePercentage` | 0.32% | 0.32% (bez zmian) | Cache praktycznie pusty |
| `Evictions` | 0 | 0 | Brak presji pamieci |
| `SwapUsage` | 0 bytes | 0 bytes | Brak swapu |

### CurrConnections — kluczowa anomalia

| Timestamp CEST | CurrConnections avg | Max |
|---|---:|---:|
| 11:30–12:05 (baseline) | 23–30 | 30 |
| **12:10 — DROP** | **5** | **5** |
| 12:10–13:15 (caly czas testu i po) | 5–6 | 6 |

**O 12:10 CEST (10:10 UTC) — 10 minut przed startem testu — liczba polaczen Redis drastycznie spadla z 30 do 5 i nie wraca do poziomu 30.** Brak odpowiadajacego zdarzenia ECS (brak task replacements, brak deployment events). Mozliwe przyczyny:
- Poprzedni test lub aktywnosc administracyjna zakonczyla sie, aplikacja zmniejszyla pool do minimalnego rozmiaru
- `minIdleConnections` klienta Redis zamknelo wiekszoc polaczen w trakcie idle period
- Ktores taski mialy blad i przelaczyl sie pool

**Implikacja**: Gdy test zaczal sie o 10:19 UTC, pool mial tylko 5 polaczen. Przy dziesiatkach concurrent write requestow → natychmiastowe `Connection is closed` → circuit open w 2 sekundy.

### NewConnections

Minimalne (1-4 podczas calego okna). **Brak reconnection storm** — po tym jak circuit sie otworzyl, aplikacja przestala probowac nowych polaczen.

### Redis jako bottleneck

Metryki Redis jako uslugi: **brak saturacji**. ElastiCache nie jest limiterem jako infrastruktura. Bottleneck jest po stronie aplikacyjnego klienta (pool rozmiaru 5 polaczen vs wzorzec ruchu wymagajacy wieccej).

---

## 8. Logi aplikacyjne

### `/maspex/uat/contest-service` — Redis circuit

| Sygnal | Count | Timing |
|---|---:|---|
| `VOTE_CACHE_WRITETHROUGH_FAIL` / `Connection is closed` | ~5,846 | 10:19:58–10:44 UTC; ~200-250/min |
| `VOTE_CACHE_WRITETHROUGH_FAIL` / `Redis circuit open` | ~299,512 | 10:20:00–10:44 UTC; peak 31K/min |
| **Lacznie VOTE_CACHE_WRITETHROUGH_FAIL** | **~305,358** | **Caly test** |

Timeline Redis circuit open (error/min):

| Czas UTC | cnt/min |
|---|---:|
| 10:19 | 2 |
| 10:20 | 198 |
| 10:25 | 2,098 |
| 10:27 | 4,076 |
| 10:30 | 12,272 |
| 10:35 | 6,080 |
| 10:37 | 18,576 |
| **10:38** | **30,976** |
| **10:39** | **30,420** |
| 10:40 | 26,816 |
| 10:44 | 15,326 |
| 10:45 | 430 |

Zauwaznie: dip na 10:35–10:36 (6K/min → 3.5K/min) = koreluje z dip logvolume i CF/ALB ruchem. Mozliwe auto-throttling lub zmiana fazy testu.

### `/maspex/uat/contest-service` — pozostale sygnaly

| Sygnal | Count | Uwagi |
|---|---:|---|
| `timeout` / `pool timeout` / `statement timeout` | 0 | Brak |
| `aborted` | 0 | Brak |
| `502` | 0 | Brak |
| `GET_SLOGANS_COUNT` | 0 | Brak |
| `GET_SLOGANS_ERROR` | 4 | 09:38–09:39 UTC, pre-test warmup |
| `AuthApiError` / `refresh token` | 0 (w contest-service) | Brak |
| `CACHE-CRON` | 0 | Brak |
| `QUEUE` | 0 | Brak |

### `/maspex/uat/admin-panel`

4x `Error [AuthApiError]: Invalid Refresh Token` (Supabase) o 09:50 UTC — pre-test. Brak bledow podczas samego testu.

### `/maspex/uat/bot`

Ciagly restart co ~7-8 minut przez SIGTERM. Przyczyna w kazdym cyklu: `[TWITCH] Failed to run Twitch bot. Missing auth token.`. Znany problem konfiguracyjny — token Twitcha nie jest ustawiony w task def. Bot Discord dziala poprawnie.

---

## 9. Korelacja sygnałów

```
10:10 UTC  ElastiCache CurrConnections: 30 → 5 (anomalia)
              ↓
10:19:58   Pierwsze Connection is closed (Redis pool wyczerpany)
              ↓ (2 sekundy)
10:20:00   Redis circuit open
              ↓ (circuit otwarty przez caly test)
10:20–10:44   305K VOTE_CACHE_WRITETHROUGH_FAIL
              |
              + ALB i CF: brak degradacji HTTP (API odpowiada 13ms avg)
              + ECS: CPU max 24%, memory rosnace do 16%
              + ALB: 0 unhealthy, 0 5XX, 0 conn errors
```

Interpretacja:

**Przyczynowosc:**
1. Pool polaczen Redis zmniejszyl sie do 5 (10:10 UTC, przed testem).
2. Ruch testowy startowal o 10:19-10:20 UTC z conrucurrency wiekszym niz 5 polaczen → pool nasycony → `Connection is closed`.
3. Circuit breaker otworzyl sie w 2 sekundy → wszystkie write-through od tej pory failuja natychmiast (bez czekania).

**Dlaczego ALB nie zdegradowal:**
- Aplikacja ma graceful degradation dla sciezki vote write-through.
- Operacja VOTE prawdopodobnie wraca OK mimo bledu cache (wynik zapisywany gdzie indziej lub ignorowany).
- CPU API bylo niskie (11% avg) bo circuit open = zadne blokujace wywolania Redis (fail fast).

**Co jest szumem lub osobnym tematem:**
- Bot crash loop: niezalezny problem konfiguracyjny (Twitch token).
- Pre-test anomalia response time 11:35 CEST: jednorazowy outlier, 104 requestow, prawdopodobnie jeden slow request.
- Pre-test GET_SLOGANS_ERROR i AuthApiError: warmup/sesja, poza testem.

---

## 10. Najbardziej prawdopodobny bottleneck

**Jednoznaczna ocena:**

| Kandydat | Ocena |
|---|---|
| ECS / CPU | Nie — max 24% single task; avg 11.64% daleko od 60% progu |
| ECS / memory | Nie — 16% avg max, daleko od 75% progu |
| ALB / origin saturation | Nie — brak 5XX, tail latency ok |
| Redis service (ElastiCache) | Nie — CPU <4%, memory 0.32%, evictions 0 |
| **App-level Redis client pool / circuit breaker** | **TAK — bottleneck potwierdzony** |
| CloudFront inefficiency | Nie — 53% offload, 0% 5xx |
| Downstream DB / Supabase | Brak dowodow w zebranych logach |

**Bottleneck**: Aplikacyjny klient Redis z zbyt malym pool (5 polaczen aktywnych w chwili startu testu). Przy pierwszym burstu vote requestow pool nasycony → `Connection is closed` → circuit open → 305K write-through fail przez caly test.

Wazna obseracja: circuit fail fast zapobiegl kaskadzie na API layer (brak blokowania na timeoutach). Aplikacja sie nie zdegradowala na poziomie HTTP — ale przez 25 minut vote cache write-through nie dzialal. **Nie wiadomo czy votes byly tracone lub zapisywane inaczej** — wymaga weryfikacji w kodzie.

---

## 11. Co wykluczono

| Wykluczenie | Dowod |
|---|---|
| ECS scale-out brak = blad konfiguracji | Skaling nie zadziałał bo CPU/memory nie zblizyly sie do progow — zachowanie zgodne z konfig |
| Redis jako zasobowo przeciazony backend | CPU max 3.71%, EngineCPU max 0.52%, memory 0.32%, evictions 0, swap 0 |
| ALB/origin degradacja | 0 ELB 5XX, 0 Target 5XX, 0 unhealthy hosts, avg latency 13ms |
| Timeout errors w aplikacji | 0 trafien dla timeout/pool/statement timeout w logach |
| API healthcheck failures | 0 stopped tasks dla maspex-api; 0 UnHealthyHostCount |
| CloudFront 5xx | 0% 5xxErrorRate przez caly czas |
| Bot jako glowny problem testu | Crash loop bota to osobny problem Twitch auth |
| Admin panel jako element degradacji | Brak bledow w oknie testu |
| Downstream DB timeout (Supabase) | Brak statement/pool timeout w logach |

Nie wykluczono:
- Utrata votow / niepoprawne dzialanie sciezki vote podczas circuit open (brak potwierdzenia z kodu).
- Per-path cache hit dla `/api/slogan` — brak danych CacheHitRate/OriginRequests.
- Przyczyna dropu CurrConnections z 30→5 o 10:10 UTC.

---

## 12. Recommended next steps

1. **Pilne: zbadac implementacje klienta Redis** — sprawdzic `maxConnections`, `minIdleConnections`, `commandTimeout`, `socketTimeout` i warunki otwarcia circuit breaker; liczba 5 polaczen dla 9 taskow jest podejrzanie niska.
2. **Zbadac co sie dzieje z votem podczas circuit open** — czy vote jest zapisywany do DB mimo blaku cache write-through, czy jest tracony; znalezc kod sciezki `VOTE_CACHE_WRITETHROUGH` i sprawdzic error handling.
3. **Wyjalic anomalie CurrConnections 30→5 (10:10 UTC)** — sprawdzic logi Redis `slow-log` z `/aws/elasticache/maspex-uat/redis` lub logi app z 10:00-10:15 UTC; czy byl poprzedni test albo admin action.
4. **Dodac Redis client metryki** do APM/logs: pool wait time, pool size, circuit state transitions, connection lifecycle — aktualnie Redis jest czarna skrzynka po stronie aplikacji.
5. **Pre-warm Redis pool przed testem** — zapewnic min 9+ polaczen (1 per task) i stabilny pool przed startem ruchu.
6. **Zweryfikowac dodana regule `/email/*` w CloudFront** — czy jest celowa, czy nie powoduje niezamierzonych cache misses lub cache poisoning.
7. **Staly problem maspex-bot**: ustawic brakujacy Twitch auth token w task def lub wylaczyc Twitch integration w UAT.

---

## 13. Evidence

### Uzyte komendy

```bash
aws ecs describe-services --cluster maspex-uat --services maspex-api maspex-admin-panel maspex-bot
aws ecs list-tasks --cluster maspex-uat --service-name maspex-api --desired-status STOPPED
aws ecs list-tasks --cluster maspex-uat --service-name maspex-bot --desired-status STOPPED
aws ecs describe-tasks --cluster maspex-uat --tasks <bot-task-arns>

aws application-autoscaling describe-scalable-targets --service-namespace ecs
aws application-autoscaling describe-scaling-policies --service-namespace ecs --resource-id service/maspex-uat/maspex-api
aws application-autoscaling describe-scaling-activities --service-namespace ecs --resource-id service/maspex-uat/maspex-api

aws cloudwatch get-metric-statistics --namespace AWS/ECS --metric-name CPUUtilization --dimensions Name=ClusterName,Value=maspex-uat Name=ServiceName,Value=maspex-api
aws cloudwatch get-metric-statistics --namespace AWS/ECS --metric-name MemoryUtilization --dimensions Name=ClusterName,Value=maspex-uat Name=ServiceName,Value=maspex-api

aws cloudwatch get-metric-statistics --namespace AWS/ApplicationELB --metric-name RequestCount --dimensions Name=LoadBalancer,Value=app/maspex-uat/68317764a66425bd
aws cloudwatch get-metric-statistics --namespace AWS/ApplicationELB --metric-name TargetResponseTime --dimensions Name=LoadBalancer,Value=app/maspex-uat/68317764a66425bd Name=TargetGroup,Value=targetgroup/maspex-uat-api-3000/97cac4c72be43344
aws cloudwatch get-metric-statistics --namespace AWS/ApplicationELB --metric-name TargetConnectionErrorCount
aws cloudwatch get-metric-statistics --namespace AWS/ApplicationELB --metric-name UnHealthyHostCount
aws cloudwatch get-metric-statistics --namespace AWS/ApplicationELB --metric-name HTTPCode_Target_4XX_Count
aws cloudwatch get-metric-statistics --namespace AWS/ApplicationELB --metric-name HTTPCode_Target_5XX_Count
aws cloudwatch get-metric-statistics --namespace AWS/ApplicationELB --metric-name HTTPCode_ELB_5XX_Count
aws elbv2 describe-target-health --target-group-arn arn:aws:elasticloadbalancing:eu-west-1:969209893152:targetgroup/maspex-uat-api-3000/97cac4c72be43344

aws cloudwatch get-metric-statistics --namespace AWS/CloudFront --metric-name Requests --region us-east-1
aws cloudwatch get-metric-statistics --namespace AWS/CloudFront --metric-name BytesDownloaded --region us-east-1
aws cloudwatch get-metric-statistics --namespace AWS/CloudFront --metric-name 4xxErrorRate --region us-east-1
aws cloudwatch get-metric-statistics --namespace AWS/CloudFront --metric-name 5xxErrorRate --region us-east-1
aws cloudwatch get-metric-statistics --namespace AWS/CloudFront --metric-name CacheHitRate --region us-east-1
aws cloudwatch get-metric-statistics --namespace AWS/CloudFront --metric-name OriginLatency --region us-east-1
aws cloudwatch get-metric-statistics --namespace AWS/CloudFront --metric-name OriginRequests --region us-east-1
aws cloudfront get-distribution-config --id E3J76RNXIE2YIG

aws elasticache describe-cache-clusters --cache-cluster-id maspex-uat --show-cache-node-info
aws cloudwatch get-metric-statistics --namespace AWS/ElastiCache --metric-name CPUUtilization --dimensions Name=CacheClusterId,Value=maspex-uat Name=CacheNodeId,Value=0001
aws cloudwatch get-metric-statistics --namespace AWS/ElastiCache --metric-name EngineCPUUtilization
aws cloudwatch get-metric-statistics --namespace AWS/ElastiCache --metric-name DatabaseMemoryUsagePercentage
aws cloudwatch get-metric-statistics --namespace AWS/ElastiCache --metric-name CurrConnections
aws cloudwatch get-metric-statistics --namespace AWS/ElastiCache --metric-name NewConnections
aws cloudwatch get-metric-statistics --namespace AWS/ElastiCache --metric-name Evictions
aws cloudwatch get-metric-statistics --namespace AWS/ElastiCache --metric-name SwapUsage

aws logs describe-log-groups --log-group-name-prefix /maspex/
aws logs start-query / get-query-results (12 queries dla contest-service, admin-panel, bot)
```

### Uzyte log groups

```
/maspex/uat/contest-service
/maspex/uat/admin-panel
/maspex/uat/bot
```

### Uzyte metryki

```
AWS/ECS: CPUUtilization, MemoryUtilization
AWS/ApplicationELB: RequestCount, TargetResponseTime, TargetConnectionErrorCount,
  UnHealthyHostCount, HTTPCode_Target_4XX_Count, HTTPCode_Target_5XX_Count, HTTPCode_ELB_5XX_Count
AWS/CloudFront: Requests, BytesDownloaded, 4xxErrorRate, 5xxErrorRate,
  CacheHitRate, OriginLatency, OriginRequests
AWS/ElastiCache: CPUUtilization, EngineCPUUtilization, DatabaseMemoryUsagePercentage,
  CurrConnections, NewConnections, Evictions, SwapUsage
```

---

## Missing or unavailable data

| Dane | Status | Wplyw |
|---|---|---|
| CloudFront `CacheHitRate` | brak datapoints (additional metrics nie wlaczone) | Brak globalnego cache hit ratio; estymacja przez delta CF/ALB |
| CloudFront `OriginLatency` | brak datapoints | Brak origin latency z perspektywy CF |
| CloudFront `OriginRequests` | brak datapoints | Brak bezposredniego origin request count z CF |
| CloudFront per-path metrics | niedostepne w standardowych metrykach | Brak split `/api/slogan` vs static vs default |
| Redis client pool state | brak metryk aplikacyjnych | Nie mozna potwierdzic rozmiaru poola w chwili testu z zewnatrz |
| Przyczyna CurrConnections 30→5 | brak eventu w ECS/CloudWatch | Nie wiadomo co spowodowalo drop polaczen 10 min przed testem |
| Stan votow podczas circuit open | brak dostepu do kodu/DB | Nie wiadomo czy votes byly tracone przez 25 minut testu |
| Test runner metrics (client-side latency) | niedostepne w AWS | Brak porownania AWS vs klient dla latency/error rate |

---

## Różnice względem poprzednich load testów

### Porownanie kluczowych metryk

| Metryka | 2026-04-28 | 2026-04-29 | **2026-05-05** |
|---|---:|---:|---:|
| CF total requests | ~1.04M | ~2.48M | **~1.44M** |
| ALB total requests | ~575K | ~1.45M | **~672K** |
| Peak ALB bucket (5min) | 250K | 787K | **255K** |
| CF/ALB offload ratio | ~45% | ~42% | **~53%** |
| `HTTPCode_ELB_5XX_Count` | 1 | 105 | **0** |
| API max TargetResponseTime | 11.0s (outlier) | **29.99s** | **0.8s** |
| ECS CPU avg peak | 13.94% | 43.21% | **11.64%** |
| ECS task churn | 0 | 1 unhealthy | **0** |
| `Redis circuit open` count | 0 | 1,758 (1 min) | **~299,512 (25 min)** |
| `VOTE_CACHE_WRITETHROUGH_FAIL` | 0 | ~1,758 | **~305,358** |
| ALB UnHealthyHostCount | 0 | 1 (krotko) | **0** |
| CF `5xxErrorRate` | 0% | 0.04% | **0%** |
| Test duration (aktywny ruch) | ~20 min | ~30 min | **~25 min** |

### Kluczowe roznicy May 5 vs April 29

1. **Test byl 3x lzejszy** (ALB peak 255K vs 787K req/5min) — nie doszlo do HTTP-level degradacji.

2. **Redis circuit otworzyl sie natychmiast** (10 minut w test), nie na peaku jak w April 29. To wskazuje na zmiane stanu Redis klienta (CurrConnections 30→5 anomalia).

3. **Masowy wzrost liczby Redis bledow**: 305K vs 1.8K. Paradoksalnie, API layer nie zdegradowalo — bo circuit breaker dziala jako fail-fast (brak blokowania na timeoutach).

4. **Brak ELB 5XX i tail latency** w May 5 (vs 105 ELB 5XX, max 29.99s w April 29). Zmiana moze wynikac z nowej task def `:53` (inne timeouty, inne zachowanie Redis client), nizszeho obciazenia, lub obu.

5. **CloudFront wyzszy offload** (53% vs 42%). Mozliwa przyczyna: lepsze cache hit dla `/api/slogan` lub `/email/*` (nowa regula), albo inny wzorzec ruchu testowego.

6. **Brak dynamicznego scale-out** — identycznie jak w poprzednich testach. Autoscaling nie zadziala dla tego wzorca obciazenia (wszystko poniżej progów CPU/memory).

### Progresja testow

| Test | Charakterystyka | Wynik |
|---|---|---|
| 2026-04-28 | Sredni load, brak Redis errors | Czyste; brak bottlenecku |
| 2026-04-29 | Ciezki load; Redis circuit open na peak (1 min) | Degradacja: ELB 5XX, tail latency, API healthcheck |
| **2026-05-05** | **Sredni load; Redis circuit open od startu (25 min)** | **Brak HTTP degradacji; silna Redis write-through failure** |
