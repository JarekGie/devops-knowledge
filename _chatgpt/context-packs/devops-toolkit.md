# ChatGPT Context Pack — devops-toolkit

Data aktualizacji: 2026-04-23

Ten plik jest syntetycznym kontekstem do pracy z ChatGPT/Codex nad projektem
`devops-toolkit`. Łączy informacje z vaulta `devops-knowledge` i z lokalnego repo
`~/projekty/devops/devops-toolkit`.

## 1. Executive Summary

`devops-toolkit` to lokalny, bezstanowy engine CLI do pracy operatorskiej DevOps/SRE:
audytów AWS, FinOps, IaC/Terraform, CloudFormation, LLZ, observability readiness,
raportów i lokalnej konsoli operatorskiej.

Aktualna decyzja architektoniczna:
po zakończeniu kampanii remediacji tagowania w projektach docelowych toolkit wchodzi w fazę
stabilizacji i refaktoru przed dalszą dużą ekspansją capability, zwłaszcza w obszarze LLZ provisioning.

Główna zasada architektury:

> Toolkit jest silnikiem. Nie posiada danych klientów. Wszystkie artefakty projektu
> żyją w repo klienta pod `.devops-toolkit/`.

Najważniejsze cechy:

- local-first, CLI-driven
- stateless engine
- contract-first
- read-only by default dla audytów
- dane raw nigdy nie trafiają do AI
- AI może dostać tylko `sanitized/` + `findings/`
- outputy są deterministycznymi artefaktami w repo projektu klienta

## 2. Lokalizacje

Repo główne:

```text
/Users/jaroslaw.golab/projekty/devops/devops-toolkit
```

Repo powiązane:

```text
/Users/jaroslaw.golab/projekty/devops/devops-toolkit-ui
/Users/jaroslaw.golab/projekty/devops/devops-toolkit-usage
/Users/jaroslaw.golab/projekty/devops/devops-console-light
```

Vault:

```text
/Users/jaroslaw.golab/projekty/devops/devops-knowledge
```

Najważniejsze notatki vaulta:

```text
60-toolkit/README.md
60-toolkit/command-catalog.md
60-toolkit/finops-reporting.md
60-toolkit/llz-audit.md
60-toolkit/observability-ready.md
20-projects/internal/devops-toolkit/context.md
20-projects/internal/devops-toolkit/next-steps.md
```

Najważniejsze pliki repo:

```text
README.md
ARCHITECTURE.md
docs/cli.md
docs/cli-public-api.md
docs/capability-status.md
docs/backlog.md
docs/platform/vnext.md
docs/platform/v2-roadmap.md
pyproject.toml
toolkit/cli.py
toolkit/commands/
toolkit/plugins/
packs/
audits/
collectors/
normalizers/
sanitizers/
rules/
tests/unit/
```

## 3. Stan Repo

Na moment zebrania kontekstu:

```text
branch: main
status: main...origin/main
```

Istnieją nieśledzone pliki/katalogi, których nie należy usuwać ani nadpisywać bez
osobnej decyzji:

```text
packs/llz-waf-readonly/
tests/unit/test_cfn_messaging_audit.py
tests/unit/test_llz_waf_readonly_pack.py
toolkit/plugins/cfn_messaging_audit/
toolkit/plugins/llz_cloudtrail/
toolkit/plugins/llz_config/
toolkit/plugins/llz_guardduty/
toolkit/plugins/llz_observability/
toolkit/plugins/llz_scp/
toolkit/plugins/llz_tagging/
```

Wniosek: pracując w repo, zakładaj brudny worktree i chroń istniejące nieśledzone
zmiany.

## 4. Model Architektury

Pipeline audytu:

```text
collectors -> normalizers -> sanitizers -> rules -> AI/report
```

Artefakty per run:

```text
<project-root>/.devops-toolkit/runs/<run-id>/
  raw/         # surowe AWS/API, nigdy do AI
  normalized/  # agregaty, nadal dane klienta
  sanitized/   # bez identyfikatorów, safe for AI
  findings/    # wyniki reguł
  results/
  report.md
  manifest.yaml
```

Konfiguracja ma 3 warstwy:

| Warstwa | Lokalizacja | Rola |
|---|---|---|
| Engine | `config/global.yaml` w repo toolkit | wersja, severity, defaulty |
| Workspace | `~/.config/devops-toolkit/workspace.yaml` | lokalne ścieżki, klienci, profile |
| Project | `<client-repo>/.devops-toolkit/project.yaml` | cloud, region, envs, IaC, tagi |

Project resolution order:

1. `--project-root`
2. istniejąca ścieżka jako argument
3. `DEVOPS_TOOLKIT_PROJECT_ROOT`
4. CWD upward scan for `.devops-toolkit/project.yaml`
5. workspace slug / `client/project`

## 5. CLI Public API

Źródło prawdy: `docs/cli-public-api.md` i `toolkit --help`.

### CORE

Stabilne, operator-facing:

```bash
toolkit onboard
toolkit here
toolkit work
toolkit audit
toolkit audit-pack <pack>
toolkit apply-pack <pack>
toolkit aws-login
toolkit aws-logout
toolkit aws-context
toolkit doctor
toolkit check
toolkit contract check
toolkit contract show
toolkit contract verify
toolkit contract init
toolkit clients
toolkit projects <client>
toolkit project init <client> <project>
toolkit project validate
toolkit install
```

### ADVANCED

Specjalistyczne, działające, wymagają wiedzy operatorskiej:

```bash
toolkit terraform init-project
toolkit terraform audit-module
toolkit terraform audit-modules
toolkit terraform check-modules
toolkit terraform bootstrap-backend
toolkit finops-report
toolkit log-report
toolkit estimate
toolkit drift
toolkit discover-aws
toolkit competency
toolkit index
toolkit path
toolkit project refresh
toolkit ui
toolkit client add
```

### EXPERIMENTAL / PREVIEW

```bash
toolkit pricing
toolkit terraform migrate
toolkit terraform <project>  # bare legacy-ish path
toolkit e2e
toolkit log-report           # GCP archived logs preview
```

### LEGACY / DEPRECATED

```bash
toolkit init-project  # alias do toolkit terraform init-project
toolkit reinit        # legacy alias; używać toolkit project refresh
toolkit service create
toolkit project bootstrap
```

## 6. Audit Packs / Capabilities

Zidentyfikowane packi:

```text
finops-basic
governance-basic
tagging
cloudformation-audit
ecs-delivery-competency
llz-basic
aws-logging
aws-logging-patch-plan
observability-ready
terraform-standard
finops-billing-gap
finops-tagging-reconciliation
finops-tagging-runtime
llz-waf-readonly        # nieśledzony, w toku
```

Uwaga strategiczna:
przed dodawaniem nowych major audit packs priorytetem jest konsolidacja istniejących capability,
szczególnie tam, gdzie nakładają się obszary tagging, governance i FinOps attribution.

Zidentyfikowane audit definitions:

```text
aws_cost_breakdown
aws_cost_full
aws_cost_hotspots
aws_idle_storage
aws_tagging
finops_tagging_reconciliation
finops_tagging_runtime
```

## 7. Aktualne Funkcjonalności

### AWS infrastructure audit

Status wg `docs/capability-status.md`: stable.

Pełny pipeline:

```text
collect -> normalize -> sanitize -> AI/report
```

Zastosowanie:

- audyty infrastruktury AWS
- raportowanie findings
- praca z artefaktami `.devops-toolkit/runs/`

### AWS logging / observability audit

Komendy:

```bash
toolkit audit-pack aws-logging
toolkit audit-pack aws-logging --patch-plan
toolkit audit-pack observability-ready
```

`aws-logging` sprawdza:

- ECS service / task definition / `logConfiguration`
- CloudWatch log groups i aktywność streamów
- ALB access logs
- CloudFront logging
- ElastiCache slow/engine logs
- VPC Flow Logs
- WAF logging
- mapowanie do Terraform

Artefakty:

```text
logging-matrix.json
resources.json
report.md
terraform-mapping.md
suspicious-or-empty-destinations.json
```

`aws-logging-patch-plan` generuje plan, nie kod i nie `terraform apply`:

```text
patch-plan.json
plan.md
changed-files.md
risk-notes.md
```

`observability-ready` jest decision layer bez AWS calls:

- czyta artefakty z `aws-logging`
- produkuje `readiness-summary.json`
- produkuje `pre-apply-review.md`
- `ready_to_apply = true` tylko jeśli brak BLOCKER
- `ready_to_operate = false` w v1, bo post-apply verification nie jest zaimplementowane

