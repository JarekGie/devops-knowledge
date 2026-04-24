---
title: AI4DevOps — Przestrzeń badawcza
tags:
  - research
  - ai4devops
  - aiops
  - agentic-ops
created: 2026-04-24
status: scaffolding
---

# AI4DevOps — Przestrzeń badawcza

> Nie jest to folder z notatkami o vendorach.
> To długoterminowa przestrzeń eksploracyjna łącząca DevOps, ITSM, AIOps i operacje agentyczne.
> Wszystko tu jest hipotezą dopóki nie zostanie oznaczone inaczej.

## Czym jest ta przestrzeń

Eksploracja przecięcia AI i operacji inżynierskich — z perspektywy praktykującego DevOps/SRE.

Nie akademicka. Nie marketingowa. Operacyjna.

Pytania wyjściowe:
- Jak AI zmienia pracę operacyjną (nie tylko narzędzia)?
- Czego jeszcze nie wiemy o ryzykach agentów w pipeline'ach?
- Gdzie AI tworzy realną wartość, a gdzie jest hype?
- Co z tego ma sens do zbudowania we własnym toolkicie?

## Mapa pojęć

| Termin | Robocza definicja | Status |
|--------|------------------|--------|
| **Copilot DevOps** | AI jako asystent w IDE / terminalu; człowiek decyduje i zatwierdza | ustalone |
| **AIOps** | ML na sygnałach operacyjnych (logi, metryki, alerty) do korelacji i anomaly detection | ustalone |
| **AI4DevOps** | Szersze: AI wbudowane w cały cykl życia operacji — od design do incident response | *hipoteza robocza* |
| **Agentic DevOps** | Agenty autonomiczne wykonujące zadania operacyjne z minimalnym nadzorem | *wczesna hipoteza* |
| **Agentic Ops** | Wariant Agentic DevOps — fokus na runtime operations, nie na SDLC | *wczesna hipoteza* |

> [!warning] Pułapka terminologiczna
> Vendorzy używają tych terminów wymiennie lub rozciągają je marketingowo.
> Trzymaj własne definicje i sprawdzaj, co konkretny produkt *faktycznie robi*.

## Spektrum autonomii

```
Copilot          AIOps           AI4DevOps        Agentic Ops
(sugeruje)    (koreluje/alarmuje) (działa w loop)  (autonomiczny)
    │               │                  │                │
  człowiek       człowiek           człowiek         human-in-loop
  decyduje      zatwierdza           nadzoruje          lub nie
```

## Hipotezy warte eksploracji

> [!note] Wszystkie poniższe to hipotezy — nie wnioski.

**H1 — Kontekst jest bottleneckiem**
Większość AI w ops zawodzi nie z powodu słabego modelu, ale braku kontekstu środowiskowego.
CMDB / graph środowiska to missing layer.

**H2 — Alert fatigue to problem strukturalny, nie ilościowy**
Klasyczny AIOps redukuje liczbę alertów. Nie rozwiązuje problemu, że *złe alerty* są przefiltrowane razem z prawdziwymi.

**H3 — Agentic ops wymaga nowej warstwy governance**
Autonomiczne agenty wykonujące operacje na produkcji potrzebują formalnych guardrails, nie tylko „ufamy LLM".

**H4 — Najcenniejszy przypadek użycia to onboarding kontekstu**
Nie automatyzacja akcji — ale szybkie zbudowanie modelu mentalnego nowego środowiska (nowy projekt, incident na nieznanym stacku).

**H5 — Bezpieczeństwo agentów to nowa klasa problemów**
Prompt injection w pipeline CI/CD, agent manipulowany przez dane w logu — to nie jest edge case.

## Relacje z istniejącymi projektami

| Projekt | Relacja |
|---------|---------|
| [[../../60-toolkit/cloud-detective/README\|Cloud Detective]] | Prototyp warstwy kontekstowej — potencjalny punkt wejścia do lekkiego AIOps |
| [[../../60-toolkit/README\|devops-toolkit]] | Platforma egzekucji — docelowy host dla capability AI4DevOps |
| [[../../20-projects/internal/llz/README\|LLZ]] | Laboratorium pattern'ów governance — test bed dla zasad human-in-loop |

## Ścieżki eksploracji

1. **Referencyjna architektura** — [[AI4DEVOPS_REFERENCE_MODEL]] — warstwy systemu AIOps od sygnału do akcji
2. **ITSM + AI** — [[ITSM_AI_OPPORTUNITIES]] — gdzie AI realnie dodaje wartość w procesach ITIL
3. **Vendorzy i wzorce** — [[VENDORS_AND_PATTERNS]] — co architektonicznie reprezentują istniejące produkty
4. **Bezpieczeństwo** — [[AI_SECURITY_IN_DEVOPS]] — ryzyka i guardrails
5. **Cloud Detective → AIOps** — [[CLOUD_DETECTIVE_CONNECTIONS]] — jak to, co już mamy, może ewoluować

## Questions to revisit later

- Czy AI4DevOps ma sens jako osobna dyscyplina, czy to tylko AIOps + Copilot?
- Co jest minimalnym viable context graph dla małego klienta cloud?
- Kiedy agentic ops staje się ryzykiem compliance / audytu?
- Czy LLM nadaje się do root cause analysis, czy tylko do korelacji sygnałów?
- Jak oceniać jakość AI w ops bez złożonych benchmarków?

#research #ai4devops #aiops #agentic-ops
