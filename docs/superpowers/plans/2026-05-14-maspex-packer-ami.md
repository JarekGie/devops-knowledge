# Maspex Load Test Generator AMI — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Rich AMI with Packer containing the full load test workshop (Docker, k6, InfluxDB/Grafana stack, k6 scripts, token generator), so ASG generators start in ~90s with only secrets + token generation at runtime.

**Architecture:** Packer builds an AL2023-based AMI from `infra-maspex/` repo. All static artifacts (workspace, scripts, provisioning) are baked in via file+shell provisioners. A systemd unit (`loadtest-bootstrap.service`) runs `bootstrap.sh` on every boot: fetches `JWT_SECRET`+`JWT_KID` from Secrets Manager, generates `tokens.json`, starts `docker compose`, creates InfluxDB `k6` database, writes `bootstrap.status`. Terraform switches Launch Template from dynamic AMI lookup to a pinned `var.loadtest_ami_id`.

**Tech Stack:** Packer HCL2 (hashicorp/amazon plugin), Amazon Linux 2023, Docker CE, Docker Compose plugin v2.28.1, k6 (Grafana RPM repo), InfluxDB 1.8, Grafana 10.4.3, Node.js 20, Terraform 5.x (AWS provider), AWS Secrets Manager.

**Repo root (all relative paths from here):** `~/projekty/mako/aws-projects/infra-maspex/`

---

## File Map

### New files

| Path | Purpose |
|------|---------|
| `packer/ami.pkr.hcl` | Packer build definition |
| `packer/variables.pkr.hcl` | Packer input variables |
| `packer/scripts/install-tools.sh` | dnf installs + pinned binary downloads |
| `packer/scripts/setup-workspace.sh` | create `/opt/loadtest/`, npm ci |
| `packer/scripts/setup-systemd.sh` | register + enable systemd unit |
| `packer/scripts/cleanup.sh` | clear caches, history |
| `scripts/loadtest/k6/kapsel.js` | k6 main scenario (from kapsel.zip) |
| `scripts/loadtest/k6/kapsel-clean.js` | k6 clean variant |
| `scripts/loadtest/k6/kapsel-main-page.js` | k6 main page only |
| `scripts/loadtest/k6/kapsel-spike.js` | k6 spike scenario |
| `scripts/loadtest/k6/kapsel-submit.js` | k6 submit only |
| `scripts/loadtest/k6/kapsel-vote.js` | k6 vote only |
| `scripts/loadtest/k6/kapsel-with-fe.js` | k6 full frontend |
| `scripts/loadtest/token-generator/generate-tokens-fn.js` | token generator (from testy-qa/, secrets via env) |
| `scripts/loadtest/token-generator/package.json` | Node.js project manifest |
| `scripts/loadtest/token-generator/package-lock.json` | lockfile for npm ci |
| `scripts/loadtest/bootstrap.sh` | runtime bootstrap script |
| `scripts/loadtest/loadtest-bootstrap.service` | systemd unit |

### Modified files

| Path | Change |
|------|--------|
| `scripts/loadtest/docker-compose.yml` | pin `grafana/grafana:10.4.3` |
| `terraform/envs/uat/loadtest.tf` | add SM IAM policy, add `loadtest_ami_id` variable, switch LT to use it, remove unused data source |
| `terraform/envs/uat/variables.tf` | add `loadtest_ami_id` variable block |
| `terraform/envs/uat/terraform.tfvars` | add `loadtest_ami_id = ""` (filled after build) |

---

## Task 1: Install Packer

**Files:** none (local tooling)

- [ ] **Step 1: Install via Homebrew**

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/packer
```

- [ ] **Step 2: Verify**

```bash
packer version
```

Expected output (version ≥ 1.11.0):
```
Packer v1.11.x
```

---

## Task 2: Fix token generator — remove hardcoded secrets, move to repo

**Files:**
- Create: `scripts/loadtest/token-generator/generate-tokens-fn.js`
- Create: `scripts/loadtest/token-generator/package.json`
- Create: `scripts/loadtest/token-generator/package-lock.json`

- [ ] **Step 1: Create directory**

```bash
mkdir -p scripts/loadtest/token-generator
```

- [ ] **Step 2: Copy from testy-qa and fix hardcoded secrets**

Copy `testy-qa/generate-tokens-fn.js` to `scripts/loadtest/token-generator/generate-tokens-fn.js`, then replace the hardcoded constants block (lines 7–10) with env var reads:

```js
// generate-tokens-fn.js
const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

// --- KONFIGURACJA ---
const PROJECT_ID = "lihjysuxubtutmbpsgqd";
const JWT_SECRET = process.env.JWT_SECRET;
const JWT_KID = process.env.JWT_KID;

