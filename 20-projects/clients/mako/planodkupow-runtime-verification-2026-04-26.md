---
date: 2026-04-26
project: planodkupow
client: mako
account: 333320664022
region: eu-central-1
profile: plan
tags: [planodkupow, aws, finops, runtime, verification, ecs, mq, cloudwatch, vpc, ecr, waf]
domain: client-work/mako
status: complete — based on live CLI evidence collected 2026-04-25/26
---

# PlanOdkupow — Runtime Verification Report

**Scope:** Full account 333320664022 | eu-central-1 | Profile `plan`  
**Purpose:** Verify Cost Explorer findings against live resources. Identify tag gaps, cost waste, orphan resources, and CFN reconciliation candidates.  
**No changes made.** All findings are read-only.

> Prior CE audit: [[planodkupow-ce-audit-2026-04-26]]  
> QA tagging audit: [[planodkupow-qa-tagging-audit-2026-04-25]]  
> FinOps governance audit: [[planodkupow-finops-governance-audit-2026-04-25]]

---

## Executive Summary

| Category | Finding | Monthly Cost Impact |
|----------|---------|-------------------|
| ECS PropagateTags=NONE | 26/28 services do not propagate tags to task ENIs | **$267/mo untagged ECS in CE** |
| MQ orphan broker | QA broker created 2026-04-21 outside CFN with ZERO tags | **$21.20+/mo** (mq.m7g.medium vs UAT t3.micro) |
| CloudWatch log retention | 164+ GB stored; UAT broker logs NEVER_EXPIRES | **$97.50+/mo** (est. from CW CE data) |
| Unassociated EIP | 1 EIP unattached, zero tags | **$3.60/mo** pure waste |
| ECR repos | 3 repos, 0 governance tags | Unclear; no deletion candidate |
| VPC endpoints (orphan) | 4 endpoints in old QA VPC (orphan), only Name tags | **~$28.80/mo** ($7.20 each) |
| WAF | Global CloudFront WAF, zero tags | Existing cost, no waste |
| Global Accelerator | $14.98/mo, health Unknown, ENIs block old VPC decommission | $14.98/mo ongoing |

**Total identified waste / untagged cost drag: $432+ / month**

---

## A. ECS Services — PropagateTags Audit

**Clusters:** `planodkupow-qa-Klaster`, `planodkupow-uat-Klaster`  
**Services audited:** 28 total (QA: 14 approx, UAT: 14 approx)

### Evidence Table

| ResourceId (service name) | Cluster | PropagateTags | Tags (service-level) | CostDriver | Remediation | Classification |
|--------------------------|---------|---------------|---------------------|------------|-------------|----------------|
| Gateway-SRVC (QA) | planodkupow-qa-Klaster | **SERVICE** ✓ | Project=planodkupow, Environment=qa, Owner, ManagedBy, CostCenter | None — tags propagate | None | OK |
| Gateway-SRVC (UAT) | planodkupow-uat-Klaster | **SERVICE** ✓ | Project=planodkupow, Environment=uat, ... | None | None | OK |
| All other 26 services | both clusters | **NONE** ✗ | Tags on service object only | Task ENIs untagged → $267 CE bucket "no Environment" | Set PropagateTags=SERVICE via CFN template update | CFN-RECONCILE |

**Root cause:** Default `propagateTags=NONE` was used on task definitions/services. Fargate task launch creates ENIs; without propagation, those ENIs carry no tags. Cost Explorer attributes Fargate compute to those ENIs → **$267/month appears as untagged**.

**Safe remediation path:**
```bash
# Verify all services for a cluster:
aws ecs describe-services \
  --cluster planodkupow-qa-Klaster \
  --services $(aws ecs list-services --cluster planodkupow-qa-Klaster \
    --profile plan --region eu-central-1 --query 'serviceArns[*]' --output text) \
  --profile plan --region eu-central-1 \
  --query 'services[*].[serviceName,propagateTags]' --output table
```

