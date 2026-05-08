# devops-toolkit — Session Log

Format: data, co zrobiono, gdzie skończono, co następne.

---

## 2026-05-08 — Governance Foundation P0/P1 — implementacja

**Branch:** `feat/governance-foundation-p0-p1`
**Plan:** `docs/superpowers/plans/2026-05-08-governance-foundation-p0-p1.md`
**Spec:** `docs/superpowers/specs/2026-05-08-governance-foundation-p0-p1-design.md`

**Zrobione w tej sesji (Tasks 1–2):**
- ✅ Task 1: `collectors/` jako Python package (`__init__.py`, error classes, `pyproject.toml`)
  - commit `122d61d`
  - `collectors/aws/{organizations,iam,cloudtrail}/errors.py` — bez importów z `toolkit.*`
  - `pyproject.toml` — dodano `collectors*` do packages.find
- ✅ Task 2: Fixtury testowe (10 plików)
  - commit `e117264` + fix `ed4c6ef`
  - `tests/fixtures/aws/organizations/` (7 JSON), `/iam/credential_report.csv`, `/cloudtrail/` (2 JSON)
  - CSV: nagłówek w linii 1, root `<123456789012>` w linii 2, brak BOM
  - Fix: `lookup_events_move_response.json` — zastąpiono `999999999999`/`888888888888` → `222222222222`/`123456789012`

**Sesja kontynuowana — Tasks 3–10 ZROBIONE:**

- ✅ Task 3: `OrganizationsCollector.collect_accounts()` — commit `bd4a5e7`
- ✅ Task 4: `collect_ou_tree()` + `check_management_account()` — commit `ee88be4`
- ✅ Task 5: `SCPCollector` (4 metody, 6 testów) — commit `9604bd5`
- ✅ Task 6: `CredentialReportCollector` (5 metod, 9 testów) — commit `e0f8acc`
- ✅ Task 7: `TestGenerateAndWait` (2 testy retry/timeout) — commit `1e726b2`
- ✅ Task 8: `CloudTrailLookupCollector` (graceful degradation, 8 testów) — commits `95a24aa`, `37ba6aa`
- ✅ Task 9: Docs PL — `docs/operator/governance-audit.md` + `docs/architecture/governance-commands.md` — commit `d29aae8`
- ✅ Task 10: 33/33 tests, contract-check PASS, lint PASS, branch pushed — commit `d29aae8`

**Stan na koniec sesji:**
- Branch `feat/governance-foundation-p0-p1` — PUSHED ✅
- 33 testów jednostkowych, 0 failures
- contract-check PASS, lint PASS
- Następna faza: P2 — Plugin `root-governance` + pack `governance-root`

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

## 2026-04-30 — FinOps hardening + AI boundary guard + CLI semantics (P0/P1/P2)

**Co zrobiono:**
- Branch: `feat/finops-hardening-ai-boundary`
- **P0:** Canonical `CostRecord` dataclass (`toolkit/finops/cost_record.py`)
  - `CostRecord(service, usage_type, amount_usd, period, environment, tags)` + `to_dict()`
  - `from_legacy_summary()` i `from_modern_service()` — fabryki bridging oba pipeline'y
  - `normalize-cost.py` używa CostRecord wewnętrznie; JSON output (legacy schema) niezmieniony
  - `toolkit/finops/normalize.py` dostał `to_cost_records()` — przelicza modern output → lista CostRecord
- **P1 (SECURITY):** AI boundary enforcement (`toolkit/ai_boundary.py`)
  - `BoundaryViolationError(RuntimeError)` — propagowany, nie tłumiony
  - `assert_ai_safe_path(path)` — guard oparty na `Path.parts`, whitelist: `{"sanitized", "findings"}`
  - Guard podłączony do `engine/evaluate-rules.py`, `engine/rules-engine.py`, `toolkit/commands/finops_report.py`
  - W `finops_report.py`: `except BoundaryViolationError: raise` przed `except Exception: pass` — nie tłumi enforcement
- **P2:** Prefiksy `[inspect]`/`[audit]`/`[apply]` w `help=` CLI (tylko metadata, bez zmian logiki)
- Testy: 175 nowych, łącznie 3451 pass, 9 fail (pre-existing na main — test isolation issue)
- `make contract-check` PASS

