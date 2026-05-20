# Manifest Schema v2 — Documentation Synchronization Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Synchronize vault documentation with Operational Project Manifest schema v2 — additive, minimal diffs only; no architecture changes.

**Architecture:** Six files updated in priority order. Each task is an independent additive patch. No file is restructured or replaced — only sections added or updated.

**Tech Stack:** Obsidian Flavored Markdown, YAML frontmatter, wiki-links

---

## Phase 1 Audit Findings (READ-ONLY, completed)

### Stale / missing in key docs:

| File | Issue |
|------|-------|
| `_system/AGENT_BOOTSTRAP.md` | No manifest loading step in 5-step sequence |
| `CODEX.md` | No Project Bootstrap section; repo work starts from `20-projects/`, not manifest |
| `_system/LLM_CONTEXT_GLOBAL.md` | Entry flow = now.md only; `50-patterns/` misses `invocations/` |
| `_system/AGENTS.md` | No manifest guidance; shared contract is silent on bootstrap flow |
| `00-start-here/how-to-use-this-vault.md` | No "Wejście do projektu → manifest" path |
| `_chatgpt/context-packs/vault-llm-governance.md` | Flow 4.2 missing manifest step; hierarchy 5.1 starts at `20-projects/`; pack count stale (14 vs 20+); section 10 stale (2026-05-15) |

### No stale `profiles/` references in operational files ✓

---

## Task 1: `_system/AGENT_BOOTSTRAP.md` — add manifest loading step

**Files:**
- Modify: `_system/AGENT_BOOTSTRAP.md` (between Krok 2 and Krok 3)

The bootstrap sequence has 5 steps. Add Krok 2.5 (or extend Krok 3) to cover manifest loading when the session involves a specific project.

- [ ] **Step 1: Add Krok 2.5 block after Krok 2 section**

Insert after the `### Krok 2 — identyfikacja domeny` section closing `---`:

```markdown
### Krok 2.5 — załadowanie manifestu projektu (jeśli dotyczy)

Jeśli sesja dotyczy konkretnego projektu:

1. Sprawdź `50-patterns/prompts/invocations/cloud-detective-<projekt>.md`
2. Jeśli manifest istnieje — załaduj frontmatter: `cloud_provider`, `repo`, `safety`, `open_items`, `vault`
3. Wykonaj `startup checklist` z body manifestu (open_items → session_log → now.md → branch LIVE)
4. NIE wykonuj akcji z `safety.requires_go` bez osobnego GO operatora

Jeśli manifest nie istnieje → postępuj jak dotychczas (czytaj notatki projektu w `20-projects/`).

**Runtime vs Persistent:**
- Manifest zawiera: identity, governance, safety, routing — dane trwałe
- Manifest NIE zawiera: live ECS state, koszty, metryki, runtime task counts
- Live state pobieraj LIVE z cloud/API w trakcie sesji

---
```

- [ ] **Step 2: Commit**

```bash
git add _system/AGENT_BOOTSTRAP.md
git commit -m "docs: add manifest loading step to AGENT_BOOTSTRAP sequence"
```

---

## Task 2: `CODEX.md` — add Project Bootstrap section

**Files:**
- Modify: `CODEX.md` (add section before `## Powiązane`)

- [ ] **Step 1: Add Project Bootstrap section before `## Powiązane`**

```markdown
## Project Bootstrap

Jeśli istnieje `50-patterns/prompts/invocations/cloud-detective-<projekt>.md` — wczytaj go **zamiast** pytać o kontekst projektu.

Zasady:
- Na początku rozmowy dotyczącej konkretnego projektu — sprawdź `50-patterns/prompts/invocations/`
- Jeśli manifest istnieje: wczytaj frontmatter (`cloud_provider`, `repo`, `safety`, `open_items`, `vault`) i `startup checklist` z body manifestu
- Jeśli manifestu nie ma: postępuj jak dotychczas (czytaj notatki projektu w `20-projects/`, pytaj o ścieżkę repo)

**Priorytety bezpieczeństwa z manifestu:**
- `safety.mode: read_only` → tylko `describe*`, `get*`, `list*`; każdy write wymaga GO
- `safety.mode: conditional_go` → plan wolny; apply i write ops wymagają osobnego GO
- `safety.mode: manual_execution_only` → żadnych automatycznych akcji; tylko analiza
- `safety.requires_go` lista jest wiążąca — nie wykonuj tych akcji bez potwierdzenia

**Aktywny branch:** pobieraj LIVE przez `git branch --show-current` w `repo.local` — nie z manifestu

**Runtime vs Persistent:**
- Manifest zawiera: identity, governance, safety, routing, constraints
- Manifest NIE zawiera: live ECS state, koszty, metryki, runtime task counts — pobieraj LIVE

**Dostępne manifesty (schema v2):** maspex, rshop, booking-online, puzzler-b2b, drp-tfs, aws-cloud-platform, mfs-onboarding (GCP)
**Generator:** `scripts/new-cloud-detective-invocation.sh`
**Szablon:** `50-patterns/prompts/invocations/templates/cloud-detective-invocation-template.md`
```