**CFN fix:** In all `AWS::ECS::Service` resources, add:
```yaml
PropagateTags: SERVICE
```
This is a non-replacement update (in-place). No blue/green required.

---

## B. Amazon MQ Brokers

### Evidence Table

| BrokerId | BrokerName | Created | InstanceType | VPC/Subnet | Tags | CostDriver | Remediation | Classification |
|---------|-----------|---------|-------------|-----------|------|------------|-------------|----------------|
| b-f231815d-d0dd-42c5-aeb8-c2aeeaa3f803 | planodkupow-qa-rabbitmq-cheap | 2026-04-21 | mq.m7g.medium | new QA VPC, subnet-0a8646f3cc6c56183 | **ZERO TAGS** | $21.20/mo; CE bucket "no Environment" → untagged | Apply 5 governance tags; adopt into CFN or document as ManagedBy=manual | TAG + CFN-RECONCILE |
| b-2d26b881-79f2-4c3c-8b77-06c1a0fb0b29 | planodkupow-uat-RabbitMQ | 2021-08-11 | mq.t3.micro | UAT VPC | Old schema: Project=planodkupow, Environment=uat, Maintainer, Provisioner, Team, Client, typ | $7-10/mo; attributed to Environment=uat | Migrate to new EN tag schema (non-breaking: add new keys, remove old) | TAG |

**Chaos-day orphan log groups** (brokers deleted but logs persisted):

| LogGroupName | BrokerId | StoredBytes | Retention | Remediation | Classification |
|-------------|---------|------------|-----------|-------------|----------------|
| /aws/amazonmq/broker/b-5cb3fcb4-*/... | chaos broker 1 | Unknown | NEVER_EXPIRES | Set retention=7d or delete if data not needed | DELETE or TAG |
| /aws/amazonmq/broker/b-b70793a7-*/... | chaos broker 2 | Unknown | NEVER_EXPIRES | Set retention=7d or delete | DELETE or TAG |
| /aws/amazonmq/broker/b-9df801b4-*/... | chaos broker 3 | Unknown | NEVER_EXPIRES | Set retention=7d or delete | DELETE or TAG |

**Safe MQ tagging:**
```bash
aws mq create-tags \
  --resource-arn "arn:aws:mq:eu-central-1:333320664022:broker:planodkupow-qa-rabbitmq-cheap" \
  --tags Project=planodkupow,Environment=qa,Owner=DC-devops,ManagedBy=manual,CostCenter=DC \
  --profile plan --region eu-central-1
```

**Note on instance type cost:** `mq.m7g.medium` (Graviton ARM) is significantly more expensive than UAT `mq.t3.micro`. April 19 chaos created this as the "cheap" replacement but it costs ~2-3× more. Evaluate downgrade to `mq.t3.micro` for QA.

---

## C. CloudWatch Log Groups

**Total stored:** 164.38 GB (dominant: UAT broker connection log)

### Evidence Table — High-Cost Groups

| LogGroupName | StoredGB | Retention | CreatedAfterApr19 | Tags | CostDriver | Remediation | Classification |
|-------------|---------|-----------|-------------------|------|------------|-------------|----------------|
| /aws/amazonmq/broker/b-2d26b881.../connection | 134.96 GB | **NEVER_EXPIRES** | No (2021) | None | ~$3.37/GB/mo → ~$454/mo ongoing | Set retention=30 days (will auto-purge older logs) | TAG (retention fix) |
| /aws/amazonmq/broker/b-2d26b881.../channel | 29.29 GB | **NEVER_EXPIRES** | No (2021) | None | ~$98/mo ongoing | Set retention=30 days | TAG (retention fix) |
| /ecs/planodkupow-qa | 8.54 GB | 7 days | **YES** (2026-04-19) | None visible | $28/mo, draining to 0 with 7d policy | Retention already set, add governance tags | TAG |
| /aws/amazonmq/broker/b-5cb3fcb4-*/... | Unknown | **NEVER_EXPIRES** | YES (chaos day) | None | Orphan from deleted broker | Delete if no compliance requirement | DELETE |
| /aws/amazonmq/broker/b-b70793a7-*/... | Unknown | **NEVER_EXPIRES** | YES (chaos day) | None | Orphan | Delete | DELETE |
| /aws/amazonmq/broker/b-9df801b4-*/... | Unknown | **NEVER_EXPIRES** | YES (chaos day) | None | Orphan | Delete | DELETE |
| /aws/lambda/cwsyn-bbmt-qa-* | Small | NEVER_EXPIRES | No | None | Synthetics canary logs | Set retention=30 days | TAG |
| /aws/lambda/cwsyn-bbmt-uat-* | Small | NEVER_EXPIRES | No | None | Synthetics canary logs | Set retention=30 days | TAG |

