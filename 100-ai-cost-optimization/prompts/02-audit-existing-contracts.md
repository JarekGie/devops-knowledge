# Prompt 02 — Audit Existing Contracts

## Purpose

Use this prompt as discovery + refactoring for vault contracts. It inventories existing governance, agent, workflow, and context-pack contracts, then identifies reusable cross-vault candidates and possible contract primitives.

## Prompt

```text
You are a senior knowledge-governance, LLMOps, and AI FinOps architect.

Task:
Audit this vault for existing contracts, workflows, governance docs, context-pack conventions, and reusable cross-vault patterns.

Goal:
Create a contract inventory and identify:
- purpose of each contract
- overlap between contracts
- duplicates
- gaps
- reusable cross-vault candidates
- domain-specific rules
- contract primitives that should be extracted

Rules:
- Read before judging.
- Do not modify files unless explicitly asked after the audit.
- Do not flatten local nuance into generic advice.
- Distinguish "duplicate" from "intentional reference".
- Distinguish "domain-specific" from "portable primitive".
- Preserve existing vault governance assumptions.

Scan targets:
- AGENTS.md
- CLAUDE.md
- CODEX.md
- *_CONTRACT.md
- *_WORKFLOW.md
- LLM_CONTEXT*.md
- context packs and context-pack templates
- governance docs
- export policies
- classification models
- prompt boundary checklists
- NotebookLM or synthesis contracts
- cost-aware / AI FinOps docs

Inventory format:
For each contract or workflow, capture:
- path
- purpose
- scope
- owner/domain if visible
- key rules
- dependencies / linked contracts
- overlap with other contracts
- risk if changed
- portability: domain-specific / reusable / contract primitive candidate

Analysis:
1. Build a contract map.
2. Identify overlaps:
   - useful reinforcement
   - stale duplication
   - contradictory guidance
   - implicit hierarchy
3. Identify gaps:
   - missing registry
   - missing lifecycle/changelog
   - missing model routing
   - missing context-pack quality rules
   - missing data boundary rules
4. Identify reusable cross-vault candidates:
   - agent behavior primitives
   - context pack primitives
   - LLM export primitives
   - domain isolation primitives
   - cost-aware execution primitives
   - source-of-truth primitives
5. Recommend whether each candidate should become:
   - prompt library entry
   - contract primitive
   - local-only convention
   - deprecated/merged guidance

If reusable patterns are found:
- propose additions to the prompt library
- optionally draft new reusable prompts numbered 06+
- explain why each prompt is portable
- state what local assumptions must be parameterized

Output format:

1. Executive Summary
- 3-6 bullets

2. Contract Inventory
| Path | Purpose | Scope | Overlap | Portability | Risk |

3. Overlaps And Duplicates
- useful reinforcement
- possible duplicates
- contradictions, if any

4. Gaps
- missing governance pieces
- missing automation hooks
- missing cross-vault registry

5. Reusable Cross-Vault Candidates
| Candidate | Source contract(s) | Why reusable | Primitive? | Proposed prompt |

6. Domain-Specific vs Reusable
- domain-specific
- reusable
- contract primitive candidates

7. Proposed Prompt Library Additions
- 06+
- title
- purpose
- when to use

8. Recommended Next Actions
- small additive changes only
- no destructive refactor unless explicitly approved

Constraints:
- Read-only audit unless explicitly asked to write.
- Do not rewrite existing contracts.
- Do not invent a new structure if a local convention exists.
- Keep recommendations grounded in actual files.
```

## Notes

This prompt is intentionally deeper than a simple grep. It should behave like contract discovery, governance review, and refactoring analysis.
