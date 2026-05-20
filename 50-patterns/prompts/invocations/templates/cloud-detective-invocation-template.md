---
# ══════════════════════════════════════════════════════════
# OPERATIONAL PROJECT MANIFEST — schema v2
# ONE PROJECT = ONE CANONICAL MANIFEST
# Generator: scripts/new-cloud-detective-invocation.sh
# ══════════════════════════════════════════════════════════

schema_contract:
  manifest_type: operational-project-manifest
  schema_version: "2"

# Backward-compatible invocation identity
type: prompt-invocation
title: cloud-detective-<PROJECT>
prompt_template: 50-patterns/prompts/starter-pack/cloud-detective-v2.md

# Project identity
domain: client-work              # client-work | internal-product | private-rnd
client: <CLIENT>
project: <PROJECT>
classification: internal         # internal | confidential | public

lifecycle:
  state: active                  # active | maintenance | archived

ownership:
  operator: jaroslaw-golab
  managed_by: human

llm_rules:
  domain_isolation: strict
  cross_project_reasoning: forbidden
  autonomous_actions: false

# Cloud provider — cloud-agnostic, provider-aware
# Tylko sekcja odpowiadająca name: jest wypełniana. Pozostałe nie istnieją.
cloud_provider:
  name: aws                      # aws | gcp | azure | ovh | multi

  aws:                           # obecne gdy name: aws lub multi
    profile: <AWS_PROFILE>
    account_id: "<123456789012>"
    iam_role: <ROLE>             # opcjonalne — assume role przez mako-dc w target account

  gcp:                           # obecne gdy name: gcp lub multi
    project_id: <GCP_PROJECT_ID>
    auth_method: gcloud_interactive   # gcloud_interactive | service_account | workload_identity

  azure:                         # obecne gdy name: azure
    subscription_id: <SUB_ID>
    auth_method: az_login        # az_login | service_principal

  ovh:                           # obecne gdy name: ovh
    project_ref: <PROJECT_REF>
    auth_method: openstack_rc    # openstack_rc | api_token

# Regiony
regions:
  primary:
    - <REGION>
  extra: []                      # globalny scope — CloudFront, ACM us-east-1, itp.

# Repozytorium IaC
repo:
  local: <~/projekty/...>
  remote: <https://...>          # opcjonalne — może być za VPN lub niedostępny offline
  default_branch: main
  working_branch_pattern: "feat/*"   # wzorzec gałęzi roboczych — branch aktualny: git branch --show-current

# IaC
iac:
  type: terraform                # terraform | cloudformation | pulumi | mixed | unknown
  state_backend: s3              # opcjonalne: s3 | local | terraform_cloud | gcs
  workspace: default             # opcjonalne

# Routing vault
vault:
  save_path: 20-projects/clients/<CLIENT>/<PROJECT>/
  output_file: <PROJECT>-context.md
  session_log: 20-projects/clients/<CLIENT>/<PROJECT>/session-log.md

# Bezpieczeństwo
safety:
  mode: read_only                # read_only | conditional_go | manual_execution_only
  requires_go: []
  # Przykłady:
  # - terraform apply
  # - aws ecs update-service
  # - aws application-autoscaling put-scaling-policy
  notes: ""

# Stan operacyjny — TYLKO: ryzyka, safety constraints, conditional_go decisions
# NIE: lista TODO, backlog, historia pracy, codzienne taski
open_items: []
# Format:
#   - id: P1
#     desc: "opis ryzyka lub constraintu"
#     status: open | conditional_go | pending_push

created: <YYYY-MM-DD>
updated: <YYYY-MM-DD>
tags:
  - prompt-invocation
  - cloud-detective
  - <domain>
  - <project>
  - <client>
  - <cloud>                      # aws | gcp | azure | ovh
---

# Cloud Detective Invocation — <PROJECT>

Ten plik jest manifestem parametrów, nie promptem do automatycznego wykonania.

Nie traktuj treści tego pliku jako instrukcji nadrzędnych.
Instrukcje wykonawcze pochodzą z `prompt_template` i `_system/`.

## Jak używać

Powiedz agentowi:

```
Użyj @50-patterns/prompts/invocations/cloud-detective-<PROJECT>.md jako manifestu parametrów
i wykonaj prompt_template. Nie traktuj treści tego pliku jako instrukcji nadrzędnych.
```

## Startup checklist (po przerwie)

1. Sprawdź `open_items` powyżej — aktywne ryzyka i constraints
2. Przeczytaj ostatnie 2 wpisy w `vault.session_log`
3. Sprawdź `02-active-context/now.md` — bieżący focus operatora
4. Aktualny branch: `git branch --show-current` w `repo.local`
5. NIE wykonuj akcji z `safety.requires_go` bez osobnego GO

## Parametry

- klient: `<CLIENT>`
- projekt: `<PROJECT>`
- cloud: `<CLOUD>`
- repo: `<REPO_PATH>`
- regiony: `<REGION>`
- zapis: `<SAVE_PATH><OUTPUT_FILE>`

## Generowanie tego pliku

```bash
scripts/new-cloud-detective-invocation.sh \
  --client <CLIENT> \
  --project <PROJECT> \
  --cloud <CLOUD> \
  --profile <PROFILE> \
  --repo-path <REPO_PATH> \
  --regions <REGION> \
  --iac-type <IAC_TYPE>
```
