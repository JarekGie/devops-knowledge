# LLM_CONTEXT — 50-patterns

## Cel katalogu

Wzorce i playbooki wielokrotnego użytku — metodyki debugowania, analizy incydentów, migracji, FinOps. Też sprawdzone prompty dla Claude/ChatGPT.

## Zakres tematyczny

- Wzorce diagnostyczne (jak podchodzić do klasy problemów)
- Playbooki incydentowe (ogólne, nie per-projekt)
- Wzorce migracji (data, infra)
- Wzorce FinOps review
- Prompty LLM sprawdzone w praktyce

## Najważniejsze notatki

| Plik | Opis |
|------|------|
| `debugging-patterns.md` | Metodyka debugowania infrastruktury |
| `incident-analysis-patterns.md` | Framework analizy incydentów / postmortem |
| `migration-patterns.md` | Wzorce bezpiecznej migracji zasobów |
| `finops-review-patterns.md` | Jak robić przegląd kosztów |
| `reusable-prompts.md` | Skuteczne prompty dla Claude/ChatGPT |

## Konwencje nazewnicze

- `<temat>-patterns.md` dla wzorców
- `reusable-prompts.md` — zbiorczy plik promptów

## Powiązania z innymi katalogami

- `[[../40-runbooks/]]` — runbooki używają tych wzorców
- `[[../10-areas/]]` — wiedza domenowa dająca podstawę wzorcom
- `[[../_chatgpt/]]` — prompty stąd trafiają do paczek kontekstu

## Wiedza trwała vs robocza

- **Trwała (całość):** wzorce nie wygasają, aktualizuj gdy zmieni się praktyka

## Jak przygotować kontekst dla ChatGPT

1. Skopiuj relevantny wzorzec (np. `incident-analysis-patterns.md`)
2. Dodaj konkretny kontekst incydentu z `40-runbooks/incidents/`
3. Wzorce działają jako "frame" — ChatGPT wypełni szczegóły

---

## Ostatnia aktualizacja kontekstu

2026-04-20 — katalog stabilny

## Najważniejsze linki

- `[[debugging-patterns]]`
- `[[incident-analysis-patterns]]`
- `[[reusable-prompts]]`
