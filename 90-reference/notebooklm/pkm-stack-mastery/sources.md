# PKM-Stack-Mastery Sources

Ten notebook powinien byc zasilany warstwowo. Nie ladowac wszystkiego na start.
Buduj source pack pod konkretny poziom, lekcje albo challenge.

## A. Wybrane zrodla z vaulta

### Po co sa

To podstawowy material roboczy do nauki stacka na realnym repo. Pokazuja jak sa
uzywane kontrakty, kontekst aktywny, runbooki, wzorce incydentowe i obszar LLZ.

### Co wnosza

- `00-start-here/` daje warstwe wejscia do vaulta i sposob poruszania sie po nim
- `90-reference/notebooklm/` pokazuje kontrakty, indeks i strukture notebookow
- `40-runbooks/incidents/` dostarcza realnych przypadkow do contradiction check, handoffow i extraction
- `20-projects/internal/llz/` daje material do pracy z governance, kontrolkami i MOC

### Czego nie wrzucac na start

- calych katalogow bez selekcji
- plikow pobocznych niezwiazanych z aktualna lekcja
- plikow tylko dlatego, ze sa "wazne", bez powiazania z celem cwiczenia

### Przykladowe pliki startowe

- [[00-start-here/README]]
- [[00-start-here/how-to-use-this-vault]]
- [[90-reference/notebooklm/README]]
- [[90-reference/notebooklm/NOTEBOOKLM_KONTRAKT]]
- [[40-runbooks/incidents/README]]
- [[40-runbooks/incidents/planodkupow-qa-postmortem]]
- [[20-projects/internal/llz/context]]

## B. Dokumentacje narzedzi

### Po co sa

Daja zewnetrzny model dzialania narzedzi, zeby nie opierac nauki tylko na lokalnym
repo i intuicji.

### Co wnosza

- Obsidian docs: nawigacja, linkowanie, praca z notatkami i wyszukiwaniem
- NotebookLM docs: model pracy ze zrodlami, artefaktami i sesjami
- Claude Code docs: workflow pracy agenta na repo, kontrakty wykonywania i edycji
- materialy PARA / MOC / Evergreen Notes: jezyk projektowania osobistej architektury wiedzy
- opcjonalnie "LLM as OS": model laczenia narzedzi w jeden system operacyjny dla wiedzy

### Czego nie wrzucac na start

- zbyt szerokich kompendiow PKM bez zwiazku z Twoim vaultem
- wielu konkurencyjnych metodologii naraz
- materialow marketingowych zamiast dokumentacji i praktyk

## C. Research corpus do dodania przez NotebookLM

### Po co jest

To warstwa rozwojowa. Ma dodac wzorce, ktorych jeszcze nie ma w vaultcie, ale ktore
moga wzbogacic praktyke.

### Co wnosi

- advanced Obsidian workflows with LLMs
- knowledge management with NotebookLM
- integracje LLM + personal knowledge workflows
- przyklady praktyk dydaktycznych dla nauki przez artefakty

### Czego nie wrzucac na start

- przypadkowych blogow bez jasnej wartosci operacyjnej
- materialow oderwanych od Obsidiana, NotebookLM i pracy na repo
- researchu, ktory ma zastapic lokalne zrodla zamiast je uzupelniac

## D. Kontrakt instruktora jako pierwsza notatka zrodlowa

### Po co jest

To zrodlo sterujace zachowaniem notebooka. Ustawia role instruktora, poziom
uzytkownika, zasady jezyka i granice odpowiedzialnosci.

### Co wnosi

- stabilny sposob prowadzenia lekcji
- preferencje praktyki nad teoria
- wymuszenie pracy na realnym vaultcie
- kontrakt na mikrolekcje, cwiczenia, quizy i challenge

### Czego nie wrzucac na start

- dodatkowych meta-instrukcji, ktore duplikuja ten kontrakt
- ogolnych zasad bez przelozenia na konkretne zadania
- kilku roznych kontraktow instruktora naraz

### Wymaganie

Pierwszym zrodlem w notebooku powinien byc:

- [[notebook-contract]]
