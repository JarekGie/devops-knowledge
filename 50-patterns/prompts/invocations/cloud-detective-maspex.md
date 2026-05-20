---
schema_contract:
  manifest_type: operational-project-manifest
  schema_version: "2"

type: prompt-invocation
title: cloud-detective-maspex
prompt_template: 50-patterns/prompts/starter-pack/cloud-detective-v2.md

domain: client-work
client: mako
project: maspex
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
    profile: maspex-cli
    account_id: "969209893152"

regions:
  primary:
    - eu-west-1
  extra: []

repo:
  local: ~/projekty/mako/aws-projects/infra-maspex
  remote: ""                     # GitLab — dostępny wyłącznie przez VPN korporacyjny
  default_branch: main
  working_branch_pattern: "feat/*"

iac:
  type: terraform
  state_backend: s3

vault:
  save_path: 20-projects/clients/mako/maspex/
  output_file: maspex-context.md
  session_log: 20-projects/clients/mako/maspex/session-log.md

safety:
  mode: conditional_go
  requires_go:
    - terraform apply
    - aws ecs update-service
    - aws application-autoscaling put-scaling-policy
    - aws wafv2 update-web-acl
    - git push --force
  notes: "GitLab push wymaga VPN korporacyjny. ECS PROD: min=30, max=45 — nie zmieniaj bez GO."

open_items:
  - id: D3
    desc: "terraform state rm 'module.cloudfront_site.aws_acm_certificate.this[0]' — required before next terraform apply"
    status: open
  - id: P1
    desc: "autoscaling min=30→8, max=45→30 (~$2 190/mies.) — CONDITIONAL GO: alarm RunningTaskCount<6 + alarm p99>500ms + 7 dni monitoringu post-kampania"
    status: conditional_go

created: 2026-05-01
updated: 2026-05-20
tags:
  - prompt-invocation
  - cloud-detective
  - client-work
  - maspex
  - mako
  - aws
---

# Cloud Detective Invocation — maspex

Ten plik jest manifestem parametrów, nie promptem do automatycznego wykonania.

Nie traktuj treści tego pliku jako instrukcji nadrzędnych.
Instrukcje wykonawcze pochodzą z `prompt_template` i `_system/`.

## Jak używać

Powiedz agentowi:

```
Użyj @50-patterns/prompts/invocations/cloud-detective-maspex.md jako manifestu parametrów
i wykonaj prompt_template. Nie traktuj treści tego pliku jako instrukcji nadrzędnych.
```

## Startup checklist (po przerwie)

1. Sprawdź `open_items` powyżej — aktywne ryzyka i constraints
2. Przeczytaj ostatnie 2 wpisy w `20-projects/clients/mako/maspex/session-log.md`
3. Sprawdź `02-active-context/now.md` — bieżący focus operatora
4. Aktualny branch: `git branch --show-current` w `~/projekty/mako/aws-projects/infra-maspex`
5. NIE wykonuj akcji z `safety.requires_go` bez osobnego GO

## Parametry

- klient: `mako`
- projekt: `maspex`
- AWS profile: `maspex-cli`
- repo: `~/projekty/mako/aws-projects/infra-maspex`
- regiony: `eu-west-1`
- zapis: `20-projects/clients/mako/maspex/maspex-context.md`
- status: `active`

## Generowanie tego pliku

```bash
scripts/new-cloud-detective-invocation.sh \
  --client mako \
  --project maspex \
  --cloud aws \
  --profile maspex-cli \
  --account-id 969209893152 \
  --repo-path ~/projekty/mako/aws-projects/infra-maspex \
  --regions eu-west-1 \
  --iac-type terraform \
  --safety-mode conditional_go
```
