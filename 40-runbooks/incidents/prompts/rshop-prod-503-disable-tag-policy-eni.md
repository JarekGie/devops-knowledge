You are an AWS platform engineer.

Goal:
Temporarily disable Tag Policy enforcement ONLY for EC2 network interfaces
in order to unblock ECS Fargate task startup (TagPolicyViolation),
WITHOUT removing the entire policy and WITHOUT impacting other resource types.

Context:
- Account: 943111679945 (rshop prod)
- Region: eu-central-1
- Issue: ECS tasks fail with TagPolicyViolation on ec2:network-interface
- Root cause: Tag Policy requires Environment + Project tags on ENI
- We want TEMPORARY bypass, no redeploy, minimal blast radius

---

STEP 1 — READ-ONLY

1. List attached tag policies:
aws organizations list-policies --filter TAG_POLICY

2. For each policy:
aws organizations describe-policy --policy-id <POLICY_ID>

3. Identify:
- Which policy enforces tags on:
  "ec2:network-interface"
- Check "enforced_for"

---

STEP 2 — ANALYSIS

Determine:
- Exact JSON path where enforcement is defined
- Whether enforcement is global or scoped
- Whether multiple policies affect ENI

---

STEP 3 — SAFE MODIFICATION PLAN

Prepare a minimal patch:
- Remove ONLY:
  "ec2:network-interface" from "enforced_for"
- Keep:
  - tag definitions
  - other resources untouched

DO NOT:
- delete policy
- remove required tags
- broaden scope

---

STEP 4 — APPLY (CONTROLLED)

Generate exact CLI:

aws organizations update-policy \
  --policy-id <POLICY_ID> \
  --content file://patched-policy.json

---

STEP 5 — VALIDATION

After change:
- wait 2–5 minutes
- verify ECS tasks start automatically
- check:
  aws ecs describe-services
  aws ecs list-tasks

---

STEP 6 — ROLLBACK PLAN (MANDATORY)

Prepare command to restore original policy JSON:
aws organizations update-policy \
  --policy-id <POLICY_ID> \
  --content file://original-policy.json

---

IMPORTANT RULES

- DO NOT modify SCPs
- DO NOT remove tag requirements globally
- DO NOT change unrelated services
- Output MUST include:
  1. Original policy snippet
  2. Patched version
  3. Exact CLI commands
  4. Rollback command

Be precise. No assumptions.
