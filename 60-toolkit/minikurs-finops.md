# Minikurs FinOps — interpretacja raportu

#toolkit #finops #minikurs

Mirror: `~/projekty/devops/devops-toolkit/docs/course/finops-mini-course.md`
Ostatnia aktualizacja źródła: 2026-04-02

---

## TL;DR — najważniejsze zasady

- **Zakres konta** (domyślny): prod + dev + qa + untagged = total
- **Zakres środowiska** (`--env prod`): tylko prod — NIE porównuj z totalem konta
- `[Obserwowany]` = dane z AWS CE — weryfikowalne w konsoli
- `[Wyliczony]` = deterministyczna formuła z danych obserwowanych
- `[Szacowany]` = heurystyka — NIE używaj do rozliczeń

---

## 1. Co raport zawiera / czego nie zawiera

**Zawiera:**
- Koszt całkowity konta lub środowiska
- Podział per środowisko i per serwis AWS
- Delta vs poprzedni okres
- Pokrycie tagowania (% zasobów z tagiem `Environment`)
- Koszty untagged

**Nie zawiera:**
- Prognoz budżetowych (poza projekcją MTD)
- Danych zewnętrznych
- Kosztów poza AWS CE

---

## 2. Zakres konta vs środowiska

```bash
# Zakres konta — wszystkie środowiska łącznie
toolkit finops-report rshop --period last-full-month

# Zakres środowiska — tylko prod
toolkit finops-report rshop --period last-full-month --env prod
```

**Niezmiennik zakresu konta:**
```
prod + dev + qa + untagged = total konta AWS
```

> Jeśli suma nie zgadza się z totalem → raport wyświetli `BŁĄD SPÓJNOŚCI DANYCH`

**Zakres środowiska:** filtr `Environment=prod` w CE — nie zawiera innych środowisk ani untagged.

---

## 3. Koszty untagged

Zasoby bez tagu `Environment`. Dwa powody:

1. **Brakujące tagi** — naprawialne przez `toolkit apply-pack tagging`
2. **Inherentne koszty AWS** — Data Transfer, NAT Gateway, CloudWatch Logs — zawsze untagged, nawet przy 100% coverage

```bash
toolkit audit-pack tagging rshop
toolkit apply-pack tagging rshop --auto --apply-safe
```

Progi:
- `> 50%` untagged → analiza per-środowisko **niewiarygodna**
- `> 20%` → ostrzeżenie, dane niepełne

---

## 4. Typy wartości

| Typ | Znaczenie | Można używać do rozliczeń? |
|-----|-----------|---------------------------|
| `[Obserwowany]` | Bezpośrednio z AWS CE | ✓ tak |
| `[Wyliczony]` | Formuła z danych CE | ✓ tak |
| `[Szacowany]` | Heurystyka (wagi, projekcje) | ✗ nie |

---

## 5. Weryfikacja w AWS Console

1. Cost Explorer → Reports
2. Daty: `period.start` → `period.end` z raportu
3. Group by: `Tag: Environment`
4. Metric: `Unblended Cost`
5. Porównaj z sekcjami raportu

Jeśli dane się różnią — sprawdź:
```bash
aws ce list-cost-allocation-tags --status Active
# Tag "Environment" musi być aktywowany jako cost allocation tag
```

---

## 6. Typowe błędy interpretacji

| Błąd | Prawda |
|------|--------|
| "prod $405 = cały projekt $405" | Cały projekt = prod + dev + untagged = $1102 |
| "100% tagowania = 0 kosztów untagged" | Transfer/NAT zawsze będzie untagged |
| Porównanie `--env prod` z raportem bez filtra | Różne zakresy — nieporównywalne |
| Używanie `[Szacowany]` do rozliczeń | To heurystyka, nie dane CE |

---

## 7. Ćwiczenia

```bash
# Ćwiczenie 1: Raport całego konta
awsume rshop-prod
toolkit finops-report . --period last-full-month --audience executive
cat .devops-toolkit/reports/finops/latest.md
# → Sprawdź: zakres, środowiska, untagged, niezmiennik

# Ćwiczenie 2: Konto vs środowisko
toolkit finops-report . --period last-full-month
toolkit finops-report . --period last-full-month --env prod
# → Czy total konta = koszt prod? (nie powinien)

# Ćwiczenie 3: Weryfikacja w AWS Console
# → Cost Explorer → Group by: Tag: Environment → porównaj

# Ćwiczenie 4: Analiza untagged
toolkit finops-report . --period last-full-month --group-by usage-type
# → Które usage-types generują untagged? Czy to inherentne koszty AWS?
```

---

## Powiązane

- [[finops-reporting]] — komendy i flagi
- [[command-catalog]]
