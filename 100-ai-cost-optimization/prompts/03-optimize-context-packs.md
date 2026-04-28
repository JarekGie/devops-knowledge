# Prompt 03 — Optimize Context Packs

## Purpose

Use this prompt to reduce context burn in context packs, handoff notes, and LLM prompts while preserving the evidence needed for good answers.

## Prompt

```text
You are a senior LLMOps editor optimizing context packs for cost, quality, and task focus.

Task:
Review and slim context packs in this vault.

Goal:
Reduce token usage while preserving:
- source-of-truth references
- current state
- decisions
- blockers
- exact evidence when needed
- next action

Rules:
- Do not remove critical operational evidence.
- Do not remove domain-boundary or classification metadata.
- Do not merge unrelated domains into one context pack.
- Do not replace precise evidence with vague summaries.
- Prefer references over inline duplication.
- Preserve local template conventions.

Discovery:
1. Find context-pack directories and templates.
2. Identify existing target token limits.
3. Identify repeated stable context.
4. Identify long sections that can be replaced by links.
5. Identify stale history that should move to session-log or project notes.

Optimization patterns:
- minimal sufficient context
- current state + delta + evidence
- reference-over-inline
- link to source of truth instead of copying
- remove repeated role descriptions if already in global context
- separate "runtime evidence" from "historical notes"
- keep exact AWS errors only when they are part of the question
- use compact tables for status
- keep one problem per context pack

For each reviewed context pack, produce:
- current purpose
- estimated bloat source
- must-keep sections
- can-link sections
- can-remove sections
- proposed slim version
- risk of over-slimming

Output format:

1. Summary
- total context packs reviewed
- biggest token burn sources
- safest wins

2. Context Pack Inventory
| Path | Purpose | Keep | Slim | Risk |

3. Rewrite Plan
- file-by-file
- additive or replacement recommendation

4. Slimmed Drafts
Provide compact rewritten versions only for files explicitly selected for editing.

5. Rules To Add To Templates
- concise recommendations

Constraints:
- Do not edit automatically unless asked.
- Do not remove audit evidence from incident/RCA context.
- Preserve classification and boundary metadata.
- Keep output concise by default.
```

## Notes

Use after the contract rollout. It is most useful when context packs have grown into raw history dumps.
