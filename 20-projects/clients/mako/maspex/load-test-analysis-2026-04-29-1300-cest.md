# Maspex UAT — Load Test Analysis — 2026-04-29 13:00 CEST

## 1. Executive Summary

Load test 2026-04-29 byl wyraznie mocniejszy niz poprzedni test z 2026-04-28.

W oknie rozszerzonym `2026-04-29 10:30-12:00 UTC` CloudFront obsluzyl ok. `2.48M` requestow, a ALB ok. `1.45M` requestow. Najwiekszy ruch przypadl na `11:25 UTC`: CloudFront `1.35M req/5 min`, ALB `787k req/5 min`.

Autoscaling dla `maspex-api` byl wlaczony (`min=9`, `max=15`, target tracking CPU 60%, memory 75%), ale nie wykonal scale-out. Service average CPU i memory pozostaly ponizej progow, mimo ze pojedynczy CPU datapoint osiagnal prawie 100%.

Najmocniejsze sygnaly degradacji:

- `maspex-api` mial unhealthy target przez ALB `Request timed out` ok. `11:27 UTC`.
- ALB pokazal `105` `HTTPCode_ELB_5XX_Count` w przedziale `11:25-11:30 UTC`.
- Target response time dla API mial spike: maksimum `29.99s` w przedziale `11:25-11:30 UTC`.
- Logi aplikacyjne API pokazaly `1758` wpisow `Redis circuit open` w jednej minucie `11:26 UTC`.

Redis/ElastiCache jako usluga nie wygladal na metryczny bottleneck: CPU niskie, pamiec bardzo niska, connections umiarkowane, evictions `0`, swap `0`. Bardziej prawdopodobny jest problem po stronie aplikacyjnego klienta/circuit-breakera Redis lub sciezki vote/cache write-through pod szczytowym ruchem, nie saturacja samego ElastiCache.

CloudFront prawdopodobnie odciazal origin: roznica CloudFront vs ALB to ok. `1.03M` requestow mniej na ALB. Nie da sie jednak jednoznacznie potwierdzic per-path cache hit dla `/api/slogan`, bo `CacheHitRate`/`OriginRequests` nie zwrocily datapoints, a odczyt standard logs z S3 nie byl dostepny podczas analizy.

Najbardziej prawdopodobny bottleneck: mieszany scenariusz `origin/app tail latency + aplikacyjny Redis circuit`, bez potwierdzonej saturacji ECS CPU/memory ani ElastiCache.

## 2. Scope i time window

Analizowane okno:

| Zakres | UTC | CEST |
|---|---:|---:|
| Glowne | `2026-04-29 10:45-11:45` | `2026-04-29 12:45-13:45` |
| Rozszerzone | `2026-04-29 10:30-12:00` | `2026-04-29 12:30-14:00` |

Zrodla:

- ECS service state/events/tasks
- Application Auto Scaling targets, policies, activities
- CloudWatch metrics: ECS, ALB, CloudFront, ElastiCache
- CloudWatch Logs Insights: `/maspex/uat/contest-service`, `/maspex/uat/admin-panel`, `/maspex/uat/bot`
- CloudFront live distribution config
- ALB target health

Zasoby:

| Obszar | Zasob |
|---|---|
| CloudFront | `E3J76RNXIE2YIG`, `kapsel.makotest.pl` |
| ALB | `app/maspex-uat/68317764a66425bd` |
| API TG | `targetgroup/maspex-uat-api-3000/97cac4c72be43344` |
| ECS cluster | `maspex-uat` |
| ECS services | `maspex-api`, `maspex-admin-panel`, `maspex-bot` |
| ElastiCache | `maspex-uat` |

## 3. Timeline

