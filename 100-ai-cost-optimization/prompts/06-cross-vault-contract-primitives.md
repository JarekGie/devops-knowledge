# Prompt 06 — Cross-Vault Contract Primitives

## Purpose

Use this prompt when an audit finds local contracts that could become reusable primitives across multiple vaults.

## Why This Prompt Exists

This vault already contains reusable contract patterns that are not only local:
- agent execution contract
- domain isolation contract
- LLM context boundary contract
- LLM export policy
- prompt boundary checklist
- NotebookLM synthesis contract
- origin metadata contract
- cost-aware execution policy

These can be extracted into portable primitives if local assumptions are parameterized.

## Prompt

```text
You are a senior cross-vault governance architect.

Task:
Extract reusable contract primitives from this vault without damaging local contracts.

Goal:
Identify which contract rules should become portable primitives for use across multiple vaults.

Rules:
- Read existing contracts first.
- Do not move or rename local files.
- Do not rewrite local contracts.
- Extract patterns as reusable drafts only.
- Preserve local examples separately from portable rules.
- Parameterize local assumptions.

Scan:
- *_CONTRACT.md
- *_WORKFLOW.md
- AGENTS.md
- CLAUDE.md
- CODEX.md
- LLM_CONTEXT*.md
- prompt/checklist docs
- context-pack templates
- export/governance docs

For each candidate primitive, capture:
- primitive name
- source files
- portable rule
- local assumptions to parameterize
- required metadata
- integration points
- anti-patterns
- migration risk

Primitive categories:
- agent behavior
- data boundary
- context packaging
- export policy
- synthesis workflow
- source-of-truth metadata
- cost-aware routing
- contract registry
- changelog discipline

Output format:

1. Candidate Primitive Inventory
| Primitive | Source files | Portable? | Local assumptions | Priority |

2. Primitive Drafts
For each selected primitive:
```markdown
# <Primitive Name>

## Purpose
## Scope
## Required Rules
## Optional Rules
## Integration Points
## Parameters
## Anti-Patterns
## Changelog
```

3. Proposed Prompt Library Additions
- numbered 07+
- purpose
- why portable

4. Registry Recommendation
- whether this vault needs `_system/contracts/registry/`
- minimal schema
- migration plan

Constraints:
- No destructive edits.
- No registry creation unless explicitly requested.
- Keep primitive drafts separate from local source-of-truth contracts.
```

## Notes

This prompt is a bridge between local governance and a future cross-vault contract registry.
