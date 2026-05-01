---
date: 2026-04-25
project: planodkupow
client: mako
account: "333320664022"
region: eu-central-1
profile: plan
tags: [planodkupow, finops, governance, llz, audit, tagging, cost-explorer]
domain: client-work/mako
status: evidence-based inference — requires fresh CLI run to validate
---

# PlanOdkupow — FinOps + Governance Audit

**Date:** 2026-04-25  
**Account:** 333320664022 | **Region:** eu-central-1 | **Profile:** `plan`  
**Auditor posture:** Senior FinOps + Governance — live resources only, billing data primary

> **Evidence transparency:** Commands in this document are executable. Findings marked
> `[CONFIRMED]` are from prior investigations. Findings marked `[INFERRED]` are
> evidence-based reasoning. Findings marked `[VERIFY]` require fresh CLI run.

---

## EXECUTIVE SUMMARY

| Dimension | Finding | Risk |
|-----------|---------|------|
| Monthly spend visible | ~$934/month total (ECS $324 + VPC $162 + CT $79 + MQ $71 + RDS $64 + CW $40 + EC $39 + ELB $31 + EC2-Other $30 + GA $14) | — |
| Untagged cost slice | **$789/month** (~85% of total) — see root cause below | CRITICAL |
| Tagged cost slice | **$145/month** (~15%) — only QA new-schema resources | HIGH |
| Root cause of $789 | UAT uses Polish-language tag keys (`Srodowisko`, `Projekt`) — Cost Explorer cannot match `Environment` filter, making entire UAT bill appear as "untagged" | CRITICAL |
| Idle/orphan costs | Old QA NAT (EIP 3.76.77.101, nat-08adf3e0a226779a7) + 4 legacy VPC endpoints in old QA VPC — estimated $40-75/month wasted | HIGH |
| Global Accelerator | Health Unknown, $14/month, likely carrying zero traffic | MAJOR |
| Governance posture | Two parallel tag schemas coexisting (EN vs PL keys). No SCP enforcement visible. CloudFront with zero tags. | MAJOR |
| LLZ maturity | Partial. CloudTrail active ($79/month). Network architecture smells (public subnet IGW, no private endpoints in new QA). | MEDIUM |
| Quick wins | Tag UAT with English keys → instantly moves $260+/month into FinOps visibility | HIGH |

---

## PHASE 1 — Live Inventory Discovery

### 1.1 Discovery Commands (run in order)

