# Notebooks Index

## Zasady wspolne

- `[[NOTEBOOKLM_KONTRAKT]]` definiuje kontrakt operacyjny dla wszystkich notebookow.
- Source of truth pozostaje w vault oraz w IaC/runtime.
- Artefakty NotebookLM sa pomocnicze i wymagaja review przed promocja do findings.

## Dostepne notebooki

### Runtime-Incidents

- Katalog roboczy: [[runtime-incidents/notebook-contract]]
- Glowny MOC: [[MOC-Incidents]]
- Typowe zrodla:
  - [[40-runbooks/incidents/README]]
  - [[40-runbooks/incidents/planodkupow-qa-postmortem]]
  - [[40-runbooks/incidents/rshop-prod-503-2026-04-20]]
  - [[20-projects/clients/mako/pbms/context]]
  - [[50-patterns/incident-analysis-patterns]]

### LLZ-Controls

- Katalog roboczy: [[llz-controls/README]]
- Glowny MOC: [[MOC-LLZ]]
- Typowe zrodla:
  - [[20-projects/internal/llz/context]]
  - [[20-projects/internal/llz/waf-checklist]]
  - [[60-toolkit/llz-audit]]
  - [[30-standards/documentation-standard]]

### FinOps-Reference

- Katalog roboczy: [[finops-reference/README]]
- Glowny MOC: [[MOC-FinOps]]
- Typowe zrodla:
  - [[70-finops/README]]
  - [[70-finops/reference-projects]]
  - [[70-finops/optimization-log]]
  - [[20-projects/clients/mako/finops-rshop]]

### CloudFormation-Recovery

- Katalog roboczy: [[cloudformation-recovery/README]]
- Glowny MOC: [[MOC-Recovery-Patterns]]
- Typowe zrodla:
  - [[40-runbooks/incidents/planodkupow-qa-cfn-rebuild]]
  - [[40-runbooks/incidents/planodkupow-qa-rabbitmq-rollback-failed]]
  - [[40-runbooks/incidents/planodkupow-uat-rabbitmq-rollback-failed]]
  - [[40-runbooks/aws/cfn-alb-safe-tagging]]

### PKM-Stack-Mastery

- Katalog roboczy: [[pkm-stack-mastery/README]]
- Kontrakt notebooka: [[pkm-stack-mastery/notebook-contract]]
- Typowe zrodla:
  - [[00-start-here/README]]
  - [[00-start-here/how-to-use-this-vault]]
  - [[90-reference/notebooklm/NOTEBOOKLM_KONTRAKT]]
  - [[40-runbooks/incidents/README]]
  - [[20-projects/internal/llz/context]]

- Cel:
  - onboarding do stacka Obsidian + Claude + NotebookLM
  - nauka pracy na realnym vaultcie
  - cwiczenia, challenge i artefakty robocze zamiast teorii oderwanej od repo

## Planodkupow-refactor

Purpose:
Notebook do przygotowania rozmowy z zespołem projektowym o planodkupow: legacy QA VPC, NAT Gateway, VPC endpoints, RabbitMQ ownership, CloudFormation blast radius, tagging/FinOps i przyszly refactor.

Status:
active / preparation

Primary sources:
- [[40-runbooks/incidents/planodkupow-qa-cfn-rebuild]]
- [[40-runbooks/incidents/planodkupow-qa-postmortem]]
- [[40-runbooks/incidents/planodkupow-qa-execution-log]]
- [[40-runbooks/incidents/planodkupow-qa-rabbitmq-rollback-failed]]
- [[40-runbooks/incidents/planodkupow-uat-rabbitmq-rollback-failed]]
- [[40-runbooks/planodkupow-tagging-finops]]
- [[40-runbooks/planodkupow-rabbitmq-cfn-refactor]]
- [[20-projects/clients/mako/planodkupow-orphan-network-investigation-2026-04-24]]

Boundaries:
- notebook sluzy do przygotowania decyzji
- nie jest cleanup approval
- orphan suspect != deletion candidate
- destructive actions require separate runbook and explicit approval

## Integracja z istniejacymi domenami

- Incidenty sa integrowane z istniejacym obszarem `40-runbooks/incidents/`, bez dublowania notatek.
- LLZ korzysta z istniejacego obszaru `20-projects/internal/llz/`.
- FinOps korzysta z istniejacego obszaru `70-finops/` oraz powiazanych notatek klienckich.
- Nowe notebooki przechowuja kontrakty, prompty, artefakty i findings, a nie kopie notatek zrodlowych.
