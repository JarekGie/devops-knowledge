---
title: ChatGPT context — struktura i budowa vault devops-knowledge (aktualny stan)
domain: shared-concept
origin: vault-synthesis
classification: internal
llm_exposure: allowed
cross_domain_export: allowed
source_of_truth: vault
created: 2026-05-20
updated: 2026-05-20
tags: [chatgpt, context-pack, vault, architecture, invocation, schema-v2, operational-platform]
---

# ChatGPT Context Pack — Struktura Vault devops-knowledge (2026-05-20)

> Wklej całość na początku rozmowy gdy tematem jest struktura vault, system invocacji, operational platform lub dzisiejsze zmiany architektoniczne.
> Zakres: `shared-concept` — brak danych klientowskich, można używać swobodnie.

**Zakres:** prywatny vault `devops-knowledge` — pełna struktura, system invocacji (schema v2), propozycja operational platform foundation, zmiany 2026-05-20  
**Data:** 2026-05-20  
**Lokalizacja lokalna:** `~/projekty/devops/devops-knowledge`  
**Branch roboczy:** `feat/operational-platform-foundation`

---

## 1. Kim jestem / jak odpowiadać

Senior DevOps/SRE, AWS multi-account (Organizations), Terraform, ECS Fargate, ADHD.  
Styl: werdykt na górze, evidence poniżej. Podążaj za nowym wątkiem bez pytania o powrót. Krótkie sekcje z nagłówkami.

---

## 2. Czym jest vault

Operacyjna baza wiedzy Obsidian dla jednego operatora. Nie wiki — narzędzie pracy. Zaprojektowany pod pracę z częstymi przerwaniami i szybki powrót do kontekstu po przerwie.

**Non-negotiable:**
- Treść po polsku; kod, komendy, ścieżki — po angielsku
- Format notatki: `objaw/problem → kontekst → rozwiązanie → uwagi`
- Każda notatka standalone (zero zależności "przeczytaj X przed Y")
- Brak pustych plików
- Nazwy plików: `kebab-case`, bez dat
- Linki wewnętrzne: `[[wiki-links]]`

---

## 3. Struktura katalogów (aktualny stan)

```
00-start-here/       ← zasady vault, persona
01-inbox/            ← tymczasowe przechwytywanie (rotacja co tydzień)
02-active-context/   ← now.md, current-focus.md, open-loops.md, waiting-for.md
10-areas/            ← aws/, terraform/, cicd/, observability/, cloud-support/, business/
20-projects/         ← internal/, clients/mako/<projekt>/
30-standards/        ← aws-tagging, iac, cicd, naming, documentation
40-runbooks/         ← aws/, ecs/, kubernetes/, terraform/, networking/, incidents/
50-patterns/         ← debugging, migration, finops, reusable-prompts
  prompts/
    invocations/     ← ★ KLUCZOWY: operational project manifests (schema v2)
    starter-pack/    ← cloud-detective-v2.md (prompt template)
60-toolkit/          ← devops-toolkit CLI (kontrakty, architektura, komendy)
70-finops/           ← przeglądy kosztów, optymalizacja
80-architecture/     ← decision-log.md, operational-platform-foundation-proposal.md (NOWY)
90-reference/        ← commands/, snippets/, glossary/, notebooklm/
_chatgpt/            ← context-packs/ + conversations/ + templates/
_system/             ← kontrakty LLM, polityki, granice domen
scripts/             ← new-cloud-detective-invocation.sh (cloud-agnostic generator)
templates/           ← szablony do kopiowania
```

**Active context (`02-active-context/`):**

| Plik | Rola |
|------|------|
| `now.md` | Bieżący stan operacyjny — update bloki per sesja |
| `current-focus.md` | Priorytety tygodnia |
| `open-loops.md` | Rzeczy wiszące |
| `waiting-for.md` | Blokery zależne od innych |

**Governance (`_system/`):**

| Plik | Rola |
|------|------|
| `AGENT_BOOTSTRAP.md` | Mandatory bootstrap dla każdego agenta LLM |
| `AI_COST_AWARE_AGENT_CONTRACT.md` | Model tiering: S/M/P |
| `DOMAIN_ISOLATION_CONTRACT.md` | Jedna sesja = jedna domena |
| `CHATGPT_WORKFLOW.md` | Export/import rozmów ChatGPT |
| `LLM_EXPORT_POLICY.md` | Co wolno eksportować do LLM |

---

