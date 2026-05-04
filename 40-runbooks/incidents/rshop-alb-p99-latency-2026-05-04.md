---
title: rshop — ALB p99 latency flapping (Services external API)
date: 2026-05-04
severity: P3
status: identified
system: rshop
tags: [rshop, alb, latency, p99, incident, ecs, external-api]
---

# rshop — ALB p99 > 2s flapping (2026-05-04)

## Objaw / Symptom

ALB `TargetResponseTime p99 > 2s` — alarm flapping (ALARM/OK).  
p50 stabilne 8–60ms. Problem wyłącznie w long tail.

## Scope

- System: rshop, region eu-central-1, account 943111679945
- LoadBalancer: `app/prod-ALB/90737edb8f90e9e6`
- ECS: `rshop-prod-Klaster` → `rshop-prod-api-svc`
- Czas trwania: ciągły (zidentyfikowany 2026-05-04, pattern od >2h)
- Severity: P3 (degraded performance, SLO breach p99, bez outage)

## Szybkie komendy diagnostyczne

```bash
# ALB p99 ostatnia godzina
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name TargetResponseTime \
  --dimensions Name=LoadBalancer,Value=app/prod-ALB/90737edb8f90e9e6 \
  --extended-statistics p99 p90 p50 \
  --period 300 --start-time $(date -u -v-1H +%Y-%m-%dT%H:%M:%SZ) --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --region eu-central-1 --profile rshop

# Najwolniejsze requesty (logi - ostatnia godzina)
# CW Logs Insights na /ecs/rshop-prod:
# fields @timestamp, @message | filter @message like /Request finished/ | parse @message / (?<duration>[0-9]+\.[0-9]+)ms/ | sort duration desc | limit 20

# ECS service status
aws ecs describe-services --cluster rshop-prod-Klaster \
  --services rshop-prod-api-svc --region eu-central-1 --profile rshop \
  --query 'services[0].{running:runningCount,desired:desiredCount,events:events[:3]}'
```

## Decision points

1. p50 wysokie (>200ms)? → globalny problem (DB, sieć) — sprawdź RDS
2. p50 normalne, p99 high? → long tail — sprawdź `/api/Services` i `/api/Tires` requesty
3. ECS restarty? → sprawdź stopped tasks + healthcheck failures
4. Alarm CIĄGŁY (nie flapping)? → sprawdź czy Services API backend jest down

## Root Cause (zidentyfikowany 2026-05-04)

**PRIMARY:** `/api/Services/category/{cat}/bir/{bir}/vin/{vin}` i `/api/Services/categories`  
wykonują synchroniczne wywołania do zewnętrznego API Renault/Dacia (vehicle service catalog).

- Czas odpowiedzi: **5–12 sekund** (zmienny — czasem 300ms, zwykle 5-12s)
- Przy `desired=1` (single ECS task) — każde wywołanie blokuje wątek ASP.NET Core
- Równoległe wywołania (4–11 na 5 minut) powodują kolejkowanie pozostałych requestów → p99 spike

**CONTRIBUTING:**
- Single ECS task (brak horizontal scaling)
- PDF generation: 2–4s, CPU-bound (82 req/2h)
- `/api/Tires`: external API, avg 1276ms, max 6642ms
- Brak timeout/circuit breaker na external API calls (prawdopodobne)

**WYKLUCZONE:** RDS (avg read 0.3ms), healthcheck failures (0 stopped tasks).

## Evidence

```
Top slow requests (logi):
12307ms  GET /api/Services/category/76/bir/61617941/vin/UU1DJF00769311154
11624ms  GET /api/Services/category/5/bir/61617074/vin/VF1RJA0016488223
11448ms  GET /api/Services/category/95/bir/70335122/vin/VF1HJD20972276386

Endpoint stats (>500ms, 2h):
/api/Services  64 req  avg=4701ms  max=12307ms
/api/pdf       82 req  avg=1559ms  max=4382ms
/api/Tires     33 req  avg=1276ms  max=6642ms

RDS (prod pssa61v1phykq0):
ReadLatency avg=0.3ms, max=2.9ms ✅
DatabaseConnections: 2-8 ✅
```

## Rollback / Safety

- Brak możliwości rollback (to nie jest deployment issue)
- System działa — NIE restartuj ECS tasks (nie pomoże)
- Jeśli Services backend jest down: dodaj feature flag wyłączający endpoint lub zwróć cached/empty response

## Recommendations (do implementacji)

1. **Timeout** na external API call ≤5s + fallback (pusta lista / cached)
2. **Circuit breaker** (Polly) na wywołania Renault/Dacia backend
3. **Caching** wyników /api/Services per VIN (TTL 24h — historia serwisowa statyczna)
4. **ECS desired=2** + autoscaling (ALBRequestCountPerTarget target=500)
5. **PDF** → background job + S3 presigned URL (nie blokuj request thread)

## Findings / Notes

- `/api/Services` calls: pattern regularny przez cały dzień (co 5-min window)
- Flapping = Services calls burstowe (brak → normalne, burst → alarm)
- Correlation: ALB p99 worst spike (13:04 CEST) = Services max 12307ms w window 11:00 UTC
- Log group API: `/ecs/rshop-prod` | Backoffice: `/esc/backoffice` (uwaga: typo w nazwie)
- Container Insights CPU — niedostępne (brak danych), nie blokuje diagnostyki
