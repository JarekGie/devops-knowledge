# Katalog komend — devops-toolkit

#toolkit #commands

Źródło prawdy: `~/projekty/devops/devops-toolkit/docs/cli-public-api.md`
Poniżej skrót do codziennego użycia.

---

## CORE — codzienne użycie

```bash
toolkit onboard [--client] [--profile] [--region] [--iac]   # onboarding repo
toolkit here [--dir PATH]                                    # kontekst projektu (bare-repo)
toolkit work [project]                                       # pełny kontekst operacyjny
toolkit audit [project]                                      # pełny audit infrastruktury
toolkit audit-pack <pack> [project]                          # konkretny audit pack
toolkit apply-pack <pack> [project]                          # pack z audit-first enforce
toolkit aws-login [project]                                  # aktywacja kontekstu AWS
toolkit aws-logout                                           # usunięcie sesji AWS
toolkit aws-context [project]                                # aktualny kontekst AWS
toolkit doctor [project]                                     # preflight checks
toolkit check [project]                                      # sanity check (dry-run)
toolkit clients                                              # lista klientów w workspace
toolkit projects <client>                                    # lista projektów klienta
toolkit project validate [--project]                         # walidacja project.yaml
toolkit contract check [--project-root]                      # walidacja kontraktów IaC
toolkit contract show [--project-root]                       # wyświetl kontrakt projektu
toolkit contract init [--project-root]                       # inicjalizuj contracts.yaml
toolkit install                                              # jednorazowy installer
```

---

## ADVANCED — specjalistyczne

```bash
# Terraform
toolkit terraform init-project --project-name X --envs dev,prod  # scaffold projektu TF
toolkit terraform audit-module <path>                             # statyczny audit modułu
toolkit terraform audit-modules --repo <path>                     # audit wielu modułów
toolkit terraform check-modules --repo <path>                     # CI check modułów

# FinOps
toolkit finops-report [project] --period mtd|last-full-month \
  --group-by service|usage-type \
  --audience executive|technical \
  --env ENV --format md|json|both|confluence

# Inne
toolkit estimate <project>                                   # estymacja architektoniczna + kosztowa
toolkit drift [project]                                      # wykrywanie IaC drift
toolkit discover-aws [project]                               # inwentaryzacja AWS (read-only)
toolkit project refresh [--project-root]                     # odświeżenie project.yaml
toolkit project init <client> <project>                      # inicjalizacja nowego projektu
toolkit client add <name>                                    # tworzenie katalogu klienta
toolkit ui [project]                                         # operator UI (FastAPI, port 8765)
toolkit index [--force]                                      # rebuild indeksu workspace
toolkit path <client/project>                                # ścieżka projektu (plumbing)
```

---

## UI operatorski (`toolkit ui`)

```bash
toolkit ui rshop                   # otwórz http://localhost:8765
```

- Renderuje raporty jako HTML (FinOps, tagging, audit)
- **Kopiuj do Confluence** — rich text do schowka
- Apply tagging per env z partial-safe rendering

---

## Audit packs — dostępne

| Pack | Co robi |
|------|---------|
| `finops-basic` | idle storage, cost hotspots, tagging |
| `tagging` | pełny audyt i plan tagowania |
| `aws-logging` | konfiguracja logowania AWS |
| `observability-ready` | observability check (decision layer) |
| `ecs-delivery-competency` | dowody AWS ECS competency |
| `terraform-standard` | zgodność TF ze standardem |
| `cloudformation-audit` | tagging + CFN scan |
| `llz-basic` | Landing Zone light check |

---

## finops-report — najczęstsze wywołania

```bash
# Executive MTD (domyślny)
toolkit finops-report rshop --period mtd --group-by service

# Techniczny z usage-type
toolkit finops-report rshop --period mtd --group-by usage-type --audience technical

# Poprzedni miesiąc
toolkit finops-report rshop --period last-full-month --group-by service

# Prod only + JSON
toolkit finops-report rshop --period mtd --env prod --format both
```

---

## DEPRECATED / LEGACY (nie używaj)

```bash
toolkit init-project   # → toolkit terraform init-project
toolkit project boot   # → toolkit onboard
toolkit reinit         # → toolkit project refresh
toolkit service create # legacy ECS scaffold (pre-microservice)
```

---

## Powiązane

- [[architecture-overview]]
- [[contracts-index]]
- `~/projekty/devops/devops-toolkit/docs/cli-public-api.md` — pełna klasyfikacja