- [ ] **Step 2: Update "Praca z repozytoriami projektów" section**

Replace the opening line of that section:
```
- Zacznij od notatki projektu w `20-projects/` i ustal lokalną ścieżkę repo
```
with:
```
- Najpierw sprawdź `50-patterns/prompts/invocations/cloud-detective-<projekt>.md` — jeśli manifest istnieje, ścieżka repo jest w `repo.local`
- Jeśli manifestu nie ma: zacznij od notatki projektu w `20-projects/` i ustal lokalną ścieżkę repo
```

- [ ] **Step 3: Commit**

```bash
git add CODEX.md
git commit -m "docs: add Project Bootstrap section to CODEX.md, align with CLAUDE.md"
```

---

## Task 3: `_system/LLM_CONTEXT_GLOBAL.md` — add invocations path, update entry flow

**Files:**
- Modify: `_system/LLM_CONTEXT_GLOBAL.md`

Two minimal changes: (A) add invocations to directory listing, (B) update "Jak pracować" step 3.

- [ ] **Step 1: Update `50-patterns/` line in directory listing**

Replace:
```
50-patterns/      — debugging, migration, incident-analysis, finops, prompts
```
with:
```
50-patterns/      — debugging, migration, finops, prompts
  invocations/    ← ★ operational project manifests (schema v2) — bootstrap per projekt
```

- [ ] **Step 2: Update "Jak pracować z notatkami" step 3**

Replace:
```
3. Nowy projekt → utwórz katalog w `20-projects/` z plikami: context.md, session-log.md
```
with:
```
3. Praca nad projektem → sprawdź `50-patterns/prompts/invocations/cloud-detective-<projekt>.md`; jeśli brak → utwórz katalog w `20-projects/`
```

- [ ] **Step 3: Update frontmatter `updated` field**

```yaml
updated: 2026-05-20
```

- [ ] **Step 4: Commit**

```bash
git add _system/LLM_CONTEXT_GLOBAL.md
git commit -m "docs: add invocations path and manifest-first project entry to LLM_CONTEXT_GLOBAL"
```

---

## Task 4: `_system/AGENTS.md` — add manifest bootstrap guidance

**Files:**
- Modify: `_system/AGENTS.md` (add section after "Priorytet folderów")

- [ ] **Step 1: Add "Project Bootstrap" section after `## Priorytet folderów` section**

```markdown
## Project Bootstrap (jeśli dotyczy projektu)

Gdy sesja dotyczy konkretnego projektu klienta lub wewnętrznego:

1. Sprawdź `50-patterns/prompts/invocations/cloud-detective-<projekt>.md`
2. Manifest dostarcza: cloud provider, repo path, safety mode, open items, session log path
3. Safety constraints z manifestu są wiążące — `safety.requires_go` = lista akcji wymagających GO
4. Branch zawsze pobieraj LIVE: `git branch --show-current` — nie z manifestu
5. Runtime state (ECS, koszty, metryki) pobieraj LIVE z cloud/API — manifest nie zawiera live data

```

- [ ] **Step 2: Commit**

```bash
git add _system/AGENTS.md
git commit -m "docs: add Project Bootstrap section to AGENTS.md"
```

---

## Task 5: `00-start-here/how-to-use-this-vault.md` — add project entry path

**Files:**
- Modify: `00-start-here/how-to-use-this-vault.md`

- [ ] **Step 1: Add manifest entry to "Szybki start pracy" section**

Replace the "Zasady nawigacji" opening block:
```
**Szybki start pracy:** otwórz [[now]] albo [[current-focus]]  
**Niespodziewany problem:** `40-runbooks/` → wybierz folder → README → konkretny runbook  
**Coś do zapamiętania, ale nie wiadomo gdzie:** wrzuć do `01-inbox/quick-capture.md`  
**Nowy projekt:** skopiuj `templates/project-note-template.md` do `20-projects/`  
**Decyzja do udokumentowania:** skopiuj `templates/decision-template.md` do `80-architecture/`
```
with:
```
**Szybki start pracy:** otwórz [[now]] albo [[current-focus]]  
**Wejście do projektu:** sprawdź `50-patterns/prompts/invocations/cloud-detective-<projekt>.md` → załaduj manifest → startup checklist  
**Niespodziewany problem:** `40-runbooks/` → wybierz folder → README → konkretny runbook  
**Coś do zapamiętania, ale nie wiadomo gdzie:** wrzuć do `01-inbox/quick-capture.md`  
**Nowy projekt:** skopiuj `templates/project-note-template.md` do `20-projects/`  
**Decyzja do udokumentowania:** skopiuj `templates/decision-template.md` do `80-architecture/`
```

