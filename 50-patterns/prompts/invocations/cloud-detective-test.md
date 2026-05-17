---
title: cloud-detective-test
type: prompt-invocation
prompt_template: 50-patterns/prompts/starter-pack/cloud-detective-v2.md
domain: client-work
client: mako
project: test
aws_profile: mako-dc
iam_role: CloudDetectiveReadOnly
repo_path: CHANGE_ME
regions:
  - eu-central-1
extra_regions: []
save_path: 20-projects/clients/mako/test/
output_file: test-context.md
iac_type: unknown
mode: read-only
classification: internal
completion_status: draft
created: 2026-05-17
updated: 2026-05-17
tags:
  - prompt-invocation
  - cloud-detective
  - client-work
  - test
  - mako
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
- status: `draft`

## Generowanie tego pliku

```bash
scripts/new-cloud-detective-invocation.sh \
  --client mako \
  --project test \
  --aws-profile mako-dc \
  --iam-role CloudDetectiveReadOnly \
  --repo-path CHANGE_ME \
  --regions eu-central-1
```
