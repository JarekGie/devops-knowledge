# Design: Maspex Load Test Generator AMI (Packer + Rich AMI + Runtime Bootstrap)

**Date:** 2026-05-14  
**Status:** approved  
**Domain:** client-work / maspex  
**Author:** Jaroslaw Golab + Claude

---

## 1. Problem Statement

Current load test generators (ASG `maspex-uat-loadtest`) start from a stock Amazon Linux 2023 AMI and assemble the entire workshop via `user_data` at boot:
- installs Docker, k6, Docker Compose plugin (unpinned `latest`)
- copies no workspace files — k6 scripts, Grafana provisioning, token generator are only on live instances, not in repo
- startup time: ~8–12 min
- no token generation automation — manual / out-of-band
- no idempotent bootstrap

**Goal:** replace this with a Rich AMI built by Packer containing the full workshop, with a lightweight runtime bootstrap (secrets → tokens → start stack → health check) taking ~60–90s.

---

## 2. Approach Selected

**Rich AMI (Approach A)** — bake all static artifacts into the AMI, runtime does secrets + tokens + stack start only.

Rejected alternatives:
- **Approach B (Minimal AMI + S3 workspace):** extra S3 dependency, more complex bootstrap, no benefit for a workspace that changes infrequently.
- **Approach C (current model):** slow, unpinned dependencies, no workspace versioning.

---

## 3. What Goes Into the AMI

| Layer | Contents |
|-------|----------|
| System tools | Docker CE (pinned), Docker Compose plugin (pinned), k6 (pinned version from Grafana RPM repo), jq, htop, nmap-ncat, Node.js (LTS) |
| Workspace | `/opt/loadtest/` owned by `ec2-user` |
| Stack | `docker-compose.yml` — InfluxDB `1.8` + Grafana (pinned minor version) |
| Grafana provisioning | `datasources/influxdb.yaml` (UID: `dfm0hl1zdovswd`, fully baked-in, no runtime override needed) |
| Grafana dashboards | `k6-load-testing-by-groups.json` (Grafana Labs ID 13719) |
| k6 scenarios | `k6/` — kapsel.js, kapsel-spike.js, kapsel-submit.js, kapsel-vote.js, kapsel-main-page.js, kapsel-with-fe.js |
| Token generator | `token-generator/generate-tokens-fn.js` + `package.json` + `package-lock.json` + `node_modules/` (pre-installed via `npm ci --production`) |
| Bootstrap script | `/opt/loadtest/bootstrap.sh` |
| systemd unit | `loadtest-bootstrap.service` (registered + enabled at Packer build time) |

**What is NOT baked in:**
- `JWT_SECRET`, `JWT_KID` — from AWS Secrets Manager at runtime
- `.env` — not used; secrets passed via env vars in memory only
- `tokens.json` — generated at runtime, stored in `/opt/loadtest/runtime/`
- `bootstrap.status` — written by bootstrap.sh on completion

---

## 4. File Structure in Repo

```
scripts/loadtest/
├── docker-compose.yml
├── grafana/
│   ├── provisioning/
│   │   ├── datasources/influxdb.yaml      # uid: dfm0hl1zdovswd
│   │   └── dashboards/default.yaml
│   └── dashboards/
│       └── k6-load-testing-by-groups.json
├── k6/                                    # renamed from scripts/
│   ├── kapsel.js
│   ├── kapsel-spike.js
│   ├── kapsel-submit.js
│   ├── kapsel-vote.js
│   ├── kapsel-main-page.js
│   └── kapsel-with-fe.js
├── token-generator/
│   ├── generate-tokens-fn.js              # supports --secret-file or env vars
│   ├── package.json
│   └── package-lock.json                  # required for npm ci
├── bootstrap.sh                           # runtime bootstrap script
└── loadtest-bootstrap.service             # systemd unit

packer/
├── ami.pkr.hcl                            # main Packer template
├── variables.pkr.hcl                      # region, ami_name_prefix, source_ami_filter
└── scripts/
    ├── install-tools.sh                   # dnf + pinned versions
    ├── setup-workspace.sh                 # /opt/loadtest, npm ci --production
    ├── setup-systemd.sh                   # register + enable loadtest-bootstrap.service
    └── cleanup.sh                         # yum cache, history, temp files
```

### On-instance layout after boot

