# FinOps Reporting Contract — Design Spec

**Status:** approved  
**Date:** 2026-04-30  
**Author:** Jarosław Gołąb  
**Scope:** devops-toolkit `toolkit finops-report` command

---

## 1. Problem

AWS Cost Explorer zwraca dane "estimated" dla bieżącego dnia. Powoduje to:
- niedeterministyczne raporty (run A ≠ run B dla tego samego okresu)
- niemożność diff-safe porównań w CI
- brak zaufania do danych zarządczych

**Rozwiązanie:** dwa tryby raportowania: `snapshot` (deterministyczny, domyślny) i `live` (real-time, tylko CLI).

---

## 2. Time Window Semantics

AWS CE semantics: **Start inclusive, End exclusive**.

| Mode | Start | End (exclusive) | Deterministyczny |
|------|-------|-----------------|------------------|
| `snapshot` | `first_day_of_period` | `today - billing_lag_days` | **TAK** |
| `live` | `first_day_of_period` | `tomorrow` | NIE |

**Przykład** MTD snapshot, `billing_lag_days=2`, `today=2025-04-30`:
- Start: `2025-04-01` (inclusive)
- End: `2025-04-28` (exclusive)
- Pokrywa: 1–27 kwietnia = 27 settled days

`last-full-month` + snapshot = zawsze deterministyczny niezależnie od laga.

---

## 3. Config

```yaml
finops:
  reporting:
    mode: snapshot          # snapshot | live
    billing_lag_days: 2     # default: 2 — configurable per project

    modes:
      snapshot:
        description: "Deterministic, diff-safe. CI, Confluence, management reports."
        end_formula: "today - billing_lag_days"
        settled_only: true
        data_quality:
          fail_on_estimated: false        # nie przerywa raportu
          emit_data_quality_warning: true # jawne oznaczenie gdy CE zwróci estimated mimo laga

      live:
        description: "Real-time MTD. CLI/troubleshooting only. Not diff-safe."
        end_formula: "tomorrow"
        settled_only: false
        data_quality:
          emit_estimated_disclaimer: true
```

---

## 4. Data Contract

### 4.1 Schema

```yaml
data_contract:
  schema_version: "1.0"

  # --- SOURCE OF TRUTH ---
  cost_total:
    value_usd: float          # AWS CE UnblendedCost — WSZYSTKO: Tax/Credit/Refund included
    source: "Cost Explorer UnblendedCost"
    period:
      start: "YYYY-MM-DD"     # inclusive
      end: "YYYY-MM-DD"       # exclusive
      mode: "snapshot | live"
      billing_lag_applied: int
      settled_days: int
    data_quality:
      all_settled: bool
      has_estimated_data: bool  # true = CE zwróciło estimated mimo laga
      warning: "string | null"

  # --- DERIVED METRIC ---
  operational_cost:
    value_usd: float          # cost_total - non_operational_costs
    note: "Used for service rankings and optimization analysis. Not shown on invoice."

  # --- NON-OPERATIONAL (Tax, Credits, Refunds) ---
  non_operational_costs:
    # Wliczone do cost_total. Wykluczone z operational_cost i service rankings.
    items:
      - type: "Tax | Credit | Refund | Support | Other"
        amount_usd: float     # ujemne dla Credit/Refund
    subtotal_usd: float       # może być ujemny (duże kredyty)

  # --- OPERATIONAL SERVICE RANKING ---
  cost_by_service:
    # Tylko serwisy operacyjne — Tax/Credit/Refund wykluczone z rankingu.
    # sum(cost_by_service) == operational_cost (R4)
    items:
      - name: str
        cost_usd: float
        pct_of_operational_cost: float
        show_usage_type: bool   # true tylko w trybie technical

  # --- ENVIRONMENT BREAKDOWN ---
  cost_by_environment:
    # sum(cost_by_environment) == cost_total (R3)
    # UWAGA: Tax/Credit/Refund nie mają tagu Environment → trafiają do bucket "untagged"
    # CE NIE rozkłada Tax proporcjonalnie. "untagged" zawiera zarówno zasoby bez tagów
    # jak i koszty non-operational bez tagów (Tax, Credits).
    items:
      - name: str               # prod | staging | dev | shared | untagged
        cost_usd: float
        pct_of_total: float

  # --- TAGGING ---
  untagged_cost:
    total_usd: float
    pct_of_total: float
    breakdown_by_service:       # tylko tryb technical
      - service: str
        cost_usd: float

  tagging_coverage:
    tagged_pct: float
    untagged_pct: float
    tagged_cost_usd: float
    untagged_cost_usd: float
    compliance_status: "compliant | warning | critical"
    # compliant  = untagged_pct < 5%
    # warning    = 5–20%
    # critical   = > 20%

  # --- DELTA ---
  delta:
    vs_previous_period:
      absolute_usd: float
      percent: float
      previous_period:
        start: "YYYY-MM-DD"
        end: "YYYY-MM-DD"
```