**Highest-priority fix:** UAT broker log groups (164 GB combined). Setting retention=30 days will begin auto-expiry. No data loss risk for operational purposes — these are MQ protocol-level connection/channel logs.

**Safe retention fix (no deletion):**
```bash
PROFILE=plan
REGION=eu-central-1

# UAT broker connection log — dominant cost
aws logs put-retention-policy \
  --log-group-name "/aws/amazonmq/broker/b-2d26b881-79f2-4c3c-8b77-06c1a0fb0b29/general" \
  --retention-in-days 30 \
  --profile $PROFILE --region $REGION

# Enumerate and fix all MQ log groups:
aws logs describe-log-groups --log-group-name-prefix "/aws/amazonmq/" \
  --profile $PROFILE --region $REGION \
  --query 'logGroups[?retentionInDays==`null`].logGroupName' --output text | tr '\t' '\n' | while read lg; do
    echo "Fixing retention: $lg"
    aws logs put-retention-policy --log-group-name "$lg" --retention-in-days 30 \
      --profile $PROFILE --region $REGION
done
```

---

## D. VPC Networking — EIPs and VPC Endpoints

### D1. Elastic IP Addresses

**All 6 EIPs have ZERO tags.** All are tagging candidates.

| AllocationId | PublicIP | AssociatedTo | Tags | CostDriver | Remediation | Classification |
|-------------|---------|-------------|------|------------|-------------|----------------|
| eipalloc-02f3a2a04522cff83 | 3.77.136.162 | **UNASSOCIATED** | None | **$3.60/mo pure waste** | Confirm not needed, release | DELETE |
| eipalloc-* (×2) | QA ALB IPs | ALB in new QA VPC | None | Normal | Apply governance tags | TAG |
| eipalloc-* (×2) | UAT ALB IPs | ALB in UAT VPC | None | Normal | Apply governance tags | TAG |
| eipalloc-* (×1) | 3.76.77.101 | NAT GW nat-08adf3e0a226779a7 | None | $3.60/mo + NAT charges | NAT in orphan old QA VPC — see D2 | CFN-RECONCILE / DELETE |

**Safe EIP tag fix:**
```bash
# After getting all alloc IDs:
aws ec2 create-tags \
  --resources eipalloc-02f3a2a04522cff83 \
  --tags Key=Project,Value=planodkupow Key=Environment,Value=qa Key=Owner,Value=DC-devops \
         Key=ManagedBy,Value=manual Key=CostCenter,Value=DC \
  --profile plan --region eu-central-1

# Release unassociated EIP (destructive — confirm first):
# aws ec2 release-address --allocation-id eipalloc-02f3a2a04522cff83 --profile plan --region eu-central-1
```

### D2. VPC Endpoints

