# FinOps Reporting — devops-toolkit

#toolkit #finops

Źródło prawdy: `~/projekty/devops/devops-toolkit/docs/course/finops-mini-course.md`
Pipeline: `collect-cost-explorer-grouped.py` → `normalize_cost_*` → `sanitize_cost` → `finops-report`

---

## Szybkie komendy

```bash
# Executive MTD (domyślny)
toolkit finops-report <projekt> --period mtd --group-by service

# Techniczny z pełną diagnostyką
toolkit finops-report <projekt> --period mtd --group-by usage-type --audience technical

# Poprzedni pełny miesiąc
toolkit finops-report <projekt> --period last-full-month --group-by service

# Filtr prod + JSON
toolkit finops-report <projekt> --period mtd --env prod --format both

# Confluence (bez emoji)
toolkit finobs-report <projekt> --period mtd --format confluence
```

---

## Flagi

| Flaga | Wartości | Domyślna |
|-------|---------|---------|
| `--period` | `mtd`, `last-full-month` | `mtd` |
| `--group-by` | `service`, `usage-type` | brak |
| `--audience` | `executive`, `technical` | `executive` |
| `--env` | dowolna | brak |
| `--format` | `md`, `json`, `both`, `confluence` | `md` |

---

## Pliki wynikowe

```
.devops-toolkit/reports/finops/
  mtd-report.md
  mtd-report.json          ← --format json|both
  mtd-report.confluence.md ← --format confluence
  last-full-month-report.md
```

---

## Pipeline wewnętrzny

```
collect-cost-explorer-grouped.py  → raw/cost-explorer-grouped.json
  normalize_cost_total            → normalized/cost-total.json
  normalize_cost_by_service       → normalized/cost-by-service.json
  normalize_cost_by_environment   → normalized/cost-by-environment.json
  normalize_cost_delta            → normalized/cost-delta.json
  sanitize_cost                   → sanitized/findings-cost.json  ✓ zaimplementowany
```

**LEGACY:** `aws_cost_hotspots` audit używa oddzielnego pipeline:
`collect-cost-explorer.sh` → `normalize-cost.py` → `sanitize_cost` ✓ zaimplementowany

---

## Jak czytać raport

**Zakres konta (domyślny):** całe konto AWS, wszystkie środowiska łącznie.
**Zakres środowiska (`--env prod`):** filtr po tagu `Environment=prod` — tylko tagged resources.

**Untagged cost:** zasoby bez tagu `Environment` trafiają do bucketu `No tag key: Environment`.
- `> 50%` untagged → analiza per-środowisko jest niewiarygodna
- `> 20%` → ostrzeżenie, dane niepełne

**Porównanie MTD:** poprzednie okno tej samej długości (nie pełny miesiąc).

---

## Sekcje raportu (executive vs technical)

| Sekcja | Executive | Technical |
|--------|-----------|-----------|
| Cost Change by Service | ✓ | ✓ |
| Change Pattern Assessment | ✓ | ✓ |
| Root Cause Summary | ✓ | ✓ |
| What Likely Changed | ✓ | ✓ |
| Growth Breakdown | — | ✓ |
| Anomalies | — | ✓ |
| Recommendations | — | ✓ |

---

## UI operatorski

```bash
toolkit ui <projekt>   # http://localhost:8765
# → FinOps Report → Run finops-report
# → "Kopiuj do Confluence" — rich text do schowka
```

---

## Powiązane

- [[command-catalog]]
- [[finops-review-patterns]]
- `~/projekty/devops/devops-toolkit/docs/course/finops-mini-course.md`