### 4.2 Kluczowe zasady

- `cost_total` = AWS CE UnblendedCost = source of truth = zgodne z fakturą
- `operational_cost` = derived = `cost_total - non_operational_costs.subtotal_usd`
- Tax/Credit/Refund **wliczone do** `cost_total`, **wykluczone z** `cost_by_service`
- `cost_by_environment` grupuje **pełny spend** (CE rozkłada Tax/Credits proporcjonalnie)

---

## 5. Reconciliation Rules

| ID | Reguła | Formuła | Tolerancja | On failure |
|----|--------|---------|------------|------------|
| R1 | tagged + untagged = total | `cost_total == tagged_cost + untagged_cost` | $0.01 | `emit_warning` |
| R2 | operational + non-op = total | `cost_total == operational_cost + non_operational_costs.subtotal_usd` | $0.01 | `emit_warning` |
| R3 | environments = total | `sum(cost_by_environment) == cost_total` | $1.00 (configurable per project) | `emit_warning` |
| R4 | services = operational | `sum(cost_by_service) == operational_cost` | $0.01 | `emit_warning` |
| R5 | no estimated in snapshot | `all(estimated==false)` gdy `mode=snapshot` | — | `emit_data_quality_warning` |

**R2 jest twardym accounting identity** — jeśli nie zachodzi, dane CE są niekompletne.  
**R3 ma wyższą tolerancję** — CE nie zawsze rozkłada Tax perfekcyjnie po tagach.

---

## 6. Tagging Contract

```yaml
tagging:
  required_tags:
    - key: "Project"
      criticality: critical     # brak = untagged bucket
    - key: "Environment"
      criticality: critical
      allowed_values: [prod, staging, dev, shared]
    - key: "Owner"
      criticality: high
    - key: "CostCenter"
      criticality: high
    - key: "ManagedBy"
      criticality: medium
      allowed_values: [terraform, pulumi, manual, cloudformation]

  edge_cases:
    tag_in_iac_not_runtime:
      classify_as: untagged
      flag: tagging_drift
      note: "Zasób wdrożony, tag nie propagował się (np. ECS task dziedziczący z klastra)."

    tag_in_runtime_not_cost_explorer:
      classify_as: tagged           # NIE licz jako untagged
      flag: data_quality_warning
      note: "Tag activation lag w CE ~24h. Nie karać zasobu za opóźnienie Cost Explorer."

    tag_value_not_in_allowed_values:
      classify_as: untagged
      note: "Niepoprawna wartość = brak tagu dla celów grupowania."
```

---

## 7. Report Modes — Technical vs Executive

