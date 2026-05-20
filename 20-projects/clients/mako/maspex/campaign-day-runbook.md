---
title: campaign-day-runbook
client: mako
project: maspex
domain: client-work
document_type: runbook
classification: internal
created: 2026-05-15
updated: 2026-05-15
tags:
  - maspex
  - runbook
  - campaign
  - observability
---

# Runbook Operatorski — Dzień Kampanii Maspex (18 maja)

#maspex #runbook #campaign #observability

**Termin:** 18 maja 2026, ~południe
**Środowisko:** PROD (`maspex-prod`)
**Operator:** monitoruje kampanię live, reaguje na sygnały

---

## Główne widoki — otwórz PRZED startem kampanii

| Widok | Link (AWS console) |
|-------|-------------------|
| **Dashboard PROD** | CloudWatch → Dashboards → `maspex-prod-overview` |
| **Alarmy PROD** | CloudWatch → Alarms → filter: `maspex-prod` |
| **ECS PROD tasks** | ECS → Clusters → `maspex-prod` → Services → `maspex-api` |
| **Autoscaling activities** | ECS → `maspex-api` → zakładka "Auto Scaling" |
| **Dashboard UAT** (fallback) | CloudWatch → Dashboards → `maspex-uat-overview` |

Skróty AWS Console (eu-west-1):
```
https://eu-west-1.console.aws.amazon.com/cloudwatch/home?region=eu-west-1#dashboards/dashboard/maspex-prod-overview
https://eu-west-1.console.aws.amazon.com/cloudwatch/home?region=eu-west-1#alarmsV2:?~(search~'maspex-prod)
https://eu-west-1.console.aws.amazon.com/ecs/v2/clusters/maspex-prod/services/maspex-api/health?region=eu-west-1
```

---

## Dashboard — co patrzeć i w jakiej kolejności

### Row 13 (na górze po przewinięciu): Alarm Status
Jedno spojrzenie — zielono = wszystko OK. Jakikolwiek czerwony = przejdź do sekcji alarmów.

### Row 1: ALB Request Count
Weryfikuj czy ruch rośnie zgodnie z oczekiwaniami. Spike w ciągu 5 minut od startu kampanii jest normalny.

### Row 14: Autoscaling trigger + Pending Tasks
- **ALBRequestCountPerTarget** — żółta linia = 200 = próg scale-out. Jeśli przez >2 min jest powyżej 200 a liczba tasków nie rośnie → patrz ECS Activities
- **PendingTaskCount** — jeśli > 0 przez >3 min → autoscaling zablokowany, patrz sekcja Scale-Up

### Row 7: Running vs Desired Task Count
Czy desired rośnie? Czy running nadąża za desired?

### Row 2: Unhealthy Hosts
Powinno być 0. Jakikolwiek > 0 przez >2 min → sprawdź logi kontenera.

---

## Progi: zielony / żółty / czerwony

| Metryka | ZIELONY | ŻÓŁTY | CZERWONY |
|---------|---------|-------|---------|
| ALB Target 5xx | 0 | 1–5 / 5 min | >5 / 5 min |
| ALB p99 TargetResponseTime | <2s | 2–10s | >10s |
| ECS CPU API (avg) | <60% | 60–80% | >80% |
| ECS Memory API (avg) | <75% | 75–85% | >85% |
| Unhealthy Hosts API | 0 | — | ≥1 przez >2 min |
| Running vs Desired | równe | pending <3 min | pending >3 min |
| ALBRequestCountPerTarget | <200 | 200–300 | >300 i pending tasks |
| Redis EngineCPU | <30% | 30–50% | >50% |
| Redis Evictions | 0 | <100/min | >100/min |
| Redis Circuit Open (log) | 0 | — | >10 / min |

---

## Kiedy robić pre-scale / scale-up

