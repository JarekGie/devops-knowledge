---
title: Model klasyfikacji — domeny i wrażliwość
domain: shared-concept
origin: own
classification: internal
llm_exposure: allowed
cross_domain_export: allowed
source_of_truth: vault
created: 2026-04-24
updated: 2026-04-24
---

# Model klasyfikacji wiedzy

> Definicje klas domen i klas wrażliwości obowiązujące w całym vault.
> Każda nowa notatka MUST mieć przypisaną domenę i klasę wrażliwości w frontmatter.

Powiązane: [[KNOWLEDGE_BOUNDARIES]] | [[ORIGIN_METADATA_CONTRACT]] | [[DOMAIN_ISOLATION_CONTRACT]]

---

## Klasy domen

### `shared-concept`

**Definicja:** Wiedza neutralna, niezwiązana z żadnym klientem, produktem ani prywatnym projektem. Wzorce, modele referencyjne, pojęcia branżowe.

**Przykłady w vault:**
- `30-research/ai4devops/` — wzorce AIOps, modele ITSM
- `30-standards/` — konwencje tagowania, IaC
- `40-runbooks/` — generyczne procedury operacyjne
- `10-areas/` — wiedza o technologiach (AWS, Terraform)
- `90-reference/` — komendy, snippety, glossary

**Reguła przepływu:** MAY być używana w każdej domenie jako źródło lub cytacja.

---

### `client-work`

**Definicja:** Wszelkie materiały pochodzące od klienta lub dotyczące pracy dla konkretnego klienta. Obejmuje: materiały dostarczone przez klienta, notatki ze spotkań, analizy wymagań, dane systemów klienta.

**Przykłady w vault:**
- `20-projects/clients/bmw/ai-taskforce/`
- `20-projects/clients/mako/maspex/`
- `20-projects/clients/mako/pbms/`
- `20-projects/clients/mako/puzzler-b2b/`

**Reguła przepływu:** MUST NOT opuścić przestrzeni klienta bez jawnej anonimizacji i oznaczenia jako `derived`. MUST NOT być łączona z `internal-product-strategy` ani `private-rnd` w jednej sesji LLM.

---

### `internal-product-strategy`

**Definicja:** Strategia produktowa, roadmapa usług, decyzje biznesowe MakoLab dotyczące własnych produktów i usług komercyjnych.

**Przykłady w vault:**
- `20-projects/internal/cloud-support-as-a-service/`
- `20-projects/internal/devops-business/`
- `20-projects/internal/devops-platform/`

**Reguła przepływu:** MAY korzystać ze `shared-concept`. MUST NOT importować `client-work`. MAY eksportować `summary-only` do `private-rnd` gdy jest jawnie oznaczone jako derived.

---

### `private-rnd`

**Definicja:** Prywatne badania i rozwój, projekty własne niezwiązane bezpośrednio z kontraktami klientowskimi ani strategią produktową pracodawcy.

**Przykłady w vault:**
- `60-toolkit/` — devops-toolkit CLI
- `60-toolkit/cloud-detective/`
- `30-research/ai4devops/` — gdy zawiera własne hipotezy
- `20-projects/internal/devops-toolkit/`

**Reguła przepływu:** MAY korzystać ze `shared-concept`. MUST NOT zawierać `client-work`. MAY linkować do `internal-product-strategy` tylko przez jawnie oznaczone derived insights.

---

### `operational-runbook`

**Definicja:** Procedury operacyjne, instrukcje krok-po-kroku, playbooki incydentowe. Mogą być przypisane do konkretnego klienta lub ogólne.

**Przykłady w vault:**
- `40-runbooks/`
- `50-patterns/`

**Reguła przepływu:** Jeśli runbook jest ogólny → traktuj jako `shared-concept`. Jeśli dotyczy konkretnego klienta → traktuj jak `client-work`.

---

### `reference-material`

**Definicja:** Materiały referencyjne: komendy, snippety, vendor docs, glossary. Nie zawierają operacyjnej wiedzy projektowej.

**Przykłady w vault:**
- `90-reference/`
- `_chatgpt/context-packs/`

**Reguła przepływu:** Zależy od zawartości. Paczki kontekstu ChatGPT dotyczące klienta → `client-work`. Ogólne snippety → `shared-concept`.

---

### `inbox-transient`

**Definicja:** Notatki tymczasowe bez przypisanej domeny. Muszą zostać przypisane do właściwej domeny w ciągu tygodnia.

**Przykłady w vault:**
- `01-inbox/`

**Reguła przepływu:** MUST NOT być używane w sesjach LLM z wrażliwym kontekstem dopóki nie mają przypisanej domeny.

---

## Klasy wrażliwości

### `public`

Wiedza możliwa do opublikowania bez konsekwencji. Brak danych klienta, brak danych biznesowych.

**Przykłady:** ogólne wzorce techniczne, tutoriale, opisy narzędzi.

---

### `internal`

Wiedza wewnętrzna MakoLab. Nie jest publiczna, ale nie zawiera danych klienta ani tajemnic handlowych.

**Przykłady:** standardy organizacyjne, konwencje, procesy wewnętrzne.

---

### `confidential`

Dane wrażliwe: dane klienta, strategie produktowe, dane finansowe, dane o infrastrukturze klienta.

**Reguła LLM:** `llm_exposure: restricted` — wymaga skurowanej paczki bez surowych danych.

---

### `restricted`

Najwyższy poziom. Materiały objęte NDA, dane osobowe, surowe logi produkcyjne klienta, credentiale, klucze.

**Reguła LLM:** `llm_exposure: prohibited` — MUST NOT być przekazywane do zewnętrznych modeli LLM w żadnej formie.

---

## Macierz: domena × wrażliwość

| Domena | Typowa wrażliwość | LLM exposure | Cross-domain export |
|--------|-----------------|--------------|---------------------|
| shared-concept | public / internal | allowed | allowed |
| client-work | confidential / restricted | restricted | prohibited |
| internal-product-strategy | internal / confidential | restricted | summary-only |
| private-rnd | internal / restricted | restricted | prohibited |
| operational-runbook | internal / confidential | restricted | summary-only |
| reference-material | public / internal | allowed | allowed |
| inbox-transient | unknown | restricted | prohibited |

---

## Dopuszczalne wartości frontmatter

```yaml
domain:
  - shared-concept
  - client-work
  - internal-product-strategy
  - private-rnd
  - operational-runbook
  - reference-material
  - inbox-transient

origin:
  - own              # własne przemyślenia, własna praca
  - client           # materiał dostarczony przez klienta
  - employer         # materiał MakoLab
  - vendor           # dokumentacja, whitepapers zewnętrznych dostawców
  - public           # wiedza publiczna (blog, RFC, standard)
  - mixed            # połączenie kilku źródeł

classification:
  - public
  - internal
  - confidential
  - restricted

llm_exposure:
  - allowed          # można wkleić do dowolnej sesji LLM
  - restricted       # tylko w skurowanej paczce, bez surowych danych
  - prohibited       # MUST NOT trafiać do zewnętrznego LLM

cross_domain_export:
  - allowed          # można cytować / linkować z innej domeny
  - summary-only     # tylko zanonimizowane podsumowanie
  - prohibited       # MUST NOT opuścić domeny

source_of_truth:
  - vault            # vault jest źródłem prawdy
  - project-local    # repo projektu jest źródłem prawdy
  - client-material  # materiał klienta jest źródłem prawdy
  - external-reference # dokument zewnętrzny
  - unknown          # nieznane
```
