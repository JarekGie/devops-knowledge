# FinOps Reporting Contract Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement production-grade FinOps reporting contract with deterministic `snapshot` mode (billing_lag_days=2), reconciliation rules R1–R5, `operational_cost` as derived metric, and CI-safe exit codes.

**Architecture:** Extend `periods.py` with mode/lag semantics → detect `estimated` flag in `collect.py` → new `reconciliation.py` module for R1–R5 → wire results into `normalize.py`'s `build_finops_model()` → surface warnings in `report_model.py` → add CLI flags + immutable snapshots + exit codes in `commands/finops_report.py`.

**Tech Stack:** Python 3.11+, boto3, pytest, unittest.mock. All user-facing text in Polish. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-04-30-finops-reporting-contract-design.md`

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `toolkit/finops/periods.py` | Modify | Add `mode`, `billing_lag_applied`, `settled_days` to `ReportingPeriod`; add `build_snapshot_period()`, `build_live_period()` |
| `toolkit/finops/collect.py` | Modify | Extract `Estimated` flag from CE response; return in raw dict |
| `toolkit/finops/reconciliation.py` | **Create** | R1–R5 validation, `compute_operational_cost()`, non-op classification |
| `toolkit/finops/normalize.py` | Modify | Wire `operational_cost` + reconciliation + `data_quality_warnings` into `build_finops_model()` |
| `toolkit/finops/report_model.py` | Modify | Add `data_quality_warnings` section (both modes), `reconciliation_results` section (technical only) |
| `config/finops.yaml` | Modify | Add `reporting.mode`, `billing_lag_days`, `reconciliation.r3_tolerance_usd` |
| `toolkit/commands/finops_report.py` | Modify | `--mode`/`--billing-lag-days` flags, immutable snapshot names, CI exit codes |
| `tests/test_finops_periods.py` | Modify | Add tests for snapshot/live/EMPTY_WINDOW |
| `tests/unit/test_finops_reporting_contract.py` | **Create** | Tests for reconciliation module |
| `tests/unit/test_finops_normalize_contract.py` | **Create** | Tests for normalized model with reconciliation results |

---

## Task 1: Extend ReportingPeriod with mode and lag fields

**Files:**
- Modify: `toolkit/finops/periods.py`
- Modify: `tests/test_finops_periods.py`

- [ ] **Step 1.1: Write failing tests for new ReportingPeriod fields**

Append to `tests/test_finops_periods.py`:

```python
class TestReportingPeriodContract:
    def test_snapshot_period_has_mode_field(self):
        p = resolve_period(period="mtd", mode="snapshot", billing_lag_days=2)
        assert p.mode == "snapshot"

    def test_snapshot_period_has_billing_lag_applied(self):
        p = resolve_period(period="mtd", mode="snapshot", billing_lag_days=2)
        assert p.billing_lag_applied == 2

    def test_snapshot_period_has_settled_days(self):
        p = resolve_period(period="mtd", mode="snapshot", billing_lag_days=2)
        assert p.settled_days > 0

    def test_live_period_has_zero_lag(self):
        p = resolve_period(period="mtd", mode="live")
        assert p.mode == "live"
        assert p.billing_lag_applied == 0

    def test_snapshot_end_is_today_minus_lag(self):
        target = date(2025, 4, 30)
        with patch("toolkit.finops.periods.date") as mock_date:
            mock_date.today.return_value = target
            mock_date.fromisoformat = date.fromisoformat
            mock_date.side_effect = lambda *a, **kw: date(*a, **kw)
            p = resolve_period(period="mtd", mode="snapshot", billing_lag_days=2)
        # end exclusive = 2025-04-28, so last covered day = 2025-04-27
        assert p.end == date(2025, 4, 28)

    def test_snapshot_empty_window_raises(self):
        # billing_lag so large that end <= start
        target = date(2025, 4, 2)   # 2nd day of month, lag=3 → end=Mar 30 < Apr 1
        with patch("toolkit.finops.periods.date") as mock_date:
            mock_date.today.return_value = target
            mock_date.fromisoformat = date.fromisoformat
            mock_date.side_effect = lambda *a, **kw: date(*a, **kw)
            with pytest.raises(ValueError, match="EMPTY_WINDOW"):
                resolve_period(period="mtd", mode="snapshot", billing_lag_days=3)

    def test_last_full_month_snapshot_is_always_deterministic(self):
        # last-full-month in snapshot mode: lag ignored, always full month
        for lag in [0, 2, 5]:
            p = resolve_period(period="last-full-month", mode="snapshot", billing_lag_days=lag)
            assert p.mode == "snapshot"
            assert p.start.day == 1
            assert p.end.day == 1      # end = first day of current month (exclusive)
            assert p.settled_days > 27  # at least 28 days
```

- [ ] **Step 1.2: Run tests to confirm they fail**

```bash
cd /Users/jaroslaw.golab/projekty/devops/devops-toolkit
pytest tests/test_finops_periods.py::TestReportingPeriodContract -v
```

Expected: multiple `FAILED` / `TypeError` (unknown kwarg `mode`).

- [ ] **Step 1.3: Extend `ReportingPeriod` dataclass and `resolve_period()` in `periods.py`**

Open `toolkit/finops/periods.py`. Find the `ReportingPeriod` dataclass and add three fields with defaults (backwards-compatible):

```python
from typing import Literal

@dataclass
class ReportingPeriod:
    # --- existing fields (keep as-is) ---
    label: str
    start: date
    end: date
    prev_start: date
    prev_end: date
    # --- new fields ---
    mode: Literal["snapshot", "live"] = "live"
    billing_lag_applied: int = 0
    settled_days: int = 0
```

Find `resolve_period()` signature and add parameters:

```python
def resolve_period(
    period: str = "mtd",
    start: str | None = None,
    end: str | None = None,
    mode: str = "live",               # NEW
    billing_lag_days: int = 0,        # NEW
) -> ReportingPeriod:
```

Inside `resolve_period()`, after the existing start/end logic is resolved (where `p_start` and `p_end` are computed), add this block **before** the `return` statement:

```python
    # Apply snapshot mode: trim end by billing lag
    if mode == "snapshot" and period != "last-full-month":
        snap_end = date.today() - timedelta(days=billing_lag_days)
        if snap_end <= p_start:
            raise ValueError(
                f"EMPTY_WINDOW: snapshot end={snap_end} <= period start={p_start}. "
                f"Increase billing_lag_days or use a wider period."
            )
        p_end = snap_end

    settled = (p_end - p_start).days
```

Update the `return` statement to pass the new fields:

```python
    return ReportingPeriod(
        label=period,
        start=p_start,
        end=p_end,
        prev_start=prev_start,
        prev_end=prev_end,
        mode=mode,
        billing_lag_applied=billing_lag_days if mode == "snapshot" else 0,
        settled_days=settled,
    )