```bash
export AWS_PROFILE=plan
export AWS_REGION=eu-central-1
export ACCOUNT=333320664022

# ── NETWORKING ────────────────────────────────────────────────────────────────

# All VPCs
aws ec2 describe-vpcs \
  | jq '.Vpcs[] | {VpcId, CidrBlock, State,
      Name: (.Tags[]? | select(.Key=="Name") | .Value),
      Env: (.Tags[]? | select(.Key=="Environment" or .Key=="Srodowisko") | .Value),
      TagCount: (.Tags | length)}'

# NAT Gateways (all states)
aws ec2 describe-nat-gateways \
  | jq '.NatGateways[] | {Id: .NatGatewayId, State, VpcId,
      PublicIp: .NatGatewayAddresses[0].PublicIp,
      Created: .CreateTime,
      TagCount: (.Tags | length)}'

# Internet Gateways
aws ec2 describe-internet-gateways \
  | jq '.InternetGateways[] | {Id: .InternetGatewayId,
      AttachedVpc: (.Attachments[0].VpcId // "DETACHED"),
      TagCount: (.Tags | length)}'

# VPC Endpoints (all active)
aws ec2 describe-vpc-endpoints \
  --filters "Name=vpc-endpoint-state,Values=available,pending" \
  | jq '.VpcEndpoints[] | {Id: .VpcEndpointId, VpcId, Type: .VpcEndpointType,
      Service: .ServiceName, State: .State,
      TagCount: (.Tags | length)}'

# Elastic IPs
aws ec2 describe-addresses \
  | jq '.Addresses[] | {AllocationId, PublicIp, AssociationId,
      AssociatedInstance: (.InstanceId // .NetworkInterfaceId // "UNASSOCIATED"),
      Domain,
      TagCount: (.Tags | length)}'

# Global Accelerator (us-east-1 only — GA is global, API endpoint in us-east-1)
aws globalaccelerator list-accelerators --region us-east-1 \
  | jq '.Accelerators[] | {Name, Arn, Status,
      IpSets: [.IpSets[].IpAddresses[]]}'
aws globalaccelerator list-listeners --region us-east-1 \
  --accelerator-arn $(aws globalaccelerator list-accelerators --region us-east-1 \
    | jq -r '.Accelerators[0].AcceleratorArn')

# ── COMPUTE / CONTAINERS ──────────────────────────────────────────────────────

# ECS clusters
aws ecs list-clusters | jq -r '.clusterArns[]' | while read arn; do
  aws ecs describe-clusters --clusters "$arn" \
    | jq '.clusters[] | {Name: .clusterName, Status, Services: .activeServicesCount,
        Running: .runningTasksCount, Pending: .pendingTasksCount}'
done

# ECS services per cluster
aws ecs list-clusters | jq -r '.clusterArns[]' | while read carn; do
  cname=$(echo "$carn" | cut -d/ -f3)
  aws ecs list-services --cluster "$carn" | jq -r '.serviceArns[]' | while read sarn; do
    aws ecs describe-services --cluster "$carn" --services "$sarn" \
      | jq --arg c "$cname" '.services[] | {
          Cluster: $c,
          Service: .serviceName,
          DesiredCount: .desiredCount,
          RunningCount: .runningCount,
          PropagateTags: .propagateTags,
          TagCount: (.tags | length)}'
  done
done

# ALB / NLB
aws elbv2 describe-load-balancers \
  | jq '.LoadBalancers[] | {Name: .LoadBalancerName, Type, Scheme, VpcId, State: .State.Code}'

# ECR repositories
aws ecr describe-repositories \
  | jq '.repositories[] | {Name: .repositoryName, Uri: .repositoryUri,
      ImageCount: .imageScanningConfiguration,
      TagCount: 0}'  # Tags require separate list-tags-for-resource

# Lambda functions
aws lambda list-functions \
  | jq '.Functions[] | {Name: .FunctionName, Runtime, Memory: .MemorySize,
      LastModified,
      TagCount: 0}'

# ── DATA ──────────────────────────────────────────────────────────────────────

# RDS instances
aws rds describe-db-instances \
  | jq '.DBInstances[] | {Id: .DBInstanceIdentifier, Class: .DBInstanceClass,
      Engine, Status: .DBInstanceStatus,
      VpcId: .DBSubnetGroup.VpcId,
      MultiAZ,
      AllocatedStorage}'

# ElastiCache clusters
aws elasticache describe-cache-clusters \
  | jq '.CacheClusters[] | {Id: .CacheClusterId, NodeType: .CacheNodeType,
      Engine, Status: .CacheClusterStatus, NumNodes: .NumCacheNodes}'

# Amazon MQ brokers
aws mq list-brokers \
  | jq '.BrokerSummaries[] | {Id: .BrokerId, Name: .BrokerName,
      Type: .BrokerType, State: .BrokerState}'

# S3 buckets
aws s3api list-buckets \
  | jq '.Buckets[] | {Name, Created: .CreationDate}'

# ── SECURITY / GOVERNANCE ─────────────────────────────────────────────────────

# CloudTrail trails
aws cloudtrail describe-trails \
  | jq '.trailList[] | {Name, HomeRegion, IsMultiRegionTrail,
      LogBucket: .S3BucketName, IsOrganizationTrail}'

# CloudWatch log groups (count + size)
aws logs describe-log-groups \
  | jq '.logGroups[] | {Name: .logGroupName,
      RetentionDays,
      StoredBytes,
      TagCount: 0}' \
  | jq -s 'length, (map(.StoredBytes) | add)'

# WAF WebACLs (regional)
aws wafv2 list-web-acls --scope REGIONAL \
  | jq '.WebACLs[] | {Name, Id, Description}'

# Route53 hosted zones
aws route53 list-hosted-zones \
  | jq '.HostedZones[] | {Name, Id, Private: .Config.PrivateZone,
      RecordCount: .ResourceRecordSetCount}'

# Transfer Family
aws transfer list-servers \
  | jq '.Servers[] | {ServerId, State, IdentityProviderType, Domain}'

# IAM roles with tags (sample — full scan expensive)
aws iam list-roles --max-items 100 \
  | jq '.Roles[] | select(.RoleName | startswith("planodkupow"))
        | {Name: .RoleName, Created: .CreateDate}' 2>/dev/null | head -40
```

### 1.2 Inventory — Known State (from prior investigations)

#### VPCs [CONFIRMED]

| VPC ID | Name | Environment | Stack | Status |
|--------|------|-------------|-------|--------|
| vpc-007d115c41f079bf3 | planodkupow-qa-VPC | qa (new schema) | planodkupow-qa-VPCStack-1V91EF1UIC85A | ACTIVE — new QA workload plane |
| vpc-02f804baee8a3f048 | planodkupow-qa-VPC | qa (old schema) | planodkupow-qa-VPCStack-1OHNJ84RQI8K2 (DELETE_COMPLETE) | ORPHAN SUSPECT — stack deleted, VPC retained |
| vpc-0b91c465aa64ba545 | (UAT VPC) | uat (old schema `Srodowisko`) | planodkupow-uat (UPDATE_ROLLBACK_COMPLETE) | ACTIVE — UAT workload plane |
| vpc-6e1d9904 | default | — | AWS default | DEFAULT — likely unused |