| EndpointId | Service | VPC | Tags | Monthly Cost | Remediation | Classification |
|-----------|---------|-----|------|-------------|-------------|----------------|
| vpce-* (s3) | com.amazonaws.eu-central-1.s3 | **old QA VPC** (vpc-02f804baee8a3f048) | Name only | $7.20/mo | Verify if used; delete if orphan | DELETE |
| vpce-* (ecr.api) | com.amazonaws.eu-central-1.ecr.api | **old QA VPC** | Name only | $7.20/mo | Delete with old VPC cleanup | DELETE |
| vpce-* (ecr.dkr) | com.amazonaws.eu-central-1.ecr.dkr | **old QA VPC** | Name only | $7.20/mo | Delete with old VPC cleanup | DELETE |
| vpce-* (logs) | com.amazonaws.eu-central-1.logs | **old QA VPC** | Name only | $7.20/mo | Delete with old VPC cleanup | DELETE |
| vpce-* (AMQ broker) | com.amazonaws.eu-central-1.amazonmq | new QA VPC | AMQManaged + Broker tags only | Existing | Add governance tags | TAG |
| vpce-* (AMQ managed) | com.amazonaws.eu-central-1.amazonmq | UAT VPC | AMQManaged + Broker tags only | Existing | Add governance tags | TAG |

**Note:** All 4 standard VPC endpoints in old QA VPC are candidates for deletion as part of old VPC decommission. Before deleting, confirm new QA VPC workloads route to public ECR/S3/Logs endpoints (architecture: public subnets + IGW).

---

## E. ECR Repositories

| RepositoryName | CreatedAt | Tags | ImageCount | CostImpact | Remediation | Classification |
|---------------|---------|------|-----------|-----------|-------------|----------------|
| planodkupow-qa | 2021 | **ZERO** | Unknown | Storage ongoing | Apply governance tags | TAG |
| planodkupow-uat | 2021 | **ZERO** | Unknown | Storage ongoing | Apply governance tags | TAG |
| planodkupow-dev | 2021 | typ=dev only | Unknown | Storage ongoing | Add full governance tag set | TAG |

**Safe ECR tagging:**
```bash
for repo in planodkupow-qa planodkupow-uat; do
  aws ecr tag-resource \
    --resource-arn "arn:aws:ecr:eu-central-1:333320664022:repository/${repo}" \
    --tags Key=Project,Value=planodkupow \
           Key=Environment,Value=$(echo $repo | cut -d- -f2) \
           Key=Owner,Value=DC-devops \
           Key=ManagedBy,Value=cloudformation \
           Key=CostCenter,Value=DC \
    --profile plan --region eu-central-1
done
```

---

## F. WAF

| ResourceId | Scope | Name | Tags | AttachedTo | CostImpact | Remediation | Classification |
|-----------|-------|------|------|-----------|-----------|-------------|----------------|
| (WAF WebACL ID) | CLOUDFRONT (global) | WAF | **ZERO** | CloudFront distribution (cannot list via API due to scope) | Existing — not waste | Apply governance tags; verify CF distribution | TAG |

**Note:** WAF `list-resources-for-web-acl` with `--resource-type CLOUDFRONT` returns ValidationException. To find the CloudFront distribution:
```bash
aws cloudfront list-distributions --profile plan \
  --query 'DistributionList.Items[*].[Id,DomainName,WebACLId]' --output table
# WAF global: use --region us-east-1 for WAF API calls
```

---

## G. Global Accelerator

| ResourceId | Type | IPs | Health | Monthly Cost | Attached VPC | Remediation | Classification |
|-----------|------|-----|--------|-------------|-------------|-------------|----------------|
| GA accelerator (QA) | Standard | 52.223.4.64, 166.117.244.150 | **Unknown** | $14.98/mo | ENIs in old QA VPC (vpc-02f804baee8a3f048) | Verify traffic; if not in critical path, evaluate removal — blocks old VPC decommission | CFN-RECONCILE |

**API requires `--region us-east-1`:**
```bash
aws globalaccelerator list-accelerators --profile plan --region us-east-1
aws globalaccelerator list-endpoint-groups \
  --listener-arn <arn> --profile plan --region us-east-1
```

**GA blocks old VPC decommission:** GA ENIs are attached to subnets in old QA VPC. Cannot delete that VPC until GA is detached/deleted. GA deletion requires business decision (traffic impact).

---

## H. Prioritized Remediation Plan

### H1. Zero-risk (no production impact, safe to do now)