| Element | Technical (DevOps) | Executive (Management) |
|---------|-------------------|----------------------|
| `cost_total` | TAK | TAK |
| `operational_cost` | TAK | TAK (jako "cost before adjustments") |
| `cost_by_service` | pełna lista + usage_type | Top 5 po koszcie, bez usage_type |
| `cost_by_environment` | wszystkie envs | wszystkie envs |
| `non_operational_costs` | pełna lista z typami | suma z etykietą "Tax & adjustments" |
| `untagged_cost` | z breakdown per service | tylko `total_usd` + `pct` |
| `tagging_coverage` | per-tag compliance + detail | `compliance_status` tylko |
| `reconciliation_results` | TAK | NIE |
| `data_quality_warnings` | pełny tekst | "⚠ data issues: N" |
| `delta` | kwota + % | kwota + % |
| `usage_type` | TAK | NIE |

---

## 8. CI / Automation

```yaml
ci:
  diff_safe:
    exclude_from_diff:          # legalnie różne między runami
      - generated_at
      - run_id
      - cli_version

    deterministic_fields:       # identyczne dla tych samych: period + mode + lag
      - cost_total.value_usd
      - cost_total.period
      - cost_by_service[*].cost_usd
      - cost_by_environment[*].cost_usd
      - non_operational_costs[*].amount_usd
      - untagged_cost.total_usd
      - operational_cost.value_usd

  snapshot_versioning:
    path_pattern: >
      .devops-toolkit/reports/finops/{YYYY-MM}/
      {report_type}_{mode}_lag{N}d_{end_date}.json
    example: "finops/2025-04/mtd_snapshot_lag2d_2025-04-28.json"
    immutable: true             # nigdy nie nadpisuj — zawsze nowy plik

  drift_detection:
    enabled: true
    compare_to: previous_snapshot
    alert_threshold_pct: 20
    alert_threshold_usd: 500

  ci_exit_codes:
    0: "raport OK, brak ostrzeżeń"
    1: "data_quality_warning (estimated data mimo snapshot)"
    2: "reconciliation failure (R1–R4 poza tolerancją)"
    3: "drift alert (powyżej progu)"
```

---

## 9. Edge Cases

| Sytuacja | Zachowanie |
|----------|-----------|
| `today - lag < period_start` | Error: `EMPTY_WINDOW`. Raport nie generowany. |
| CE zwraca `estimated=true` mimo snapshot | `data_quality_warning`, dane oznaczone, **wchodzą** do `cost_total` ale z flagą |
| Tag activation lag w CE | `classify_as: tagged` + `data_quality_warning` |
| EDP / RI adjustments opóźnione >48h | `data_quality_warning` na R2 (R2 poza tolerancją) |
| Zero cost environment | Środowisko **nie pojawia się** w `cost_by_environment` |
| Negative `cost_total` (duże kredyty > spend) | Dozwolone — nie jest błędem |
| `Tax > 15% of cost_total` | Nienormalne — `emit_data_quality_warning` z wartością % |
| Region mix (eu-west-1 + us-east-1) | Grupowanie po regionie opcjonalne, domyślnie wyłączone |
| `last-full-month` + snapshot | Zawsze deterministyczne — lag nieistotny dla zamkniętego miesiąca |

---

## 10. Implementation Notes for Codex

### Pliki do modyfikacji (Python + boto3)

#### `toolkit/finops/periods.py`

```python
from datetime import date, timedelta
from dataclasses import dataclass
from typing import Literal

@dataclass
class ReportingPeriod:
    start: date          # inclusive
    end: date            # exclusive (AWS CE convention)
    mode: Literal["snapshot", "live"]
    billing_lag_applied: int
    settled_days: int

def build_snapshot_period(
    period_type: str,        # "mtd" | "last-full-month" | "custom"
    billing_lag_days: int = 2,
    custom_start: date | None = None,
    custom_end: date | None = None,
) -> ReportingPeriod:
    today = date.today()
    end = today - timedelta(days=billing_lag_days)  # exclusive cutoff

    if period_type == "mtd":
        start = today.replace(day=1)
    elif period_type == "last-full-month":
        # zamknięty miesiąc — lag nieistotny
        first_of_this_month = today.replace(day=1)
        end = first_of_this_month
        start = (first_of_this_month - timedelta(days=1)).replace(day=1)
    elif period_type == "custom":
        start = custom_start
        end = custom_end
    else:
        raise ValueError(f"Unknown period_type: {period_type}")

    if end <= start:
        raise ValueError(f"EMPTY_WINDOW: end={end} <= start={start}. "
                         f"Increase billing_lag_days or use a different period.")

    settled_days = (end - start).days
    return ReportingPeriod(
        start=start,
        end=end,
        mode="snapshot",
        billing_lag_applied=billing_lag_days,
        settled_days=settled_days,
    )

def build_live_period(period_type: str, ...) -> ReportingPeriod:
    today = date.today()
    end = today + timedelta(days=1)  # AWS CE: end exclusive = include today
    start = today.replace(day=1) if period_type == "mtd" else ...
    return ReportingPeriod(start=start, end=end, mode="live",
                           billing_lag_applied=0,
                           settled_days=(end - start).days)
```