#### NAT Gateways [CONFIRMED]

| Resource | VPC | EIP | State | Cost/month | Risk |
|---------|-----|-----|-------|-----------|------|
| nat-08adf3e0a226779a7 | OLD QA vpc-02f804baee8a3f048 | 3.76.77.101 | available | ~$32 fixed + data | HIGH — stack DELETE_COMPLETE, NAT still running |

**No NAT in new QA VPC** (public subnet + IGW architecture). No NAT visible in UAT VPC [VERIFY].

#### VPC Endpoints [CONFIRMED]

| Endpoint | VPC | Service | Tag status | Note |
|---------|-----|---------|-----------|------|
| vpce-0f06338f894336448 | OLD QA | ecr.api | old schema | Orphan suspect |
| vpce-0066f4327e86d8687 | OLD QA | ecr.dkr | old schema | Orphan suspect |
| vpce-0dcfc106af654bae6 | OLD QA | secretsmanager | old schema | Orphan suspect |
| vpce-093fc974c5ae750f4 | OLD QA | logs | old schema | Orphan suspect |
| vpce-0aab2367ad6396bd9 | NEW QA / UAT | AMQ PrivateLink | [VERIFY] | Active dependency |
| vpce-0973cb43ab01ac289 | UAT | AMQ PrivateLink | [VERIFY] | Active dependency |

**New QA VPC has ZERO standard VPC endpoints.** ECS tasks in public subnets egress via IGW directly. This is an architectural smell (see Phase 3).

#### Global Accelerator [CONFIRMED]

| Anycast IPs | Health | Monthly cost | Traffic last 7 days |
|-------------|--------|-------------|---------------------|
| 52.223.4.64, 166.117.244.150 | **Unknown** | ~$14 | Unknown — [VERIFY metrics] |

GA is QA-only. GA ENIs are blocking decommission of old QA VPC.

#### Compute [CONFIRMED + VERIFY]

| Resource | Environment | Stack status | Tag schema | PropagateTags |
|---------|-------------|-------------|-----------|--------------|
| ECS: planodkupow-qa-Klaster | QA | CREATE_COMPLETE | New (EN) | [VERIFY] |
| ECS: UAT cluster | UAT | UPDATE_ROLLBACK_COMPLETE | Old (PL) | [VERIFY] |
| ALB (QA) | QA | CFN-managed | New (EN) ✓ | — |
| ALB ×2 (UAT) | UAT | CFN-managed | Old (PL) ✓ | — |
| ECR repositories | Both | [VERIFY] | [VERIFY] | — |
| Lambda functions | [VERIFY] | [VERIFY] | [VERIFY] | — |

#### Data [CONFIRMED]

| Resource | Env | VPC | Tag schema | Class |
|---------|-----|-----|-----------|-------|
| planodkupowqadb (RDS) | QA | new | New (EN) ✓ | COMPLIANT |
| planodkupowuatdb (RDS) | UAT | UAT | Old (PL) | MISSING Owner/ManagedBy/CostCenter |
| planodkupow-qa-redisinst | QA | new | New (EN) ✓ | COMPLIANT |
| planodkupow-uat-redisinst | UAT | UAT | Old (PL) | MISSING Owner/ManagedBy/CostCenter |
| planodkupow-qa-rabbitmq-cheap | QA | new | [VERIFY — orphan suspect] | NOT IN CFN STACK |

#### S3 Buckets [CONFIRMED]

| Bucket | Schema | Status |
|-------|--------|--------|
| planodkupow-qa | New (EN) ✓ | OK |
| planodkupow-qa-pliki | New (EN) ✓ | OK |
| planodkupow-uat | Old (PL) | MISSING Owner/ManagedBy/CostCenter |
| planodkupow-uat-pliki | Old (PL) | MISSING Owner/ManagedBy/CostCenter |
| planodkupow-cf | Old/dev schema | MISSING multiple |
| planodkupow-s3-logi | Old/dev schema | MISSING multiple |

#### CloudFront [CONFIRMED — OUT OF SCOPE but FinOps-relevant]

| Distribution | Env | Tag count | Note |
|-------------|-----|-----------|------|
| EORCEYNXGKU9K | QA | **ZERO** | Confirmed zero tags in Phase 1 |
| E2KYCZWO6DNDQQ | UAT | [VERIFY] | Old schema |
| E1GPI75PXVTZP5 | UAT | [VERIFY] | Old schema |
| EF983GSFSLS4A | UAT | [VERIFY] | Old schema |

