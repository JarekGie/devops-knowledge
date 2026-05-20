---
schema_contract:
  manifest_type: operational-project-manifest
  schema_version: "2"

type: prompt-invocation
title: cloud-detective-mfs-onboarding
prompt_template: 50-patterns/prompts/starter-pack/cloud-detective-v2.md

domain: client-work
client: mako
project: mfs-onboarding
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
  name: gcp
  gcp:
    project_id: rci-orchestration
    auth_method: gcloud_interactive

regions:
  primary:
    - europe-west2
  extra: []

repo:
  local: /Users/jaroslaw.golab/projekty/mako/mfs-orchestration
  remote: ""
  default_branch: main
  working_branch_pattern: "feat/*"

iac:
  type: terraform

vault:
  save_path: 20-projects/clients/mako/mfs-onboarding/
  output_file: mfs-onboarding-context.md
  session_log: 20-projects/clients/mako/mfs-onboarding/session-log.md

safety:
  mode: read_only
  requires_go:
    - gcloud ... (any mutating command)
    - terraform apply
  notes: "Projekt GCP. Przed komendami gcloud: operator uruchamia 'gcloud auth login' przez prefiks ! w Claude Code."

open_items: []

created: 2026-05-17
updated: 2026-05-20
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
- status: `active`

## Generowanie tego pliku

```bash
scripts/new-cloud-detective-invocation.sh \
  --client mako \
  --project mfs-onboarding \
  --cloud gcp \
  --gcp-project-id rci-orchestration \
  --auth-method gcloud_interactive \
  --repo-path /Users/jaroslaw.golab/projekty/mako/mfs-orchestration \
  --regions europe-west2 \
  --iac-type terraform
```
