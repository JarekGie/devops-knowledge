# Maspex UAT — Load Test Analysis — 2026-04-28 17:30 CEST

## 1. Executive Summary

Load test był widoczny w metrykach CloudFront i ALB głównie między 15:40 a 16:00 UTC, z maksimum około 457k requestów CloudFront i 250k requestów ALB/API w 5-minutowym bucketcie.

Środowisko nie wykazało saturacji ECS ani Redis. `maspex-api` pracował stabilnie na 9 taskach, bez task churn w oknie testu. Autoscaling był skonfigurowany tylko dla API, ale nie wykonał scale-out, bo CPU i memory pozostały poniżej progów target tracking.

CloudFront prawdopodobnie odciążył origin częściowo: w okresie testowym CloudFront obsłużył około 1.04M requestów, a ALB API około 575k. Nie da się jednak jednoznacznie policzyć cache hit ratio per path, bo metryki `CacheHitRate`, `OriginRequests` i `OriginLatency` nie zwróciły danych.

Najmocniejszy sygnał: duży ruch dotarł nadal do origin/API, ale origin obsłużył go bez widocznej degradacji w AWS metrics. Brak potwierdzonego bottlenecku po stronie ECS, ALB lub Redis.

## 2. Scope i time window

| Obszar | Wartość |
|---|---|
| Konto AWS | `969209893152` |
| Profil | `maspex-cli` |
| Region aplikacyjny | `eu-west-1` |
| CloudFront metrics region | `us-east-1` |
| Zakres główny | `2026-04-28 15:15:00 UTC` - `2026-04-28 16:15:00 UTC` |
| Zakres rozszerzony | `2026-04-28 15:00:00 UTC` - `2026-04-28 16:30:00 UTC` |
| ECS cluster | `maspex-uat` |
| ECS services | `maspex-api`, `maspex-admin-panel`, `maspex-bot` |
| CloudFront distribution | `E3J76RNXIE2YIG` |
| UAT hostname | `kapsel.makotest.pl` |
| ALB | `maspex-uat` / `app/maspex-uat/68317764a66425bd` |
| API target group | `targetgroup/maspex-uat-api-3000/97cac4c72be43344` |
| Redis | `maspex-uat`, node `0001` |

Źródła: ECS service state/events, Application Auto Scaling, CloudWatch metrics, CloudWatch Logs Insights, ALB target health, CloudFront config/cache policies, ElastiCache metrics.

## 3. Timeline

| Timestamp UTC | Timestamp CEST | Komponent | Zdarzenie | Znaczenie |
|---|---:|---|---|---|
| 06:46-06:47 | 08:46-08:47 | ECS/API | Desired count ustawiony na 9, uruchomiono 3 dodatkowe taski | Capacity podniesione przed testem |
| 12:47 | 14:47 | ECS/API | `maspex-api` reached steady state | API stabilne przed oknem testowym |
| 15:00-15:35 | 17:00-17:35 | CF/ALB | Baseline: około 15 requestów / 5 min | Brak ruchu testowego |
| 15:40 | 17:40 | CF/ALB | Start wyraźnego wzrostu ruchu | Początek właściwego load testu |
| 15:45 | 17:45 | CF/ALB | CF 117,571 req / 5 min; ALB API 65,297 req / 5 min | Ruch narasta |
| 15:45 | 17:45 | ALB | 1 `HTTPCode_ELB_5XX_Count`; 2 target 4xx | Pojedynczy błąd, bez utrzymanej serii |
| 15:50 | 17:50 | CF/ALB/ECS | CF 457,558 req / 5 min; ALB API 250,342 req / 5 min; API CPU avg 13.9%, max 33.5% | Szczyt testu bez saturacji CPU |
| 15:55 | 17:55 | CF/ALB | CF 318,290 req / 5 min; ALB API 176,362 req / 5 min | Ruch nadal wysoki |
| 16:00 | 18:00 | CF/ALB | CF 123,978 req / 5 min; ALB API 69,303 req / 5 min | Wygaszanie testu |
| 16:05+ | 18:05+ | CF/ALB | Powrót do baseline około 15 requestów / 5 min | Koniec testu |
| 19:04+ | 21:04+ | ECS/Bot | Bot task replacement przez ELB health checks | Poza oknem testu; nie koreluje z load testem |

## 4. ECS / Auto Scaling

### Service state

