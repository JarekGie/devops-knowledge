---
title: Kontrakt izolacji domen
domain: shared-concept
origin: own
classification: internal
llm_exposure: allowed
cross_domain_export: allowed
source_of_truth: vault
created: 2026-04-24
updated: 2026-04-24
---

# Kontrakt izolacji domen

> Kontrakt nadrzędny wobec wszystkich notatek i sesji LLM w tym vault.
> Język: MUST = obowiązkowe, MUST NOT = bezwzględnie zabronione, SHOULD = zalecane, MAY = dozwolone.

Powiązane: [[KNOWLEDGE_BOUNDARIES]] | [[CLASSIFICATION_MODEL]] | [[DERIVATIVE_INSIGHT_RULES]]

---

## Zasady izolacji — reguły bezwzględne

### R1 — Separacja domen w notatce

**MUST NOT** umieszczać w jednej notatce treści z więcej niż jednej domeny wrażliwości, chyba że notatka sama jest klasyfikowana jako `mixed` z jawną dokumentacją źródeł.

**MUST** każda notatka zawierać frontmatter z polem `domain` przed jakimkolwiek użyciem LLM.

**SHOULD** notatki domeny `client-work` nie zawierać wikilinków do notatek `internal-product-strategy` ani `private-rnd`.

---

### R2 — Separacja domen w sesji LLM

**MUST NOT** łączyć materiałów `client-work` z `internal-product-strategy` ani `private-rnd` w jednej sesji LLM.

**MUST NOT** przekazywać materiałów `restricted` do zewnętrznych modeli LLM (ChatGPT, Claude API, Codex, NotebookLM) w żadnej formie — ani bezpośrednio, ani po przetworzeniu.

**MUST** sesja LLM dotycząca `client-work` zawierać tylko materiały tego samego klienta lub `shared-concept`.

**SHOULD** przed każdą sesją LLM wypełnić [[PROMPT_BOUNDARY_CHECKLIST]].

---

### R3 — Przepływ pochodnych wniosków

**MUST NOT** kopiować wniosków z `client-work` do `internal-product-strategy` ani `private-rnd` bez:
1. jawnej anonimizacji (usunięcia nazwy klienta, nazw systemów, konkretnych danych),
2. uogólnienia do wzorca (nie konkretnego przypadku),
3. oznaczenia w notatce docelowej jako `derived insight` z datą generalizacji.

**Szczegółowe zasady:** [[DERIVATIVE_INSIGHT_RULES]]

---

### R4 — Przechowywanie i organizacja

**MUST** materiały klientowskie znajdować się wyłącznie w `20-projects/clients/<klient>/`.

**MUST NOT** materiały `client-work` być przechowywane w folderach `shared-concept` (`30-standards/`, `10-areas/`, `40-runbooks/`, `90-reference/`), `private-rnd` (`60-toolkit/`) ani `internal-product-strategy` (`20-projects/internal/`).

**SHOULD** każdy folder `20-projects/clients/<klient>/` zawierać plik `client-boundaries.md` z jawnym opisem granic danych dla tego klienta.

---

### R5 — Linki i cytacje

**MUST NOT** notatka `client-work` być wikilinkiem w notatce `shared-concept` ani `private-rnd`.

**MAY** notatka `shared-concept` być linkowana ze wszystkich domen.

**SHOULD** notatki `internal-product-strategy` linkować do `shared-concept` jako źródeł, nie do `private-rnd` jako implementacji.

---

### R6 — Context packi i eksporty

**MUST NOT** `_chatgpt/context-packs/` zawierać materiałów `client-work` zmieszanych z `internal-product-strategy` lub `private-rnd` w jednym pliku.

**MUST** każdy context pack mieszający domeny mieć jawne oznaczenie `domain: mixed` i listę źródeł.

**SHOULD** context packi klientowskie mieć `classification: confidential` minimum.

---

### R7 — NotebookLM

**MUST NOT** notebook NotebookLM zawierać równocześnie źródeł z `client-work` i `internal-product-strategy`.

**MUST** każdy notebook NotebookLM być dedykowany jednej domenie (patrz [[../NOTEBOOKLM_CONTRACT]]).

**SHOULD** przed stworzeniem nowego notebooka sprawdzić, czy zawartość należy do jednej domeny.

---

## Wyjątki i procedura eskalacji

### Kiedy mieszanie jest uzasadnione

Mieszanie domen MAY być dozwolone wyłącznie gdy:
1. Notatka jest jawnie sklasyfikowana jako `domain: mixed`,
2. Zawiera sekcję `## Źródła domen` z listą skąd pochodzi każdy fragment,
3. Właściciel vault świadomie podjął tę decyzję,
4. `cross_domain_export: prohibited` jest ustawione na notatce mieszanej.

### Procedura gdy nie wiadomo do jakiej domeny należy notatka

1. Umieść w `01-inbox/` z `domain: inbox-transient`.
2. W ciągu tygodnia przypisz właściwą domenę lub usuń.
3. Nie używaj w sesjach LLM dopóki domena nie jest przypisana.

---

## Tabela zabronionych kombinacji

| Domena A | Domena B | Status | Warunek wyjątku |
|----------|----------|--------|-----------------|
| client-work | internal-product-strategy | PROHIBITED | brak |
| client-work | private-rnd | PROHIBITED | brak |
| client-work | client-work (inny klient) | PROHIBITED | brak |
| internal-product-strategy | private-rnd | RESTRICTED | tylko summary-only, jawne derived |
| client-work | shared-concept | ALLOWED | shared-concept w roli źródła |
| internal-product-strategy | shared-concept | ALLOWED | shared-concept w roli źródła |
| private-rnd | shared-concept | ALLOWED | shared-concept w roli źródła |
