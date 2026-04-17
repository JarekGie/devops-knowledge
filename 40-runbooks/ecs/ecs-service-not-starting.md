# Runbook — ECS service not starting

#ecs #aws #runbook

## Symptom

- Task w stanie `STOPPED` lub restart loop
- Service desired count > running count
- ALB healthcheck failing

## Zakres

ECS Fargate lub EC2. Jeden lub wiele tasków.

---

## Komendy diagnostyczne

```bash
CLUSTER=nazwa-klastra
SERVICE=nazwa-serwisu

# Status serwisu
aws ecs describe-services \
  --cluster $CLUSTER \
  --services $SERVICE \
  --query 'services[0].{status:status,running:runningCount,desired:desiredCount,pending:pendingCount}'

# Lista ostatnich tasków (w tym stopped)
aws ecs list-tasks \
  --cluster $CLUSTER \
  --service-name $SERVICE \
  --desired-status STOPPED \
  --query 'taskArns'

# Szczegóły zatrzymanego taska (przyczyna)
aws ecs describe-tasks \
  --cluster $CLUSTER \
  --tasks TASK_ARN \
  --query 'tasks[0].{stopCode:stopCode,stoppedReason:stoppedReason,containers:containers[*].{name:name,reason:reason,exitCode:exitCode}}'

# Logi kontenera
aws logs tail /ecs/$SERVICE --follow --since 30m
```

## Punkty decyzyjne

| Objaw | Przyczyna | Akcja |
|-------|-----------|-------|
| `exitCode: 1`, krótki czas działania | crash aplikacji | sprawdź logi |
| `exitCode: 137` | OOM kill | zwiększ memory limit |
| `CannotPullContainerError` | brak dostępu do ECR lub złe image | sprawdź IAM i URI obrazu |
| `ResourceInitializationError` | problem z secrets / env vars | sprawdź Secrets Manager / SSM |
| `HEALTH_CHECK_GRACE_PERIOD_EXPIRED` | app startuje wolno | zwiększ grace period |
| Task zatrzymuje się po 30s | ALB healthcheck fail | sprawdź target group health |

## Sprawdzenie healthcheck

```bash
# Target group health
TG_ARN=arn:aws:elasticloadbalancing:...
aws elbv2 describe-target-health \
  --target-group-arn $TG_ARN
```

## Rollback / bezpieczeństwo

```bash
# Przywróć poprzednią task definition
aws ecs update-service \
  --cluster $CLUSTER \
  --service $SERVICE \
  --task-definition NAZWA:POPRZEDNIA_REWIZJA \
  --force-new-deployment
```

## Findings

<!-- Wpisz co znalazłeś i jak rozwiązano -->
