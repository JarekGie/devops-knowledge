# Runbook — ECS deployment stuck

#ecs #aws #runbook

## Symptom

Deployment ECS nie kończy się — nowe taski nie zastępują starych lub deployment zatrzymał się na X%.

## Zakres

Jeden service ECS. Sprawdź deployment circuit breaker i minimum healthy percent.

---

## Komendy diagnostyczne

```bash
CLUSTER=nazwa-klastra
SERVICE=nazwa-serwisu

# Status deploymentu
aws ecs describe-services \
  --cluster $CLUSTER \
  --services $SERVICE \
  --query 'services[0].deployments'

# Czy nowe taski startują?
aws ecs list-tasks \
  --cluster $CLUSTER \
  --service-name $SERVICE \
  --desired-status RUNNING

# Dlaczego deployment nie postępuje
aws ecs describe-services \
  --cluster $CLUSTER \
  --services $SERVICE \
  --query 'services[0].events[:5]'
```

## Punkty decyzyjne

| Objaw | Przyczyna | Akcja |
|-------|-----------|-------|
| Nowe taski nie startują | crash nowej wersji | sprawdź logi, cofnij |
| Stare taski nie kończą się | długie połączenia / deregistration delay | poczekaj lub zmniejsz delay |
| Deployment zatrzymał się na 50% | minimum healthy percent constraint | sprawdź config |
| Circuit breaker zadziałał | zbyt wiele failed tasks | sprawdź logi i przyczynę |

## Wymuś zakończenie deploymentu (rollback)

```bash
# Rollback do poprzedniej task definition
PREV_REVISION=$(aws ecs describe-services \
  --cluster $CLUSTER \
  --services $SERVICE \
  --query 'services[0].deployments[1].taskDefinition' \
  --output text)

aws ecs update-service \
  --cluster $CLUSTER \
  --service $SERVICE \
  --task-definition $PREV_REVISION \
  --force-new-deployment
```

## Wymuś zatrzymanie stuck tasków

```bash
# Lista running tasks
TASKS=$(aws ecs list-tasks --cluster $CLUSTER --service-name $SERVICE --query 'taskArns' --output text)

# Zatrzymaj stuck task (ostateczność)
aws ecs stop-task --cluster $CLUSTER --task TASK_ARN --reason "deployment stuck"
```

## Rollback / bezpieczeństwo

- Nie zatrzymuj wszystkich tasków jednocześnie jeśli serwis jest aktywny
- Zmniejsz deregistration delay tylko jeśli serwis obsługuje krótkie połączenia

## Findings

<!-- Co znalazłeś -->
