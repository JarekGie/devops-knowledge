# devops-toolkit

Bezstanowe CLI — control plane dla AWS, FinOps, IaC i raportów audytowych.

## Co to jest

CLI tool budowany jako system wtyczek z kontraktami. Każda komenda = kontrakt wejście/wyjście.  
Stateless by design — brak lokalnego state, brak bazy danych.

## Szybka nawigacja

- [[context]] — aktualny stan projektu
- [[decisions]] — decyzje architektoniczne
- [[next-steps]] — co dalej
- [[links]] — linki do repo, CI, docs
- [[architecture-overview]] — pełna architektura
- [[contracts-index]] — katalog kontraktów
- [[command-catalog]] — dostępne komendy
- [[roadmap]] — roadmapa

## Repozytorium kodu

- lokalna ścieżka: `~/projekty/devops/devops-toolkit/`
- CLAUDE.md repo: reguły pracy z kodem (feature branch zawsze, nie commituj do main)
- CLAUDE_CONTEXT.md: kontekst architektoniczny i kontrakt wykonawczy

## Technologie

| Warstwa | Tech |
|---------|------|
| Język | (uzupełnij) |
| CLI framework | (uzupełnij) |
| AWS SDK | boto3 / aws-sdk |
| Output | JSON, Markdown, CSV |
| Testy E2E | [[e2e-testing]] |

## Status

`#active`
