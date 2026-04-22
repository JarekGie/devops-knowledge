# PKM-Stack-Mastery Curriculum

Kurs jest zaprojektowany jako progres przez realny stack:
Obsidian + Claude + NotebookLM + vault.

## Level 1 - Vault Navigation

### Cel

Zrozumiec jak poruszac sie po vaultcie i jak odnajdywac aktywny kontekst.

### Czego mam sie nauczyc

- rozpoznawac warstwy vaulta
- znajdowac pliki startowe i indeksy
- odroznic source of truth od artefaktow pomocniczych
- budowac maly source pack do konkretnego pytania

### Wymagane zrodla

- [[00-start-here/README]]
- [[00-start-here/how-to-use-this-vault]]
- [[90-reference/notebooklm/README]]
- [[notebook-contract]]

### Cwiczenia praktyczne

- znajdz aktywny kontekst i opisz, ktore pliki pelnia role wejscia
- zbuduj pierwszy source pack do nauki stacka
- opisz roznice miedzy kontraktem globalnym a kontraktem notebooka

### Kryterium zaliczenia

Potrafisz wskazac zestaw 5-8 plikow startowych i uzasadnic, dlaczego wlasnie one
sa potrzebne do pierwszej sesji NotebookLM.

### Artefakty do wygenerowania

- onboarding briefing
- mapa startowa zrodel
- notatka "jak czytam ten vault"

### Typowe bledy i antywzorce

- czytanie wszystkiego naraz
- mylenie notatek referencyjnych z aktywnym kontekstem
- traktowanie notebooka jako archiwum zamiast warstwy syntezy

## Level 2 - MOC Architecture

### Cel

Nauczyc sie budowac i oceniac MOC jako warstwe nawigacji i kompresji wiedzy.

### Czego mam sie nauczyc

- czym rozni sie MOC od zwyklej listy linkow
- jak laczyc MOC z kontraktami i katalogami referencyjnymi
- jak wskazywac luki w strukturze wiedzy

### Wymagane zrodla

- [[90-reference/notebooklm/_moc/MOC-Incidents]]
- [[90-reference/notebooklm/_moc/MOC-LLZ]]
- [[90-reference/notebooklm/_moc/MOC-FinOps]]
- [[80-architecture/system-maps]]
- [[notebook-contract]]

### Cwiczenia praktyczne

- porownaj dwa istniejace MOC-i i opisz ich role
- zaprojektuj MOC dla wybranego obszaru roboczego
- zidentyfikuj brakujace linki lub nadmiarowe sekcje

### Kryterium zaliczenia

Powstaje MOC roboczy albo plan MOC, ktory prowadzi do konkretnych zrodel zamiast
powielac liste plikow.

### Artefakty do wygenerowania

- draft MOC
- audyt MOC
- lista brakujacych polaczen

### Typowe bledy i antywzorce

- MOC jako dump linkow
- brak rozroznienia miedzy zrodlami, findings i promptami
- projektowanie struktury bez sprawdzenia realnych sciezek w vault

## Level 3 - Incident Knowledge Graphs

### Cel

Nauczyc sie skladac knowledge graph z incidentow, postmortemow i recovery controls.

### Czego mam sie nauczyc

- laczyc incydenty z patternami i kontrolkami
- robic contradiction check na zrodlach operacyjnych
- wyciagac reusable controls bez halucynowania

### Wymagane zrodla

- [[40-runbooks/incidents/README]]
- [[40-runbooks/incidents/planodkupow-qa-postmortem]]
- [[40-runbooks/incidents/rshop-prod-503-2026-04-20]]
- [[90-reference/notebooklm/recovery-controls-catalog]]
- [[90-reference/notebooklm/runtime-incidents/sources]]

### Cwiczenia praktyczne

- zbuduj source pack do analizy jednego wzorca incydentowego
- uzyj NotebookLM do contradiction check
- wypisz kandydatow na reusable controls i przypisz im zrodla

### Kryterium zaliczenia

Powstaje krotki artefakt, ktory oddziela fakty, sprzecznosci i luki oraz wskazuje
minimum jeden control wart review.

### Artefakty do wygenerowania

- contradiction audit
- incident briefing
- recovery control draft