CloudFront costs are not visible in the breakdown provided — either very small or attributed to other services.

---

## PHASE 2 — FinOps Tagging Audit

### 2.1 Root Cause: $789 Untagged Slice

**Finding: PRIMARY DRIVER IS TAG KEY SCHEMA DIVERGENCE, NOT MISSING TAGS.**

The $789 "no Environment tag" slice is not caused by resources with missing tags. It is caused by UAT using a completely different tag key vocabulary:

| Tag key | QA (new schema) | UAT (old schema) | Cost Explorer filter "no Environment" |
|---------|----------------|-----------------|--------------------------------------|
| Project key | `Project` | `Projekt` (Polish) | UAT appears UNTAGGED |
| Environment key | `Environment` | `Srodowisko` (Polish) | UAT appears UNTAGGED |
| Owner key | `Owner` | `Maintainer` | UAT appears UNTAGGED |
| Managed by key | `ManagedBy` | `Provisioner` | UAT appears UNTAGGED |
| Cost center key | `CostCenter` | **ABSENT** | UAT appears UNTAGGED |

AWS Cost Explorer and tag policies operate on exact key strings. `Srodowisko=uat` is invisible to any filter or policy that uses `Environment`. The entire UAT bill (~$260-300/month) appears as completely untagged infrastructure.

### 2.2 Cost Attribution Model

```
Total monthly spend: ~$934
├─ TAGGED (has Environment=qa):         ~$145  (15%)
│   └─ QA new-schema resources: VPC, ALB, TG, RDS, Redis, ECS cluster
│       Note: ECS task compute may leak to untagged if PropagateTags unset
│
└─ UNTAGGED (no Environment key):       ~$789  (85%)
    ├─ UAT workload (Srodowisko=uat, ~$260-300)
    │   ├─ ECS UAT cluster:     ~$162   (half of total ECS $324)
    │   ├─ RDS UAT:             ~$32    (half of $64)
    │   ├─ ElastiCache UAT:     ~$19    (half of $39)
    │   ├─ MQ UAT:              ~$35    (half of $71)
    │   └─ ALB/ELB UAT:        ~$15    (half of $31)
    │
    ├─ CloudTrail:              ~$79    (account-level trail, no Environment tag)
    │   └─ $79/month is HIGH — suggests S3 data events enabled
    │
    ├─ CloudWatch:              ~$40    (log groups likely untagged)
    │
    ├─ Old QA VPC residual:     ~$40-75
    │   ├─ NAT Gateway (nat-08adf3e0a226779a7): ~$32 fixed + data
    │   ├─ 4× VPC endpoints (old QA): ~$29 (4 × 1 AZ × $0.01/hr × 720h)
    │   └─ IGW (old QA, still attached)
    │
    ├─ Global Accelerator:      ~$14   (Unknown health, likely 0 traffic)
    │
    ├─ EC2-Other:               ~$30   (EIPs, ENI data transfer, misc)
    │   └─ EIP 3.76.77.101 unassociated charges possible
    │
    └─ ECS task ENIs:           [VERIFY]
        └─ If PropagateTags=NONE on services, Fargate compute attributed
           to untagged ENIs — could explain residual gap
```

### 2.3 Tagging Coverage Matrix

#### Required tags check

