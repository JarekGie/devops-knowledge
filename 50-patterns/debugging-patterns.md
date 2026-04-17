# Wzorce debugowania

#debugging #patterns

## Zasada pierwsza: zawęź zakres

Przed wejściem w logi — odpowiedz na:
1. Kiedy zaczął się problem? (deploy? zmiana konfiguracji? wzrost ruchu?)
2. Czy dotyczy wszystkich? (wszystkich userów / regionów / serwisów?)
3. Czy problem jest powtarzalny?

## Wzorzec: od zewnątrz do środka

```
Internet → CloudFront → ALB → ECS/Lambda → DB/Cache → External API
         ↑               ↑         ↑              ↑
     sprawdź tu     sprawdź tu  sprawdź tu   sprawdź tu
```

Zacznij od punktu wejścia, idź do środka.

## Wzorzec: sprawdź co się zmieniło

```bash
# Ostatnie deploye ECS
aws ecs describe-services --cluster CLUSTER --services SERVICE \
  --query 'services[0].deployments'

# Historia Terraform
git log --oneline -10 -- infra/

# Logi zmian w infrastrukturze
aws cloudtrail lookup-events \
  --start-time $(date -u -d '2 hours ago' +%Y-%m-%dT%H:%M:%S) \
  --query 'Events[*].{time:EventTime,event:EventName,user:Username}'
```

## Wzorzec: 5 Why

Dlaczego (1) → Dlaczego (2) → Dlaczego (3) → Dlaczego (4) → Root cause

Zatrzymaj się gdy dojdziesz do przyczyny, którą możesz kontrolować.

## Wzorzec: błąd 5xx — warstwy

| Warstwa | Narzędzie | Co sprawdzić |
|---------|-----------|-------------|
| DNS | `dig`, Route53 | poprawność rekordów |
| CloudFront | CF logs, error rate | origin error, cache miss |
| ALB | access logs, target health | 5xx origin errors |
| Aplikacja | CloudWatch Logs | stack trace, error message |
| DB | RDS metrics, slow query log | connections, CPU, locks |

## Wzorzec: timeout cascade

Jeden powolny serwis może zablokować cały system przez timeouty.

```
Symptom: rosnący czas odpowiedzi → 504/503 → circuit breaker
Sprawdź: metryki latency per serwis, connection pool exhaustion
```

## Wzorzec: OOM / memory leak

```bash
# ECS: sprawdź MemoryUtilization
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS --metric-name MemoryUtilization \
  --dimensions Name=ServiceName,Value=SERVICE \
  --start-time $(date -u -d '3 hours ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 --statistics Maximum

# K8s
kubectl top pod -n NAMESPACE
kubectl describe pod POD | grep -i oom
```

## Powiązane

- [[incident-analysis-patterns]]
- `40-runbooks/incidents/incident-response-checklist.md`
- [[command-catalog]]
