# Standard dokumentacji

#standard

## Co dokumentować

| Co | Gdzie | Priorytet |
|----|-------|-----------|
| Decyzje architektoniczne | [[decision-log]] | wysoki |
| Runbooki operacyjne | `40-runbooks/` | wysoki |
| Standardy i konwencje | `30-standards/` | wysoki |
| Wzorce do reużycia | `50-patterns/` | średni |
| Kontrakty CLI | `60-toolkit/contracts/` | wysoki |

## Czego nie dokumentować

- Kodu który jest oczywisty
- Procesów jednorazowych (chyba że staną się wzorcem)
- Teorii bez zastosowania praktycznego

## Format notatek

```markdown
# Tytuł — krótki i konkretny

#tag1 #tag2

## Sekcja (opcjonalnie — jeśli notatka > 1 ekran)

Treść.

## Powiązane

- [[inna-notatka]]
```

## Zasady

- **Krótko** — notatka powinna być użyteczna w 30 sekund
- **Modularna** — każda sekcja działa niezależnie
- **Linkuj zamiast kopiować** — DRY w dokumentacji
- **Bez wstępu** — zacznij od informacji, nie od kontekstu
- **Język** — polski dla treści, angielski dla nazw technicznych i kodu

## Szablony

→ `templates/` — kopiuj, nie edytuj oryginałów