| Service | Desired | Running | Pending | Rollout | Task definition |
|---|---:|---:|---:|---|---|
| `maspex-api` | 9 | 9 | 0 | `COMPLETED` | `maspex-api:50` |
| `maspex-admin-panel` | 1 | 1 | 0 | `COMPLETED` | `maspex-admin-panel:24` |
| `maspex-bot` | 1 | 1 | 0 | `IN_PROGRESS` | `maspex-bot:8` |

`maspex-bot` miał późniejszy churn około 21:04-22:15 CEST, poza analizowanym load testem.

### Auto Scaling

| Resource | Min | Max | Policy | Target | Cooldown |
|---|---:|---:|---|---:|---|
| `service/maspex-uat/maspex-api` | 9 | 15 | CPU target tracking | 60% | out 60s / in 300s |
| `service/maspex-uat/maspex-api` | 9 | 15 | Memory target tracking | 75% | out 60s / in 300s |

Scaling activities: tylko jedna aktywność, `Setting desired count to 9`, start `2026-04-28 06:46:35 UTC`, zakończona sukcesem. Brak scale-out w trakcie testu.

### ECS metrics

| Service | Metric | Baseline | Peak in test | Ocena |
|---|---|---:|---:|---|
| `maspex-api` | CPU avg | około 1.3% | 13.94% avg / 33.51% max at 15:50 UTC | Daleko poniżej progu 60% |
| `maspex-api` | Memory avg | około 51.8% | 53.37% avg / 60.19% max at 15:55 UTC | Poniżej progu 75% |
| `maspex-admin-panel` | CPU avg | <0.2% | <0.45% max | Nieuczestniczący w obciążeniu |
| `maspex-admin-panel` | Memory | około 4.64% | stabilne | Bez wpływu |
| `maspex-bot` | CPU max | zmienne krótkie piki | 52.49% max at 15:35 UTC | Nie koreluje z ALB/API peak |
| `maspex-bot` | Memory | około 4% | <5.9% | Bez saturacji |

Wniosek: autoscaling nie zadziałał, bo nie było sygnału skalującego. To zachowanie jest zgodne z konfiguracją.

## 5. ALB

### API target group metrics

| Window UTC | RequestCount | TargetResponseTime avg | TargetResponseTime p95 | Target 4xx | Target 5xx | ELB 5xx | Unhealthy hosts |
|---|---:|---:|---:|---:|---:|---:|---:|
| 15:40 | 14,050 | 29.7 ms | 44.4 ms | 0 | 0 | 0 | 0 |
| 15:45 | 65,297 | 29.0 ms | 44.4 ms | 2 | 0 | 1 | 0 |
| 15:50 | 250,342 | 29.2 ms | 43.2 ms | 9 | 0 | 0 | 0 |
| 15:55 | 176,362 | 55.4 ms | 191.4 ms | 4 | 0 | 0 | 0 |
| 16:00 | 69,303 | 143.0 ms | 773.9 ms | 2 | 0 | 0 | 0 |

Łącznie w rozszerzonym oknie ALB API obsłużył około 575,851 requestów. W samym piku 15:40-16:00 UTC było około 575,354 requestów.

Nie było target connection errors. API target group miał 9 zdrowych targetów po teście.

Wniosek: ALB/API origin przyjął duży ruch, ale metryki nie wskazują na trwałe przeciążenie. Najwyższy `TargetResponseTime Maximum` pojawił się o 15:50 UTC jako 11.02 s, ale p95 w tym samym bucketcie wynosił około 43 ms, więc wygląda to na outlier, nie na systemową degradację.

## 6. CloudFront

### Distribution config

| Path pattern | Cache policy | Default TTL | Max TTL | Origin request policy |
|---|---|---:|---:|---|
| `/api/slogan` | `kapsel-makotest-pl-api--api-slogan` | 60 s | 600 s | Host + query whitelist |
| `/_next/image*` | `kapsel-makotest-pl-image-optimizer` | 86400 s | 2592000 s | Managed/CORS-S3-like policy |
| `/_next/static/*` | `kapsel-makotest-pl-static-assets` | 86400 s | 31536000 s | Managed/CORS-S3-like policy |

`/api/slogan` cache key nie zawiera headers ani cookies. Query string whitelist: `search`, `sortBy`, `page`.

### CloudFront metrics