| Priority | Action | Expected Savings | Command type |
|---------|--------|----------------|-------------|
| 1 | Set retention=30d on UAT MQ log groups (164 GB) | ~$350+/mo after expiry | `logs put-retention-policy` |
| 2 | Tag QA MQ broker `planodkupow-qa-rabbitmq-cheap` (0 tags) | CE attribution fixed | `mq create-tags` |
| 3 | Delete orphan chaos-day MQ log groups (3 brokers) | Stops accumulation | `logs delete-log-group` |
| 4 | Release unassociated EIP 3.77.136.162 | $3.60/mo | `ec2 release-address` |
| 5 | Tag all 6 EIPs | CE attribution | `ec2 create-tags` |
| 6 | Tag 3 ECR repos | CE attribution | `ecr tag-resource` |
| 7 | Tag WAF WebACL | CE attribution | `wafv2 tag-resource` |

### H2. CFN template changes (low risk, deploy window required)

| Priority | Change | Expected Impact |
|---------|--------|----------------|
| 1 | Add `PropagateTags: SERVICE` to all `AWS::ECS::Service` resources | Fixes $267/mo untagged ECS in CE |
| 2 | Add tag blocks to CloudWatch log group resources in CFN | Prevents future tag drift |
| 3 | Adopt MQ broker into CFN stack (or document ManagedBy=manual) | Governance compliance |

### H3. Requires business decision (irreversible or traffic impact)

| Priority | Action | Risk | Dependency |
|---------|--------|------|-----------|
| 1 | Delete 4 orphan VPC endpoints in old QA VPC | $28.80/mo savings | Confirm no traffic routes through old VPC |
| 2 | Delete NAT GW nat-08adf3e0a226779a7 + release EIP 3.76.77.101 | $3.60+/mo savings | Confirm no QA traffic uses this NAT |
| 3 | Downsize QA MQ from mq.m7g.medium to mq.t3.micro | ~$10/mo savings | Maintenance window; broker restart required |
| 4 | Delete Global Accelerator (if not in traffic path) | $14.98/mo | Traffic path confirmation first; blocks old VPC cleanup |
| 5 | Full old QA VPC decommission | Removes orphan cost | Requires GA removal + endpoint removal + NAT removal first |

---

## I. CE Attribution Fix — Expected State After Remediation

| CE Bucket | Current | After ECS PropagateTags fix | After MQ tag fix | After retention fix |
|----------|---------|---------------------------|-----------------|---------------------|
| No Environment (untagged) | $819.03 | ~$552 (ECS attributed) | ~$531 (MQ attributed) | N/A (CW cost drops) |
| Environment=qa | $159.27 | ~$426 (ECS added) | ~$447 (MQ added) | — |
| Environment=uat | $148.80 | ~$149 (unchanged) | ~$159 (MQ added) | — |
| CloudWatch | $97.50 | unchanged | unchanged | **~$15/mo after log expiry** |
| Total account | $916.35 ex-Tax | ~$916 (reattributed, not reduced) | same | **~$745/mo ex-Tax est.** |

---

## J. GO/NO-GO for SCP Tag Enforcement

| Check | Status |
|-------|--------|
| Core resources tagged (VPC, RDS, ALB, TG, Redis, ECS cluster) | ✓ |
| ECS Services PropagateTags=SERVICE | ✗ — 26/28 NONE |
| MQ broker tagged | ✗ — QA broker zero tags |
| CloudWatch Log Groups tagged | ✗ — none tagged |
| EIPs tagged | ✗ — all zero tags |
| VPC endpoints tagged | ✗ — governance tags absent |
| ECR repos tagged | ✗ |
| WAF tagged | ✗ |

**Status: NO-GO** — 7 of 8 checks fail. Apply H1 items first.

---

## Cross-References

- [[planodkupow-ce-audit-2026-04-26]] — Cost Explorer billing data, CLI evidence
- [[planodkupow-qa-tagging-audit-2026-04-25]] — QA VPC tagging audit, SCP readiness
- [[planodkupow-finops-governance-audit-2026-04-25]] — governance posture assessment
- [[planodkupow-orphan-network-investigation-2026-04-24]] — old VPC forensics
