# LLM_CONTEXT — 40-runbooks

## Cel katalogu

Procedury operacyjne i incydentowe — gotowe do użycia pod presją czasu. Runbook = wchodzisz z objawem, wychodzisz z działaniem.

## Zakres tematyczny

- Procedury diagnostyczne per technologia (AWS, ECS, Kubernetes, Terraform, networking)
- Logi incydentów produkcyjnych z RCA
- Checklisty bezpiecznych operacji (tagging, ALB, S3)

Nie przechowuj tu planów projektów ani decyzji architektonicznych.

## Najważniejsze notatki

| Plik | Opis |
|------|------|
| `incidents/` | Aktywne i zamknięte incydenty produkcyjne |
| `aws/iam-access-issue.md` | Diagnoza problemów IAM/SCP |
| `aws/cfn-alb-safe-tagging.md` | Bezpieczne tagowanie ALB w CFN |
| `aws/s3-bucket-policy-lockout.md` | Odblokowanie bucket policy |
| `ecs/ecs-deploy-stuck.md` | ECS deployment zakleszczony |
| `ecs/ecs-service-not-starting.md` | ECS serwis nie startuje |
| `terraform/terraform-state-lock.md` | Odblokowywanie state lock |
| `networking/alb-502-503.md` | Diagnoza błędów ALB |
| `incidents/incident-response-checklist.md` | Checklista przy incydencie |

## Konwencje nazewnicze

- Podkatalog per technologia: `aws/`, `ecs/`, `kubernetes/`, `terraform/`, `networking/`
- Incydenty: `incidents/<projekt>-<symptom>-<data>.md`
- Nazwa opisuje objaw, nie przyczynę: `ecs-deploy-stuck.md` nie `missing-iam-role.md`

## Powiązania z innymi katalogami

- `[[../20-projects/]]` — kontekst projektów dla których pisano runbooki
- `[[../50-patterns/]]` — wzorce diagnostyczne ogólne
- `[[../90-reference/]]` — komendy CLI używane w runbookach

## Wiedza trwała vs robocza

- **Trwała:** `aws/`, `ecs/`, `kubernetes/`, `terraform/`, `networking/` — procedury ogólne
- **Robocza:** `incidents/` — aktywne incydenty; zamknięte stają się archiwum

## Jak przygotować kontekst dla ChatGPT

1. Skopiuj właściwy runbook (np. `ecs-deploy-stuck.md`)
2. Dodaj aktualny stan z `02-active-context/now.md`
3. Dodaj error message verbatim — ChatGPT potrzebuje dokładnego tekstu błędu

---

## Ostatnia aktualizacja kontekstu

2026-04-20 — dodano incydenty: rshop-prod-503, planodkupow-qa-cfn-rebuild

## Najważniejsze linki

- `[[incidents/incident-response-checklist]]`
- `[[incidents/planodkupow-qa-postmortem]]`
- `[[aws/iam-access-issue]]`
- `[[ecs/ecs-deploy-stuck]]`
