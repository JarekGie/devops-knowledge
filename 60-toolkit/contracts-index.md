# Katalog kontraktów

Każda komenda toolkit ma zdefiniowany kontrakt wejście/wyjście.  
Kontrakty są źródłem prawdy — implementacja jest drugorzędna.

#toolkit #contracts

## Konwencja

Plik kontraktu: `contracts/{kategoria}/{komenda}.json` lub `.md`

```
contracts/
├── aws/
│   ├── audit-iam.md
│   ├── audit-s3.md
│   └── list-resources.md
├── finops/
│   ├── cost-report.md
│   └── tagging-audit.md
└── iac/
    └── terraform-audit.md
```

## Zaimplementowane komendy

| Komenda | Kontrakt | Status |
|---------|----------|--------|
| | | |

## Planowane komendy

| Komenda | Opis | Priorytet |
|---------|------|-----------|
| `audit iam` | Audyt polityk IAM, loose permissions | P0 |
| `audit s3` | Audyt bucketów: publiczne, bez szyfrowania | P0 |
| `audit tagging` | Zasoby bez wymaganych tagów | P0 |
| `finops report` | Raport kosztów per projekt/env | P1 |
| `iac lint` | Walidacja Terraform wg standardów | P1 |
| `list resources` | Lista zasobów z filtrami | P2 |

## Format kontraktu (wzorzec)

→ `contracts/` — każdy kontrakt w osobnym pliku

## Powiązane

- [[architecture-overview]]
- [[command-catalog]]
- [[plugin-system]]