| Resource | Project | Environment | Owner | ManagedBy | CostCenter | Status |
|---------|---------|-------------|-------|-----------|-----------|--------|
| QA VPC | planodkupow ✓ | qa ✓ | DC-devops ✓ | cloudformation ✓ | DC ✓ | **COMPLIANT** |
| QA ALB | ✓ | ✓ | ✓ | ✓ | ✓ | **COMPLIANT** |
| QA TG ×3 | ✓ | ✓ | ✓ | ✓ | ✓ | **COMPLIANT** |
| QA RDS | ✓ | ✓ | ✓ | ✓ | ✓ | **COMPLIANT** |
| QA Redis | ✓ | ✓ | ✓ | ✓ | ✓ | **COMPLIANT** |
| QA ECS cluster | ✓ | ✓ | ✓ | ✓ | ✓ | **COMPLIANT** |
| QA ECS services | [VERIFY] | [VERIFY] | [VERIFY] | [VERIFY] | [VERIFY] | **UNKNOWN** |
| QA ECS task ENIs | [VERIFY] | [VERIFY] | — | — | — | **PROPAGATION RISK** |
| QA MQ broker | [VERIFY] | [VERIFY] | [VERIFY] | [VERIFY] | [VERIFY] | **ORPHAN SUSPECT** |
| QA CloudFront | ✗ | ✗ | ✗ | ✗ | ✗ | **ZERO TAGS** (out of scope but cost driver) |
| QA Log Groups | [VERIFY] | [VERIFY] | [VERIFY] | [VERIFY] | [VERIFY] | **LIKELY ZERO** |
| Old QA NAT | old schema | old schema | ✗ | ✗ | ✗ | **PARTIAL + ORPHAN** |
| Old QA endpoints ×4 | old schema | old schema | ✗ | ✗ | ✗ | **PARTIAL + ORPHAN** |
| UAT VPC | Projekt ✓* | Srodowisko ✓* | ✗** | ✗** | ✗** | **WRONG KEY SCHEMA** |
| UAT RDS | Projekt ✓* | Srodowisko ✓* | ✗ | ✗ | ✗ | **WRONG KEY SCHEMA** |
| UAT Redis | Projekt ✓* | Srodowisko ✓* | ✗ | ✗ | ✗ | **WRONG KEY SCHEMA** |
| UAT ECS cluster | Projekt ✓* | Srodowisko ✓* | ✗ | ✗ | ✗ | **WRONG KEY SCHEMA** |
| UAT ALB ×2 | Projekt ✓* | Srodowisko ✓* | ✗ | ✗ | ✗ | **WRONG KEY SCHEMA** |
| S3 (shared) | partial | old schema | ✗ | ✗ | ✗ | **PARTIAL** |
| CloudTrail | [VERIFY] | [VERIFY] | [VERIFY] | [VERIFY] | [VERIFY] | **LIKELY UNTAGGED** |
| Global Accelerator | [VERIFY] | [VERIFY] | [VERIFY] | [VERIFY] | [VERIFY] | **LIKELY UNTAGGED** |

`*` = value present but under wrong key name (`Projekt`/`Srodowisko`)  
`**` = `Maintainer` present (≠ `Owner`), `Provisioner` present (≠ `ManagedBy`)

### 2.4 CloudTrail $79/month — Anomaly

$79/month for CloudTrail is elevated. Normal management events for a single-account non-org setup:  
- Management events: first copy free  
- Each additional copy: $2.00 per 100,000 events  

$79/month implies either:
1. **S3 data events enabled** — $0.10 per 100,000 events × high S3 activity
2. **Lambda data events** — same rate
3. **Organization trail** — aggregating from multiple accounts (unlikely for single-account setup)
4. **CloudTrail Lake** — event data store, $0.005 per 100,000 events ingested + storage

**Verify:**
```bash
aws cloudtrail describe-trails | jq '.trailList[] | {
  Name, HomeRegion, IsMultiRegionTrail, IsOrganizationTrail,
  HasS3DataEvents: "verify separately",
  Bucket: .S3BucketName}'

# Check if data events are enabled
aws cloudtrail get-event-selectors --trail-name <trail-name> \
  | jq '.EventSelectors[] | {ReadWriteType, DataResources}'

# Check CloudTrail Lake data stores
aws cloudtrail list-event-data-stores
```

---

## PHASE 3 — LLZ / Governance Posture

### 3.1 Tagging Compliance Maturity: LEVEL 2 of 5

| Level | Description | Status |
|-------|-------------|--------|
| L1 | Some resources have some tags | ✓ achieved |
| L2 | Defined schema exists, partially applied | ✓ achieved — but schema split QA/UAT |
| L3 | Schema enforced consistently across all environments | ✗ — UAT uses wrong keys |
| L4 | Tag policies / SCPs prevent untagged resources from being created | ✗ — not enforced |
| L5 | Automated drift detection and remediation | ✗ |

### 3.2 Centralized Logging Signals

| Signal | Status | Evidence |
|--------|--------|---------|
| CloudTrail active | ✓ | $79/month spend confirms active |
| CloudTrail multi-region | [VERIFY] | Check trail config |
| CloudWatch log groups | ✓ present | $40/month spend confirms active |
| VPC Flow Logs (new QA) | [VERIFY] | Not confirmed |
| VPC Flow Logs (old QA) | [VERIFY] | Likely absent — orphan VPC |
| CloudTrail → CloudWatch Logs integration | [VERIFY] | Useful for near-real-time alerting |
| CloudWatch alarms | [VERIFY] | Not audited |
| WAF logging | [VERIFY] | WAF not confirmed in account |

**Concern:** $79/month CloudTrail without verified log group retention policy = possible runaway S3 storage. If trail logs to S3 with no lifecycle policy, storage compounds indefinitely.

### 3.3 Network Architecture Smells

