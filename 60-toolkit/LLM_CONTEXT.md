# LLM_CONTEXT — 60-toolkit

## Cel katalogu

Dokumentacja projektu `devops-toolkit` — stateless CLI z architekturą plugin/command-router. Kontrakty są source of truth, implementacja wtórna.

## Zakres tematyczny

- Architektura CLI (command-router, plugin system, JSON piping)
- Kontrakty komend (input/output schema)
- Katalog komend i ich parametry
- Raporty, audyty, observability
- Minikursy operacyjne (FinOps, operator, LLZ audit)

## Najważniejsze notatki

| Plik | Opis |
|------|------|
| `architecture-overview.md` | Warstwy: CLI Entry → Command Router → Plugin → AWS SDK → Output |
| `contracts-index.md` | Indeks wszystkich kontraktów (source of truth) |
| `command-catalog.md` | Wszystkie dostępne komendy |
| `llz-audit.md` | Scaffold conformance — reguły A/B/C |
| `observability-ready.md` | Observability readiness — verdict ready_to_apply |
| `roadmap.md` | Roadmap produktu |

## Konwencje nazewnicze

- Kontrakty w `contracts/` — JSON schema
- Komendy w `commands/` — implementacja
- Minikursy: `minikurs-<temat>.md`

## Powiązania z innymi katalogami

- `[[../20-projects/internal/llz/]]` — LLZ używa toolkit do audytów
- `[[../20-projects/internal/devops-toolkit/]]` — projekt tworzący toolkit
- `[[../30-standards/iac-standard]]` — toolkit weryfikuje compliance ze standardem

## Wiedza trwała vs robocza

- **Trwała:** `architecture-overview.md`, `contracts-index.md`, `command-catalog.md`
- **Robocza:** `roadmap.md` — zmienia się z priorytetami

## Jak przygotować kontekst dla ChatGPT

1. `architecture-overview.md` + relevant kontrakt z `contracts/`
2. Dodaj konkretną komendę z `command-catalog.md`
3. Kontrakty JSON są zwięzłe — można wkleić kilka naraz

---

## Ostatnia aktualizacja kontekstu

2026-04-20 — toolkit zaimplementowany, onboarding org LLZ nie rozpoczęty

## Najważniejsze linki

- `[[architecture-overview]]`
- `[[contracts-index]]`
- `[[command-catalog]]`
- `[[llz-audit]]`
