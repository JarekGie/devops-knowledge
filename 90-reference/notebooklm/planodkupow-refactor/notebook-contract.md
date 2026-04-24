# Notebook Contract

## Purpose

- Nazwa notebooka: `Planodkupow-refactor`
- Zakres: przygotowanie rozmowy z zespołem projektowym o legacy QA VPC, NAT Gateway, VPC endpoints, ownership RabbitMQ, tagging/FinOps i przyszlym refactorze
- Owner: zespol projektowy + operator przygotowujacy material decyzyjny

## Allowed use

- synthesis
- contradiction check
- gap analysis
- pattern extraction
- artifact generation

## Source packs

- glowna domena: `planodkupow`
- preferowane zrodla:
  - `40-runbooks/incidents/planodkupow-qa-cfn-rebuild.md`
  - `40-runbooks/incidents/planodkupow-qa-postmortem.md`
  - `40-runbooks/incidents/planodkupow-qa-execution-log.md`
  - `40-runbooks/incidents/planodkupow-qa-rabbitmq-rollback-failed.md`
  - `40-runbooks/incidents/planodkupow-uat-rabbitmq-rollback-failed.md`
  - `40-runbooks/planodkupow-tagging-finops.md`
  - `40-runbooks/planodkupow-rabbitmq-cfn-refactor.md`
  - `20-projects/clients/mako/planodkupow-orphan-network-investigation-2026-04-24.md`
  - `_chatgpt/context-packs/planodkupow-ops-context-2026-04-24.md`
- wykluczenia:
  - cleanup approval
  - deletion plans
  - niezweryfikowane tezy o orphanach jako faktach

## Output contract

- domyslny jezyk: polski
- wymagane provenance: tak
- human review przed findings: tak

## Promotion rules

- co moze trafic do findings:
  - potwierdzone fakty o ownership, dependencies, blast radius i governance
  - porownanie wariantow refactoru z jasno oznaczonymi lukami
- co pozostaje tylko artefaktem roboczym:
  - hipotezy cleanup
  - spekulacje o braku ruchu
  - szkice decyzji bez walidacji z zespolem projektowym
