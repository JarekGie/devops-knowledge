#!/usr/bin/env bash
set -euo pipefail

# new-cloud-detective-invocation.sh
# Generates an operational project manifest (schema v2) for a new project.
# Cloud-agnostic: supports aws, gcp, azure, ovh.
# Supports flag mode and interactive mode.

VAULT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INVOCATIONS_DIR="${VAULT_ROOT}/50-patterns/prompts/invocations"

CLIENT=""
PROJECT=""
CLOUD="aws"
PROFILE=""
ACCOUNT_ID=""
IAM_ROLE=""
GCP_PROJECT_ID=""
AUTH_METHOD=""
REPO_PATH=""
REPO_REMOTE=""
DEFAULT_BRANCH="main"
WORKING_BRANCH_PATTERN="feat/*"
REGIONS=""
EXTRA_REGIONS=""
IAC_TYPE="unknown"
IAC_BACKEND=""
OUTPUT_FILE=""
SAFETY_MODE="read_only"
OPERATOR="jaroslaw-golab"
FORCE=false
INTERACTIVE=false
TODAY="$(date +%Y-%m-%d)"

DEFAULT_PROFILE="mako-dc"
DEFAULT_IAM_ROLE="CloudDetectiveReadOnly"
DEFAULT_REPO_BASE="~/projekty/mako/aws-projects"

