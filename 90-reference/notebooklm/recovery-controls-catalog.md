# Recovery Controls Catalog

Zbior reusable controls identyfikowanych przez NotebookLM i promowanych po review czlowieka.

## Aktywne kontrole

- RC-001 — Pre-delete ENI audit
  - Status: kandydat
  - Powiazane zrodla: [[40-runbooks/incidents/rshop-tag-policy-remediation]], [[40-runbooks/incidents/rshop-prod-503-2026-04-20]]
  - Tagi: #notebooklm #notebooklm/finding #recovery-pattern #llz-control

- RC-002 — Retain on stateful resources
  - Status: kandydat
  - Powiazane zrodla: [[40-runbooks/incidents/planodkupow-qa-rabbitmq-rollback-failed]], [[40-runbooks/incidents/planodkupow-uat-rabbitmq-rollback-failed]]
  - Tagi: #notebooklm #notebooklm/finding #recovery-pattern

- RC-003 — External DNS dependency check
  - Status: kandydat
  - Powiazane zrodla: [[40-runbooks/networking/alb-502-503]], [[40-runbooks/incidents/incident-response-checklist]]
  - Tagi: #notebooklm #notebooklm/finding #recovery-pattern

## Reguly promocji

- Control trafia tutaj dopiero po human review artefaktu z `artifacts/`.
- Wpis musi wskazywac konkretne zrodla w vault.
- Jesli control stabilizuje sie domenowo, powinien zostac przeniesiony do `[[MOC-LLZ]]` lub do notatki domenowej LLZ.
