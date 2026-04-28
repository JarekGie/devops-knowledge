# Prompt 04 — Model Tiering For Vault

## Purpose

Use this prompt to calibrate Tier S / Tier M / Tier P for a specific vault, team, or agent workflow.

## Prompt

```text
You are a senior LLMOps / AI FinOps architect calibrating model tier policy for an existing vault.

Task:
Create a vault-specific model tiering matrix.

Goal:
Map recurring task classes to:
- Tier S: low-cost/default
- Tier M: standard reasoning
- Tier P: premium reasoning

Rules:
- Start from the vault's actual work patterns.
- Do not assume all AWS/Terraform tasks require premium reasoning.
- Do not route premium-by-default.
- Include escalation and de-escalation rules.
- Respect data classification and domain isolation rules before cost optimization.

Discovery:
1. Inspect active context and project categories.
2. Inspect runbooks, standards, context packs, and agent contracts.
3. Identify recurring task classes.
4. Identify high-risk work where wrong output is expensive.
5. Identify routine work that can stay on low-cost/default models.

Build a tiering matrix:

| Task class | Examples | Default tier | Escalate when | De-escalate when | Evidence required |

Required task categories:
- markdown / note cleanup
- context pack creation
- context pack slimming
- routine refactoring
- IaC review
- CloudFormation / Terraform failure diagnosis
- RCA synthesis
- architecture design
- threat modeling
- long-context analysis
- cross-vault contract audit
- client confidential work

Escalation policy:
- Tier S -> Tier M when task needs real synthesis, validation, or medium-risk reasoning.
- Tier M -> Tier P when unresolved ambiguity, contradiction, long context, or high blast radius remains.
- Do not escalate when confidence is high and evidence is direct.

Output format:

1. Vault Workload Summary
2. Tiering Matrix
3. Escalation Rules
4. De-escalation Rules
5. Data Boundary Overrides
6. Suggested Updates To Existing Cost-Aware Contract
7. Open Questions

Constraints:
- Do not edit files unless explicitly asked.
- Keep recommendations additive.
- Do not weaken data-governance contracts for cost reasons.
```

## Notes

Use this after Prompt 02 if the vault has many specialized workflows.
