---
date: 2026-04-26
project: planodkupow
client: mako
account: "333320664022"
region: eu-central-1
profile: plan
tags: [planodkupow, finops, remediation, runbook, ecs, mq, cloudwatch, vpc, tagging]
domain: client-work/mako
status: DRAFT — pending team review before execution
evidence-sources:
  - planodkupow-ce-audit-2026-04-26.md
  - planodkupow-runtime-verification-2026-04-26.md
  - planodkupow-finops-governance-audit-2026-04-25.md
---

# PlanOdkupow — FinOps Remediation Runbook

**Account:** 333320664022 | **Region:** eu-central-1 | **Profile:** `plan`  
**Target window for P0+P1:** Any business hours, no outage risk  
**Target window for P2:** Scheduled deploy window (CFN change set)  
**Target window for P3:** Requires 7-day metric gate + explicit business sign-off

---

## 1. Executive Change Plan

### What we're fixing and why

Three distinct problem categories, each with a different fix path:

| # | Problem | Current cost | Fix path | Risk |
|---|---------|-------------|---------|------|
| A | CloudWatch log groups NEVER_EXPIRES — 164 GB accumulated | ~$97/mo and growing | `logs put-retention-policy` — pure API, no resource change | **Medium** — workload safe, but eventually deletes old log events; requires compliance approval |
| B | ECS `PropagateTags=NONE` on 26/28 services — task ENIs untagged | $267/mo misattributed | CFN template change set on existing stacks | Low |
| C | MQ orphan broker zero tags | $21/mo unattributed | `mq create-tags` — pure metadata | **Zero** |
| D | Unassociated EIP 3.77.136.162 | $3.60/mo pure waste | `ec2 release-address` — irreversible | Low-medium |
| E | All other tagging gaps (ECR, WAF, CloudTrail, GA) | CE attribution only | `tag-resource` variants | **Zero** |
| F | Old QA VPC orphan stack (NAT, 4 endpoints, GA, EIP) | ~$50-75/mo | Ordered teardown sequence | **High — needs gate** |

### What this runbook does NOT fix

- The $262/month permanent baseline increase from April 19 rebuild (different task sizes, more services) — that requires an architectural review, not a tagging fix
- CloudTrail data ingestion cost ($81/mo) — it's 100% untagged but it's structural account-level spend, not a waste item
- Tax ($211) — not taggable
- The underlying MQ instance type mismatch (QA mq.m7g.medium vs UAT mq.t3.micro) — requires broker maintenance window

### Expected outcomes

| After phase | CE "no Environment" bucket | Monthly savings |
|------------|--------------------------|----------------|
| P0 (no changes) | $819.03 | $0 |
| P1 complete | ~$787 (MQ tagged, minor shift) | ~$3.60 (EIP) |
| P2 complete | ~$550 (ECS attributed) | ~$0 (attribution fix, not cost reduction) |
| P3 complete | ~$450 (VPC orphans gone) | **~$65-85/mo real savings** |
| Log retention fix in P1 | CW drops from $126/mo → ~$15/mo after decay | **~$111/mo savings after 30-day decay** |

**Total recoverable over 90 days: ~$175-200/month**

---

## 2. Risk Matrix

| Action | Risk level | Reversible? | CFN drift risk? | Requires change window? |
|--------|-----------|------------|----------------|------------------------|
| Export evidence (P0) | **Zero** | N/A | No | No |
| `logs put-retention-policy` | Runtime: **Zero** / Compliance: **Medium** | Yes, before log expiry (see P1.1 rollback) | No | No — but requires compliance gate (see P1.1) |
| `mq create-tags` | **Zero** | Yes (delete tags) | No | No |
| `cloudtrail add-tags` | **Zero** | Yes | No | No |
| `globalaccelerator tag-resource` | **Zero** | Yes | No | No |
| `wafv2 tag-resource` | **Zero** | Yes | No | No |
| `ecr tag-resource` | **Zero** | Yes | No | No |
| `ec2 create-tags` (EIPs) | **Zero** | Yes | No | No |
| Delete chaos-day MQ log groups | **Low** | No — logs gone | No | No (orphan broker deleted) |
| `ec2 release-address` (unassoc. EIP) | **Low-medium** | No — IP released to pool | No | No |
| CFN change set: ECS PropagateTags | **Low** | Yes (revert template) | N/A — is the CFN route | Yes (notify team) |
| `ecs update-service --propagate-tags` (fallback) | **Medium** | Yes, but creates CFN drift | **YES** | Yes (notify team) |
| Delete old QA VPC endpoints | **Medium** | No | Unknown | Yes |
| Delete NAT GW + EIP | **Medium** | No | Unknown | Yes |
| Delete Global Accelerator | **High** | No — anycast IPs lost | Unknown | Yes + business approval |
| Delete old QA VPC | **High** | No | Unknown | Yes + business approval |

---

## 3. Command Runbook

### Environment

```bash
export AWS_PROFILE=plan
export AWS_REGION=eu-central-1
export ACCOUNT_ID=333320664022
export SNAPSHOT_DIR="/tmp/planodkupow-snapshot-$(date +%Y-%m-%d)"
mkdir -p "$SNAPSHOT_DIR"
```

---

## Phase P0 — Evidence Snapshots (mandatory, read-only)

**Gate:** All snapshots must complete without error before ANY change in P1.  
**Purpose:** Establish a timestamped baseline. If anything goes wrong in P1/P2, these are the reference.  
**Time estimate:** 10-15 minutes.

### P0.1 — ECS Services + PropagateTags

```bash
# Full service inventory across all clusters
for CLUSTER_ARN in $(aws ecs list-clusters --output text --query 'clusterArns[*]'); do
  CLUSTER_NAME=$(basename "$CLUSTER_ARN")
  echo "=== Cluster: $CLUSTER_NAME ===" >> "$SNAPSHOT_DIR/ecs-services.json"
  
  SERVICE_ARNS=$(aws ecs list-services \
    --cluster "$CLUSTER_ARN" \
    --output text --query 'serviceArns[*]')
  
  if [ -n "$SERVICE_ARNS" ]; then
    aws ecs describe-services \
      --cluster "$CLUSTER_ARN" \
      --services $SERVICE_ARNS \
      --query 'services[*].{Name:serviceName,PropagateTags:propagateTags,TaskDef:taskDefinition,Status:status,DesiredCount:desiredCount,StackId:tags[?key==`aws:cloudformation:stack-id`].value|[0]}' \
      --output json >> "$SNAPSHOT_DIR/ecs-services.json"
  fi
done

# Quick PropagateTags summary
jq -r '.[] | "\(.Name) | \(.PropagateTags) | CFN: \(.StackId // "NONE")"' \
  "$SNAPSHOT_DIR/ecs-services.json" 2>/dev/null || \
  echo "Parse warning — check raw file for structure"

echo "ECS snapshot: $SNAPSHOT_DIR/ecs-services.json"
```

**Expected output:** 28 services, 26 with PropagateTags=NONE, 2 with SERVICE. Each entry shows CFN stack ownership.

**Gate check:** If any service shows PropagateTags=SERVICE that wasn't already known (only Gateway-SRVC QA+UAT should), investigate before P2.

### P0.2 — Amazon MQ Brokers + Tags

```bash
# All broker summaries
aws mq list-brokers \
  --output json > "$SNAPSHOT_DIR/mq-brokers.json"

# Detailed describe for each broker
jq -r '.BrokerSummaries[].BrokerId' "$SNAPSHOT_DIR/mq-brokers.json" | while read BID; do
  echo "=== Broker: $BID ===" >> "$SNAPSHOT_DIR/mq-brokers-detail.json"
  aws mq describe-broker --broker-id "$BID" \
    --query '{Name:BrokerName,Id:BrokerId,Arn:BrokerArn,Type:BrokerInstanceType,
              State:BrokerState,Created:Created,Tags:Tags,SubnetIds:SubnetIds,
              DeploymentMode:DeploymentMode}' \
    --output json >> "$SNAPSHOT_DIR/mq-brokers-detail.json"
done

echo "MQ snapshot: $SNAPSHOT_DIR/mq-brokers-detail.json"

# Print tag summary
jq '{Name,Id,Type,Tags}' "$SNAPSHOT_DIR/mq-brokers-detail.json" 2>/dev/null || \
  cat "$SNAPSHOT_DIR/mq-brokers-detail.json"
```

