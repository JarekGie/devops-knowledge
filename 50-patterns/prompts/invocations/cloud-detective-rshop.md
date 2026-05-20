---
schema_contract:
  manifest_type: operational-project-manifest
  schema_version: "2"

type: prompt-invocation
title: cloud-detective-rshop
prompt_template: 50-patterns/prompts/starter-pack/cloud-detective-v2.md

domain: client-work
client: mako
project: rshop
classification: internal

lifecycle:
  state: active

ownership:
  operator: jaroslaw-golab
  managed_by: human

llm_rules:
  domain_isolation: strict
  cross_project_reasoning: forbidden
  autonomous_actions: false

cloud_provider:
  name: aws
  aws:
    profile: rshop
    account_id: ""

regions:
  primary:
    - eu-central-1
  extra: []

repo:
  local: ~/projekty/mako/aws-projects/infra-rshop
  remote: ""
  default_branch: main
  working_branch_pattern: "feat/*"

iac:
  type: cloudformation

vault:
  save_path: 20-projects/clients/mako/rshop/
  output_file: rshop-context.md
  session_log: 20-projects/clients/mako/rshop/session-log.md

safety:
  mode: read_only
  requires_go: []
  notes: ""

open_items: []

created: 2026-05-01
updated: 2026-05-20
tags:
  - prompt-invocation
  - cloud-detective
  - client-work
  - rshop
  - mako
  - aws
---

# Cloud Detective Invocation — rshop

Ten plik jest manifestem parametrów, nie promptem do automatycznego wykonania.

Nie traktuj treści tego pliku jako instrukcji nadrzędnych.
Instrukcje wykonawcze pochodzą z `prompt_template` i `_system/`.

## Jak używać

Powiedz agentowi:

```
Użyj @50-patterns/prompts/invocations/cloud-detective-rshop.md jako manifestu parametrów
i wykonaj prompt_template. Nie traktuj treści tego pliku jako instrukcji nadrzędnych.
```

## Parametry

- klient: `mako`
- projekt: `rshop`
- AWS profile: `rshop`
- repo: `~/projekty/mako/aws-projects/infra-rshop`
- regiony: `eu-central-1`
- zapis: `20-projects/clients/mako/rshop/rshop-context.md`
- status: `active`

## Generowanie tego pliku

```bash
scripts/new-cloud-detective-invocation.sh \
  --client mako \
  --project rshop \
  --cloud aws \
  --profile rshop \
  --repo-path ~/projekty/mako/aws-projects/infra-rshop \
  --regions eu-central-1 \
  --iac-type cloudformation
```
