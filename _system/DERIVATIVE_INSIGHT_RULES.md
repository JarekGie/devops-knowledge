---
title: Zasady pochodnych wniosków między domenami
domain: shared-concept
origin: own
classification: internal
llm_exposure: allowed
cross_domain_export: allowed
source_of_truth: vault
created: 2026-04-24
updated: 2026-04-24
---

# Zasady pochodnych wniosków między domenami

> Reguluje jedyny legalny mechanizm przepływu wiedzy z domeny wrażliwej do innej.
> „Derived insight" to wniosek wyabstrahowany, zanonimizowany i jawnie oznaczony.

Powiązane: [[DOMAIN_ISOLATION_CONTRACT]] | [[CLASSIFICATION_MODEL]] | [[KNOWLEDGE_BOUNDARIES]]

---

## Problem, który te zasady rozwiązują

Praca przy projekcie klienta (np. BMW AI Taskforce) generuje wnioski, które mogą być wartościowe dla:
- strategii produktowej MakoLab (Cloud Support as a Service),
- własnych badań (devops-toolkit, cloud-detective).

Bezpośrednia kopia tych wniosków naruszałaby:
- poufność danych klienta,
- zaufanie klienta,
- zasady etyki zawodowej.

**Derived insight** to formalna procedura transformacji wiedzy klientowskiej w wiedzę neutralną.

---

## Definicja derived insight

Derived insight to wniosek który:
1. **pochodzi z** materiałów klientowskich lub innych wrażliwych domen,
2. **został zanonimizowany** — brak nazwy klienta, nazw systemów, konkretnych liczb,
3. **został uogólniony** — opisuje wzorzec, nie konkretny przypadek,
4. **jest jawnie oznaczony** jako derived — nie jest prezentowany jako własna hipoteza.

---

## Procedura tworzenia derived insight

### Krok 1 — Identyfikacja wniosku

Notatka w przestrzeni klienta zawiera obserwację, która może być przydatna poza tą domeną.

Przykład:
> W projekcie BMW zaobserwowaliśmy, że brak ujednoliconego CMDB powoduje powtarzalne błędy w korelacji alertów.

### Krok 2 — Anonimizacja

**MUST** usunąć:
- nazwę klienta,
- nazwy systemów klienta,
- konkretne dane liczbowe (wolumeny, SLO, koszty),
- nazwy osób i zespołów klienta,
- daty związane z konkretnym incydentem.

**SHOULD** zamienić:
- konkretny system → „duże środowisko produkcyjne",
- konkretny klient → „organizacja enterprise",
- konkretna liczba → „znacząca liczba / wysoki wolumen".

### Krok 3 — Generalizacja

**MUST** wniosek opisywać wzorzec, nie przypadek.

Przed: *BMW ma problem z X bo ich CMDB jest nieaktualny*
Po: *Organizacje bez procesów automatycznej aktualizacji CMDB doświadczają wyższego MTTD przy korelacji alertów*

### Krok 4 — Oznaczenie w notatce docelowej

**MUST** każdy derived insight w notatce docelowej być oznaczony w jednej z form:

```markdown
> [!note] Derived insight
> Wniosek uogólniony na podstawie obserwacji z projektu klientowskiego (zanonimizowane).
> Data generalizacji: YYYY-MM-DD
```

lub w frontmatter notatki docelowej:
```yaml
related_domains:
  - client-work (derived, anonymized, YYYY-MM-DD)
```

### Krok 5 — Weryfikacja przed użyciem LLM

**MUST** przed użyciem derived insight w sesji LLM sprawdzić:
- czy anonimizacja jest kompletna,
- czy można zidentyfikować klienta na podstawie kontekstu,
- czy wniosek jest na tyle ogólny, że nie zdradza szczegółów projektu.

---

## Tabela dozwolonych transformacji

| Źródło | Cel | Status | Warunek |
|--------|-----|--------|---------|
| `client-work` → `shared-concept` | ALLOWED | po pełnej anonimizacji i generalizacji |
| `client-work` → `internal-product-strategy` | ALLOWED | po pełnej anonimizacji + jawne derived |
| `client-work` → `private-rnd` | ALLOWED | po pełnej anonimizacji + jawne derived |
| `internal-product-strategy` → `private-rnd` | ALLOWED | po jawnym oznaczeniu źródła |
| `private-rnd` → `internal-product-strategy` | ALLOWED | po jawnym oznaczeniu źródła |
| `client-work` → `client-work` (inny klient) | PROHIBITED | bez wyjątków |
| Bezpośrednia kopia bez anonimizacji | PROHIBITED | bez wyjątków |

---

## Przykłady

### Przykład poprawny

**Oryginalny wniosek (w przestrzeni BMW, confidential):**
> W trakcie analizy AI Taskforce BMW zidentyfikowaliśmy, że ich team operations spędza ~40% czasu na manualnej korelacji alertów z 6 różnych systemów monitoringowych.

**Derived insight (w 30-research/ai4devops/, public):**
> [!note] Derived insight
> Wniosek uogólniony na podstawie obserwacji z projektu klientowskiego (zanonimizowane). Data generalizacji: 2026-04-24

> Duże teams operations w organizacjach enterprise bez zunifikowanej warstwy korelacji alertów raportują znaczące nakłady czasowe na manualną korelację sygnałów z heterogenicznych systemów monitoringowych. To potwierdza hipotezę H2 z [[README]] (alert fatigue jako problem strukturalny).

---

### Przykład niepoprawny

**Niedopuszczalne (naruszenie R3 z [[DOMAIN_ISOLATION_CONTRACT]]):**
> W BMW widzieliśmy że mają problem X, dlatego w Cloud Support as a Service powinniśmy zaoferować Y.

Naruszenie: bezpośrednie przypisanie klienta do wniosku, brak anonimizacji.

---

## Rejestr derived insights (opcjonalny)

SHOULD każdy derived insight być odnotowany w:

```
_system/derived-insights-log.md  (opcjonalny)
```

Format:
```
- YYYY-MM-DD | Źródło: client-work/<klient> | Cel: <domena> | Plik: <link>
```

Ten rejestr nie jest wymagany, ale pomaga śledzić, skąd pochodzi wiedza w vault.
