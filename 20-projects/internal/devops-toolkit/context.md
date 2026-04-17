# devops-toolkit — Kontekst

## Aktualny stan projektu

```
Faza:       [ ] prototyp  [x] MVP  [ ] produkcja
Wersja:     0.1.0
Commity:    302
Ostatnia zmiana: 2026-04-17 (feat: observability-ready v1)
```

## Co to jest

Stateless CLI do audytowania infrastruktury AWS. Zbiera dane z AWS API, przetwarza je przez pipeline collect → normalize → sanitize → rules → raport AI. Dane klienta nigdy nie trafiają do repozytorium toolkit — żyją wyłącznie w klienckiej repo pod `.devops-toolkit/`.

Uruchamia się jako: `toolkit <komenda> [opcje]`

## Co działa (stabilne)

- Pełny pipeline audytów: collect → normalize → sanitize → rules → findings
- Audit packi: `finops-basic`, `tagging`, `aws-logging`, `ecs-delivery-competency`, `terraform-standard`, `observability-ready`, `llz-basic`, `cloudformation-audit`
- FinOps reporting: trend kosztów, cost breakdown per env/service, untagged allocation
- Estymacja kosztów (3 scenariusze: cheap/balanced/enterprise) via AWS Bulk Pricing API
- Generowanie scaffoldu Terraform (`toolkit terraform init-project`)
- CloudFormation linting i drift detection
- Operator console — FastAPI UI na porcie 8000 z kolejką runów
- Onboarding projektów (`toolkit onboard`, `toolkit doctor`)
- Contract enforcement (`make contract-check`) — reguły architektoniczne weryfikowane w CI
- 85+ plików testów jednostkowych

## Co jest w budowie / niekompletne

- **Cost normalization** — `normalizers/cost/normalize-cost.py` to stub (TODO w linii 10)
- **FinOps findings sanitization** — `sanitizers/sanitize-finops-findings.py` to stub (`print("TODO sanitize findings")`)
- **Terraform provider auto-detection** — częściowa implementacja, edge cases z HCL2 parsing
- Scaffold emituje `alb_enable_https = false + alb_certificate_arn = null` z TODO (zarejestrowany regresja w testach)

## Architektura w skrócie

```
CLI (toolkit/cli.py ~1200 linii)
  └─ Command Router (toolkit/commands/ — 40+ komend)
       └─ Audit Engine
            ├─ Collectors (collectors/aws/*) — tylko AWS API, nie importują nic z toolkit
            ├─ Normalizers (normalizers/*) — aggregacje, bez AWS API
            ├─ Sanitizers (sanitizers/*) — usuwają ARNy, account ID, nazwy zasobów
            ├─ Rules Engine (engine/rules-engine.py)
            └─ AI Input — TYLKO sanitized/ + findings/ (nigdy raw/)

Dane per run: <client-repo>/.devops-toolkit/runs/<RUN_ID>/
  raw/        ← surowe AWS (NIGDY do AI)
  normalized/ ← agregaty (nie do AI)
  sanitized/  ← bez identyfikatorów (safe for AI)
  findings/   ← wyniki reguł
  manifest.yaml
```

## Konfiguracja (3 warstwy)

| Warstwa | Lokalizacja | Co zawiera |
|---------|-------------|-----------|
| Engine | `config/global.yaml` (toolkit repo) | wersja, severity, defaults |
| Workspace | `~/.config/devops-toolkit/workspace.yaml` | ścieżki klientów, AWS profile |
| Project | `<client-repo>/.devops-toolkit/project.yaml` | cloud provider, region, account ID, envs |

Zmienna środowiskowa do override: `DEVOPS_TOOLKIT_PROJECT_ROOT`

## Środowisko dev

```bash
# Setup
cd /Users/jaroslaw.golab/projekty/devops/devops-toolkit
toolkit install          # tworzy .venv i instaluje zależności

# Uruchomienie
.venv/bin/python -m toolkit.cli --help
# lub bezpośrednio przez bash wrapper:
bash cli/toolkit --help

# Testy
pytest tests/unit/ -q
pytest tests/unit -k tagging -q     # filtrowane
make contract-check                  # walidacja kontraktów architektonicznych
make contract-verify                 # pełna weryfikacja: contract + lint + test

# Operator console (UI)
uvicorn app:app --port 8000
```

Python 3.10+ wymagany. Resolver kolejność: `.venv` → `$VIRTUAL_ENV` → `python3.13/3.12/3.11/3.10` → `python3`

## Powiązane repozytoria

| Repo | Ścieżka lokalna | Rola |
|------|----------------|------|
| toolkit (engine) | `../devops-toolkit` | główne repozytorium |
| toolkit UI | `../devops-toolkit-ui` | frontend operator console |
| toolkit usage | `../devops-toolkit-usage` | przykłady użycia, testy E2E |
| console light | `../devops-console-light` | uproszczona wersja konsoli |

## Kluczowe pliki do nawigacji

| Plik | Co robi |
|------|---------|
| `toolkit/cli.py` | Główny entrypoint CLI (1208 linii) |
| `engine/run-audit.py` | Orkiestrator pipeline'u audytów |
| `toolkit/project_config.py` | Loader konfiguracji projektu (v1/v2 schema) |
| `docs/kontrakty/` | 18 dokumentów kontraktów architektonicznych (PL) |
| `ARCHITECTURE.md` | Pełna dokumentacja architektury (EN, 516 linii) |
| `audits/*.yaml` | Definicje audytów (pipeline-as-code) |
| `collectors/registry.yaml` | Rejestr collectorów |
| `toolkit/plugins/` | Pluginy: finops_billing_gap, aws_logging_audit, llz_scaffold_conformance |

→ [[decisions]] | [[next-steps]] | [[links]] | [[session-log]]