**Expected output:** 2 active brokers. `b-f231815d` with Tags={}, `b-2d26b881` with old-schema tags.

### P0.3 — CloudWatch Log Groups: retention + stored bytes

```bash
# All log groups — paginate fully
aws logs describe-log-groups \
  --output json > "$SNAPSHOT_DIR/cw-log-groups-p1.json"

TOKEN=$(jq -r '.nextToken // empty' "$SNAPSHOT_DIR/cw-log-groups-p1.json")
PAGE=2
while [ -n "$TOKEN" ]; do
  aws logs describe-log-groups \
    --next-token "$TOKEN" \
    --output json > "$SNAPSHOT_DIR/cw-log-groups-p${PAGE}.json"
  TOKEN=$(jq -r '.nextToken // empty' "$SNAPSHOT_DIR/cw-log-groups-p${PAGE}.json")
  PAGE=$((PAGE+1))
done

# Merge and analyze NEVER_EXPIRES groups
cat "$SNAPSHOT_DIR"/cw-log-groups-p*.json | \
  jq -s '[.[].logGroups[]] | 
    map({name: .logGroupName, retentionDays: .retentionInDays, 
         storedGB: (.storedBytes/1073741824 | . * 100 | round / 100),
         createdMs: .creationTime}) |
    sort_by(-.storedGB)' \
  > "$SNAPSHOT_DIR/cw-log-groups-merged.json"

echo "Total log groups: $(jq length $SNAPSHOT_DIR/cw-log-groups-merged.json)"
echo ""
echo "=== NEVER_EXPIRES groups (retentionDays=null): ==="
jq '.[] | select(.retentionDays == null) | "\(.name) | \(.storedGB) GB"' \
  "$SNAPSHOT_DIR/cw-log-groups-merged.json" -r

echo ""
echo "=== Top 10 by stored bytes: ==="
jq -r '.[:10][] | "\(.storedGB) GB | \(.retentionDays // "NEVER_EXPIRES") days | \(.name)"' \
  "$SNAPSHOT_DIR/cw-log-groups-merged.json"
```

**Expected output:** ~60+ log groups. NEVER_EXPIRES list should show `b-2d26b881` connection (134.96 GB) and channel (29.29 GB) at the top.

### P0.4 — NAT Gateway + CloudWatch traffic metrics (7-day)

```bash
# Get NAT GW inventory
aws ec2 describe-nat-gateways \
  --filter Name=state,Values=available \
  --query 'NatGateways[*].{Id:NatGatewayId,VPC:VpcId,State:State,
           Subnet:SubnetId,AllocationId:NatGatewayAddresses[0].AllocationId,
           PublicIP:NatGatewayAddresses[0].PublicIp}' \
  --output json > "$SNAPSHOT_DIR/nat-gateways.json"

jq . "$SNAPSHOT_DIR/nat-gateways.json"

# 7-day traffic metrics for orphan NAT (nat-08adf3e0a226779a7)
NAT_ID="nat-08adf3e0a226779a7"
echo "=== BytesOutToDestination for $NAT_ID (last 7 days) ===" \
  > "$SNAPSHOT_DIR/nat-metrics.json"

aws cloudwatch get-metric-statistics \
  --namespace AWS/NatGateway \
  --metric-name BytesOutToDestination \
  --dimensions Name=NatGatewayId,Value="$NAT_ID" \
  --start-time "$(date -u -v-7d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u --date='7 days ago' +%Y-%m-%dT%H:%M:%SZ)" \
  --end-time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --period 86400 \
  --statistics Sum \
  --query 'sort_by(Datapoints, &Timestamp)[*].{Date:Timestamp,Bytes:Sum}' \
  --output json >> "$SNAPSHOT_DIR/nat-metrics.json"

jq . "$SNAPSHOT_DIR/nat-metrics.json"
```

**Interpretation:** If `BytesOutToDestination` sum is 0 or near-0 for all 7 days → NAT is idle → eligible for P3 decommission. If non-zero → investigate source before any deletion.

### P0.5 — Global Accelerator inventory + traffic metrics

```bash
# GA requires us-east-1
aws globalaccelerator list-accelerators \
  --region us-east-1 \
  --output json > "$SNAPSHOT_DIR/ga-accelerators.json"

jq '.Accelerators[] | {Name, Arn, Status, IpAddresses: .IpSets[0].IpAddresses}' \
  "$SNAPSHOT_DIR/ga-accelerators.json"

# Get listeners for each accelerator
GA_ARN=$(jq -r '.Accelerators[0].AcceleratorArn' "$SNAPSHOT_DIR/ga-accelerators.json")
if [ -n "$GA_ARN" ] && [ "$GA_ARN" != "null" ]; then
  aws globalaccelerator list-listeners \
    --accelerator-arn "$GA_ARN" \
    --region us-east-1 \
    --output json > "$SNAPSHOT_DIR/ga-listeners.json"
  
  LISTENER_ARN=$(jq -r '.Listeners[0].ListenerArn' "$SNAPSHOT_DIR/ga-listeners.json")
  if [ -n "$LISTENER_ARN" ] && [ "$LISTENER_ARN" != "null" ]; then
    aws globalaccelerator list-endpoint-groups \
      --listener-arn "$LISTENER_ARN" \
      --region us-east-1 \
      --output json > "$SNAPSHOT_DIR/ga-endpoint-groups.json"
    
    jq '.EndpointGroups[].EndpointDescriptions[] | 
        {EndpointId, HealthState, HealthReason, Weight}' \
      "$SNAPSHOT_DIR/ga-endpoint-groups.json"
  fi

  # GA traffic metrics — ProcessedByteCount
  GA_ID=$(basename "$GA_ARN")
  aws cloudwatch get-metric-statistics \
    --namespace AWS/GlobalAccelerator \
    --metric-name ProcessedByteCount \
    --dimensions Name=Accelerator,Value="$GA_ID" \
    --start-time "$(date -u -v-7d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u --date='7 days ago' +%Y-%m-%dT%H:%M:%SZ)" \
    --end-time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --period 86400 \
    --statistics Sum \
    --region us-east-1 \
    --query 'sort_by(Datapoints, &Timestamp)[*].{Date:Timestamp,Bytes:Sum}' \
    --output json > "$SNAPSHOT_DIR/ga-traffic.json"
  
  jq . "$SNAPSHOT_DIR/ga-traffic.json"
fi
```

**Interpretation:** `ProcessedByteCount = 0` across all days → GA is not carrying real traffic. This is the prerequisite for P3 decommission.

### P0.6 — VPC Endpoints inventory

```bash
aws ec2 describe-vpc-endpoints \
  --filter Name=vpc-endpoint-state,Values=available \
  --query 'VpcEndpoints[*].{Id:VpcEndpointId,VpcId:VpcId,Service:ServiceName,
           State:State,Tags:Tags}' \
  --output json > "$SNAPSHOT_DIR/vpc-endpoints.json"

jq -r '.[] | "\(.Id) | \(.VpcId) | \(.Service | split(".")[-1]) | tags: \(.Tags | length)"' \
  "$SNAPSHOT_DIR/vpc-endpoints.json"
```

**Expected:** 6 endpoints. 4 in vpc-02f804baee8a3f048 (old QA VPC, orphan), 2 AMQ PrivateLink in new VPCs.

### P0.7 — WAF WebACL inventory + associations

