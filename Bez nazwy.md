Pracujesz w repo Obsidian vault.

Wykonaj implementację zgodnie z poniższą specyfikacją:

1. Utwórz strukturę katalogów dla NotebookLM pod 90-reference/notebooklm/
2. Dodaj wszystkie pliki MOC, templates i kontrakt.
3. Wygeneruj NOTEBOOKLM_KONTRAKT.md z zasadą:
   - wszystkie artefakty NotebookLM domyślnie po polsku,
   - inny język tylko gdy jawnie podam override.
4. Dodaj notebooks-index.md oraz recovery-controls-catalog.md.
5. Nie nadpisuj istniejących notatek domenowych.
6. Jeśli widzisz istniejące katalogi dla incidents / llz / finops — zintegruj je zamiast dublować.
7. Zrób commit w stylu:
   feat(obsidian): add NotebookLM vault structure and operational contract

Specyfikacja:
# NotebookLM w Vault — struktura, MOC i kontrakt operacyjny

## Cel

NotebookLM nie jest traktowany jako „kolejne notatki”, tylko jako:

- silnik syntezy (synthesis engine)
    
- generator artefaktów (artifact generator)
    
- warstwa pomocnicza do contradiction checks / gap analysis
    
- pomocniczy system evidence-backed reasoning
    

**Source of truth pozostaje w vault oraz IaC/runtime.**

---

# Proponowana struktura vault

```text
90-reference/
└── notebooklm/
    ├── README.md
    ├── NOTEBOOKLM_KONTRAKT.md
    ├── notebooks-index.md
    ├── _templates/
    │   ├── notebook-contract-template.md
    │   ├── artifact-review-template.md
    │   └── conversation-template.md
    │
    ├── _moc/
    │   ├── MOC-Incidents.md
    │   ├── MOC-LLZ.md
    │   ├── MOC-FinOps.md
    │   └── MOC-Recovery-Patterns.md
    │
    ├── runtime-incidents/
    │   ├── notebook-contract.md
    │   ├── sources.md
    │   ├── conversations/
    │   ├── artifacts/
    │   ├── findings/
    │   └── prompts/
    │
    ├── llz-controls/
    ├── finops-reference/
    └── cloudformation-recovery/
```

---

# Map of Content (MOC)

## MOC-Incidents.md

Łączy:

- recurring failure patterns
    
- recovery anti-patterns
    
- reusable runbook primitives
    
- cross-project contradictions
    

Przykładowe linki:

```md
# MOC — Incident Patterns

## Anti-patterns
- [[ContinueUpdateRollback Trap]]
- [[Manual Resource Visibility Gap]]
- [[Retain Policy Contradiction]]

## Recovery Controls
- [[ENI Pre-Delete Audit Control]]
- [[No-Go Gates For Stack Recovery]]

## Incident Notebooks
- [[Runtime-Incidents]]
```

---

## MOC-Recovery-Patterns.md

To może być potem zalążek katalogu kontroli LLZ.

Np:

```md
- Recovery Control RC-001 — Pre-delete ENI audit
- Recovery Control RC-002 — Retain on stateful resources
- Recovery Control RC-003 — External DNS dependency check
```

---

# Struktura pojedynczego notebooka

## runtime-incidents/

```text
runtime-incidents/
├── notebook-contract.md
├── sources.md
├── prompts/
│   ├── contradiction-check.md
│   ├── gap-analysis.md
│   └── recovery-control-contract.md
│
├── conversations/
│   └── 2026-04-22-contradiction-check.md
│
├── artifacts/
│   ├── 2026-04-22-briefing-v1.md
│   ├── mind-map.json
│   └── flashcards.json
│
└── findings/
    ├── anti-patterns.md
    └── recovery-controls.md
```

---

# Tagowanie Obsidian

Proponuję lekkie tagi:

```text
#notebooklm
#notebooklm/artifact
#notebooklm/finding
#notebooklm/contradiction
#recovery-pattern
#llz-control
```

Do wyszukiwań bardzo dobre.

