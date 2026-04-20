# LLM_CONTEXT — 70-finops

## Cel katalogu

Zarządzanie kosztami chmury — przeglądy kosztów, optymalizacje, szablony audytów. Wejście dla rozmów o redukcji wydatków i FinOps maturity.

## Zakres tematyczny

- Szablony przeglądów kosztów (Cost Explorer, tagowanie)
- Log oszczędności (co wdrożono, ile zaoszczędzono)
- Pomysły optymalizacyjne (backlog)
- Projekty referencyjne (punkty odniesienia kosztowe)

## Najważniejsze notatki

| Plik | Opis |
|------|------|
| `cost-review-template.md` | Szablon przeglądu kosztów per projekt |
| `tagging-review-template.md` | Szablon audytu tagowania |
| `optimization-log.md` | Historia wdrożonych oszczędności |
| `savings-ideas.md` | Backlog pomysłów optymalizacyjnych |
| `reference-projects.md` | Bazowe koszty projektów (punkt odniesienia) |

## Konwencje nazewnicze

- Szablony: `*-template.md`
- Logi: `*-log.md`
- Pomysły: `savings-ideas.md` (jeden plik, nie multiplikuj)

## Powiązania z innymi katalogami

- `[[../20-projects/clients/mako/finops-rshop]]` — konkretny FinOps review
- `[[../30-standards/aws-tagging-standard]]` — tagging jako fundament FinOps
- `[[../20-projects/internal/llz/waf-checklist]]` — COST pillar WAF

## Wiedza trwała vs robocza

- **Trwała:** szablony, reference-projects
- **Robocza:** optimization-log (aktywne projekty oszczędnościowe)

## Jak przygotować kontekst dla ChatGPT

1. `cost-review-template.md` + dane z Cost Explorer (CSV lub liczby)
2. Dodaj `reference-projects.md` jako punkt odniesienia
3. ChatGPT dobrze radzi sobie z analizą kosztów gdy dostanie konkretne liczby

---

## Ostatnia aktualizacja kontekstu

2026-04-20 — katalog do rozbudowania (brak konkretnych danych kosztowych)

## Najważniejsze linki

- `[[cost-review-template]]`
- `[[savings-ideas]]`
- `[[optimization-log]]`