```

- [ ] **Step 1.4: Run tests to confirm they pass**

```bash
pytest tests/test_finops_periods.py::TestReportingPeriodContract -v
```

Expected: all 7 tests `PASSED`.

- [ ] **Step 1.5: Run full periods test suite to confirm no regressions**

```bash
pytest tests/test_finops_periods.py -v
```

Expected: all existing tests still `PASSED`.

- [ ] **Step 1.6: Commit**

```bash
git add toolkit/finops/periods.py tests/test_finops_periods.py
git commit -m "feat(finops): add snapshot/live mode and billing_lag to ReportingPeriod"
```

---

## Task 2: Detect estimated flag in collect.py

**Files:**
- Modify: `toolkit/finops/collect.py`
- Modify: `tests/unit/test_finops_billing_gap.py` (existing — add two tests)

The CE response `ResultsByTime[0]["Estimated"]` is `True` when the period overlaps the current (partial) day. We need to surface this flag in the raw output so downstream code can act on it.

- [ ] **Step 2.1: Write failing tests**

Append to `tests/unit/test_finops_billing_gap.py` (or create a class at the end of the file):

```python
class TestEstimatedFlagDetection:
    """collect.py must surface CE's Estimated=True in the raw output."""

    def _make_ce_response(self, estimated: bool) -> dict:
        return {
            "ResultsByTime": [{
                "TimePeriod": {"Start": "2025-04-01", "End": "2025-04-28"},
                "Total": {"UnblendedCost": {"Amount": "950.00", "Unit": "USD"}},
                "Groups": [],
                "Estimated": estimated,
            }]
        }

    def test_estimated_false_propagated(self):
        from unittest.mock import MagicMock, patch
        mock_ce = MagicMock()
        mock_ce.get_cost_and_usage.return_value = self._make_ce_response(False)
        with patch("toolkit.finops.collect.boto3") as mock_boto3:
            mock_boto3.client.return_value = mock_ce
            from toolkit.finops.collect import collect_cost_data
            raw = collect_cost_data(
                period=_make_period("2025-04-01", "2025-04-28"),
                env_filter=None,
                group_by="service",
            )
        assert raw["estimated"] is False

    def test_estimated_true_propagated(self):
        from unittest.mock import MagicMock, patch
        mock_ce = MagicMock()
        mock_ce.get_cost_and_usage.return_value = self._make_ce_response(True)
        with patch("toolkit.finops.collect.boto3") as mock_boto3:
            mock_boto3.client.return_value = mock_ce
            from toolkit.finops.collect import collect_cost_data
            raw = collect_cost_data(
                period=_make_period("2025-04-01", "2025-05-01"),
                env_filter=None,
                group_by="service",
            )
        assert raw["estimated"] is True


def _make_period(start_iso: str, end_iso: str):
    """Helper: build a minimal ReportingPeriod for tests."""
    from toolkit.finops.periods import ReportingPeriod
    s = date.fromisoformat(start_iso)
    e = date.fromisoformat(end_iso)
    return ReportingPeriod(
        label="custom", start=s, end=e, prev_start=s, prev_end=e,
        mode="snapshot", billing_lag_applied=2, settled_days=(e - s).days,
    )
```

- [ ] **Step 2.2: Run to confirm failure**

```bash
pytest tests/unit/test_finops_billing_gap.py::TestEstimatedFlagDetection -v
```

Expected: `FAILED` — `raw` dict has no `estimated` key.

- [ ] **Step 2.3: Add estimated flag extraction to collect.py**

In `toolkit/finops/collect.py`, find the function that calls `ce.get_cost_and_usage()` for the total (no-grouping) query — likely inside `_collect_period()`. After extracting the total amount, add:

```python
    # Extract CE's estimated flag (True when period overlaps current partial day)
    result_by_time = response["ResultsByTime"][0]
    is_estimated = bool(result_by_time.get("Estimated", False))
```

Find where the function builds and returns its result dict. Add `"estimated": is_estimated` to that dict. If the return is a nested dict (e.g., `raw["cost_total"]`), add it at the top level of the raw output:

```python
    raw["estimated"] = is_estimated
```

Also find `collect_cost_data_unavailable()` (the stub returned when CE is unreachable) and add `"estimated": False` to it so downstream code always finds the key.

- [ ] **Step 2.4: Run tests to confirm they pass**

```bash
pytest tests/unit/test_finops_billing_gap.py::TestEstimatedFlagDetection -v
```

Expected: both `PASSED`.

- [ ] **Step 2.5: Run full collect test suite**

```bash
pytest tests/unit/test_finops_billing_gap.py tests/unit/test_finops_runtime_collect.py -v
```

Expected: all existing tests still `PASSED`.

- [ ] **Step 2.6: Commit**

```bash
git add toolkit/finops/collect.py tests/unit/test_finops_billing_gap.py
git commit -m "feat(finops): surface CE Estimated flag in raw collect output"
```

---

## Task 3: Create reconciliation.py module

**Files:**
- Create: `toolkit/finops/reconciliation.py`
- Create: `tests/unit/test_finops_reporting_contract.py`

- [ ] **Step 3.1: Write failing tests**

Create `tests/unit/test_finops_reporting_contract.py`:

```python
import sys
from pathlib import Path
from datetime import date

import pytest

TOOLKIT_ROOT = Path(__file__).parent.parent.parent
sys.path.insert(0, str(TOOLKIT_ROOT))

from toolkit.finops.reconciliation import (
    is_non_operational,
    classify_non_op,
    compute_operational_cost,
    validate_reconciliation,
    ReconciliationResult,
)


class TestIsNonOperational:
    def test_tax_is_non_operational(self):
        assert is_non_operational("Tax") is True

    def test_credit_is_non_operational(self):
        assert is_non_operational("Credit") is True

    def test_refund_is_non_operational(self):
        assert is_non_operational("Refund") is True

    def test_aws_support_is_non_operational(self):
        assert is_non_operational("AWS Support (Developer)") is True

    def test_ec2_is_operational(self):
        assert is_non_operational("Amazon EC2") is False

    def test_s3_is_operational(self):
        assert is_non_operational("Amazon Simple Storage Service") is False


class TestClassifyNonOp:
    def test_tax(self):
        assert classify_non_op("Tax") == "Tax"

    def test_credit(self):
        assert classify_non_op("Credit") == "Credit"

    def test_refund(self):
        assert classify_non_op("Refund") == "Refund"

    def test_support(self):
        assert classify_non_op("AWS Support (Developer)") == "Support"

    def test_other_billing(self):
        assert classify_non_op("Other Billing Adjustment") == "Other"


class TestComputeOperationalCost:
    def test_subtracts_non_op_from_total(self):
        non_op = [
            {"type": "Tax", "amount_usd": 50.00},
            {"type": "Credit", "amount_usd": -10.00},
        ]
        result = compute_operational_cost(cost_total=1000.00, non_op_items=non_op)
        assert abs(result - 960.00) < 0.01

    def test_no_non_op_returns_total(self):
        result = compute_operational_cost(cost_total=500.00, non_op_items=[])
        assert abs(result - 500.00) < 0.01

    def test_large_credit_can_make_negative(self):
        non_op = [{"type": "Credit", "amount_usd": -200.00}]
        result = compute_operational_cost(cost_total=100.00, non_op_items=non_op)
        assert result == pytest.approx(300.00)  # 100 - (-200)


