# FinOps Reporting

#toolkit #finops

## Cel

Generowanie raportów kosztów AWS dla klientów i wewnętrznych przeglądów.  
Input: AWS Cost Explorer API. Output: Markdown / CSV gotowy do wysłania.

## Komendy

```bash
# Raport miesięczny per projekt
toolkit finops report --month 2026-03 --group-by Project --output markdown

# Raport per środowisko
toolkit finops report --month 2026-03 --group-by Environment

# Porównanie miesięcy
toolkit finops report --compare 2026-02 2026-03

# Eksport CSV
toolkit finops report --month 2026-03 --output csv > raport-marzec.csv
```

## Format raportu Markdown (wzorzec)

```markdown
# Raport kosztów AWS — Marzec 2026

## Podsumowanie

| Serwis | Koszt | Zmiana vs poprzedni miesiąc |
|--------|-------|----------------------------|
| EC2 | $XXX | +5% |
| RDS | $XXX | -2% |

## Per projekt

| Projekt | Koszt | % całości |
|---------|-------|-----------|

## Rekomendacje

1. [automatycznie generowane z Compute Optimizer]
```

## Integracja z Cost Explorer

```python
# Kluczowe API calls
ce.get_cost_and_usage(
    TimePeriod={'Start': '2026-03-01', 'End': '2026-04-01'},
    Granularity='MONTHLY',
    Metrics=['BlendedCost', 'UsageQuantity'],
    GroupBy=[{'Type': 'TAG', 'Key': 'Project'}]
)
```

## Powiązane

- [[cost-review-template]]
- [[finops-review-patterns]]
- [[contracts-index]]
