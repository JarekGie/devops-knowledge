---
date: 2026-04-25
project: planodkupow
client: mako
environment: qa
vpc: vpc-007d115c41f079bf3
tags: [planodkupow, aws, tagging, finops, compliance, audit, qa]
domain: client-work/mako
status: evidence-framework — requires fresh CLI run to produce final numbers
---

# PlanOdkupow QA — Tagging Compliance Audit

**Scope:** `vpc-007d115c41f079bf3` (new QA VPC) ONLY  
**Account:** 333320664022 | **Region:** eu-central-1 | **Profile:** `plan`  
**CF root stack:** `planodkupow-qa` → nested `planodkupow-qa-VPCStack-1V91EF1UIC85A`

> Run the companion script to produce live evidence:
> ```bash
> bash 40-runbooks/incidents/planodkupow-qa-tagging-audit.sh 2>&1 | tee /tmp/planodkupow-qa-audit-$(date +%Y-%m-%d).txt
> ```

---

## A. Executive Summary (pre-populated from prior evidence)

Prior evidence sources: Phase 1 audit 2026-04-21, orphan network investigation 2026-04-24.

| Metric | From Prior Evidence | Requires Verification |
|--------|--------------------|-----------------------|
| Tag schema in use | `Project=planodkupow`, `Environment=qa`, `Owner=DC-devops`, `ManagedBy=cloudformation`, `CostCenter=DC` | fresh run |
| Confirmed compliant resources | VPC, RDS, ALB, TG×3, Redis, ECS cluster | confirm tag drift |
| VPC Endpoints in scope | **ZERO** — all 4 standard endpoints are in OLD VPC (out of scope) | confirmed |
| NAT Gateway in scope | **NONE** — new QA VPC is public-subnet + IGW architecture | confirmed |
| Highest-risk resource | Amazon MQ broker (not visible in root CFN stack) | fresh run |
| Known value drift | `Project=planodkupow` ≠ audit contract value `PlanOdkupow` | **see note below** |
| Propagation risk | ECS task ENIs, CloudWatch Log Groups | fresh run |

### Critical pre-finding: Project tag value normalization

The audit contract specifies `Project = PlanOdkupow` (PascalCase).
The live environment uses `Project = planodkupow` (lowercase).

**This is an existing, consistent schema decision** — not accidental drift.
Before classifying as MAJOR drift, confirm with team: is `PlanOdkupow` the canonical value going forward,
or is `planodkupow` accepted? The AWS Tagging Standard in this vault lists kebab-case as the format,
which would make `planodkupow` correct and `PlanOdkupow` the error.

**Recommendation:** Normalize the audit contract to match the live schema (`planodkupow`) unless
a formal rename decision has been made. The script uses case-insensitive match and accepts `planodkupow`.

---

## B. Resource-by-Resource Findings (known state from prior evidence)

_Legend: ✓ = confirmed compliant | ? = unverified | ⚠ = known gap | N/A = not applicable_

### B1. Networking

| ResourceId | ResourceType | Status | Evidence Source | Notes |
|-----------|-------------|--------|----------------|-------|
| vpc-007d115c41f079bf3 | VPC | ✓ | Phase 1 audit 2026-04-21 | Full tag set present |
| subnets (public×N) | Subnet | ? | Not audited in Phase 1 | CFN-managed, likely inherited |
| route tables | RouteTable | ? | Not audited in Phase 1 | CFN-managed, likely inherited |
| igw-* | InternetGateway | ? | Not audited in Phase 1 | Only IGW in new VPC |
| — | NatGateway | N/A | Confirmed: no NAT in new QA VPC | Architecture: public subnet + IGW |
| — | VpcEndpoint | N/A | Confirmed: all 4 standard endpoints in OLD VPC | Old VPC = out of scope |
| nacl-* | NetworkAcl | ? | Not audited | Likely default NACL |
| sg-* | SecurityGroup | ? | Not audited in Phase 1 | CFN-managed stack expected |
| eni-* (workload) | ENI | ? | Not audited directly | ECS task + data ENIs; propagation risk |

### B2. Load Balancing

| ResourceId | ResourceType | Status | Evidence Source | Notes |
|-----------|-------------|--------|----------------|-------|
| planodkupow-qa-ALB | ALB | ✓ | Phase 1 audit 2026-04-21 | Full tag set present |
| TG×3 (QA) | TargetGroup | ✓ | Phase 1 audit 2026-04-21 | Full tag set present |
| ALB Listener Rules | ListenerRule | N/A | Non-taggable by AWS design | Rules share ALB tags |

### B3. Compute

| ResourceId | ResourceType | Status | Evidence Source | Notes |
|-----------|-------------|--------|----------------|-------|
| planodkupow-qa-Klaster | ECSCluster | ✓ | Phase 1 audit 2026-04-21 | Full tag set present |
| ECS Services (all QA) | ECSService | ? | Not verified per-service | CFN-managed; PropagateTags setting critical |
| ECS task ENIs | ENI | ? | Not verified | Tag propagation depends on PropagateTags=SERVICE |