class TestValidateReconciliation:
    """Each rule tested independently; pass case and fail case."""

    def _base_args(self):
        return dict(
            cost_total=1000.00,
            operational_cost=950.00,
            non_op_subtotal=50.00,
            tagged_cost=800.00,
            untagged_cost=200.00,
            env_sum=1000.00,
            op_services_sum=950.00,
            mode="snapshot",
            r3_tolerance=1.00,
        )

    def test_all_rules_pass_returns_empty_list(self):
        results = validate_reconciliation(**self._base_args())
        assert results == []

    def test_r1_fails_when_tagged_plus_untagged_diverges(self):
        args = self._base_args()
        args["untagged_cost"] = 205.00   # 800+205=1005 ≠ 1000
        results = validate_reconciliation(**args)
        rules = [r.rule_id for r in results]
        assert "R1" in rules

    def test_r2_fails_when_operational_plus_non_op_diverges(self):
        args = self._base_args()
        args["non_op_subtotal"] = 55.00  # 950+55=1005 ≠ 1000
        results = validate_reconciliation(**args)
        rules = [r.rule_id for r in results]
        assert "R2" in rules

    def test_r3_passes_within_tolerance(self):
        args = self._base_args()
        args["env_sum"] = 1000.50        # diff=0.50 < tolerance=1.00
        results = validate_reconciliation(**args)
        assert all(r.rule_id != "R3" for r in results)

    def test_r3_fails_beyond_tolerance(self):
        args = self._base_args()
        args["env_sum"] = 1002.00        # diff=2.00 > tolerance=1.00
        results = validate_reconciliation(**args)
        rules = [r.rule_id for r in results]
        assert "R3" in rules

    def test_r3_tolerance_configurable(self):
        args = self._base_args()
        args["env_sum"] = 1004.00        # diff=4.00
        args["r3_tolerance"] = 5.00      # but tolerance=5.00 → should pass
        results = validate_reconciliation(**args)
        assert all(r.rule_id != "R3" for r in results)

    def test_r4_fails_when_service_sum_diverges_from_operational(self):
        args = self._base_args()
        args["op_services_sum"] = 940.00  # 940 ≠ 950
        results = validate_reconciliation(**args)
        rules = [r.rule_id for r in results]
        assert "R4" in rules

    def test_r5_fires_when_estimated_true_in_snapshot_mode(self):
        args = self._base_args()
        args["mode"] = "snapshot"
        args["has_estimated_data"] = True
        results = validate_reconciliation(**args)
        rules = [r.rule_id for r in results]
        assert "R5" in rules

    def test_r5_does_not_fire_in_live_mode(self):
        args = self._base_args()
        args["mode"] = "live"
        args["has_estimated_data"] = True
        results = validate_reconciliation(**args)
        assert all(r.rule_id != "R5" for r in results)


class TestReconciliationResult:
    def test_result_has_required_fields(self):
        args = dict(
            cost_total=1000.00,
            operational_cost=940.00,   # R2: 940+50=990 ≠ 1000
            non_op_subtotal=50.00,
            tagged_cost=800.00,
            untagged_cost=200.00,
            env_sum=1000.00,
            op_services_sum=940.00,
            mode="snapshot",
            r3_tolerance=1.00,
        )
        results = validate_reconciliation(**args)
        r2 = next(r for r in results if r.rule_id == "R2")
        assert hasattr(r2, "rule_id")
        assert hasattr(r2, "expected")
        assert hasattr(r2, "actual")
        assert hasattr(r2, "diff")
        assert hasattr(r2, "tolerance")
        assert hasattr(r2, "message")
```

- [ ] **Step 3.2: Run to confirm all fail**

```bash
pytest tests/unit/test_finops_reporting_contract.py -v
```

Expected: `ImportError` — module doesn't exist yet.

- [ ] **Step 3.3: Create `toolkit/finops/reconciliation.py`**

```python
from __future__ import annotations

from dataclasses import dataclass
from typing import Literal

_NON_OPERATIONAL_PREFIXES = ("Tax", "Credit", "Refund", "AWS Support")


def is_non_operational(service_name: str) -> bool:
    return any(service_name.startswith(p) for p in _NON_OPERATIONAL_PREFIXES)


def classify_non_op(service_name: str) -> str:
    if service_name.startswith("Tax"):
        return "Tax"
    if service_name.startswith("Credit"):
        return "Credit"
    if service_name.startswith("Refund"):
        return "Refund"
    if service_name.startswith("AWS Support"):
        return "Support"
    return "Other"


def compute_operational_cost(cost_total: float, non_op_items: list[dict]) -> float:
    """cost_total minus non-operational costs (Tax, Credits, Refunds)."""
    non_op_total = sum(item["amount_usd"] for item in non_op_items)
    return cost_total - non_op_total


@dataclass
class ReconciliationResult:
    rule_id: str
    expected: float
    actual: float
    diff: float
    tolerance: float
    message: str
    severity: Literal["warning", "data_quality"] = "warning"


def validate_reconciliation(
    cost_total: float,
    operational_cost: float,
    non_op_subtotal: float,
    tagged_cost: float,
    untagged_cost: float,
    env_sum: float,
    op_services_sum: float,
    mode: str = "snapshot",
    r3_tolerance: float = 1.00,
    has_estimated_data: bool = False,
) -> list[ReconciliationResult]:
    """
    Returns list of ReconciliationResult for each violated rule.
    Empty list = all rules pass.

    R1: cost_total == tagged + untagged
    R2: cost_total == operational_cost + non_op_subtotal  (twardy accounting identity)
    R3: sum(environments) == cost_total                   (tolerance configurable per project)
    R4: sum(services) == operational_cost
    R5: no estimated data in snapshot mode
    """
    results: list[ReconciliationResult] = []

    checks = [
        ("R1", cost_total, tagged_cost + untagged_cost, 0.01),
        ("R2", cost_total, operational_cost + non_op_subtotal, 0.01),
        ("R3", cost_total, env_sum, r3_tolerance),
        ("R4", operational_cost, op_services_sum, 0.01),
    ]

    for rule_id, expected, actual, tolerance in checks:
        diff = abs(expected - actual)
        if diff > tolerance:
            results.append(ReconciliationResult(
                rule_id=rule_id,
                expected=round(expected, 4),
                actual=round(actual, 4),
                diff=round(diff, 4),
                tolerance=tolerance,
                message=(
                    f"{rule_id} naruszony: oczekiwano {expected:.2f} USD, "
                    f"otrzymano {actual:.2f} USD (różnica {diff:.4f} > tolerancja {tolerance})"
                ),
                severity="warning",
            ))

    # R5: estimated data must not appear in snapshot mode
    if mode == "snapshot" and has_estimated_data:
        results.append(ReconciliationResult(
            rule_id="R5",
            expected=0,
            actual=1,
            diff=1,
            tolerance=0,
            message=(
                "R5 naruszony: Cost Explorer zwrócił estimated=true mimo trybu snapshot. "
                "Dane mogą zawierać częściowe szacunki. "
                "Rozważ zwiększenie billing_lag_days."
            ),
            severity="data_quality",
        ))

    return results
