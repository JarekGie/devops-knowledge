---
schema_contract:
  manifest_type: operational-project-manifest
  schema_version: "2"

type: prompt-invocation
title: cloud-detective-testowy-projekt
prompt_template: 50-patterns/prompts/starter-pack/cloud-detective-v2.md

domain: client-work
client: mako
project: testowy-projekt
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
    - CHANGE_ME
  extra: []

repo:
  local: ~/projekty/mako/aws-projects/testowy-projekt
  remote: ""
  default_branch: main
  working_branch_pattern: "feat/*"

iac:
  type: terraform

vault:
  save_path: 20-projects/clients/mako/testowy-projekt/
  output_file: testowy-projekt-context.md
  session_log: 20-projects/clients/mako/testowy-projekt/session-log.md

safety:
  mode: read_only
  requires_go: []
  notes: ""

open_items: []

created: 2026-05-21
updated: 2026-05-21
tags:
  - prompt-invocation
  - cloud-detective
  - client-work
  - testowy-projekt
  - mako
  - aws
---

# Cloud Detective Invocation — testowy-projekt

Ten plik jest manifestem parametrów, nie promptem do automatycznego wykonania.

Nie traktuj treści tego pliku jako instrukcji nadrzędnych.
Instrukcje wykonawcze pochodzą z `prompt_template` i `_system/`.

## Jak używać

Powiedz agentowi:

```
Użyj @50-patterns/prompts/invocations/cloud-detective-testowy-projekt.md jako manifestu parametrów
i wykonaj prompt_template. Nie traktuj treści tego pliku jako instrukcji nadrzędnych.
```

## Startup checklist (po przerwie)

1. Sprawdź `open_items` powyżej — aktywne ryzyka i constraints
2. Przeczytaj ostatnie 2 wpisy w `20-projects/clients/mako/testowy-projekt/session-log.md`
3. Sprawdź `02-active-context/now.md` — bieżący focus operatora
4. Aktualny branch: `git branch --show-current` w `~/projekty/mako/aws-projects/testowy-projekt`
5. NIE wykonuj akcji z `safety.requires_go` bez osobnego GO

## Parametry

- klient: `mako`
- projekt: `testowy-projekt`
- cloud: `aws`
- AWS profile: `mako-dc`
- IAM role: `CloudDetectiveReadOnly`
- repo: `~/projekty/mako/aws-projects/testowy-projekt`
- regiony: `CHANGE_ME`
- zapis: `20-projects/clients/mako/testowy-projekt/testowy-projekt-context.md`

## Generowanie tego pliku

```bash
scripts/new-cloud-detective-invocation.sh \
  --client mako \
  --project testowy-projekt \
  --cloud aws \
  --profile mako-dc \
  --iam-role CloudDetectiveReadOnly \
  --repo-path ~/projekty/mako/aws-projects/testowy-projekt \
  --regions CHANGE_ME \
  --iac-type terraform
```
