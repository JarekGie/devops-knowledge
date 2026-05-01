---
title: cloud-detective-rshop
type: prompt-invocation
prompt_template: 50-patterns/prompts/starter-pack/cloud-detective-v2.md
domain: client-work
client: mako
project: rshop
aws_profile: rshop
repo_path: CHANGE_ME
regions:
  - eu-central-1
extra_regions: []
save_path: 20-projects/clients/mako/rshop/
output_file: rshop-context.md
iac_type: cloudformation
mode: read-only
classification: internal
completion_status: draft
created: 2026-05-01
updated: 2026-05-01
tags:
  - prompt-invocation
  - cloud-detective
  - client-work
  - rshop
  - mako
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
- repo: `CHANGE_ME`
- regiony: `eu-central-1`
- zapis: `20-projects/clients/mako/rshop/rshop-context.md`
- status: `draft`

## Generowanie tego pliku

```bash
scripts/new-cloud-detective-invocation.sh \
  --client mako \
  --project rshop \
  --aws-profile rshop \
  --repo-path CHANGE_ME \
  --regions eu-central-1 \
  --iac-type cloudformation
```