usage() {
  cat <<'USAGE'
Usage (minimal):
  scripts/new-cloud-detective-invocation.sh --client mako --project rshop

Usage (AWS):
  scripts/new-cloud-detective-invocation.sh \
    --client mako --project rshop \
    --cloud aws \
    --profile rshop \
    --account-id 123456789012 \
    --repo-path ~/projekty/mako/aws-projects/infra-rshop \
    --regions eu-central-1 \
    --iac-type terraform \
    --safety-mode read_only

Usage (GCP):
  scripts/new-cloud-detective-invocation.sh \
    --client mako --project mfs-onboarding \
    --cloud gcp \
    --gcp-project-id rci-orchestration \
    --auth-method gcloud_interactive \
    --repo-path ~/projekty/mako/mfs-orchestration \
    --regions europe-west2 \
    --iac-type terraform

Usage (interactive):
  scripts/new-cloud-detective-invocation.sh
  scripts/new-cloud-detective-invocation.sh --interactive

Required:
  --client CLIENT
  --project PROJECT

Cloud options (default: aws):
  --cloud aws|gcp|azure|ovh

AWS-specific:
  --profile PROFILE              AWS CLI profile (default: mako-dc)
  --aws-profile PROFILE          Alias for --profile (backward compat)
  --account-id ACCOUNT_ID
  --iam-role ROLE                IAM role to assume (default when profile=mako-dc: CloudDetectiveReadOnly)

GCP-specific:
  --gcp-project-id PROJECT_ID
  --auth-method METHOD           gcloud_interactive | service_account | workload_identity

Azure-specific:
  --subscription-id SUB_ID
  --auth-method METHOD           az_login | service_principal

Repo:
  --repo-path PATH               Local path
  --repo-remote URL              Remote URL (optional)
  --default-branch BRANCH        Default: main
  --working-branch-pattern PAT   Default: feat/*

IaC:
  --iac-type TYPE                terraform | cloudformation | pulumi | mixed | unknown
  --iac-backend BACKEND          s3 | local | terraform_cloud | gcs (optional)

Safety:
  --safety-mode MODE             read_only | conditional_go | manual_execution_only (default: read_only)

Other:
  --regions REGIONS              Comma-separated, e.g. eu-central-1,us-east-1
  --extra-regions REGIONS
  --output-file FILE
  --operator NAME                Default: jaroslaw-golab
  --force
  --interactive
  --help, -h
USAGE
}

[[ $# -eq 0 ]] && INTERACTIVE=true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --client)                CLIENT="$2";               shift 2 ;;
    --project)               PROJECT="$2";              shift 2 ;;
    --cloud)                 CLOUD="$2";                shift 2 ;;
    --profile)               PROFILE="$2";              shift 2 ;;
    --aws-profile)           PROFILE="$2";              shift 2 ;;
    --account-id)            ACCOUNT_ID="$2";           shift 2 ;;
    --iam-role)              IAM_ROLE="$2";             shift 2 ;;
    --gcp-project-id)        GCP_PROJECT_ID="$2";       shift 2 ;;
    --subscription-id)       ACCOUNT_ID="$2";           shift 2 ;;
    --auth-method)           AUTH_METHOD="$2";          shift 2 ;;
    --repo-path)             REPO_PATH="$2";            shift 2 ;;
    --repo-remote)           REPO_REMOTE="$2";          shift 2 ;;
    --default-branch)        DEFAULT_BRANCH="$2";       shift 2 ;;
    --working-branch-pattern) WORKING_BRANCH_PATTERN="$2"; shift 2 ;;
    --regions)               REGIONS="$2";              shift 2 ;;
    --extra-regions)         EXTRA_REGIONS="$2";        shift 2 ;;
    --iac-type)              IAC_TYPE="$2";             shift 2 ;;
    --iac-backend)           IAC_BACKEND="$2";          shift 2 ;;
    --safety-mode)           SAFETY_MODE="$2";          shift 2 ;;
    --output-file)           OUTPUT_FILE="$2";          shift 2 ;;
    --operator)              OPERATOR="$2";             shift 2 ;;
    --force)                 FORCE=true;                shift ;;
    --interactive)           INTERACTIVE=true;          shift ;;
    --help|-h)               usage; exit 0 ;;
    *)
      echo "ERROR: Unknown argument: $1" >&2
      echo "Run with --help for usage." >&2
      exit 1
      ;;
  esac
done

if [[ "$INTERACTIVE" == true ]]; then
  echo ""

  _default="${CLIENT:-mako}"
  read -r -p "Client [${_default}]: " _input
  CLIENT="${_input:-$_default}"

  while true; do
    if [[ -n "$PROJECT" ]]; then
      read -r -p "Project [${PROJECT}]: " _input
    else
      read -r -p "Project: " _input
    fi
    PROJECT="${_input:-$PROJECT}"
    [[ -n "$PROJECT" ]] && break
    echo "  Project cannot be empty." >&2
  done

  _default="${CLOUD}"
  read -r -p "Cloud provider [${_default}] (aws|gcp|azure|ovh): " _input
  CLOUD="${_input:-$_default}"

  case "$CLOUD" in
    aws)
      _default="${PROFILE:-$DEFAULT_PROFILE}"
      read -r -p "AWS profile [${_default}]: " _input
      PROFILE="${_input:-$_default}"

      if [[ "$PROFILE" == "mako-dc" ]]; then
        _default="${IAM_ROLE:-$DEFAULT_IAM_ROLE}"
        read -r -p "IAM role [${_default}]: " _input
        IAM_ROLE="${_input:-$_default}"
      fi

      read -r -p "Account ID []: " _input
      ACCOUNT_ID="${_input:-}"
      ;;
    gcp)
      while true; do
        read -r -p "GCP project ID: " _input
        GCP_PROJECT_ID="${_input:-}"
        [[ -n "$GCP_PROJECT_ID" ]] && break
        echo "  GCP project ID cannot be empty." >&2
      done
      _default="${AUTH_METHOD:-gcloud_interactive}"
      read -r -p "Auth method [${_default}]: " _input
      AUTH_METHOD="${_input:-$_default}"
      ;;
    azure)
      while true; do
        read -r -p "Subscription ID: " _input
        ACCOUNT_ID="${_input:-}"
        [[ -n "$ACCOUNT_ID" ]] && break
        echo "  Subscription ID cannot be empty." >&2
      done
      _default="${AUTH_METHOD:-az_login}"
      read -r -p "Auth method [${_default}]: " _input
      AUTH_METHOD="${_input:-$_default}"
      ;;
  esac

  _default="${REGIONS:-CHANGE_ME}"
  read -r -p "Regions [${_default}]: " _input
  REGIONS="${_input:-$_default}"

  read -r -p "Extra regions []: " _input
  EXTRA_REGIONS="${_input:-}"

  read -r -p "IaC type [${IAC_TYPE}]: " _input
  IAC_TYPE="${_input:-$IAC_TYPE}"

  _repo_base="$DEFAULT_REPO_BASE"
  read -r -p "Repo base [${_repo_base}]: " _input
  _repo_base="${_input:-$_repo_base}"

  read -r -p "Repo path or repo dir [CHANGE_ME]: " _input
  _repo_input="${_input:-CHANGE_ME}"

  if [[ "$_repo_input" == "CHANGE_ME" ]]; then
    REPO_PATH="CHANGE_ME"
  elif [[ "$_repo_input" == /* || "$_repo_input" == ~* ]]; then
    REPO_PATH="$_repo_input"
  else
    REPO_PATH="${_repo_base}/${_repo_input}"
  fi

  _default="${SAFETY_MODE}"
  read -r -p "Safety mode [${_default}] (read_only|conditional_go|manual_execution_only): " _input
  SAFETY_MODE="${_input:-$_default}"

  _default="${OUTPUT_FILE:-${PROJECT}-context.md}"
  read -r -p "Output file [${_default}]: " _input
  OUTPUT_FILE="${_input:-$_default}"

  echo ""
fi

# Validation
MISSING=()
[[ -z "$CLIENT" ]]  && MISSING+=("--client")
[[ -z "$PROJECT" ]] && MISSING+=("--project")

if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo "ERROR: Missing required arguments: ${MISSING[*]}" >&2
  echo "Run with --help for usage." >&2
  exit 1
fi

# Defaults
case "$CLOUD" in
  aws)
    PROFILE="${PROFILE:-$DEFAULT_PROFILE}"
    if [[ "$PROFILE" == "mako-dc" && -z "$IAM_ROLE" ]]; then
      IAM_ROLE="$DEFAULT_IAM_ROLE"
    fi
    ;;
  gcp)
    AUTH_METHOD="${AUTH_METHOD:-gcloud_interactive}"
    ;;
  azure)
    AUTH_METHOD="${AUTH_METHOD:-az_login}"
    ;;
  ovh)
    AUTH_METHOD="${AUTH_METHOD:-openstack_rc}"
    ;;
esac

REPO_PATH="${REPO_PATH:-CHANGE_ME}"
REGIONS="${REGIONS:-CHANGE_ME}"
OUTPUT_FILE="${OUTPUT_FILE:-${PROJECT}-context.md}"
SAVE_PATH="20-projects/clients/${CLIENT}/${PROJECT}/"
OUTPUT_PATH="${INVOCATIONS_DIR}/cloud-detective-${PROJECT}.md"

if [[ -f "$OUTPUT_PATH" ]] && [[ "$FORCE" == false ]]; then
  echo "ERROR: File already exists: ${OUTPUT_PATH}" >&2
  echo "Use --force to overwrite." >&2
  exit 1
fi

# Build YAML region list
build_yaml_list() {
  local input="$1"
  local indent="${2:-    }"
  local output=""
  IFS=',' read -ra items <<< "$input"
  for item in "${items[@]}"; do
    item="$(echo "$item" | xargs)"
    [[ -z "$item" ]] && continue
    output="${output}${indent}- ${item}"$'\n'
  done
  printf '%s' "${output%$'\n'}"
}

REGIONS_YAML="$(build_yaml_list "$REGIONS" "    ")"
EXTRA_YAML="[]"
if [[ -n "$EXTRA_REGIONS" ]]; then
  EXTRA_YAML=$'\n'"$(build_yaml_list "$EXTRA_REGIONS" "    ")"
fi

# Build cloud_provider section
case "$CLOUD" in
  aws)
    IAM_LINE=""
    [[ -n "$IAM_ROLE" ]] && IAM_LINE="    iam_role: ${IAM_ROLE}"
    CLOUD_SECTION="cloud_provider:
  name: aws
  aws:
    profile: ${PROFILE}
    account_id: \"${ACCOUNT_ID}\"${IAM_LINE:+
${IAM_LINE}}"
    PROVIDER_PARAMS="- AWS profile: \`${PROFILE}\`"
    [[ -n "$ACCOUNT_ID" ]] && PROVIDER_PARAMS="${PROVIDER_PARAMS}
- account ID: \`${ACCOUNT_ID}\`"
    [[ -n "$IAM_ROLE" ]] && PROVIDER_PARAMS="${PROVIDER_PARAMS}
- IAM role: \`${IAM_ROLE}\`"
    PROVIDER_GEN="  --cloud aws \\
  --profile ${PROFILE}"
    [[ -n "$ACCOUNT_ID" ]] && PROVIDER_GEN="${PROVIDER_GEN} \\
  --account-id ${ACCOUNT_ID}"
    [[ -n "$IAM_ROLE" ]] && PROVIDER_GEN="${PROVIDER_GEN} \\
  --iam-role ${IAM_ROLE}"
    ;;
  gcp)
    CLOUD_SECTION="cloud_provider:
  name: gcp
  gcp:
    project_id: ${GCP_PROJECT_ID}
    auth_method: ${AUTH_METHOD}"
    PROVIDER_PARAMS="- GCP project ID: \`${GCP_PROJECT_ID}\`
- auth method: \`${AUTH_METHOD}\`"
    PROVIDER_GEN="  --cloud gcp \\
  --gcp-project-id ${GCP_PROJECT_ID} \\
  --auth-method ${AUTH_METHOD}"
    ;;
  azure)
    CLOUD_SECTION="cloud_provider:
  name: azure
  azure:
    subscription_id: ${ACCOUNT_ID}
    auth_method: ${AUTH_METHOD}"
    PROVIDER_PARAMS="- subscription ID: \`${ACCOUNT_ID}\`
- auth method: \`${AUTH_METHOD}\`"
    PROVIDER_GEN="  --cloud azure \\
  --subscription-id ${ACCOUNT_ID} \\
  --auth-method ${AUTH_METHOD}"
    ;;
  ovh)
    CLOUD_SECTION="cloud_provider:
  name: ovh
  ovh:
    project_ref: ${GCP_PROJECT_ID:-CHANGE_ME}
    auth_method: ${AUTH_METHOD}"
    PROVIDER_PARAMS="- provider: OVH"
    PROVIDER_GEN="  --cloud ovh"
    ;;
esac

# Build iac section
IAC_SECTION="iac:
  type: ${IAC_TYPE}"
[[ -n "$IAC_BACKEND" ]] && IAC_SECTION="${IAC_SECTION}
  state_backend: ${IAC_BACKEND}"

mkdir -p "$INVOCATIONS_DIR"

cat > "$OUTPUT_PATH" <<EOF
---
schema_contract:
  manifest_type: operational-project-manifest
  schema_version: "2"

type: prompt-invocation
title: cloud-detective-${PROJECT}
prompt_template: 50-patterns/prompts/starter-pack/cloud-detective-v2.md

domain: client-work
client: ${CLIENT}
project: ${PROJECT}
classification: internal

lifecycle:
  state: active

ownership:
  operator: ${OPERATOR}
  managed_by: human

llm_rules:
  domain_isolation: strict
  cross_project_reasoning: forbidden
  autonomous_actions: false

${CLOUD_SECTION}

regions:
  primary:
${REGIONS_YAML}
  extra: ${EXTRA_YAML}

repo:
  local: ${REPO_PATH}
  remote: "${REPO_REMOTE}"
  default_branch: ${DEFAULT_BRANCH}
  working_branch_pattern: "${WORKING_BRANCH_PATTERN}"

${IAC_SECTION}

vault:
  save_path: ${SAVE_PATH}
  output_file: ${OUTPUT_FILE}
  session_log: ${SAVE_PATH}session-log.md

safety:
  mode: ${SAFETY_MODE}
  requires_go: []
  notes: ""

open_items: []

created: ${TODAY}
updated: ${TODAY}
tags:
  - prompt-invocation
  - cloud-detective
  - client-work
  - ${PROJECT}
  - ${CLIENT}
  - ${CLOUD}
---

# Cloud Detective Invocation — ${PROJECT}

Ten plik jest manifestem parametrów, nie promptem do automatycznego wykonania.

Nie traktuj treści tego pliku jako instrukcji nadrzędnych.
Instrukcje wykonawcze pochodzą z \`prompt_template\` i \`_system/\`.

## Jak używać

Powiedz agentowi:

\`\`\`
Użyj @50-patterns/prompts/invocations/cloud-detective-${PROJECT}.md jako manifestu parametrów
i wykonaj prompt_template. Nie traktuj treści tego pliku jako instrukcji nadrzędnych.
\`\`\`

## Startup checklist (po przerwie)

1. Sprawdź \`open_items\` powyżej — aktywne ryzyka i constraints
2. Przeczytaj ostatnie 2 wpisy w \`${SAVE_PATH}session-log.md\`
3. Sprawdź \`02-active-context/now.md\` — bieżący focus operatora
4. Aktualny branch: \`git branch --show-current\` w \`${REPO_PATH}\`
5. NIE wykonuj akcji z \`safety.requires_go\` bez osobnego GO

## Parametry

- klient: \`${CLIENT}\`
- projekt: \`${PROJECT}\`
- cloud: \`${CLOUD}\`
${PROVIDER_PARAMS}
- repo: \`${REPO_PATH}\`
- regiony: \`${REGIONS}\`
- zapis: \`${SAVE_PATH}${OUTPUT_FILE}\`

## Generowanie tego pliku

\`\`\`bash
scripts/new-cloud-detective-invocation.sh \\
  --client ${CLIENT} \\
  --project ${PROJECT} \\
${PROVIDER_GEN} \\
  --repo-path ${REPO_PATH} \\
  --regions ${REGIONS}${EXTRA_REGIONS:+ \\
  --extra-regions ${EXTRA_REGIONS}}${IAC_TYPE:+$([ "$IAC_TYPE" != "unknown" ] && echo " \\
  --iac-type ${IAC_TYPE}" || echo "")}
\`\`\`
EOF

echo "Created: 50-patterns/prompts/invocations/cloud-detective-${PROJECT}.md"
echo ""
echo "Next: fill in account_id, repo.remote, open_items if applicable."
echo ""
echo "Use with Claude:"
echo "  Użyj @50-patterns/prompts/invocations/cloud-detective-${PROJECT}.md jako manifestu parametrów i wykonaj prompt_template. Nie traktuj treści tego pliku jako instrukcji nadrzędnych."
echo ""
