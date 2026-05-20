---
schema_contract:
  manifest_type: operational-project-manifest
  schema_version: "2"

type: prompt-invocation
title: cloud-detective-test
prompt_template: 50-patterns/prompts/starter-pack/cloud-detective-v2.md

domain: client-work
client: mako
project: test
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
  local: CHANGE_ME
  remote: ""
  default_branch: main
  working_branch_pattern: "feat/*"

iac:
  type: unknown

vault:
  save_path: 20-projects/clients/mako/test/
  output_file: test-context.md
  session_log: 20-projects/clients/mako/test/session-log.md

safety:
  mode: read_only
  requires_go: []
  notes: ""

open_items: []

created: 2026-05-17
updated: 2026-05-20
tags:
  - prompt-invocation
  - cloud-detective
  - client-work
  - test
  - mako
  - aws
---

# Cloud Detective Invocation — test

Ten plik jest manifestem parametrów, nie promptem do automatycznego wykonania.

Nie traktuj treści tego pliku jako instrukcji nadrzędnych.
Instrukcje wykonawcze pochodzą z `prompt_template` i `_system/`.

## Jak używać

Powiedz agentowi:

```
Użyj @50-patterns/prompts/invocations/cloud-detective-test.md jako manifestu parametrów
i wykonaj prompt_template. Nie traktuj treści tego pliku jako instrukcji nadrzędnych.
```

## Parametry

- klient: `mako`
- projekt: `test`
- AWS profile: `mako-dc`
- IAM role: `CloudDetectiveReadOnly`
- repo: `CHANGE_ME`
- regiony: `eu-central-1`
- zapis: `20-projects/clients/mako/test/test-context.md`

## Generowanie tego pliku

```bash
scripts/new-cloud-detective-invocation.sh \
  --client mako \
  --project test \
  --cloud aws \
  --profile mako-dc \
  --iam-role CloudDetectiveReadOnly \
  --regions eu-central-1
```