| Smell | Detail | Risk | Recommendation |
|-------|--------|------|----------------|
| New QA VPC: no private VPC endpoints | ECS tasks in public subnets egress via IGW directly to AWS services (ECR, Secrets Manager, CloudWatch Logs) | MEDIUM — traffic routes through public internet, higher data transfer cost | Add PrivateLink endpoints or accept as QA cost decision |
| Old QA VPC alive | Stack DELETE_COMPLETE but VPC, NAT, 4 endpoints, IGW still running | HIGH — ~$40-75/month wasted | Decommission requires GA ENI resolution first |
| Global Accelerator blocking decommission | GA ENIs attached in old QA VPC, health Unknown | HIGH | Remove GA endpoints, release ENIs, then decommission |
| Two QA VPCs same Name tag | vpc-007d115c41f079bf3 and vpc-02f804baee8a3f048 both named "planodkupow-qa-VPC" | MEDIUM — operational confusion | Rename old VPC to "planodkupow-qa-VPC-ORPHAN-DO-NOT-USE" |
| ECS tasks in public subnets | assignPublicIp=ENABLED likely — ephemeral public IPs per task | MEDIUM — no consistent egress IP for partner whitelisting | Confirm with `aws ecs describe-services` |

### 3.4 Idle / Legacy Resource Indicators

| Resource | Evidence of Idleness | Monthly waste | Action |
|---------|---------------------|--------------|--------|
| nat-08adf3e0a226779a7 | Stack DELETE_COMPLETE, old VPC, no active routes to it from ECS | ~$32-50 | Decommission (after GA ENI released) |
| 4× VPC endpoints in old QA | Old VPC, no active ECS tasks in old VPC confirmed | ~$29 | Delete after NAT removed |
| GA (52.223.4.64, 166.117.244.150) | Health Unknown, $14/month, zero confirmed traffic | $14 | Decommission after verifying zero traffic |
| EIP 3.76.77.101 | Associated with orphan NAT — will become unassociated charge after NAT deleted | $3.60/month if orphaned | Release after NAT delete |
| igw-0862c2814f8c0265b | Old QA VPC, still attached per forensic audit | $0 (IGW free) but blocks full cleanup | Detach + delete |

### 3.5 Governance Gaps

| Gap | Severity | Evidence |
|-----|---------|---------|
| No SCP enforcement on tagging | HIGH | $789/month untagged resources created without enforcement |
| Parallel tag schemas coexisting | HIGH | QA EN keys, UAT PL keys — neither Cost Explorer nor tag policies can unify |
| CloudFront with zero tags | HIGH | EORCEYNXGKU9K confirmed zero tags |
| Amazon MQ broker not in root CFN stack | HIGH | planodkupow-qa-rabbitmq-cheap — orphan suspect, manual creation |
| ECS PropagateTags unknown | MEDIUM | Fargate compute may be attributed to untagged ENIs |
| CloudTrail data events unknown | MEDIUM | $79/month unexplained without data events audit |
| No WAF confirmed | MEDIUM | Internet-facing ALB without confirmed WAF |
| Log group retention not verified | LOW-MEDIUM | $40/month CloudWatch — is any of it runaway log storage? |
| UAT stack UPDATE_ROLLBACK_COMPLETE | HIGH | Stack in failed state — CFN cannot safely manage UAT resources |

### 3.6 Quick Wins

| Action | Impact | Effort | Risk | CLI method |
|--------|--------|--------|------|-----------|
| Add `Environment=uat` to all UAT resources | Moves ~$260-300/month from "untagged" to FinOps-visible | MEDIUM | LOW (additive tagging) | `ec2 create-tags`, `rds add-tags-to-resource`, etc. |
| Add `Owner`, `ManagedBy`, `CostCenter` to UAT resources | Completes standard schema | MEDIUM | LOW (additive) | Same API calls |
| Tag CloudTrail trail | Attribute $79/month in Cost Explorer | LOW | ZERO | `cloudtrail add-tags` |
| Tag Global Accelerator | Attribute $14/month | LOW | ZERO | `globalaccelerator tag-resource` |
| Decommission old QA NAT | Save $32-50/month | LOW | LOW (verify no traffic first) | After GA ENI release |
| Decommission GA | Save $14/month + unblock old VPC cleanup | MEDIUM | MEDIUM (verify zero traffic) | Remove endpoint groups first |
| Enable VPC Flow Logs on new QA | Forensic visibility for zero marginal cost if CW Logs already paid | LOW | ZERO | `ec2 create-flow-logs` |

---

## PHASE 4 — Safe Next Actions (Prioritized)

### Step 1 — Read-only: establish baseline (zero risk)