#### `toolkit/finops/collect.py`

```python
def collect_cost_total(ce_client, period: ReportingPeriod) -> dict:
    response = ce_client.get_cost_and_usage(
        TimePeriod={"Start": str(period.start), "End": str(period.end)},
        Granularity="MONTHLY",
        Metrics=["UnblendedCost"],
    )

    result_by_time = response["ResultsByTime"][0]
    total = float(result_by_time["Total"]["UnblendedCost"]["Amount"])

    # Wykryj estimated mimo snapshot
    is_estimated = result_by_time.get("Estimated", False)
    data_quality_warning = None
    if period.mode == "snapshot" and is_estimated:
        data_quality_warning = (
            f"Cost Explorer returned estimated=true for period ending {period.end} "
            f"despite billing_lag_days={period.billing_lag_applied}. "
            f"Data may include partial-day estimates. "
            f"Consider increasing billing_lag_days."
        )

    return {
        "value_usd": total,
        "source": "Cost Explorer UnblendedCost",
        "period": {
            "start": str(period.start),
            "end": str(period.end),
            "mode": period.mode,
            "billing_lag_applied": period.billing_lag_applied,
            "settled_days": period.settled_days,
        },
        "data_quality": {
            "all_settled": not is_estimated,
            "has_estimated_data": is_estimated,
            "warning": data_quality_warning,
        },
    }
```

#### `toolkit/finops/normalize.py`

```python
NON_OPERATIONAL_PREFIXES = ("Tax", "Credit", "Refund", "AWS Support")

def is_non_operational(service_name: str) -> bool:
    return any(service_name.startswith(p) for p in NON_OPERATIONAL_PREFIXES)

def classify_non_op(service_name: str) -> str:
    if service_name.startswith("Tax"): return "Tax"
    if service_name.startswith("Credit"): return "Credit"
    if service_name.startswith("Refund"): return "Refund"
    if service_name.startswith("AWS Support"): return "Support"
    return "Other"

def normalize_cost_by_service(raw_services: list[dict]) -> tuple[list, list]:
    """Returns (operational_services, non_operational_costs)."""
    operational, non_op = [], []
    for svc in raw_services:
        item = {"name": svc["name"], "cost_usd": float(svc["cost"])}
        if is_non_operational(svc["name"]):
            non_op.append({
                "type": classify_non_op(svc["name"]),
                "amount_usd": item["cost_usd"],
            })
        else:
            operational.append(item)
    return operational, non_op

def compute_operational_cost(cost_total: float, non_op_items: list[dict]) -> float:
    non_op_total = sum(i["amount_usd"] for i in non_op_items)
    return cost_total - non_op_total

def validate_reconciliation(
    cost_total: float,
    operational_cost: float,
    non_op_subtotal: float,
    tagged_cost: float,
    untagged_cost: float,
    env_sum: float,
    op_services_sum: float,
    tolerance: float = 0.01,
    r3_tolerance: float = 1.00,   # per-project override
) -> list[dict]:
    warnings = []

    # r3_tolerance configurable per project (config: finops.reporting.reconciliation.r3_tolerance_usd)
    checks = [
        ("R1", cost_total, tagged_cost + untagged_cost, 0.01),
        ("R2", cost_total, operational_cost + non_op_subtotal, 0.01),
        ("R3", cost_total, env_sum, r3_tolerance),   # default 1.00, per-project override
        ("R4", operational_cost, op_services_sum, 0.01),
    ]

    for rule_id, expected, actual, tol in checks:
        diff = abs(expected - actual)
        if diff > tol:
            warnings.append({
                "rule": rule_id,
                "expected": expected,
                "actual": actual,
                "diff": diff,
                "tolerance": tol,
                "message": f"{rule_id} reconciliation failed: diff={diff:.4f} > tolerance={tol}",
            })

    return warnings  # pusta lista = OK
```