### FinOps reporting

Komendy:

```bash
toolkit finops-report <project> --period mtd --group-by service
toolkit finops-report <project> --period mtd --group-by usage-type --audience technical
toolkit finops-report <project> --period last-full-month --group-by service
toolkit finops-report <project> --period mtd --env prod --format both
```

Możliwości:

- AWS Cost Explorer integration
- MTD i last-full-month
- grupowanie po service albo usage-type
- `executive` vs `technical`
- markdown, JSON, both, confluence
- delta i heurystyki zmian kosztowych
- tagging coverage / untagged cost
- env filter po tagu `Environment`

Artefakty:

```text
.devops-toolkit/reports/finops/
  mtd-report.md
  mtd-report.pl.md
  mtd-report.json
  mtd-report.confluence.md
  last-full-month-report.md
```

### Tagging / CloudFormation apply-pack

Komendy:

```bash
toolkit audit-pack tagging <project>
toolkit apply-pack tagging <project> --env dev --dry-run
toolkit apply-pack tagging <project> --env dev
```

Właściwości:

- audit-first enforcement
- multi-env guardrail: `--env` wymagane przy wielu środowiskach
- CFN-only dla apply
- partial-safe model
- blocked stack nie oznacza globalnego crasha, tylko status `partial`

Statusy per stack:

```text
ALREADY_COMPLIANT
SKIPPED_NO_CHANGE
APPLIED
BLOCKED_RESOURCE_CHANGE
BLOCKED_CAPABILITY_REQUIRED
FAILED_OTHER
```

### Terraform

Komendy:

```bash
toolkit terraform init-project
toolkit terraform bootstrap-backend
toolkit terraform audit-module
toolkit terraform audit-modules
toolkit terraform check-modules
toolkit terraform init-module
```

`terraform init-project`:

- generuje projekt Terraform z layoutem envs
- wzorzec domyślny: `app-stack`
- wspiera flagi m.in.:
  - `--with-rds`
  - `--with-redis`
  - `--with-cloudfront`
  - `--with-sqs`
  - `--with-documentdb`
  - `--with-db-jumphost`
  - `--with-worker`
  - `--enable-scheduler`
  - `--no-dns`

Generuje m.in.:

```text
envs/<env>/main.tf
envs/<env>/backend.tf
envs/<env>/versions.tf
envs/<env>/terraform.tfvars
README.md
.gitignore
.devops-toolkit/project.yaml
```

LLZ note:

- projekt po `terraform init-project` ma być strukturalnie LLZ-ready
- operator uzupełnia `client.name`, `cloud.profile`, `finops.billing_profile`

### LLZ audit

Komenda:

```bash
toolkit audit-pack llz-basic
```

Charakter:

- statyczny audit lokalny
- bez AWS calls
- sprawdza Terraform project conformance względem Light Landing Zone

Obszary:

- A: struktura projektu
- B: standard scaffoldu
- C: polityki

Przykładowe reguły:

- `.devops-toolkit/project.yaml` istnieje
- `iac_type: Terraform`
- `envs/` ma środowiska
- każdy env ma `main.tf`
- `backend.tf` istnieje i używa S3 backend
- brak placeholderów w backendzie
- `client.name`, `cloud.profile`, `finops.billing_profile` uzupełnione
- scheduler dev/qa on, prod off
- `enforce_tagging`, `enforce_finops`

### Contract Engine

Komendy:

```bash
toolkit contract check
toolkit contract show
toolkit contract verify
toolkit contract init
```

Obsługiwane kontrakty wg `docs/cli-public-api.md`:

```text
PROJ-001 project.yaml exists
PROJ-002 project.yaml required fields
STATE-001 Terraform backend uses S3
STATE-002 No committed .tfstate files
STATE-003 Separate state key per environment
TAG-001 Required tags configured in project.yaml
TF-004 No hardcoded AWS region or account ID
MOD-001 Reusable modules have required files
SEC-001 No hardcoded secrets in IaC files
SEC-002 No explicitly public resources
```

### Doctor / Check / Self-Test

`toolkit doctor`:

- runtime checks
- project config checks
- CFN checks
- AWS credential checks

`toolkit check`:

