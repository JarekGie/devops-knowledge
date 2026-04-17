# devops-toolkit — Linki

## Repozytoria lokalne

| Repo | Ścieżka | Rola |
|------|---------|------|
| toolkit (engine) | `~/projekty/devops/devops-toolkit` | główny silnik CLI |
| toolkit UI | `~/projekty/devops/devops-toolkit-ui` | frontend operator console |
| toolkit usage | `~/projekty/devops/devops-toolkit-usage` | przykłady użycia, testy E2E |
| console light | `~/projekty/devops/devops-console-light` | uproszczona konsola (status nieznany) |

## Kluczowe pliki w repo

| Plik | Opis |
|------|------|
| `toolkit/cli.py` | Główny entrypoint CLI — 1208 linii, wszystkie komendy |
| `ARCHITECTURE.md` | Pełna architektura systemu (EN, 516 linii) |
| `docs/kontrakty/` | 18 kontraktów architektonicznych (PL) |
| `audits/*.yaml` | Definicje pipeline'ów audytów |
| `collectors/registry.yaml` | Rejestr wszystkich collectorów |
| `normalizers/registry.yaml` | Rejestr normalizerów |
| `sanitizers/registry.yaml` | Rejestr sanitizerów |
| `rules/registry.yaml` | Rejestr reguł |
| `packs/*.yaml` | Definicje audit packów |
| `engine/run-audit.py` | Orkiestrator pipeline'u |
| `toolkit/plugins/` | Pluginy: finops_billing_gap, aws_logging_audit, llz_scaffold_conformance |
| `toolkit/finops/` | Moduły FinOps reporting |
| `toolkit/terraform/` | Generowanie i parsowanie Terraform |
| `pyproject.toml` | Zależności i wersja (0.1.0) |

## Znane długi techniczne (pliki do naprawy)

| Plik | Problem |
|------|---------|
| `normalizers/cost/normalize-cost.py` | Stub — TODO w linii 10 |
| `sanitizers/sanitize-finops-findings.py` | Stub — `print("TODO sanitize findings")` |
| `templates/command-template/command.py` | TODO comments dla nowych komend |

## CI/CD

| Pipeline | Gdzie |
|----------|-------|
| Contract check | `make contract-check` (lokalnie + CI) |
| Contract verify | `make contract-verify` (contract + lint + test) |
| Testy jednostkowe | `pytest tests/unit/ -q` |
