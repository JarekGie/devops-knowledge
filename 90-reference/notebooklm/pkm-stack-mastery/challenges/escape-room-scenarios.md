# Escape Room Scenarios

## Scenariusz 1 - Incydent bez mapy

### Sytuacja

Masz incydent. Zrodla sa rozproszone miedzy runbookami, postmortemem i notatkami projektu.
Masz dojsc do wstepnego RCA bez zgadywania.

### Dostepne zrodla

- [[40-runbooks/incidents/README]]
- [[40-runbooks/incidents/planodkupow-qa-postmortem]]
- [[40-runbooks/incidents/rshop-prod-503-2026-04-20]]
- [[20-projects/clients/mako/pbms/context]]

### Ograniczenia

- nie ladowac calego katalogu `40-runbooks/`
- oddzielic fakty od hipotez
- nie promowac wyniku do findings bez review

### Expected output

- briefing incydentu
- lista sprzecznosci
- kandydat na recovery control

### Warunek zaliczenia

Wynik wskazuje zrodla dla kluczowych faktow i proponuje jeden konkretny plik do dalszej aktualizacji.

## Scenariusz 2 - Briefing z chaosu zrodel

### Sytuacja

Masz zbudowac briefing z rozproszonych zrodel o stacku wiedzy, ale bez tworzenia drugiego systemu obok vaulta.

### Dostepne zrodla

- [[00-start-here/README]]
- [[00-start-here/how-to-use-this-vault]]
- [[90-reference/notebooklm/README]]
- [[notebook-contract]]
- [[curriculum]]

### Ograniczenia

- briefing ma byc operacyjny, nie marketingowy
- max 8 zrodel w source packu
- wszystko po polsku

### Expected output

- onboarding briefing
- lista plikow startowych
- propozycja pierwszej mikrolekcji

### Warunek zaliczenia

Briefing prowadzi do konkretnego nastepnego kroku w vaultcie, a nie do abstrakcyjnej teorii PKM.

## Scenariusz 3 - Sprzecznosc miedzy runbookiem a stanem wiedzy

### Sytuacja

Podejrzewasz, ze runbook i inne notatki operacyjne opisuja ten sam proces niespojnie.

### Dostepne zrodla

- [[40-runbooks/incidents/incident-response-checklist]]
- [[40-runbooks/incidents/planodkupow-qa-cfn-rebuild]]
- [[40-runbooks/incidents/planodkupow-qa-rabbitmq-rollback-failed]]
- [[90-reference/notebooklm/runtime-incidents/prompts/contradiction-check]]

### Ograniczenia

- nie zgadywac brakujacych krokow
- nie poprawiac zrodel przed wskazaniem sprzecznosci
- wynik ma wskazac luki i ryzyka

### Expected output

- contradiction audit
- lista luk
- propozycja pliku do aktualizacji

### Warunek zaliczenia

Sprzecznosci sa przypisane do konkretnych dokumentow, a brakujace informacje sa nazwane jawnie.

## Scenariusz 4 - Minimalny recovery control contract

### Sytuacja

Masz zaprojektowac minimalny recovery control contract na podstawie kilku incidentow,
tak aby wynik nadawal sie do review i dalszego rozwijania w LLZ.

### Dostepne zrodla

- [[40-runbooks/incidents/rshop-tag-policy-remediation]]
- [[40-runbooks/incidents/rshop-prod-503-2026-04-20]]
- [[20-projects/internal/llz/context]]
- [[90-reference/notebooklm/recovery-controls-catalog]]

### Ograniczenia

- nie tworzyc ogolnych zasad bez zrodel
- wynik ma byc minimalny i testowalny
- notebook nie podejmuje decyzji wdrozeniowej

### Expected output

- recovery control draft
- warunki uzycia
- lista zrodel i luk

### Warunek zaliczenia

Kontrakt jest oparty na zrodlach, ma jasny zakres i nie udaje gotowej polityki produkcyjnej.