### Pre-scale (PRZED kampanią, ~30 min wcześniej)
Podnieś min_capacity jeśli wiesz że będzie dużo ruchu:
```bash
AWS_PROFILE=maspex-cli aws application-autoscaling register-scalable-target \
  --service-namespace ecs \
  --resource-id service/maspex-prod/maspex-api \
  --scalable-dimension ecs:service:DesiredCount \
  --min-capacity 12 \
  --max-capacity 15 \
  --region eu-west-1
```

### Ręczny scale-up (kampania trwa, autoscaling nie nadąża)
```bash
# Podnieś desired natychmiast (poza autoscalingiem):
AWS_PROFILE=maspex-cli aws ecs update-service \
  --cluster maspex-prod \
  --service maspex-api \
  --desired-count 15 \
  --region eu-west-1
```

### Powrót do baseline (po kampanii)
```bash
# Przywróć min_capacity do 9:
AWS_PROFILE=maspex-cli aws application-autoscaling register-scalable-target \
  --service-namespace ecs \
  --resource-id service/maspex-prod/maspex-api \
  --scalable-dimension ecs:service:DesiredCount \
  --min-capacity 9 \
  --max-capacity 15 \
  --region eu-west-1
```

---

## Kiedy eskalować do devów

Eskaluj jeśli wystąpi JEDNO z:
- **5xx > 10% requestów** przez >5 min bez wyraźnej przyczyny w logach
- **Redis circuit open** trwa >5 min mimo zdrowego Redis (EngineCPU < 50%)
- **ECS tasks crashują** — RunningTaskCount spada mimo desired > running
- **ALB unhealthy hosts** utrzymuje się >5 min mimo restartu tasków
- **Supabase 502** pojawia się masowo w logach (downstream degradacja)

Kontakt devów: sprawdź w projekcie maspex kto jest on-call.

---

## Kiedy uznać incident

Incident formalny jeśli:
- Platforma PROD niedostępna (5xx > 80%) przez >5 min
- Autoscaling całkowicie przestał działać i ręczny scale-up nie pomaga
- Redis całkowicie niedostępny (circuit open na wszystkich instancjach)
- Dane tracone lub corrupted (nie tylko błędy sieciowe)

---

## Gotowe komendy diagnostyczne

### Status ECS PROD
```bash
AWS_PROFILE=maspex-cli aws ecs describe-services \
  --cluster maspex-prod \
  --services maspex-api maspex-admin-panel maspex-bot \
  --region eu-west-1 \
  --query 'services[*].{svc:serviceName,desired:desiredCount,running:runningCount,pending:pendingCount}'
```

### Autoscaling activities (ostatnie 20)
```bash
AWS_PROFILE=maspex-cli aws application-autoscaling describe-scaling-activities \
  --service-namespace ecs \
  --resource-id service/maspex-prod/maspex-api \
  --region eu-west-1 \
  --max-results 20 \
  --query 'ScalingActivities[*].{time:StartTime,cause:Cause,status:StatusCode,desc:Description}'
```

### Aktywne alarmy PROD
```bash
AWS_PROFILE=maspex-cli aws cloudwatch describe-alarms \
  --alarm-name-prefix maspex-prod \
  --state-value ALARM \
  --region eu-west-1 \
  --query 'MetricAlarms[*].{alarm:AlarmName,reason:StateReason}'
```

### ALB healthy host count
```bash
AWS_PROFILE=maspex-cli aws elbv2 describe-target-health \
  --target-group-arn $(AWS_PROFILE=maspex-cli aws elbv2 describe-target-groups \
    --region eu-west-1 \
    --query 'TargetGroups[?contains(TargetGroupName,`prod`)&&contains(TargetGroupName,`api`)].TargetGroupArn' \
    --output text) \
  --region eu-west-1
```

