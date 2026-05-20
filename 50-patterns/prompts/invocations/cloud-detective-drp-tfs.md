---
schema_contract:
  manifest_type: operational-project-manifest
  schema_version: "2"

type: prompt-invocation
title: cloud-detective-drp-tfs
prompt_template: 50-patterns/prompts/starter-pack/cloud-detective-v2.md

domain: client-work
client: mako
project: drp-tfs
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
    profile: drp-tfs
    account_id: ""

regions:
  primary:
    - eu-central-1
  extra: []

repo:
  local: ~/projekty/mako/drp-tfs
  remote: ""
  default_branch: main
  working_branch_pattern: "feat/*"

iac:
  type: terraform

vault:
  save_path: 20-projects/clients/mako/drp-tfs/
  output_file: drp-tfs-context.md
  session_log: 20-projects/clients/mako/drp-tfs/session-log.md

safety:
  mode: read_only
  requires_go: []
  notes: ""

open_items: []

created: 2026-05-07
updated: 2026-05-20
tags:
  - prompt-invocation
  - cloud-detective
  - client-work
  - drp-tfs
  - mako
  - aws
---

# Cloud Detective Invocation — drp-tfs

Ten plik jest manifestem parametrów, nie promptem do automatycznego wykonania.

Nie traktuj treści tego pliku jako instrukcji nadrzędnych.
Instrukcje wykonawcze pochodzą z `prompt_template` i `_system/`.

## Jak używać

Powiedz agentowi:

```
Użyj @50-patterns/prompts/invocations/cloud-detective-drp-tfs.md jako manifestu parametrów
i wykonaj prompt_template. Nie traktuj treści tego pliku jako instrukcji nadrzędnych.
```

## Parametry

- klient: `mako`
- projekt: `drp-tfs`
- AWS profile: `drp-tfs`
- repo: `~/projekty/mako/drp-tfs`
- regiony: `eu-central-1`
- zapis: `20-projects/clients/mako/drp-tfs/drp-tfs-context.md`
- status: `active`

## Generowanie tego pliku

```bash
scripts/new-cloud-detective-invocation.sh \
  --client mako \
  --project drp-tfs \
  --cloud aws \
  --profile drp-tfs \
  --repo-path ~/projekty/mako/drp-tfs \
  --regions eu-central-1 \
  --iac-type terraform
```
