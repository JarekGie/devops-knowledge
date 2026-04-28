---
title: Cost-Aware Agent Execution Policy
domain: shared-concept
origin: own
classification: internal
llm_exposure: allowed
cross_domain_export: allowed
source_of_truth: vault
created: 2026-04-28
updated: 2026-04-28
tags: [ai-finops, llmops, governance, agent-contract, token-cost]
---

# Cost-Aware Agent Execution Policy

> AI FinOps lite dla agentów pracujących z vaultem.
> Ten kontrakt jest warstwą addytywną: nie zastępuje zasad bezpieczeństwa, granic domenowych ani workflow zapisu do vault.

Powiązane: [[AGENTS]] | [[LLM_CONTEXT_GLOBAL]] | [[LLM_CONTEXT_BOUNDARY_CONTRACT]] | [[CHATGPT_WORKFLOW]]

---

## 1. Purpose

Celem kontraktu jest ograniczenie kosztu pracy agentów LLM bez pogorszenia jakości decyzji technicznych.

Agent powinien:
- optimize token usage
- preserve output quality
- use premium reasoning only when justified
- treat context window as scarce resource

Zasada nadrzędna:

> Użyj najtańszego modelu i najmniejszego kontekstu, które są wystarczające do poprawnego wykonania zadania.

Ten kontrakt dotyczy:
- doboru model tier
- rozmiaru kontekstu wejściowego
- długości odpowiedzi
- eskalacji reasoning dopiero po sygnale potrzeby
- minimalizacji przepalania tokenów w workflow vault

Nie dotyczy:
- obchodzenia zasad bezpieczeństwa danych
- obniżania jakości RCA, review lub decyzji architektonicznych
- zastępowania kontraktów domenowych i klasyfikacji wrażliwości

---

## 2. Model Tier Policy

### Tier S — low-cost / default

Domyślny poziom dla zadań prostych, mechanicznych i dobrze określonych.

Używaj dla:
- drafting
- markdown
- formatting
- checklist generation
- routine refactoring
- aktualizacji frontmatter
- krótkich podsumowań
- konwersji notatek do istniejącego szablonu
- prostych diffów bez ryzyka architektonicznego

Przykłady:
- dopisanie sekcji do runbooka
- uporządkowanie tabeli
- przygotowanie checklisty deploy
- drobna korekta notatki zgodnie z istniejącym stylem

### Tier M — standard reasoning

Poziom dla zadań wymagających realnego rozumowania technicznego, ale bez wysokiej niepewności lub bardzo długiego kontekstu.

Używaj dla:
- IaC review
- RCA synthesis
- medium-complexity architecture
- review change setów i planów Terraform
- analiza incydentu z jasnym zakresem
- projektowanie runbooka operacyjnego
- porównanie 2-3 wariantów rozwiązania

Przykłady:
- analiza CloudFormation failure chain
- synteza findings z AWS CLI
- ocena ryzyka tag policy re-enable
- review zmian w module Terraform

### Tier P — premium reasoning

Poziom kosztowny. Używaj tylko gdy zadanie ma wysoką złożoność, duży blast radius albo wymaga długiego kontekstu.

Używaj dla:
- deep architecture
- threat modeling
- difficult debugging
- long-context analysis
- projektowanie agent workflows z wieloma constraints
- rozwiązywanie sprzeczności między źródłami
- analiza dużego refaktoru lub migracji
- decyzje z wysokim ryzykiem produkcyjnym

Przykłady:
- architektura wielokontowej platformy AWS
- threat model dla przepływu danych do LLM
- debugging awarii z kilkoma niezależnymi hipotezami
- synteza wielu dużych context packów

### Escalation rule

Routing powinien iść w górę stopniowo:

```text
Tier S -> Tier M -> Tier P
```

Premium reasoning jest uzasadnione dopiero wtedy, gdy:
- niższy tier nie rozwiązał zadania
- walidacja wykazała błąd lub sprzeczność
- kontekst jest zbyt złożony dla niższego tieru
- decyzja ma wysoki koszt błędu
- użytkownik jawnie poprosił o głęboką analizę

Zakazane jest `premium-by-default` dla rutynowych aktualizacji vault, formatowania, prostych notatek i mechanicznego refaktoru.

---

## 3. Cost-Aware Execution Rules

Agent MUST:
- prefer lowest capable model
- avoid premium-by-default
- use diffs over full rewrites
- use concise-by-default responses unless expanded output requested
- reuse prior context, avoid re-summarizing stable context
- use minimal sufficient context

Agent SHOULD:
- czytać tylko pliki potrzebne do zadania
- linkować do istniejących notatek zamiast kopiować duże fragmenty
- streszczać stabilny kontekst raz, a potem odwoływać się do niego
- separować discovery od execution, jeśli pełny kontekst nie jest potrzebny od razu
- wykorzystywać `rg` i selektywne odczyty zamiast pełnych dumpów katalogów
- kończyć odpowiedź wynikiem i evidence, nie pełnym transcript tooli

Agent MUST NOT:
- przepisywać całych kontraktów, gdy wystarczy dopisać sekcję
- wklejać dużych bloków kontekstu, jeśli wystarczy link lub ścieżka
- re-summarize całego vaulta przy każdej zmianie aktywnego zadania
- eskalować modelu tylko dlatego, że zadanie dotyczy AWS, Terraform albo ECS
- generować długiej odpowiedzi, gdy użytkownik prosi o konkretny wynik

---

## 4. Confidence / Escalation Policy

Model escalation jest decyzją operacyjną, nie odruchem.

Escalate only when:
- ambiguity remains unresolved after reading available context
- validation failed or produced contradictory evidence
- sources disagree and the conflict changes the recommendation
- task complexity exceeds current tier capability
- blast radius is high and confidence is not high

