---
title: cloud-detective-puzzler-b2b
type: prompt-invocation
prompt_template: 50-patterns/prompts/starter-pack/cloud-detective-v2.md
domain: client-work
client: mako
project: puzzler-b2b
aws_profile: puzzler-pbms
repo_path: ~/projekty/mako/aws-projects/infra-puzzler-b2b-final
regions:
  - eu-west-2
extra_regions: []
save_path: 20-projects/clients/mako/puzzler-b2b/
output_file: puzzler-b2b-context.md
iac_type: terraform
mode: read-only
classification: internal
completion_status: draft
created: 2026-05-01
updated: 2026-05-01
tags:
  - prompt-invocation
  - cloud-detective
  - client-work
  - puzzler-b2b
  - mako
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
- status: `draft`

## Generowanie tego pliku

```bash
scripts/new-cloud-detective-invocation.sh \
  --client mako \
  --project puzzler-b2b \
  --aws-profile puzzler-pbms \
  --repo-path ~/projekty/mako/aws-projects/infra-puzzler-b2b-final \
  --regions eu-west-2 \
  --iac-type terraform
```
