# Cloud Detective

## Cel notatki

Robocze miejsce do myślenia o Cloud Detective jako capability wewnątrz prywatnego `devops-toolkit`.

To nie jest finalna architektura, oferta ani branding. To mapa pytań, granic i możliwych zastosowań.

## Stan obecny

- `devops-toolkit` już ma elementy potrzebne do rozpoznania środowiska: audit packi, discovery, FinOps, tagging, observability i raporty.
- Nie ma jeszcze decyzji, czy Cloud Detective będzie osobną komendą, packiem, aliasem, czy tylko nazwą warstwy capability.
- Nie ma finalnego modelu raportu ani UI.

## Czym roboczo jest Cloud Detective

Hipoteza: Cloud Detective to warstwa rozpoznania i oceny środowiska cloud.

Może spinać:

- read-only discovery,
- mapę środowiska,
- assessment operatorski,
- wejście do FinOps / governance / observability,
- raport startowy po onboardingu klienta lub projektu.

## Relacja do devops-toolkit

Cloud Detective nie jest osobnym silnikiem.

Jest capability / warstwą rozpoznania i oceny środowiska wewnątrz `devops-toolkit`.

Musi trzymać zasady toolkitu:

- local-first,
- stateless,
- contract-first,
- read-only by default dla audytów,
- dane klientów nie żyją w repo toolkitu,
- artefakty klienta żyją w repo klienta pod `.devops-toolkit/`,
- raw data nie trafiają do AI,
- do AI mogą trafiać tylko `sanitized/` i `findings/`.

## Jakie problemy ma rozwiązywać

- Szybsze wejście w nowe środowisko.
- Szybsze zbudowanie mapy zasobów i zależności.
- Mniej ręcznego zbierania danych z AWS CLI, Terraform i dokumentacji.
- Lepszy punkt startowy do rozmowy operatorskiej.
- Powtarzalny raport bazowy dla FinOps, governance i observability.

## Czego jeszcze nie wiemy

- Czy to ma być osobna komenda.
- Jaki ma być minimalny output MVP.
- Czy głównym artefaktem ma być raport, zestaw findings, mapa środowiska czy wszystko razem.
- Jak odróżnić tę capability od `discover-aws`, `audit`, `audit-pack` i `finops-report`.
- Czy potrzebny jest osobny operator flow.

## Poza zakresem na tym etapie

- Finalna oferta.
- Finalny branding.
- Finalna architektura UI.
- Publiczny produkt.
- Osobny silnik.
- Zmiana zasad data boundary toolkitu.
- Decyzja, czy to będzie osobna komenda, zestaw komend czy capability opisowe.

## Linki wewnętrzne

- [[../README|devops-toolkit]]
- [[../command-catalog|Katalog komend]]
- [[../finops-reporting|FinOps Reporting]]
- [[../observability-ready|Observability Readiness]]
- [[../../20-projects/internal/devops-toolkit/context|devops-toolkit — kontekst]]
- [[../../20-projects/internal/devops-toolkit/next-steps|devops-toolkit — następne kroki]]
