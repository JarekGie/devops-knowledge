# Area — Cloud Support

AWS Support cases, limity serwisów, quota management.

**Należy tutaj:** otwarte i zamknięte case'y, wzorce zgłoszeń, limity kont.  
**Nie należy tutaj:** runbooki debugowania (→ `40-runbooks/`).

## Aktywne case'y AWS Support

| Case ID | Temat | Status | Konto | Data |
|---------|-------|--------|-------|------|
| | | | | |

## Limity serwisów — do monitorowania

```bash
# Lista limitów serwisu
aws service-quotas list-service-quotas --service-code ec2

# Request increase
aws service-quotas request-service-quota-increase \
  --service-code ec2 \
  --quota-code L-1216C47A \
  --desired-value 100
```

## Typowe limity do sprawdzenia

| Serwis | Limit | Typowa wartość |
|--------|-------|----------------|
| EC2 vCPUs (on-demand) | running instances | 32–96 |
| ECS Tasks per service | 1000 | |
| ALB per region | 50 | |
| ACM certs | 2500 | |

## Jak otworzyć case

1. Console → Support → Create case
2. Wybierz: Technical / Service limit increase
3. Podaj: konto, region, serwis, aktualny limit, żądany limit, uzasadnienie biznesowe
4. Priority: Normal / High / Urgent (Urgent = produkcja down)

## Historia case'ów

<!-- Wpisuj zamknięte case'y jako referencja -->