### Redis live metrics
```bash
AWS_PROFILE=maspex-cli aws cloudwatch get-metric-statistics \
  --namespace AWS/ElastiCache \
  --metric-name EngineCPUUtilization \
  --dimensions Name=CacheClusterId,Value=maspex-prod \
  --start-time $(date -u -v-10M +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 60 \
  --statistics Average \
  --region eu-west-1 \
  --query 'Datapoints[*].{time:Timestamp,cpu:Average}' | jq 'sort_by(.time)'
```

### Logi API (ostatnie błędy)
```bash
AWS_PROFILE=maspex-cli aws logs filter-log-events \
  --log-group-name /maspex/shared/maspex-api \
  --start-time $(date -v-10M +%s000) \
  --filter-pattern "error" \
  --region eu-west-1 \
  --query 'events[*].{time:timestamp,msg:message}' \
  --limit 50
```

---

## Alarmy — kompletna lista z progami i akcjami

| Alarm | Próg | Uzasadnienie | Akcja operatorska |
|-------|------|-------------|-------------------|
| `maspex-prod-alb-target-5xx` | >5 / 5 min | Baseline błędów w normalnej pracy ~0 | Sprawdź logi `/maspex/shared/maspex-api` → szukaj pattern błędu |
| `maspex-prod-alb-elb-5xx` | >5 / 5 min | ELB 5xx = problem po stronie ALB/circuit breaker | Sprawdź czy ECS tasks healthy; jeśli tak — upstream timeout |
| `maspex-prod-alb-unhealthy-hosts-api` | ≥1 / 5 min | Jeden unhealthy host = potencjalny cascade | Sprawdź describe-target-health + logi taska |
| `maspex-prod-alb-api-target-response-time-high` | p99 >10s / 3 min | Aplikacja akceptuje ale nie odpowiada szybko | Sprawdź Redis (circuit open?) i Supabase (502?) |
| `maspex-prod-alb-api-target-connection-errors` | >10 / 1 min | Tasks nie akceptują połączeń | Sprawdź czy tasks są w healthy state; może restart |
| `maspex-prod-ecs-api-running-below-desired` | running < desired / 2 min | Tasks nie startują lub crashują | Sprawdź stopped tasks: describe-tasks --desired-status STOPPED |
| `maspex-prod-ecs-high-cpu-api` | avg >80% / 10 min | Aplikacja na granicy | Pre-scale: podnieś desired o +3 |
| `maspex-prod-ecs-high-memory-api` | avg >85% / 10 min | Memory leak lub niedobór | Sprawdź per-task memory (Enhanced CI); rozważ restart najstarszych |
| `maspex-prod-ecs-api-pending-tasks` | >0 / 3 min | Autoscaling nie dostarcza tasków | Sprawdź Fargate capacity + logi ECS service events |
| `maspex-prod-cloudfront-api-5xx-rate` | >1% / 3 min | CF zwraca 5xx do użytkowników | Sprawdź origin health (ALB/ECS) |
| `maspex-prod-api-downstream-log-errors` | >5 / 5 min | Problemy z Supabase / Redis / pool | Sprawdź szczegółowe logi: supabase502, pool timeout |
| `maspex-prod-api-redis-circuit-open` | >10 / 1 min | App omija Redis → Supabase pod pełnym obciążeniem | Sprawdź Redis health (EngineCPU, evictions, connections) |
| `maspex-prod-redis-high-engine-cpu` | >50% / 3 min | Cache saturation — spowolnienie sloganów | Monitoruj połączenia; jeśli >70% → eskalacja |
| `maspex-prod-redis-evictions` | >100 / 1 min | maxmemory pressure — dane tracone | Sprawdź `maxmemory-policy` Redis; rozważ flush starych kluczy |
| `maspex-prod-api-auth-errors` | >10 / 5 min | Masowe błędy auth — może być burza auth refresh | Sprawdź czy to batch refresh czy błąd JWT config |

---

## Powiązane

- [[maspex-context]] — architektura i zasoby
- [[loadtest-observability]] — jak interpretować metryki pod obciążeniem
- [[session-log]] — historia sesji
