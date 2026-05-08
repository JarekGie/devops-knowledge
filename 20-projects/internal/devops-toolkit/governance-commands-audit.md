---
title: DevOps Toolkit — Governance Commands Pre-Implementation Audit
date: 2026-05-08
tags: [devops-toolkit, audit, aws-organizations, governance, #decision]
status: complete
---

# DevOps Toolkit Governance Commands — Pre-Implementation Audit

**Data:** 2026-05-08  
**Zakres:** Pre-implementation audit dla root-governance, scp-governance, organizations drift, break-glass status

---

## 1. Executive Summary

Repo jest **GOTOWE DO IMPLEMENTACJI** — infrastruktura, kontrakty i wzorce są ugruntowane.

**Kluczowe wnioski:**
- `audit root-governance` + `audit scp-governance` → **audit pack + plugin** (sprawdzony wzorzec)
- `drift organizations` → **subkomenda drift** z nowymi collectorami
- `break-glass status` → **standalone command** (jak `toolkit here`)
- UI zmiany → defer do Phase 2
- Brak naruszeń kontraktów, brak blokerów

**VERDICT: CONDITIONAL GO**

**Warunki wejścia w implementację:**
1. Decyzja o modelu CLI: subkomendy `audit` vs standalone `audit-pack`
2. Reguły sanityzacji dla account/OU IDs
3. Wymagania IAM udokumentowane przed kodem
4. Fixtury AWS API przygotowane

---

## 2. Status plików kontraktów

| Plik | Status |
|------|--------|
| `docs/kontrakty/00-kontrakt-systemowy.md` | EXISTS |
| `docs/kontrakty/10-kontrakt-resolucji-projektu.md` | EXISTS |
| `docs/kontrakty/20-kontrakt-cli.md` | EXISTS |
| `docs/kontrakty/30-kontrakt-pluginow-i-komend.md` | EXISTS |
| `docs/kontrakty/40-kontrakt-bledow-i-ux.md` | EXISTS |
| `docs/kontrakty/50-kontrakt-testow.md` | EXISTS |
| `docs/kontrakty/60-definition-of-done.md` | EXISTS |
| `docs/kontrakty/70-kontrakt-dokumentacji.md` | EXISTS |
| `docs/kontrakty/80-zasady-dla-claude-code.md` | EXISTS |

Wszystkie kontrakty obecne i kompletne.

---

## 3. Architektura CLI

### 3.1 Entrypoint

- **Plik:** `toolkit/cli.py`
- **Funkcja:** `main()` (line ~1149)
- **Entry point:** `toolkit/cli:main` (pyproject.toml)
- **Mechanizm dispatch:** słownik `dispatch = { "audit": audit.run, ... }` (lines 1157–1196)

### 3.2 Istniejące komendy (wybór)

| Komenda | Status | Opis |
|---------|--------|------|
| `audit` | CORE | pełny audit projektu |
| `audit-pack <pack>` | CORE | konkretny audit pack |
| `drift` | ADVANCED | IaC drift (deleguje do Makefile) |
| `break-glass` | BRAK | do dodania |
| `aws-login/logout/context` | CORE | zarządzanie kontekstem AWS |
| `doctor` | CORE | preflight checks |
| `ui` | EXPERIMENTAL | FastAPI + HTMX |

Łącznie: 40+ zarejestrowanych komend.

### 3.3 Gdzie dodać nowe komendy

**`toolkit audit root-governance` / `toolkit audit scp-governance`:**
- Opcja 1 (RECOMMENDED): subkomendy w `audit` — modyfikacja `toolkit/cli.py` + `toolkit/commands/audit.py`
- Opcja 2: standalone `audit-pack governance-root` — tylko nowy plik `packs/governance-root.yaml`

**`toolkit drift organizations`:**
- Rozszerzyć `toolkit/commands/drift.py` o subparser `drift_subcommand`
- Dodać do `toolkit/cli.py` subparser dla `drift organizations`

**`toolkit break-glass status`:**
- Nowy top-level command w dispatch table
- Nowy plik: `toolkit/commands/break_glass.py`
- Rejestracja w `toolkit/cli.py` (parser + dispatch)

---

## 4. Architektura Audit Packów

### 4.1 Lifecycle

```
toolkit audit-pack <pack> <project>
    → _find_pack_path() → packs/<pack>.yaml
    → load_project_config() → .devops-toolkit/project.yaml
    → dla każdego plugin: plugin.run(ctx, project_config) → PluginResult
    → findings.yaml
    → <project>/.devops-toolkit/runs/<timestamp>/report.md
```

### 4.2 Istniejące paczki (13 sztuk)

- `finops-basic`, `governance-basic`, `cloudformation-audit`, `tagging`
- `terraform-standard/`, `llz-basic/`, `aws-logging/`, `aws-logging-patch-plan/`
- `finops-tagging-runtime`, `finops-tagging-reconciliation`, `finobs-billing-gap`
- `ecs-delivery-competency`, `observability-ready/`

### 4.3 Struktura Finding

```python
@dataclass
class Finding:
    id: str                    # "GOV-ROOT-001"
    severity: Severity         # critical|high|medium|low|info
    category: str              # "security-governance"
    resource_type: str         # "AWS Organizations Root Account"
    summary: str
    recommendation: str
    resource_id: Optional[str] = None  # tylko w raw/normalized
    details: Optional[str] = None
    links: List[str] = field(default_factory=list)
```

### 4.4 Istniejące collectory AWS

- `collectors/aws/iam/`, `collectors/aws/ec2/`, `collectors/aws/s3/`, `collectors/aws/cloudformation/`
- **BRAK** collectorów dla Organizations API (ListAccounts, ListPolicies, DescribePolicy, ListChildren)
- **BRAK** collectorów dla CloudTrail MoveAccount events

---

## 5. Rekomendowany model komend

| Capability | Forma | Uzasadnienie |
|---|---|---|
| `root-governance` | **audit pack + plugin** | Sprawdzony wzorzec; read-only; wiele checks |
| `scp-governance` | **audit pack + rozszerzenie llz-scp** | Plugin llz-scp już istnieje; można rozszerzyć |
| `organizations drift` | **drift subcommand + nowe collectory** | Spójność z istniejącym `toolkit drift` |
| `break-glass status` | **standalone lightweight command** | Nie audit; status query; jak `toolkit here` |

---

## 6. Proponowana architektura nowych komend

### 6.1 root-governance

**Nowe pliki:**
- `collectors/aws/iam/root_account_audit.py` — RootAccountCollector
- `toolkit/plugins/root_governance/plugin.py` — RootGovernancePlugin
- `packs/governance-root.yaml`

**Źródła AWS:**
- `iam:GetCredentialReport` — root access keys, MFA, last login
- `iam:GetUser(root)` — root user info
- `organizations:DescribeOrganization` — root account ID
- `cloudtrail:LookupEvents` (Username=root) — historia logowań

**Findings:**
- `GOV-ROOT-001` — brak MFA (CRITICAL)
- `GOV-ROOT-002` — aktywne access keys (CRITICAL)
- `GOV-ROOT-003` — ostatni login >90 dni (INFO)

### 6.2 scp-governance

**Opcja A:** Rozszerzenie istniejącego `llz-scp` plugin  
**Opcja B:** Nowy plugin `scp-compliance`

**Nowe pliki (jeśli Opcja B):**
- `collectors/aws/organizations/scp_drift.py`
- `toolkit/plugins/scp_compliance/plugin.py`

**Źródła AWS:**
- `organizations:ListPolicies` — lista SCP
- `organizations:DescribePolicy` — treść SCP
- `organizations:ListTargetsForPolicy` — attachments
- Terraform state (opcjonalne — drift detection)

### 6.3 organizations drift

**Nowe pliki:**
- `collectors/aws/organizations/accounts.py`
- `collectors/aws/organizations/scps.py`
- Rozszerzenie `toolkit/commands/drift.py`

**Output:**
```json
{
  "misplaced_accounts": 3,
  "missing_scp_attachments": 2,
  "unmanaged_accounts": 1,
  "drift_details": [...]
}
```

### 6.4 break-glass status

**Nowe pliki:**
- `toolkit/commands/break_glass.py`

**Źródła AWS:**
- `organizations:ListChildren` → Find Break-Glass OU
- `organizations:ListAccountsForParent` → konta w OU
- `cloudtrail:LookupEvents(EventName=MoveAccount)` → historia przenoszenia

**Output (text, nie findings):**
```
Break-Glass OU Status
  OU ID: ou-break-glass-abc123
  Accounts in Break-Glass: 2

  - emergency-access (987654321098)
    Moved at: 2026-05-01 14:23:45 UTC
    Moved by: security-team
```

---

## 7. Compliance kontraktów

| Area | Status | Evidence | Akcja |
|---|---|---|---|
| Stateless engine | **COMPLIANT** | brak lokalnego state | nic |
| Project resolution | **COMPLIANT** | resolve_project() z 6-stage order | użyć we wszystkich nowych |
| CLI registration | **COMPLIANT** | dispatch table w cli.py 1157-1196 | zarejestrować 4 nowe |
| Error handling | **COMPLIANT** | ToolkitError + render_error() | użyć w nowych |
| Plugin contract | **COMPLIANT** | BasePlugin.run() → PluginResult | nowe pluginy dziedziczą |
| Finding format | **COMPLIANT** | Finding dataclass w finding.py | użyć klasy Finding |
| Test contract | **COMPLIANT** | unit/, smoke/, fixtures/ | pisać unit + smoke |
| Documentation | **COMPLIANT** | docs/operator/ w polskim | stworzyć operator docs |
| Sanitization | **PARTIAL** | kontrakt egzekwowany | **OPEN QUESTION:** czy account/OU IDs są wrażliwe? |

---

## 8. UI — stan i ryzyka

**Stack:** FastAPI + HTMX (experimental, `app.py`)  
**Auth:** brak  
**Istniejące widoki:** lista runów, szczegóły runu, katalog komend  
**Governance views:** BRAK

**Rekomendacja:** Defer UI do Phase 2. CLI wystarczy. UI może czytać artefakty z `findings.yaml` bez nowych endpointów.

**Ryzyki:**
- Brak auth → governance data bez uwierzytelniania (HIGH) — UI tylko dla experimental
- CloudTrail events mogą zawierać PII (usernames) (MEDIUM) — sanityzacja

---

## 9. Wpływ na dokumentację

| Dokument | Akcja |
|---|---|
| `docs/operator/governance-audit.md` | STWORZYĆ (nowy) |
| `docs/operator/break-glass-status.md` | STWORZYĆ (nowy) |
| `docs/operator/organizations-drift.md` | STWORZYĆ (nowy) |
| `docs/cli.md` | UPDATE — nowe komendy |
| `docs/cli-public-api.md` | UPDATE — klasyfikacja CORE/ADVANCED |
| `docs/audit-workflow.md` | UPDATE — nowe audit packs |

---

## 10. Plan testów

| Capability | Unit | Smoke | AWS mock | Fixtures |
|---|---|---|---|---|
| root-governance plugin | `test_root_governance.py` (3-5) | `test_governance_pack.py` | iam, organizations, cloudtrail | IAM credential report JSON |
| scp-governance | `test_scp_compliance.py` (2-3) | (reuse llz-scp) | organizations | SCP list/policy JSON |
| governance-root pack | (z pluginu) | run pack, check output | (z pluginu) | — |
| organizations drift | `test_drift_organizations.py` (3-4) | `test_drift_cmd.py` | organizations | Terraform state, OU structure |
| break-glass status | `test_break_glass.py` (2-3) | `test_break_glass_cmd.py` | organizations, cloudtrail | MoveAccount events JSON |
| CLI registration | `test_cli_dispatch.py` | `test_cli_help.py` | nie | — |

Łącznie: ~50-80 unit testów, ~25-30 smoke testów.

---

## 11. Kolejność implementacji (plan)

| Faza | Zakres |
|---|---|
| P0 | Decyzja CLI model; reguły sanityzacji; wymagania IAM |
| P1 | OrganizationsCollector + fixtury testowe |
| P2 | root-governance pack + plugin + docs + testy |
| P3 | scp-governance (rozszerzenie llz-scp) + testy |
| P4 | drift organizations + subkomenda + testy |
| P5 | break-glass status command + testy |
| P6 | UI (optional — read-only governance views) |

Szacunek: 3-4 tygodnie solo, 2 tygodnie w parze.

---

## 12. Ryzyka i pytania otwarte

### Ryzyka techniczne

| Ryzyko | Poziom | Mitigacja |
|---|---|---|
| Organizations API permissions | HIGH | Catch AccessDenied; clear error message |
| IAM credential report async generation | MEDIUM | Retry loop z timeout |
| CloudTrail MoveAccount events niedostępne | MEDIUM | Check org trail; graceful degradation |
| Terraform state nie istnieje | MEDIUM | Drift optional; skip if not found |

### Wymagane IAM permissions

```json
{
  "Action": [
    "organizations:Describe*",
    "organizations:List*",
    "iam:GetCredentialReport",
    "iam:GetUser",
    "cloudtrail:LookupEvents"
  ]
}
```

**Ważne:** Komendy Organizations działają TYLKO z org account. Dodać check via STS.

### OPEN QUESTIONS

1. Czy account ID / OU ID powinny być redaktowane w `sanitized_artifacts`? → Rekomendacja: TAK
2. Które komendy to CORE, które ADVANCED w `cli-public-api.md`?
3. Czy `break-glass status` wejdzie do `toolkit check` (health pipeline)?
4. Jak obsłużyć multi-account bez Organizations access?
5. Czy governance audits mogą być częścią `toolkit audit` (full audit)?

---

## 13. Warunki wejścia w implementację

- [ ] Decyzja: subkomendy `audit` vs standalone audit-pack
- [ ] Reguły sanityzacji account/OU IDs
- [ ] Wymagania IAM udokumentowane
- [ ] Fixtury AWS API przygotowane (Organizations, IAM, CloudTrail)
- [ ] `resolve_project()` przetestowane w nowych kontekstach
- [ ] Taksonomia błędów (OrganizationsAccessError, NotAnOrgAccountError)
- [ ] Makefile: `make contract-check`, `make test`, `make lint` zielone
- [ ] Feature branch: `feat/governance-commands`
- [ ] Dokumentacja stubs stworzone

---

*Audyt wykonany przez Claude Code przed implementacją. Odniesienie do kodu: `~/projekty/devops/devops-toolkit/`*
