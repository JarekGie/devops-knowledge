# Globalny kontekst vault — LLM

> Ładuj ten plik na początku każdej sesji gdy potrzebujesz ogólnego kontekstu vault.
> Dla kontekstu specyficznego dla katalogu — czytaj `<katalog>/LLM_CONTEXT.md`.

---

## Czym jest ten vault

Operacyjna baza wiedzy DevOps/SRE — narzędzie pracy, nie wiki. Właściciel: Jarosław Gołąb (senior DevOps/SRE, AWS-primary, ADHD). Zaprojektowany pod szybki powrót do kontekstu po przerwie i pracę z wieloma równoległymi wątkami.

## Do czego służy

- Kontekst aktywnych zadań i incydentów (`02-active-context/`)
- Runbooki operacyjne i postmortem (`40-runbooks/`)
- Dokumentacja projektów klientów i wewnętrznych (`20-projects/`)
- Standardy, wzorce, komendy referencyjne (`30-standards/`, `50-patterns/`, `90-reference/`)
- Wiedza domenowa (AWS, Terraform, CI/CD) (`10-areas/`)
- FinOps, architektura, dokumentacja CLI toolkit (`70-finops/`, `80-architecture/`, `60-toolkit/`)

## Środowisko techniczne

- Cloud: AWS primary (eu-west-1, eu-central-1), GCP/Azure marginalnie
- IaC: Terraform + CloudFormation
- Konteneryzacja: ECS Fargate
- CI/CD: Jenkins, Atlantis (planowany)
- Profil AWS: `mako-dc` = management account (864277686382), `maspex-cli` = maspex, `plan` = planodkupow
- Vault: Obsidian + git sync

## Aktywne projekty (aktualizuj przy zmianie)

- `planodkupow` — UAT stuck (RabbitMQ deprecated 3.8.6), czeka na deva
- `maspex preprod` — wdrożone, czeka na certyfikaty od klienta
- `LLZ health-notifications` — wdrożone na monitoring-nagios-bot
- `LLZ Faza B` — planowana (GuardDuty, Config, SCP, Security Account)

## Zasada bezpieczeństwa wiedzy — przeczytaj przed każdą sesją LLM

> **Jedna sesja LLM = jedna domena wrażliwości.**
>
> Nie łącz `client-work` + `internal-product-strategy` + `private-rnd` w jednym prompcie.
>
> Jeżeli potrzebne jest porównanie między domenami, użyj wyłącznie neutralnego `shared-concept` (`30-research/ai4devops/`, `30-standards/`, `10-areas/`) albo przygotuj zanonimizowane summary oznaczone jako derived insight.
>
> Szczegółowe zasady: [[DOMAIN_ISOLATION_CONTRACT]] | [[LLM_CONTEXT_BOUNDARY_CONTRACT]]
> Checklista: [[PROMPT_BOUNDARY_CHECKLIST]]
> Model klas: [[CLASSIFICATION_MODEL]]

## Zasady organizacji

| Zasada | Opis |
|--------|------|
| Standalone | Każda notatka działa bez kontekstu zewnętrznego |
| Nie duplikuj | Linkuj zamiast kopiować |
| Kebab-case | Nazwy plików bez dat, bez sufiksów v2/final |
| Trwała vs robocza | `02-active-context/` = robocza, reszta = trwała |
| Język | Polski dla treści, angielski dla kodu/komend |

## Struktura katalogów

```
00-start-here/    — onboarding vault, persona
01-inbox/         — tymczasowe przechwytywanie (czyść co tydzień)
02-active-context/— żywy dashboard: now.md, open-loops.md, waiting-for.md
10-areas/         — AWS, Terraform, CI/CD, observability, business
20-projects/      — internal/ (LLZ, toolkit, exam) + clients/mako/
30-standards/     — tagging, IaC, CI/CD, naming, dokumentacja
40-runbooks/      — aws/, ecs/, kubernetes/, terraform/, incidents/
50-patterns/      — debugging, migration, incident-analysis, finops, prompts
60-toolkit/       — devops-toolkit CLI (architektura, kontrakty, komendy)
70-finops/        — przeglądy kosztów, optymalizacja
80-architecture/  — ADR, mapy systemów, zasady platformy
90-reference/     — commands/, snippets/, glossary/, vendors/
_system/          — kontrakty LLM, kontekst globalny, szablony
_chatgpt/         — eksporty konwersacji dla ChatGPT
```

## Jak pracować z notatkami

1. Wejście po przerwie → czytaj `02-active-context/now.md`
2. Szukasz runbooka → `40-runbooks/<technologia>/`
3. Nowy projekt → utwórz katalog w `20-projects/` z plikami: context.md, session-log.md
4. Nowa decyzja arch. → `80-architecture/decision-log.md`
5. Szybka notatka → `01-inbox/` (przenieś w ciągu tygodnia)

## Jak odróżniać wiedzę trwałą od roboczej

| Trwała | Robocza |
|--------|---------|
| `30-standards/`, `40-runbooks/`, `50-patterns/` | `02-active-context/`, `01-inbox/` |
| `80-architecture/`, `90-reference/` | `session-log.md` w projektach |
| `10-areas/` | `waiting-for.md`, `open-loops.md` |

Wiedza robocza wygasa — aktualizuj `now.md` przy każdej zmianie kontekstu.