| Window UTC | Requests | 4xxErrorRate avg | 5xxErrorRate avg | BytesDownloaded |
|---|---:|---:|---:|---:|
| 15:40 | 25,079 | 0% | 0% | 1.57 GB |
| 15:45 | 117,571 | 0.0017% | 0.00085% | 7.31 GB |
| 15:50 | 457,558 | 0.00197% | 0% | 28.07 GB |
| 15:55 | 318,290 | 0.00126% | 0% | 19.77 GB |
| 16:00 | 123,978 | 0.00161% | 0% | 7.78 GB |

Łącznie CloudFront obsłużył około 1,043,196 requestów w rozszerzonym oknie, z czego około 1,042,476 w okresie 15:40-16:00 UTC.

Porównanie CF vs ALB API w okresie 15:40-16:00 UTC:

| Warstwa | Request count |
|---|---:|
| CloudFront | 1,042,476 |
| ALB API target group | 575,354 |
| Różnica | około 467,122 |

To sugeruje częściowe odciążenie origin przez CloudFront, ale nie potwierdza jednoznacznie cache hit ratio dla `/api/slogan`, bo brakuje metryk per path i dodatkowych metryk cache/origin.

## 7. Redis / ElastiCache

| Metric | Wartość w oknie | Ocena |
|---|---:|---|
| `EngineCPUUtilization` | około 0.23%-0.27% max | Brak saturacji Redis engine |
| `CPUUtilization` | około 1.8%-3.0% max | Brak saturacji hosta |
| `DatabaseMemoryUsagePercentage` | około 0.32% | Bardzo niski poziom użycia |
| `CurrConnections` | 4-5 | Stabilne, niskie |
| `NewConnections` | 0 | Brak churn połączeń |
| `Evictions` | 0 | Brak presji pamięci |
| `SwapUsage` | 0 | Brak swap |

Wniosek: Redis nie wygląda na limiter ani współwinnego dla tego testu.

## 8. Logi aplikacyjne

Analizowane log groups:

| Log group | Wynik |
|---|---|
| `/maspex/uat/contest-service` | 122 rekordy w oknie głównym; regularny `CACHE-CRON`; 0 dopasowań dla błędów |
| `/maspex/uat/admin-panel` | 0 rekordów / 0 dopasowań w oknie |
| `/maspex/uat/bot` | 230 rekordów przeskanowanych w rozszerzonym oknie; 0 dopasowań dla szukanych sygnałów |
| `/aws/elasticache/maspex-uat/redis` | 0 rekordów w oknie |

Szukane sygnały:

| Sygnał | Count | Uwagi |
|---|---:|---|
| `timeout` / `pool timeout` / `statement timeout` | 0 w oknie głównym | Brak potwierdzonego timeout bottleneck |
| `aborted` | 0 | Brak potwierdzenia abortów |
| `502` | 0 w app logs | ALB miał 1 ELB 5xx w metryce |
| `GET_SLOGANS_COUNT` | 0 | Brak logowego potwierdzenia liczby origin hits dla slogans |
| `Redis circuit open` | 0 | Brak problemu Redis circuit |
| `AuthApiError` / `refresh token` | 0 | Brak korelacji auth |
| `cache cron` | regularne wpisy | Sygnał operacyjny, nie błąd |

W rozszerzonym oknie przed głównym testem było 64 dopasowań związanych z błędem prerenderingu route `/zwycieskie` około 15:02 UTC. To było przed zasadniczym wzrostem ruchu i nie koreluje z peak 15:40-16:00 UTC.

## 9. Korelacja sygnałów

| Sygnał | Czas | Korelacja |
|---|---|---|
| Wzrost CloudFront Requests | 15:40-16:00 UTC | Główny sygnał load testu |
| Wzrost ALB API RequestCount | 15:40-16:00 UTC | Origin dostał znaczącą część ruchu |
| API CPU i memory | 15:40-16:00 UTC | Wzrosły lekko, bez saturacji |
| ALB 4xx/5xx | 15:45-16:00 UTC | Minimalne liczności względem wolumenu |
| Redis metrics | cały okres | Stabilne, brak presji |
| App error logs | główne okno | Brak timeoutów, Redis circuit, auth errors |
| Bot task churn | 19:04+ UTC | Poza oknem testu, niepowiązane |

Przyczyną obserwowanego ruchu był load test na CloudFront/API. Skutkiem był wzrost request volume na ALB i lekki wzrost CPU/memory API. Nie ma dowodu, że ALB, ECS albo Redis były bottleneckiem.

