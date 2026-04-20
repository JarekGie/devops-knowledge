# LLM_CONTEXT — 02-active-context

## Cel katalogu

Żywy dashboard operacyjny — bieżący stan pracy, blokady, oczekiwania. Najczęściej czytany katalog. Punkt wejścia po każdej przerwie.

## Zakres tematyczny

- Aktywne zadania i ich status
- Otwarte pętle (rzeczy niedomknięte)
- Na co czekamy (zależności zewnętrzne)
- Kontekst bieżącej sesji

Nie przechowuj tu wiedzy trwałej — ona należy do `40-runbooks/`, `20-projects/`, `30-standards/`.

## Najważniejsze notatki

| Plik | Opis |
|------|------|
| `now.md` | **Główny punkt wejścia** — aktywne zadanie, stan po sesji, zamknięte wątki |
| `open-loops.md` | Rzeczy niedomknięte, wymagające uwagi |
| `waiting-for.md` | Zależności zewnętrzne (dev team, klient, AWS Support) |
| `current-focus.md` | Aktualny fokus (aktualizuj przy przełączaniu kontekstu) |

## Konwencje nazewnicze

- Pliki stałe — nie twórz nowych bez potrzeby
- `now.md` — aktualizuj in-place, nie twórz `now-v2.md`
- Daty w treści, nie w nazwie pliku

## Powiązania z innymi katalogami

- `[[../20-projects/]]` — szczegóły projektów wymienionych w `now.md`
- `[[../40-runbooks/incidents/]]` — aktywne incydenty
- `[[../_system/LLM_CONTEXT_GLOBAL]]` — kontekst globalny vault

## Wiedza trwała vs robocza

- **Robocza (całość):** ten katalog wygasa — aktualizuj przy każdej zmianie kontekstu
- Zamknięte tematy przenoś do `session-log.md` projektu lub `40-runbooks/incidents/`

## Jak przygotować kontekst dla ChatGPT

1. Skopiuj sekcję "Aktywne zadanie" i "Gdzie skończyłem" z `now.md`
2. Dodaj relevant sekcję z `20-projects/<projekt>/context.md`
3. Skróć do ~1000 tokenów

---

## Ostatnia aktualizacja kontekstu

2026-04-20 — struktura katalogu stabilna

## Najważniejsze linki

- `[[now]]`
- `[[open-loops]]`
- `[[waiting-for]]`