```bash
# Regional WAF
aws wafv2 list-web-acls \
  --scope REGIONAL \
  --output json > "$SNAPSHOT_DIR/waf-regional.json"

# Global WAF (for CloudFront)
aws wafv2 list-web-acls \
  --scope CLOUDFRONT \
  --region us-east-1 \
  --output json > "$SNAPSHOT_DIR/waf-global.json"

jq '{Regional: (.WebACLs // []), Global: "see waf-global.json"}' \
  "$SNAPSHOT_DIR/waf-regional.json"

jq '.WebACLs[] | {Name, Id, ARN}' "$SNAPSHOT_DIR/waf-global.json"

# For global WAF ARN — check CloudFront distribution
aws cloudfront list-distributions \
  --query 'DistributionList.Items[*].{Id:Id,Domain:DomainName,WebACLId:WebACLId}' \
  --output json > "$SNAPSHOT_DIR/cloudfront-distributions.json"

jq '.[] | select(.WebACLId != null and .WebACLId != "")' \
  "$SNAPSHOT_DIR/cloudfront-distributions.json"
```

### P0.8 — EIP inventory

```bash
aws ec2 describe-addresses \
  --query 'Addresses[*].{AllocationId:AllocationId,PublicIp:PublicIp,
           AssociationId:AssociationId,InstanceId:InstanceId,
           NetworkInterfaceId:NetworkInterfaceId,
           Tags:Tags}' \
  --output json > "$SNAPSHOT_DIR/eips.json"

jq -r '.[] | "\(.PublicIp) | alloc: \(.AllocationId) | assoc: \(.AssociationId // "UNASSOCIATED") | tags: \(.Tags | length)"' \
  "$SNAPSHOT_DIR/eips.json"
```

**Expected:** 6 EIPs, all tags=0. One UNASSOCIATED (3.77.136.162, eipalloc-02f3a2a04522cff83).

### P0.9 — ECR repositories + tags

```bash
aws ecr describe-repositories \
  --query 'repositories[*].{Name:repositoryName,Arn:repositoryArn,Created:createdAt}' \
  --output json > "$SNAPSHOT_DIR/ecr-repos.json"

jq -r '.[].Name' "$SNAPSHOT_DIR/ecr-repos.json" | while read REPO; do
  REPO_ARN=$(jq -r --arg r "$REPO" '.[] | select(.Name==$r) | .Arn' "$SNAPSHOT_DIR/ecr-repos.json")
  TAGS=$(aws ecr list-tags-for-resource --resource-arn "$REPO_ARN" --output json)
  echo "$REPO: $TAGS" >> "$SNAPSHOT_DIR/ecr-tags.json"
done

cat "$SNAPSHOT_DIR/ecr-tags.json"
```

### P0.10 — CloudTrail trails + tags

```bash
aws cloudtrail describe-trails \
  --output json > "$SNAPSHOT_DIR/cloudtrail-trails.json"

jq -r '.trailList[].TrailARN' "$SNAPSHOT_DIR/cloudtrail-trails.json" | while read TRAIL_ARN; do
  TAGS=$(aws cloudtrail list-tags --resource-id-list "$TRAIL_ARN" --output json)
  echo "=== $TRAIL_ARN ===" >> "$SNAPSHOT_DIR/cloudtrail-tags.json"
  echo "$TAGS" >> "$SNAPSHOT_DIR/cloudtrail-tags.json"
done

cat "$SNAPSHOT_DIR/cloudtrail-tags.json"
```

### P0 — GO/NO-GO Gate

```
CHECKLIST — complete before proceeding to P1:

[ ] $SNAPSHOT_DIR exists and contains all 10 snapshot files
[ ] ecs-services.json: 28 services visible, CFN stack-id field populated or "NONE"
[ ] mq-brokers-detail.json: 2 brokers visible, b-f231815d Tags={}
[ ] cw-log-groups-merged.json: b-2d26b881 connection group visible at top (>130 GB)
[ ] nat-metrics.json: BytesOutToDestination visible (values may be 0 or non-0)
[ ] ga-accelerators.json: accelerator ARN captured
[ ] vpc-endpoints.json: 6 endpoints captured
[ ] eips.json: 6 EIPs, eipalloc-02f3a2a04522cff83 shows no AssociationId
[ ] ecr-tags.json: 3 repos captured
[ ] cloudtrail-tags.json: trail ARN captured

DO NOT PROCEED if any snapshot failed.
```

---

## Phase P1 — Zero-Risk Remediations

**Gate condition:** P0 complete, all snapshots green.  
**Risk:** Low. Most actions are reversible. Exception: EIP release (irreversible), log deletion (irreversible), log expiry after retention window closes (irreversible).  
**Estimated time:** 20-30 minutes.  
**No change window required.** Inform team before EIP release and before applying log retention.

---

### P1.1 — CloudWatch Log Retention: MQ broker logs

**Why:** UAT broker log groups carry 164 GB with NEVER_EXPIRES. AWS charges $0.03/GB/month for CloudWatch storage. After setting a retention policy, log events older than the retention window auto-expire gradually. No data is deleted immediately — expiry begins only after the retention window elapses from each event's creation time.

**Risk classification:**
```
Runtime risk:                    zero — setting retention does not interrupt workloads
Data-retention/compliance risk:  MEDIUM unless approved — log events will eventually be deleted
Cost impact:                     HIGH — ~$111/month reduction after decay
Reversible before log expiry:    YES — delete the retention policy to restore NEVER_EXPIRES
Reversible after log expiry:     NO — expired log events are permanently gone
```

**Expected impact:** ~$111/month reduction after decay (30-day retention) or ~$58/month (90-day retention).

**Important — cost reduction timeline:**
Setting retention does NOT reduce the CloudWatch bill immediately.
- Log events expire gradually as they age past the retention window
- Stored bytes decrease only as old events are purged by AWS (daily background process)
- Cost reduction appears over 30–90 days depending on retention chosen
- The first billing cycle after applying retention will show little or no reduction
- Full savings are only visible once the oldest cohort of events has aged out

**Rollback — correct command to restore NEVER_EXPIRES:**
```bash
# CORRECT: removes the retention policy entirely, restoring NEVER_EXPIRES behaviour
aws logs delete-retention-policy \
  --log-group-name "<log-group-name>"

# WRONG — do NOT use retention-in-days 0; this is not a valid value:
# aws logs put-retention-policy --log-group-name "<name>" --retention-in-days 0
```

**CFN drift risk:** None for this operation. CloudWatch log group retention is managed via `RetentionInDays` in CFN, but setting it via API does not constitute drift unless the template explicitly sets a different value. MQ-managed log groups are not in any CFN stack.

**Retention drift on recreation — known failure mode:** Amazon MQ creates its log groups automatically when a broker is provisioned. CloudWatch Synthetics creates Lambda log groups when a canary runs. In both cases, AWS sets no retention policy by default — any recreated log groups will return to NEVER_EXPIRES. This means:
- If a broker is deleted and recreated (as happened on April 19), the new log groups start with NEVER_EXPIRES
- If a canary is redeployed, the new Lambda log group has no retention
- This runbook's fix is a one-time remediation, not a persistent control

**Recommended follow-up:** Codify retention in IaC. For CFN-managed log groups, add `RetentionInDays` to `AWS::Logs::LogGroup` resources. For MQ broker log groups (AWS-managed, not in CFN), add a Lambda or EventBridge rule that applies retention on `CreateLogGroup` events — otherwise retention drift will recur after any rebuild.

---

#### P1.1 — GO/NO-GO Gate (mandatory before applying retention)

```
GO only if ALL of the following are confirmed:

[ ] Application/team owner confirms MQ logs older than 30 days (or 90 days)
    are not required for operational or debugging purposes
[ ] No contractual, audit, or regulatory requirement mandates longer retention
    (e.g., GDPR data processing records, PCI-DSS audit logs, ISO 27001 retention policy)
[ ] P0.3 log group inventory snapshot is complete and storedBytes values are recorded
[ ] The exact list of target log groups has been printed and reviewed before apply
    (see pre-check below — run it, read the output, then decide)

If any item is NOT confirmed → defer this action and document the reason.
Do NOT apply retention speculatively.
```

