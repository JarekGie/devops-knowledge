---
date: 2026-04-24
project: planodkupow
tags: [notebooklm, research, refactor, planodkupow, architecture, operations]
domain: notebooks
---

# planodkupow-refactor

Pakiet startowy pod nowy notebook NotebookLM o nazwie `planodkupow-refactor`.

Cel notebooka:
- przygotowanie do rozmowy z zespołem projektowym
- uporządkowanie wiedzy o legacy network artifacts
- ustalenie ownership i rzeczywistych zależności
- przygotowanie gruntu pod przyszły refactor planodkupow

To **nie** jest kolejna notatka incydentowa.
To **nie** jest cleanup runbook.
To **nie** jest materiał autoryzujący jakiekolwiek działania destrukcyjne.

Notebook ma służyć do:
- analizy źródeł
- konfrontacji hipotez z evidence
- przygotowania pytań do projektu
- porównania opcji refactoru
- obniżenia ryzyka błędnych decyzji wokół legacy assets

## Zawartość pakietu

- [SOURCES_INDEX.md](/Users/jaroslaw.golab/projekty/devops/devops-knowledge/30-notebooks/planodkupow-refactor/SOURCES_INDEX.md)
- [QUESTIONS_FOR_PROJECT_TEAM.md](/Users/jaroslaw.golab/projekty/devops/devops-knowledge/30-notebooks/planodkupow-refactor/QUESTIONS_FOR_PROJECT_TEAM.md)
- [HYPOTHESES_AND_RISKS.md](/Users/jaroslaw.golab/projekty/devops/devops-knowledge/30-notebooks/planodkupow-refactor/HYPOTHESES_AND_RISKS.md)
- [REFactor_OPTIONS.md](/Users/jaroslaw.golab/projekty/devops/devops-knowledge/30-notebooks/planodkupow-refactor/REFactor_OPTIONS.md)
- [MEETING_BRIEF.md](/Users/jaroslaw.golab/projekty/devops/devops-knowledge/30-notebooks/planodkupow-refactor/MEETING_BRIEF.md)

## Sposób użycia

1. Wgrać do NotebookLM źródła z `SOURCES_INDEX.md`.
2. Traktować `planodkupow-orphan-network-investigation-2026-04-24.md` jako input śledczy, nie jako decyzję cleanup.
3. Użyć `QUESTIONS_FOR_PROJECT_TEAM.md` jako checklisty na spotkanie.
4. Użyć `REFactor_OPTIONS.md` do porównania wariantów architektoniczno-operacyjnych.
5. Użyć `MEETING_BRIEF.md` jako krótkiego materiału otwierającego rozmowę.

## Granice tego notebooka

- bez decyzji wykonawczych
- bez sugestii usuwania zasobów
- bez założenia, że `orphan suspect` oznacza orphan confirmed
- bez zamykania pytań ownership bez walidacji z zespołem projektowym

## NotebookLM prompts

1. Which resources are likely orphan candidates versus active dependencies?
2. What evidence contradicts deleting the old QA VPC?
3. What are the hidden dependency risks around the NAT gateway?
4. Which findings are confirmed facts versus inference?
5. How should we classify the QA RabbitMQ cheap broker: active dependency, external ownership, or refactor artifact?
6. What refactor path minimizes blast radius while improving ownership clarity?
7. Which legacy artifacts look retained after CloudFormation deletion and what evidence supports that?
8. What evidence is still missing before any cleanup assessment could even begin?
9. How should compliance findings be separated between active runtime and legacy residual assets?
10. Which meeting decisions are required from the project team before any network refactor planning can proceed?