**8 commitów:**
- `48f7d04` feat(finops): add CostRecord dataclass with factory functions
- `3ded0e1` fix(finops): to_dict() returns tags copy, guard None top_services
- `79f1105` refactor(finops): use CostRecord internally in legacy normalize-cost.py
- `465173e` fix(finops): fix misleading comment and guard sys.path insert in normalize-cost
- `bfd6a38` feat(finops): add to_cost_records() conversion helper
- `2865aa2` feat(security): add AI boundary guard with BoundaryViolationError
- `b73a44b` feat(security): wire AI boundary guard to findings read call-sites
- `a3dd513` feat(cli): add semantic intent prefixes [inspect][audit][apply] to commands

**Stan na koniec sesji:**
- Branch gotowy do PR
- AI boundary code-enforced (nie tylko konwencja)
- CostRecord canonical typed model bridging legacy + modern FinOps pipeline

**Następna sesja:**
- Otworzyć PR: `feat/finops-hardening-ai-boundary` → main

---

## 2026-04-30 — FinOps live mode + Operator UI + LLZ WAF readonly merged

**Co zrobiono:**
- Repo: `/Users/jaroslaw.golab/projekty/devops/devops-toolkit`
- PR #58 zmergowany:
  - Branch: `feat/finops-live-mode`
  - Merge commit: `9745e9a`
  - Zakres: `toolkit finops-report` dostał `--mode live|snapshot`, `--period custom`, `--start/--end`, wiring do `resolve_period()` i `build_finops_model()`, sekcję `Jakość danych`, Estimated=true jako warning, Tax jako non-operational cost
  - Operator UI: formularz FinOps obsługuje `mtd`, `last-full-month`, `custom`, `mode=live|snapshot`, `start/end`, helper messages live/snapshot; backend przekazuje opcje do CLI
  - Testy: `make contract-check` PASS; `pytest tests/unit/ -q -k "ui or finops or report"` PASS poza sandboxem; `tests/test_operator_console_v3.py` PASS
- PR #59 zmergowany:
  - Branch: `feat/llz-readonly-packs`
  - Merge commit: `ff9cd46`
  - Zakres: pack `llz-waf-readonly`, pluginy `llz-guardduty`, `llz-scp`, `llz-cloudtrail`, `llz-config`, `llz-tagging`, `llz-observability`, plugin `cfn-messaging-audit`, testy jednostkowe i plany superpowers
  - Testy: `make contract-check` PASS; `pytest tests/unit/test_llz_waf_readonly_pack.py tests/unit/test_cfn_messaging_audit.py -q` → 149 passed

**Stan na koniec sesji:**
- Lokalny `main` w `devops-toolkit` zsynchronizowany z `origin/main`
- `git status`: czysty względem tracked files (`## main...origin/main`)
- Ostatnie commity:
  - `ff9cd46 Merge pull request #59 from JarekGie/feat/llz-readonly-packs`
  - `9745e9a Merge pull request #58 from JarekGie/feat/finops-live-mode`
- Nie ma aktywnego brancha roboczego w toolkit — wszystko zmergowane do main

**Następna sesja:**
- Manualny smoke UI:
  - `toolkit ui --project-root /path/to/project --port auto --no-open`
  - FinOps tab → Custom range → mode Live → group by Service → format Markdown
- Manualny smoke CLI z aktywnymi AWS credentials:
  - `toolkit finops-report rshop --period custom --start 2026-04-01 --end 2026-05-01 --mode live --audience executive --group-by service --format md`
- Opcjonalnie zweryfikować, czy pack `llz-waf-readonly` ma być dopięty do publicznej dokumentacji/command catalog.

---

## 2026-05-01 — rshop FinOps forensic: Data Export + runtime join read-only

**Co zrobiono:**
- Projekt: `/Users/jaroslaw.golab/projekty/mako/aws-projects/infra-rshop`
- Account rshop: `943111679945`, region `eu-central-1`, profile `rshop`
- Billing/management profile: `mako-dc`, account `864277686382`
- Klasyczny CUR nie istnieje: `aws cur describe-report-definitions --profile mako-dc --region us-east-1` zwrócił `ReportDefinitions: []`
- Znaleziono nowszy AWS BCM Data Export:
  - Export: `test`
  - ARN: `arn:aws:bcm-data-exports:us-east-1:864277686382:export/test-6deef56f-73db-49d9-926f-3c57ea271ffd`
  - Status: `HEALTHY`
  - LastRefreshedAt: `2026-04-30T19:04:34Z`
  - Destination: `s3://testdataexportjanmarchel/test/test/data/BILLING_PERIOD=2026-04/test-00001.csv.gz`
  - Format: `TEXT_OR_CSV`, `GZIP`
  - `INCLUDE_RESOURCES=TRUE`, `TIME_GRANULARITY=MONTHLY`
