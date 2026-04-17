# devops-toolkit

Bezstanowe CLI — control plane dla AWS, FinOps, IaC i raportów audytowych.

## Szybka nawigacja

| Zasób | Link |
|-------|------|
| Architektura | [[architecture-overview]] |
| Kontrakty (katalog) | [[contracts-index]] |
| Komendy | [[command-catalog]] |
| Roadmapa | [[roadmap]] |
| System wtyczek | [[plugin-system]] |
| FinOps reporting | [[finops-reporting]] |
| Testy E2E | [[e2e-testing]] |

## Subkatalogi

```
contracts/    ← kontrakty wejście/wyjście per komenda
commands/     ← implementacja komend
audits/       ← moduły audytowe
reports/      ← szablony i generatory raportów
```

## Zasady projektu

- **Stateless** — brak lokalnego state, brak bazy danych
- **Contract-first** — każda komenda ma zdefiniowany kontrakt przed implementacją
- **Composable** — output jednej komendy = input następnej (JSON)
- **Deterministic** — ten sam input = ten sam output

## Status projektu

→ `20-projects/internal/devops-toolkit/`