## 10. Najbardziej prawdopodobny bottleneck

Najbardziej prawdopodobny scenariusz: brak potwierdzonego bottlenecku infrastrukturalnego w analizowanym oknie.

Ocena wariantów:

| Hipoteza | Ocena | Evidence |
|---|---|---|
| ECS / CPU | Niepotwierdzone | API CPU avg max 13.94%, max datapoint 33.51%, próg autoscaling 60% |
| ECS / memory | Niepotwierdzone | API memory avg około 53%, max około 60%, próg 75% |
| ALB / origin saturation | Niepotwierdzone | Wysoki wolumen, ale niskie p95 i brak unhealthy hosts |
| Redis | Wykluczone na podstawie metryk | EngineCPU <0.3%, memory 0.32%, evictions 0, swap 0 |
| Downstream DB / Supabase | Brak dowodu | Brak timeoutów i app errors w logach; metryki DB/Supabase nie były dostępne w AWS |
| CloudFront cache inefficiency | Częściowo możliwe | Origin nadal dostał około 55% CF request volume; brak CacheHitRate/OriginRequests per path |
| Mieszany scenariusz | Niepotwierdzone | Brak zbieżnych błędów w kilku warstwach |

Jeśli test miał mierzyć skuteczność cache `/api/slogan`, najważniejszą luką jest brak per-path CloudFront/ALB observability, nie widoczny bottleneck runtime.

## 11. Co wykluczono

| Obszar | Status |
|---|---|
| Task churn API | Brak w oknie testowym |
| API autoscaling failure | Nie; scaling nie był wymagany według CPU/memory |
| ALB target health issue | Nie; `UnHealthyHostCount=0`, 9 healthy targets |
| ALB target connection errors | Brak datapoints, traktowane jako 0 |
| Redis limiter | Wykluczone na podstawie CPU/memory/connections/evictions/swap |
| Auth errors | Brak dopasowań w logach |
| Redis circuit open | Brak dopasowań w logach |
| App timeout/pool timeout/statement timeout | Brak dopasowań w logach |
| Admin panel jako źródło problemu | Brak ruchu/błędów w logach i minimalne metryki |
| Bot jako źródło testowego problemu | Późniejszy churn poza oknem testu |

## 12. Recommended next steps

1. Włączyć albo potwierdzić CloudFront additional metrics dla `CacheHitRate`, `OriginRequests`, `OriginLatency`; obecne zapytania nie zwróciły danych.
2. Dodać per-path observability dla `/api/slogan`, `/_next/image*`, `/_next/static/*`, np. CloudFront real-time logs albo standard logs do S3/Athena.
3. Dodać jawne metryki aplikacyjne dla `/api/slogan`: request count, cache hit/miss, origin compute time, DB/Supabase call count.
4. Zweryfikować, czy generator load testu używał stabilnego query string dla `/api/slogan`; różne `search/sortBy/page` będą rozbijały cache key.
5. Utrzymać `maspex-api` min capacity 9 na czas kolejnych testów lub jawnie oznaczać pre-scale jako element scenariusza.
6. Zbierać wyniki test runnera obok AWS telemetry, żeby skorelować latency klienta z ALB/CF.
7. Osobno zbadać późniejszy `maspex-bot` healthcheck churn, bo jest poza tym incydentem, ale widoczny w bieżącym stanie ECS.

## 13. Evidence

### Użyte komendy