#### `toolkit/finops/report_model.py`

Dodaj do `CostReport` dataclass:
```python
@dataclass
class CostReport:
    cost_total: CostTotal
    operational_cost: OperationalCost          # derived
    non_operational_costs: NonOperationalCosts # Tax, Credits etc.
    cost_by_service: list[ServiceCost]         # operational only
    cost_by_environment: list[EnvironmentCost]
    untagged_cost: UntaggedCost
    tagging_coverage: TaggingCoverage
    delta: Delta
    reconciliation_results: list[ReconciliationWarning]
    data_quality_warnings: list[str]
    schema_version: str = "1.0"
    generated_at: str = field(default_factory=lambda: datetime.utcnow().isoformat())
    mode: Literal["snapshot", "live"] = "snapshot"
```

#### Snapshot versioning (`toolkit/finops/output.py`)

```python
def snapshot_path(report_type: str, period: ReportingPeriod) -> Path:
    month = period.start.strftime("%Y-%m")
    end_date = str(period.end)
    lag = period.billing_lag_applied
    filename = f"{report_type}_{period.mode}_lag{lag}d_{end_date}.json"
    return Path(".devops-toolkit/reports/finops") / month / filename

# Zawsze nowy plik — nigdy nie nadpisuj istniejącego snapshotu
def save_snapshot(report: dict, path: Path) -> None:
    if path.exists():
        raise FileExistsError(f"Snapshot already exists: {path}. Snapshots are immutable.")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, indent=2, default=str))
```

#### CI exit codes (`toolkit/finops/cli.py`)

```python
import sys

def run_report(...) -> int:
    report = generate_report(...)
    save_snapshot(report, snapshot_path(...))

    has_data_quality = bool(report["cost_total"]["data_quality"]["has_estimated_data"])
    has_reconciliation_failure = bool(report["reconciliation_results"])
    has_drift = check_drift(report) if drift_detection_enabled else False

    if has_drift:
        return 3
    if has_reconciliation_failure:
        return 2
    if has_data_quality:
        return 1
    return 0

sys.exit(run_report(...))
```

### Kolejność implementacji

1. `periods.py` — `build_snapshot_period()` + `build_live_period()` + `EMPTY_WINDOW` guard
2. `collect.py` — `estimated` flag detection + `data_quality_warning`
3. `normalize.py` — `is_non_operational()` + `compute_operational_cost()` + `validate_reconciliation()`
4. `report_model.py` — dodaj `operational_cost`, `non_operational_costs`, `reconciliation_results`, `data_quality_warnings`
5. `output.py` — `snapshot_path()` + immutable `save_snapshot()`
6. `cli.py` — exit codes + `--mode` / `--billing-lag-days` flags
7. `config/finops.yaml` — dodaj `mode: snapshot`, `billing_lag_days: 2`
8. Testy — jeden test na każdą regułę R1–R4, jeden na `EMPTY_WINDOW`, jeden na `estimated=true` mimo snapshot

---

## Appendix: Variant C (future extension)

Wariant "include + tag" (estimated dane w raporcie ale wykluczone z `cost_total`):
- Wymaga osobnego pola `cost_total_with_estimated` obok `cost_total`
- Sensowny dla real-time dashboardów (nie dla raportów zarządczych)
- Nie implementować jako default — zbyt dużo ambiguity przy reconciliation