```

- [ ] **Step 3.4: Run tests to confirm they pass**

```bash
pytest tests/unit/test_finops_reporting_contract.py -v
```

Expected: all tests `PASSED`.

- [ ] **Step 3.5: Commit**

```bash
git add toolkit/finops/reconciliation.py tests/unit/test_finops_reporting_contract.py
git commit -m "feat(finops): add reconciliation module with R1-R5 rules"
```

---

## Task 4: Wire reconciliation into normalize.py

**Files:**
- Modify: `toolkit/finops/normalize.py`
- Create: `tests/unit/test_finops_normalize_contract.py`

- [ ] **Step 4.1: Write failing tests**

Create `tests/unit/test_finops_normalize_contract.py`:

```python
import sys
from pathlib import Path
from datetime import date

import pytest

TOOLKIT_ROOT = Path(__file__).parent.parent.parent
sys.path.insert(0, str(TOOLKIT_ROOT))

from toolkit.finops.normalize import build_finops_model
from toolkit.finops.periods import ReportingPeriod


def _make_period(mode: str = "snapshot") -> ReportingPeriod:
    s, e = date(2025, 4, 1), date(2025, 4, 28)
    return ReportingPeriod(
        label="mtd", start=s, end=e, prev_start=s, prev_end=e,
        mode=mode, billing_lag_applied=2 if mode == "snapshot" else 0,
        settled_days=27,
    )


def _make_raw(estimated: bool = False) -> dict:
    """Minimal raw CE dict that build_finops_model() will accept."""
    return {
        "estimated": estimated,
        "cost_total": {"amount": "1000.00", "unit": "USD"},
        "prev_cost_total": {"amount": "900.00", "unit": "USD"},
        "cost_by_environment": [
            {"name": "prod", "amount": "700.00"},
            {"name": "staging", "amount": "250.00"},
            {"name": "untagged", "amount": "50.00"},
        ],
        "cost_by_service": [
            {"name": "Amazon EC2", "amount": "600.00"},
            {"name": "Amazon S3", "amount": "300.00"},
            {"name": "Tax", "amount": "80.00"},
            {"name": "Credit", "amount": "-30.00"},
        ],
        "prev_cost_by_service": [],
        "cost_by_usage_type": [],
        "prev_cost_by_usage_type": [],
        "untagged_cost_by_usage_type": [],
        "untagged_cost_by_service": [],
        "service_by_env": [],
        "tagging_coverage": {
            "tagged_count": 8,
            "untagged_count": 2,
            "tagged_cost": "950.00",
            "untagged_cost": "50.00",
        },
    }


class TestNormalizedModelContract:
    def test_operational_cost_present_in_model(self):
        model = build_finops_model(_make_raw(), env_filter=None)
        assert "operational_cost" in model

    def test_operational_cost_excludes_tax_and_credit(self):
        # Tax=80, Credit=-30 → non_op_subtotal=50 → operational = 1000-50 = 950
        model = build_finops_model(_make_raw(), env_filter=None)
        assert abs(model["operational_cost"]["value_usd"] - 950.00) < 0.01

    def test_non_operational_costs_present(self):
        model = build_finops_model(_make_raw(), env_filter=None)
        assert "non_operational_costs" in model
        types = [i["type"] for i in model["non_operational_costs"]["items"]]
        assert "Tax" in types
        assert "Credit" in types

    def test_reconciliation_results_present(self):
        model = build_finops_model(_make_raw(), env_filter=None)
        assert "reconciliation_results" in model

    def test_reconciliation_passes_when_data_is_consistent(self):
        model = build_finops_model(_make_raw(), env_filter=None)
        # With the raw data above, R1/R2/R3/R4 should all pass
        assert model["reconciliation_results"] == []

    def test_data_quality_warnings_present(self):
        model = build_finops_model(_make_raw(), env_filter=None)
        assert "data_quality_warnings" in model

    def test_data_quality_warning_when_estimated_in_snapshot(self):
        raw = _make_raw(estimated=True)
        model = build_finops_model(raw, env_filter=None, mode="snapshot")
        # R5 should appear in reconciliation_results
        rule_ids = [r["rule_id"] for r in model["reconciliation_results"]]
        assert "R5" in rule_ids

    def test_no_r5_warning_in_live_mode(self):
        raw = _make_raw(estimated=True)
        model = build_finops_model(raw, env_filter=None, mode="live")
        rule_ids = [r.get("rule_id") for r in model["reconciliation_results"]]
        assert "R5" not in rule_ids

    def test_r3_tolerance_configurable(self):
        raw = _make_raw()
        # Make env_sum off by 3.00 — should fail R3 with default tolerance=1.00
        raw["cost_by_environment"][-1]["amount"] = "53.00"  # env_sum = 1003
        model_default = build_finops_model(raw, env_filter=None)
        rule_ids_default = [r["rule_id"] for r in model_default["reconciliation_results"]]
        assert "R3" in rule_ids_default

        # With tolerance=5.00 it should pass
        model_wide = build_finops_model(raw, env_filter=None, r3_tolerance=5.00)
        rule_ids_wide = [r["rule_id"] for r in model_wide["reconciliation_results"]]
        assert "R3" not in rule_ids_wide
```

- [ ] **Step 4.2: Run to confirm failure**

```bash
pytest tests/unit/test_finops_normalize_contract.py -v
```

Expected: `FAILED` — `build_finops_model()` doesn't accept `mode` kwarg and `operational_cost` key missing.

- [ ] **Step 4.3: Update `build_finops_model()` signature in normalize.py**

Find `build_finops_model()` in `toolkit/finops/normalize.py`. Add new parameters:

```python
def build_finops_model(
    raw: dict,
    env_filter: str | None = None,
    forecast_raw: dict | None = None,
    mode: str = "snapshot",            # NEW
    r3_tolerance: float = 1.00,        # NEW
) -> dict:
```

- [ ] **Step 4.4: Add non-operational cost extraction to build_finops_model()**

Inside `build_finops_model()`, after the existing `normalize_cost_by_service()` call that already separates operational/non-operational services, add code to build the `non_operational_costs` structure for the contract.

Find where `normalize_cost_by_service()` is called. Below it (or replacing any existing non-op handling), add:

```python
    from toolkit.finops.reconciliation import (
        is_non_operational, classify_non_op,
        compute_operational_cost, validate_reconciliation,
    )

    # Build non_operational_costs from the raw service list
    non_op_items = [
        {
            "type": classify_non_op(svc["name"]),
            "amount_usd": float(svc["amount"]),
        }
        for svc in raw.get("cost_by_service", [])
        if is_non_operational(svc["name"])
    ]
    non_op_subtotal = sum(i["amount_usd"] for i in non_op_items)

    cost_total_value = float(raw["cost_total"]["amount"])
    operational_cost_value = compute_operational_cost(cost_total_value, non_op_items)
