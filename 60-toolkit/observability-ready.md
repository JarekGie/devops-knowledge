---
source: devops-toolkit/docs/capabilities/observability-ready.md + aws-logging-audit.md + aws-logging-patch-plan.md
synced: 2026-04-18
tags: [observability, logging, aws, toolkit, llz]
---

# Observability Readiness — dokumentacja operatorska

> Mirror z `devops-toolkit/docs/capabilities/`. Aktualizuj przy każdej zmianie w source.

## Flow operatorski

```bash
# Step 1: audit pokrycia logowaniem (wywołuje AWS API)
toolkit audit-pack aws-logging

# Step 2 (opcjonalnie): wygeneruj plan patchy Terraform
toolkit audit-pack aws-logging --patch-plan

# Step 3: verdict czy można aplikować
toolkit audit-pack observability-ready
```

## aws-logging-audit — co audytuje

Scope v1 (read-only, wywołuje AWS API):
- ECS service / task definition / `logConfiguration`
- CloudWatch log groups i aktywność streamów
- ALB access logs
- CloudFront standard logging + wykrycie realtime logging
- ElastiCache log delivery (slow / engine log)
- VPC Flow Logs
- WAF logging
- Deterministyczne mapowanie do Terraform z lokalnego repo

Artefakty w `.devops-toolkit/runs/<run_id>/`:
- `logging-matrix.json` — kanoniczna maszyna (gap_classification per resource)
- `resources.json` — inwentarz zasobów
- `report.md` — human-readable
- `terraform-mapping.md` — mapowanie do plików Terraform
- `suspicious-or-empty-destinations.json`

Klasyfikacje gap:

| gap_classification | Znaczenie |
|-------------------|-----------|
| `NOT_ENABLED` | logging nie skonfigurowany lub brakuje destination |
| `ENABLED_BUT_EMPTY` | skonfigurowany, destination istnieje, brak danych historycznych |
| `ENABLED_AND_HAS_DATA` | działa poprawnie |
| `UNKNOWN` | brak wystarczających dowodów |
| `ORPHANED_DESTINATION` | destination istnieje, brak aktywnej relacji source→dest |
| `NOT_SUPPORTED` | resource type nie wspiera logowania |

## aws-logging-patch-plan — co generuje

Wejście: artefakty z `aws-logging-audit`.
Wyjście:
- `patch-plan.json` — maszynowy plan
- `plan.md` — human-readable summary
- `changed-files.md` — wskazanie plików Terraform do zmiany
- `risk-notes.md` — notatki ryzyka

Capability NIE generuje kodu Terraform automatycznie. NIE uruchamia `terraform apply`.

Logika decyzji (konserwatywna — wątpliwe = INVESTIGATE):

| gap_classification | terraform_managed | Wynik |
|---|---|---|
| `NOT_SUPPORTED` | * | OUT_OF_SCOPE |
| `NOT_ENABLED` + `logging_expected=false` | * | OUT_OF_SCOPE |
| `NOT_ENABLED` + `logging_expected=true` | true/partial | ADD lub MODIFY |
| `NOT_ENABLED` + `logging_expected=true` | false/unknown | INVESTIGATE |
| `ENABLED_BUT_EMPTY` | * | INVESTIGATE |
| `ORPHANED_DESTINATION` | true | REMOVE |
| `UNKNOWN` | * | INVESTIGATE |

## observability-ready — verdict

Czyta artefakty z `aws-logging-audit`. Nie wywołuje AWS.

Outputs:
- `readiness-summary.json` — verdict + classified findings
- `pre-apply-review.md` — human-readable pre-apply review

`ready_to_apply = (count(BLOCKER) == 0)`

BLOCKER = `NOT_ENABLED` + `logging_expected=true` + `terraform_managed in (true, partial)`

`ready_to_operate = false` zawsze w v1 (post-apply verification nie zaimplementowane).

## Ograniczenia v1

- CloudFront realtime logging klasyfikowany zachowawczo → często `UNKNOWN`
- Mapowanie Terraform z lokalnego repo (nie z `terraform state`)
- `ready_to_operate` nie zaimplementowane — nie możesz przez toolkit potwierdzić że logi faktycznie przychodzą

## Powiązane

- [[../20-projects/internal/llz/context]] — kontekst LLZ
- `toolkit audit-pack aws-logging` — uruchomienie
- `devops-toolkit/docs/capabilities/aws-logging-audit.md` — pełna spec