```bash
aws ecs describe-services --cluster maspex-uat --services maspex-api maspex-admin-panel maspex-bot --region eu-west-1 --profile maspex-cli
aws ecs list-tasks --cluster maspex-uat --desired-status RUNNING --region eu-west-1 --profile maspex-cli
aws ecs list-tasks --cluster maspex-uat --desired-status STOPPED --region eu-west-1 --profile maspex-cli
aws ecs describe-tasks --cluster maspex-uat --tasks <task-arns> --region eu-west-1 --profile maspex-cli
aws application-autoscaling describe-scalable-targets --service-namespace ecs --region eu-west-1 --profile maspex-cli
aws application-autoscaling describe-scaling-policies --service-namespace ecs --resource-id service/maspex-uat/maspex-api --scalable-dimension ecs:service:DesiredCount --region eu-west-1 --profile maspex-cli
aws application-autoscaling describe-scaling-activities --service-namespace ecs --resource-id service/maspex-uat/maspex-api --scalable-dimension ecs:service:DesiredCount --region eu-west-1 --profile maspex-cli
aws elbv2 describe-load-balancers --region eu-west-1 --profile maspex-cli
aws elbv2 describe-target-groups --region eu-west-1 --profile maspex-cli
aws elbv2 describe-target-health --target-group-arn arn:aws:elasticloadbalancing:eu-west-1:969209893152:targetgroup/maspex-uat-api-3000/97cac4c72be43344 --region eu-west-1 --profile maspex-cli
aws elasticache describe-cache-clusters --show-cache-node-info --region eu-west-1 --profile maspex-cli
aws cloudfront get-distribution-config --id E3J76RNXIE2YIG --profile maspex-cli
aws cloudfront get-cache-policy --id d71f43bc-4f5e-4188-baa8-1ef94da6ddda --profile maspex-cli
aws cloudfront get-cache-policy --id dea1b35e-7ae4-46b0-b523-78995fc22288 --profile maspex-cli
aws cloudfront get-cache-policy --id ab5d9518-10b2-44d4-ae22-c81253d9a539 --profile maspex-cli
aws logs start-query --log-group-name /maspex/uat/contest-service --start-time 1777388400 --end-time 1777393800 --region eu-west-1 --profile maspex-cli
aws logs get-query-results --query-id <query-id> --region eu-west-1 --profile maspex-cli
aws cloudwatch get-metric-statistics --namespace AWS/ECS --metric-name CPUUtilization --region eu-west-1 --profile maspex-cli
aws cloudwatch get-metric-statistics --namespace AWS/ApplicationELB --metric-name RequestCount --region eu-west-1 --profile maspex-cli
aws cloudwatch get-metric-statistics --namespace AWS/CloudFront --metric-name Requests --region us-east-1 --profile maspex-cli
aws cloudwatch get-metric-statistics --namespace AWS/ElastiCache --metric-name EngineCPUUtilization --region eu-west-1 --profile maspex-cli
```

### Metryki

| Namespace | Metrics |
|---|---|
| `AWS/ECS` | `CPUUtilization`, `MemoryUtilization` |
| `AWS/ApplicationELB` | `RequestCount`, `TargetResponseTime`, `HTTPCode_Target_4XX_Count`, `HTTPCode_Target_5XX_Count`, `HTTPCode_ELB_5XX_Count`, `TargetConnectionErrorCount`, `UnHealthyHostCount` |
| `AWS/CloudFront` | `Requests`, `BytesDownloaded`, `4xxErrorRate`, `5xxErrorRate`, `CacheHitRate`, `OriginRequests`, `OriginLatency` |
| `AWS/ElastiCache` | `CPUUtilization`, `EngineCPUUtilization`, `DatabaseMemoryUsagePercentage`, `CurrConnections`, `NewConnections`, `Evictions`, `SwapUsage` |

### Zasoby AWS

| Typ | Identyfikator |
|---|---|
| ECS cluster | `maspex-uat` |
| API service | `maspex-api` |
| Admin service | `maspex-admin-panel` |
| Bot service | `maspex-bot` |
| ALB | `arn:aws:elasticloadbalancing:eu-west-1:969209893152:loadbalancer/app/maspex-uat/68317764a66425bd` |
| API TG | `arn:aws:elasticloadbalancing:eu-west-1:969209893152:targetgroup/maspex-uat-api-3000/97cac4c72be43344` |
| CloudFront | `E3J76RNXIE2YIG` |
| Redis | `maspex-uat`, node `0001` |

## Missing or unavailable data

| Dane | Status | Wpływ |
|---|---|---|
| CloudFront `CacheHitRate` | Brak datapoints z `get-metric-statistics` | Nie da się policzyć cache hit ratio z CloudWatch metrics |
| CloudFront `OriginRequests` | Brak datapoints | Origin traffic oszacowano przez ALB API RequestCount |
| CloudFront `OriginLatency` | Brak datapoints | Latency origin oceniono przez ALB `TargetResponseTime` |
| Per-path CloudFront metrics | Niedostępne w standardowych metrykach | Nie da się rozdzielić `/api/slogan`, `/_next/image*`, `/_next/static/*` bez logów CF |
| Test runner metrics | Nie były dostępne w AWS | Brak porównania AWS-side vs client-side latency/error rate |
| Downstream DB/Supabase metrics | Nie były dostępne w AWS | Nie da się niezależnie potwierdzić lub wykluczyć DB bottleneck poza app logs |