| Timestamp UTC | Komponent | Zdarzenie | Znaczenie |
|---|---|---|---|
| 10:30-10:55 | Baseline | CloudFront/ALB bardzo niski ruch | Srodowisko przed testem praktycznie idle |
| 11:00 | CloudFront/ALB | Poczatek wzrostu: CF `770 req/5m`, ALB `386 req/5m` | Start ruchu testowego |
| 11:05 | CloudFront/ALB | CF `29,344`, ALB `17,499` | Ruch narasta |
| 11:10 | CloudFront/ALB | CF `124,267`, ALB `74,072` | Stabilny ramp-up |
| 11:15 | CloudFront/ALB | CF `367,128`, ALB `213,982` | Origin zaczyna dostawac duzy ruch |
| 11:20 | CloudFront/ALB | CF `576,897`, ALB `341,118` | Wysoki load, response max API `4.84s` |
| 11:25 | CloudFront/ALB/API | CF `1,350,136`, ALB `787,455`; API max response `29.99s`; ALB `105` ELB 5XX | Peak i glowny epizod degradacji |
| 11:26 | App logs | `1758` wpisow `Redis circuit open` | Najmocniejszy sygnal aplikacyjny korelujacy z peakiem |
| 11:27 | ECS/API | API task unhealthy: ALB health check `Request timed out` | ECS wymienia task po braku zdrowia |
| 11:30 | CloudFront/ALB | CF `29,399`, ALB `10,866` | Test wygasa bardzo szybko |
| 11:39-11:42 | ECS/API | Deployment/rolling replacement `maspex-api:52`, 9 taskow wymienionych | Zdarzenie operacyjne w oknie, po peaku; moze zaklocac interpretacje task churn |
| 12:00+ | ECS/Bot | Bot nadal ma task replacements i health check failures | Osobny problem operacyjny, slabo powiazany z API load testem |

## 4. ECS / Auto Scaling

### Current service state

| Service | Desired | Running | Pending | Task definition | Rollout |
|---|---:|---:|---:|---|---|
| `maspex-api` | 9 | 9 | 0 | `maspex-api:52` | `COMPLETED` |
| `maspex-admin-panel` | 1 | 1 | 0 | `maspex-admin-panel:25` | `COMPLETED` |
| `maspex-bot` | 1 | 1 | 0 | `maspex-bot:8` | `IN_PROGRESS` |

### Autoscaling

`maspex-api`:

| Parametr | Wartosc |
|---|---:|
| Min capacity | 9 |
| Max capacity | 15 |
| CPU target | 60% |
| Memory target | 75% |
| Scale-out cooldown | 60s |
| Scale-in cooldown | 300s |

Scaling activities:

| Time | Activity | Wynik |
|---|---|---|
| 2026-04-28 06:46 UTC | `Setting desired count to 9` | Successful |

W oknie testu 2026-04-29 nie bylo nowych scaling activities. Brak scale-out jest spojny z metrykami service average: CPU i memory nie przekroczyly targetow target tracking.

### ECS CPU / memory

`maspex-api`:

| Metryka | Baseline | Peak |
|---|---:|---:|
| CPUUtilization Average | ok. 0.3-2.1% przed testem | `43.21%` avg w 11:25-11:30 UTC |
| CPUUtilization Maximum | zwykle do kilku % | `99.38%` max w 11:25-11:30 UTC |
| MemoryUtilization Average | ok. 65% przed 10:50, potem nisko | `44.28%` avg w 11:25-11:30 UTC |
| MemoryUtilization Maximum | ok. 73.9% baseline | `58.11%` w 11:25-11:30 UTC |

Interpretacja:

- Autoscaling patrzy na srednia uslugi, nie na pojedynczy maksimum CPU.
- Pojedyncze taski/proby mogly byc przeciazone, ale service average nie wymusil scale-out.
- `desired=9` wyglada jak pre-scale/min-capacity, a nie dynamiczny scale-out w trakcie testu.

### Task churn / service events

API:

- `11:27 UTC`: ECS zastapil 1 task z powodu unhealthy status.
- ALB powod: health check `/api/health` zakonczyl sie `Request timed out`.
- `11:39-11:42 UTC`: deployment/rolling replacement `maspex-api:52`, 9 taskow wymienionych; zdarzenie wystapilo po glownym peaku, ale jeszcze w oknie analizy.

Admin:

- Stabilny w czasie glownego testu.
- Deployment admina zakonczony przed glownym ruchem (`10:29 UTC`).

Bot:

- Niezalezny problem: wiele taskow `maspex-bot:8` zatrzymanych przez ELB health checks, exit code `1`.
- Live target health po analizie: jeden target `draining`, jeden `unhealthy`.
- Bot nie wyglada na glowny element sciezki `kapsel.makotest.pl`, ale wymaga osobnej naprawy.

## 5. ALB

### Request volume

ALB `RequestCount` w 5-minutowych bucketach:

| UTC | RequestCount |
|---|---:|
| 10:35 | 225 |
| 11:00 | 386 |
| 11:05 | 17,499 |
| 11:10 | 74,072 |
| 11:15 | 213,982 |
| 11:20 | 341,118 |
| 11:25 | 787,455 |
| 11:30 | 10,866 |
| 11:35-11:55 | 268 lacznie |

Total ALB request count w oknie rozszerzonym: ok. `1,445,871`.

### Response time

API target group `TargetResponseTime`:

| UTC | Average | Maximum |
|---|---:|---:|
| 11:05 | 0.019s | 0.779s |
| 11:10 | 0.018s | 0.892s |
| 11:15 | 0.018s | 0.884s |
| 11:20 | 0.030s | 4.842s |
| 11:25 | 0.491s | 29.991s |
| 11:30 | 0.025s | 0.713s |

Interpretacja:

- Srednia pozostala akceptowalna poza peak bucketem.
- Maksimum `29.99s` w 11:25 bucket jest silnym sygnalem tail latency / timeout pressure.

### Errors and health

| Metryka | Wynik |
|---|---:|
| `TargetConnectionErrorCount` | brak datapoints / 0 |
| `UnHealthyHostCount` API | 0 w metryce 5-min, mimo ECS eventu pojedynczego unhealthy taska |
| `HTTPCode_Target_5XX_Count` API | brak datapoints / 0 |
| `HTTPCode_ELB_5XX_Count` | `105` w 11:25-11:30 UTC |
| `HTTPCode_Target_4XX_Count` API | `5,778` total, peak `4,369` w 11:25-11:30 UTC |

Wniosek: origin/ALB pokazal realny, krotki epizod degradacji w peak bucket, glownie przez ELB 5XX i tail latency, nie przez target 5XX.

## 6. CloudFront

### Live config sanity check

Distribution `E3J76RNXIE2YIG`:

| Element | Wartosc |
|---|---|
| Alias | `kapsel.makotest.pl` |
| Origin | `maspex-uat-1361582173.eu-west-1.elb.amazonaws.com` |
| WebACL | `maspex-uat-public-uat-allowlist` |
| Standard logging | enabled, prefix `cloudfront/maspex-uat/api` |

Ordered behaviors:

| Precedence | Path pattern | Cache model |
|---:|---|---|
| 1 | `/api/slogan` | dedicated API cache policy |
| 2 | `/_next/image*` | dedicated image optimizer cache policy |
| 3 | `/_next/static/*` | static assets cache policy |
| 4 | `/landing/*` | static assets cache policy |
| 5 | `/favicon.ico` | static assets cache policy |
| default | `*` | managed caching disabled |

### Request volume

CloudFront `Requests`:

| UTC | Requests |
|---|---:|
| 11:00 | 770 |
| 11:05 | 29,344 |
| 11:10 | 124,267 |
| 11:15 | 367,128 |
| 11:20 | 576,897 |
| 11:25 | 1,350,136 |
| 11:30 | 29,399 |

Total CloudFront requests w oknie rozszerzonym: ok. `2,479,052`.

Bytes downloaded: ok. `36.59 GB` decimal (`~34.08 GiB`).

### Errors

| Metryka | Obserwacja |
|---|---|
| `4xxErrorRate` | w czasie peaku nisko: ok. `0.06-0.32%`; wysokie 100% tylko przy bardzo niskim baseline traffic |
| `5xxErrorRate` | tylko `0.0407%` average w 11:25 bucket; odpowiada ALB/ELB 5XX spike |

### Cache / origin behavior

CloudFront vs ALB:

| Metric | Requests |
|---|---:|
| CloudFront total | `~2,479,052` |
| ALB total | `~1,445,871` |
| Delta | `~1,033,181` |

Delta oznacza, ze ok. `41.7%` requestow widocznych na CloudFront nie pojawilo sie jako ALB requests. To jest zgodne z edge offload / cache behavior / ewentualnym edge filtering. Nie mozna jednak przypisac tej roznicy konkretnie do `/api/slogan`, bo:

- CloudFront `CacheHitRate` nie zwrocil datapoints.
- CloudFront `OriginRequests` nie zwrocil datapoints.
- Odczyt standard logs z S3 nie byl dostepny w trakcie analizy z powodu bledu polaczenia z endpointem S3.

Wniosek per path:

| Path | Ocena |
|---|---|
| `/api/slogan` | Behavior istnieje i jest pierwszy w precedence; realny cache hit niepotwierdzony per-path |
| `/_next/image*` | Behavior istnieje; brak per-path origin pressure z logow |
| `/_next/static/*` | Behavior istnieje; brak per-path potwierdzenia z logow |

## 7. Redis / ElastiCache

ElastiCache `maspex-uat` w oknie rozszerzonym:

| Metryka | Baseline | Peak / max |
|---|---:|---:|
| `CPUUtilization` | ok. 1.8-2.0% | max `7.52%` |
| `EngineCPUUtilization` | ok. 0.23% | max `5.80%` |
| `DatabaseMemoryUsagePercentage` | ok. 0.32% | max `0.58%` |
| `CurrConnections` | ok. 4-5 | max `45` |
| `NewConnections` | pojedyncze bursty | ok. `45` total w oknie |
| `Evictions` | 0 | 0 |
| `SwapUsage` | 0 | 0 |

Metryki Redis nie pokazuja saturacji. To jest wazne, bo aplikacja masowo logowala `Redis circuit open` w tym samym czasie. Najbardziej prawdopodobna interpretacja: problem w aplikacyjnym circuit breakerze, polaczeniach klienta, timeoutach klienta lub sciezce write-through, a nie w zasobach ElastiCache jako takich.

## 8. Logi aplikacyjne

Log groupy:

- `/maspex/uat/contest-service`
- `/maspex/uat/admin-panel`
- `/maspex/uat/bot`

### API / contest-service

CloudWatch Logs Insights:

| Sygnal | Count | Timing |
|---|---:|---|
| `Redis circuit open` | `1758` | wszystko w `11:26 UTC` |
| `AuthApiError` / invalid refresh token | `4` | `10:37 UTC` |
| `aborted` | `2` | w peak bucket `11:25 UTC` |
| `GET_SLOGANS_COUNT` | `0` | brak trafien w logach |
| `502` | `0` | brak trafien w logach |
| `statement timeout` / `pool timeout` | brak potwierdzonych trafien | brak |

Przykladowy dominujacy wpis:

```text
2026-04-29 11:26:19: [VOTE_CACHE_WRITETHROUGH_FAIL] Error: Redis circuit open
```

### Admin panel

Brak dopasowan do wzorcow degradacji w analizowanym oknie.

### Bot

Bot mial osobny problem:

| Sygnal | Count / pattern |
|---|---|
| `npm error ... SIGTERM` / `command failed` | 60 wpisow |
| ECS stopped tasks | exit code `1`, stopped reason `Task failed ELB health checks` |
| Target health | jeden target `draining`, jeden `unhealthy` po analizie |

To wyglada na osobny problem stabilnosci `maspex-bot`, nie na glowny bottleneck testu API.

## 9. Korelacja sygnałów

Najwazniejsza korelacja:

1. Ruch zaczal narastac od `11:00 UTC`.
2. Peak byl w `11:25-11:30 UTC`.
3. W tym samym bucket:
   - ALB `RequestCount` = `787,455`
   - CloudFront `Requests` = `1,350,136`
   - API `TargetResponseTime Maximum` = `29.99s`
   - ALB `HTTPCode_ELB_5XX_Count` = `105`
   - API logs: `1758` x `Redis circuit open` w `11:26 UTC`
   - ECS: API task unhealthy `Request timed out` ok. `11:27 UTC`

Co wyglada na przyczyne:

- Peak request pressure na origin/API.
- Aplikacyjny Redis circuit/write-through failure w czasie peaku.
- Tail latency i timeout na health checku API.

Co wyglada na skutek:

- `HTTPCode_ELB_5XX_Count` spike.
- ECS replacement jednego API taska.
- Szybkie wygaszenie ruchu po 11:30.

Co wyglada na szum lub osobny temat:

- Auth refresh token errors z 10:37 UTC: poza peakiem, tylko 4 wpisy.
- Bot health-check loop: realny problem, ale osobna sciezka od `kapsel.makotest.pl` API.

## 10. Najbardziej prawdopodobny bottleneck

Ocena:

| Kandydat | Ocena |
|---|---|
| ECS / CPU | Nie jako service average; pojedynczy CPU max byl wysoki, ale srednia ponizej targetu |
| ECS / memory | Nie |
| ALB / origin saturation | Czesciowo tak: tail latency `29.99s`, `105` ELB 5XX, healthcheck timeout |
| Redis service | Niepotwierdzone; metryki ElastiCache zdrowe |
| Redis client/circuit breaker | Tak, bardzo mocny sygnal aplikacyjny |
| CloudFront inefficiency | Niepotwierdzone; CF odciaza origin ilosciowo, ale brak per-path danych |
| downstream DB / Supabase | Brak bezposredniego dowodu w zebranych logach |

Najbardziej prawdopodobny bottleneck: mieszany scenariusz `API/origin tail latency + aplikacyjny Redis circuit breaker/write-through path` przy peaku. Brak dowodu na twarda saturacje ElastiCache albo ECS service average.

## 11. Co wykluczono

| Wykluczenie | Dowod |
|---|---|
| Brak dynamicznego scale-out | Application Auto Scaling activities nie maja wpisow z 2026-04-29; tylko min capacity set do 9 z 2026-04-28 |
| Redis jako zasobowo przeciazony backend | CPU max `7.52%`, EngineCPU max `5.80%`, memory max `0.58%`, evictions `0`, swap `0` |
| Target 5XX jako glowny blad | `HTTPCode_Target_5XX_Count` brak datapoints / 0 |
| Target connection errors | `TargetConnectionErrorCount` brak datapoints / 0 |
| Admin panel jako element degradacji | Brak dopasowanych logow degradacji i steady state |
| Auth jako przyczyna peaku | tylko 4 invalid refresh token przed peakiem |

Nie wykluczono:

- App-level Redis client pool/circuit breaker saturation.
- Downstream latency w sciezce vote/write-through.
- Per-path origin pressure dla `/api/slogan` i `/_next/image*`, bo brak per-path logs/OriginRequests datapoints.

## 12. Recommended next steps

1. Zbadac implementacje `VOTE_CACHE_WRITETHROUGH_FAIL` i warunki otwierania Redis circuit breaker; policzyc timeouty/thresholds/pool size po stronie klienta.
2. Dodac aplikacyjne metryki dla Redis client: pool wait, command latency, circuit state, write-through failures.
3. Zmienic autoscaling sygnal dla API: rozwazyc dodatkowy target/policy na ALB request count per target albo custom latency/error metric, bo CPU average nie wyzwolil scale-out.
4. Ustalic, czy `desired=9` jest wystarczajacym pre-scale dla testu >2M CF requests; przetestowac min=12/15 przed kolejnym testem.
5. Naprawic osobny problem `maspex-bot`: health checks + exit code 1 / npm SIGTERM loop.
6. Odblokowac per-path CloudFront standard logs analysis w S3/Athena i potwierdzic cache hit dla `/api/slogan`, `/_next/image*`, `/_next/static/*`.
7. Skorelowac app logs z request IDs / route-level latency dla 11:25-11:27 UTC.

## 13. Evidence

Uzyte komendy / zrodla:

```text
aws ecs describe-services --cluster maspex-uat --services maspex-api maspex-admin-panel maspex-bot
aws ecs list-tasks --cluster maspex-uat --service-name maspex-api --desired-status STOPPED
aws ecs list-tasks --cluster maspex-uat --service-name maspex-bot --desired-status STOPPED
aws ecs describe-tasks --cluster maspex-uat --tasks <bot stopped task arns>

aws application-autoscaling describe-scalable-targets --service-namespace ecs
aws application-autoscaling describe-scaling-policies --service-namespace ecs --resource-id service/maspex-uat/maspex-api
aws application-autoscaling describe-scaling-activities --service-namespace ecs --resource-id service/maspex-uat/maspex-api

aws cloudfront get-distribution-config --id E3J76RNXIE2YIG

aws elbv2 describe-load-balancers --names maspex-uat
aws elbv2 describe-target-groups
aws elbv2 describe-target-health --target-group-arn <api/admin/bot tg>

aws cloudwatch get-metric-statistics --namespace AWS/ECS --metric-name CPUUtilization
aws cloudwatch get-metric-statistics --namespace AWS/ECS --metric-name MemoryUtilization
aws cloudwatch get-metric-statistics --namespace AWS/ApplicationELB --metric-name RequestCount
aws cloudwatch get-metric-statistics --namespace AWS/ApplicationELB --metric-name TargetResponseTime
aws cloudwatch get-metric-statistics --namespace AWS/ApplicationELB --metric-name TargetConnectionErrorCount
aws cloudwatch get-metric-statistics --namespace AWS/ApplicationELB --metric-name UnHealthyHostCount
aws cloudwatch get-metric-statistics --namespace AWS/ApplicationELB --metric-name HTTPCode_Target_4XX_Count
aws cloudwatch get-metric-statistics --namespace AWS/ApplicationELB --metric-name HTTPCode_Target_5XX_Count
aws cloudwatch get-metric-statistics --namespace AWS/ApplicationELB --metric-name HTTPCode_ELB_5XX_Count
aws cloudwatch get-metric-statistics --namespace AWS/CloudFront --metric-name Requests
aws cloudwatch get-metric-statistics --namespace AWS/CloudFront --metric-name BytesDownloaded
aws cloudwatch get-metric-statistics --namespace AWS/CloudFront --metric-name 4xxErrorRate
aws cloudwatch get-metric-statistics --namespace AWS/CloudFront --metric-name 5xxErrorRate
aws cloudwatch get-metric-statistics --namespace AWS/CloudFront --metric-name CacheHitRate
aws cloudwatch get-metric-statistics --namespace AWS/CloudFront --metric-name OriginRequests
aws cloudwatch get-metric-statistics --namespace AWS/ElastiCache --metric-name CPUUtilization
aws cloudwatch get-metric-statistics --namespace AWS/ElastiCache --metric-name EngineCPUUtilization
aws cloudwatch get-metric-statistics --namespace AWS/ElastiCache --metric-name DatabaseMemoryUsagePercentage
aws cloudwatch get-metric-statistics --namespace AWS/ElastiCache --metric-name CurrConnections
aws cloudwatch get-metric-statistics --namespace AWS/ElastiCache --metric-name NewConnections
aws cloudwatch get-metric-statistics --namespace AWS/ElastiCache --metric-name Evictions
aws cloudwatch get-metric-statistics --namespace AWS/ElastiCache --metric-name SwapUsage

aws logs start-query / get-query-results for:
  /maspex/uat/contest-service
  /maspex/uat/admin-panel
  /maspex/uat/bot
```

Uzyte log groups:

```text
/maspex/uat/contest-service
/maspex/uat/admin-panel
/maspex/uat/bot
```

Uzyte metryki:

```text
AWS/ECS: CPUUtilization, MemoryUtilization
AWS/ApplicationELB: RequestCount, TargetResponseTime, TargetConnectionErrorCount,
  UnHealthyHostCount, HTTPCode_Target_4XX_Count, HTTPCode_Target_5XX_Count,
  HTTPCode_ELB_5XX_Count
AWS/CloudFront: Requests, BytesDownloaded, 4xxErrorRate, 5xxErrorRate,
  CacheHitRate, OriginRequests
AWS/ElastiCache: CPUUtilization, EngineCPUUtilization,
  DatabaseMemoryUsagePercentage, CurrConnections, NewConnections,
  Evictions, SwapUsage
```

## Missing or unavailable data

| Dane | Status | Wplyw |
|---|---|---|
| CloudFront `CacheHitRate` | brak datapoints | Nie da sie potwierdzic globalnego cache hit ratio z CloudWatch |
| CloudFront `OriginRequests` | brak datapoints | Nie da sie potwierdzic origin pressure bezposrednio z CF additional metrics |
| CloudFront standard logs z S3 | odczyt `aws s3 ls` zakonczyl sie bledem polaczenia z endpointem S3 | Brak per-path analizy logowej dla `/api/slogan`, `/_next/image*`, `/_next/static/*` |
| WAF metrics | brak datapoints dla sprawdzonych metryk | Nie potwierdzono skali blokad WAF w oknie testu |
| API stopped task details | `list-tasks --desired-status STOPPED` dla `maspex-api` nie zwrocil taskow | Przyczyna API unhealthy oparta na ECS service event, nie na stopped task detail |

Istotna roznica wzgledem testu 2026-04-28:

- 2026-04-28: ok. `1.04M` CloudFront requests i ok. `575k` ALB requests; brak potwierdzonej saturacji i brak mocnego Redis signal.
- 2026-04-29: ok. `2.48M` CloudFront requests i ok. `1.45M` ALB requests; pojawil sie krotki, ale realny epizod degradacji: `Redis circuit open`, ALB `ELB 5XX`, tail latency i API healthcheck timeout.