---

**Pre-check — print list before touching anything:**
```bash
# Show all MQ log groups with current retention and size
jq -r '.[] | select(.name | contains("amazonmq")) | "\(.storedGB) GB | \(.retentionDays // "NEVER_EXPIRES") days | \(.name)"' \
  "$SNAPSHOT_DIR/cw-log-groups-merged.json"
```

---

**Retention mode and dry-run flag — set both before running any stage:**

```bash
# Default conservative mode (recommended for first run):
# 90 days — meaningful cost reduction with lower compliance risk
RETENTION_DAYS=90

# Aggressive cost mode (use only after explicit team approval):
# 30 days — maximum savings, higher risk of losing recent-ish logs
# RETENTION_DAYS=30

# Dry-run mode: set to true to print commands without executing them.
# Always run with DRY_RUN=true first, review output, then set to false.
DRY_RUN=true
```

```bash
# Helper function — used by all three stages below
apply_retention() {
  local LG="$1"
  if [ "$DRY_RUN" = true ]; then
    echo "[DRY-RUN] aws logs put-retention-policy --log-group-name \"$LG\" --retention-in-days $RETENTION_DAYS"
  else
    aws logs put-retention-policy \
      --log-group-name "$LG" \
      --retention-in-days "$RETENTION_DAYS"
    echo "Applied: $LG"
  fi
}
```

---

**Action — Stage 1: apply retention to UAT broker log groups (highest cost, 134 + 29 GB):**

Stage 1 is scoped to the specific UAT broker ID — no scope expansion risk.

```bash
UAT_BROKER_ID="b-2d26b881-79f2-4c3c-8b77-06c1a0fb0b29"

# Derive target list from P0 snapshot (locked at snapshot time, not live re-query)
STAGE1_GROUPS=$(jq -r \
  --arg bid "$UAT_BROKER_ID" \
  '.[] | select(.name | contains($bid)) | select(.retentionDays == null) | .name' \
  "$SNAPSHOT_DIR/cw-log-groups-merged.json")

echo "=== Stage 1 targets (UAT broker $UAT_BROKER_ID) ==="
echo "$STAGE1_GROUPS"
echo "=== Retention: ${RETENTION_DAYS}d | DRY_RUN: ${DRY_RUN} ==="

for LG in $STAGE1_GROUPS; do
  apply_retention "$LG"
done
```

**Action — Stage 2: apply to chaos-day orphan MQ log groups (explicit list from snapshot only):**

> **Scope safety:** Stage 2 does NOT use a live `/aws/amazonmq/` prefix scan. A live prefix scan would match the active QA broker (b-f231815d), any future brokers, and any new log groups created between snapshot and execution time. Instead, the target set is locked to the specific broker IDs confirmed as deleted in P1.3 pre-checks.

```bash
# Explicit list of confirmed-deleted chaos-day broker IDs (from April 19 investigation)
# Do NOT expand this list without re-running P0 and confirming broker deletion
CHAOS_BROKER_IDS=(
  "b-5cb3fcb4"
  "b-b70793a7"
  "b-9df801b4"
)

# Build target list from P0 snapshot — only groups matching confirmed-deleted broker IDs
STAGE2_GROUPS=$(jq -r \
  '.[] | select(.retentionDays == null) | .name' \
  "$SNAPSHOT_DIR/cw-log-groups-merged.json" | \
  grep -E "$(IFS='|'; echo "${CHAOS_BROKER_IDS[*]}")")

echo "=== Stage 2 targets (chaos-day orphan brokers) ==="
echo "$STAGE2_GROUPS"
echo "=== Retention: ${RETENTION_DAYS}d | DRY_RUN: ${DRY_RUN} ==="

if [ -z "$STAGE2_GROUPS" ]; then
  echo "No matching log groups found — nothing to do."
else
  for LG in $STAGE2_GROUPS; do
    apply_retention "$LG"
  done
fi
```

**Action — Stage 3: apply to CloudWatch Synthetics (cwsyn) canary log groups:**

Stage 3 uses the `cwsyn-bbmt-` prefix, which is specific to the known canary naming pattern for this account. If other cwsyn canaries exist outside this prefix, they are not touched.

```bash
# Build target list from P0 snapshot — only cwsyn groups with no retention
STAGE3_GROUPS=$(jq -r \
  '.[] | select((.name | startswith("/aws/lambda/cwsyn-bbmt-")) and .retentionDays == null) | .name' \
  "$SNAPSHOT_DIR/cw-log-groups-merged.json")

echo "=== Stage 3 targets (cwsyn-bbmt canary log groups) ==="
echo "$STAGE3_GROUPS"
echo "=== Retention: ${RETENTION_DAYS}d | DRY_RUN: ${DRY_RUN} ==="

if [ -z "$STAGE3_GROUPS" ]; then
  echo "No matching canary log groups found — nothing to do."
else
  for LG in $STAGE3_GROUPS; do
    apply_retention "$LG"
  done
fi
```

**Post-check — verify retention applied and inspect sizes:**
```bash
# Verify no MQ log groups remain with NEVER_EXPIRES
aws logs describe-log-groups \
  --log-group-name-prefix "/aws/amazonmq/" \
  --query 'logGroups[?retentionInDays==`null`].logGroupName' \
  --output text
# Expected: empty output

# Full inventory with retention and stored bytes — confirm state matches intent
aws logs describe-log-groups \
  --log-group-name-prefix "/aws/amazonmq/" \
  --query 'logGroups[*].{Name:logGroupName,Retention:retentionInDays,StoredBytes:storedBytes}' \
  --output table
```

---

### P1.2 — Tag QA MQ Orphan Broker

**Why:** Broker `planodkupow-qa-rabbitmq-cheap` (b-f231815d) was created 2026-04-21 outside CloudFormation during the chaos-day rebuild. It has zero tags. It costs ~$21/month unattributed in CE.

**Challenge on tag value `ManagedBy=cloudformation`:** The user request specified this tag value, but it is **incorrect** for this resource. The broker was created manually/by a script outside CFN — there is no CFN resource tracking it. Setting `ManagedBy=cloudformation` would create a false governance record. **Use `ManagedBy=manual` instead.** If the intent is to eventually adopt it into CFN, set `ManagedBy=manual-pending-cfn-adoption`.

**Expected impact:** CE will begin attributing this broker's cost to Environment=qa. No cost reduction, but attribution corrected.

**Rollback:** `aws mq delete-tags --resource-arn <arn> --tag-keys Project Environment Owner ManagedBy CostCenter`

**CFN drift risk:** None. Tag-only API call on a resource not tracked in any CFN stack.

**Pre-check:**
```bash
BROKER_ID="b-f231815d-d0dd-42c5-aeb8-c2aeeaa3f803"
BROKER_ARN="arn:aws:mq:eu-central-1:${ACCOUNT_ID}:broker:planodkupow-qa-rabbitmq-cheap"

# Verify broker is active and has zero tags
aws mq describe-broker \
  --broker-id "$BROKER_ID" \
  --query '{Name:BrokerName,State:BrokerState,Tags:Tags,Type:BrokerInstanceType}'
# Expected: State=RUNNING, Tags={}
```

**Action:**
```bash
BROKER_ARN="arn:aws:mq:eu-central-1:${ACCOUNT_ID}:broker:planodkupow-qa-rabbitmq-cheap"

aws mq create-tags \
  --resource-arn "$BROKER_ARN" \
  --tags '{
    "Project": "planodkupow",
    "Environment": "qa",
    "Owner": "DC-devops",
    "ManagedBy": "manual",
    "CostCenter": "DC"
  }'
```

**Post-check:**
```bash
aws mq describe-broker \
  --broker-id "b-f231815d-d0dd-42c5-aeb8-c2aeeaa3f803" \
  --query 'Tags'
# Expected: all 5 keys present
```

**Note:** CE cost allocation tag propagation delay: AWS processes new tags into CE within 24-48 hours. The Environment=qa attribution will appear on the next billing day.