- [ ] **Step 2: Commit**

```bash
git add 00-start-here/how-to-use-this-vault.md
git commit -m "docs: add manifest entry point to how-to-use-this-vault"
```

---

## Task 6: `_chatgpt/context-packs/vault-llm-governance.md` — update flows + manifest section

**Files:**
- Modify: `_chatgpt/context-packs/vault-llm-governance.md`

Three targeted updates: (A) Claude Code flow 4.2, (B) context hierarchy 5.1, (C) header + context pack count.

- [ ] **Step 1: Update Sekcja 4.2 flow (add manifest step)**

Replace Claude Code flow diagram:
```
Start sesji → AGENT_BOOTSTRAP.md (5 kroków) → czytaj now.md
```
with:
```
Start sesji → AGENT_BOOTSTRAP.md → identyfikacja domeny
  ↓ (jeśli praca nad projektem)
Manifest: 50-patterns/prompts/invocations/cloud-detective-<projekt>.md
  → cloud_provider, repo, safety.mode, open_items, vault.session_log
  ↓
Czytaj last 2 wpisy session_log + now.md
```

- [ ] **Step 2: Update Sekcja 5.1 context hierarchy (manifest first)**

Replace step 3:
```
3. **Projekt:** `20-projects/<klient>/<projekt>/context.md` + ostatni `session-log.md`
```
with:
```
3. **Projekt:** `50-patterns/prompts/invocations/cloud-detective-<projekt>.md` (manifest); fallback → `20-projects/<klient>/<projekt>/context.md`
```

- [ ] **Step 3: Update context pack count in Sekcja 5.3**

Replace:
```
### 5.3 Aktywne context packs (14 tematów)
```
with:
```
### 5.3 Aktywne context packs (20+ tematów)
```

- [ ] **Step 4: Add manifest schema v2 note to Sekcja 9 (agent contracts)**

After the table in 9.1, add:
```markdown
### 9.3 Project Bootstrap (od 2026-05-20)

Oba agenty (Claude Code i Codex) mają identyczny Project Bootstrap:
- Entry point: `50-patterns/prompts/invocations/cloud-detective-<projekt>.md`
- Schema v2: `schema_contract`, `lifecycle`, `llm_rules`, `cloud_provider` (cloud-agnostic: aws/gcp/azure/ovh), `safety.mode`, `open_items`
- `open_items` = wyłącznie aktywne ryzyka i safety constraints — NIE todo/backlog
- Runtime state pobierany LIVE — manifest zawiera tylko persistent identity + governance
- `profiles/` usunięty 2026-05-20 — zastąpiony przez manifest schema v2
```

- [ ] **Step 5: Update frontmatter `updated` and document date**

```yaml
updated: 2026-05-20
```

- [ ] **Step 6: Commit**

```bash
git add _chatgpt/context-packs/vault-llm-governance.md
git commit -m "docs: update vault-llm-governance — manifest flow, schema v2, context pack count"
```

---

## Phase 6 — Validation Checklist

After all tasks complete:

- [ ] `grep -r "profiles/" --include="*.md"` — only `80-architecture/` proposal and `vault-structure-current.md` (both intentional)
- [ ] AGENT_BOOTSTRAP.md contains "manifest projektu" and "50-patterns/prompts/invocations"
- [ ] CODEX.md has `## Project Bootstrap` section identical in intent to CLAUDE.md
- [ ] LLM_CONTEXT_GLOBAL.md shows `invocations/` under `50-patterns/`
- [ ] AGENTS.md has `## Project Bootstrap` section
- [ ] how-to-use-this-vault.md has "Wejście do projektu" in Nawigacja
- [ ] vault-llm-governance.md flow includes manifest step and mentions schema v2
- [ ] No file was restructured — all changes additive

---

## Critical Rules (enforced throughout)

- NO architecture expansion
- NO new systems, orchestration, collectors, UI work
- Minimal additive diffs — preserve surrounding content exactly
- vault philosophy preserved: standalone notes, Polish content, wiki-links
