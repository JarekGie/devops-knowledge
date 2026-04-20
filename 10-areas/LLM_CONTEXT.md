# LLM_CONTEXT — 10-areas

## Cel katalogu

Wiedza domenowa — "jak działa X" zamiast "co zrobić z konkretnym problemem". Wiedza referencyjna, nie operacyjna.

## Zakres tematyczny

- `aws/` — AWS services, patterns, best practices
- `terraform/` — HCL, provider patterns, state management
- `cicd/` — pipelines, Jenkins, Atlantis
- `observability/` — CloudWatch, OAM, metryki, logi
- `business/` — kontekst biznesowy DevOps jako usługi
- `cloud-support/` — praca z AWS Support
- `obsidian/` — meta-wiedza o vault (git sync, pluginy)

> ⚠️ Większość podkatalogów ma tylko README.md — sekcje do wypełnienia przy pierwszej sesji domenowej.

## Najważniejsze notatki

| Plik | Opis |
|------|------|
| `obsidian/git-sync.md` | Git sync vault — konfiguracja |
| `obsidian/plugin-terminal.md` | Terminal plugin w Obsidian |

## Konwencje nazewnicze

- Podkatalogi = domeny techniczne
- Pliki = konkretne tematy domenowe (np. `vpc-flow-logs.md`, `ecs-task-iam.md`)
- Nie duplikuj runbooków — link do `40-runbooks/`

## Powiązania z innymi katalogami

- `[[../40-runbooks/]]` — procedury używające tej wiedzy domenowej
- `[[../30-standards/]]` — standardy wynikające z wiedzy domenowej
- `[[../90-reference/]]` — komendy i snippety per domena

## Wiedza trwała vs robocza

- **Trwała (całość):** wiedza domenowa nie wygasa szybko
- Aktualizuj gdy AWS zmieni API lub pojawi się nowy pattern

## Jak przygotować kontekst dla ChatGPT

1. Skopiuj relevantny plik domenowy (np. `terraform/state-backend.md`)
2. Dodaj konkretny problem z `02-active-context/now.md`
3. Ten katalog jest zazwyczaj tłem — nie głównym kontekstem

---

## Ostatnia aktualizacja kontekstu

2026-04-20 — katalog w dużej mierze do wypełnienia (stub READMEs)

## Najważniejsze linki

- `[[obsidian/git-sync]]`
