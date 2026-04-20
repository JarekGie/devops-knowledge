# LLM_CONTEXT — 80-architecture

## Cel katalogu

Decyzje architektoniczne i mapy systemów — "dlaczego tak, a nie inaczej". ADR jako źródło prawdy o wyborach technicznych.

## Zakres tematyczny

- ADR (Architecture Decision Records) — decyzje z uzasadnieniem
- Mapy systemów — wizualizacje architektury projektów
- Zasady platformy — non-negotiable reguły projektowania
- Notatki integracyjne — jak systemy się łączą

## Najważniejsze notatki

| Plik | Opis |
|------|------|
| `decision-log.md` | Rejestr wszystkich ADR — główny plik |
| `platform-principles.md` | Zasady których nie łamiemy |
| `system-maps.md` | Diagramy i mapy architektury |
| `integration-notes.md` | Wzorce integracji między systemami |

## Konwencje nazewnicze

- ADR: wpis w `decision-log.md` z datą i statusem (accepted/superseded/deprecated)
- Format ADR: problem → opcje → decyzja → konsekwencje

## Powiązania z innymi katalogami

- `[[../30-standards/]]` — standardy wynikające z decyzji arch.
- `[[../20-projects/]]` — projekty których dotyczą decyzje
- `[[../10-areas/]]` — wiedza domenowa będąca podstawą decyzji

## Wiedza trwała vs robocza

- **Trwała (całość):** ADR nigdy nie usuwa — "superseded" zamiast delete
- Stare decyzje mają wartość historyczną

## Jak przygotować kontekst dla ChatGPT

1. Skopiuj relevantny ADR z `decision-log.md`
2. Dodaj `platform-principles.md` gdy pytanie dotyczy "czy powinniśmy X"
3. ChatGPT może sugerować alternatywy — zrób ADR z decyzji

---

## Ostatnia aktualizacja kontekstu

2026-04-20 — katalog do wypełnienia (decision-log wymaga uzupełnienia aktualnych decyzji)

## Najważniejsze linki

- `[[decision-log]]`
- `[[platform-principles]]`