---

### P1.3 — Delete Chaos-Day Orphan MQ Log Groups

**Why:** Three MQ brokers were created and deleted during the April 19 chaos. Their log groups persisted with NEVER_EXPIRES retention. These brokers no longer exist — the logs have no operational value.

**Challenge — verify before deletion:** Confirm that these brokers are actually deleted and the log groups are genuine orphans.

**Pre-check:**
```bash
# Verify these broker IDs do NOT appear in active broker list
aws mq list-brokers --output json | \
  jq '.BrokerSummaries[] | select(.BrokerId | contains("b-5cb3fcb4") or 
      contains("b-b70793a7") or contains("b-9df801b4"))'
# Expected: NO output. If any appear, STOP — do not delete.

# Show the orphan log groups and their sizes
jq -r '.[] | select(.name | contains("b-5cb3fcb4") or contains("b-b70793a7") or contains("b-9df801b4")) | "\(.storedGB) GB | \(.name)"' \
  "$SNAPSHOT_DIR/cw-log-groups-merged.json"
```

**Action — only if pre-check confirms brokers deleted:**
```bash
# Get full names of orphan log groups
aws logs describe-log-groups \
  --output json | \
  jq -r '.logGroups[].logGroupName | 
    select(contains("b-5cb3fcb4") or contains("b-b70793a7") or contains("b-9df801b4"))' | \
  while read LG; do
    echo "Deleting: $LG"
    # dry-run: echo only — uncomment delete line after confirming the list
    # aws logs delete-log-group --log-group-name "$LG"
  done

# After confirming the dry-run list, run for real:
# (remove the 'echo "Deleting"' and uncomment aws logs delete-log-group)
```

**Rollback:** None — log deletion is permanent. This is why the pre-check is mandatory.

**CFN drift risk:** None. These log groups belong to deleted brokers with no CFN stack.

---

### P1.4 — Tag: CloudTrail Trail

**Why:** CloudTrail costs $81/month (100% in "no Environment" CE bucket). The trail is account-level, not environment-specific. Tag with `Environment=shared` to move it out of the untagged bucket into a meaningful CE group.

**Pre-check:**
```bash
# Get trail ARN
TRAIL_ARN=$(jq -r '.trailList[0].TrailARN' "$SNAPSHOT_DIR/cloudtrail-trails.json")
echo "Trail ARN: $TRAIL_ARN"

aws cloudtrail list-tags \
  --resource-id-list "$TRAIL_ARN" \
  --query 'ResourceTagList[0].TagsList'
# Expected: empty or no tags
```

**Action:**
```bash
TRAIL_ARN=$(jq -r '.trailList[0].TrailARN' "$SNAPSHOT_DIR/cloudtrail-trails.json")

aws cloudtrail add-tags \
  --resource-id "$TRAIL_ARN" \
  --tags-list \
    Key=Project,Value=planodkupow \
    Key=Environment,Value=shared \
    Key=Owner,Value=DC-devops \
    Key=ManagedBy,Value=manual \
    Key=CostCenter,Value=DC
```

**Post-check:**
```bash
aws cloudtrail list-tags \
  --resource-id-list "$TRAIL_ARN" \
  --query 'ResourceTagList[0].TagsList'
# Expected: 5 tags present
```

**Rollback:** `aws cloudtrail remove-tags --resource-id <trail_arn> --tags-list Key=Environment ...`

**CFN drift risk:** Low. If CloudTrail is CFN-managed, the template may overwrite these tags on next deploy. Check whether trail is in a CFN stack. If yes, add tags to the CFN resource instead.

---

### P1.5 — Tag: Global Accelerator

**Why:** GA costs $14.98/month (100% untagged). Tag it for CE attribution regardless of decommission decision in P3.

```bash
GA_ARN=$(jq -r '.Accelerators[0].AcceleratorArn' "$SNAPSHOT_DIR/ga-accelerators.json")
echo "GA ARN: $GA_ARN"

aws globalaccelerator tag-resource \
  --resource-arn "$GA_ARN" \
  --tags \
    Key=Project,Value=planodkupow \
    Key=Environment,Value=qa \
    Key=Owner,Value=DC-devops \
    Key=ManagedBy,Value=manual \
    Key=CostCenter,Value=DC \
  --region us-east-1

# Post-check
aws globalaccelerator list-tags-for-resource \
  --resource-arn "$GA_ARN" \
  --region us-east-1
```

**CFN drift risk:** None if GA is not in a CFN stack. Verify:
```bash
# Check if GA has aws:cloudformation:stack-id tag
aws globalaccelerator list-tags-for-resource \
  --resource-arn "$GA_ARN" \
  --region us-east-1 \
  --query 'Tags[?Key==`aws:cloudformation:stack-id`].Value'
```

---

### P1.6 — Tag: WAF WebACL

```bash
# Get WAF ARN from snapshot
WAF_ARN=$(jq -r '.WebACLs[0].ARN' "$SNAPSHOT_DIR/waf-global.json")
echo "WAF ARN: $WAF_ARN"

# Tagging global WAF requires --region us-east-1 and --scope CLOUDFRONT implicitly via ARN
aws wafv2 tag-resource \
  --resource-arn "$WAF_ARN" \
  --tags \
    Key=Project,Value=planodkupow \
    Key=Environment,Value=shared \
    Key=Owner,Value=DC-devops \
    Key=ManagedBy,Value=manual \
    Key=CostCenter,Value=DC \
  --region us-east-1

# Post-check
aws wafv2 list-tags-for-resource \
  --resource-arn "$WAF_ARN" \
  --region us-east-1
```

---

### P1.7 — Tag: ECR Repositories

```bash
# planodkupow-qa
aws ecr tag-resource \
  --resource-arn "arn:aws:ecr:eu-central-1:${ACCOUNT_ID}:repository/planodkupow-qa" \
  --tags \
    Key=Project,Value=planodkupow \
    Key=Environment,Value=qa \
    Key=Owner,Value=DC-devops \
    Key=ManagedBy,Value=cloudformation \
    Key=CostCenter,Value=DC

# planodkupow-uat
aws ecr tag-resource \
  --resource-arn "arn:aws:ecr:eu-central-1:${ACCOUNT_ID}:repository/planodkupow-uat" \
  --tags \
    Key=Project,Value=planodkupow \
    Key=Environment,Value=uat \
    Key=Owner,Value=DC-devops \
    Key=ManagedBy,Value=cloudformation \
    Key=CostCenter,Value=DC

# planodkupow-dev
aws ecr tag-resource \
  --resource-arn "arn:aws:ecr:eu-central-1:${ACCOUNT_ID}:repository/planodkupow-dev" \
  --tags \
    Key=Project,Value=planodkupow \
    Key=Environment,Value=dev \
    Key=Owner,Value=DC-devops \
    Key=ManagedBy,Value=cloudformation \
    Key=CostCenter,Value=DC

# Post-check
for REPO in planodkupow-qa planodkupow-uat planodkupow-dev; do
  echo "=== $REPO ==="
  aws ecr list-tags-for-resource \
    --resource-arn "arn:aws:ecr:eu-central-1:${ACCOUNT_ID}:repository/${REPO}"
done
```

**Challenge on ManagedBy=cloudformation for ECR:** Only set this if ECR repos are confirmed in a CFN stack. If unsure, use `ManagedBy=manual`.

---

### P1.8 — Tag: EIPs (all 6)

**Pre-check:**
```bash
# Show all EIPs with current state
aws ec2 describe-addresses \
  --query 'Addresses[*].{IP:PublicIp,AllocId:AllocationId,Assoc:AssociationId,Tags:Tags}' \
  --output table
```

