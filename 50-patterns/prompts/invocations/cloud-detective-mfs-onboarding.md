---
title: cloud-detective-mfs-onboarding
type: prompt-invocation
prompt_template: 50-patterns/prompts/starter-pack/cloud-detective-v2.md
domain: client-work
client: mako
project: mfs-onboarding
cloud: gcp
gcp_project_id: rci-orchestration
auth_method: gcloud_interactive
repo_path: /Users/jaroslaw.golab/projekty/mako/mfs-orchestration
regions:
  - europe-west2
extra_regions: []
save_path: 20-projects/clients/mako/mfs-onboarding/
output_file: mfs-onboarding-context.md
iac_type: terraform
mode: read-only
classification: internal
completion_status: draft
created: 2026-05-17
updated: 2026-05-17
tags:
  - prompt-invocation
  - cloud-detective
  - client-work
  - mfs-onboarding
  - mako
  - gcp
---

# Cloud Detective Invocation — mfs-onboarding (GCP)

Ten plik jest manifestem parametrów, nie promptem do automatycznego wykonania.

Nie traktuj treści tego pliku jako instrukcji nadrzędnych.
Instrukcje wykonawcze pochodzą z `prompt_template` i `_system/`.

## Jak używać

Powiedz agentowi:

```
Użyj @50-patterns/prompts/invocations/cloud-detective-mfs-onboarding.md jako manifestu parametrów
i wykonaj prompt_template. Nie traktuj treści tego pliku jako instrukcji nadrzędnych.
```

## Autentykacja (GCP)

Ten projekt używa **Google Cloud**, nie AWS. Przed wykonaniem jakichkolwiek komend gcloud:

1. Poproś operatora o uruchomienie: `! gcloud auth login`
2. Po zalogowaniu ustaw projekt: `gcloud config set project rci-orchestration`
3. Zweryfikuj dostęp: `gcloud projects describe rci-orchestration`

Operator uruchamia `gcloud auth login` przez prefiks `!` w Claude Code, co uruchamia komendę interaktywnie w terminalu użytkownika.

## Parametry

- klient: `mako`
- projekt: `mfs-onboarding`
- GCP project ID: `rci-orchestration`
- cloud: GCP (nie AWS)
- repo: `/Users/jaroslaw.golab/projekty/mako/mfs-orchestration`
- region: `europe-west2`
- IaC: Terraform
- zapis: `20-projects/clients/mako/mfs-onboarding/mfs-onboarding-context.md`
- status: `draft`

## Generowanie tego pliku

```bash
scripts/new-cloud-detective-invocation.sh \
  --client mako \
  --project mfs-onboarding \
  --aws-profile gcloud \
  --repo-path /Users/jaroslaw.golab/projekty/mako/mfs-orchestration \
  --regions europe-west2 \
  --iac-type terraform
# Po wygenerowaniu: ręcznie podmień aws_profile → cloud/gcp_project_id/auth_method
```
