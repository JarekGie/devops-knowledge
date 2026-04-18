---
source: devops-toolkit/docs/llz-audit.md
synced: 2026-04-18
tags: [llz, terraform, audit, toolkit]
---

# LLZ Audit — dokumentacja operatorska

> Mirror z `devops-toolkit/docs/llz-audit.md`. Aktualizuj przy każdej zmianie w source.

## Co to jest LLZ audit

**LLZ audit** to capability devops-toolkit weryfikująca zgodność projektu Terraform
ze standardem platformowym **Light Landing Zone (LLZ)** MakoLab.

LLZ audit v1 odpowiada na pytanie:

> Czy to repo projektu Terraform jest LLZ-ready — gotowe do działania na platformie MakoLab?

To jest **statyczny audit lokalny** — nie wymaga dostępu do AWS.
Analizuje strukturę katalogów, pliki konfiguracyjne i deklaracje standardów.

## Jak uruchomić

```bash
# Z katalogu projektu Terraform
cd ~/projekty/mako/infra-myapp
toolkit audit-pack llz-basic

# Z podaniem ścieżki
toolkit audit-pack llz-basic --project-root ~/projekty/mako/infra-myapp
```

Wyniki zapisują się do `.devops-toolkit/runs/<run-id>/findings/`.

## Co sprawdza LLZ audit v1

### Obszar A — Struktura projektu

| ID | Opis | Severity |
|----|------|----------|
| LLZ-A-001 | `.devops-toolkit/project.yaml` istnieje | HIGH |
| LLZ-A-002 | `project.yaml` deklaruje `iac_type: Terraform` | MEDIUM |
| LLZ-A-003 | `envs/` zawiera co najmniej jedno środowisko | HIGH |
| LLZ-A-004 | Każde środowisko ma `main.tf` | HIGH |
| LLZ-A-005 | `README.md` istnieje | LOW |
| LLZ-A-006 | `.gitignore` chroni `.devops-toolkit/` | MEDIUM |

### Obszar B — Standard scaffoldu

| ID | Opis | Severity |
|----|------|----------|
| LLZ-B-001 | `backend.tf` istnieje w każdym env | HIGH |
| LLZ-B-002 | `versions.tf` istnieje w każdym env | MEDIUM |
| LLZ-B-003 | `terraform.tfvars` istnieje w każdym env | LOW |
| LLZ-B-004 | `backend.tf` używa S3 backend (nie local) | HIGH |
| LLZ-B-005 | Projekt app-stack deklaruje ECR per env w `project.yaml` | MEDIUM |
| LLZ-B-006 | Brak nieuzupełnionych placeholderów `<TO_FILL>` w `backend.tf` | HIGH |
| LLZ-B-007 | `main.tf` używa zatwierdzonego patternu z `project.yaml` | HIGH |
| LLZ-B-008 | `backend.bucket` spełnia konwencję nazewniczą LLZ | MEDIUM |
| LLZ-B-010 | `client.name` uzupełniony (nie `FILL_IN`) | MEDIUM |
| LLZ-B-011 | `finops.billing_profile` uzupełniony | MEDIUM |
| LLZ-B-012 | `cloud.profile` uzupełniony | MEDIUM |

### Obszar C — Polityki

| ID | Opis | Severity |
|----|------|----------|
| LLZ-C-001 | Env dev/qa ma scheduler włączony | LOW |
| LLZ-C-002 | Env prod NIE ma scheduler=true | MEDIUM |
| LLZ-C-003 | `project.yaml` deklaruje `enforce_tagging: true` | MEDIUM |
| LLZ-C-004 | `project.yaml` deklaruje `enforce_finops: true` | MEDIUM |

## Czego NIE sprawdza LLZ v1

- Brak wywołań AWS API (w pełni statyczny)
- Nie weryfikuje live zasobów AWS (ECR, S3 backend, tagging)
- Nie sprawdza AWS Organizations / Control Tower
- Nie audytuje zawartości modułów Terraform

## Projekt LLZ-ready po `toolkit terraform init-project`

Projekt wygenerowany przez init-project jest strukturalnie LLZ-ready od razu.
Wymaga uzupełnienia 3 pól (`client.name`, `cloud.profile`, `finops.billing_profile`) — potem 0 findings.

```bash
toolkit terraform init-project \
  --project-name myapp --cloud aws --region eu-central-1 \
  --pattern app-stack --envs dev,qa,prod

cd myapp
# uzupełnij project.yaml
toolkit audit-pack llz-basic  # → 0 findings
```

## Powiązane

- [[../20-projects/internal/llz/context]] — kontekst projektu LLZ w organizacji
- [[../20-projects/internal/llz/progress-tracker]] — stan onboardingu projektów
- Kontrakt source: `devops-toolkit/docs/kontrakty/39-kontrakt-llz.md`
