---
tags: [finops, contract, toolkit, reporting]
created: 2026-04-30
status: approved
---

# FinOps Reporting Contract v1.0

Kontrakt definiuje semantykę danych, tryby raportowania i reguły walidacji dla `toolkit finops-report`.

Pełny spec (z implementation notes dla Codex): [[2026-04-30-finops-reporting-contract-design]]

---

## Problem, który rozwiązuje

AWS CE zwraca `estimated=true` dla bieżącego dnia → raporty niedeterministyczne → brak zaufania i niemożność diffowania w CI.

**Rozwiązanie:** domyślny tryb `snapshot` z `billing_lag_days=2`.

---

## Config (source of truth)

```yaml
finops:
  reporting:
    mode: snapshot          # snapshot | live
    billing_lag_days: 2
```

---

## Time Window

| Mode | End (exclusive) | Deterministyczny |
|------|-----------------|------------------|
| `snapshot` | `today - billing_lag_days` | TAK |
| `live` | `tomorrow` | NIE |

- `snapshot` → CI, Confluence, raporty zarządcze
- `live` → CLI, troubleshooting

---

## Kluczowe pojęcia

| Pole | Definicja |
|------|-----------|
| `cost_total` | AWS CE UnblendedCost. **Z Tax/Credit/Refund. Zgodne z fakturą.** |
| `operational_cost` | `cost_total − non_operational_costs`. Derived metric. Ranking serwisów. |
| `non_operational_costs` | Tax, Credit, Refund, Support. Osobna sekcja. Wliczone do `cost_total`. |
| `cost_by_service` | Tylko serwisy operacyjne. `sum == operational_cost` (R4). |
| `cost_by_environment` | Pełny spend. `sum == cost_total` (R3). |

---

## Reconciliation Rules

| ID | Formuła | Tolerancja |
|----|---------|------------|
| R1 | `cost_total == tagged + untagged` | $0.01 |
| R2 | `cost_total == operational_cost + non_operational_costs` | $0.01 |
| R3 | `sum(environments) == cost_total` | $1.00 |
| R4 | `sum(services) == operational_cost` | $0.01 |
| R5 | `all(estimated==false)` gdy snapshot | — → `data_quality_warning` |

**R2 = twardy accounting identity.** Jeśli nie zachodzi → dane CE niekompletne.

---

## Tagging — wymagane tagi

| Tag | Criticality |
|-----|-------------|
| `Project` | critical |
| `Environment` | critical (`prod\|staging\|dev\|shared`) |
| `Owner` | high |
| `CostCenter` | high |
| `ManagedBy` | medium (`terraform\|pulumi\|manual\|cloudformation`) |

**Edge cases:**
- tag w IaC, nie w runtime → `untagged` + flag `tagging_drift`
- tag w runtime, nie w CE → `tagged` + `data_quality_warning` (CE lag ~24h)
- tag z niepoprawną wartością → `untagged`

---

## Report Modes

| | Technical | Executive |
|--|-----------|-----------|
| usage_type | TAK | NIE |
| reconciliation_results | TAK | NIE |
| untagged breakdown | per service | suma tylko |
| tagging detail | per tag | status tylko |
| top services | pełna lista | Top 5 |

---

## CI Exit Codes

| Code | Znaczenie |
|------|-----------|
| 0 | OK |
| 1 | `data_quality_warning` (estimated mimo snapshot) |
| 2 | reconciliation failure (R1–R4 poza tolerancją) |
| 3 | drift alert (>20% lub >$500 vs poprzedni snapshot) |

---

## Snapshot versioning

```
.devops-toolkit/reports/finops/{YYYY-MM}/
  {report_type}_{mode}_lag{N}d_{end_date}.json

# przykład:
finops/2025-04/mtd_snapshot_lag2d_2025-04-28.json
```

Snapshoty są **immutable** — nigdy nie nadpisuj, zawsze nowy plik.

---

## Edge Cases

| Sytuacja | Zachowanie |
|----------|-----------|
| `today - lag < period_start` | Error `EMPTY_WINDOW` |
| CE zwraca estimated mimo snapshot | `data_quality_warning`, dane z flagą |
| Tax > 15% cost_total | `data_quality_warning` |
| Negative `cost_total` | Dozwolone (duże kredyty) |
| Zero cost environment | Nie pojawia się w `cost_by_environment` |
| `last-full-month` + snapshot | Zawsze deterministyczne |