Do not escalate when:
- confidence is high
- task is mechanical
- output is formatting, checklist, or short markdown
- evidence is direct and sufficient
- user explicitly asked for concise execution

Confidence levels:

| Confidence | Action |
|------------|--------|
| HIGH | proceed in current tier; no model escalation |
| MEDIUM | narrow context, validate key assumption, then proceed or escalate to Tier M |
| LOW | ask for missing input or escalate only if additional reasoning can reduce uncertainty |

Failed validation rule:
- jeśli test, plan, AWS CLI read-only check albo review wykazuje sprzeczność z założeniem, agent powinien najpierw zawęzić hipotezę i zebrać brakujące evidence
- eskalacja do Tier P jest uzasadniona dopiero gdy błąd nie jest lokalny lub wymaga szerokiej syntezy

---

## 5. Token Frugality Guidelines

Tokeny są kosztem operacyjnym i ograniczeniem jakościowym. Długi kontekst zwiększa koszt, latency i ryzyko zgubienia ważnych szczegółów.

Guidelines:
- reduce redundant output
- prefer references over reinlining large context
- minimize context burn in vault workflows
- treat long context as expensive resource
- keep context packs scoped to one problem and one domain
- prefer `current state + delta + evidence` over full history
- copy exact evidence only when it matters for auditability
- avoid repeating unchanged architecture descriptions

Vault workflows:
- przy aktualizacji `02-active-context/now.md` dopisuj delta, nie pełny rewrite
- przy context packach utrzymuj kompaktowy zakres i linki do źródeł prawdy
- przy runbookach zachowuj sekcje operacyjne, ale nie doklejaj pełnych logów
- przy agent handoff używaj: cel, stan, blokery, next step, evidence

Context pack target:
- mała paczka: do ~1500 tokenów
- standardowa paczka: do ~3000 tokenów
- długa paczka: tylko gdy uzasadniona przez Tier M/P i zakres problemu

---

## 6. Integration

Ten kontrakt powinien być integrowany przez krótkie odwołania, nie przez kopiowanie pełnej treści.

Minimalne punkty integracji:

| Plik | Integracja |
|------|------------|
| `_system/AGENTS.md` | dodać zasadę cost-aware execution i link do tego kontraktu |
| `CLAUDE.md` | dodać krótką zasadę: minimalny wystarczający kontekst, bez premium-by-default |
| `CODEX.md` | dodać krótką zasadę: małe diffy, selektywny odczyt, model escalation tylko przy potrzebie |
| `_system/LLM_CONTEXT_GLOBAL.md` | dodać link w sekcji zasad sesji LLM |
| `_chatgpt/README.md` | dodać zasadę kompaktowych paczek i cost-aware promptingu |
| `_chatgpt/templates/context-pack-template.md` | utrzymać target tokenów i przypomnieć o minimalnym kontekście |

Zasada integracji:

> Dokumenty nadrzędne linkują do tego kontraktu. Nie kopiują jego treści, żeby uniknąć driftu.

---

## 7. Deliverables

### Gotowy plik markdown

Ten dokument jest źródłem prawdy dla cost-aware execution:

```text
_system/AI_COST_AWARE_AGENT_CONTRACT.md
```

### Propozycja frontmatter

```yaml
title: Cost-Aware Agent Execution Policy
domain: shared-concept
origin: own
classification: internal
llm_exposure: allowed
cross_domain_export: allowed
source_of_truth: vault
created: 2026-04-28
updated: 2026-04-28
tags: [ai-finops, llmops, governance, agent-contract, token-cost]
```

### Changelog zmian

2026-04-28:
- utworzono kontrakt `AI_COST_AWARE_AGENT_CONTRACT.md`
- zdefiniowano tiering modeli `S/M/P`
- dodano regułę eskalacji `small -> medium -> premium`
- dodano zasady token frugality dla vault workflows i context packów
- wskazano minimalne punkty integracji z kontraktami agentów

### Przyszły model router

Ten kontrakt może później sterować prawdziwym routerem modeli w API.

Minimalny router mógłby przyjmować:

```json
{
  "task_type": "iac_review",
  "risk": "medium",
  "context_size": "standard",
  "confidence": "medium",
  "requires_tools": true,
  "domain": "client-work",
  "classification": "confidential"
}
```

I zwracać:

```json
{
  "tier": "M",
  "reason": "IaC review with medium risk; no unresolved contradiction",
  "max_context_tokens": 3000,
  "response_style": "concise_with_evidence",
  "escalation_allowed": true
}
```

Routing API powinien respektować najpierw bezpieczeństwo danych:
1. `DOMAIN_ISOLATION_CONTRACT`
2. `LLM_CONTEXT_BOUNDARY_CONTRACT`
3. `AI_COST_AWARE_AGENT_CONTRACT`

Koszt nigdy nie może uzasadniać użycia modelu lub kanału niezgodnego z klasyfikacją danych.

---

## Klasyfikacja

Najlepsza klasyfikacja: **hybryda Governance + LLMOps + FinOps**.

Uzasadnienie:
- Governance: definiuje obowiązujące zachowanie agentów i zasady eskalacji.
- LLMOps: dotyczy routingu modeli, context window, prompt/context management i jakości odpowiedzi.
- FinOps: optymalizuje koszt tokenów i traktuje użycie modeli jako mierzalny koszt operacyjny.

Praktycznie ten kontrakt powinien mieszkać w `_system/`, bo jest zasadą wykonawczą dla agentów, ale tag `ai-finops` jest właściwy dla późniejszego raportowania i routera kosztowego.
