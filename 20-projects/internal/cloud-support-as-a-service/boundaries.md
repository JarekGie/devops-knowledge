---
title: Cloud Support as a Service — kontrakt granic domeny
domain: internal-product-strategy
origin: own
classification: internal
llm_exposure: allowed
cross_domain_export: summary-only
source_of_truth: vault
created: 2026-04-24
updated: 2026-04-24
---

# Kontrakt granic domeny — Cloud Support as a Service

---

## Co MUST NOT wchodzić do tej domeny

- Surowe materiały klientowskie (dokumenty, transkrypty, dane systemów klientów)
- Wnioski z projektów klientów bez przejścia przez [[../../../_system/DERIVATIVE_INSIGHT_RULES|Derived Insight Rules]]
- Kod ani architektura z `60-toolkit/` jako component tej usługi (chyba że jest publicznym produktem)

## Co MAY wchodzić do tej domeny

- Neutralne wzorce z `30-research/ai4devops/` jako inspiracja
- Ogólne runbooki z `40-runbooks/` jako referencja operacyjna
- Standardy MakoLab z `30-standards/`
- Derived insights z projektów klientów (po anonimizacji)

## Co MAY opuścić tę domenę

- `summary-only` — zanonimizowane podsumowania strategiczne mogą trafić do `private-rnd` jako inspiracja
- Dokumenty oznaczone `cross_domain_export: allowed` (jeśli nie zawierają confidential)

## Co MUST NOT opuścić tę domenę

- Szczegóły modelu biznesowego (ceny, marże, plany klientów)
- Roadmapa z konkretnymi terminami i celami
- Wewnętrzne decyzje zarządcze

## Zasada dotycząca BMW i innych klientów

> [!important]
> Wnioski z pracy z BMW (ani żadnym innym klientem) MUST NOT być importowane do tego folderu jako „własne pomysły MakoLab" bez jawnego derived insight z datą i oznaczeniem źródła.
>
> Zasada: jeśli pomysł na element usługi pochodzi z obserwacji przy kliencie — musi być jawnie oznaczony jako `derived insight` i zanonimizowany zgodnie z [[../../../_system/DERIVATIVE_INSIGHT_RULES|Derived Insight Rules]].
