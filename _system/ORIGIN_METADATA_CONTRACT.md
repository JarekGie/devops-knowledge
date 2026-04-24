---
title: Kontrakt metadanych origin — frontmatter
domain: shared-concept
origin: own
classification: internal
llm_exposure: allowed
cross_domain_export: allowed
source_of_truth: vault
created: 2026-04-24
updated: 2026-04-24
---

# Kontrakt metadanych origin — frontmatter

> Wszystkie nowe notatki MUST zawierać poniższy frontmatter.
> Istniejące notatki SHOULD być stopniowo aktualizowane, zaczynając od domen `client-work` i `internal-product-strategy`.

Powiązane: [[CLASSIFICATION_MODEL]] | [[DOMAIN_ISOLATION_CONTRACT]]

---

## Obowiązkowy schemat frontmatter

```yaml
---
title: <tytuł notatki>
domain: <klasa domeny>
origin: <źródło wiedzy>
classification: <klasa wrażliwości>
llm_exposure: <dozwolona ekspozycja LLM>
cross_domain_export: <zasada eksportu>
source_of_truth: <gdzie jest stan prawdziwy>
related_domains: []           # opcjonalne — lista powiązanych domen
created: YYYY-MM-DD
updated: YYYY-MM-DD
---
```

---

## Dopuszczalne wartości

### `domain`

| Wartość | Kiedy używać |
|---------|-------------|
| `shared-concept` | Neutralna wiedza techniczna, wzorce, modele referencyjne |
| `client-work` | Praca dla konkretnego klienta, materiały klienta |
| `internal-product-strategy` | Strategia MakoLab, roadmapy produktów, decyzje biznesowe |
| `private-rnd` | Prywatne projekty, devops-toolkit, cloud-detective |
| `operational-runbook` | Procedury operacyjne, playbooki |
| `reference-material` | Komendy, snippety, dokumentacja referencyjna |
| `inbox-transient` | Tymczasowe — przypisz właściwą domenę w ciągu tygodnia |

---

### `origin`

| Wartość | Kiedy używać |
|---------|-------------|
| `own` | Własna praca, własne przemyślenia, własne badania |
| `client` | Materiał dostarczony lub wytworzony dla klienta |
| `employer` | Materiał MakoLab, decyzje organizacyjne |
| `vendor` | Dokumentacja vendorów, whitepapers, konferencje |
| `public` | Wiedza publiczna: blog posty, RFC, standardy, książki |
| `mixed` | Połączenie kilku źródeł — wymaga sekcji `## Źródła domen` |

---

### `classification`

| Wartość | Znaczenie |
|---------|-----------|
| `public` | Może być opublikowane bez konsekwencji |
| `internal` | Wewnętrzne MakoLab, nie publiczne |
| `confidential` | Dane klienta, strategie, dane infrastruktury |
| `restricted` | NDA, dane osobowe, credentiale, surowe logi produkcyjne |

---

### `llm_exposure`

| Wartość | Zasada |
|---------|--------|
| `allowed` | MAY być przekazane do dowolnego LLM bez ograniczeń |
| `restricted` | MUST być w skurowanej paczce, bez surowych danych wrażliwych |
| `prohibited` | MUST NOT trafiać do zewnętrznych modeli LLM w żadnej formie |

---

### `cross_domain_export`

| Wartość | Zasada |
|---------|--------|
| `allowed` | MAY być cytowane lub linkowane z innych domen |
| `summary-only` | Tylko zanonimizowane podsumowanie może opuścić domenę |
| `prohibited` | MUST NOT opuścić domeny w żadnej formie |

---

### `source_of_truth`

| Wartość | Znaczenie |
|---------|-----------|
| `vault` | Ten plik vault jest autorytatywny |
| `project-local` | Repo projektu (IaC, kod) jest autorytatywne; vault = dokumentacja |
| `client-material` | Materiał klienta jest autorytatywny; vault = notatki |
| `external-reference` | Dokument zewnętrzny (RFC, vendor doc) jest autorytatywny |
| `unknown` | Źródło prawdy nieznane — wymaga wyjaśnienia |

---

## Zasady stosowania

**MUST** każda notatka tworzona od 2026-04-24 zawierać pełny frontmatter.

**SHOULD** istniejące notatki bez frontmatter być aktualizowane przy pierwszej edycji.

**MUST NOT** pole `domain` być pomijane — jest kluczem do izolacji kontekstów.

**SHOULD** notatki z `domain: client-work` mieć `classification: confidential` minimum.

**MUST** notatki z `classification: restricted` mieć `llm_exposure: prohibited`.

**SHOULD** notatki z `origin: mixed` zawierać sekcję `## Źródła domen` wyjaśniającą skąd pochodzi każdy fragment.

---

## Przykłady poprawnego frontmatter

### Notatka z runbook ogólny

```yaml
---
title: ECS Fargate — crash loop diagnostics
domain: operational-runbook
origin: own
classification: internal
llm_exposure: allowed
cross_domain_export: allowed
source_of_truth: vault
created: 2026-04-24
updated: 2026-04-24
---
```

### Notatka projektu klientowskiego

```yaml
---
title: BMW AI Taskforce — meeting notes 2026-04-24
domain: client-work
origin: client
classification: confidential
llm_exposure: restricted
cross_domain_export: prohibited
source_of_truth: client-material
created: 2026-04-24
updated: 2026-04-24
---
```

### Notatka badań własnych

```yaml
---
title: Cloud Detective — hipotezy ewolucji
domain: private-rnd
origin: own
classification: restricted
llm_exposure: restricted
cross_domain_export: prohibited
source_of_truth: vault
created: 2026-04-24
updated: 2026-04-24
---
```
