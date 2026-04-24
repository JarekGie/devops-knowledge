---
title: Cloud Detective → AI4DevOps — hipotezy ewolucji
tags:
  - research
  - ai4devops
  - cloud-detective
  - devops-toolkit
  - context-graph
created: 2026-04-24
status: draft-scaffold
---

# Cloud Detective → AI4DevOps — hipotezy ewolucji

> Zestaw hipotez o tym, jak Cloud Detective może ewoluować w kierunku lekkiego AIOps
> lub capability kontekstowej dla agentów operacyjnych.
> Wszystko tu jest hipotezą. Nic nie jest decyzją.

Powiązane: [[README]] | [[AI4DEVOPS_REFERENCE_MODEL]] | [[../../60-toolkit/cloud-detective/README|Cloud Detective]] | [[../../60-toolkit/cloud-detective/boundaries|Cloud Detective — granice]]

---

## Stan obecny Cloud Detective (2026-04-24)

Z istniejących notatek w [[../../60-toolkit/cloud-detective/README|Cloud Detective]]:

- Jest capability / warstwą rozpoznania środowiska wewnątrz `devops-toolkit`
- Read-only discovery, FinOps, observability readiness, governance
- Zasada: raw data nie do AI; tylko `sanitized/` i `findings/`
- Brak decyzji: osobna komenda vs. capability vs. alias
- Brak finalnego modelu raportu

**Aktualny output:** raport bazowy po onboardingu klienta lub projektu.

---

## Luka między Cloud Detective a AIOps

```
Cloud Detective dziś:              Pełny AIOps:
  Discovery (read-only)    ←→      Signal ingestion (continuous)
  Raport bazowy            ←→      Context graph (live)
  Jednorazowy snapshot     ←→      Ciągła korelacja
  Brak reasoning           ←→      Reasoning layer (ML/LLM)
  Brak akcji               ←→      Automation layer
  Brak governance layer    ←→      Human-in-loop framework
```

Luka jest duża — ale nie znaczy to, że Cloud Detective musi ją całą wypełnić.

---

## Hipotezy ewolucji

> [!note] Status wszystkich hipotez: *nieweryfikowane*

### H-CD1 — Tags-as-CMDB

**Hipoteza:** Dobrze utrzymane tagi AWS (Tagging Contract v1 z [[../../30-standards/aws-tagging-standard|AWS Tagging Standard]]) mogą zastąpić dedykowany CMDB jako podstawę kontekstu dla reasoning layer.

**Dlaczego:** Tagi to już dostępne metadane zasobu: Owner, CostCenter, Environment, Project, ManagedBy. To wystarczy do budowania mini-grafu zależności bez osobnej bazy danych.

**Warunek:** Tagi muszą być kompletne i świeże. To jest bloker — nie technologia.

**Pytania:**
- Czy brakuje czegoś w Tagging Contract v1 co byłoby potrzebne dla context graph?
- Jak modelować zależności runtime (service-to-service) których nie ma w tagach?

---

### H-CD2 — Discovery jako snapshot CMDB

**Hipoteza:** `toolkit discover-aws` może generować jednorazowy snapshot w formacie graph-compatible (JSON-LD lub prosta mapa relacji), który służy jako wejście dla LLM reasoning.

```
toolkit discover-aws --output context-graph.json
      │
      ▼
[context-graph.json] → LLM prompt z kontekstem → [analiza / rekomendacje]
```

**Dlaczego:** Nie potrzebujemy live graph dla jednorazowych zadań: "co jest zepsute", "skąd ten cost spike", "jaka jest zależność między serwisem A i B".

**Ryzyko:** Snapshot starzeje się. Godzinny snapshot może być nieaktualny dla dynamicznych środowisk ECS Fargate.

**Pytania:**
- Jaki format jest minimalnie użyteczny dla LLM (nie nadmiarowy, nie za ubogi)?
- Jak często snapshot jest wystarczająco świeży dla typowego use case?

---

### H-CD3 — Findings jako signal feed

**Hipoteza:** Istniejące `findings/` z audit packów Cloud Detective mogą być traktowane jako quasi-sygnały dla mini reasoning layer.

```
audit-pack → findings.yaml
                  │
                  ▼
           [pattern matching]
                  │
                  ├── Known problem? → match runbook
                  ├── Regression?    → diff z poprzednim run
                  └── Anomaly?       → flag do manualnej analizy
```

**Dlaczego:** Findings są już produkowane. Brakuje warstwy która je *interpretuje* i *koreluje w czasie*.