```

- [ ] **Step 4.5: Add operational_cost, non_operational_costs, reconciliation to the returned model**

Find where `build_finops_model()` builds and returns its model dict. Add the new keys:

```python
    # --- existing keys kept as-is ---

    model["operational_cost"] = {
        "value_usd": round(operational_cost_value, 4),
        "note": "cost_total minus Tax/Credit/Refund. Używane do rankingów serwisów.",
    }

    model["non_operational_costs"] = {
        "items": non_op_items,
        "subtotal_usd": round(non_op_subtotal, 4),
        "note": "Wliczone do cost_total. Wykluczone z operational_cost i rankingów serwisów.",
    }

    # Pull values needed for reconciliation from already-normalized data
    tagged_cost = float(model.get("tagging_cost_coverage", {}).get("tagged_cost_usd", 0))
    untagged_cost = float(model.get("tagging_cost_coverage", {}).get("untagged_cost_usd", 0))
    env_sum = sum(
        float(e.get("cost_usd", 0))
        for e in model.get("cost_by_environment", {}).get("environments", [])
    )
    op_services_sum = sum(
        float(s.get("cost_usd", 0))
        for s in model.get("cost_by_service", {}).get("services", [])
    )
    is_estimated = raw.get("estimated", False)

    recon_results = validate_reconciliation(
        cost_total=cost_total_value,
        operational_cost=operational_cost_value,
        non_op_subtotal=non_op_subtotal,
        tagged_cost=tagged_cost,
        untagged_cost=untagged_cost,
        env_sum=env_sum,
        op_services_sum=op_services_sum,
        mode=mode,
        r3_tolerance=r3_tolerance,
        has_estimated_data=is_estimated,
    )

    model["reconciliation_results"] = [
        {
            "rule_id": r.rule_id,
            "expected": r.expected,
            "actual": r.actual,
            "diff": r.diff,
            "tolerance": r.tolerance,
            "message": r.message,
            "severity": r.severity,
        }
        for r in recon_results
    ]

    data_quality_warnings = [
        r.message for r in recon_results if r.severity == "data_quality"
    ]
    model["data_quality_warnings"] = data_quality_warnings
```

- [ ] **Step 4.6: Run new tests**

```bash
pytest tests/unit/test_finops_normalize_contract.py -v
```

Expected: all tests `PASSED`. Fix any field name mismatches between the test's `_make_raw()` structure and what `build_finops_model()` actually reads — adjust `_make_raw()` to match the real raw dict keys if needed.

- [ ] **Step 4.7: Run full normalize test suite to confirm no regressions**

```bash
pytest tests/unit/test_finops_normalize_model.py tests/unit/test_finops_scope_logic.py -v
```

Expected: all existing tests still `PASSED`.

- [ ] **Step 4.8: Commit**

```bash
git add toolkit/finops/normalize.py tests/unit/test_finops_normalize_contract.py
git commit -m "feat(finops): wire operational_cost and reconciliation R1-R5 into build_finops_model"
```

---

## Task 5: Surface warnings in report_model.py

**Files:**
- Modify: `toolkit/finops/report_model.py`

Both `build_executive_report_model()` and `build_technical_report_model()` receive the `normalized` dict. We need to add:
1. `data_quality_warnings` section in **both** modes (shown as a prominent callout when non-empty)
2. `reconciliation_results` section in **technical** mode only

- [ ] **Step 5.1: Write failing tests**

Append to `tests/unit/test_finops_report.py`:

```python
class TestReportModelContract:
    def _normalized_with_r5(self):
        """Normalized model that has a data quality warning (R5)."""
        base = _minimal_normalized()   # use existing helper in that test file
        base["data_quality_warnings"] = [
            "R5 naruszony: Cost Explorer zwrócił estimated=true mimo trybu snapshot."
        ]
        base["reconciliation_results"] = [
            {
                "rule_id": "R5",
                "expected": 0,
                "actual": 1,
                "diff": 1,
                "tolerance": 0,
                "message": "R5 naruszony: Cost Explorer zwrócił estimated=true mimo trybu snapshot.",
                "severity": "data_quality",
            }
        ]
        base["operational_cost"] = {"value_usd": 950.00, "note": "derived"}
        base["non_operational_costs"] = {
            "items": [{"type": "Tax", "amount_usd": 50.00}],
            "subtotal_usd": 50.00,
            "note": "wliczone do cost_total",
        }
        return base

    def _normalized_clean(self):
        base = _minimal_normalized()
        base["data_quality_warnings"] = []
        base["reconciliation_results"] = []
        base["operational_cost"] = {"value_usd": 950.00, "note": "derived"}
        base["non_operational_costs"] = {
            "items": [{"type": "Tax", "amount_usd": 50.00}],
            "subtotal_usd": 50.00,
            "note": "wliczone do cost_total",
        }
        return base

    def test_executive_report_has_data_quality_section_when_warnings_present(self):
        from toolkit.finops.report_model import build_executive_report_model
        model = build_executive_report_model(
            project="test", period_label="MTD", normalized=self._normalized_with_r5(),
            audit_findings=[], allocation_config=None,
        )
        all_text = " ".join(
            s.get("text", "") + " ".join(str(v) for v in s.get("items", []))
            for s in model["sections"]
        )
        assert "estimated" in all_text.lower() or "data" in all_text.lower()

    def test_executive_report_no_data_quality_section_when_clean(self):
        from toolkit.finops.report_model import build_executive_report_model
        model = build_executive_report_model(
            project="test", period_label="MTD", normalized=self._normalized_clean(),
            audit_findings=[], allocation_config=None,
        )
        section_texts = [s.get("text", "") for s in model["sections"]]
        assert not any("data_quality" in t.lower() for t in section_texts)

    def test_technical_report_has_reconciliation_section(self):
        from toolkit.finops.report_model import build_technical_report_model
        model = build_technical_report_model(
            project="test", period_label="MTD", normalized=self._normalized_with_r5(),
            audit_findings=[], run_id="run-001",
        )
        section_texts = [s.get("text", "") for s in model["sections"]]
        assert any("reconcil" in t.lower() or "R5" in t for t in section_texts)

    def test_executive_report_does_not_have_reconciliation_section(self):
        from toolkit.finops.report_model import build_executive_report_model
        model = build_executive_report_model(
            project="test", period_label="MTD", normalized=self._normalized_with_r5(),
            audit_findings=[], allocation_config=None,
        )
        section_texts = [s.get("text", "") for s in model["sections"]]
        # Executive mode: no raw reconciliation table
        assert not any("R1" in t or "R2" in t or "R4" in t for t in section_texts)