```bash
export AWS_PROFILE=plan
export AWS_REGION=eu-central-1

# 1a. Confirm both VPCs and their tag state
aws ec2 describe-vpcs \
  | jq '.Vpcs[] | {VpcId, CidrBlock,
      Tags: ([.Tags[] | {(.Key): .Value}] | add // {})}'

# 1b. NAT Gateway — confirm state and traffic (run for old QA NAT)
aws ec2 describe-nat-gateways \
  --filter "Name=nat-gateway-id,Values=nat-08adf3e0a226779a7" \
  | jq '.NatGateways[] | {State, SubnetId, VpcId, Tags}'

aws cloudwatch get-metric-statistics \
  --namespace AWS/NatGateway \
  --metric-name BytesOutToDestination \
  --dimensions Name=NatGatewayId,Value=nat-08adf3e0a226779a7 \
  --start-time $(date -d '7 days ago' -u +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 86400 --statistics Sum \
  | jq '.Datapoints | sort_by(.Timestamp)[] | {Date: .Timestamp, BytesOut: .Sum}'
# → All zeros = NAT idle → safe to decommission

# 1c. Global Accelerator — confirm zero traffic
aws globalaccelerator list-accelerators --region us-east-1 | jq '.Accelerators[] | {Name, Arn, Status}'

# Get accelerator ARN then:
GA_ARN=$(aws globalaccelerator list-accelerators --region us-east-1 | jq -r '.Accelerators[0].AcceleratorArn')
aws cloudwatch get-metric-statistics \
  --namespace AWS/GlobalAccelerator \
  --metric-name ProcessedByteCount \
  --dimensions Name=Accelerator,Value=$(basename $GA_ARN) \
  --start-time $(date -d '7 days ago' -u +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 86400 --statistics Sum --region us-east-1 \
  | jq '.Datapoints | sort_by(.Timestamp)[] | {Date: .Timestamp, Bytes: .Sum}'
# → All zeros = GA carries zero traffic → safe to decommission

# 1d. ECS PropagateTags — critical for understanding untagged cost
aws ecs list-clusters | jq -r '.clusterArns[]' | while read carn; do
  aws ecs list-services --cluster "$carn" | jq -r '.serviceArns[]' | while read sarn; do
    aws ecs describe-services --cluster "$carn" --services "$sarn" \
      | jq --arg c "$(basename $carn)" '.services[] |
          {Cluster: $c, Service: .serviceName,
           PropagateTags: .propagateTags,
           TagCount: (.tags | length)}'
  done
done

# 1e. CloudTrail — check for data events (explains $79/month)
aws cloudtrail describe-trails | jq -r '.trailList[].TrailARN' | while read tarn; do
  tname=$(aws cloudtrail describe-trails | jq -r --arg a "$tarn" '.trailList[] | select(.TrailARN==$a) | .Name')
  aws cloudtrail get-event-selectors --trail-name "$tname" \
    | jq --arg n "$tname" '{Trail: $n, EventSelectors: .EventSelectors}'
done

# 1f. Confirm Amazon MQ broker is not in any CFN stack
aws cloudformation list-stack-resources --stack-name planodkupow-qa \
  | jq '.StackResourceSummaries[] | select(.ResourceType | contains("MQ"))'
# → Empty result = MQ is NOT in stack = orphan/manual creation confirmed

# 1g. Tag all CloudWatch log groups — audit first
aws logs describe-log-groups \
  | jq '.logGroups[] | {Name: .logGroupName, RetentionDays, StoredBytes}'
# Check for missing tags:
aws logs list-tags-log-group --log-group-name /ecs/planodkupow-qa 2>/dev/null \
  | jq 'to_entries | map({Key: .key, Value: .value})'
```

### Step 2 — Zero-risk tagging: UAT additive fix (highest FinOps impact)