## 4. System invocacji — Operational Project Manifest (schema v2) ★ KLUCZOWE

### Co to jest

`50-patterns/prompts/invocations/` to zbiór per-projekt manifestów YAML+MD. Jeden plik = jeden projekt = jeden canonical manifest. Zasada: **ONE PROJECT = ONE CANONICAL MANIFEST**.

Manifest działa jako deterministyczny bootstrap dla agenta LLM: zamiast czytać `now.md` w całości, agent ładuje manifest projektu i ma wszystko — AWS profile, repo path, safety constraints, open items.

### Dostępne manifesty (schema v2, aktywne)

| Manifest | Klient | Cloud | Status |
|----------|--------|-------|--------|
| `cloud-detective-maspex.md` | mako | AWS eu-west-1 | active |
| `cloud-detective-rshop.md` | mako | AWS | active |
| `cloud-detective-booking-online.md` | mako | AWS | active |
| `cloud-detective-puzzler-b2b.md` | mako | AWS | active |
| `cloud-detective-drp-tfs.md` | mako | AWS | active |
| `cloud-detective-aws-cloud-platform.md` | internal | AWS | active |
| `cloud-detective-mfs-onboarding.md` | mako | GCP | active |
| `cloud-detective-test.md` | — | template/test | active |

### Struktura manifest (schema v2)

```yaml
schema_contract:
  manifest_type: operational-project-manifest
  schema_version: "2"

type: prompt-invocation              # backward-compat
domain: client-work                  # client-work | internal-product | private-rnd
cloud_provider:
  name: aws                          # aws | gcp | azure | ovh | multi
  aws:
    profile: <AWS_PROFILE>
    account_id: "<ID>"

regions:
  primary: [eu-west-1]
  extra: []

repo:
  local: ~/projekty/...
  default_branch: main
  working_branch_pattern: "feat/*"   # branch aktualny: git branch --show-current LIVE

iac:
  type: terraform
  state_backend: s3

vault:
  save_path: 20-projects/clients/<CLIENT>/<PROJECT>/
  session_log: 20-projects/clients/<CLIENT>/<PROJECT>/session-log.md

safety:
  mode: read_only                    # read_only | conditional_go | manual_execution_only
  requires_go: [terraform apply, ...]

open_items:                          # TYLKO: ryzyka, safety constraints — NIE todo/backlog
  - id: P1
    desc: "opis ryzyka"
    status: open | conditional_go | pending_push

llm_rules:
  domain_isolation: strict
  cross_project_reasoning: forbidden
  autonomous_actions: false
```

### Jak agent używa manifestu

1. Użytkownik mówi: *"przełącz na maspex"* lub przekazuje ścieżkę manifestu
2. Agent ładuje frontmatter: `cloud_provider`, `repo`, `safety`, `open_items`, `vault`
3. Agent wykonuje `startup checklist` z body manifestu:
   - Sprawdź `open_items`
   - Przeczytaj ostatnie 2 wpisy w `session_log`
   - Sprawdź `now.md`
   - `git branch --show-current` w `repo.local` (branch live, nie z manifestu)
   - Nie wykonuj akcji z `safety.requires_go` bez GO

### Generator manifestów

```bash
scripts/new-cloud-detective-invocation.sh \
  --client <CLIENT> \
  --project <PROJECT> \
  --cloud aws|gcp|azure|ovh \
  --profile <PROFILE> \
  --repo-path <PATH> \
  --regions <REGION> \
  --iac-type terraform \
  --safety-mode conditional_go
```

---

## 5. Dzisiejsze zmiany (2026-05-20) — szczegóły

### Zmiana A: Migracja schema v1 → v2 (DONE)

**Motywacja:** stary schemat był AWS-only, brak standaryzacji pól, brak `lifecycle`, `ownership`, `llm_rules`.

**Co zmieniono:**
- 8 plików invocations zmigrowanych do schema v2
- Pole `cloud_provider.name: aws|gcp|azure|ovh` — generator cloud-agnostic
- Nowe pola: `schema_contract`, `lifecycle`, `ownership`, `llm_rules`
- Usunięty `profiles/` folder — dane w manifest v2 (profiles/ był pilotażową próbą, zastąpiony przez pełny manifest schema)
- Poprawki: region `eu-central` → `eu-central-1`, garbage char w drp-tfs, GCP hackfix w mfs-onboarding
- Generator: flaga `--cloud` zamiast tylko `--aws-profile` (backward-compat alias zachowany)