```

- [ ] **Step 5.2: Run to confirm failure**

```bash
pytest tests/unit/test_finops_report.py::TestReportModelContract -v
```

Expected: `FAILED` — sections missing.

- [ ] **Step 5.3: Add `_build_data_quality_section()` helper to report_model.py**

In `toolkit/finops/report_model.py`, add this private helper function near the other `_build_*` helpers:

```python
def _build_data_quality_section(data_quality_warnings: list[str]) -> list[dict]:
    """Returns sections to prepend when data quality issues exist. Empty list if clean."""
    if not data_quality_warnings:
        return []
    items = [f"⚠ {w}" for w in data_quality_warnings]
    return [
        {"type": "heading", "level": 2, "text": "Ostrzeżenia jakości danych"},
        {
            "type": "bullet_list",
            "items": items,
        },
    ]
```

- [ ] **Step 5.4: Add `_build_reconciliation_section()` helper**

```python
def _build_reconciliation_section(reconciliation_results: list[dict]) -> list[dict]:
    """Technical mode only. Returns reconciliation table when violations exist."""
    if not reconciliation_results:
        return [
            {"type": "heading", "level": 2, "text": "Reconciliation"},
            {"type": "paragraph", "text": "✓ Wszystkie reguły R1–R5 spełnione."},
        ]
    rows = [
        [r["rule_id"], r["message"], f"{r['diff']:.4f}", f"{r['tolerance']}"]
        for r in reconciliation_results
    ]
    return [
        {"type": "heading", "level": 2, "text": "Reconciliation — naruszenia"},
        {
            "type": "table",
            "headers": ["Reguła", "Komunikat", "Różnica", "Tolerancja"],
            "rows": rows,
        },
    ]
```

- [ ] **Step 5.5: Wire helpers into both report builders**

In `build_executive_report_model()`, find where sections are assembled. Prepend the data quality section **after** the title/scope section but **before** the main summary:

```python
    sections = []
    sections += _build_title_sections(...)       # existing
    sections += _build_data_quality_section(     # NEW — after title
        normalized.get("data_quality_warnings", [])
    )
    sections += _build_summary_section(...)      # existing continues
    # ... rest unchanged
```

In `build_technical_report_model()`, add both sections. Prepend data quality after title, then append reconciliation near the end (before caveats/footer):

```python
    sections = []
    sections += _build_title_sections(...)
    sections += _build_data_quality_section(
        normalized.get("data_quality_warnings", [])
    )
    # ... existing sections ...
    sections += _build_reconciliation_section(
        normalized.get("reconciliation_results", [])
    )
    # caveats / footer
```

- [ ] **Step 5.6: Run tests**

```bash
pytest tests/unit/test_finops_report.py::TestReportModelContract -v
```

Expected: all `PASSED`.

- [ ] **Step 5.7: Run full report model tests**

```bash
pytest tests/unit/test_finops_report.py tests/unit/test_finops_renderers.py -v
```

Expected: all existing tests still `PASSED`.

- [ ] **Step 5.8: Commit**

```bash
git add toolkit/finops/report_model.py tests/unit/test_finops_report.py
git commit -m "feat(finops): add data_quality and reconciliation sections to report model"
```

---

## Task 6: Update config/finops.yaml

**Files:**
- Modify: `config/finops.yaml`

- [ ] **Step 6.1: Add reporting section**

Open `config/finops.yaml`. Current content:

```yaml
# FinOps configuration
cost_thresholds:
  monthly_alert_usd: 10000
  idle_resource_min_days: 7
currency: USD
```

Replace with:

```yaml
# FinOps configuration
cost_thresholds:
  monthly_alert_usd: 10000
  idle_resource_min_days: 7
currency: USD

reporting:
  mode: snapshot                # snapshot | live  (default: snapshot)
  billing_lag_days: 2           # default: 2 — configurable per project via CLI flag
  reconciliation:
    r3_tolerance_usd: 1.00      # default: 1.00 — configurable per project
```

- [ ] **Step 6.2: Commit**

```bash
git add config/finops.yaml
git commit -m "config(finops): add reporting.mode, billing_lag_days, r3_tolerance defaults"
```

---

## Task 7: Update commands/finops_report.py — CLI flags, snapshot names, exit codes

**Files:**
- Modify: `toolkit/commands/finops_report.py`
- Modify: `tests/unit/test_finops_report_cli_path.py`

- [ ] **Step 7.1: Write failing tests**

Append to `tests/unit/test_finops_report_cli_path.py`:

```python
class TestSnapshotNaming:
    def test_snapshot_filename_includes_mode_lag_end_date(self):
        from toolkit.commands.finops_report import build_snapshot_filename
        from toolkit.finops.periods import ReportingPeriod
        from datetime import date
        p = ReportingPeriod(
            label="mtd",
            start=date(2025, 4, 1),
            end=date(2025, 4, 28),
            prev_start=date(2025, 3, 1),
            prev_end=date(2025, 4, 1),
            mode="snapshot",
            billing_lag_applied=2,
            settled_days=27,
        )
        name = build_snapshot_filename(report_type="mtd", period=p)
        assert "snapshot" in name
        assert "lag2d" in name
        assert "2025-04-28" in name

    def test_snapshot_filename_different_lag(self):
        from toolkit.commands.finops_report import build_snapshot_filename
        from toolkit.finops.periods import ReportingPeriod
        from datetime import date
        p = ReportingPeriod(
            label="mtd",
            start=date(2025, 4, 1),
            end=date(2025, 4, 27),
            prev_start=date(2025, 3, 1),
            prev_end=date(2025, 4, 1),
            mode="snapshot",
            billing_lag_applied=3,
            settled_days=26,
        )
        name = build_snapshot_filename(report_type="mtd", period=p)
        assert "lag3d" in name
        assert "2025-04-27" in name


class TestCIExitCodes:
    def test_exit_code_0_when_clean(self):
        from toolkit.commands.finops_report import compute_exit_code
        assert compute_exit_code(
            has_data_quality_warning=False,
            has_reconciliation_failure=False,
            has_drift_alert=False,
        ) == 0

    def test_exit_code_1_for_data_quality(self):
        from toolkit.commands.finops_report import compute_exit_code
        assert compute_exit_code(
            has_data_quality_warning=True,
            has_reconciliation_failure=False,
            has_drift_alert=False,
        ) == 1

    def test_exit_code_2_for_reconciliation(self):
        from toolkit.commands.finops_report import compute_exit_code
        assert compute_exit_code(
            has_data_quality_warning=False,
            has_reconciliation_failure=True,
            has_drift_alert=False,
        ) == 2

    def test_exit_code_3_for_drift(self):
        from toolkit.commands.finops_report import compute_exit_code
        assert compute_exit_code(
            has_data_quality_warning=False,
            has_reconciliation_failure=False,
            has_drift_alert=True,
        ) == 3

    def test_drift_takes_priority_over_reconciliation(self):
        from toolkit.commands.finops_report import compute_exit_code
        assert compute_exit_code(
            has_data_quality_warning=True,
            has_reconciliation_failure=True,
            has_drift_alert=True,
        ) == 3