### Typowe bledy i antywzorce

- mieszanie faktow z hipotezami
- brak wskazania zrodel dla wnioskow
- za szybkie promowanie draftu do findings

## Level 4 - Claude + Obsidian Workflows

### Cel

Opanowac przeplyw pracy, w ktorym Claude wykonuje zmiany na repo, a vault pozostaje
source of truth.

### Czego mam sie nauczyc

- jak przygotowac handoff note dla agenta
- jak przejsc od syntezy do wykonania
- jak zamieniac wynik analizy w konkretna zmiane w vaultcie

### Wymagane zrodla

- [[00-start-here/Kontrakt komunikacji — v1]]
- [[_system/AGENTS]]
- [[02-active-context/current-focus]]
- [[02-active-context/open-loops]]
- [[notebook-contract]]

### Cwiczenia praktyczne

- przygotuj handoff note dla Claude do aktualizacji wybranego obszaru
- zbuduj mini workflow: source pack -> NotebookLM -> note -> Claude
- sprawdz, ktore informacje sa jeszcze zbyt slabe do wykonania

### Kryterium zaliczenia

Powstaje handoff note, na podstawie ktorego agent moze wykonac ograniczona, konkretna
zmiane bez domyslow.

### Artefakty do wygenerowania

- handoff note
- task briefing
- lista plikow do aktualizacji

### Typowe bledy i antywzorce

- dawanie agentowi surowego outputu zamiast notatki w vault
- brak rozdzielenia decyzji od implementacji
- brak listy plikow do aktualizacji

## Level 5 - NotebookLM as Reasoning Copilot

### Cel

Uzywac NotebookLM jako copilot reasoning, a nie jako zastępstwa weryfikacji.

### Czego mam sie nauczyc

- kiedy uruchamiac contradiction check
- kiedy uruchamiac gap analysis
- jak projektowac artefakty, ktore wspieraja decyzje, ale ich nie podejmuja

### Wymagane zrodla

- [[../NOTEBOOKLM_KONTRAKT]]
- [[notebook-contract]]
- [[90-reference/notebooklm/runtime-incidents/prompts/contradiction-check]]
- [[90-reference/notebooklm/runtime-incidents/prompts/gap-analysis]]
- [[prompts/contradiction-audit]]

### Cwiczenia praktyczne

- porownaj dwa prompty contradiction check
- uruchom analiza luk dla jednego obszaru wiedzy
- zaproponuj artefakt, ktory po review moze trafic do findings

### Kryterium zaliczenia

Potrafisz zaprojektowac prompt i ocenic, czy wynik jest wystarczajaco dobrze podparty,
aby przejsc do review.

### Artefakty do wygenerowania

- contradiction report
- gap analysis
- checklista review artefaktu

### Typowe bledy i antywzorce

- delegowanie weryfikacji do modelu
- zbyt szeroki source pack
- brak provenance przy artefakcie

## Level 6 - Personal Ops Knowledge System

### Cel

Zlozyc caly stack w osobisty system operacyjny do pracy z wiedza techniczna i operacyjna.

### Czego mam sie nauczyc

- jak laczyc onboarding, MOC, incidenty i governance w jeden przeplyw
- jak promowac wartosciowe wnioski do stabilnych notatek
- jak utrzymywac system bez dublowania tresci

### Wymagane zrodla

- [[curriculum]]
- [[sources]]
- [[exercises/level-based-exercises]]
- [[challenges/escape-room-scenarios]]
- [[90-reference/notebooklm/notebooks-index]]

### Cwiczenia praktyczne

- zaprojektuj swoj tygodniowy workflow pracy z vaultem
- okresl, ktore artefakty maja byc efemeryczne, a ktore promowane
- zbuduj minimalny system przegladu findings i source packow

### Kryterium zaliczenia

Powstaje operacyjny plan pracy z wiedza, ktory laczy realne katalogi, NotebookLM,
Claude i review czlowieka.

### Artefakty do wygenerowania

- personal ops playbook
- review cadence
- kontrakt promocji findings

### Typowe bledy i antywzorce

- mnozenie struktur bez potrzeby
- tworzenie drugiego systemu obok vaulta
- brak regularnego review i czyszczenia artefaktow roboczych