- 9-step dry-run sanity pipeline
- fail-fast on ERROR
- skips IaC-specific steps when not applicable

Pipeline:

```text
1. toolkit doctor
2. toolkit contract verify
3. toolkit aws-context
4. toolkit audit-pack tagging
5. toolkit audit-pack finops-basic
6. toolkit audit-pack finops-tagging-runtime
7. toolkit apply-pack tagging --dry-run
8. toolkit audit-pack terraform-standard
9. toolkit audit-pack llz-basic
```

`toolkit self-test`:

```bash
toolkit self-test --scope quick
toolkit self-test --scope project
toolkit self-test --scope release
```

### Operator UI

Komenda:

```bash
toolkit ui
toolkit ui --project-root <path>
toolkit ui --port 9000 --no-open
toolkit ui --port auto
```

Status: lokalny UI operatorski, FastAPI + HTMX.

Możliwości:

- renderowanie raportów
- FinOps report UI
- copy markdown / copy to Confluence
- AWS session status
- gotowy command do `awsume`, jeśli brak sesji
- port fallback
- env-aware tagging buttons
- partial-safe rendering dla apply tagging

Ograniczenia:

- lokalne użycie
- brak auth
- nie traktować jako zewnętrzny serwis

### GCP archived log analysis

Komenda:

```bash
toolkit log-report
```

Status: preview/operator-scoped.

Zakres:

- analiza historycznych shardów logów w GCS
- stdout verified path
- stderr zależy od środowiska
- nie jest ogólną platformą GCP observability

## 8. Pluginy i Moduły

Istniejące pluginy śledzone / w repo:

```text
aws_logging_audit
aws_logging_patch_plan
finops_billing_gap
llz_policy_conformance
llz_project_structure
llz_scaffold_conformance
observability_ready
terraform_module_auditor
```

Nieśledzone / w toku:

```text
cfn_messaging_audit
llz_cloudtrail
llz_config
llz_guardduty
llz_observability
llz_scp
llz_tagging
```

Plugin concept z vaulta:

- plugin ma nazwę, opis, input schema, output schema
- input/output walidowane
- plugin nie zna innych pluginów
- read-only default
- write operations wymagają jawnego potwierdzenia / dry-run / audit-first
- output powinien być valid JSON nawet przy błędzie

## 9. Security / Data Handling

Twarde zasady:

- raw data zostają lokalnie w repo klienta
- raw data nigdy do AI
- normalized data nadal traktować jako client data
- do AI tylko sanitized findings + identifier-free rule findings
- toolkit repo nie powinno zawierać artefaktów klientów
- `.devops-toolkit/runs/` powinno być gitignored w repo klientów
- `project.yaml` jest konfiguracją projektu i może być commitowany, ale bez sekretów
- AWS credentials nie są przechowywane w toolkit

## 10. Testy

Repo ma rozbudowaną bazę testów:

- `tests/unit/`
- `tests/integration/terraform/`
- `tests/smoke/`

Obszary testów obejmują m.in.:

- CLI dispatch/errors
- project resolution
- doctor/check
- AWS context/login guard
- contract engine
- FinOps reports/trends/forecast/allocation
- tagging
- CFN lint/inspector/tagging
- terraform init/audit/bootstrap/parser
- LLZ plugins/audit
- observability-ready
- aws-logging-audit / patch-plan
- self-test
- UI command/actions
- GCP log forensics

Typowe komendy:

```bash
pytest tests/unit/ -q
pytest tests/unit -k tagging -q
make contract-check
make contract-verify
.venv/bin/python -m toolkit.cli --help
```

## 11. Roadmapa — Stan Z Vaulta i Repo

Uwaga: `60-toolkit/roadmap.md` w vaulcie jest starsza i opisuje wczesne fazy MVP.
Aktualniejsze źródła to `docs/capability-status.md`, `docs/platform/vnext.md`,
`docs/platform/v2-roadmap.md`, `docs/backlog.md`.

### Aktualny baseline

Według `docs/capability-status.md`:

- repo było zamrożone po stabilizacji 2026-04-16
- baseline obejmuje onboarding, Terraform scaffold generation, backend bootstrap,
  checks i operator-first local workflows
- nowe zmiany powinny iść przez osobne branche
- `toolkit ui` pozostaje lokalne/experimental
- AWS jest canonical provider path
- GCP log analysis jest preview

