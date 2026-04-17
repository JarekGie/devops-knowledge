# Area — Observability

Logi, metryki, tracowanie, alerty.

**Należy tutaj:** wzorce alertów, konfiguracje, gotcha, referencje dashboardów.  
**Nie należy tutaj:** runbooki incydentów (→ `40-runbooks/incidents/`).

## Stack

| Warstwa | Narzędzie |
|---------|-----------|
| Logi | CloudWatch Logs, (opcjonalnie: Loki) |
| Metryki | CloudWatch Metrics, Container Insights |
| Trace | AWS X-Ray |
| Alerty | CloudWatch Alarms → SNS → PagerDuty / Slack |

## Kluczowe metryki ECS

```
CPUUtilization         > 80% → alert
MemoryUtilization      > 85% → alert
RunningTasksCount      < desired → krytyczny
HealthyHostCount (ALB) = 0  → krytyczny
```

## CloudWatch — przydatne komendy

```bash
# Ostatnie logi z log group
aws logs tail /ecs/NAZWA_SERWISU --follow

# Filter pattern
aws logs filter-log-events \
  --log-group-name /ecs/NAZWA \
  --filter-pattern "ERROR"

# Metrics ostatnia godzina
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=NAZWA \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

## Dashboardy

<!-- uzupełnij linkami do CloudWatch dashboardów -->

| Dashboard | Link | Środowisko |
|-----------|------|-----------|
| | | |
