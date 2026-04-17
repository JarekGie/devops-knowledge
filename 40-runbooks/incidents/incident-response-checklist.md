# Incident Response — Pierwsza odpowiedź

#incident #runbook

## Natychmiast (pierwsze 5 minut)

- [ ] Potwierdź symptom — co dokładnie nie działa
- [ ] Sprawdź zakres — jeden klient / region / serwis czy więcej
- [ ] Sprawdź AWS Service Health Dashboard
- [ ] Otwórz nową notatkę incydentu: `templates/incident-template.md`
- [ ] Powiadom odpowiednie osoby (klient, team)

## Diagnostyka (5–15 minut)

```bash
# Status serwisów ECS
aws ecs describe-services --cluster CLUSTER --services SERVICE

# Zdrowie ALB targetów
aws elbv2 describe-target-health --target-group-arn TG_ARN

# Ostatnie logi
aws logs tail /ecs/SERVICE --follow --since 15m

# CloudWatch alarms w stanie ALARM
aws cloudwatch describe-alarms --state-value ALARM
```

- [ ] Zidentyfikuj serwis / komponent który zawiódł
- [ ] Sprawdź ostatnie deploye (CI/CD, Terraform)
- [ ] Sprawdź ostatnie zmiany konfiguracji

## Mitygacja

- [ ] Czy można rollback? → zrób rollback
- [ ] Czy można skalować? → scale out
- [ ] Czy można wyłączyć feature flag? → wyłącz
- [ ] Czy można przekierować ruch? → zmień routing

## Komunikacja

```
Status update (co X minut):
- Co się dzieje
- Zakres wpływu
- Aktualny status
- Planowane działania
- Następny update za X minut
```

## Po mitygacji

- [ ] Potwierdź że problem ustąpił
- [ ] Zapisz timeline incydentu
- [ ] Zaplanuj post-mortem

## Powiązane

- [[debugging-patterns]]
- [[incident-analysis-patterns]]
- `templates/incident-template.md`
