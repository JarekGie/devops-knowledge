# Wzorce analizy incydentów

#patterns #incident

## Post-mortem — szkielet (blameless)

```
1. Co się stało (timeline, fakty)
2. Zakres wpływu (kto / co / ile czasu)
3. Wykrycie (jak dowiedzieliśmy się — alert, klient, monitoring)
4. Mitygacja (co zrobiono, kiedy wróciło do normy)
5. Root cause (przyczyna techniczna)
6. Contributing factors (co ułatwiło wystąpienie)
7. Action items (co zmienić, kto, do kiedy)
```

## Wzorzec: timeline reconstruction

```bash
# CloudTrail — zmiany w infrastrukturze
aws cloudtrail lookup-events \
  --start-time CZAS_PRZED \
  --end-time CZAS_PO \
  --query 'Events[*].{time:EventTime,event:EventName,resource:Resources[0].ResourceName}'

# ECS deployment history
aws ecs describe-services --cluster CLUSTER --services SERVICE \
  --query 'services[0].deployments[*].{status:status,created:createdAt,updated:updatedAt,taskDef:taskDefinition}'

# RDS parameter / snapshot history
aws rds describe-db-instances --db-instance-identifier NAZWA \
  --query 'DBInstances[0].{modified:LatestRestorableTime}'
```

## Wzorzec: metryki przed i po

```bash
# Porównaj metryki request rate, latency, error rate
# Przed incydentem vs. w trakcie vs. po naprawie
# CloudWatch Metrics Insights (Console) lub CLI
```

## Wzorzec: identyfikacja blast radius

| Pytanie | Jak sprawdzić |
|---------|--------------|
| Które serwisy dotknięte? | Service map / X-Ray |
| Które konta dotknięte? | Organizations + CloudTrail |
| Ilu klientów dotknięte? | Logi aplikacji, monitoring |
| Czy nastąpił wyciek danych? | CloudTrail, VPC Flow Logs |

## Wzorzec: 5 Contributing Factors (nie 5 Why)

Zamiast szukać jednej przyczyny — znajdź 5 czynników, które razem umożliwiły incydent.

```
1. Brak monitoringu na X
2. Zmiana wdrożona bez review
3. Test environment nie odzwierciedla produkcji
4. Brak automatycznego rollbacku
5. Alert wysłany na niewłaściwy kanał
```

Każdy factor → osobny action item.

## Action items — format

```
[ ] CO zrobić — KTO odpowiedzialny — DO KIEDY — PRIORYTET
```

Priorytet:
- **P0** = zapobiega powtórzeniu tego incydentu
- **P1** = poprawia wykrywalność
- **P2** = poprawia czas reakcji
- **P3** = zmniejsza zakres przyszłego incydentu

## Powiązane

- [[debugging-patterns]]
- `templates/incident-template.md`
- `40-runbooks/incidents/`
