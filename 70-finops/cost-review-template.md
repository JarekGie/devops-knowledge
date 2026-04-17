# Przegląd kosztów AWS — {YYYY-MM}

#finops #cost-review

**Klient / konto:** ___  
**Okres:** ___  
**Przeprowadził:** Jarek Gołąb  
**Data:** ___

---

## Podsumowanie

| Serwis | Koszt bieżący | Koszt poprzedni | Zmiana |
|--------|--------------|----------------|--------|
| EC2 | | | |
| RDS | | | |
| ECS / Fargate | | | |
| S3 | | | |
| CloudFront | | | |
| Data Transfer | | | |
| Inne | | | |
| **RAZEM** | | | |

## Top 3 — wzrosty kosztów

1.
2.
3.

## Top 3 — spadki / optymalizacje

1.
2.
3.

## Analiza per środowisko

| Środowisko | Koszt | % całości |
|-----------|-------|-----------|
| prod | | |
| staging | | |
| dev | | |

## Analiza per projekt / tag

| Projekt | Koszt | Uwagi |
|---------|-------|-------|
| | | |

## Anomalie

<!-- Koszty niezwiązane z żadnym tagiem, nagłe wzrosty, etc. -->

## Rekomendacje

| Rekomendacja | Szacowane oszczędności | Priorytet | Do |
|-------------|----------------------|-----------|-----|
| | | | |

## Komendy do analizy

```bash
# Koszty per serwis
aws ce get-cost-and-usage \
  --time-period Start=YYYY-MM-01,End=YYYY-MM-01 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE

# Koszty per tag
aws ce get-cost-and-usage \
  --time-period Start=YYYY-MM-01,End=YYYY-MM-01 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=TAG,Key=Project
```

## Następne kroki

- [ ]

---

*Powiązane: [[tagging-review-template]] | [[optimization-log]] | [[finops-review-patterns]]*
