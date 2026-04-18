# devops-toolkit — Session Log

Format: data, co zrobiono, gdzie skończono, co następne.

---

## 2026-04-17 — Przegląd i dokumentacja kontekstu

**Co zrobiono:**
- Pełny przegląd repo (302 commity, architektura, testy, długi techniczne)
- Wypełniono context.md, decisions.md, next-steps.md, links.md w vault
- Zidentyfikowano 3 stuby wymagające implementacji (cost normalization, finops sanitization, ALB scaffold)
- Ostatni PR: #50 feat/observability-ready-v1 (merged)

**Stan na koniec sesji:**
- Toolkit stabilny po "repo freeze" (commit `a022781`)
- Brak aktywnych PR
- Znane długi: cost normalization + finops sanitization (nie blokują głównego flow)

**Następna sesja:**
- Zdecydować który dług techniczny zaadresować jako pierwszy
- Sprawdzić status devops-toolkit-ui (czy UI jest zsynchronizowane z backendem)

---

## 2026-04-17 — Git cleanup + priorytetyzacja długów technicznych

**Co zrobiono:**
- Git cleanup repo: uncommitted changes na main → branch `feat/project-audit-ownership-patterns` (ALB ownership patterns, nowy moduł `toolkit/project_audit/ownership_patterns.py`)
- Wypchnięto zaległe branche: `feat/atlantis-poc-implementation`, `feat/onboard-allocation-defaults`
- Zabezpieczono lokalne worktree: `feat/init-project-v2-roadmap-clean`, `fix/finops-cost-trend-section-green`
- Stary worktree agenta (`worktree-agent-a0c3d3c4`, 195 commitów za main) → zapisany jako `chore/agent-terraform-module-audit-wip`, usunięty
- Priorytetyzacja długów: FinOps sanitizer (bezpieczeństwo) > cost normalization > ALB scaffold
- Zaktualizowano konwencję vaultu: sekcja "Repozytorium kodu" w notatkach projektów

**Stan na koniec sesji:**
- main czysty, zsynchronizowany z origin
- Brak otwartych PR
- Wybrane następne zadanie: `sanitizers/sanitize-finops-findings.py` (stub → implementacja)

**Następna sesja:**
- Implementacja FinOps sanitizer na feature branchu
- Uruchomić testy po implementacji

---

## 2026-04-17 — Implementacja FinOps sanitizer

**Co zrobiono:**
- Branch: `fix/finops-sanitizer-stub`
- Zaimplementowano `sanitizers/sanitize-finops-findings.py` (stub → pełna implementacja)
- Auto-detekcja dwóch schematów wejściowych: `idle-storage.json` i `cost-summary.json`
- 22 testy jednostkowe (`tests/unit/test_sanitize_finops_findings.py`) — 22/22 pass
- `make contract-check` — czysty
- Zaktualizowano `ARCHITECTURE.md` (sekcja sanitizers/registry.yaml)
- Commit: `f9d278b`, branch wypchnięty do origin

**Stan na koniec:**
- PR do stworzenia: `fix/finops-sanitizer-stub` → main
- Pozostałe długi: cost normalization (`normalizers/cost/normalize-cost.py:10`), ALB scaffold fix

**Następna sesja:**
- Stworzyć PR dla `fix/finops-sanitizer-stub`
- Rozważyć: cost normalization jako następny dług techniczny

---

## 2026-04-17 — Cost normalization stub + vault contract

**Co zrobiono:**
- Branch: `fix/cost-normalization-stub`
- Zaimplementowano `normalizers/cost/normalize-cost.py` (legacy, używany przez `aws_cost_hotspots`)
- Sumowanie `BlendedCost` przez `ResultsByTime`, agregacja `Groups` → `top_services`
- 14 testów jednostkowych — 14/14 pass
- `make contract-check` — czysty
- Zaktualizowano `ARCHITECTURE.md`
- PR #52 zmerge, commit `6cc66d7`
- Zaktualizowano kontrakt vaultu: mirror docs/minikursów obowiązkowy
- Przepisano `60-toolkit/finops-reporting.md` (fikcyjne komendy → realne)
- Przepisano `60-toolkit/command-catalog.md` (fikcyjne komendy → realne z cli-public-api.md)

**Stan na koniec:**
- Oba stuby FinOps naprawione i w main
- Pozostały dług: ALB scaffold fix (`test_init_project.py:1396`)

**Następna sesja:**
- ALB scaffold fix lub weryfikacja devops-toolkit-ui sync

---

## 2026-04-18 — fix apply-pack tagging (PR #53)