### B4. Data

| ResourceId | ResourceType | Status | Evidence Source | Notes |
|-----------|-------------|--------|----------------|-------|
| planodkupowqadb | RDSInstance | ✓ | Phase 1 audit 2026-04-21 | Full tag set present |
| planodkupow-qa-redisinst | ElastiCache | ✓ | Phase 1 audit 2026-04-21 | Full tag set present |
| planodkupow-qa-rabbitmq-cheap | AmazonMQ | ⚠ | Orphan investigation 2026-04-24 | **NOT visible as nested resource in active root stack** — manual creation suspected |

### B5. Observability

| ResourceId | ResourceType | Status | Evidence Source | Notes |
|-----------|-------------|--------|----------------|-------|
| /ecs/* log groups | LogGroup | ? | Never audited | Historical gap — CloudWatch Log Groups systematically skipped |
| CloudWatch Alarms | CWAlarm | ? | Never audited | No prior evidence |

---

## C. Coverage by Resource Class (estimated from prior evidence)

| Resource Class | Confirmed Compliant | Unverified | Known Gap | N/A | Est. Coverage |
|---------------|--------------------|-----------|---------|----|--------------|
| VPC | 1/1 | 0 | 0 | 0 | 100% (1 resource) |
| Subnets | 0 | ? | 0 | 0 | Unknown |
| Route Tables | 0 | ? | 0 | 0 | Unknown |
| Internet Gateway | 0 | 1 | 0 | 0 | Unknown |
| NAT Gateway | — | — | — | N/A | N/A (none in scope) |
| VPC Endpoints | — | — | — | N/A | N/A (none in new VPC) |
| NACLs | 0 | ? | 0 | 0 | Unknown |
| Security Groups | 0 | ? | 0 | 0 | Unknown |
| ENIs (workload) | 0 | ? | 0 | 0 | Unknown |
| ALB | 1/1 | 0 | 0 | 0 | 100% |
| Target Groups | 3/3 | 0 | 0 | 0 | 100% |
| ALB Listener Rules | — | — | — | N/A | Non-taggable |
| ECS Cluster | 1/1 | 0 | 0 | 0 | 100% |
| ECS Services | 0 | ? | 0 | 0 | Unknown |
| ECS Task ENIs | 0 | ? | 0 | 0 | Propagation-dependent |
| RDS | 1/1 | 0 | 0 | 0 | 100% |
| ElastiCache | 1/1 | 0 | 0 | 0 | 100% |
| Amazon MQ | 0 | 0 | 1 | 0 | **0% — orphan risk** |
| CloudWatch Log Groups | 0 | ? | 0 | 0 | Unknown (historical blind spot) |
| CloudWatch Alarms | 0 | ? | 0 | 0 | Unknown |

---

## D. Resources Requiring Remediation (known + suspected)

### D1. Confirmed gaps

| Resource | Gap | Severity | Action |
|---------|-----|---------|--------|
| Amazon MQ `planodkupow-qa-rabbitmq-cheap` | Not visible in root CFN stack — possible manual/orphan | MAJOR | Verify stack ownership; add missing tags via `mq create-tags`; confirm CFN adoption |
| CloudWatch Log Groups `/ecs/*` | Never audited; historically untagged across all projects | MAJOR (suspected) | Run audit script; apply `logs tag-log-group` for each missing |

### D2. Propagation risks (requires live verification)

| Flow | Risk | How to verify |
|------|------|--------------|
| ECS Cluster → ECS Service | `PropagateTags=SERVICE` may not be set | `aws ecs describe-services --cluster planodkupow-qa-Klaster --services <all>` → check `propagateTags` field |
| ECS Service → Task ENIs | PropagateTags must be `SERVICE` or `TASK_DEFINITION` | Check ENI tags on running tasks during integration window |
| ALB → Target Groups | Confirmed OK in Phase 1 | Re-verify with fresh run |
| VPC → Subnets/RT | CFN-managed — likely propagated in stack | Verify with fresh describe |

### D3. Suspected issues (verify with live run)

- **Security Groups**: CFN manages them but SGs created before tag schema update may be missing newer keys
- **Default NACL**: AWS auto-creates default NACL; tagging it is possible but often missed
- **ENIs from ALB**: ALB creates ENIs in subnets — these are AWS-managed and non-taggable directly

---

## E. Remediation Recommendations

### E1. Immediate — no change-set risk

These are safe direct API tag operations (do not trigger CFN replacements):

```bash
PROFILE=plan
REGION=eu-central-1
REQUIRED_TAGS="Key=Project,Value=planodkupow Key=Environment,Value=qa Key=Owner,Value=DC-devops Key=ManagedBy,Value=cloudformation Key=CostCenter,Value=DC"

# CloudWatch Log Groups — list first, then apply
aws logs describe-log-groups --log-group-name-prefix "/ecs/" \
  --profile $PROFILE --region $REGION \
  | jq -r '.logGroups[].logGroupName' | while read lg; do
    aws logs tag-log-group --log-group-name "$lg" \
      --tags Project=planodkupow,Environment=qa,Owner=DC-devops,ManagedBy=cloudformation,CostCenter=DC \
      --profile $PROFILE --region $REGION
  done

# Amazon MQ broker — after confirming ownership
aws mq create-tags \
  --resource-arn "arn:aws:mq:${REGION}:333320664022:broker:planodkupow-qa-rabbitmq-cheap" \
  --tags Project=planodkupow,Environment=qa,Owner=DC-devops,ManagedBy=cloudformation,CostCenter=DC \
  --profile $PROFILE --region $REGION

# Security Groups / Subnets / Route Tables / IGW — after audit run confirms gaps
# aws ec2 create-tags --resources <id> --tags $REQUIRED_TAGS --profile $PROFILE --region $REGION
```

### E2. CloudFormation template fixes

Apply to `planodkupow-qa-VPCStack-1V91EF1UIC85A` template:

1. **ECS Services** — ensure all service definitions have:
   ```yaml
   PropagateTags: SERVICE  # critical for task ENI tag propagation
   Tags:
     - Key: Project
       Value: !Ref Project
     - Key: Environment
       Value: !Ref Environment
     - Key: Owner
       Value: !Ref Owner
     - Key: ManagedBy
       Value: cloudformation
     - Key: CostCenter
       Value: !Ref CostCenter
   ```

2. **CloudWatch Log Groups** — add explicit tag blocks if managed in CFN:
   ```yaml
   Type: AWS::Logs::LogGroup
   Properties:
     Tags:
       - Key: Project
         Value: !Ref Project
       # ... full tag set
   ```
   Note: CFN `AWS::Logs::LogGroup` does not always propagate tags; direct API tagging is more reliable (E1 above).

3. **Amazon MQ** — if adopting into CFN:
   - Import existing broker or create new with `DeletionPolicy: Retain`
   - Add tag block to `AWS::AmazonMQ::Broker` resource

### E3. Propagation model improvements

| Issue | Current | Target |
|-------|---------|--------|
| ECS task ENI propagation | Unknown — depends on `PropagateTags` | Set `PropagateTags: SERVICE` on ALL ECS service definitions |
| Log group tag coverage | No systematic approach | Add all log groups to `/ecs/planodkupow-qa-*` naming convention + apply tags on create |
| MQ broker IaC ownership | Suspected manual | Adopt into CFN stack or document as `ManagedBy: manual` explicitly |
| Default NACL | AWS-managed | Tag directly via API; accept it may be overwritten by AWS |

---

## F. Non-Taggable Resources (by AWS design)

| Resource | Reason |
|---------|--------|
| ALB Listener Rules | Rules share tags with their Listener; `describe-rules` returns no separate tag API |
| VPC Route Table entries | Individual routes are not AWS resources; only the Route Table itself |
| NACL individual rules | Individual rule entries are not resources; only NACL is |
| Security Group inbound/outbound rules | Same as NACL rules — not separately taggable |
| ECS Task ENIs (ALB-managed) | ENIs created by ALB for routing are AWS-managed; non-taggable |
| VPC default DHCP options set | AWS-managed; tagging not supported |

---

## G. GO/NO-GO for SCP Tag Enforcement

Criteria for enabling tag-enforcing SCPs on this environment:

| Check | Status | Required Before SCP |
|-------|--------|---------------------|
| VPC, RDS, ALB, TG, Redis, ECS cluster tagged | ✓ confirmed | ✓ |
| All ECS Services tagged + PropagateTags=SERVICE | ? unknown | **YES — verify first** |
| Amazon MQ broker tagged | ⚠ gap | **YES — patch before SCP** |
| CloudWatch Log Groups tagged | ? unknown (likely NO) | **YES — patch before SCP** |
| Security Groups gap assessed | ? unknown | YES |
| Subnets / RT / IGW gap assessed | ? unknown | YES |
| ECS task ENIs inherit tags | ? unknown | YES (must verify during night window) |

**Current GO/NO-GO status: NO-GO** — MQ broker gap + log groups gap + unverified propagation.

---

## Cross-References

- [[planodkupow-orphan-network-investigation-2026-04-24]] — old VPC / NAT / endpoint forensics
- [[planodkupow-tagging-finops]] — Phase 1 audit results, tag schema decisions
- [[planodkupow-qa-network-forensic-audit]] — GA / traffic path investigation
- [[40-runbooks/incidents/planodkupow-qa-tagging-audit.sh]] — runnable evidence-collection script
- [[aws-tagging-standard]] — org-wide tag contract