```

- [ ] **Step 7.2: Run to confirm failure**

```bash
pytest tests/unit/test_finops_report_cli_path.py::TestSnapshotNaming tests/unit/test_finops_report_cli_path.py::TestCIExitCodes -v
```

Expected: `ImportError` — `build_snapshot_filename` and `compute_exit_code` don't exist.

- [ ] **Step 7.3: Add helper functions to commands/finops_report.py**

In `toolkit/commands/finops_report.py`, add these two functions near the top (after imports):

```python
def build_snapshot_filename(report_type: str, period) -> str:
    """Immutable snapshot filename encoding mode, lag, and end date."""
    end_str = period.end.isoformat()
    lag = period.billing_lag_applied
    return f"{report_type}_{period.mode}_lag{lag}d_{end_str}"


def compute_exit_code(
    has_data_quality_warning: bool,
    has_reconciliation_failure: bool,
    has_drift_alert: bool,
) -> int:
    """
    CI exit codes:
    0 = OK
    1 = data quality warning (estimated data in snapshot)
    2 = reconciliation failure (R1-R4 out of tolerance)
    3 = drift alert (cost change above threshold)
    Higher severity takes priority.
    """
    if has_drift_alert:
        return 3
    if has_reconciliation_failure:
        return 2
    if has_data_quality_warning:
        return 1
    return 0
```

- [ ] **Step 7.4: Add --mode and --billing-lag-days CLI arguments**

Find the argument parser setup in `run()` or wherever `argparse` is configured. Add:

```python
    parser.add_argument(
        "--mode",
        choices=["snapshot", "live"],
        default=None,          # None = read from config/finops.yaml
        help="Reporting mode: snapshot (deterministic) or live (real-time). Default: snapshot.",
    )
    parser.add_argument(
        "--billing-lag-days",
        type=int,
        default=None,          # None = read from config/finops.yaml
        dest="billing_lag_days",
        help="Days to subtract from today for snapshot end date. Default: 2.",
    )
    parser.add_argument(
        "--r3-tolerance",
        type=float,
        default=None,          # None = read from config/finops.yaml
        dest="r3_tolerance",
        help="USD tolerance for R3 (environment sum == cost_total). Default: 1.00.",
    )
```

- [ ] **Step 7.5: Read config values and resolve with CLI overrides**

Find where the config is loaded (likely `config/finops.yaml` read via `_load_config()` or similar). After loading, resolve mode/lag with CLI override:

```python
    finops_cfg = config.get("reporting", {})
    mode = args.mode or finops_cfg.get("mode", "snapshot")
    billing_lag_days = (
        args.billing_lag_days
        if args.billing_lag_days is not None
        else finops_cfg.get("billing_lag_days", 2)
    )
    r3_tolerance = (
        args.r3_tolerance
        if args.r3_tolerance is not None
        else finops_cfg.get("reconciliation", {}).get("r3_tolerance_usd", 1.00)
    )
```

- [ ] **Step 7.6: Pass mode and lag into resolve_period() call**

Find where `resolve_period()` is called in `run()`. Update the call:

```python
    period = resolve_period(
        period=args.period,
        start=getattr(args, "start", None),
        end=getattr(args, "end", None),
        mode=mode,
        billing_lag_days=billing_lag_days,
    )
```

- [ ] **Step 7.7: Pass mode and r3_tolerance into build_finops_model() call**

Find where `build_finops_model()` is called. Update:

```python
    normalized = build_finops_model(
        raw,
        env_filter=env_filter,
        forecast_raw=forecast_raw,
        mode=mode,
        r3_tolerance=r3_tolerance,
    )
```

- [ ] **Step 7.8: Update snapshot filename and make it immutable**

Find where the report file is written. Replace the current filename construction with:

```python
    snap_name = build_snapshot_filename(report_type=args.period, period=period)
    report_dir = project_root / ".devops-toolkit" / "reports" / "finops" / period.start.strftime("%Y-%m")
    report_dir.mkdir(parents=True, exist_ok=True)

    json_path = report_dir / f"{snap_name}.json"
    if json_path.exists() and mode == "snapshot":
        # Snapshots are immutable — do not overwrite
        print(f"[INFO] Snapshot already exists: {json_path}. Skipping write.")
    else:
        json_path.write_text(json.dumps(report_json, indent=2, default=str))

    # latest symlink (always updated)
    latest_json = report_dir.parent / "latest.json"
    if latest_json.is_symlink():
        latest_json.unlink()
    latest_json.symlink_to(json_path)
```

- [ ] **Step 7.9: Wire exit codes into run() return value**

Find the end of `run()`. Replace any `return` or `sys.exit(0)` with:

```python
    has_data_quality = bool(normalized.get("data_quality_warnings"))
    has_recon_failure = any(
        r["severity"] == "warning"
        for r in normalized.get("reconciliation_results", [])
    )
    # Basic drift detection: compare cost_total vs previous snapshot if available
    has_drift = False
    previous_snap = _load_previous_snapshot(report_dir)
    if previous_snap:
        prev_total = float(previous_snap.get("cost_total", {}).get("value_usd", 0))
        curr_total = float(normalized.get("cost_total", {}).get("value_usd", 0))
        if prev_total > 0:
            drift_pct = abs(curr_total - prev_total) / prev_total * 100
            drift_abs = abs(curr_total - prev_total)
            if drift_pct > 20 or drift_abs > 500:
                has_drift = True
                print(f"[DRIFT] Cost changed {drift_pct:.1f}% (${drift_abs:.2f}) vs previous snapshot.")

    return compute_exit_code(has_data_quality, has_recon_failure, has_drift)
```

Add the helper at module level:

```python
def _load_previous_snapshot(report_dir: Path) -> dict | None:
    """Load the most recent snapshot JSON from the same month directory, if any."""
    import json as _json
    snapshots = sorted(report_dir.glob("*_snapshot_*.json"))
    if len(snapshots) < 2:
        return None
    try:
        return _json.loads(snapshots[-2].read_text())
    except Exception:
        return None
```

- [ ] **Step 7.10: Ensure CLI entry point returns exit code**

Find the `main()` or `__main__` block that calls `run()`. Ensure it passes the return value to `sys.exit()`:

```python
if __name__ == "__main__":
    import sys
    sys.exit(run(sys.argv[1:]))
