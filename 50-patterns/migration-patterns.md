# Wzorce migracji

#patterns #migration

## Zasady migracji

1. **Migracja != big bang** — migruj inkrementalnie, ruch stopniowo
2. **Zawsze miej rollback plan** — zanim zaczniesz, wiesz jak cofnąć
3. **Testuj na staging** — miarą sukcesu jest działanie, nie plan
4. **Dane osobno od aplikacji** — migruj DB i app niezależnie

## Wzorzec: Strangler Fig (stopniowe zastępowanie)

```
Stary system → Router (ALB / CloudFront) → Nowy system (subset ruchu)
                                          → Stary system (reszta)

Kroki:
1. Wdróż nowy system obok starego
2. Przekieruj X% ruchu na nowy
3. Monitoruj, powiększaj X
4. Gdy 100% — wyłącz stary
```

## Wzorzec: Blue/Green deployment

```bash
# ECS: zmień target group w ALB listener rule
# Blue = aktualny, Green = nowy

# 1. Deploy nowej wersji jako Green (personal TG)
# 2. Healthcheck Green
# 3. Swap: ALB listener → Green
# 4. Blue zostaje jako rollback przez X minut
# 5. Wyłącz Blue
```

## Wzorzec: migracja DB (zero-downtime)

```
1. Expand: dodaj nowe kolumny / tabele (backward compatible)
2. Migruj: aplikacja pisze do starego i nowego
3. Backfill: przenieś stare dane do nowych kolumn
4. Contract: usuń stare kolumny gdy aplikacja tylko nowe czyta
```

## Wzorzec: migracja EC2 → ECS Fargate

```
1. Konteneryzuj aplikację (Dockerfile)
2. Przetestuj lokalnie i na dev
3. ECS Task Definition → deploy na dev ECS
4. Wdróż nowy ALB target group
5. Stopniowe przekierowanie ruchu (Route53 weighted / ALB weights)
6. Monitoring 24–48h
7. Odtnij EC2
```

## Wzorzec: migracja między kontami AWS

```
1. Przygotuj konto docelowe (VPC, IAM, baseline)
2. Skonfiguruj cross-account access
3. Replikuj S3 (S3 Replication)
4. Snapshot RDS → restore w nowym koncie
5. Deploy aplikacji w nowym koncie
6. Testy
7. DNS cut-over (low TTL przed migracją)
8. Cleanup starego konta
```

## Rollback decision tree

```
Problem po deployu?
├── Czy problem w aplikacji? → rollback task definition / image
├── Czy problem w konfiguracji? → rollback Terraform / env vars
├── Czy problem w bazie? → rollback migracji DB (jeśli backward compatible)
└── Czy problem w sieci? → sprawdź security groups, routing
```

## Powiązane

- [[debugging-patterns]]
- [[decision-log]]
- `40-runbooks/`