### vNext priority order

Z `docs/platform/vnext.md`:

| Priorytet | Epic | Status |
|---|---|---|
| P0 | Terraform Parity | planned |
| P1 | toolkit reinit / refresh config | planned, częściowo pokryte przez `project refresh` |
| P1 | Multi-project workflow | planned / częściowo istnieje workspace + resolution |
| P1 | AWS session management | planned / częściowo istnieje aws-login/context/UI status |
| P2 | FinOps Executive Report | planned / duża część już istnieje w `finops-report` |

### Terraform Parity

Najważniejszy strategiczny gap.

Wymagane tryby:

- Mode A: desired state / plan-based (`terraform plan` + `terraform show -json`)
- Mode B: runtime-based (AWS API, zgodnie z CFN semantics)
- Hybrid: deduplikacja po ARN/resource_id/canonical identity

Hard constraints:

- Terraform tagging apply nie może zakładać `locals.common_tags`
- toolkit nie uruchamia `terraform apply`
- dla Terraform generuje diff/patch/recommendation artifact, nie wykonuje zmian

Fazy:

1. IaC detection + routing logs
2. Terraform audit read-only
3. Terraform apply dry-run artifact generation
4. Hybrid parity + merged findings

### Platform v2

Status: design, not implemented.

Kierunek:

- template-driven generation zamiast Python string generation
- `architecture.yaml` jako richer project descriptor
- light landing zone modules
- pattern-level modules
- service types: `http`, `background`, `batch`
- module registry + versioning

Nie jest breaking change. v1 zostaje.

## 12. Długi Techniczne / Open Items

Z vaulta `20-projects/internal/devops-toolkit/next-steps.md`:

- cost normalization była oznaczona jako stub w starszym stanie
- FinOps findings sanitization była oznaczona jako stub w starszym stanie
- ALB scaffold fix: `alb_enable_https=false` + `alb_certificate_arn=null` z TODO
- Terraform provider auto-detection ma edge cases
- sprawdzić status `devops-toolkit-ui`
- zweryfikować `devops-toolkit-usage`
- dokończyć dokumentację kontraktów dla nowych capabilities
- uzupełnić templates command/plugin
- konteneryzacja toolkit
- publish do PyPI
- rozszerzenie coverage na GCP/Azure
- automatyczne triggery audytów po deploy

Korekta aktualności:

- `pyproject.toml` ma już `[project.scripts] toolkit = "toolkit.cli:main"`
- `pyproject.toml` ma już `boto3`, `fastapi`, `uvicorn`, `python-hcl2`, itd.
- `docs/backlog.md` zawiera starsze wpisy, z których część może być już rozwiązana.
  Przed pracą nad backlogiem trzeba zweryfikować każdy item w aktualnym kodzie.

Aktualne repo ma też aktywne nieśledzone prace LLZ/WAF/CFN messaging.

## 13. Typowy Operator Flow

Onboarding istniejącego repo:

```bash
cd ~/projekty/mako/aws-projects/infra-rshop
toolkit onboard
toolkit doctor
toolkit aws-login
toolkit work
toolkit check
```

Audyt:

```bash
toolkit audit
toolkit audit-pack tagging
toolkit audit-pack finops-basic
toolkit audit-pack aws-logging
toolkit audit-pack observability-ready
```

Tagging CFN:

```bash
toolkit audit-pack tagging
toolkit apply-pack tagging --env dev --dry-run
toolkit apply-pack tagging --env dev
```

Terraform scaffold:

```bash
toolkit terraform init-project \
  --project-name acme-web \
  --cloud aws \
  --region eu-central-1 \
  --pattern app-stack \
  --envs dev,qa,prod
```

FinOps:

```bash
toolkit finops-report . --period mtd --group-by service
toolkit finops-report . --period last-full-month --audience technical --format both
```

## 14. Jak Pracować Z Kodem

Zasady praktyczne:

- Nie ruszaj nieśledzonych plików bez potrzeby.
- Najpierw sprawdź, czy zmiana dotyka public API, kontraktu, czy tylko implementacji.
- Jeśli zmienia się CLI, sprawdź `docs/cli-public-api.md`.
- Jeśli zmienia się operator flow, sprawdź `docs/operator/*` i vault `60-toolkit/`.
- Jeśli zmienia się capability, sprawdź `docs/capability-status.md` i `docs/capabilities/*`.
- Jeśli zmienia się architektura, sprawdź `docs/kontrakty/*`.
- Po zmianie dokumentacji repo, trzeba zmirrorować istotny kontekst do vaulta `60-toolkit/`.

