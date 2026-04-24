---
date: 2026-04-24
project: planodkupow
tags: [notebooklm, sources, research]
domain: notebooks
---

# Sources Index

Poniżej lista źródeł rekomendowanych do wgrania do NotebookLM dla notebooka `planodkupow-refactor`.

## Core sources to import

### 1. Incident and rebuild context

- [planodkupow-qa-cfn-rebuild.md](/Users/jaroslaw.golab/projekty/devops/devops-knowledge/40-runbooks/incidents/planodkupow-qa-cfn-rebuild.md)
  Cel:
  rekonstrukcja kontekstu przebudowy QA, timeline zmian i możliwych źródeł nowej QA VPC.

- [planodkupow-qa-postmortem.md](/Users/jaroslaw.golab/projekty/devops/devops-knowledge/40-runbooks/incidents/planodkupow-qa-postmortem.md)
  Cel:
  zrozumienie mechaniki awarii, rollbacków, decyzji awaryjnych i zmian wykonanych pod presją incydentu.

- [planodkupow-qa-execution-log.md](/Users/jaroslaw.golab/projekty/devops/devops-knowledge/40-runbooks/incidents/planodkupow-qa-execution-log.md)
  Cel:
  odtworzenie sekwencji wykonawczej i ustalenie, czy czesc legacy artifacts mogla zostac po awaryjnych dzialaniach runtime.

- [planodkupow-qa-rabbitmq-rollback-failed.md](/Users/jaroslaw.golab/projekty/devops/devops-knowledge/40-runbooks/incidents/planodkupow-qa-rabbitmq-rollback-failed.md)
  Cel:
  zrozumienie rozjazdu wokół QA RabbitMQ, rollbacków i możliwego wyjęcia brokera poza standardowy lifecycle.

- [planodkupow-uat-rabbitmq-rollback-failed.md](/Users/jaroslaw.golab/projekty/devops/devops-knowledge/40-runbooks/incidents/planodkupow-uat-rabbitmq-rollback-failed.md)
  Cel:
  porównanie zachowania środowiska UAT i RabbitMQ ownership względem QA.

### 2. Governance / FinOps / tagging context

- [planodkupow-tagging-finops.md](/Users/jaroslaw.golab/projekty/devops/devops-knowledge/40-runbooks/planodkupow-tagging-finops.md)
  Cel:
  osadzenie problemu legacy network artifacts w szerszym kontekście tagowania, FinOps i governance.

### 3. RabbitMQ refactor context

- [planodkupow-rabbitmq-cfn-refactor.md](/Users/jaroslaw.golab/projekty/devops/devops-knowledge/40-runbooks/planodkupow-rabbitmq-cfn-refactor.md)
  Cel:
  materiał wejściowy do rozmowy o ownership RabbitMQ, root lifecycle i możliwym kierunku refactoru.

### 4. Current detective investigation

- [planodkupow-orphan-network-investigation-2026-04-24.md](/Users/jaroslaw.golab/projekty/devops/devops-knowledge/20-projects/clients/mako/planodkupow-orphan-network-investigation-2026-04-24.md)
  Cel:
  aktualny zapis śledztwa read-only o VPC, NAT, VPC endpoints i klasyfikacji `orphan suspect`.

- [planodkupow-ops-context-2026-04-24.md](/Users/jaroslaw.golab/projekty/devops/devops-knowledge/_chatgpt/context-packs/planodkupow-ops-context-2026-04-24.md)
  Cel:
  skondensowany context pack do rozmowy o ownership, retained artifacts i przyszlym refactorze.

## Notebook-local sources to import