**Action — tag all 4 associated EIPs first:**
```bash
# For each associated EIP, determine its environment and tag accordingly
# QA ALB EIPs → Environment=qa
# UAT ALB EIPs → Environment=uat  
# NAT GW EIP in OLD VPC → Environment=qa (or orphan — see note)

# IMPORTANT: Get actual alloc IDs from snapshot before running
# Replace eipalloc-XXXX with real values from $SNAPSHOT_DIR/eips.json

# Example structure (fill in real IDs):
# aws ec2 create-tags \
#   --resources eipalloc-<QA_ALB_1> eipalloc-<QA_ALB_2> \
#   --tags Key=Project,Value=planodkupow Key=Environment,Value=qa \
#          Key=Owner,Value=DC-devops Key=ManagedBy,Value=cloudformation Key=CostCenter,Value=DC

# Unassociated EIP — tag for visibility (before deciding release in P1.9)
aws ec2 create-tags \
  --resources eipalloc-02f3a2a04522cff83 \
  --tags \
    Key=Project,Value=planodkupow \
    Key=Environment,Value=qa \
    Key=Owner,Value=DC-devops \
    Key=ManagedBy,Value=orphan \
    Key=CostCenter,Value=DC
```

---

### P1.9 — Release Unassociated EIP (LOW risk — confirm first)

**Why:** 3.77.136.162 (eipalloc-02f3a2a04522cff83) is not attached to any resource. Costs $3.60/month.

**Challenge:** Before releasing, confirm it was not intentionally reserved (e.g., whitelisted by a partner or registered in any external system). Ask the MakoLab team. If it was previously used as a NAT or ALB IP and partners may have it whitelisted, releasing it loses that IP permanently.

**Risk:** Low-medium. Irreversible — IP returns to AWS pool.

**Pre-check:**
```bash
# Confirm still unassociated
aws ec2 describe-addresses \
  --allocation-ids eipalloc-02f3a2a04522cff83 \
  --query 'Addresses[0].{IP:PublicIp,AssociationId:AssociationId,InstanceId:InstanceId}'
# Expected: AssociationId=null, InstanceId=null

# Check for any Route53 records pointing to this IP
aws route53 list-hosted-zones --output json | jq -r '.HostedZones[].Id' | \
  while read ZID; do
    aws route53 list-resource-record-sets --hosted-zone-id "$ZID" | \
      jq --arg ip "3.77.136.162" '.ResourceRecordSets[] | select(.ResourceRecords[]?.Value == $ip) | .Name'
  done
# Expected: no output
```

**Action (only after team confirmation):**
```bash
# IRREVERSIBLE — confirm with team before running
aws ec2 release-address \
  --allocation-id eipalloc-02f3a2a04522cff83
```

**Post-check:**
```bash
aws ec2 describe-addresses --allocation-ids eipalloc-02f3a2a04522cff83 2>&1
# Expected: error InvalidAllocationID.NotFound — confirms released
```

---

### P1 — GO/NO-GO Gate before Phase P2

```
CHECKLIST:

[ ] P1.1: All MQ log groups show retentionInDays ≠ null (verified with post-check)
[ ] P1.2: MQ broker b-f231815d shows 5 tags in describe-broker
[ ] P1.3: Chaos-day log groups deleted (or deferred with documented reason)
[ ] P1.4–P1.8: All tagging actions completed and post-checked
[ ] P1.9: EIP released OR deferred with written team confirmation

GATE CONDITION FOR P2:
The ECS PropagateTags change touches CloudFormation-managed resources.
Before proceeding to P2:

[ ] Confirm the ECS services are in active CFN stacks (verified in P0.1 CFN stack-id field)
[ ] Confirm you have access to modify the CFN template in source control (not ad hoc)
[ ] Confirm a deploy window is scheduled and team is notified
[ ] Confirm no ECS deployments are in progress

DO NOT run P2 if ECS deployments are active.
```

---

## Phase P2 — CFN-Aligned ECS PropagateTags Remediation

**Expected impact:** Moves ~$267/month from "no Environment" to attributed CE buckets. This is an attribution fix, not a cost reduction. Cost stays the same; visibility improves.

**Important caveat:** The change only affects NEW Fargate task launches. Tasks already running continue without tags on their ENIs. CE attribution improvement is gradual as tasks cycle through.

**Time to full CE effect:** 48-72 hours after all tasks replaced (ECS service rolling update).

---

### P2.1 — Identify CFN Stack Ownership of ECS Services

```bash
# From P0.1 snapshot — find all unique stack IDs
jq -r '.[] | .StackId // "UNMANAGED"' "$SNAPSHOT_DIR/ecs-services.json" | \
  sort -u | grep -v null

# For each stack ID, describe the stack
STACK_IDS=$(jq -r '.[] | .StackId // empty' "$SNAPSHOT_DIR/ecs-services.json" | sort -u)
for STACK_ID in $STACK_IDS; do
  echo "=== Stack ==="
  aws cloudformation describe-stacks \
    --stack-name "$STACK_ID" \
    --query 'Stacks[0].{Name:StackName,Status:StackStatus,ParentId:ParentId,RootId:RootId}' \
    --output json
done
```

**What you're looking for:**
- Are all 26 services in the same root stack (e.g., `planodkupow-qa` and `planodkupow-uat`)?
- Are any services NOT in a CFN stack (StackId=null/NONE)? Those require the fallback path.
- What is the root stack vs nested stack relationship?

**Decision tree:**
```
All 26 services in CFN stacks → use Change Set path (P2.2)
Some services NOT in CFN      → use runtime fallback for those only (P2.3)
All services NOT in CFN       → use runtime path for all (P2.3)
```

---

### P2.2 — CFN Change Set Path (preferred)

**Why preferred:** Keeps CFN as the single source of truth. Runtime mutation causes stack drift — the next CFN deploy will revert PropagateTags to NONE if the template isn't updated.

**Step 1: Locate the template.**

```bash
# Find template source (may be S3 or local IaC repo)
ROOT_STACK="planodkupow-qa"  # adjust to actual root stack name
aws cloudformation get-template \
  --stack-name "$ROOT_STACK" \
  --template-stage Original \
  --query 'TemplateBody' \
  --output text > "$SNAPSHOT_DIR/cfn-template-qa-current.json"

# If nested — get the VPC/ECS nested stack template:
aws cloudformation list-stack-resources \
  --stack-name "$ROOT_STACK" \
  --query 'StackResourceSummaries[?ResourceType==`AWS::CloudFormation::Stack`].{LogicalId:LogicalResourceId,PhysicalId:PhysicalResourceId}' \
  --output table
```

**Step 2: Identify ECS Service resources in template.**

```bash
# Find all AWS::ECS::Service resources and their current PropagateTags
cat "$SNAPSHOT_DIR/cfn-template-qa-current.json" | \
  python3 -c "
import json, sys
t = json.load(sys.stdin)
for rname, r in t.get('Resources', {}).items():
    if r.get('Type') == 'AWS::ECS::Service':
        pt = r.get('Properties', {}).get('PropagateTags', 'NOT SET')
        print(f'{rname}: PropagateTags={pt}')
"
```

**Step 3: Apply template change (in your IaC repository).**

```yaml
# In every AWS::ECS::Service resource, add under Properties:
Properties:
  PropagateTags: SERVICE
  # ... existing properties unchanged
```

**Is PropagateTags a replacement attribute?**  
No. According to AWS CloudFormation documentation, `PropagateTags` on `AWS::ECS::Service` is an **Update requires: No interruption** attribute. The service is updated in-place; existing tasks are not replaced immediately but will receive the setting on their next natural replacement.

**Step 4: Create and execute a Change Set (not direct deploy).**

```bash
# Validate the modified template first
aws cloudformation validate-template \
  --template-body file://cfn-template-qa-updated.json

# Create change set — review before execute
aws cloudformation create-change-set \
  --stack-name planodkupow-qa \
  --change-set-name propagate-tags-$(date +%Y%m%d%H%M) \
  --template-body file://cfn-template-qa-updated.json \
  --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
  --description "Add PropagateTags=SERVICE to all ECS services for CE attribution"

# Review what the change set will modify
aws cloudformation describe-change-set \
  --stack-name planodkupow-qa \
  --change-set-name propagate-tags-$(date +%Y%m%d%H%M) \
  --query 'Changes[*].{Action:ResourceChange.Action,LogicalId:ResourceChange.LogicalResourceId,Type:ResourceChange.ResourceType,Replacement:ResourceChange.Replacement}' \
  --output table
```

