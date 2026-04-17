# Area — AWS

Wiedza operacyjna o AWS. Nie tutoriale — wzorce, decyzje, referencje.

**Należy tutaj:** konfiguracje serwisów, wzorce, gotcha, linki do runbooków.  
**Nie należy tutaj:** runbooki krok-po-kroku (→ `40-runbooks/aws/`), decyzje architektoniczne (→ `80-architecture/`).

## Kluczowe referencje

- [[aws-tagging-standard]] — obowiązkowe tagi na wszystkich zasobach
- [[command-catalog]] — AWS CLI komendy
- [[debugging-patterns]] — wzorce debugowania

## Serwisy w użyciu

| Serwis | Zastosowanie |
|--------|-------------|
| ECS | kontenery, produkcja |
| EKS | kubernetes managed |
| ALB | load balancing HTTP/HTTPS |
| CloudFront | CDN, edge |
| VPC | sieć, segmentacja |
| RDS | relacyjne bazy danych |
| DocumentDB | MongoDB-compatible |
| ElastiCache (Redis) | cache, session |

## Konta AWS

<!-- uzupełnij -->

| Alias | Account ID | Env | Profil CLI |
|-------|-----------|-----|-----------|
| | | | |

## Szybkie komendy

```bash
# Przełączenie profilu
export AWS_PROFILE=nazwa-profilu

# Sprawdzenie tożsamości
aws sts get-caller-identity

# Lista ECS services
aws ecs list-services --cluster NAZWA_KLASTRA
```
