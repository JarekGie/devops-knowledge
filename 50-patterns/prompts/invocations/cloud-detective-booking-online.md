---
title: cloud-detective-booking-online
type: prompt-invocation
prompt_template: 50-patterns/prompts/starter-pack/cloud-detective-v2.md
domain: client-work
client: mako
project: booking-online
aws_profile: booking
repo_path: ~/projekty/mako/aws-projects/infra-booking-online
regions:
  - eu-central-1
extra_regions: []
save_path: 20-projects/clients/mako/booking-online/
output_file: booking-online-context.md
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
  - booking-online
  - mako
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
- status: `draft`

## Generowanie tego pliku

```bash
scripts/new-cloud-detective-invocation.sh \
  --client mako \
  --project booking-online \
  --aws-profile booking \
  --repo-path ~/projekty/mako/aws-projects/infra-booking-online \
  --regions eu-central-1 \
  --iac-type cloudformation
```
