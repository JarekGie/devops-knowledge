# Open Loops

Sprawy w toku, bez zakończenia. Nie todo — rzeczy, które "wiszą" i zajmują RAM.

## Format

```
- [ ] opis — kontekst — kiedy wrócić / co odblokowuje
```

---

## Techniczne

- [ ] rshop DEV — zebrać Jenkins console log dla nocnego failed build; lokalnie nie znaleziono aktualnego logu, AWS potwierdził ECSStack-only rollback
- [ ] rshop DEV — sprawdzić logi aplikacyjne dla nieudanego rollout: API ALB healthcheck HTTP 500 oraz backoffice startup/runtime dla próbowanej rewizji obrazu
- [ ] rshop — utrzymać zakaz root stack app deploy; permanent fix CFN-MUT-001 przez immutable nested `TemplateURL` / release artifact paths

## Biznesowe

- [ ]

## Decyzje do podjęcia

- [ ]

## Do sprawdzenia później

- [ ]

---

*Powiązane: [[waiting-for]] | [[current-focus]]*
