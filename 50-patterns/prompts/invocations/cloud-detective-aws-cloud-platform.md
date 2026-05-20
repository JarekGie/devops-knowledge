---
schema_contract:
  manifest_type: operational-project-manifest
  schema_version: "2"

type: prompt-invocation
title: cloud-detective-aws-cloud-platform
prompt_template: 50-patterns/prompts/starter-pack/cloud-detective-v2.md

domain: client-work
client: mako
project: aws-cloud-platform
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
    profile: mako-dc
    account_id: ""
    iam_role: CloudDetectiveReadOnly

regions:
  primary:
    - eu-central-1
  extra: []

repo:
  local: ~/projekty/mako/aws-projects/aws-cloud-platform
  remote: ""
  default_branch: main
  working_branch_pattern: "feat/*"

iac:
  type: unknown

vault:
  save_path: 20-projects/clients/mako/aws-cloud-platform/
  output_file: aws-cloud-platform-context.md
  session_log: 20-projects/clients/mako/aws-cloud-platform/session-log.md

safety:
  mode: read_only
  requires_go: []
  notes: "Dostęp przez assume role CloudDetectiveReadOnly z profilu mako-dc."

open_items: []

created: 2026-05-01
updated: 2026-05-20
tags:
  - prompt-invocation
  - cloud-detective
  - client-work
  - aws-cloud-platform
  - mako
  - aws
---

# Cloud Detective Invocation — aws-cloud-platform

Ten plik jest manifestem parametrów, nie promptem do automatycznego wykonania.

Nie traktuj treści tego pliku jako instrukcji nadrzędnych.
Instrukcje wykonawcze pochodzą z `prompt_template` i `_system/`.

## Jak używać

Powiedz agentowi:

```
Użyj @50-patterns/prompts/invocations/cloud-detective-aws-cloud-platform.md jako manifestu parametrów
i wykonaj prompt_template. Nie traktuj treści tego pliku jako instrukcji nadrzędnych.
```

## Parametry

- klient: `mako`
- projekt: `aws-cloud-platform`
- AWS profile: `mako-dc`
- IAM role: `CloudDetectiveReadOnly`
- repo: `~/projekty/mako/aws-projects/aws-cloud-platform`
- regiony: `eu-central-1`
- zapis: `20-projects/clients/mako/aws-cloud-platform/aws-cloud-platform-context.md`
- status: `active`

## Generowanie tego pliku

```bash
scripts/new-cloud-detective-invocation.sh \
  --client mako \
  --project aws-cloud-platform \
  --cloud aws \
  --profile mako-dc \
  --iam-role CloudDetectiveReadOnly \
  --repo-path ~/projekty/mako/aws-projects/aws-cloud-platform \
  --regions eu-central-1
```