**Co zrobiono:**
- Zidentyfikowano 3 bugi w `tools/finops_tagging/stack-tag-updater.py` podczas tagowania rshop dev
- Branch: `fix/stack-tag-updater-safety-check`
- Fix 1: `_inspect_changes()` — tag-only CFN propagation jest teraz safe (był blokowany)
- Fix 2: `CAPABILITY_NAMED_IAM` dodane do `create_change_set` i `update_stack`
- Fix 3: `Project` tag value z `project_cfg["project"]` zamiast nazwy katalogu
- 8 nowych testów jednostkowych, 130/130 pass
- Weryfikacja na rshop dev: 11/14 zgodnych (2 słusznie zablokowane — nested CFN stacks)
- PR #53 otwarty: `fix/stack-tag-updater-safety-check` → main
- Git cleanup: usunięto 4 zmergowane lokalne branche

**Stan na koniec:**
- main czysty, zsynchronizowany
- PR #53 otwarty, czeka na merge
- rshop dev: 11/14 stacków otagowanych — pozostałe 2 (nested stacks) nie wymagają tagowania

**Następna sesja:**
- Merge PR #53
- Uruchomić apply-pack tagging mako/rshop --env prod po merge

---

## 2026-04-18 — FinOps rshop → toolkit bugs

**Co zrobiono:**
- Sesja FinOps rshop: raport MTD ($584.83, +30.1%), audit tagging runtime (11/27 stacków bez tagów)
- Znaleziono i naprawiono bug: `stack-tag-updater.py:115` — `Project = infra-rshop` zamiast `rshop` (fix: `project_cfg.get("project") or project`)
- Uruchomiono apply-pack tagging dev → 10/10 stacków zablokowanych przez safety check

**Zidentyfikowane bugi do naprawy:**
1. `validate_tag_only_changeset` zbyt konserwatywny — blokuje tag-only propagation (resource change w changesecie). Wymaga inspekcji `ChangeSource` / `Details` i przepuszczenia zmian gdzie jedyną zmianą są tagi
2. `create_change_set` nie przekazuje `Capabilities: [CAPABILITY_NAMED_IAM]` → IAM stacki zawsze blokowane

**Stan na koniec:**
- `tools/finops_tagging/stack-tag-updater.py` — fix Project tag value (w main? do sprawdzenia)
- Tagowanie rshop dev zablokowane do czasu naprawy toolkitu

**Następna sesja:**
- Naprawić `validate_tag_only_changeset` — tag-only changeset detection
- Naprawić `CAPABILITY_NAMED_IAM` w create_change_set
- Ponowić apply-pack tagging mako/rshop --env dev po naprawie

---

## 2026-04-18 — apply-pack tagging mako/rshop prod (finalizacja)

**Co zrobiono:**
- PR #54 zmergowany (`fix/tagging-env-not-passed-to-make`)
- Uruchomiono `toolkit apply-pack tagging mako/rshop --env prod`
- Wynik: 12/13 stacków already compliant, 1 blocked (root `prod` — nested stacks)
- Root `prod` stack: 0 tagów, changeset cascaduje do ALBStack/CFStack/DBStack/ECSStack/IAMStack/S3Stack/SGStack/VPCStack → safety check słusznie blokuje
- Root stack wymaga tagowania przez IaC (nie możliwe przez toolkit ze względu na nested-stack propagation)

**Stan końcowy rshop tagging:**
- dev: 11/14 compliant (3 nested-stack roots blocked)
- prod: 12/13 compliant (root `prod` blocked)
- Toolkit działa poprawnie — ograniczenie to architektura CFN nested stacks

**Następna sesja:**
- Zdecydować kolejne zadanie: ALB scaffold, devops-toolkit-ui sync, lub inne

---

## 2026-04-18 — fix tagging ENV not passed to make (PR #54)

**Co zrobiono:**
- Bug: `run_dry_run` / `run_apply` w `toolkit/executors/tagging.py` używały `env` do wykrywania stacków, ale nie przekazywały `ENV=<value>` do komendy `make` → `stack-tag-updater.py` zawsze tagował z `Environment=dev`
- Branch: `fix/tagging-env-not-passed-to-make`
- Fix: dodano `cmd.append(f"ENV={env}")` w `run_dry_run` i `run_apply` gdy `env` jest ustawiony
- 2 testy regresyjne: `test_dry_run_passes_env_to_make`, `test_apply_passes_env_to_make`
- 132/132 testów pass
- PR #54 otwarty

**Stan na koniec:**
- main zsynchronizowany (PR #53 zmergowany przed tą sesją)
- PR #54 otwarty, czeka na merge
- Po merge: uruchomić `toolkit apply-pack tagging mako/rshop --env prod`

**Następna sesja:**
- Merge PR #54
- `toolkit apply-pack tagging mako/rshop --env prod`

---

<!-- Template kolejnej sesji:

## YYYY-MM-DD — [opis zadania]

**Co zrobiono:**
- 

**Stan na koniec sesji:**
- 

**Następna sesja:**
- 

-->
