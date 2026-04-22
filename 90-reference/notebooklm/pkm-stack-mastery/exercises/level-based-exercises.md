# Level-Based Exercises

## Level 1 - Vault Navigation

- Znajdz aktywny kontekst w vault i wskaz 5 plikow, od ktorych zaczalbys onboarding.
- Zbuduj pierwszy source pack dla pytania: "Jak ten vault rozdziela source of truth od warstwy syntezy?"
- Napisz krotka notatke wyjasniajaca roznice miedzy `00-start-here/` a `90-reference/notebooklm/`.

## Level 2 - MOC Architecture

- Wybierz obszar `incidents`, `llz` albo `finops` i zbuduj roboczy MOC prowadzacy do najwazniejszych zrodel.
- Wskaz 3 linki, ktorych brakuje w istniejacej architekturze nawigacji, ale nie nadpisuj notatek domenowych bez potrzeby.
- Opisz, ktore sekcje MOC sa warstwa nawigacji, a ktore tylko lista plikow.

## Level 3 - Incident Knowledge Graphs

- Uzyj NotebookLM do contradiction check na wybranych notatkach z `40-runbooks/incidents/`.
- Przygotuj liste reusable controls wyciagnietych z co najmniej dwoch incidentow.
- Zbuduj krotki incident graph: incident -> anti-pattern -> control -> plik do aktualizacji.

## Level 4 - Claude + Obsidian Workflows

- Przygotuj handoff note dla Claude do aktualizacji wybranego MOC albo kontraktu.
- Zidentyfikuj, ktore dane z source packa sa wystarczajace do wykonania zmiany, a ktore wymagaja dalszej weryfikacji.
- Zrob probe workflow: NotebookLM generuje briefing, a potem Claude aktualizuje jedna notatke pomocnicza w vault.

## Level 5 - NotebookLM as Reasoning Copilot

- Porownaj wynik `contradiction check` i `gap analysis` dla tego samego source packa.
- Ocen, czy artefakt ma provenance i czy nadaje sie do review.
- Przygotuj checklista review dla jednego wygenerowanego artefaktu.

## Level 6 - Personal Ops Knowledge System

- Zbuduj osobisty workflow tygodniowy oparty na realnych katalogach tego vaulta.
- Okresl zasady promocji wynikow do `findings/` i zasady usuwania artefaktow efemerycznych.
- Zaprojektuj minimalny recovery control contract na podstawie incidentow i wlacz go do osobistego systemu pracy.
