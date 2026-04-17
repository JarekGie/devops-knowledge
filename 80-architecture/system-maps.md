# Mapy systemów

Diagramy i opisy kluczowych systemów. ASCII art lub linki do zewnętrznych narzędzi.

#architecture #systems

## Wzorzec platformy AWS (generyczny)

```
                    Route53
                       │
                   CloudFront
                       │
                      ALB
                    ┌──┴──┐
               ECS Fargate  Lambda
                    │
            ┌───────┼───────┐
           RDS  DocumentDB  ElastiCache
                             (Redis)
```

## devops-toolkit — przepływ danych

```
User / CI
    │
    ▼
toolkit CLI
    │
    ├── AWS SDK ──────── Cost Explorer API
    │                    IAM API
    │                    Resource Groups API
    │                    CloudWatch API
    │
    └── Output ─────────── stdout (JSON / Markdown / CSV)
```

## Mapa kont AWS

<!-- Uzupełnij strukturę kont -->

```
Management Account
├── Security OU
│   └── security-account
├── Prod OU
│   └── prod-account
└── Dev OU
    ├── dev-account
    └── sandbox-account
```

## Systemy klienckie

<!-- Dodawaj mapy per klient / projekt -->

---

*Powiązane: [[decision-log]] | [[platform-principles]] | [[integration-notes]]*