- Odczytano istniejący export read-only do `/tmp/rshop-cur-2026-04.csv.gz`; nie tworzono exportu, nie uruchamiano Athena, nie modyfikowano S3/Glue/tagów/AWS resources
- Data Export ma wymagane kolumny line item (`line_item_resource_id`, `line_item_usage_type`, `line_item_product_code`, `line_item_unblended_cost`, `line_item_usage_account_id`, `line_item_usage_start_date`, `line_item_line_item_type`) oraz zbiorczą kolumnę JSON `resource_tags`; nie ma osobnych kolumn `resource_tags_user_environment/project`
- Forensic Data Export dla rshop April 2026:
  - `TAGGED_IN_CUR`: `$488.287400` / 50.46%
  - `UNTAGGED_RESOURCE_IN_CUR`: `$257.860038` / 26.65%
  - `BILLING_ARTIFACT`: `$180.960000` / 18.70%
  - `NO_RESOURCE_ID`: `$40.517868` / 4.19%
- Focus:
  - Fargate/ECS: `$263.345090` total; `$109.077232` untagged resource in CUR; `$105.317858` tagged; `$48.95` tax
  - VPC/PublicIPv4/VpcEndpoint: `$217.012576`; `$107.552401` untagged resource in CUR; `$109.460175` tagged
  - CloudWatch: `$82.474224`; `$36.744759` untagged resource; `$25.044927` no resource id; `$15.43` tax; `$5.254538` tagged
  - Tax: `$180.96`, expected billing artifact without `resource_id`
- Wykonano read-only join top 100 `UNTAGGED_RESOURCE_IN_CUR` z live runtime tags:
  - Zakres top 100: `$249.677894`
  - `A_live_tagged_billing_untagged`: `$61.776000` / 24.74% / 3 zasoby
  - `B_live_untagged`: `$13.969005` / 5.59% / 10 zasobów
  - `C_historical_or_ephemeral`: `$169.936491` / 68.06% / 83 zasoby
  - `D_no_runtime_lookup_possible`: `$3.996398` / 1.60% / 4 zasoby
- Najważniejsze ustalenia:
  - `rshop-prod-alb-heartbeat` Synthetics canary: `$36.56`, runtime `not_found` → historical/ephemeral
  - VPC endpoints `vpce-055c1e81bc384fe77`, `vpce-04a529e00f650ba57`, `vpce-0adbca724b31df149`: razem `$61.776`, teraz istnieją i mają `Environment=dev`, ale Data Export line item nie miał Environment
  - ECS/Fargate: `$97.469897` historyczne task ARN już niewidoczne runtime; `$6.914270` istniejące taski bez `Environment`, głównie jumphost dev/prod
  - ENI/PublicIPv4: `$35.906594` ENI historyczne/not_found; `$7.054735` ENI live bez `Environment`

**Artefakty:**
- Base audit dir: `/Users/jaroslaw.golab/projekty/mako/aws-projects/infra-rshop/.devops-toolkit/manual-audits/finops-tagging-live-20260430-212856/`
- Data Export report: `data-export-cur-forensic-report.md`
- Data Export summary: `normalized/data-export-cur-forensic-summary.json`
- Top 100 untagged IDs: `normalized/data-export-untagged-resource-ids.json`
- Runtime join summary: `normalized/data-export-runtime-join-summary.json`
- Runtime join report: `data-export-runtime-join-report.md`
- Local source copy: `/tmp/rshop-cur-2026-04.csv.gz`

**Stan na koniec sesji:**
- Audyt zachował read-only boundary: żadnych zmian w AWS, żadnego tworzenia CUR/Data Export/Athena/S3/Glue, żadnego tagowania
- Werdykt: wysoki `Environment absent` w CE/Data Export to mieszanka billing artifacts, historycznych/ephemeral resource IDs, line itemów bez runtime mapping oraz mniejszej liczby faktycznie live-untagged zasobów; CE "untagged" nie jest równoważne prostemu brakowi tagów na aktualnych zasobach runtime

**Następna sesja:**
- Jeśli potrzebny jest pełny coverage: rozszerzyć join z top 100 na wszystkie `UNTAGGED_RESOURCE_IN_CUR`
- Opcjonalnie read-only: porównać przypadki `A_live_tagged_billing_untagged` z CloudTrail tag events/deployment history, jeśli logi są dostępne bez zmian
- Opcjonalnie read-only: rozbić ECS task line items po timestampach/deploymentach, bez aktualizacji service

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
