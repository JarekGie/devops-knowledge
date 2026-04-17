# Pomysły na oszczędności

Backlog optymalizacji kosztów. Do weryfikacji i wdrożenia.

#finops #savings

## Format

```
- [ ] Opis — szacowane oszczędności — konto/klient — trudność [low/med/high]
```

---

## Natychmiastowe / łatwe

- [ ] Usuń nieużywane Elastic IPs — ~$3.65/miesiąc za EIP
- [ ] Usuń stare EBS snapshots (>90 dni) — zależy od wolumenu
- [ ] NAT Gateway bez ruchu — sprawdź i usuń
- [ ] Load balancery bez targetów — sprawdź i usuń

## Rightsizing

- [ ] EC2 — sprawdź Compute Optimizer recommendations
- [ ] RDS — sprawdź DatabaseConnections metrykę (0 połączeń = candidate do wyłączenia)
- [ ] ECS tasks — memory utilization < 30% → zmniejsz task size

## Reserved / Savings Plans

- [ ] Sprawdź Coverage Report w Cost Explorer
- [ ] Compute Savings Plans 1-rok dla stabilnych workloadów

## Architektoniczne

- [ ] Migracja dev/staging na Spot Instances
- [ ] S3 lifecycle policies — przeniesienie starych obiektów do Glacier
- [ ] CloudFront cache hit ratio — zwiększ TTL gdzie możliwe

## Zweryfikowane (w toku)

<!-- Przenieś tu gdy pracujesz nad optymalizacją -->

---

*Powiązane: [[optimization-log]] | [[finops-review-patterns]]*
