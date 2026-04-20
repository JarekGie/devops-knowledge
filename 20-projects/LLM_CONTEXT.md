# LLM_CONTEXT — 20-projects

## Cel katalogu

Dokumentacja projektów — wewnętrznych i klienckich. Kontekst, decyzje, historia sesji, stan wdrożeń.

## Zakres tematyczny

- `internal/` — projekty własne: LLZ, devops-toolkit, egzamin AWS, udemy-tool
- `clients/mako/` — projekty klienckie: maspex, rshop (finops), puzzler-b2b
- Każdy projekt: context.md (standalone LLM), session-log.md (historia), decisions.md

## Najważniejsze notatki

| Plik | Opis |
|------|------|
| `internal/llz/context.md` | LLZ — Light Landing Zone, standard platformowy MakoLab |
| `internal/llz/waf-checklist.md` | WAF checklist — 57 pytań, ~30% ready |
| `internal/llz/session-log.md` | Historia sesji LLZ |
| `internal/devops-toolkit/context.md` | CLI toolkit — architektura, kontrakty |
| `clients/mako/maspex/troubleshooting.md` | Maspex preprod — stan, ALB DNS, TODO |
| `clients/mako/finops-rshop.md` | RShop — FinOps, observability backlog |

## Konwencje nazewnicze

- Każdy projekt: `context.md`, `session-log.md`, `decisions.md`, `next-steps.md`
- Klienci w `clients/<nazwa-klienta>/<projekt>/`
- `troubleshooting.md` — aktywne i zamknięte problemy per projekt kliencki

## Powiązania z innymi katalogami

- `[[../02-active-context/now]]` — aktywne zadania z projektów
- `[[../40-runbooks/]]` — runbooki pisane w kontekście projektów
- `[[../80-architecture/decision-log]]` — decyzje arch. z projektów
- `[[../10-areas/]]` — wiedza domenowa używana w projektach

## Wiedza trwała vs robocza

- **Trwała:** `context.md`, `decisions.md` — kontekst i decyzje
- **Robocza:** `session-log.md` (historia sesji), `troubleshooting.md` (aktywne problemy)

## Jak przygotować kontekst dla ChatGPT

1. `context.md` projektu → punkt wejścia
2. Ostatni wpis z `session-log.md` → aktualny stan
3. Relevant sekcja z `02-active-context/now.md`
4. Razem: ~1500 tokenów wystarczy

---

## Ostatnia aktualizacja kontekstu

2026-04-20 — maspex preprod wdrożone, LLZ health-notifications wdrożone, WAF checklist gotowa

## Najważniejsze linki

- `[[internal/llz/context]]`
- `[[internal/llz/waf-checklist]]`
- `[[internal/devops-toolkit/context]]`
- `[[clients/mako/maspex/troubleshooting]]`
