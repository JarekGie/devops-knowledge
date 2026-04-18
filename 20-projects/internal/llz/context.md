---
project: llz
type: internal
tags: [llz, terraform, cloudformation, governance, observability, platform, mako]
created: 2026-04-18
updated: 2026-04-18
---

# LLZ — Light Landing Zone

> Kontekst ładowany na początku każdej sesji LLZ. Standalone — bez zależności.

## Co to jest LLZ

**Light Landing Zone (LLZ)** to standard platformowy MakoLab. Obejmuje trzy wymiary:

| Wymiar | Scope | Pack/capability |
|--------|-------|-----------------|
| **Scaffold conformance** | Terraform | `toolkit audit-pack llz-basic` |
| **Observability readiness** | AWS (CFN + Terraform) | `toolkit audit-pack aws-logging` + `observability-ready` |
| **Tagging governance** | AWS (CFN + Terraform) | `toolkit audit-pack tagging` + CFN tagging contract |

LLZ NIE jest pełnym AWS Landing Zone (Control Tower, multi-account governance).
LLZ JEST: minimalnym zestawem standardów operacyjnych na poziomie projektu.

---

## Wymiar 1 — Scaffold conformance (Terraform only)

Weryfikacja: czy projekt Terraform ma poprawną strukturę, scaffold i polityki.

```bash
toolkit audit-pack llz-basic --project-root ~/projekty/mako/<infra-projekt>
```

Trzy obszary:

| Obszar | Plugin | Co sprawdza |
|--------|--------|-------------|
| A — Struktura | `llz-project-structure` | `envs/`, `project.yaml`, `README.md`, `.gitignore` |
| B — Scaffold | `llz-scaffold-conformance` | `backend.tf` (S3, bez placeholderów), `versions.tf`, wzorzec `main.tf` |
| C — Polityki | `llz-policy-conformance` | scheduler dev/qa=on prod=off, `enforce_tagging`, `enforce_finops` |

Statyczny — bez wywołań AWS API.

---

## Wymiar 2 — Observability readiness (wszystkie projekty AWS)

Trzyetapowy flow:

```bash
# Step 1: audit pokrycia logowaniem (wywołuje AWS API)
toolkit audit-pack aws-logging

# Step 2 (opcjonalnie): wygeneruj plan patchy Terraform
toolkit audit-pack aws-logging --patch-plan

# Step 3: verdict czy można aplikować
toolkit audit-pack observability-ready
```

**Co audytuje `aws-logging`:**
- ECS service / task definition / logConfiguration
- CloudWatch log groups (aktywność streamów)
- ALB access logs
- CloudFront standard logging
- ElastiCache log delivery
- VPC Flow Logs
- WAF logging

**Artefakty:**
- `logging-matrix.json` — source of truth (gap_classification per resource)
- `report.md`, `resources.json`, `terraform-mapping.md`
- `patch-plan.json`, `plan.md`, `changed-files.md`, `risk-notes.md` (jeśli --patch-plan)

**`observability-ready` verdict:**
- `ready_to_apply: true/false` — czy patch plan można aplikować bez ryzyka
- Nie wywołuje AWS — operuje na artefaktach z poprzedniego runu
- `ready_to_operate: false` zawsze w v1 (weryfikacja post-apply nie zaimplementowana)

**Klasyfikacje gap:**
`NOT_ENABLED` | `ENABLED_BUT_EMPTY` | `ENABLED_AND_HAS_DATA` | `UNKNOWN` | `ORPHANED_DESTINATION` | `NOT_SUPPORTED`

---

## Wymiar 3 — Tagging governance (wszystkie projekty AWS)

```bash
# CloudFormation
toolkit audit-pack tagging --project-root ~/projekty/mako/<infra-cfn>

# Tagging + apply (tylko CFN, z safety check)
toolkit apply-pack tagging mako/<projekt> --env <env>
```

**Standard tagowania LLZ (oparty na rzeczywistym użyciu, audit 2026-04-18):**

| Tag key | Wymagane | Dozwolone wartości | Uwagi |
|---------|----------|--------------------|-------|
| `Project` | TAK | rshop, booking, dacia-asystent, planodkupow, cc, akcesoria2, platform, drp-tfs | +nowe projekty przy onboardingu |
| `Environment` | TAK | dev, qa, uat, prod, test, poc | |
| `ManagedBy` | zalecane | Terraform, cloudformation, manual | |
| `Owner` | zalecane | DC-devops, DC/IT | |

**Enforced przez AWS Tag Policies** (org-wide, Root):
- `llz-project` (p-95oz353nfp) — waliduje wartości `Project`
- `llz-environment` (p-9554uyl3h8) — waliduje wartości `Environment`

CFN tagging contract (LLZ v1):
- `CFN_TAG_001` ERROR: `Tags` na resource type bez CFN schema support
- `CFN_TAG_002` ERROR: zmiana tagów na frozen resource
- `CFN_TAG_003` WARN: brakujące tagi na `AWS::CloudFormation::Stack`
- `CFN_TAG_004` WARN: zduplikowane tagi w leaf resource
- `CFN_TAG_006` ERROR: katalog backup w zakresie skanowania

---

## Canonical operator flow (pełny LLZ check)

```bash
# 1. Scaffold (Terraform)
toolkit audit-pack llz-basic

# 2. Tagging
toolkit audit-pack tagging

# 3. Observability
toolkit audit-pack aws-logging
toolkit audit-pack observability-ready

# Lub wszystko przez:
toolkit check  # uruchamia full dry-run sanity pipeline
```

---

## Stan obecny (2026-04-18)

```
Toolkit LLZ:              zaimplementowany (wszystkie 3 wymiary)
Onboarding org:           nie rozpoczęty
Projekty audytowane:
  mako/rshop (CFN):       tagging DONE (dev 11/14, prod 12/13 compliant)
                          observability: 9 findings (ALB, CF, VPC — backlog)
  Terraform projekty:     niezbadane — wymaga inwentaryzacji
```

## Cele

1. Zinwentaryzować wszystkie projekty Terraform w organizacji → uruchomić `llz-basic`
2. Dla każdego projektu CFN: `audit-pack tagging` + `audit-pack aws-logging`
3. Zintegrować LLZ check w CI/CD (Jenkins/Atlantis)
4. Dokumentacja procesu onboardingu dla devopsów (Confluence)

## Powiązane

- [[session-log]] — historia sesji
- [[progress-tracker]] — stan onboardingu projektów
- `60-toolkit/llz-audit.md` — scaffold conformance (szczegóły reguł A/B/C)
- `60-toolkit/observability-ready.md` — observability readiness (szczegóły)
- `20-projects/clients/mako/finops-rshop.md` — rshop: backlog observability
- Kontrakty: `devops-toolkit/docs/kontrakty/39-kontrakt-llz.md`