Preferowane testy zależnie od zmiany:

```bash
.venv/bin/python -m toolkit.cli --help
pytest tests/unit/test_cli_dispatch.py -q
pytest tests/unit/test_project_resolution.py -q
pytest tests/unit/test_doctor.py -q
pytest tests/unit/test_check_cmd.py -q
pytest tests/unit/test_finops_report.py -q
pytest tests/unit/test_aws_logging_audit.py -q
pytest tests/unit/test_observability_ready.py -q
pytest tests/unit/terraform -q
make contract-check
```

## 15. Ważne Rozbieżności W Dokumentacji

Niektóre notatki vaulta są starsze niż repo.

Przykłady:

- `60-toolkit/roadmap.md` opisuje wczesne MVP i nie odzwierciedla pełnego obecnego CLI.
- `60-toolkit/plugin-system.md` jest bardziej koncepcyjny niż aktualny stan plugin loadera.
- `20-projects/internal/devops-toolkit/next-steps.md` wskazuje stuby, które mogą być częściowo lub całkowicie naprawione.
- `60-toolkit/architecture-overview.md` wygląda na zanieczyszczony treścią scaffoldingu vaulta; nie traktować jako source of truth bez weryfikacji.

Priorytet źródeł:

1. Aktualny kod w `~/projekty/devops/devops-toolkit`
2. `README.md`, `docs/cli-public-api.md`, `docs/capability-status.md`, `ARCHITECTURE.md`
3. Vault `60-toolkit/*` jako mapa operatorska
4. Stare backlogi jako hipotezy, nie fakty

## 16. Szybki Prompt Dla ChatGPT

Możesz wkleić:

```text
Pracujesz nad lokalnym repo devops-toolkit:
/Users/jaroslaw.golab/projekty/devops/devops-toolkit

To stateless CLI engine do audytów AWS, FinOps, IaC/Terraform, CloudFormation,
LLZ i observability readiness. Dane klientów nie są przechowywane w repo toolkitu;
artefakty trafiają do <client-repo>/.devops-toolkit/runs/.

Zasady:
- nie ruszaj nieśledzonych plików bez potrzeby
- najpierw sprawdź git status
- jeśli zmieniasz CLI, sprawdź docs/cli-public-api.md
- jeśli zmieniasz capability, sprawdź docs/capability-status.md
- jeśli zmieniasz docs w repo, zmirroruj istotny kontekst do vaulta 60-toolkit/
- raw AWS data nigdy do AI; tylko sanitized/findings

Aktualne capability:
- audit/audit-pack/apply-pack
- aws-login/aws-context/doctor/check
- finops-report
- aws-logging + patch-plan + observability-ready
- LLZ audit
- Terraform init-project/audit/bootstrap
- Contract Engine
- local FastAPI/HTMX UI
- GCP archived log report preview

Strategiczna roadmapa:
P0 Terraform Parity, potem project refresh/multi-project/AWS session, potem FinOps executive.
Platform v2 jest design-only: template-driven, architecture.yaml, light landing zone modules.
```

## 17. Files Inspected

Vault:

```text
60-toolkit/README.md
60-toolkit/roadmap.md
60-toolkit/architecture-overview.md
60-toolkit/command-catalog.md
60-toolkit/plugin-system.md
60-toolkit/finops-reporting.md
60-toolkit/llz-audit.md
60-toolkit/observability-ready.md
20-projects/internal/devops-toolkit/context.md
20-projects/internal/devops-toolkit/next-steps.md
```

Repo:

```text
README.md
ARCHITECTURE.md
docs/cli.md
docs/cli-public-api.md
docs/capability-status.md
docs/backlog.md
docs/platform/vnext.md
docs/platform/v2-roadmap.md
docs/roadmap.md
docs/architecture/toolkit-ecosystem-remediation-plan.md
pyproject.toml
toolkit/commands/*
toolkit/plugins/*
packs/*
audits/*
collectors/*
normalizers/*
sanitizers/*
rules/*
tests/*
```