```
/opt/loadtest/                             # owned ec2-user (from AMI)
├── docker-compose.yml
├── grafana/ ...
├── k6/ ...
├── token-generator/  (node_modules pre-installed)
├── bootstrap.sh
└── runtime/                               # created by bootstrap.sh, chmod 700
    ├── tokens.json                        # chmod 600 — generated JWT tokens
    └── bootstrap.status                   # "READY 2026-05-14T10:00:00Z"
```

---

## 5. Runtime Bootstrap Design

### bootstrap.sh — execution phases

```
Phase 1: Sekrety (in-memory only, no persistence)
  SECRET_JSON=$(aws secretsmanager get-secret-value \
    --secret-id maspex/uat/api \
    --query SecretString --output text)
  export JWT_SECRET=$(echo "$SECRET_JSON" | jq -r '.JWT_SECRET')
  export JWT_KID=$(echo "$SECRET_JSON" | jq -r '.JWT_KID')
  unset SECRET_JSON

Phase 2: Token generation
  mkdir -p /opt/loadtest/runtime
  chmod 700 /opt/loadtest/runtime
  cd /opt/loadtest/token-generator
  JWT_SECRET="$JWT_SECRET" JWT_KID="$JWT_KID" \
    node generate-tokens-fn.js \
    > /opt/loadtest/runtime/tokens.json
  chmod 600 /opt/loadtest/runtime/tokens.json
  unset JWT_SECRET JWT_KID

Phase 3: Start stack
  cd /opt/loadtest
  docker compose up -d

Phase 4: Health checks (idempotent, retry loop)
  wait_for_healthy() {
    for i in $(seq 20); do curl -sf "$1" && return 0; sleep 3; done; return 1
  }
  wait_for_healthy http://localhost:8086/ping
  wait_for_healthy http://localhost:3000/api/health
  docker exec $(docker compose ps -q influxdb) \
    influx -execute "CREATE DATABASE IF NOT EXISTS k6"

Phase 5: Write status
  echo "READY $(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    > /opt/loadtest/runtime/bootstrap.status
```

**Bootstrap guarantees:**
- `set -euo pipefail` — fails fast on any error
- `mkdir -p` everywhere — idempotent
- Secrets held in shell vars only — never written to disk as plaintext
- `tokens.json` overwritten on each boot (safe idempotency)
- `bootstrap.status` overwritten on each boot

### systemd unit

```ini
[Unit]
Description=Load test bootstrap
After=docker.service network-online.target
Wants=network-online.target
Requires=docker.service

[Service]
Type=oneshot
User=ec2-user
ExecStart=/opt/loadtest/bootstrap.sh
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

Diagnostics: `journalctl -u loadtest-bootstrap -f`

---

## 6. Packer Template — Key Decisions

- **Base AMI:** Amazon Linux 2023 (latest at build time, filtered by `al2023-ami-2023.*-x86_64`)
- **Build instance type:** `t3.medium` (cheap, sufficient for dnf + npm ci)
- **Region:** `eu-west-1`
- **AMI naming:** `maspex-uat-loadtest-YYYYMMDD-HHmmss` — sortable, no `latest` tag
- **Provisioner order:**
  1. `shell: install-tools.sh` — pinned versions via dnf + manual binary installs
  2. `file` — copies `scripts/loadtest/` → `/opt/loadtest/`
  3. `shell: setup-workspace.sh` — `chown -R ec2-user`, `npm ci --production`
  4. `shell: setup-systemd.sh` — `systemctl enable loadtest-bootstrap`
  5. `shell: cleanup.sh` — clear caches, remove build artifacts
- **AMI output:** single AMI in eu-west-1, tagged `project=maspex`, `environment=uat`, `managed_by=packer`

---

## 7. IAM Changes Required

Current role `maspex-uat-loadtest` has only `AmazonSSMManagedInstanceCore`.

### Add to `loadtest.tf`:

```hcl
resource "aws_iam_role_policy" "loadtest_secrets" {
  name = "loadtest-secrets-read"
  role = aws_iam_role.loadtest.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = "arn:aws:secretsmanager:eu-west-1:969209893152:secret:maspex/uat/api-*"
      },
      # Add kms:Decrypt if the secret uses a CMK (customer-managed KMS key)
      # {
      #   Effect   = "Allow"
      #   Action   = "kms:Decrypt"
      #   Resource = "<CMK_ARN>"
      # }
    ]
  })
}
```

### Add if S3 results archiving is enabled:

```hcl
resource "aws_iam_role_policy" "loadtest_s3_results" {
  name = "loadtest-s3-results-write"
  role = aws_iam_role.loadtest.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject"]
      Resource = "arn:aws:s3:::maspex-loadtest-artifacts/results/*"
    }]
  })
}
```

---

## 8. Secrets Manager — Required Change

`JWT_KID` must be added to the existing secret `maspex/uat/api`.

Current secret structure (assumed):
```json
{ "JWT_SECRET": "...", ... }
```

Required secret structure:
```json
{ "JWT_SECRET": "...", "JWT_KID": "...", ... }
```

This is a one-time manual operation (or via Terraform `aws_secretsmanager_secret_version`).

---

## 9. S3 Test Results Archiving

**Scope:** test run artifacts only. Everything else stays ephemeral.

**What to archive:**
- `summary.json` — k6 `--summary-export` output
- `metadata.json` — run context

**`metadata.json` schema:**
```json
{
  "ami_id": "ami-xxxx",
  "launch_template_version": "3",
  "instance_id": "i-xxxx",
  "scenario_name": "kapsel-spike",
  "target_rps": 500,
  "prescale_value": 4,
  "started_at": "2026-05-14T10:00:00Z",
  "ended_at": "2026-05-14T10:30:00Z"
}
```

**S3 layout:**
```
s3://maspex-loadtest-artifacts/
└── results/
    └── 2026-05-14T10-00-00Z/
        ├── summary.json
        └── metadata.json
