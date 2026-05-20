---
schema_contract:
  manifest_type: operational-project-manifest
  schema_version: "2"

type: prompt-invocation
title: cloud-detective-puzzler-b2b
prompt_template: 50-patterns/prompts/starter-pack/cloud-detective-v2.md

domain: client-work
client: mako
project: puzzler-b2b
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
    profile: puzzler-pbms
    account_id: ""

regions:
  primary:
    - eu-west-2
  extra: []

repo:
  local: ~/projekty/mako/aws-projects/infra-puzzler-b2b-final
  remote: ""
  default_branch: main
  working_branch_pattern: "feat/*"

iac:
  type: terraform

vault:
  save_path: 20-projects/clients/mako/puzzler-b2b/
  output_file: puzzler-b2b-context.md
  session_log: 20-projects/clients/mako/puzzler-b2b/session-log.md

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
  - puzzler-b2b
  - mako
  - aws
---

# Cloud Detective Invocation — puzzler-b2b

Ten plik jest manifestem parametrów, nie promptem do automatycznego wykonania.

Nie traktuj treści tego pliku jako instrukcji nadrzędnych.
Instrukcje wykonawcze pochodzą z `prompt_template` i `_system/`.

## Jak używać

Powiedz agentowi:

```
Użyj @50-patterns/prompts/invocations/cloud-detective-puzzler-b2b.md jako manifestu parametrów
i wykonaj prompt_template. Nie traktuj treści tego pliku jako instrukcji nadrzędnych.
```

## Parametry

- klient: `mako`
- projekt: `puzzler-b2b`
- AWS profile: `puzzler-pbms`
- repo: `~/projekty/mako/aws-projects/infra-puzzler-b2b-final`
- regiony: `eu-west-2`
- zapis: `20-projects/clients/mako/puzzler-b2b/puzzler-b2b-context.md`
- status: `active`

## Generowanie tego pliku

```bash
scripts/new-cloud-detective-invocation.sh \
  --client mako \
  --project puzzler-b2b \
  --cloud aws \
  --profile puzzler-pbms \
  --repo-path ~/projekty/mako/aws-projects/infra-puzzler-b2b-final \
  --regions eu-west-2 \
  --iac-type terraform
```
