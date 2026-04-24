---
date: 2026-04-24
project: planodkupow
tags: [refactor, options, architecture, operations]
domain: notebooks
---

# Refactor Options

Poniższe warianty służą do rozmowy architektoniczno-operacyjnej. Nie są planem wykonawczym i nie sugerują działań destrukcyjnych.

## Option A — Preserve and document

Opis:
- zachować obecny stan
- formalnie opisać ownership, legacy artifacts i aktywne zależności
- nie wykonywać ruchów sieciowych do czasu pełnej walidacji

### Benefits

- minimalny blast radius
- szybkie uporządkowanie wiedzy bez ryzyka zmian runtime
- pozwala oddzielić fakty od hipotez

### Risks

- pozostaje złożoność architektury
- pozostają niejasności ownership
- FinOps i governance mogą nadal być częściowo nieczytelne

### Unknowns

- czy projekt zaakceptuje dłuższe utrzymanie legacy artifacts
- czy istnieją ukryte koszty i zależności, które wyjdą później

### Prerequisites

- potwierdzenie ownership przez projekt
- rejestr aktywnych i legacy zasobów
- jawna klasyfikacja `active dependency` vs `legacy residual`

## Option B — Migrate dependencies, then retire legacy assets

Opis:
- najpierw zidentyfikować i przenieść zależności ze starej QA VPC
- dopiero po migracji rozważyć retirement legacy assets

### Benefits

- lepsza ścieżka do uproszczenia topologii
- mniejsze długoterminowe koszty utrzymania
- czytelniejszy ownership model

### Risks

- ryzyko pominięcia ukrytej zależności
- ryzyko rozjazdu między RabbitMQ, ECS i networkingiem
- ryzyko, że legacy assets są wykorzystywane przez nieudokumentowane manual flows

### Unknowns

- pełna lista konsumentów NAT i legacy endpointów
- rzeczywisty zakres manual integrations
- docelowy ownership RabbitMQ

### Prerequisites

- twarde evidence użycia / braku użycia
- uzgodniony target architecture dla QA
- walidacja z zespołem projektowym i ownerami biznesowo-operacyjnymi

## Option C — Broader network refactor with ownership cleanup

Opis:
- potraktować temat szerzej niż pojedynczy cleanup
- uporządkować ownership, stack topology, RabbitMQ lifecycle i legacy networking w jednym programie zmian

### Benefits

- największa poprawa spójności architektury
- możliwość domknięcia wieloletnich rozjazdów ownership
- dobra baza pod governance i przyszły toolkit refactor

### Risks

- największy blast radius organizacyjny i techniczny
- większa liczba zależności do skoordynowania
- większe ryzyko, jeśli projekt nie ma pełnej wiedzy o runtime i manualnych obejściach

### Unknowns

- kto ma mandate do decyzji cross-stack / cross-team
- czy projekt chce inwestować w szeroki refactor teraz
- czy istnieją constraints biznesowe blokujące większe zmiany

### Prerequisites

- potwierdzony ownership model
- inventory zależności manualnych i legacy
- uzgodniony docelowy model dla QA RabbitMQ
- osobny assessment ryzyka i kolejności zmian
