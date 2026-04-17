# devops-toolkit — Architektura

#toolkit #architecture

## Diagram

```
┌─────────────────────────────────────────────┐
│                  CLI Entry                   │
│         toolkit <komenda> [opcje]            │
└──────────────────┬──────────────────────────┘
                   │
         ┌─────────▼─────────┐
         │   Command Router   │
         │  (plugin loader)   │
         └──┬────────┬───────┘
            │        │
   ┌────────▼──┐  ┌──▼────────┐
   │  AWS      │  │  FinOps   │  ...
 You are working inside an existing local filesystem repository that is used as an Obsidian vault.

Your task is to redesign, extend, and normalize the vault into a practical DevOps knowledge system for a senior DevOps/SRE engineer.

Important: this vault already exists. You must inspect the current directory structure and current Markdown files first, then:
- preserve useful existing content
- update existing files where appropriate
- avoid destructive rewrites unless a file is clearly placeholder-quality or redundant
- merge and normalize content instead of blindly duplicating it
- create missing folders and files where needed
- improve the vault so it becomes immediately usable for real technical work

Do not treat this as a greenfield scaffold unless the current vault is nearly empty.

## Core behavioral constraints

This is not a generic note-taking vault and not a productivity-influencer setup.

The vault must be designed for:
- AWS / Terraform / CI/CD / Kubernetes / FinOps / incident response / architecture notes / standards / audit workflows / custom devops-toolkit work
- interruption-heavy technical work
- fast context switching
- ADHD-friendly navigation
- fragment-based usage
- fast re-entry after context loss

Strict constraints:
- do not create “read this first before doing anything” style documentation
- do not end key notes with advice like “before you begin, do X”
- do not assume the user will calmly read a long note from top to bottom
- do not generate motivational fluff
- do not overengineer with too many speculative folders or empty placeholders
- do not depend on Obsidian plugins
- do not delete valuable existing content unless you replace it with a clearly better integrated version

## Language rules

- User-facing note content must be in Polish
- Technical identifiers, filenames, commands, and folder names may remain English where practical
- Keep wording practical, short, and operator-friendly

## First: inspect before changing

1. Inspect the current vault tree
2. Inspect existing Markdown files
3. Detect:
   - existing useful structure
   - duplicate notes
   - stale placeholder files
   - files that should be updated rather than recreated
4. Then perform an in-place redesign

## Target vault structure

Ensure the vault contains these top-level folders, creating missing ones and reusing existing ones if similar structure already exists:

- 00-start-here
- 01-inbox
- 02-active-context
- 10-areas
- 20-projects
- 30-standards
- 40-runbooks
- 50-patterns
- 60-toolkit
- 70-finops
- 80-architecture
- 90-reference
- templates
- assets

If similar folders already exist under different names, prefer normalizing and merging rather than duplicating.

## Required substructure

### 00-start-here
Ensure these files exist and are updated with useful content:
- README.md
- how-to-use-this-vault.md
- persona.md

### 01-inbox
- README.md
- quick-capture.md

### 02-active-context
- now.md
- current-focus.md
- open-loops.md
- waiting-for.md

### 10-areas
Ensure subfolders:
- aws/
- terraform/
- cicd/
- observability/
- cloud-support/
- business/

Each area should contain:
- README.md

If useful existing notes are found, move or link them into the right area.

### 20-projects
Ensure subfolders:
- internal/
- client/
- reference/

Under internal/, ensure:
- devops-toolkit/
- devops-platform/
- devops-business/

Each of those should contain:
- README.md
- context.md
- decisions.md
- next-steps.md
- links.md

If similar files already exist elsewhere, consolidate rather than duplicate.

### 30-standards
Ensure:
- aws-tagging-standard.md
- iac-standard.md
- cicd-standard.md
- naming-conventions.md
- documentation-standard.md

### 40-runbooks
Ensure subfolders:
- aws/
- ecs/
- kubernetes/
- terraform/
- networking/
- incidents/

Inside each:
- README.md
- at least one practical example note

### 50-patterns
Ensure:
- debugging-patterns.md
- migration-patterns.md
- incident-analysis-patterns.md
- finops-review-patterns.md
- reusable-prompts.md

### 60-toolkit
Ensure:
- README.md
- architecture-overview.md
- contracts-index.md
- command-catalog.md
- roadmap.md
- plugin-system.md
- finops-reporting.md
- e2e-testing.md

Also ensure subfolders:
- contracts/
- commands/
- audits/
- reports/

### 70-finops
Ensure:
- README.md
- cost-review-template.md
- tagging-review-template.md
- optimization-log.md
- savings-ideas.md
- reference-projects.md

### 80-architecture
Ensure:
- README.md
- decision-log.md
- system-maps.md
- platform-principles.md
- integration-notes.md

### 90-reference
Ensure subfolders:
- commands/
- snippets/
- glossary/
- vendors/

Each subfolder should contain:
- README.md

### templates
Ensure:
- project-note-template.md
- runbook-template.md
- incident-template.md
- architecture-note-template.md
- audit-template.md
- decision-template.md
- meeting-note-template.md

## Content rules

Do not leave files empty.

Every created or updated Markdown file must contain useful starter content.

### README files
Each README should explain:
- what belongs in that folder
- what does NOT belong there
- how to use it in practice
Keep it concise and practical.

### Templates
Templates must be ready to duplicate and use immediately.
They must support fragmented work.
Do not place giant “before you begin” sections at the top.
Critical sections must be near the top.

### now.md and current-focus.md
Make them immediately usable as live operational dashboards in Markdown.

### Runbook design
Runbooks and the runbook template must prioritize:
- objaw / symptom
- zakres / scope
- szybkie komendy / fast commands
- decision points
- rollback / safety
- findings / notes

Not a long introduction.

## Persona note requirements

For `00-start-here/persona.md`, write in Polish using this factual profile and integrate it into a practical operator persona:

- Name: Jarosław Gołąb
- Experienced DevOps/SRE engineer
- Works mainly with AWS, plus GCP and Azure
- Uses Terraform, Terragrunt, CloudFormation, Helm
- Uses GitHub Actions, GitLab CI, Jenkins, Make
- Works with ECS, EKS, GKE, ALB, CloudFront, VPC, RDS, DocumentDB, Redis
- Strong focus on automation, standards, architecture, FinOps, AWS audits, debugging distributed systems
- Builds a DevOps-as-a-Service model based on hourly packages and distributed B2B delivery
- Builds devops-toolkit as a stateless CLI control plane for AWS / FinOps / IaC audits and reports
- Thinks in contracts, interfaces, repeatable patterns, and system design
- Prefers deterministic, practical solutions over theory
- Has ADHD
- ADHD implications:
  - works well with fast access, modular notes, short context blocks, and reusable fragments
  - works poorly with long linear instructions, huge checklists, and notes that must be read from start to finish
  - knowledge system must reduce memory burden and support interruption/re-entry

Important:
- do not write the persona as a biography for LinkedIn
- write it as an operational profile that influences vault design and note style

## how-to-use-this-vault.md requirements

Write concise rules for using the vault in a way that supports interrupted technical work.
Do not write motivational advice.
Do not end the note with “before you start...” style recommendations.

## Existing file update policy

When existing files already cover similar topics:
- update them in place if possible
- merge duplicate notes when reasonable
- normalize naming if needed
- add links between related notes
- preserve valuable technical content
- if renaming a file, update links where possible
- avoid creating “v2”, “new”, “final”, “copy” style filenames

If a file is clearly weak placeholder content:
- replace it with better structured content

## Linking rules

Use Obsidian wiki-links between key notes, for example:
- [[persona]]
- [[current-focus]]
- [[command-catalog]]
- [[aws-tagging-standard]]
- [[decision-log]]
- [[devops-toolkit]]
- [[finops-reporting]]

Add links where they improve navigation, but do not spam every paragraph.

## File naming rules

- Prefer kebab-case
- Keep names short and obvious
- Avoid speculative files
- Build a usable skeleton, not an encyclopedia

## Root README

Ensure there is a useful vault-root README.md.
It should briefly explain the vault structure and how to navigate it.

## Execution requirements

- Work directly in the current directory
- Inspect first, then modify
- Update existing files where appropriate
- Create missing folders and files
- Reorganize content when needed
- After changes, print:
  1. a tree of the resulting structure
  2. a summary of files created
  3. a summary of files updated
  4. a summary of files moved/renamed if any
  5. a short explanation of the design decisions

Do not ask for clarification.
Do not give a plan first.
Do the work directly.You are working inside an existing local filesystem repository that is used as an Obsidian vault.

Your task is to redesign, extend, and normalize the vault into a practical DevOps knowledge system for a senior DevOps/SRE engineer.

Important: this vault already exists. You must inspect the current directory structure and current Markdown files first, then:
- preserve useful existing content
- update existing files where appropriate
- avoid destructive rewrites unless a file is clearly placeholder-quality or redundant
- merge and normalize content instead of blindly duplicating it
- create missing folders and files where needed
- improve the vault so it becomes immediately usable for real technical work

Do not treat this as a greenfield scaffold unless the current vault is nearly empty.

## Core behavioral constraints

This is not a generic note-taking vault and not a productivity-influencer setup.

The vault must be designed for:
- AWS / Terraform / CI/CD / Kubernetes / FinOps / incident response / architecture notes / standards / audit workflows / custom devops-toolkit work
- interruption-heavy technical work
- fast context switching
- ADHD-friendly navigation
- fragment-based usage
- fast re-entry after context loss

Strict constraints:
- do not create “read this first before doing anything” style documentation
- do not end key notes with advice like “before you begin, do X”
- do not assume the user will calmly read a long note from top to bottom
- do not generate motivational fluff
- do not overengineer with too many speculative folders or empty placeholders
- do not depend on Obsidian plugins
- do not delete valuable existing content unless you replace it with a clearly better integrated version

## Language rules

- User-facing note content must be in Polish
- Technical identifiers, filenames, commands, and folder names may remain English where practical
- Keep wording practical, short, and operator-friendly

## First: inspect before changing

1. Inspect the current vault tree
2. Inspect existing Markdown files
3. Detect:
   - existing useful structure
   - duplicate notes
   - stale placeholder files
   - files that should be updated rather than recreated
4. Then perform an in-place redesign

## Target vault structure

Ensure the vault contains these top-level folders, creating missing ones and reusing existing ones if similar structure already exists:

- 00-start-here
- 01-inbox
- 02-active-context
- 10-areas
- 20-projects
- 30-standards
- 40-runbooks
- 50-patterns
- 60-toolkit
- 70-finops
- 80-architecture
- 90-reference
- templates
- assets

If similar folders already exist under different names, prefer normalizing and merging rather than duplicating.

## Required substructure

### 00-start-here
Ensure these files exist and are updated with useful content:
- README.md
- how-to-use-this-vault.md
- persona.md

### 01-inbox
- README.md
- quick-capture.md

### 02-active-context
- now.md
- current-focus.md
- open-loops.md
- waiting-for.md

### 10-areas
Ensure subfolders:
- aws/
- terraform/
- cicd/
- observability/
- cloud-support/
- business/

Each area should contain:
- README.md

If useful existing notes are found, move or link them into the right area.

### 20-projects
Ensure subfolders:
- internal/
- client/
- reference/

Under internal/, ensure:
- devops-toolkit/
- devops-platform/
- devops-business/

Each of those should contain:
- README.md
- context.md
- decisions.md
- next-steps.md
- links.md

If similar files already exist elsewhere, consolidate rather than duplicate.

### 30-standards
Ensure:
- aws-tagging-standard.md
- iac-standard.md
- cicd-standard.md
- naming-conventions.md
- documentation-standard.md

### 40-runbooks
Ensure subfolders:
- aws/
- ecs/
- kubernetes/
- terraform/
- networking/
- incidents/

Inside each:
- README.md
- at least one practical example note

### 50-patterns
Ensure:
- debugging-patterns.md
- migration-patterns.md
- incident-analysis-patterns.md
- finops-review-patterns.md
- reusable-prompts.md

### 60-toolkit
Ensure:
- README.md
- architecture-overview.md
- contracts-index.md
- command-catalog.md
- roadmap.md
- plugin-system.md
- finops-reporting.md
- e2e-testing.md

Also ensure subfolders:
- contracts/
- commands/
- audits/
- reports/

### 70-finops
Ensure:
- README.md
- cost-review-template.md
- tagging-review-template.md
- optimization-log.md
- savings-ideas.md
- reference-projects.md

### 80-architecture
Ensure:
- README.md
- decision-log.md
- system-maps.md
- platform-principles.md
- integration-notes.md

### 90-reference
Ensure subfolders:
- commands/
- snippets/
- glossary/
- vendors/

Each subfolder should contain:
- README.md

### templates
Ensure:
- project-note-template.md
- runbook-template.md
- incident-template.md
- architecture-note-template.md
- audit-template.md
- decision-template.md
- meeting-note-template.md

## Content rules

Do not leave files empty.

Every created or updated Markdown file must contain useful starter content.

### README files
Each README should explain:
- what belongs in that folder
- what does NOT belong there
- how to use it in practice
Keep it concise and practical.

### Templates
Templates must be ready to duplicate and use immediately.
They must support fragmented work.
Do not place giant “before you begin” sections at the top.
Critical sections must be near the top.

### now.md and current-focus.md
Make them immediately usable as live operational dashboards in Markdown.

### Runbook design
Runbooks and the runbook template must prioritize:
- objaw / symptom
- zakres / scope
- szybkie komendy / fast commands
- decision points
- rollback / safety
- findings / notes

Not a long introduction.

## Persona note requirements

For `00-start-here/persona.md`, write in Polish using this factual profile and integrate it into a practical operator persona:

- Name: Jarosław Gołąb
- Experienced DevOps/SRE engineer
- Works mainly with AWS, plus GCP and Azure
- Uses Terraform, Terragrunt, CloudFormation, Helm
- Uses GitHub Actions, GitLab CI, Jenkins, Make
- Works with ECS, EKS, GKE, ALB, CloudFront, VPC, RDS, DocumentDB, Redis
- Strong focus on automation, standards, architecture, FinOps, AWS audits, debugging distributed systems
- Builds a DevOps-as-a-Service model based on hourly packages and distributed B2B delivery
- Builds devops-toolkit as a stateless CLI control plane for AWS / FinOps / IaC audits and reports
- Thinks in contracts, interfaces, repeatable patterns, and system design
- Prefers deterministic, practical solutions over theory
- Has ADHD
- ADHD implications:
  - works well with fast access, modular notes, short context blocks, and reusable fragments
  - works poorly with long linear instructions, huge checklists, and notes that must be read from start to finish
  - knowledge system must reduce memory burden and support interruption/re-entry

Important:
- do not write the persona as a biography for LinkedIn
- write it as an operational profile that influences vault design and note style

## how-to-use-this-vault.md requirements

Write concise rules for using the vault in a way that supports interrupted technical work.
Do not write motivational advice.
Do not end the note with “before you start...” style recommendations.

## Existing file update policy

When existing files already cover similar topics:
- update them in place if possible
- merge duplicate notes when reasonable
- normalize naming if needed
- add links between related notes
- preserve valuable technical content
- if renaming a file, update links where possible
- avoid creating “v2”, “new”, “final”, “copy” style filenames

If a file is clearly weak placeholder content:
- replace it with better structured content

## Linking rules

Use Obsidian wiki-links between key notes, for example:
- [[persona]]
- [[current-focus]]
- [[command-catalog]]
- [[aws-tagging-standard]]
- [[decision-log]]
- [[devops-toolkit]]
- [[finops-reporting]]

Add links where they improve navigation, but do not spam every paragraph.

## File naming rules

- Prefer kebab-case
- Keep names short and obvious
- Avoid speculative files
- Build a usable skeleton, not an encyclopedia

## Root README

Ensure there is a useful vault-root README.md.
It should briefly explain the vault structure and how to navigate it.

## Execution requirements

- Work directly in the current directory
- Inspect first, then modify
- Update existing files where appropriate
- Create missing folders and files
- Reorganize content when needed
- After changes, print:
  1. a tree of the resulting structure
  2. a summary of files created
  3. a summary of files updated
  4. a summary of files moved/renamed if any
  5. a short explanation of the design decisions

Do not ask for clarification.
Do not give a plan first.
Do the work directly.  │  Audit    │  │  Report   │
   └────────┬──┘  └──┬────────┘
            │        │
   ┌────────▼────────▼────────┐
   │      AWS SDK / API       │
   └──────────────────────────┘
            │
   ┌────────▼────────┐
   │   Output Layer  │
   │  JSON / MD / CSV│
   └─────────────────┘
```

## Warstwy

| Warstwa | Odpowiedzialność |
|---------|-----------------|
| CLI Entry | parsowanie argumentów, routing do komendy |
| Command Router | ładowanie wtyczek, resolving kontraktów |
| Command / Plugin | logika biznesowa, wywołania AWS SDK |
| AWS SDK / API | komunikacja z chmurą |
| Output Layer | formatowanie wyjścia (JSON, Markdown, CSV) |

## Kontrakt komendy

Każda komenda jest opisana kontraktem:

```json
{
  "command": "audit iam",
  "input": {
    "account_id": "string",
    "region": "string",
    "profile": "string (optional)"
  },
  "output": {
    "findings": [
      {
        "resource": "string",
        "severity": "HIGH | MEDIUM | LOW",
        "finding": "string",
        "recommendation": "string"
      }
    ],
    "summary": {
      "total": "number",
      "by_severity": "object"
    }
  }
}
```

## Zasada composability

```bash
# Output jednej komendy można przekazać do następnej
toolkit audit iam --output json | toolkit report generate --format markdown
```

## Powiązane

- [[contracts-index]]
- [[plugin-system]]
- [[command-catalog]]