**Gate before executing:** The change set MUST show:
- `Action=Modify` for ECS Service resources
- `Replacement=False` for all rows
- No resources with `Action=Remove` unless intentional

**Execute (only after reviewing change set):**
```bash
aws cloudformation execute-change-set \
  --stack-name planodkupow-qa \
  --change-set-name propagate-tags-<timestamp>

# Monitor
aws cloudformation wait stack-update-complete \
  --stack-name planodkupow-qa
```

**Repeat for planodkupow-uat stack.**

---

### P2.3 — Runtime Fallback (only for non-CFN services or if CFN route is blocked)

**Use only if:** CFN change set is impossible (e.g., template is lost, stack in bad state, service not in any stack).

**Risk:** Creates CFN stack drift. The next deploy will revert PropagateTags to NONE unless the template is also updated. This is a bandage, not a fix.

**Stage first on one non-critical service:**
```bash
# Stage on one QA service that is least critical (not Gateway-SRVC which already has SERVICE)
TEST_CLUSTER="planodkupow-qa-Klaster"
TEST_SERVICE="<non-critical-service-name>"  # pick from list

# Pre-state
aws ecs describe-services \
  --cluster "$TEST_CLUSTER" \
  --services "$TEST_SERVICE" \
  --query 'services[0].{PropageTags:propagateTags,RunningCount:runningCount}'

# Apply
aws ecs update-service \
  --cluster "$TEST_CLUSTER" \
  --service "$TEST_SERVICE" \
  --propagate-tags SERVICE \
  --force-new-deployment

# Wait for stabilization
aws ecs wait services-stable \
  --cluster "$TEST_CLUSTER" \
  --services "$TEST_SERVICE"

# Post-check: verify new tasks have tags on ENIs
TASK_ARN=$(aws ecs list-tasks \
  --cluster "$TEST_CLUSTER" \
  --service-name "$TEST_SERVICE" \
  --query 'taskArns[0]' --output text)

ENI_ID=$(aws ecs describe-tasks \
  --cluster "$TEST_CLUSTER" --tasks "$TASK_ARN" \
  --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' \
  --output text)

echo "ENI: $ENI_ID"
aws ec2 describe-network-interfaces \
  --network-interface-ids "$ENI_ID" \
  --query 'NetworkInterfaces[0].TagSet'
# Expected: tags present including Environment=qa
```

**Only after staging succeeds, apply to remaining services:**
```bash
for SERVICE_NAME in $(aws ecs list-services \
    --cluster planodkupow-qa-Klaster \
    --query 'serviceArns[*]' \
    --output text | xargs -n1 basename | grep -v Gateway-SRVC); do
  
  echo "Updating: $SERVICE_NAME"
  aws ecs update-service \
    --cluster planodkupow-qa-Klaster \
    --service "$SERVICE_NAME" \
    --propagate-tags SERVICE
  
  # Brief pause between updates to avoid throttling
  sleep 2
done
```

**Rollback (if service instability detected):**
```bash
aws ecs update-service \
  --cluster planodkupow-qa-Klaster \
  --service <SERVICE_NAME> \
  --propagate-tags NONE
```

---

### P2 — GO/NO-GO Gate before Phase P3

```
CHECKLIST:

[ ] All ECS services show PropagateTags=SERVICE (re-run P0.1 snapshot to verify)
[ ] Spot-check 3 running task ENIs — confirm tags present on ENI
[ ] No ECS deployment failures or task startup loops
[ ] CFN stacks are in UPDATE_COMPLETE state (if CFN route used)
[ ] Wait 48h for CE to reflect new attribution
[ ] CE spot-check: Environment=qa bucket should increase; "no Environment" should decrease

GATE CONDITION FOR P3:
P3 involves irreversible deletions.
P3 must NOT proceed until:

[ ] P0 NAT metrics reviewed: BytesOutToDestination for nat-08adf3e0a226779a7
    must be 0 for ≥7 consecutive days
[ ] P0 GA traffic reviewed: ProcessedByteCount for GA accelerator
    must be 0 for ≥7 consecutive days
[ ] Business owner has explicitly approved decommission of GA and old VPC
[ ] A change window is scheduled with rollback plan documented
```

---

## Phase P3 — Cleanup Candidates (7-day metric gate required)

**This phase is destructive and irreversible. Do not execute without explicit GO/NO-GO above.**

**Dependency order is mandatory.** Old QA VPC cannot be deleted until GA and endpoints are removed.

---

### P3 Dependency Graph

```
GA decommission (blocks VPC)
  ↓
Delete 4 VPC endpoints in old QA VPC
  ↓
Delete NAT GW nat-08adf3e0a226779a7
  ↓
Release NAT EIP 3.76.77.101
  ↓
Delete remaining subnets in old QA VPC
  ↓
Delete old QA VPC vpc-02f804baee8a3f048
```

Each step cannot proceed until the previous is confirmed complete.

---

### P3.1 — 7-Day Metric Gate (mandatory)

Run daily from day of P2 completion:

```bash
# NAT gateway — should be 0 bytes every day
aws cloudwatch get-metric-statistics \
  --namespace AWS/NatGateway \
  --metric-name BytesOutToDestination \
  --dimensions Name=NatGatewayId,Value=nat-08adf3e0a226779a7 \
  --start-time "$(date -u -v-7d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u --date='7 days ago' +%Y-%m-%dT%H:%M:%SZ)" \
  --end-time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --period 86400 --statistics Sum \
  --query 'sort_by(Datapoints,&Timestamp)[*].{Date:Timestamp,Bytes:Sum}' \
  --output table

# GA — ProcessedByteCount must be 0 for all 7 days
GA_ARN=$(jq -r '.Accelerators[0].AcceleratorArn' "$SNAPSHOT_DIR/ga-accelerators.json")
GA_ID=$(basename "$GA_ARN")
aws cloudwatch get-metric-statistics \
  --namespace AWS/GlobalAccelerator \
  --metric-name ProcessedByteCount \
  --dimensions Name=Accelerator,Value="$GA_ID" \
  --start-time "$(date -u -v-7d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u --date='7 days ago' +%Y-%m-%dT%H:%M:%SZ)" \
  --end-time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --period 86400 --statistics Sum \
  --region us-east-1 \
  --query 'sort_by(Datapoints,&Timestamp)[*].{Date:Timestamp,Bytes:Sum}' \
  --output table
```

**Pass criteria:** All 7 data points for both metrics are 0 or no data (meaning zero traffic).

---

### P3.2 — Decommission Global Accelerator

**Expected savings:** $14.98/month. Unblocks old VPC cleanup.

**Business risk:** GA provides anycast routing with DDoS protection. If it is in the traffic path (even partially), removal causes traffic disruption. The Unknown health status in the current evidence suggests endpoint groups are unhealthy and GA is not actually routing traffic, but this must be confirmed by the 7-day metric gate.

```bash
GA_ARN=$(jq -r '.Accelerators[0].AcceleratorArn' "$SNAPSHOT_DIR/ga-accelerators.json")

# Step 1: Disable GA (disabling is reversible; deletion is not)
aws globalaccelerator update-accelerator \
  --accelerator-arn "$GA_ARN" \
  --enabled false \
  --region us-east-1

# Wait for state: DISABLED
aws globalaccelerator describe-accelerator \
  --accelerator-arn "$GA_ARN" \
  --region us-east-1 \
  --query 'Accelerator.Status'

# Step 2: Remove all endpoint groups from listeners
LISTENER_ARN=$(jq -r '.Listeners[0].ListenerArn' "$SNAPSHOT_DIR/ga-listeners.json")
EG_ARN=$(jq -r '.EndpointGroups[0].EndpointGroupArn' "$SNAPSHOT_DIR/ga-endpoint-groups.json")

aws globalaccelerator delete-endpoint-group \
  --endpoint-group-arn "$EG_ARN" \
  --region us-east-1

# Step 3: Delete listener
aws globalaccelerator delete-listener \
  --listener-arn "$LISTENER_ARN" \
  --region us-east-1

# Step 4: Delete accelerator
aws globalaccelerator delete-accelerator \
  --accelerator-arn "$GA_ARN" \
  --region us-east-1
```

