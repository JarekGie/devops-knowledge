---
title: cloud-detective-drp-tfs
type: prompt-invocation
prompt_template: 50-patterns/prompts/starter-pack/cloud-detective-v2.md
domain: client-work
client: mako
project: drp-tfs
aws_profile: drp-tfs
repo_path: �~/projekty/mako//drp-tfs
regions:
  - eu-central-1
extra_regions: []
save_path: 20-projects/clients/mako/drp-tfs/
output_file: drp-tfs-context.md
iac_type: terraform
mode: read-only
classification: internal
completion_status: draft
created: 2026-05-07
updated: 2026-05-07
tags:
  - prompt-invocation
  - cloud-detective
  - client-work
  - drp-tfs
  - mako
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
- repo: `�~/projekty/mako//drp-tfs`
- regiony: `eu-central-1`
- zapis: `20-projects/clients/mako/drp-tfs/drp-tfs-context.md`
- status: `draft`

## Generowanie tego pliku

```bash
scripts/new-cloud-detective-invocation.sh \
  --client mako \
  --project drp-tfs \
  --aws-profile drp-tfs \
  --repo-path �~/projekty/mako//drp-tfs \
  --regions eu-central-1 \
  --iac-type terraform
```