**Pytania:**
- Czy format `findings.yaml` jest wystarczająco strukturyzowany do diff-owania?
- Jak przechowywać historię findings bez nadmiernego rozrostu repo klienta?

---

### H-CD4 — LLM jako warstwa interpretacji findings

**Hipoteza:** Cloud Detective może dodać opcjonalny krok: przekazanie `sanitized/findings/` do LLM z pytaniem "co z tego jest najważniejsze i co zrobić jako pierwsze".

**To by wyglądało tak:**
```
toolkit cloud-detective run --with-llm-summary
      │
      ├── discover → sanitize → findings.yaml
      └── llm summarize findings.yaml → executive_summary.md
```

**Granica danych:** Zgodna z istniejącym kontraktem — tylko `sanitized/`, nie raw.

**Pytania:**
- Jaki model LLM jest tu odpowiedni (lokalny vs. Anthropic API)?
- Jak obsłużyć sytuację gdy model nie ma kontekstu o konwencjach projektu?
- Koszt API dla regularnych runów (np. tygodniowy audit)?

---

### H-CD5 — Context graph jako wejście dla agentów

**Hipoteza:** W dalszej perspektywie, context graph generowany przez Cloud Detective może być wejściem dla autonomicznych agentów operacyjnych — nie tylko dla człowieka.

```
Cloud Detective (context) → Agent operacyjny → Akcja z guardrails
```

**Dlaczego:** Agent bez kontekstu środowiska jest generyczny i podatny na błędy.
Agent z kontekstem (kto jest ownerem, jakie są tagi, co zależy od czego) jest precyzyjniejszy.

**Ryzyko:** To jest najdalej idąca hipoteza. Wymaga całej warstwy governance i agent security.

**Pytania:**
- Czy Cloud Detective powinien w ogóle wiedzieć o agentach, czy to osobna warstwa?
- Jak trzymać granicę danych gdy agent używa kontekstu z Cloud Detective?

---

## Mapa drogowa hipotez (nie roadmapa produktu)

```
Poziom 1 (najniższy wysiłek):
  H-CD1 — Tags-as-CMDB ← już prawie gotowe, potrzeba weryfikacji Tagging Contract
  H-CD3 — Findings jako signal ← potrzeba diff-owania findings w czasie

Poziom 2 (umiarkowany wysiłek):
  H-CD2 — Discovery snapshot ← nowy format outputu z discover-aws
  H-CD4 — LLM findings summary ← nowy krok w pipeline, opcjonalny

Poziom 3 (duży wysiłek, odległy):
  H-CD5 — Context dla agentów ← wymaga całej warstwy governance
```

---

## Co NIE należy do Cloud Detective

Na podstawie [[../../60-toolkit/cloud-detective/boundaries|granic Cloud Detective]]:

- Continuous monitoring — to nie jest Cloud Detective
- Alert routing i escalation — to nie jest Cloud Detective
- Pełny CMDB — za ciężkie, poza zakresem toolkitu
- Autonomiczne akcje — poza aktualnym kontraktem bezpieczeństwa danych
- Multi-tenant platforma SaaS — poza zakresem prywatnego toolkitu

---

## Relacja do modelu referencyjnego

| Warstwa [[AI4DEVOPS_REFERENCE_MODEL]] | Cloud Detective dziś | Cloud Detective potencjalnie |
|---------------------------------------|---------------------|------------------------------|
| Signal ingestion | Audit run (jednorazowy) | Scheduled discovery z diffem |
| Context / CMDB graph | Brak | H-CD1, H-CD2 |
| Reasoning layer | Brak | H-CD4 (LLM summary) |
| Automation layer | Brak | Poza zakresem |
| Governance | Brak | Poza zakresem |

---

## Questions to revisit later

- Czy jest sens rozmawiać z użytkownikami Cloud Detective o tym, czego im brakuje (kontekst? interpretacja? historia)?
- Jak wygląda minimalny PoC dla H-CD2 (discovery snapshot jako LLM context)?
- Czy tags-as-CMDB sprawdzi się na projekcie z dużym długiem tagowania (np. legacy AWS)?
- Jakie są koszty LLM API przy tygodniowym audycie 50 zasobów vs. 500 zasobów?
- Czy [[AI_SECURITY_IN_DEVOPS|ryzyko prompt injection]] jest realne dla findings summary, czy tylko dla akcji?

#research #ai4devops #cloud-detective #devops-toolkit #context-graph