**Rollback for step 1 (disable only):**
```bash
aws globalaccelerator update-accelerator \
  --accelerator-arn "$GA_ARN" \
  --enabled true \
  --region us-east-1
```

**Rollback after deletion:** None. The anycast IPs 52.223.4.64 and 166.117.244.150 are lost.

---

### P3.3 — Delete Old QA VPC Endpoints

```bash
OLD_VPC="vpc-02f804baee8a3f048"

# Get endpoint IDs in old VPC
OLD_ENDPOINT_IDS=$(aws ec2 describe-vpc-endpoints \
  --filters Name=vpc-id,Values="$OLD_VPC" \
            Name=vpc-endpoint-state,Values=available \
  --query 'VpcEndpoints[*].VpcEndpointId' \
  --output text)

echo "Endpoints to delete: $OLD_ENDPOINT_IDS"

# Confirm each is in old VPC
aws ec2 describe-vpc-endpoints \
  --vpc-endpoint-ids $OLD_ENDPOINT_IDS \
  --query 'VpcEndpoints[*].{Id:VpcEndpointId,Service:ServiceName,VPC:VpcId}' \
  --output table

# Delete
aws ec2 delete-vpc-endpoints \
  --vpc-endpoint-ids $OLD_ENDPOINT_IDS

# Post-check — state should be deleting/deleted
aws ec2 describe-vpc-endpoints \
  --vpc-endpoint-ids $OLD_ENDPOINT_IDS \
  --query 'VpcEndpoints[*].{Id:VpcEndpointId,State:State}' \
  --output table
```

**Expected savings:** $28.80/month (4 × $7.20)

---

### P3.4 — Delete Old QA NAT Gateway + Release EIP

```bash
NAT_ID="nat-08adf3e0a226779a7"
NAT_EIP="eipalloc-<get from P0.8 snapshot for 3.76.77.101>"

# Delete NAT GW
aws ec2 delete-nat-gateway --nat-gateway-id "$NAT_ID"

# Wait for deleted state (may take 2-3 minutes)
aws ec2 wait nat-gateway-deleted --nat-gateway-ids "$NAT_ID"

# Release the EIP (only after NAT GW is deleted)
aws ec2 release-address --allocation-id "$NAT_EIP"
```

**Rollback:** Not possible. New NAT GW can be created but will have a different EIP.

---

### P3.5 — Delete Old QA VPC

```bash
OLD_VPC="vpc-02f804baee8a3f048"

# Pre-check: all dependencies must be removed first
aws ec2 describe-vpc-endpoints \
  --filters Name=vpc-id,Values="$OLD_VPC" \
            Name=vpc-endpoint-state,Values=available \
  --query 'VpcEndpoints[*].VpcEndpointId'
# Expected: empty

aws ec2 describe-nat-gateways \
  --filter Name=vpc-id,Values="$OLD_VPC" \
           Name=state,Values=available \
  --query 'NatGateways[*].NatGatewayId'
# Expected: empty

# Check for remaining subnets
SUBNET_IDS=$(aws ec2 describe-subnets \
  --filters Name=vpc-id,Values="$OLD_VPC" \
  --query 'Subnets[*].SubnetId' --output text)
echo "Remaining subnets: $SUBNET_IDS"

# Delete subnets
for SID in $SUBNET_IDS; do
  aws ec2 delete-subnet --subnet-id "$SID"
done

# Check for remaining security groups (skip default)
aws ec2 describe-security-groups \
  --filters Name=vpc-id,Values="$OLD_VPC" \
  --query 'SecurityGroups[?GroupName!=`default`].GroupId' \
  --output text | xargs -n1 aws ec2 delete-security-group --group-id

# Delete route tables (non-main)
aws ec2 describe-route-tables \
  --filters Name=vpc-id,Values="$OLD_VPC" \
  --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' \
  --output text | xargs -n1 aws ec2 delete-route-table --route-table-id

# Detach and delete internet gateway if present
IGW_ID=$(aws ec2 describe-internet-gateways \
  --filters Name=attachment.vpc-id,Values="$OLD_VPC" \
  --query 'InternetGateways[0].InternetGatewayId' --output text)
if [ -n "$IGW_ID" ] && [ "$IGW_ID" != "None" ]; then
  aws ec2 detach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$OLD_VPC"
  aws ec2 delete-internet-gateway --internet-gateway-id "$IGW_ID"
fi

# Finally delete the VPC
aws ec2 delete-vpc --vpc-id "$OLD_VPC"
```

**Expected savings from P3.3-P3.5 combined:** ~$40-50/month (endpoints + NAT + EIP + VPC data transfer).

---

## 4. Immediate Execution Recommendation

### Next 30 minutes (right now, no change window needed)

Execute P0 fully, then begin P1 items in this order:

| Step | Action | Time | Why now |
|------|--------|------|---------|
| 1 | Run all P0 snapshots | 15 min | Baseline before any change |
| 2 | P1.1: Set MQ log retention 30d | 5 min | Largest single savings ($111/mo), zero risk, zero blast radius |
| 3 | P1.2: Tag MQ orphan broker | 2 min | Zero risk, fixes $21/mo CE attribution gap |
| 4 | P1.4: Tag CloudTrail | 2 min | Zero risk, $81/mo attribution |
| 5 | P1.5: Tag GA | 2 min | Zero risk, $15/mo attribution |
| 6 | P1.6: Tag WAF | 2 min | Zero risk |
| 7 | P1.7: Tag ECR repos | 3 min | Zero risk |
| 8 | P1.3: Delete chaos-day MQ log groups | 5 min | Only after pre-check confirms orphan |

**Do NOT do today:** P1.8/P1.9 (EIP release — need team confirmation), P2 (needs deploy window), P3 (needs 7-day gate).

### Waiting for maintenance window (next week)

| Step | Prerequisite | Action |
|------|-------------|--------|
| P1.8/P1.9 | Team confirmation that unassociated EIP not whitelisted | Tag and release EIP |
| P2 | Scheduled deploy window, team notified | CFN change set for PropagateTags |
| P3 metric check | 7 days post-P2 | Verify NAT and GA traffic = 0 |
| P3 decommission | P3 metric gate passed + business sign-off | Old VPC teardown |

### What to challenge before you start

1. **MQ broker ManagedBy tag value:** The request said `ManagedBy=cloudformation` — that is wrong for an orphan created outside CFN. Use `ManagedBy=manual`.
2. **ECR ManagedBy=cloudformation:** Verify ECR repos are actually in a CFN stack before setting this tag. If unsure, use `ManagedBy=manual`.
3. **PropagateTags CFN vs runtime:** Do NOT run `aws ecs update-service --propagate-tags SERVICE` directly unless you have confirmed the services are not in any CFN stack. A runtime mutation on a CFN-managed service will be silently reverted on the next stack update.
4. **GA decommission:** Health=Unknown does not prove zero traffic. The CloudWatch `ProcessedByteCount` metric is the only safe gate. Do not delete GA on Unknown health alone.
5. **Old QA VPC:** Verify that no test tooling, VPN configurations, or external whitelist rules reference the old VPC subnets before deletion.

---

## Cross-References

- [[planodkupow-ce-audit-2026-04-26]] — billing evidence
- [[planodkupow-runtime-verification-2026-04-26]] — runtime findings
- [[planodkupow-finops-governance-audit-2026-04-25]] — governance posture
- [[planodkupow-qa-tagging-audit-2026-04-25]] — QA VPC tagging detail
- [[planodkupow-orphan-network-investigation-2026-04-24]] — old VPC forensics
