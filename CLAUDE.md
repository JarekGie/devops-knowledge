# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

An Obsidian-based operational knowledge vault for a senior DevOps/SRE engineer (Jarosław Gołąb). Not a wiki — a work tool. Designed for interruption-heavy technical work and fast re-entry after context loss.

## Vault contract (non-negotiable)

- **Language:** note content in Polish; code, commands, filenames may be English
- **Structure per note:** symptom/problem → context → solution/actions → notes. Never long theoretical intros.
- **Every note must work standalone** — no "read section 1 before section 3" dependencies
- **No empty files** — every file must contain real operational value or a ready-to-use template
- **File naming:** kebab-case, short, no `final`/`v2`/`new`/`copy` suffixes
- **Links:** use `[[wiki-links]]` for cross-note navigation; don't repeat content across notes

## Folder priority (highest to lowest)

1. `02-active-context/` — daily operational state (now.md, current-focus.md, open-loops.md, waiting-for.md)
2. `40-runbooks/` — incident and operational procedures
3. `20-projects/` — internal and client project notes
4. `30-standards/` — tagging, IaC, CI/CD, naming conventions
5. `50-patterns/` — debugging, migration, FinOps review patterns
6. `90-reference/` — commands, snippets, glossary

## Vault structure

```
00-start-here/       ← vault usage rules, persona
01-inbox/            ← temporary capture (not an archive)
02-active-context/   ← live operational dashboard
10-areas/            ← aws/, terraform/, cicd/, observability/, cloud-support/, business/
20-projects/         ← internal/, client/, reference/
30-standards/        ← aws-tagging, iac, cicd, naming, documentation
40-runbooks/         ← aws/, ecs/, kubernetes/, terraform/, networking/, incidents/
50-patterns/         ← debugging, migration, incident-analysis, finops, reusable-prompts
60-toolkit/          ← devops-toolkit CLI project (architecture, contracts, commands, audits)
70-finops/           ← cost reviews, optimization, savings
80-architecture/     ← ADR (decision-log), system maps, platform principles
90-reference/        ← commands/, snippets/, glossary/, vendors/
templates/           ← copy before use, never edit originals
```

## devops-toolkit architecture

`60-toolkit/` tracks a stateless CLI (`toolkit <command> [options]`) with a plugin/command-router architecture. Key concepts:

- Every command is defined by a **contract** (input/output schema) in `60-toolkit/contracts/` — contracts are source of truth, implementation is secondary
- Commands compose via JSON piping: `toolkit audit iam --output json | toolkit report generate --format markdown`
- Layers: CLI Entry → Command Router → Command/Plugin → AWS SDK → Output Layer (JSON/MD/CSV)
- See [[architecture-overview]], [[contracts-index]], [[command-catalog]]

## Runbook design pattern

Runbooks must follow this section order:
1. Objaw / symptom
2. Zakres / scope
3. Szybkie komendy
4. Decision points
5. Rollback / safety
6. Findings / notes

Template: `templates/runbook-template.md`

## inbox policy

`01-inbox/` is temporary. Items older than 1 week are backlog, not archive. Move or delete — don't accumulate.

## Tagging conventions (notes)

Use `#aws`, `#terraform`, `#incident`, `#finops`, `#todo`, `#decision` for cross-vault search.

## Persona context

User: experienced DevOps/SRE, AWS-primary (also GCP/Azure), ADHD. System must reduce memory burden. Fast-access modular notes work well; linear checklists and long sequential docs do not. See [[persona]] for full profile.