- [README.md](/Users/jaroslaw.golab/projekty/devops/devops-knowledge/90-reference/notebooklm/planodkupow-refactor/README.md)
- [sources.md](/Users/jaroslaw.golab/projekty/devops/devops-knowledge/90-reference/notebooklm/planodkupow-refactor/sources.md)
- [notebook-contract.md](/Users/jaroslaw.golab/projekty/devops/devops-knowledge/90-reference/notebooklm/planodkupow-refactor/notebook-contract.md)
- [meeting-brief.md](/Users/jaroslaw.golab/projekty/devops/devops-knowledge/90-reference/notebooklm/planodkupow-refactor/artifacts/meeting-brief.md)
- [hypotheses-and-risks.md](/Users/jaroslaw.golab/projekty/devops/devops-knowledge/90-reference/notebooklm/planodkupow-refactor/findings/hypotheses-and-risks.md)
- [refactor-options.md](/Users/jaroslaw.golab/projekty/devops/devops-knowledge/90-reference/notebooklm/planodkupow-refactor/findings/refactor-options.md)

## Additional evidence to consider importing

Ta sekcja opisuje evidence, które warto rozważyć jako osobne załączniki do NotebookLM, jeśli zostaną przygotowane lub zapisane do vault.

### NAT metrics evidence

Do rozważenia:
- eksport lub zrzut wyników CloudWatch metrics dla:
  - `BytesInFromSource`
  - `BytesOutToDestination`
  - `ActiveConnectionCount`

Cel:
- odróżnić „brak datapoints” od „potwierdzony brak ruchu”
- ograniczyć ryzyko nadinterpretacji wokół NAT

### Orphan VPC evidence

Do rozważenia:
- inventory ENI w starej QA VPC
- inventory EC2 instances w starej QA VPC
- inventory pozostałych attachmentów i zależności do VPC

Cel:
- sprawdzić, czy istnieją ukryte workloady poza ECS/ALB/RDS

### VPC endpoint evidence

Do rozważenia:
- pełny dump legacy endpointów
- mapowanie SG i subnetów endpointów
- dodatkowe evidence dla endpointów starej QA VPC

Cel:
- potwierdzić czy są tylko residual artifacts, czy nadal istnieje realna ścieżka użycia

### Current stack topology

Do rozważenia:
- zrzut aktualnej topologii root stack + nested stacks dla QA/UAT
- lineage `DELETE_COMPLETE` dla starszych QA stacków

Cel:
- rozdzielić active IaC ownership od retained artifacts

### RabbitMQ ownership findings

Do rozważenia:
- broker details QA/UAT
- mapowanie broker → SG → subnet → VPC
- evidence, że QA broker `rabbitmq-cheap` jest aktywny, ale poza bieżącym root lifecycle

Cel:
- przygotować materiał do rozmowy o ownership i przyszłym modelu zarządzania RabbitMQ

## Use guidance

Przy pracy w NotebookLM:
- traktować źródła incydentowe jako context, nie jako aktualną decyzję
- traktować notatkę orphan investigation jako evidence pack, nie cleanup plan
- rozdzielać pytania ownership, runtime usage i governance

## Manual upload list

Jesli lokalne `notebooklm` CLI nie pozwoli automatycznie dodac plikow, do notebooka `Planodkupow-refactor` nalezy recznie wgrac:

- `40-runbooks/incidents/planodkupow-qa-cfn-rebuild.md`
- `40-runbooks/incidents/planodkupow-qa-postmortem.md`
- `40-runbooks/incidents/planodkupow-qa-execution-log.md`
- `40-runbooks/incidents/planodkupow-qa-rabbitmq-rollback-failed.md`
- `40-runbooks/incidents/planodkupow-uat-rabbitmq-rollback-failed.md`
- `40-runbooks/planodkupow-tagging-finops.md`
- `40-runbooks/planodkupow-rabbitmq-cfn-refactor.md`
- `20-projects/clients/mako/planodkupow-orphan-network-investigation-2026-04-24.md`
- `_chatgpt/context-packs/planodkupow-ops-context-2026-04-24.md`
- `90-reference/notebooklm/planodkupow-refactor/README.md`
- `90-reference/notebooklm/planodkupow-refactor/sources.md`
- `90-reference/notebooklm/planodkupow-refactor/notebook-contract.md`
- `90-reference/notebooklm/planodkupow-refactor/artifacts/meeting-brief.md`
- `90-reference/notebooklm/planodkupow-refactor/findings/hypotheses-and-risks.md`
- `90-reference/notebooklm/planodkupow-refactor/findings/refactor-options.md`