---

# NOTEBOOKLM_KONTRAKT.md

## Kontrakt operacyjny NotebookLM

## Rola

NotebookLM służy do:

DOPUSZCZALNE:

- synteza źródeł
    
- contradiction check
    
- gap analysis
    
- pattern extraction
    
- artifact generation
    
- przygotowanie briefingów i map zależności
    

NIEDOPUSZCZALNE:

- source of truth dla live state
    
- zatwierdzanie zmian produkcyjnych
    
- destructive runbooks bez walidacji człowieka
    
- decyzje apply/rollback bez weryfikacji w IaC i runtime
    

---

## Zasada języka (domyślnie polski)

To ważne — zgodnie z Twoim życzeniem:

```text
DOMYŚLNY JĘZYK WSZYSTKICH TWORZONYCH ARTEFAKTÓW:
POLSKI
```

Dotyczy:

- odpowiedzi na ask
    
- raportów
    
- flashcards
    
- quizów
    
- mind maps (etykiety)
    
- slide decks
    
- data tables (nagłówki)
    
- notatek zapisywanych do vault
    

### Reguła

Jeśli użytkownik nie wskaże wyraźnie innego języka:

- twórz wszystko po polsku
    
- zachowuj polską terminologię techniczną, gdy naturalna
    
- nazwy AWS/CLI pozostawiaj oryginalne
    

### Override

Wyjątek tylko gdy prompt jawnie mówi np:

- respond in English
    
- generate report in English
    
- output for customer in English
    

Wtedy tylko dany artefakt może być po angielsku.

---

## Prompt safety contract

Dla promptów analitycznych preferowany wzorzec:

```text
Oddziel:
- fakty potwierdzone
- hipotezy
- sprzeczności
- luki

Nie zgaduj.
Opieraj się wyłącznie na źródłach.
Oznacz słabo wspierane twierdzenia.
```

To powinno być domyślne.

---

## Provenance rule

Każdy artefakt z NotebookLM powinien mieć metadane:

```yaml
notebook:
created_from: Runtime-Incidents
generated: 2026-04-22
sources:
  - pbms/context.md
  - qa-postmortem.md
reviewed_by_human: true
status: draft
```

Bez provenance artefakt nie trafia do findings.

---

## Artifact review gate

Przed przeniesieniem do findings:

sprawdzić:

- czy model nie przesadził z uogólnieniem („always”, „never”)
    
- czy cytowane fakty naprawdę są w źródłach
    
- czy recommendations nie są halucynowane
    

Dopiero potem finding.

---

## Notebook typy (docelowo)

### Runtime-Incidents

cross-project incident synthesis

### LLZ-Controls

kontrolki, guardrails, governance patterns

### FinOps-Reference

referencyjne analizy kosztowe

### CloudFormation-Recovery

RCA + recovery primitives

---

## Naming convention

Artefakty:

```text
YYYY-MM-DD-briefing-v1.md
YYYY-MM-DD-mind-map.json
YYYY-MM-DD-gap-analysis.md
```

Deterministycznie.

---

## Minimalny workflow

```text
1. Curated sources -> NotebookLM
2. Ask / contradiction / gap analysis
3. Generate artifact
4. Download to artifacts/
5. Human review
6. Promote distilled insights into findings/
```

Dopiero findings mogą wpływać na runbooki.

---

## Bardzo ważna zasada

NotebookLM:

```text
assist reasoning
never replace verification
```

To powinno zostać.

---

# README dla notebooklm/

Krótka nota startowa:

```md
NotebookLM w tym vault służy jako pomocnicza warstwa syntezy.

Domyślny język artefaktów: polski.

Zobacz:
- [[NOTEBOOKLM_KONTRAKT]]
- [[notebooks-index]]
- [[MOC-Incidents]]
```

---

## Mój bonus (bardzo Twoje)

Dodałbym osobny plik:

```text
recovery-controls-catalog.md
```

I odkładał tam wszystko co model odkrywa jako reusable control.

To może naturalnie zasilić LLZ.