```

Also verify the toolkit command router forwards the return value.

- [ ] **Step 7.11: Run new tests**

```bash
pytest tests/unit/test_finops_report_cli_path.py::TestSnapshotNaming tests/unit/test_finops_report_cli_path.py::TestCIExitCodes -v
```

Expected: all `PASSED`.

- [ ] **Step 7.12: Run full CLI test suite**

```bash
pytest tests/unit/test_finops_report_cli_path.py -v
```

Expected: all existing tests still `PASSED`.

- [ ] **Step 7.13: Commit**

```bash
git add toolkit/commands/finops_report.py tests/unit/test_finops_report_cli_path.py
git commit -m "feat(finops): add --mode/--billing-lag-days flags, immutable snapshots, CI exit codes"
```

---

## Task 8: Full integration test and smoke test

**Files:**
- Modify: `tests/test_finops_reports.py`

- [ ] **Step 8.1: Add integration test for snapshot mode end-to-end**

Append to `tests/test_finops_reports.py`:

```python
class TestSnapshotModeIntegration:
    """End-to-end: snapshot period → collect (mocked) → normalize → report model."""

    def _mock_ce_response(self) -> dict:
        return {
            "ResultsByTime": [{
                "TimePeriod": {"Start": "2025-04-01", "End": "2025-04-28"},
                "Total": {"UnblendedCost": {"Amount": "1000.00", "Unit": "USD"}},
                "Groups": [],
                "Estimated": False,
            }]
        }

    def test_snapshot_report_is_deterministic(self):
        """Running normalize twice on same raw data produces identical cost_total."""
        from toolkit.finops.normalize import build_finops_model
        raw = {
            "estimated": False,
            "cost_total": {"amount": "1000.00", "unit": "USD"},
            "prev_cost_total": {"amount": "900.00", "unit": "USD"},
            "cost_by_environment": [
                {"name": "prod", "amount": "950.00"},
                {"name": "untagged", "amount": "50.00"},
            ],
            "cost_by_service": [
                {"name": "Amazon EC2", "amount": "900.00"},
                {"name": "Tax", "amount": "50.00"},
                {"name": "Amazon S3", "amount": "50.00"},
            ],
            "prev_cost_by_service": [],
            "cost_by_usage_type": [],
            "prev_cost_by_usage_type": [],
            "untagged_cost_by_usage_type": [],
            "untagged_cost_by_service": [],
            "service_by_env": [],
            "tagging_coverage": {
                "tagged_count": 9, "untagged_count": 1,
                "tagged_cost": "950.00", "untagged_cost": "50.00",
            },
        }
        model_a = build_finops_model(raw, env_filter=None, mode="snapshot")
        model_b = build_finops_model(raw, env_filter=None, mode="snapshot")

        assert model_a["cost_total"]["value_usd"] == model_b["cost_total"]["value_usd"]
        assert model_a["operational_cost"]["value_usd"] == model_b["operational_cost"]["value_usd"]
        assert model_a["reconciliation_results"] == model_b["reconciliation_results"]

    def test_snapshot_with_estimated_true_triggers_r5(self):
        from toolkit.finops.normalize import build_finops_model
        raw = {
            "estimated": True,   # CE says data is estimated
            "cost_total": {"amount": "1000.00", "unit": "USD"},
            "prev_cost_total": {"amount": "900.00", "unit": "USD"},
            "cost_by_environment": [{"name": "prod", "amount": "1000.00"}],
            "cost_by_service": [
                {"name": "Amazon EC2", "amount": "950.00"},
                {"name": "Tax", "amount": "50.00"},
            ],
            "prev_cost_by_service": [],
            "cost_by_usage_type": [],
            "prev_cost_by_usage_type": [],
            "untagged_cost_by_usage_type": [],
            "untagged_cost_by_service": [],
            "service_by_env": [],
            "tagging_coverage": {
                "tagged_count": 10, "untagged_count": 0,
                "tagged_cost": "1000.00", "untagged_cost": "0.00",
            },
        }
        model = build_finops_model(raw, env_filter=None, mode="snapshot")
        rule_ids = [r["rule_id"] for r in model["reconciliation_results"]]
        assert "R5" in rule_ids
        assert len(model["data_quality_warnings"]) > 0
```

- [ ] **Step 8.2: Run integration tests**

```bash
pytest tests/test_finops_reports.py::TestSnapshotModeIntegration -v
```

Expected: both tests `PASSED`.

- [ ] **Step 8.3: Run complete test suite**

```bash
pytest tests/ -v --tb=short 2>&1 | tail -40
```

Expected: all tests `PASSED`. Fix any remaining failures — they will typically be key name mismatches between the existing normalized model structure and the new keys.

- [ ] **Step 8.4: Final commit**

```bash
git add tests/test_finops_reports.py
git commit -m "test(finops): add integration tests for snapshot mode and R5 detection"
```

---

## Self-Review Checklist

### Spec Coverage

| Spec Section | Task |
|---|---|
| 2. Time Window Semantics — snapshot/live modes, EMPTY_WINDOW | Task 1 |
| 2. Time Window Semantics — last-full-month always full | Task 1 |
| 3. Config — mode, billing_lag_days, r3_tolerance (per project) | Task 6, Task 7 |
| 4. Data Contract — cost_total = CE UnblendedCost | Task 4 (normalize) |
| 4. Data Contract — operational_cost as derived metric | Task 3, Task 4 |
| 4. Data Contract — non_operational_costs separate section | Task 3, Task 4 |
| 4. Data Contract — data_quality.has_estimated_data | Task 2, Task 4 |
| 5. Reconciliation R1–R4 | Task 3 |
| 5. Reconciliation R5 (no estimated in snapshot) | Task 3 |
| 5. R3 tolerance configurable per project | Task 3, Task 7 |
| 6. Tagging Contract edge cases | ⚠ Partially covered — tag_in_iac_not_runtime and tag_in_runtime_not_CE are handled by existing `normalize_tagging_cost_coverage()`. No new code needed unless existing behavior diverges from spec. Verify manually. |
| 7. Report Modes — data_quality_warnings in both | Task 5 |
| 7. Report Modes — reconciliation_results in technical only | Task 5 |
| 8. CI — snapshot versioning (immutable filenames) | Task 7 |
| 8. CI — drift detection (basic 20%/$500) | Task 7 |
| 8. CI — exit codes 0–3 | Task 7 |
| 9. Edge Cases — EMPTY_WINDOW | Task 1 |
| 9. Edge Cases — estimated=true in snapshot | Task 2, Task 3, Task 8 |
| 9. Edge Cases — Tax > 15% warning | ⚠ Not yet implemented — add as follow-up or add to Task 4 manually |

### Tagging edge cases note

The spec requires:
- `tag_in_runtime_not_cost_explorer` → `classify_as: tagged` + `data_quality_warning`

This is already partially handled by `normalize_tagging_cost_coverage()` with scope-aware logic. Verify that the existing implementation covers this — if it doesn't emit a `data_quality_warning`, add it to Task 4.

### Tax > 15% edge case

Add to `build_finops_model()` in Task 4, Step 4.5, after computing `non_op_subtotal`:

```python
    if cost_total_value > 0:
        tax_pct = (non_op_subtotal / cost_total_value) * 100
        if tax_pct > 15:
            # This is unusual — Tax/Credits exceeding 15% of total is anomalous
            data_quality_warnings_extra = [
                f"Koszty nieoperacyjne (Tax/Credit/Refund) stanowią {tax_pct:.1f}% "
                f"cost_total ({non_op_subtotal:.2f} USD). Wartość powyżej 15% jest nienormalna — "
                f"sprawdź czy nie ma anomalii rozliczeniowej."
            ]
```

Then add `data_quality_warnings_extra` to the `data_quality_warnings` list before returning.
