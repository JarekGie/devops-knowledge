# AI Cost Optimization Prompt Library

## Purpose

Portable prompt library for rolling out and evolving AI Cost Optimization / AI FinOps lite across knowledge vaults.

The prompts help with:
- deploying cost-aware agent policies
- auditing existing contracts
- reducing context burn
- calibrating model tiering
- maintaining AI FinOps governance notes
- discovering reusable cross-vault contract primitives

This library is meant to travel between vaults. Each prompt should adapt to local structure instead of forcing a fixed taxonomy.

---

## Prompt Index

| Prompt | Type | Use When |
|--------|------|----------|
| `01-rollout-ai-cost-aware-contract.md` | bootstrap | You want to add cost-aware policy to a vault additively |
| `02-audit-existing-contracts.md` | audit | You need inventory, overlap, gaps, and reusable contract candidates |
| `03-optimize-context-packs.md` | optimization | Context packs are too long or duplicate stable context |
| `04-model-tiering-for-vault.md` | governance | You need vault-specific Tier S/M/P routing rules |
| `05-ai-finops-readiness-notes.md` | governance | You want to maintain operating-model notes and backlog |
| `06-cross-vault-contract-primitives.md` | audit/governance | You found local contracts that should become reusable primitives |
| `wdrozenie.md` | local/bootstrap | Original Polish rollout prompt used to create the first cost-aware contract |

---

## Recommended Rollout Order

1. `01-rollout-ai-cost-aware-contract.md`
   - add the base policy
   - integrate only with existing contract entry points
   - produce changelog

2. `02-audit-existing-contracts.md`
   - inventory current governance
   - find overlaps and gaps
   - identify reusable cross-vault candidates

3. `03-optimize-context-packs.md`
   - reduce prompt/context cost
   - keep evidence and source-of-truth links

4. `04-model-tiering-for-vault.md`
   - calibrate Tier S/M/P to real local workflows

5. `05-ai-finops-readiness-notes.md`
   - maintain hypotheses, metrics, operating-model backlog

6. `06-cross-vault-contract-primitives.md`
   - extract portable primitives after the audit confirms repeatable patterns

---

## Bootstrap vs Audit vs Governance

### Bootstrap

Use when a vault does not yet have cost-aware execution:
- `01-rollout-ai-cost-aware-contract.md`
- `wdrozenie.md`

### Audit

Use when the vault already has contracts and you need discovery/refactoring:
- `02-audit-existing-contracts.md`
- `06-cross-vault-contract-primitives.md`

### Optimization

Use when context packs or prompts are consuming too many tokens:
- `03-optimize-context-packs.md`

### Governance

Use when moving from one contract to an operating model:
- `04-model-tiering-for-vault.md`
- `05-ai-finops-readiness-notes.md`
- `06-cross-vault-contract-primitives.md`

---

## Portability Rules

When using these prompts in another vault:
- inspect first
- preserve local folder conventions
- do not create artificial structure
- do not overwrite working contracts
- keep changes additive unless explicitly asked
- parameterize local paths, domains, and model names
- prefer references over copying full policy text
- keep data-boundary contracts higher priority than cost optimization

---

## Existing Cross-Vault Candidates Found In This Vault

Useful patterns that may justify future reusable prompts or contract primitives:
- domain isolation and sensitivity boundaries
- LLM context boundary contracts
- LLM export policy
- prompt boundary checklist
- NotebookLM synthesis workflow
- origin/source-of-truth metadata
- cost-aware model tiering and escalation
- context pack slimming conventions
- contract inventory / registry workflow

Recommended future prompts if the library grows:
- `07-build-contract-registry.md`
- `08-llm-export-policy-rollout.md`
- `09-domain-isolation-rollout.md`
- `10-notebooklm-synthesis-contract-rollout.md`

---

## Future Registry Note

It is worth considering a future directory:

```text
_system/contracts/registry/
```

Use it only when there are enough reusable primitives to justify a registry. A minimal registry should track:
- primitive name
- source contract
- version
- scope
- required frontmatter
- integration points
- portability status
- changelog

Do not create the registry prematurely. Start with prompt-library discovery and primitive drafts first.
