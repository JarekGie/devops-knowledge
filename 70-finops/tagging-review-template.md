# Audyt tagowania — {YYYY-MM} — {klient/konto}

#finops #tagging #audit

**Konto AWS:** ___  
**Region:** ___  
**Data:** ___

---

## Wymagane tagi (wg standardu)

→ [[aws-tagging-standard]]

| Tag | Pokrycie (%) | Uwagi |
|-----|-------------|-------|
| Environment | | |
| Project | | |
| Owner | | |
| ManagedBy | | |
| CostCenter | | |

## Zasoby bez tagów — krytyczne

```bash
# Znajdź zasoby bez tagu Environment
aws resourcegroupstaggingapi get-resources \
  --query 'ResourceTagMappingList[?!contains(Tags[*].Key, `Environment`)].ResourceARN'

# Znajdź zasoby bez tagu Project
aws resourcegroupstaggingapi get-resources \
  --query 'ResourceTagMappingList[?!contains(Tags[*].Key, `Project`)].ResourceARN'
```

## Wyniki

| ARN | Brakujące tagi | Typ zasobu | Właściciel |
|-----|---------------|-----------|-----------|
| | | | |

## Zasoby bez właściciela

<!-- Zasoby niezidentyfikowane — brak tagu Owner lub Project -->

## Koszty bez alokacji

Koszt zasobów bez tagów (niemożliwy do alokacji per projekt):  
**Wartość:** ___

## Rekomendacje

- [ ] Otagować zasoby X, Y, Z — właściciel: ___
- [ ] Uruchomić periodic tagging audit w CI/CD
- [ ] Dodać SCP blokujące tworzenie zasobów bez wymaganych tagów

## Następne kroki

- [ ]

---

*Powiązane: [[aws-tagging-standard]] | [[cost-review-template]] | [[finops-review-patterns]]*