```

**Lifecycle:** 90 days → expire. No versioning, no replication.

---

## 10. ASG Integration — Rollout Plan

**AMI ID is managed as a Terraform variable, not hardcoded in the resource.**

### In `terraform/envs/uat/terraform.tfvars`:
```hcl
loadtest_ami_id = "ami-xxxx"   # updated after each packer build
```

### In `loadtest.tf`:
```hcl
variable "loadtest_ami_id" {
  description = "AMI ID for load test generators (output of packer build)"
  type        = string
}

resource "aws_launch_template" "loadtest" {
  image_id = var.loadtest_ami_id
  # ...
}
```

### Rollout steps:

| Step | Action | Risk |
|------|--------|------|
| 1 | `packer build` → note AMI ID output | None — isolated build instance |
| 2 | Update `terraform.tfvars`: `loadtest_ami_id = "ami-xxxx"` | None |
| 3 | `terraform plan` — review LT version diff | None |
| 4 | `terraform apply` → new Launch Template version | None — existing instances unaffected |
| 5 | `./scripts/loadtest-ctrl.sh --stop` | Normal shutdown |
| 6 | `./scripts/loadtest-ctrl.sh --run` → ASG starts with new AMI | First real boot of new AMI |
| 7 | SSH in: `systemctl status loadtest-bootstrap` + `cat /opt/loadtest/runtime/bootstrap.status` | Validation |

**Do NOT use `instance refresh` or force-replace running instances.** Stop/start via existing fleet scripts is sufficient and safer.

**Note on data source removal:** The existing `data "aws_ami" "loadtest_al2023"` block in `loadtest.tf` must be removed (or kept but unused) when switching to `var.loadtest_ami_id`. Leaving an unreferenced data source is harmless but adds noise — remove it as part of the same PR.

---

## 11. InfluxDB Version Decision

**Stay on InfluxDB 1.8.** Reasons:
- k6 native output (`K6_OUT=influxdb=http://...`) uses InfluxDB 1.x line protocol
- InfluxDB 2.x requires `xk6-output-influxdb` (custom k6 binary rebuild)
- Grafana dashboard 13719 is designed for InfluxDB 1.x datasource
- No operational benefit from migration at this stage

---

## 12. Open Items Before Implementation

| Item | Action | Priority |
|------|--------|----------|
| k6 scripts on live instances | Copy to repo under `scripts/loadtest/k6/` | HIGH — blocks Packer build |
| `generate-tokens-fn.js` | Copy to repo, add env var input support (`JWT_SECRET`, `JWT_KID`), add `package-lock.json` | HIGH — blocks bootstrap |
| `JWT_KID` in Secrets Manager | Add to `maspex/uat/api` secret | HIGH — blocks bootstrap |
| CMK on secret? | Check if `maspex/uat/api` uses CMK — if yes, add `kms:Decrypt` to IAM | MEDIUM |
| Packer install | Install locally (Homebrew or tfenv equivalent) | HIGH — blocks build |
| S3 bucket for results | Decide: create now or defer | LOW — not blocking |