**Status:** kompletne — wszystkie 8 projektów na v2

### Zmiana B: Operational Platform Foundation Proposal (NOWY)

**Lokalizacja:** `80-architecture/operational-platform-foundation-proposal.md`

**Co to:** propozycja architektoniczna rozwiązująca 6 udokumentowanych bottlenecków:

| ID | Problem | Rozwiązanie |
|----|---------|-------------|
| B1 | Brak deterministycznego project bootstrap | Project Profiles (Krok 1) |
| B2 | Context packs driftują od vault | — (future) |
| B3 | Evidence collection reinventowana przy każdym audycie | Evidence Collectors w `scripts/collectors/` |
| B4 | Cross-project navigation liniowa | `_index/projects.yaml` registry |
| B5 | `now.md` nie skaluje dla 8+ projektów | Slim-down `now.md`, szczegóły w profilach |
| B6 | `_system/scripts/` folder pusty, brak automatyzacji | Collectors + generator |

**Priorytety:**

| Kategoria | Co | Effort |
|-----------|-----|--------|
| MUST HAVE | Cleanup tech debt + Evidence collectors (3 core) + Project profiles | ~12h |
| HIGH VALUE | `_index/projects.yaml` + pozostałe profiles + now.md slim-down | ~11h |
| OPTIONAL / DEFER | AI orchestration layer, operational UI | po 3 miesiącach użycia |

**Safety model:**
- Każdy krok = nowe pliki, ZERO modyfikacji `_system/` bez osobnego ADR
- Rollback: `git checkout last-stable-version` (tag → commit `449df1c`)
- Status: proposal — awaiting operator review

### Zmiana C: CLAUDE.md Project Bootstrap

Sekcja `## Project Bootstrap` zaktualizowana — wskazuje na `50-patterns/prompts/invocations/` zamiast na `profiles/`:

```
Jeśli istnieje cloud-detective-<projekt>.md — wczytaj go zamiast pytać o kontekst.
Jeśli manifestu nie ma: czytaj notatki projektu w 20-projects/, pytaj o ścieżkę repo.
```

---

## 6. Domeny wrażliwości (sesja = jedna domena)

| Domena | Przykłady |
|--------|-----------|
| `client-work` | maspex, rshop, puzzler-b2b, booking-online, drp-tfs |
| `internal-product-strategy` | LLZ, devops-toolkit roadmapa, aws-cloud-platform |
| `private-rnd` | osobiste projekty R&D |
| `shared-concept` | standardy, wzorce Terraform, zasady vault, kontrakty LLM |

---

## 7. Jak Claude Code pracuje z vaultem

- Pełny dostęp do filesystem
- Obowiązkowy bootstrap: `_system/AGENT_BOOTSTRAP.md`
- Triggery zapisu (natychmiast): zmiana zadania → `now.md`; implementacja → `session-log.md`; decyzja arch → `decision-log.md`
- Context packs: najpierw sprawdza czy istnieje przed tworzeniem nowego
- Authorship: żadnych `Co-Authored-By`, żadnych wzmianek AI w commitach/dokumentach

---

## 8. Jak używać tej paczki w ChatGPT

**Użyj do:**
- pytań o strukturę vault, jak coś jest zorganizowane, gdzie coś szukać
- projektowania nowych notatek, sekcji, folderów
- dyskusji o invocation schema — co zmienić, jak rozszerzyć
- planowania kolejnych kroków operational platform foundation (Krok 1–5)
- porównywania opcji dla governance, lifecycle, evidence collection

**Nie używaj do:**
- konkretnych projektów klientowskich (użyj dedykowanego packa np. `maspex.md`)
- decyzji runtime AWS bez live verification

**Dodaj kontekst przed pytaniem:**
```
Zadanie: [co chcesz osiągnąć / o co pytasz]
Obszar: [invocations | struktura | operational platform | inne]
```

---

## 9. Źródła użyte do przygotowania

```
devops-knowledge:
  CLAUDE.md (sekcja Project Bootstrap)
  _system/AGENT_BOOTSTRAP.md
  50-patterns/prompts/invocations/templates/cloud-detective-invocation-template.md
  50-patterns/prompts/invocations/cloud-detective-maspex.md (przykład v2)
  80-architecture/operational-platform-foundation-proposal.md
  _chatgpt/context-packs/dual-vault-architecture.md (struktura vault — sekcja 3)
  git log --since 2026-05-20 (dzisiejsze commity)
```
