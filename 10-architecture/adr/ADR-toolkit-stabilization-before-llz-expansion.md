# ADR — Stabilization Before Capability Expansion

Status: Accepted
Date: 2026-04-24

## Context

`devops-toolkit` osiągnął już istotną szerokość capability i nie jest wyłącznie małym CLI do pojedynczego typu audytu.

Obecny zakres obejmuje między innymi:
- AWS audit packs
- LLZ controls
- FinOps reporting
- tagging audits
- operator console
- emerging LLZ provisioning ambitions

Wraz ze wzrostem zakresu pojawiła się obserwacja, że część capability częściowo nakłada się funkcjonalnie, szczególnie w obszarach:
- tagging
- governance
- attribution

To zwiększa ryzyko:
- duplikacji logiki,
- niespójnych punktów wejścia CLI,
- command sprawl,
- rozchodzenia się podobnych reguł między audit packami i raportami.

Ostatnia kampania remediacji tagowania obejmująca wiele projektów:
- `rshop`
- `akcesoria2`
- `planodkupow` (w toku)

ujawniła jednocześnie:
- powtarzalne, nadające się do uogólnienia wzorce,
- miejsca, w których capability powinny zostać skonsolidowane,
- obszary, gdzie dalsza ekspansja funkcjonalna przed refaktorem zwiększałaby dług techniczny zamiast wartości architektonicznej.

## Decision

Po zakończeniu remediacji tagowania we wszystkich docelowych projektach:

ekspansja funkcjonalna zostaje tymczasowo wstrzymana.

Priorytet przesuwa się kolejno na:

1. Capability consolidation
2. Duplicate logic removal
3. Public API stabilization
4. Dopiero potem wznowienie LLZ provisioning through toolkit

Nie należy wprowadzać nowych major audit packs, chyba że reprezentują rzeczywiście nowe domeny problemowe, a nie nakładają się z już istniejącymi checkami.

Ta decyzja dotyczy w szczególności dalszego rozszerzania provisioning ambitions wokół LLZ.

## Consolidation Goals

### A. Tagging capability consolidation

Kierunek docelowy:
jeden spójny capability obszaru tagowania, z wieloma rodzinami checków:
- static compliance
- runtime-generated resources
- policy readiness
- FinOps attribution

Zamiast osobnych, częściowo nakładających się komend i auditów.

### B. Public API cleanup

Model komend powinien zostać ponownie uporządkowany wokół klas:
- core
- advanced
- experimental

Celem jest redukcja command sprawl i czytelniejsze granice public API.

### C. Duplicate reduction targets

Przeglądowi i redukcji powinny podlegać:
- overlapping audits
- duplicated discovery logic
- duplicated report rendering logic
- repeated policy/tag evaluation logic

### D. LLZ only after stabilization

Prace nad LLZ provisioning przez toolkit wracają dopiero po ustabilizowaniu baseline refaktoru.

Najpierw stabilizacja architektury capability, potem dalsza ekspansja provisioning.

## Rationale

Decyzja wynika z następujących przesłanek:
- stability before growth,
- redukcja długu technicznego zanim zostanie przykryty nowymi capability,
- ograniczenie capability inflation,
- ochrona maintainability,
- budowa mocniejszej podstawy pod dalszy rozwój LLZ.

Innymi słowy: obecnie ważniejsze jest uproszczenie i konsolidacja już zbudowanej powierzchni systemu niż dokładanie kolejnych dużych funkcji.

## Consequences

Pozytywne:
- cleaner architecture
- easier long-term evolution
- stronger base for LLZ

Tradeoff:
- wolniejszy short-term feature growth jest akceptowany świadomie i celowo