if (!JWT_SECRET || !JWT_KID) {
  throw new Error("JWT_SECRET and JWT_KID environment variables are required");
}

function base64url(str) {
  return Buffer.from(str)
    .toString("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=/g, "");
}

function generateValidJWT(payload, secret) {
  const header = { alg: "HS256", kid: JWT_KID, typ: "JWT" };
  const encodedHeader = base64url(JSON.stringify(header));
  const encodedPayload = base64url(JSON.stringify(payload));
  const dataToSign = `${encodedHeader}.${encodedPayload}`;
  const signature = crypto
    .createHmac("sha256", secret)
    .update(dataToSign)
    .digest("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=/g, "");
  return `${dataToSign}.${signature}`;
}

/**
 * Generuje tokeny JWT lokalnie i zapisuje je do pliku JSON.
 * @param {number} count - Liczba tokenów do wygenerowania
 * @param {object} [options]
 * @param {number} [options.startIndex=10001] - Numer startowy użytkownika
 * @param {string} [options.emailDomain='example.com'] - Domena adresu e-mail
 * @param {string} [options.outputFile='tokens.json'] - Ścieżka do pliku wynikowego
 */
function generateTokens(count, options = {}) {
  const {
    startIndex = 10001,
    emailDomain = "example.com",
    outputFile = "tokens.json",
  } = options;

  const tokens = [];

  for (let i = startIndex; i < startIndex + count; i++) {
    const userId = `00000000-0000-0000-0000-${i.toString().padStart(12, "0")}`;
    const email = `user-test-uat-${i}@${emailDomain}`;
    const now = Math.floor(Date.now() / 1000);
    const payload = {
      iss: `https://${PROJECT_ID}.supabase.co/auth/v1`,
      sub: userId,
      aud: "authenticated",
      exp: now + 60 * 60 * 24,
      iat: now,
      email,
      phone: "",
      app_metadata: { provider: "email", providers: ["email"] },
      user_metadata: { full_name: "TestUser" },
      role: "authenticated",
      aal: "aal1",
      amr: [{ method: "password", timestamp: now }],
      session_id: "c87b2411-c1c6-40f1-8cdd-8b74c064d165",
      is_anonymous: false,
    };

    const access_token = generateValidJWT(payload, JWT_SECRET);
    tokens.push({ access_token, user_id: userId, email });
  }

  const outputPath = path.resolve(outputFile);
  fs.writeFileSync(outputPath, JSON.stringify(tokens, null, 2));
  console.log(`Wygenerowano ${tokens.length} tokenów. Zapisano do: ${outputPath}`);

  return tokens;
}

// CLI: node generate-tokens-fn.js [count] [startIndex] [outputFile]
if (require.main === module) {
  const count = parseInt(process.argv[2] ?? "5000", 10);
  const startIndex = parseInt(process.argv[3] ?? "10001", 10);
  const outputFile = process.argv[4] ?? "tokens.json";
  generateTokens(count, { startIndex, outputFile });
}

module.exports = { generateTokens };
```

- [ ] **Step 3: Create package.json**

```json
{
  "name": "maspex-token-generator",
  "version": "1.0.0",
  "description": "JWT token generator for Maspex load tests — reads JWT_SECRET and JWT_KID from env",
  "main": "generate-tokens-fn.js",
  "scripts": {
    "generate": "node generate-tokens-fn.js"
  },
  "dependencies": {},
  "engines": {
    "node": ">=18"
  }
}
```

- [ ] **Step 4: Generate package-lock.json**

```bash
cd scripts/loadtest/token-generator
npm install
cd -
```

Expected: `package-lock.json` created with `"lockfileVersion": 3`, no packages in `node_modules/` (no external deps).

- [ ] **Step 5: Smoke-test the fixed script locally**

```bash
cd scripts/loadtest/token-generator
JWT_SECRET="test-secret-for-local-validation" \
JWT_KID="test-kid" \
  node generate-tokens-fn.js 3 10001 /tmp/test-tokens.json
```

Expected output:
```
Wygenerowano 3 tokenów. Zapisano do: /tmp/test-tokens.json
```

```bash
jq 'length' /tmp/test-tokens.json
```

Expected: `3`

- [ ] **Step 6: Verify error on missing env vars**

```bash
cd scripts/loadtest/token-generator
node generate-tokens-fn.js 3 2>&1 || true
```

Expected: `Error: JWT_SECRET and JWT_KID environment variables are required`

- [ ] **Step 7: Commit**

```bash
git add scripts/loadtest/token-generator/
git commit -m "feat(loadtest): add token-generator to repo, remove hardcoded secrets

Moves generate-tokens-fn.js from testy-qa/ to scripts/loadtest/token-generator/.
JWT_SECRET and JWT_KID are now read from environment variables — never hardcoded.
Added package.json + package-lock.json for npm ci support."
```

---

## Task 3: Extract k6 scripts from kapsel.zip

**Files:** `scripts/loadtest/k6/*.js` (7 files)

- [ ] **Step 1: Create k6 directory and extract scripts**

```bash
mkdir -p scripts/loadtest/k6
cd testy-qa
unzip -j kapsel.zip "kapsel-perf/scripts/*" -d ../scripts/loadtest/k6/
cd -
```

- [ ] **Step 2: Verify — no tokens.json, only .js files**

```bash
ls scripts/loadtest/k6/
```

Expected (7 files, no `tokens.json`):
```
kapsel-clean.js  kapsel-main-page.js  kapsel-spike.js  kapsel-submit.js
kapsel-vote.js   kapsel-with-fe.js    kapsel.js
```

- [ ] **Step 3: Syntax-check scripts**

```bash
for f in scripts/loadtest/k6/*.js; do
  node --check "$f" && echo "OK: $f" || echo "FAIL: $f"
done
```

Expected: `OK:` for all 7 files.

- [ ] **Step 4: Commit**

```bash
git add scripts/loadtest/k6/
git commit -m "feat(loadtest): add k6 scenario scripts to repo

Extracted from testy-qa/kapsel.zip into scripts/loadtest/k6/.
Scenarios: kapsel (main), clean, spike, submit, vote, main-page, with-fe.
These are now versioned and will be baked into the load test AMI."
```

---

## Task 4: Pin Grafana version in docker-compose.yml

**Files:**
- Modify: `scripts/loadtest/docker-compose.yml`

- [ ] **Step 1: Update Grafana image tag**

In `scripts/loadtest/docker-compose.yml`, change line:
```yaml
    image: grafana/grafana
```
to:
```yaml
    image: grafana/grafana:10.4.3
```

Full file after change:

```yaml
services:
  influxdb:
    image: influxdb:1.8
    ports:
      - "8086:8086"
    environment:
      - INFLUXDB_DB=k6
      - INFLUXDB_HTTP_AUTH_ENABLED=false
    volumes:
      - influxdb-data:/var/lib/influxdb

  grafana:
    image: grafana/grafana:10.4.3
    ports:
      - "3000:3000"
    environment:
      - GF_AUTH_ANONYMOUS_ENABLED=true
      - GF_AUTH_ANONYMOUS_ORG_ROLE=Admin
    volumes:
      - grafana-data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
      - ./grafana/dashboards:/etc/grafana/dashboards
    depends_on:
      - influxdb

volumes:
  influxdb-data:
  grafana-data:
```

- [ ] **Step 2: Commit**

```bash
git add scripts/loadtest/docker-compose.yml
git commit -m "fix(loadtest): pin grafana/grafana:10.4.3 in docker-compose

Unpinned 'latest' tag causes non-deterministic AMI builds.
influxdb:1.8 was already pinned — grafana now matches."
```

---

## Task 5: Create bootstrap.sh

**Files:**
- Create: `scripts/loadtest/bootstrap.sh`

- [ ] **Step 1: Create the file**

```bash
cat > scripts/loadtest/bootstrap.sh << 'BOOTSTRAP'
#!/usr/bin/env bash
# Runtime bootstrap for maspex load test generators.
# Runs on every boot via loadtest-bootstrap.service (systemd).
# Idempotent: safe to re-run.
set -euo pipefail

WORKSPACE="/opt/loadtest"
RUNTIME_DIR="$WORKSPACE/runtime"
REGION="eu-west-1"
SECRET_ID="maspex/uat/api"

log()  { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" | tee -a /var/log/loadtest-bootstrap.log; }
fail() { log "ERROR: $*"; exit 1; }

log "=== loadtest bootstrap start ==="

# ── Phase 1: Secrets ────────────────────────────────────────────────────────
log "Phase 1: Fetching secrets from Secrets Manager ($SECRET_ID)"

SECRET_JSON=$(aws secretsmanager get-secret-value \
  --secret-id "$SECRET_ID" \
  --query SecretString \
  --output text \
  --region "$REGION") || fail "secretsmanager:GetSecretValue failed"

JWT_SECRET=$(echo "$SECRET_JSON" | jq -r '.JWT_SECRET // empty')
JWT_KID=$(echo    "$SECRET_JSON" | jq -r '.JWT_KID // empty')
unset SECRET_JSON

[[ -n "$JWT_SECRET" ]] || fail "JWT_SECRET not found in $SECRET_ID"
[[ -n "$JWT_KID"    ]] || fail "JWT_KID not found in $SECRET_ID"

log "Secrets fetched."

# ── Phase 2: Token generation ────────────────────────────────────────────────
log "Phase 2: Generating JWT tokens"

mkdir -p "$RUNTIME_DIR"
chmod 700 "$RUNTIME_DIR"

cd "$WORKSPACE/token-generator"
JWT_SECRET="$JWT_SECRET" JWT_KID="$JWT_KID" \
  node generate-tokens-fn.js 5000 10001 "$RUNTIME_DIR/tokens.json"
chmod 600 "$RUNTIME_DIR/tokens.json"
unset JWT_SECRET JWT_KID

TOKEN_COUNT=$(jq length "$RUNTIME_DIR/tokens.json")
log "Generated $TOKEN_COUNT tokens → $RUNTIME_DIR/tokens.json"

# ── Phase 3: Start stack ─────────────────────────────────────────────────────
log "Phase 3: Starting Docker Compose stack"

cd "$WORKSPACE"
docker compose up -d

# ── Phase 4: Health checks + DB init ─────────────────────────────────────────
log "Phase 4: Health checks"

wait_for_healthy() {
  local url="$1" max=20 i
  for i in $(seq "$max"); do
    if curl -sf "$url" > /dev/null 2>&1; then
      log "  $url → healthy"
      return 0
    fi
    log "  waiting for $url ($i/$max)..."
    sleep 3
  done
  fail "Service $url not healthy after $(( max * 3 ))s"
}

wait_for_healthy "http://localhost:8086/ping"
wait_for_healthy "http://localhost:3000/api/health"

log "Creating InfluxDB k6 database (idempotent)"
docker exec "$(docker compose ps -q influxdb)" \
  influx -execute "CREATE DATABASE k6" 2>/dev/null || true

# ── Phase 5: Done ────────────────────────────────────────────────────────────
echo "READY $(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$RUNTIME_DIR/bootstrap.status"
log "=== loadtest bootstrap READY ==="
BOOTSTRAP

chmod +x scripts/loadtest/bootstrap.sh
```

- [ ] **Step 2: Validate syntax**

```bash
bash -n scripts/loadtest/bootstrap.sh && echo "Syntax OK"
```

Expected: `Syntax OK`

- [ ] **Step 3: Commit**

```bash
git add scripts/loadtest/bootstrap.sh
git commit -m "feat(loadtest): add runtime bootstrap.sh

Fetches JWT_SECRET+JWT_KID from Secrets Manager, generates 5000 tokens,
starts docker compose stack, waits for InfluxDB+Grafana health, creates
k6 database. Idempotent, logs to journald + /var/log/loadtest-bootstrap.log."
```

---

## Task 6: Create systemd unit

**Files:**
- Create: `scripts/loadtest/loadtest-bootstrap.service`

- [ ] **Step 1: Create the unit file**

```bash
cat > scripts/loadtest/loadtest-bootstrap.service << 'UNIT'
[Unit]
Description=Maspex load test bootstrap
Documentation=https://github.com/makolab
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
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
UNIT
```

- [ ] **Step 2: Validate (syntax check — systemd-analyze not always available, use basic check)**

```bash
grep -E "^\[Unit\]|^\[Service\]|^\[Install\]" scripts/loadtest/loadtest-bootstrap.service
```

Expected output:
```
[Unit]
[Service]
[Install]
```

- [ ] **Step 3: Commit**

```bash
git add scripts/loadtest/loadtest-bootstrap.service
git commit -m "feat(loadtest): add loadtest-bootstrap systemd unit

Runs bootstrap.sh once at boot after docker.service.
Type=oneshot + RemainAfterExit: visible via systemctl status."
```

---

## Task 7: Create Packer provisioner scripts

**Files:**
- Create: `packer/scripts/install-tools.sh`
- Create: `packer/scripts/setup-workspace.sh`
- Create: `packer/scripts/setup-systemd.sh`
- Create: `packer/scripts/cleanup.sh`

- [ ] **Step 1: Create directory**

```bash
mkdir -p packer/scripts
```

- [ ] **Step 2: Create install-tools.sh**

```bash
cat > packer/scripts/install-tools.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

DOCKER_COMPOSE_VERSION="2.28.1"
K6_VERSION="0.56.0"

echo "=== install-tools: updating packages ==="
dnf update -y --allowerasing

echo "=== install-tools: base packages ==="
dnf install -y docker htop iotop tcpdump wget jq git nmap-ncat

echo "=== install-tools: Node.js 20 (nodesource) ==="
curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
dnf install -y nodejs

echo "=== install-tools: Docker service ==="
systemctl enable docker
systemctl start docker
usermod -aG docker ec2-user

echo "=== install-tools: Docker Compose plugin v${DOCKER_COMPOSE_VERSION} ==="
mkdir -p /usr/local/lib/docker/cli-plugins
curl -fsSL \
  "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-linux-x86_64" \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
ln -sf /usr/local/lib/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose

echo "=== install-tools: k6 v${K6_VERSION} ==="
dnf install -y \
  "https://github.com/grafana/k6/releases/download/v${K6_VERSION}/k6-v${K6_VERSION}-linux-amd64.rpm"

echo "=== install-tools: verification ==="
docker --version
docker compose version
k6 version
node --version
npm --version
jq --version
echo "install-tools: DONE"
EOF
chmod +x packer/scripts/install-tools.sh
```

- [ ] **Step 3: Create setup-workspace.sh**

```bash
cat > packer/scripts/setup-workspace.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "=== setup-workspace: moving files ==="
mv /tmp/loadtest /opt/loadtest
chown -R ec2-user:ec2-user /opt/loadtest
chmod +x /opt/loadtest/bootstrap.sh

echo "=== setup-workspace: npm ci --production ==="
cd /opt/loadtest/token-generator
# No external dependencies — npm ci confirms package-lock.json is valid
sudo -u ec2-user npm ci --production

echo "=== setup-workspace: verify structure ==="
ls -la /opt/loadtest/
ls -la /opt/loadtest/k6/
ls -la /opt/loadtest/token-generator/
echo "setup-workspace: DONE"
EOF
chmod +x packer/scripts/setup-workspace.sh
```

- [ ] **Step 4: Create setup-systemd.sh**

```bash
cat > packer/scripts/setup-systemd.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "=== setup-systemd: registering loadtest-bootstrap.service ==="
cp /opt/loadtest/loadtest-bootstrap.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable loadtest-bootstrap.service

echo "=== setup-systemd: verify ==="
systemctl is-enabled loadtest-bootstrap.service
echo "setup-systemd: DONE"
EOF
chmod +x packer/scripts/setup-systemd.sh
```

- [ ] **Step 5: Create cleanup.sh**

```bash
cat > packer/scripts/cleanup.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "=== cleanup: clearing caches ==="
dnf clean all
rm -rf /tmp/*
rm -rf /var/tmp/*
rm -f /home/ec2-user/.bash_history
rm -f /root/.bash_history
# Stop and remove container images pulled during build (none expected here)
# systemd journal cleanup
journalctl --vacuum-time=1s 2>/dev/null || true
echo "cleanup: DONE"
EOF
chmod +x packer/scripts/cleanup.sh
```

- [ ] **Step 6: Syntax check all scripts**

```bash
for f in packer/scripts/*.sh; do
  bash -n "$f" && echo "OK: $f" || echo "FAIL: $f"
done
```

Expected: `OK:` for all 4 files.

- [ ] **Step 7: Commit**

```bash
git add packer/scripts/
git commit -m "feat(packer): add provisioner scripts

install-tools.sh: Docker, Compose v2.28.1, k6 v0.56.0, Node.js 20
setup-workspace.sh: /opt/loadtest layout, npm ci
setup-systemd.sh: register loadtest-bootstrap.service
cleanup.sh: clear dnf cache, bash history"
```

---

## Task 8: Create Packer HCL template

**Files:**
- Create: `packer/variables.pkr.hcl`
- Create: `packer/ami.pkr.hcl`

- [ ] **Step 1: Create variables.pkr.hcl**

```bash
cat > packer/variables.pkr.hcl << 'EOF'
variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "ami_name_prefix" {
  type    = string
  default = "maspex-uat-loadtest"
}

variable "aws_profile" {
  type    = string
  default = "maspex-cli"
}

variable "build_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "subnet_id" {
  type        = string
  default     = "subnet-0ceb2411d9d6091de"
  description = "Public subnet in maspex VPC for Packer build instance"
}
EOF
```

- [ ] **Step 2: Create ami.pkr.hcl**

```bash
cat > packer/ami.pkr.hcl << 'EOF'
packer {
  required_plugins {
    amazon = {
      version = ">= 1.3.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

data "amazon-ami" "al2023" {
  profile     = var.aws_profile
  region      = var.region
  owners      = ["amazon"]
  most_recent = true

  filters = {
    name                = "al2023-ami-2023.*-x86_64"
    architecture        = "x86_64"
    root-device-type    = "ebs"
    virtualization-type = "hvm"
  }
}

source "amazon-ebs" "loadtest" {
  profile       = var.aws_profile
  region        = var.region
  source_ami    = data.amazon-ami.al2023.id
  instance_type = var.build_instance_type
  ssh_username  = "ec2-user"
  subnet_id     = var.subnet_id

  ami_name        = "${var.ami_name_prefix}-${formatdate("YYYY-MM-DD-hhmmss", timestamp())}"
  ami_description = "Maspex UAT load test generator — Docker+k6+InfluxDB+Grafana+token-generator"

  associate_public_ip_address = true

  launch_block_device_mappings {
    device_name           = "/dev/xvda"
    volume_size           = 30
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name        = "${var.ami_name_prefix}-${formatdate("YYYY-MM-DD", timestamp())}"
    project     = "maspex"
    environment = "uat"
    managed_by  = "packer"
    built_at    = timestamp()
  }
}

build {
  name    = "maspex-loadtest-ami"
  sources = ["source.amazon-ebs.loadtest"]

  # 1. Install system tools (pinned versions)
  provisioner "shell" {
    script          = "packer/scripts/install-tools.sh"
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
  }

  # 2. Upload workspace
  provisioner "file" {
    source      = "scripts/loadtest/"
    destination = "/tmp/loadtest"
  }

  # 3. Move to /opt/loadtest, npm ci
  provisioner "shell" {
    script          = "packer/scripts/setup-workspace.sh"
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
  }

  # 4. Register + enable systemd unit
  provisioner "shell" {
    script          = "packer/scripts/setup-systemd.sh"
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
  }

  # 5. Clean up
  provisioner "shell" {
    script          = "packer/scripts/cleanup.sh"
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
  }

  post-processor "manifest" {
    output     = "packer/manifest.json"
    strip_path = true
  }
}
EOF
```

- [ ] **Step 3: Commit**

```bash
git add packer/ami.pkr.hcl packer/variables.pkr.hcl
git commit -m "feat(packer): add AMI build template

amazon-ebs source: AL2023 latest, t3.medium, eu-west-1.
Provisioners: install-tools → upload workspace → setup → systemd → cleanup.
Output: manifest.json with AMI ID for Terraform handoff."
```

---

## Task 9: Update Terraform — IAM Secrets Manager policy

**Files:**
- Modify: `terraform/envs/uat/loadtest.tf`

- [ ] **Step 1: Add IAM policy block**

In `terraform/envs/uat/loadtest.tf`, append after the `aws_iam_role_policy_attachment.loadtest_ssm` resource:

```hcl
# ---------------------------------------------------------------------------
# IAM — Secrets Manager access for bootstrap.sh
# ---------------------------------------------------------------------------
resource "aws_iam_role_policy" "loadtest_secrets" {
  name = "${var.project}-${var.environment}-loadtest-secrets-read"
  role = aws_iam_role.loadtest.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = "arn:aws:secretsmanager:${var.region}:969209893152:secret:maspex/uat/api-*"
      }
      # Uncomment if maspex/uat/api uses a CMK (customer-managed KMS key):
      # {
      #   Effect   = "Allow"
      #   Action   = "kms:Decrypt"
      #   Resource = "<CMK_ARN>"
      # }
    ]
  })
}
```

- [ ] **Step 2: Validate**

```bash
cd terraform/envs/uat
terraform validate
cd -
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 3: Commit**

```bash
git add terraform/envs/uat/loadtest.tf
git commit -m "feat(iam): add Secrets Manager read policy to loadtest role

bootstrap.sh fetches JWT_SECRET+JWT_KID from maspex/uat/api at boot.
Resource scoped to maspex/uat/api-* ARN pattern."
```

---

## Task 10: Switch Launch Template to loadtest_ami_id variable

**Files:**
- Modify: `terraform/envs/uat/variables.tf`
- Modify: `terraform/envs/uat/terraform.tfvars`
- Modify: `terraform/envs/uat/loadtest.tf`

- [ ] **Step 1: Add variable to variables.tf**

Append to `terraform/envs/uat/variables.tf`:

```hcl
variable "loadtest_ami_id" {
  description = "AMI ID for load test generators — output of packer build. Update after each packer build."
  type        = string
  default     = ""
}
```

- [ ] **Step 2: Add placeholder to terraform.tfvars**

Append to `terraform/envs/uat/terraform.tfvars`:

```hcl
# Load test generator AMI — set after packer build
# loadtest_ami_id = "ami-xxxx"
```

- [ ] **Step 3: Update loadtest.tf — replace data source with variable, remove unused data source**

In `terraform/envs/uat/loadtest.tf`:

**Remove** the entire `data "aws_ami" "loadtest_al2023"` block (lines 24–38 in current file).

**Change** in the `aws_launch_template.loadtest` resource:
```hcl
  # Before:
  image_id = data.aws_ami.loadtest_al2023.id

  # After:
  image_id = var.loadtest_ami_id
```

Also add a validation guard just before the `aws_launch_template` resource:

```hcl
locals {
  _validate_ami_id = var.loadtest_ami_id != "" ? true : tobool("loadtest_ami_id must be set in terraform.tfvars — run packer build first")
}
```

- [ ] **Step 4: Validate**

```bash
cd terraform/envs/uat
# Temporarily set a fake AMI ID to pass validation
TF_VAR_loadtest_ami_id="ami-00000000000000000" terraform validate
cd -
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 5: Commit**

```bash
git add terraform/envs/uat/variables.tf terraform/envs/uat/terraform.tfvars terraform/envs/uat/loadtest.tf
git commit -m "feat(terraform): switch loadtest LT to explicit loadtest_ami_id variable

Removes dynamic data.aws_ami lookup (was always latest AL2023).
AMI ID is now a required tfvar — set explicitly after each packer build.
Ensures ASG always uses the exact tested image."
```

---

## Task 11: Add JWT_KID to Secrets Manager

**Files:** none (AWS runtime change)

- [ ] **Step 1: Read current secret value**

```bash
aws secretsmanager get-secret-value \
  --secret-id maspex/uat/api \
  --query SecretString \
  --output text \
  --profile maspex-cli \
  --region eu-west-1
```

Note the current JSON. **Do not run this in a shared terminal session.**

- [ ] **Step 2: Update secret to add JWT_KID**

Take the JSON from Step 1 and add `"JWT_KID": "<value from generate-tokens-fn.js>"`. Then:

```bash
aws secretsmanager update-secret \
  --secret-id maspex/uat/api \
  --secret-string '{ <existing-fields>, "JWT_KID": "<value>" }' \
  --profile maspex-cli \
  --region eu-west-1
```

The `JWT_KID` value is the one that was hardcoded in `testy-qa/generate-tokens-fn.js` (line 10 of the original file).

- [ ] **Step 3: Verify the new field is present**

```bash
aws secretsmanager get-secret-value \
  --secret-id maspex/uat/api \
  --query SecretString \
  --output text \
  --profile maspex-cli \
  --region eu-west-1 \
  | jq 'has("JWT_KID")'
```

Expected: `true`

---

## Task 12: packer init + validate

**Files:** none (validation only)

- [ ] **Step 1: packer init — download amazon plugin**

```bash
cd packer
packer init .
cd -
```

Expected: downloads `github.com/hashicorp/amazon` plugin, no errors.

- [ ] **Step 2: packer validate**

```bash
cd packer
AWS_PROFILE=maspex-cli packer validate .
cd -
```

Expected:
```
The configuration is valid.
```

If there are errors, fix them before proceeding to build.

---

## Task 13: packer build — produce AMI

**Files:** `packer/manifest.json` (generated output)

**Note:** This step takes ~15–25 minutes. The build launches a `t3.medium` in eu-west-1 (account 969209893152). Cost: ~$0.05.

- [ ] **Step 1: Run build**

```bash
cd packer
AWS_PROFILE=maspex-cli packer build .
```

Expected final output:
```
==> Builds finished. The artifacts of successful builds are:
--> maspex-loadtest-ami.amazon-ebs.loadtest: AMIs were created:
eu-west-1: ami-xxxxxxxxxxxx
```

- [ ] **Step 2: Note AMI ID from manifest**

```bash
jq -r '.builds[-1].artifact_id' packer/manifest.json | cut -d: -f2
```

Copy this AMI ID — needed for Task 14.

- [ ] **Step 3: Commit manifest**

```bash
git add packer/manifest.json
git commit -m "chore(packer): record AMI build manifest $(date +%Y-%m-%d)

$(jq -r '.builds[-1].artifact_id' packer/manifest.json)"
```

---

## Task 14: terraform plan + apply (IAM + Launch Template)

**Files:** none (AWS state change)

- [ ] **Step 1: Set AMI ID in tfvars**

Edit `terraform/envs/uat/terraform.tfvars` — uncomment and fill in the AMI ID from Task 13:

```hcl
loadtest_ami_id = "ami-xxxxxxxxxxxx"
```

- [ ] **Step 2: terraform plan**

```bash
cd terraform/envs/uat
terraform init -backend-config=backend.hcl
terraform plan -out=loadtest-ami.tfplan
```

Review the plan. Expected changes:
1. **aws_iam_role_policy.loadtest_secrets** — CREATE (new Secrets Manager policy)
2. **aws_launch_template.loadtest** — UPDATE (new `image_id`, new LT version)
3. **data.aws_ami.loadtest_al2023** — DESTROY (removed data source, no real AWS resource)

No other resources should be in the plan. If ECS or other resources appear, stop and investigate.

- [ ] **Step 3: Apply**

```bash
terraform apply loadtest-ami.tfplan
```

Expected: `Apply complete! Resources: 2 added, 1 changed, 0 destroyed.`

- [ ] **Step 4: Verify new Launch Template version**

```bash
aws ec2 describe-launch-template-versions \
  --launch-template-name "maspex-uat-loadtest-$(terraform output -raw launch_template_id 2>/dev/null || echo '<id>')" \
  --profile maspex-cli --region eu-west-1 \
  --query 'LaunchTemplateVersions[-1].{Version:VersionNumber,ImageId:LaunchTemplateData.ImageId}' \
  --output table
```

Expected: version number incremented, ImageId = the AMI from Task 13.

- [ ] **Step 5: Commit tfvars with AMI ID**

```bash
cd -
git add terraform/envs/uat/terraform.tfvars
git commit -m "chore(terraform): set loadtest_ami_id to $(grep loadtest_ami_id terraform/envs/uat/terraform.tfvars | awk '{print $3}' | tr -d '"')

First Packer-built load test AMI deployed to Launch Template."
```

---

## Task 15: Fleet rollout + validation

**Files:** none (operational)

**Prerequisites:** IAM policy applied (Task 14), AMI in Launch Template (Task 14), JWT_KID in SM (Task 11).

- [ ] **Step 1: Stop current fleet**

```bash
./scripts/loadtest-ctrl.sh --stop
```

Expected: WAF cleared, ASG desired → 0, instances terminated.

- [ ] **Step 2: Start fleet with new AMI**

```bash
./scripts/loadtest-ctrl.sh --run
```

Expected: ASG starts new instances (from new AMI), waits for InService.

- [ ] **Step 3: SSH into one instance and check bootstrap**

```bash
./scripts/loadtest-ctrl.sh --ssh
# Once connected:
```

```bash
# On the generator instance:
sudo systemctl status loadtest-bootstrap
```

Expected: `Active: active (exited)` — oneshot service completed successfully.

- [ ] **Step 4: Check bootstrap status file**

```bash
# On the generator instance:
cat /opt/loadtest/runtime/bootstrap.status
```

Expected: `READY 2026-05-14T10:xx:xxZ`

- [ ] **Step 5: Check tokens were generated**

```bash
# On the generator instance:
jq 'length' /opt/loadtest/runtime/tokens.json
```

Expected: `5000`

- [ ] **Step 6: Check Docker stack is running**

```bash
# On the generator instance:
cd /opt/loadtest && docker compose ps
```

Expected:
```
NAME                 SERVICE    STATUS    PORTS
loadtest-influxdb-1  influxdb   running   0.0.0.0:8086->8086/tcp
loadtest-grafana-1   grafana    running   0.0.0.0:3000->3000/tcp
```

- [ ] **Step 7: Check InfluxDB has k6 database**

```bash
# On the generator instance:
docker exec $(docker compose ps -q influxdb) influx -execute "SHOW DATABASES"
```

Expected: output includes `k6`.

- [ ] **Step 8: Check bootstrap log for errors**

```bash
# On the generator instance:
sudo journalctl -u loadtest-bootstrap --no-pager | tail -20
```

Expected: no ERROR lines, final line contains `loadtest bootstrap READY`.

- [ ] **Step 9: Run a quick k6 smoke test**

```bash
# On the generator instance:
K6_OUT=influxdb=http://localhost:8086/k6 \
  k6 run --vus 1 --duration 10s /opt/loadtest/k6/kapsel-main-page.js
```

Expected: k6 completes, metrics appear in Grafana dashboard (verify via SSH tunnel: `ssh -L 3000:localhost:3000 ec2-user@<IP>` then open http://localhost:3000).

---

## Self-Review

**Spec coverage check:**

| Spec requirement | Task |
|-----------------|------|
| Install Packer | Task 1 |
| Fix generate-tokens-fn.js hardcoded secrets | Task 2 |
| k6 scripts in repo | Task 3 |
| Pin Grafana version | Task 4 |
| bootstrap.sh (secrets → tokens → compose → health check) | Task 5 |
| systemd unit | Task 6 |
| Packer provisioner scripts (install, workspace, systemd, cleanup) | Task 7 |
| Packer HCL template | Task 8 |
| IAM Secrets Manager policy | Task 9 |
| AMI ID as Terraform variable (not data source) | Task 10 |
| JWT_KID in Secrets Manager | Task 11 |
| packer init + validate | Task 12 |
| packer build | Task 13 |
| terraform plan + apply | Task 14 |
| Fleet rollout + validation | Task 15 |
| InfluxDB 1.8 (datasource baked-in) | Task 4 (compose) — no change needed, already 1.8 |
| S3 test results archiving | Not in scope of this plan — deferred |
| data.aws_ami removed | Task 10 |

**Placeholder scan:** no TBD, TODO, or "similar to Task N" entries. All code blocks are complete. ✓

**Type consistency:** `docker compose ps -q influxdb` used consistently in Task 5 and Task 15. `generateTokens` function signature matches CLI call (count, startIndex, outputFile). ✓
