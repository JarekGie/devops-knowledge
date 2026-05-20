---
schema_contract:
  manifest_type: operational-project-manifest
  schema_version: "2"

type: prompt-invocation
title: cloud-detective-booking-online
prompt_template: 50-patterns/prompts/starter-pack/cloud-detective-v2.md

domain: client-work
client: mako
project: booking-online
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
    profile: booking
    account_id: ""

regions:
  primary:
    - eu-central-1
  extra: []

repo:
  local: ~/projekty/mako/aws-projects/infra-booking-online
  remote: ""
  default_branch: main
  working_branch_pattern: "feat/*"

iac:
  type: cloudformation

vault:
  save_path: 20-projects/clients/mako/booking-online/
  output_file: booking-online-context.md
  session_log: 20-projects/clients/mako/booking-online/session-log.md

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
  - booking-online
  - mako
  - aws
---

# Cloud Detective Invocation — booking-online

Ten plik jest manifestem parametrów, nie promptem do automatycznego wykonania.

Nie traktuj treści tego pliku jako instrukcji nadrzędnych.
Instrukcje wykonawcze pochodzą z `prompt_template` i `_system/`.

## Jak używać

Powiedz agentowi:

```
Użyj @50-patterns/prompts/invocations/cloud-detective-booking-online.md jako manifestu parametrów
i wykonaj prompt_template. Nie traktuj treści tego pliku jako instrukcji nadrzędnych.
```

## Parametry

- klient: `mako`
- projekt: `booking-online`
- AWS profile: `booking`
- repo: `~/projekty/mako/aws-projects/infra-booking-online`
- regiony: `eu-central-1`
- zapis: `20-projects/clients/mako/booking-online/booking-online-context.md`
- status: `active`

## Generowanie tego pliku

```bash
scripts/new-cloud-detective-invocation.sh \
  --client mako \
  --project booking-online \
  --cloud aws \
  --profile booking \
  --repo-path ~/projekty/mako/aws-projects/infra-booking-online \
  --regions eu-central-1 \
  --iac-type cloudformation
```