```bash
# Add standard English keys to UAT resources WITHOUT removing Polish keys
# This is purely additive — no risk to running workloads

AWS_PROFILE=plan
AWS_REGION=eu-central-1

STANDARD_TAGS="Key=Environment,Value=uat Key=Owner,Value=DC-devops Key=ManagedBy,Value=cloudformation Key=CostCenter,Value=DC"

# UAT VPC and networking
aws ec2 create-tags \
  --resources vpc-0b91c465aa64ba545 \
  --tags $STANDARD_TAGS \
  --region $AWS_REGION --profile $AWS_PROFILE

# UAT subnets — get IDs first
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=vpc-0b91c465aa64ba545" \
  | jq -r '.Subnets[].SubnetId' | tr '\n' ' '
# Then: aws ec2 create-tags --resources <all subnet IDs> --tags $STANDARD_TAGS

# UAT RDS
aws rds add-tags-to-resource \
  --resource-name "arn:aws:rds:$AWS_REGION:333320664022:db:planodkupowuatdb" \
  --tags Key=Environment,Value=uat Key=Owner,Value=DC-devops Key=ManagedBy,Value=cloudformation Key=CostCenter,Value=DC \
  --region $AWS_REGION --profile $AWS_PROFILE

# CloudTrail trail — tag it
TRAIL_ARN=$(aws cloudtrail describe-trails | jq -r '.trailList[0].TrailARN')
aws cloudtrail add-tags --resource-id "$TRAIL_ARN" \
  --tags-list Key=Project,Value=planodkupow Key=Environment,Value=shared \
    Key=Owner,Value=DC-devops Key=ManagedBy,Value=cloudformation Key=CostCenter,Value=DC \
  --region $AWS_REGION --profile $AWS_PROFILE

# Global Accelerator — tag it
aws globalaccelerator tag-resource \
  --resource-arn "$GA_ARN" \
  --tags Key=Project,Value=planodkupow Key=Environment,Value=qa \
    Key=Owner,Value=DC-devops Key=ManagedBy,Value=cloudformation Key=CostCenter,Value=DC \
  --region us-east-1 --profile $AWS_PROFILE
```

### Step 3 — Idle resource decommission (after metrics confirm idle)

**Prerequisites before any delete:** NAT BytesOut = 0 for 7 days AND GA ProcessedByteCount = 0 for 7 days.

```bash
# Sequence — do NOT skip steps
# 3a. Remove GA endpoint groups (releases ENIs from old VPC)
# 3b. Delete GA accelerator
# 3c. Delete old QA VPC endpoints (vpce-0f06338f894336448 etc.)
# 3d. Delete NAT Gateway nat-08adf3e0a226779a7
# 3e. Release EIP eipalloc-03f5ee498546ec65c (3.76.77.101) — only after NAT delete
# 3f. Detach + Delete IGW igw-0862c2814f8c0265b from old QA VPC
# 3g. Delete old QA VPC subnets
# 3h. Delete old QA VPC vpc-02f804baee8a3f048
#
# NOTE: This is NOT a read-only step. Confirm GO/NO-GO from metrics before executing.
```

### Step 4 — Optional: CloudFormation ownership mapping

Only after live resource + billing data is understood:

```bash
# Which stacks own which resources?
aws cloudformation list-stacks \
  --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE UPDATE_ROLLBACK_COMPLETE \
  | jq '.StackSummaries[] | {Name: .StackName, Status: .StackStatus, Created: .CreationTime}'

# Find the MQ broker's true CFN parent (or confirm it's manual)
aws cloudformation list-stack-resources --stack-name planodkupow-qa \
  | jq '.StackResourceSummaries[] | {LogicalId, PhysicalId: .PhysicalResourceId, Type: .ResourceType}'
```

---

## APPENDIX: Service-by-Service Findings Table

| Service | Monthly cost | Tag compliance | Orphan risk | Key finding |
|---------|-------------|---------------|------------|-------------|
| ECS | ~$324 | PARTIAL — depends on PropagateTags | LOW (active) | Task ENI propagation unverified; UAT uses wrong tag schema |
| VPC | ~$162 | PARTIAL | HIGH (old QA residual) | ~$40-75 in idle NAT + endpoints + GA ENIs; two VPCs same name |
| CloudTrail | ~$79 | UNTAGGED | LOW (active) | $79/month is elevated — verify S3 data events; trail likely untagged |
| MQ | ~$71 | UNKNOWN | HIGH (QA MQ not in CFN) | QA broker orphan suspect; UAT wrong tag schema |
| RDS | ~$64 | PARTIAL | LOW | QA compliant; UAT wrong tag schema |
| CloudWatch | ~$40 | LIKELY ZERO | LOW (active) | Log groups historically untagged; $40 includes log storage |
| ElastiCache | ~$39 | PARTIAL | LOW | QA compliant; UAT wrong tag schema |
| ELB | ~$31 | PARTIAL | LOW | QA ALB compliant; UAT ALBs wrong tag schema |
| EC2-Other | ~$30 | PARTIAL | MEDIUM | EIPs, data transfer, ENIs — mixed tag state |
| Global Accelerator | ~$14 | LIKELY UNTAGGED | HIGH | Health Unknown; $14/month for zero apparent traffic |

---

## Cross-References

- [[planodkupow-orphan-network-investigation-2026-04-24]] — VPC/NAT forensics
- [[planodkupow-qa-tagging-audit-2026-04-25]] — QA VPC tagging audit detail
- [[planodkupow-tagging-finops]] — Phase 1 tag schema decisions
- [[planodkupow-qa-network-forensic-audit]] — CloudTrail timeline, GA analysis
- [[40-runbooks/incidents/planodkupow-qa-tagging-audit.sh]] — QA audit script
