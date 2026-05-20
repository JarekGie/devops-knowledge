# Superpowers Vault Layer — Plan Implementacji

> **Dla agentów wykonawczych:** Użyj `superpowers:subagent-driven-development` (zalecane) lub `superpowers:executing-plans` do implementacji zadanie po zadaniu. Kroki używają składni checkbox (`- [ ]`).

**Cel:** Zbudować `_system/superpowers/` — lekką warstwę execution/bootstrap dla Claude Code i Codex, działającą jako runtime wrapper wymuszający safety contracts i redukujący context switching.

**Architektura:** Vault pozostaje jedynym source of truth. Superpowers ładuje kontekst z vault (nigdy nie kopiuje wiedzy), wykonuje guided workflows, zwraca wyniki do vault. Warstwa addytywna — nie zastępuje istniejących kontraktów `_system/`.

**Stos:** Markdown + YAML frontmatter, Obsidian wiki-links, bash (dla bootstrap scripts gdzie potrzebne).

**Vault root:** `/Users/jaroslaw.golab/projekty/devops/devops-knowledge/`

---

## Mapa plików

| Plik | Rola |
|------|------|
| `_system/superpowers/README.md` | Entry point — co to jest, jak używać |
| `_system/superpowers/SUPERPOWERS-CONTRACT.md` | Główny kontrakt — definicja, architektura, zakazy |
| `_system/superpowers/SAFETY-CONTRACT.md` | Blast radius, forbidden actions, operator gate |
| `_system/superpowers/CONTEXT-GOVERNANCE.md` | Domain isolation, minimal context, ADHD UX |
| `_system/superpowers/EXECUTION-MODES.md` | Tryby wykonania, evidence-first format, cost tiers |
| `_system/superpowers/SKILL-TEMPLATE.md` | Szablon dla nowych skillów |
| `_system/superpowers/bootstrap/project-bootstrap.md` | Bootstrap sesji roboczej na projekcie |
| `_system/superpowers/bootstrap/incident-bootstrap.md` | Bootstrap incydentu/awarii |
| `_system/superpowers/bootstrap/governance-bootstrap.md` | Bootstrap przeglądu governance |
| `_system/superpowers/bootstrap/finops-bootstrap.md` | Bootstrap analizy FinOps |
| `_system/superpowers/categories/aws/README.md` | Katalog skillów AWS |
| `_system/superpowers/categories/ecs/README.md` | Katalog skillów ECS |
| `_system/superpowers/categories/terraform/README.md` | Katalog skillów Terraform |
| `_system/superpowers/categories/cloudformation/README.md` | Katalog skillów CloudFormation |
| `_system/superpowers/categories/finops/README.md` | Katalog skillów FinOps |
| `_system/superpowers/categories/governance/README.md` | Katalog skillów Governance |
| `_system/superpowers/categories/incidents/README.md` | Katalog skillów Incidents |
| `_system/superpowers/categories/observability/README.md` | Katalog skillów Observability |
| `_system/superpowers/categories/onboarding/README.md` | Katalog skillów Onboarding |
| `_system/superpowers/categories/chatgpt/README.md` | Katalog skillów ChatGPT workflows |
| `_system/superpowers/examples/rshop-cfn-analysis.md` | Przykład: analiza CloudFormation |
| `_system/superpowers/examples/pbms-runtime-debug.md` | Przykład: debug ECS/ALB runtime |
| `_system/superpowers/examples/llz-governance-review.md` | Przykład: przegląd governance |
| `_system/superpowers/examples/finops-review.md` | Przykład: przegląd FinOps |

---

## Task 1: Scaffold katalogów

**Files:**
- Create: `_system/superpowers/` (tree katalogów)

- [ ] **Krok 1: Utwórz strukturę katalogów**

```bash
cd /Users/jaroslaw.golab/projekty/devops/devops-knowledge
mkdir -p _system/superpowers/bootstrap
mkdir -p _system/superpowers/categories/aws
mkdir -p _system/superpowers/categories/ecs
mkdir -p _system/superpowers/categories/terraform
mkdir -p _system/superpowers/categories/cloudformation
mkdir -p _system/superpowers/categories/finops
mkdir -p _system/superpowers/categories/governance
mkdir -p _system/superpowers/categories/incidents
mkdir -p _system/superpowers/categories/observability
mkdir -p _system/superpowers/categories/onboarding
mkdir -p _system/superpowers/categories/chatgpt
mkdir -p _system/superpowers/examples
```

- [ ] **Krok 2: Weryfikacja struktury**

```bash
find _system/superpowers -type d | sort
```

Oczekiwany output:
```
_system/superpowers
_system/superpowers/bootstrap
_system/superpowers/categories
_system/superpowers/categories/aws
_system/superpowers/categories/cloudformation
_system/superpowers/categories/chatgpt
_system/superpowers/categories/ecs
_system/superpowers/categories/finops
_system/superpowers/categories/governance
_system/superpowers/categories/incidents
_system/superpowers/categories/observability
_system/superpowers/categories/onboarding
_system/superpowers/categories/terraform
_system/superpowers/examples
```

---

## Task 2: README.md — entry point

**Files:**
- Create: `_system/superpowers/README.md`

- [ ] **Krok 1: Utwórz README.md**

Utwórz plik `_system/superpowers/README.md` z poniższą treścią:

```markdown
---
title: Superpowers — Warstwa Execution dla Vault DevOps/SRE
type: readme
status: active
domain: shared-concept
classification: internal
llm_exposure: allowed
created: 2026-05-18
updated: 2026-05-18
tags: [superpowers, execution-layer, runtime, governance]
---

# Superpowers — Warstwa Execution

Superpowers to lekka warstwa execution/bootstrap dla Claude Code i Codex.
Runtime wrapper — nie vault, nie dokumentacja, nie autonomiczny agent.

## Architektura

```
vault (source of truth)
  → context pack / derived context
    → superpower (guided workflow)
      → Claude/Codex execution
        → wynik z powrotem do vault
```

## Czym jest

- execution bootstrap dla typowych workflows DevOps/SRE
- reusable guided templates redukujące context switching
- mechanizm wymuszający safety contracts
- guided execution dla operatorów i juniorów

## Czym NIE jest

- source of truth (vault jest jedynym SoT)
- duplikacją runbooków
- miejscem wiedzy operacyjnej
- autonomicznym agentem

## Szybki start

### Nowa sesja na projekcie

```
Użyj @_system/superpowers/bootstrap/project-bootstrap.md.
Projekt: <nazwa>. Domena: client-work.
```

### Incydent

```
Użyj @_system/superpowers/bootstrap/incident-bootstrap.md.
Incydent: <opis>. Środowisko: <prod/uat>.
```

### Analiza FinOps

```
Użyj @_system/superpowers/bootstrap/finops-bootstrap.md.
Projekt: <nazwa>. Zakres: <miesięczny/anomalia>.
```

## Kontrakty

| Kontrakt | Rola |
|----------|------|
| [[SUPERPOWERS-CONTRACT]] | Definicja, architektura, zakazy |
| [[SAFETY-CONTRACT]] | Blast radius, forbidden actions, operator gate |
| [[CONTEXT-GOVERNANCE]] | Domain isolation, minimal context, ADHD UX |
| [[EXECUTION-MODES]] | Tryby wykonania, evidence-first format |
| [[SKILL-TEMPLATE]] | Szablon dla nowych skillów |

## Bootstrap

| Plik | Kiedy używać |
|------|-------------|
| [[project-bootstrap]] | Nowa sesja robocza na projekcie |
| [[incident-bootstrap]] | Incydent / awaria |
| [[governance-bootstrap]] | Przegląd governance, SCP, tagging |
| [[finops-bootstrap]] | Analiza kosztów, optymalizacja |

## Relacja do istniejących kontraktów

Superpowers nie zastępuje:
- [[AGENT_BOOTSTRAP]] — obowiązkowy bootstrap pozostaje
- [[AI_COST_AWARE_AGENT_CONTRACT]] — tiering S/M/P obowiązuje
- [[DOMAIN_ISOLATION_CONTRACT]] — jedna domena per sesja obowiązuje

## Kategorie skillów

```
categories/
  aws/          — IAM, S3, CloudFront, Route53, ACM
  ecs/          — ECS Fargate, task definitions, scaling
  terraform/    — plan review, drift, module audit
  cloudformation/ — stack analysis, rollback, changeset
  finops/       — cost review, tagging gaps, optimization
  governance/   — SCP, LLZ, tagging standards, compliance
  incidents/    — RCA, diagnostic, post-mortem
  observability/ — CloudWatch, alarms, dashboards
  onboarding/   — nowy projekt, nowy junior
  chatgpt/      — context pack workflows
```
```

- [ ] **Krok 2: Weryfikacja**

```bash
grep -c "^#" _system/superpowers/README.md
```

Oczekiwany output: liczba nagłówków > 5

- [ ] **Krok 3: Commit**

```bash
git add _system/superpowers/README.md
git commit -m "superpowers: dodaj README — entry point warstwy execution"
```

---

## Task 3: SUPERPOWERS-CONTRACT.md

**Files:**
- Create: `_system/superpowers/SUPERPOWERS-CONTRACT.md`

- [ ] **Krok 1: Utwórz SUPERPOWERS-CONTRACT.md**

```markdown
---
title: Superpowers Layer Contract
type: contract
status: active
domain: shared-concept
classification: internal
llm_exposure: allowed
created: 2026-05-18
updated: 2026-05-18
tags: [superpowers, contract, governance, execution-layer]
---

# Superpowers Layer Contract

Powiązane: [[SAFETY-CONTRACT]] | [[CONTEXT-GOVERNANCE]] | [[EXECUTION-MODES]] | [[AGENT_BOOTSTRAP]]

---

## 1. Definicja

Superpowers to lekka warstwa execution/bootstrap.

Superpowers MA być:
- execution bootstrap dla typowych workflows DevOps/SRE
- reusable guided templates dla operatorów i juniorów
- mechanizmem wymuszającym safety i governance contracts
- reduktorem context switching i cognitive load

Superpowers NIE MA być:
- source of truth (jedynym SoT pozostaje vault Obsidian)
- duplikacją runbooków ani wiedzy operacyjnej
- miejscem przechowywania context packów
- autonomicznym agentem podejmującym decyzje bez operatora

---

## 2. Architektura (non-negotiable)

### Dozwolony przepływ

```
vault → context pack / derived context → superpower → Claude/Codex execution
```

### NIEDOZWOLONE

```
vault → duplicate into superpowers → execution
```

Superpowers:
- czyta z vault (runbooki, context packs, session-log)
- NIE kopiuje treści vault do własnych plików
- linkuje do vault zamiast powielać (`[[wiki-link]]`)
- zwraca wyniki do vault (`session-log.md`, `now.md`)

---

## 3. Zasada referencji

Każdy skill superpowers MUSI wskazać:
- `context_sources` — które pliki vault są source of truth
- `context_type` — derived / targeted-snippet / runbook
- `assumptions` — przyjęte założenia (jawnie, nie domyślnie)

Skill NIE MOŻE:
- załadować pełnego vault jako kontekst
- wkleić zawartości całych repozytoriów
- używać stale context bez oznaczenia source

---

## 4. Relacja do istniejących kontraktów

Superpowers jest warstwą addytywną — nie zastępuje i nie nadpisuje:

| Kontrakt | Lokalizacja | Priorytet |
|----------|-------------|-----------|
| AGENT_BOOTSTRAP | `_system/AGENT_BOOTSTRAP.md` | Nadrzędny |
| AI_COST_AWARE_AGENT_CONTRACT | `_system/AI_COST_AWARE_AGENT_CONTRACT.md` | Nadrzędny |
| DOMAIN_ISOLATION_CONTRACT | `_system/DOMAIN_ISOLATION_CONTRACT.md` | Nadrzędny |
| LLM_CONTEXT_BOUNDARY_CONTRACT | `_system/LLM_CONTEXT_BOUNDARY_CONTRACT.md` | Nadrzędny |
| SAFETY-CONTRACT | `_system/superpowers/SAFETY-CONTRACT.md` | Superpowers |
| CONTEXT-GOVERNANCE | `_system/superpowers/CONTEXT-GOVERNANCE.md` | Superpowers |

Każdy skill musi respektować WSZYSTKIE kontrakty z powyższej listy.

Priorytet rozwiązywania konfliktów:
1. Instrukcje użytkownika (CLAUDE.md, bezpośrednie polecenia)
2. Kontrakty nadrzędne `_system/`
3. Kontrakty superpowers

---

## 5. Zasady tworzenia nowych skillów

Nowy skill MUSI:
- używać `SKILL-TEMPLATE.md` jako punktu startowego
- deklarować `blast_radius` i `execution_mode` w frontmatter
- wskazać `context_sources`
- zawierać sekcję Guardrails
- zawierać Operator Gate jeśli `blast_radius: HIGH` lub `CRITICAL`

Nowy skill NIE MOŻE:
- kopiować treści runbooków — linkować do nich
- przechowywać wiedzy projektowej — zapisać do vault
- wykonywać write actions domyślnie — wymagać explicit approval

---

## 6. Lifecycle skilla

```
draft (w categories/) → review przez operatora → active → deprecated
```

Status `deprecated` zamiast usunięcia — historia wymagań.

---

## 7. Zasada autorstwa

Wyniki generowane przez superpowers trafiają do vault z metadatą:
- `generated_by: claude` lub `generated_by: codex`
- `source_skill: <nazwa skilla>`

Autorem notatki pozostaje operator — AI jest narzędziem.
```

- [ ] **Krok 2: Weryfikacja sekcji**

```bash
grep "^## " _system/superpowers/SUPERPOWERS-CONTRACT.md
```

Oczekiwany output (7 sekcji):
```
## 1. Definicja
## 2. Architektura (non-negotiable)
## 3. Zasada referencji
## 4. Relacja do istniejących kontraktów
## 5. Zasady tworzenia nowych skillów
## 6. Lifecycle skilla
## 7. Zasada autorstwa
```

- [ ] **Krok 3: Commit**

```bash
git add _system/superpowers/SUPERPOWERS-CONTRACT.md
git commit -m "superpowers: dodaj SUPERPOWERS-CONTRACT — definicja, architektura, zasady"
```

---

## Task 4: SAFETY-CONTRACT.md

**Files:**
- Create: `_system/superpowers/SAFETY-CONTRACT.md`

- [ ] **Krok 1: Utwórz SAFETY-CONTRACT.md**

```markdown
---
title: Superpowers Safety Contract
type: contract
status: active
domain: shared-concept
classification: internal
llm_exposure: allowed
created: 2026-05-18
updated: 2026-05-18
tags: [superpowers, safety, blast-radius, operator-gate, governance]
---

# Superpowers Safety Contract

Powiązane: [[SUPERPOWERS-CONTRACT]] | [[EXECUTION-MODES]] | [[AGENT_BOOTSTRAP]]

---

## 1. Domyślny tryb

DOMYŚLNY TRYB WYKONANIA: **READ-ONLY ANALYSIS**

Każdy skill działa domyślnie jako:
- `analysis-first` — najpierw zbierz dane, potem wnioski
- `evidence-driven` — fakty przed hipotezami, hipotezy przed rekomendacjami
- `blast-radius-aware` — zadeklaruj ryzyko zanim zaczniesz

---

## 2. Poziomy Blast Radius

| Poziom | Opis | Write actions? | Operator gate? |
|--------|------|----------------|----------------|
| LOW | read-only, analiza, audyt, generowanie raportów | NIE | NIE |
| MEDIUM | dry-run, generowanie changesetów, plan generation | NIE (changeset ≠ apply) | Opcjonalny |
| HIGH | modyfikacja konfiguracji, deploy, update service | NIE bez gate | WYMAGANY |
| CRITICAL | SCP, IAM, DNS, security groups, prod data, certyfikaty | NIE bez gate | WYMAGANY + uzasadnienie |

Skill deklaruje blast_radius w frontmatter. Brak deklaracji = traktuj jako HIGH.

---

## 3. Domyślnie Zabronione

Bez explicit approval operatora (written, w tej sesji, dla tego konkretnego działania):

### IaC
- `terraform apply`
- `terraform destroy`
- `terraform import`
- `cloudformation deploy`
- `cloudformation update-stack`
- `cloudformation delete-stack`

### AWS Services
- `aws ecs update-service`
- `aws ecs register-task-definition` (jeśli natychmiast deployowane)
- modyfikacje SCP (Service Control Policies)
- modyfikacje IAM (policies, roles, users)
- modyfikacje Route53 (records, hosted zones)
- DNS cutover (CNAME, A record swap)
- modyfikacje security groups
- modyfikacje NACL
- disable/enable GuardDuty, SecurityHub, Config

### Kubernetes
- `kubectl apply`
- `kubectl delete`
- `kubectl rollout restart`
- modyfikacje RBAC

### Dane
- migracje baz danych
- usuwanie zasobów (S3, RDS snapshots, EBS)
- `FLUSHALL` (Redis/ElastiCache) bez potwierdzenia

### Git
- force push (`git push --force`)
- `git reset --hard`
- `git rebase` bez weryfikacji

### System
- `rm -rf`
- autonomous remediation (działanie naprawcze bez zatwierdzenia)

---

## 4. Domyślnie Dozwolone

Bez dodatkowego potwierdzenia:

Analiza read-only:
- `aws <serwis> describe-*` / `list-*` / `get-*`
- `terraform plan` (nigdy `apply`)
- `kubectl get` / `kubectl describe` / `kubectl logs`
- `git log` / `git diff` / `git status`
- parsing logów CloudWatch
- drift review (IaC vs stan runtime)
- RCA z istniejących danych
- generowanie checklist
- generowanie raportów Markdown
- przygotowanie changeset (nie deploy)
- przygotowanie rollback plan (nie execute)
- context bootstrap
- risk analysis
- validation (read-only)
- dry-run (gdy serwis to wspiera)
- plan generation

---

## 5. Operator Gate Format

Każdy skill z `blast_radius: HIGH` lub `CRITICAL` MUSI zakończyć się checkpointem:

```
---
STOP. OPERATOR GATE

Blast radius:  [HIGH | CRITICAL]
Tryb:          [execution_mode skilla]
Sesja:         [projekt / środowisko]

Pending actions:
  1. [konkretne działanie 1]
  2. [konkretne działanie 2]

Ryzyko:
  - [ryzyko 1]
  - [ryzyko 2]

Oczekuję explicit approval przed kontynuacją.
Powiedz "tak, wykonaj [1/2/all]" lub "anuluj".
---
```

### Zasady gate

Skill NIE może:
- przejść dalej bez odpowiedzi operatora
- interpretować ciszy jako zgody
- wykonać częściowego apply jeśli operator zatwierdził "all"

Operator MUSI:
- odpowiedzieć jawnie (tak/nie/konkretne numery)
- podać zakres (które działania)

Jeden approval = jeden konkretny zakres. Nie przenosi się na inne sesje ani inne działania.

---

## 6. Self-check dla agenta

Przed każdą nieread-only akcją agent musi mentalnie sprawdzić:

1. Czy jest explicit approval dla TEGO konkretnego działania?
2. Czy blast_radius jest zadeklarowany?
3. Czy Operator Gate został wyświetlony i zatwierdzony?
4. Czy scope jest zgodny z zatwierdzeniem?

Jeśli odpowiedź na jakiekolwiek pytanie brzmi "nie" lub "nie wiem":
→ ZATRZYMAJ SIĘ i wróć do operatora.
```

- [ ] **Krok 2: Weryfikacja sekcji**

```bash
grep "^## " _system/superpowers/SAFETY-CONTRACT.md
```

Oczekiwany output:
```
## 1. Domyślny tryb
## 2. Poziomy Blast Radius
## 3. Domyślnie Zabronione
## 4. Domyślnie Dozwolone
## 5. Operator Gate Format
## 6. Self-check dla agenta
```

- [ ] **Krok 3: Commit**

```bash
git add _system/superpowers/SAFETY-CONTRACT.md
git commit -m "superpowers: dodaj SAFETY-CONTRACT — blast radius, forbidden actions, operator gate"
```

---

## Task 5: CONTEXT-GOVERNANCE.md

**Files:**
- Create: `_system/superpowers/CONTEXT-GOVERNANCE.md`

- [ ] **Krok 1: Utwórz CONTEXT-GOVERNANCE.md**

```markdown
---
title: Superpowers Context Governance
type: contract
status: active
domain: shared-concept
classification: internal
llm_exposure: allowed
created: 2026-05-18
updated: 2026-05-18
tags: [superpowers, context, governance, domain-isolation, adhd-ux]
---

# Superpowers Context Governance

Powiązane: [[SUPERPOWERS-CONTRACT]] | [[DOMAIN_ISOLATION_CONTRACT]] | [[AI_COST_AWARE_AGENT_CONTRACT]]

---

## 1. Domain Isolation (non-negotiable)

Jedna sesja = jedna domena. Reguła pochodzi z `_system/DOMAIN_ISOLATION_CONTRACT.md` i jest bezwzględna.

Domeny:
- `client-work` — projekty klientów (rshop, maspex, puzzler-b2b)
- `internal-product-strategy` — LLZ, devops-toolkit, roadmapa wewnętrzna
- `private-rnd` — osobiste projekty R&D
- `shared-concept` — standardy AWS, wzorce Terraform, governance

Każdy skill MUSI deklarować `domain` w frontmatter.

### Boundary violation

Jeśli skill wykryje, że sesja próbuje zmieszać domeny:
1. Zatrzymaj działanie
2. Zgłoś: `BOUNDARY VIOLATION: próba mieszania domen [A] i [B]`
3. Poproś operatora o wybór jednej domeny
4. NIE kontynuuj z mieszanym kontekstem

Forbidden w shared vault (dc-devops-team-vault):
- devops-toolkit internals
- private-rnd
- product strategy
- prywatne notatki
- projekty poza MakoLab/BMW

---

## 2. Minimal Context Principle

Skill ładuje: **minimalny kontekst potrzebny do wykonania zadania**.

### Target rozmiar kontekstu

| Typ zadania | Target kontekst |
|-------------|----------------|
| Analiza pojedynczego zasobu | 1 context pack lub 1 runbook |
| Incident response | runbook + session-log + resource state |
| Governance review | standards + project context |
| FinOps review | finops context + cost report |
| Full project context | project context pack (max ~3000 tokenów) |

### Zakazane wzorce

NIE wolno:
- ładować całego vault jako kontekst
- wklejać pełnych repozytoriów IaC
- re-summarizować całego historycznego session-log
- używać `@codebase` lub równoważnych (pełny kontekst repozytorium) bez uzasadnienia

Preferowane:
- derived context (konkretna notatka projektu)
- targeted snippets (konkretna sekcja runbooka)
- `@ścieżka/do/konkretnego/pliku.md` zamiast całego katalogu
- `rg` i selektywne czytanie zamiast pełnych dumpów

---

## 3. Context Source Declaration

Każdy skill MUSI zadeklarować w sekcji wykonawczej:

```
## Kontekst wejściowy

Źródła (source of truth):
- `20-projects/clients/<klient>/<projekt>/<projekt>-context.md` — runtime state
- `40-runbooks/<kategoria>/<runbook>.md` — procedura
- `<ścieżka/do/session-log.md>` — historia sesji

Założenia (jawne):
- środowisko: <prod/uat/dev>
- region AWS: <eu-west-1/eu-central-1>
- profil AWS: <nazwa>
```

Brak source declaration = agent MUSI zapytać operatora przed kontynuacją.

---

## 4. ADHD-Aware UX (non-negotiable)

Vault jest narzędziem pracy dla osoby z ADHD. Superpowers musi redukować, nie zwiększać cognitive load.

### Wymagania formatu outputu

Każda odpowiedź superpowers:
1. **Werdykt na górze** — jedna linia, co znaleziono / jaki status
2. **Krótkie sekcje** z nagłówkami — nie ciągłe eseje
3. **Checklisty** dla next stepów — nie numerowane paragrafy
4. **Konkretne next steps** — nie "rozważ opcje"
5. **Brak długich wstępów** — nie tłumacz co za chwilę zrobisz

### Zakazane wzorce UX

NIE pisz:
- "W celu przeprowadzenia analizy, najpierw załaduję kontekst..."
- "Rozważę kilka podejść do tego problemu..."
- "To jest złożone zagadnienie wymagające..."
- Długich podsumowań na końcu (użytkownik widział diff)
- Marketingowego języka ("kompleksowa analiza", "holistyczne podejście")
- "AI magic" ("pomogę ci...", "przygotowałem dla ciebie...")

### Format odpowiedzi superpowers

```
[WERDYKT: 1 linia — co z tego wynika]

## Fakty
- ...
- ...

## Hipotezy / ryzyko
- ...

## Next steps
- [ ] krok 1
- [ ] krok 2
```

### Przerywanie wątków

Użytkownik może przejść na nowy wątek bez ostrzeżenia.
Superpowers: podążaj za nowym wątkiem bez pytania o powrót do poprzedniego.
Zapisz stan bieżącego wątku do vault przed przejściem.

---

## 5. Context Pack lifecycle

Context pack stworzony przez superpowers trafia do:
- `_chatgpt/context-packs/<temat>.md` (dla sesji ChatGPT)
- lub bezpośrednio do notatki projektu jako sekcja

Context pack MUSI:
- zawierać `generated_by: claude` i `source_skill:`
- nie zawierać danych `restricted` (hasła, klucze, IP prod)
- być anonimizowany przed udostępnieniem w shared vault
```

- [ ] **Krok 2: Weryfikacja**

```bash
grep "^## " _system/superpowers/CONTEXT-GOVERNANCE.md
```

Oczekiwany output:
```
## 1. Domain Isolation (non-negotiable)
## 2. Minimal Context Principle
## 3. Context Source Declaration
## 4. ADHD-Aware UX (non-negotiable)
## 5. Context Pack lifecycle
```

- [ ] **Krok 3: Commit**

```bash
git add _system/superpowers/CONTEXT-GOVERNANCE.md
git commit -m "superpowers: dodaj CONTEXT-GOVERNANCE — domain isolation, minimal context, ADHD UX"
```

---

## Task 6: EXECUTION-MODES.md

**Files:**
- Create: `_system/superpowers/EXECUTION-MODES.md`

- [ ] **Krok 1: Utwórz EXECUTION-MODES.md**

```markdown
---
title: Superpowers Execution Modes
type: contract
status: active
domain: shared-concept
classification: internal
llm_exposure: allowed
created: 2026-05-18
updated: 2026-05-18
tags: [superpowers, execution-modes, evidence-first, cost-aware]
---

# Superpowers Execution Modes

Powiązane: [[SAFETY-CONTRACT]] | [[AI_COST_AWARE_AGENT_CONTRACT]] | [[CONTEXT-GOVERNANCE]]

---

## 1. Tryby wykonania

Każdy skill MUSI deklarować `execution_mode` w frontmatter. Domyślnie: `read-only`.

### read-only

Tylko analiza i raportowanie. Żadnych modyfikacji.

```
Dozwolone: describe, list, get, logs, diff, plan (bez apply)
Zabronione: apply, delete, update, create, deploy
```

Typowe zastosowania:
- drift analysis
- security audit
- RCA z istniejących danych
- generowanie raportu

### advisory

Analiza + rekomendacje działań. Nie wykonuje działań.

```
Dozwolone: wszystko z read-only + formułowanie rekomendacji
Nie generuje: changesetów gotowych do wykonania
```

Typowe zastosowania:
- cost optimization recommendations
- architecture review
- onboarding checklist

### dry-run

Analiza + generowanie changeset/planu gotowego do review. Nie wykonuje.

```
Dozwolone: wszystko z advisory + generowanie changesetów
Output: gotowy plan/changeset, oznaczony jako "NIE WYKONANY"
```

Typowe zastosowania:
- terraform plan review
- ECS task definition diff
- DNS changeset

### execute

Analiza + wykonanie zatwierdzonych działań. WYMAGA explicit Operator Gate.

```
Dozwolone: wszystko + write actions po explicit approval
Wymagane: Operator Gate PRZED każdą write action
Wymagane: blast_radius: HIGH lub CRITICAL → gate obowiązkowy
```

Typowe zastosowania:
- terraform apply (po review planu)
- ECS service update
- DNS cutover (po zatwierdzeniu)

### Escalacja trybu

Skill może zaproponować escalację trybu, NIE może jej wykonać sam:

```
Propozycja: "Ten skill działa w trybie dry-run.
Aby wykonać zmiany, potrzebuję zmiany trybu na execute.
Czy chcesz kontynuować z execute?"
```

---

## 2. Evidence-First Format (obowiązkowy)

Każdy raport z superpowers MUSI stosować format evidence-first.

### Format

```
[WERDYKT]
Jedna linia: status, główny wniosek, lub krytyczne znalezisko.

## Fakty
- [fakt 1] (source: `ścieżka/do/pliku` lub AWS ARN)
- [fakt 2]
- [fakt 3]

## Hipotezy
- [hipoteza 1] — prawdopodobieństwo: HIGH/MEDIUM/LOW
- [hipoteza 2]

## Ryzyko
- [ryzyko 1] — blast_radius: [HIGH/MEDIUM/LOW]
- [ryzyko 2]

## Next steps
- [ ] krok 1 (konkretny, wykonywalny)
- [ ] krok 2
```

### Zasady

1. **WERDYKT zawsze na górze** — operator widzi wynik bez czytania całości
2. **Fakty z source** — każdy fakt musi mieć wskazany plik lub zasób AWS
3. **Hipotezy oddzielne od faktów** — jasne rozróżnienie
4. **Ryzyko z blast_radius** — nie "może być problem", ale "blast_radius: HIGH, dotyczy: prod"
5. **Next steps jako checklisty** — nie numerowane listy bez checkbox

### Anti-patterns

NIE pisz:
- "Analiza wykazała, że możliwe jest, że..."
- "Wydaje się, że problem może być spowodowany..."
- Faktu bez źródła
- Hipotezy bez oceny prawdopodobieństwa
- Next step bez konkretnego działania

---

## 3. Cost-Aware Execution

Superpowers stosuje tiering modeli z `_system/AI_COST_AWARE_AGENT_CONTRACT.md`:

| Tier | Kiedy | Przykłady zadań superpowers |
|------|-------|-----------------------------|
| S — low-cost | Proste analizy, formatowanie, checklisty | Generowanie checklist deploy, formatowanie raportu |
| M — standard | Techniczne RCA, review changesetów, IaC review | CloudFormation drift, terraform plan review, incident analysis |
| P — premium | Złożona architektura, threat modeling, multi-account | SCP design, security governance review, multi-region architecture |

### Escalation rule

```
Zacznij od Tier S.
Eskaluj do M: gdy zadanie wymaga realnego rozumowania technicznego.
Eskaluj do P: TYLKO gdy:
  - sprzeczne dane (wielokrotna walidacja nie pomogła)
  - blast_radius: CRITICAL
  - architektura multi-account lub multi-region
  - security/governance z wysokim kosztem błędu
  - użytkownik jawnie poprosił
```

Premium-by-default jest zabronione.

---

## 4. Reasoning Display Policy

Superpowers ukrywa verbose reasoning jeśli niepotrzebny.

```
Output do operatora: werdykt + sekcje (patrz evidence-first format)
NIE wyświetlaj: pełnego procesu rozumowania, deliberacji, "zastanawiam się"
WYŚWIETLAJ: tylko gdy operator prosi o "pokaż reasoning" lub Tier P
```

---

## 5. Mode × Blast Radius Matrix

| Mode | LOW | MEDIUM | HIGH | CRITICAL |
|------|-----|--------|------|----------|
| read-only | ✅ | ✅ | ✅ (tylko analiza) | ✅ (tylko analiza) |
| advisory | ✅ | ✅ | ✅ (rekomendacje, nie write) | ✅ (rekomendacje, nie write) |
| dry-run | ✅ | ✅ | ✅ (plan, nie execute) | ⚠️ z gate |
| execute | ✅ | ⚠️ z gate | ❌ bez gate | ❌ bez gate |
```

- [ ] **Krok 2: Weryfikacja**

```bash
grep "^## " _system/superpowers/EXECUTION-MODES.md
```

Oczekiwany output:
```
## 1. Tryby wykonania
## 2. Evidence-First Format (obowiązkowy)
## 3. Cost-Aware Execution
## 4. Reasoning Display Policy
## 5. Mode × Blast Radius Matrix
```

- [ ] **Krok 3: Commit**

```bash
git add _system/superpowers/EXECUTION-MODES.md
git commit -m "superpowers: dodaj EXECUTION-MODES — tryby, evidence-first, cost tiers"
```

---

## Task 7: SKILL-TEMPLATE.md

**Files:**
- Create: `_system/superpowers/SKILL-TEMPLATE.md`

- [ ] **Krok 1: Utwórz SKILL-TEMPLATE.md**

```markdown
---
title: Superpowers Skill Template
type: template
status: active
domain: shared-concept
classification: internal
llm_exposure: allowed
created: 2026-05-18
updated: 2026-05-18
tags: [superpowers, template, skill]
---

# Skill Template

Kopiuj ten plik przed tworzeniem nowego skilla.
Wypełnij WSZYSTKIE sekcje oznaczone `<...>`. Nie zostawiaj placeholderów w aktywnym skilu.

---

## Jak używać

1. Skopiuj ten plik do `_system/superpowers/categories/<kategoria>/<nazwa-skilla>.md`
2. Wypełnij frontmatter
3. Wypełnij wszystkie sekcje
4. Usuń tę sekcję "Jak używać"
5. Przetestuj na bezpiecznym środowisku (nie prod) przed markiem `status: active`

---

## FRONTMATTER (wymagany, skopiuj i wypełnij)

```yaml
---
title: <Tytuł Skilla — co robi>
type: skill
category: <aws|ecs|terraform|cloudformation|finops|governance|incidents|observability|onboarding|chatgpt>
status: draft
blast_radius: <LOW|MEDIUM|HIGH|CRITICAL>
execution_mode: <read-only|advisory|dry-run|execute>
domain: <client-work|internal-product-strategy|private-rnd|shared-concept>
context_sources:
  - <ścieżka/do/pliku.md> — <co to jest>
guardrails:
  - <ograniczenie 1>
  - <ograniczenie 2>
classification: internal
llm_exposure: allowed
created: <YYYY-MM-DD>
updated: <YYYY-MM-DD>
tags: [superpowers, <kategoria>, <dodatkowe-tagi>]
---
```

---

# <Nazwa Skilla>

Jeden akapit: co ten skill robi, kiedy go używać, co zwraca.

Powiązane: [[SAFETY-CONTRACT]] | [[EXECUTION-MODES]] | [[<powiązany-runbook-lub-projekt>]]

---

## Cel

Krótko (2-4 linie):
- problem który rozwiązuje
- output który generuje
- kiedy NIE używać

---

## Kontekst wejściowy

Przed uruchomieniem skilla operator MUSI podać:

```
Parametry wymagane:
  - projekt: <nazwa projektu>
  - środowisko: <prod|uat|dev>
  - <parametr 3>: <opis>

Parametry opcjonalne:
  - <parametr opcjonalny>: <opis> [domyślnie: <wartość>]
```

Źródła (source of truth):
```
- <ścieżka/do/context.md> — runtime state projektu
- <ścieżka/do/runbook.md> — procedura
- [opcjonalnie] <ścieżka/do/session-log.md> — historia
```

Jak załadować kontekst:
```
Użyj @<ścieżka/do/context.md> jako kontekstu projektu
i wykonaj ten skill dla środowiska <prod/uat>.
```

---

## Wykonanie

### Krok 1: <Nazwa kroku>

<Opis działania>

```bash
# Komendy read-only do wykonania
aws <serwis> describe-... --profile <profil>
```

Output do zinterpretowania:
- `<pole>` — co oznacza
- `<status>` — kiedy jest OK, kiedy problem

### Krok 2: <Nazwa kroku>

<Opis>

```bash
<komendy>
```

### Krok N: <Agregacja wyników>

Zebranie wszystkich findings z poprzednich kroków.

---

## Format outputu

Użyj evidence-first format z `_system/superpowers/EXECUTION-MODES.md`:

```
[WERDYKT]
<jedna linia — status lub główne znalezisko>

## Fakty
- ...

## Hipotezy
- ...

## Ryzyko
- blast_radius: <LOW|MEDIUM|HIGH|CRITICAL>
- <opis>

## Next steps
- [ ] ...
```

---

## Guardrails

Ten skill:
- NIE wykonuje write actions (jeśli execution_mode: read-only)
- NIE ładuje kontekstu spoza zadeklarowanych `context_sources`
- NIE przechodzi do kolejnego kroku bez zakończenia analizy poprzedniego
- ZATRZYMUJE SIĘ i raportuje jeśli dane są niejednoznaczne lub brakujące

---

## Operator Gate

<Wypełnij tylko gdy blast_radius: HIGH lub CRITICAL. Usuń tę sekcję dla LOW/MEDIUM.>

```
---
STOP. OPERATOR GATE

Blast radius:  <HIGH | CRITICAL>
Tryb:          <execution_mode>
Sesja:         <projekt / środowisko>

Pending actions:
  1. <działanie 1>
  2. <działanie 2>

Ryzyko:
  - <ryzyko 1>

Oczekuję explicit approval przed kontynuacją.
Powiedz "tak, wykonaj [1/2/all]" lub "anuluj".
---
```

---

## Zapis do vault

Po zakończeniu skilla, wyniki trafiają do:

```
<ścieżka/do/session-log.md> — log sesji projektu
<ścieżka/do/now.md> — aktualizacja active context (jeśli zmienił się stan)
```

Frontmatter notatki z wynikiem:
```yaml
generated_by: claude
source_skill: categories/<kategoria>/<nazwa-skilla>
```
```

- [ ] **Krok 2: Weryfikacja sekcji**

```bash
grep "^## " _system/superpowers/SKILL-TEMPLATE.md
```

Oczekiwany output:
```
## Jak używać
## FRONTMATTER (wymagany, skopiuj i wypełnij)
## Cel
## Kontekst wejściowy
## Wykonanie
## Format outputu
## Guardrails
## Operator Gate
## Zapis do vault
```

- [ ] **Krok 3: Commit**

```bash
git add _system/superpowers/SKILL-TEMPLATE.md
git commit -m "superpowers: dodaj SKILL-TEMPLATE — szablon dla nowych skillów"
```

---

## Task 8: bootstrap/project-bootstrap.md

**Files:**
- Create: `_system/superpowers/bootstrap/project-bootstrap.md`

- [ ] **Krok 1: Utwórz project-bootstrap.md**

```markdown
---
title: Project Bootstrap — Superpowers
type: bootstrap
category: bootstrap
status: active
blast_radius: LOW
execution_mode: read-only
domain: client-work
context_sources:
  - 20-projects/clients/<klient>/<projekt>/<projekt>-context.md
  - 02-active-context/now.md
  - 02-active-context/current-focus.md
guardrails:
  - read-only — brak write actions w tym bootstrapie
  - jeden projekt per sesja
classification: internal
llm_exposure: allowed
created: 2026-05-18
updated: 2026-05-18
tags: [superpowers, bootstrap, project, context-loader]
---

# Project Bootstrap

Ładuje kontekst projektu na początku sesji roboczej.
Redukuje cold-start time po przerwie.

Nie zastępuje: [[AGENT_BOOTSTRAP]] — obowiązkowy bootstrap systemowy wciąż obowiązuje.

---

## Jak uruchomić

```
Użyj @_system/superpowers/bootstrap/project-bootstrap.md.
Projekt: <nazwa>.
Klient: <klient|internal>.
Domena: <client-work|internal-product-strategy>.
```

---

## Parametry

```
Wymagane:
  - projekt:  <nazwa projektu, np. maspex>
  - klient:   <klient, np. mako | internal>
  - domena:   <client-work | internal-product-strategy>

Opcjonalne:
  - środowisko: <prod|uat|dev> [domyślnie: nie zakładaj]
  - fokus:      <konkretny problem lub zadanie> [domyślnie: ogólny kontekst]
```

---

## Wykonanie

### Krok 1: Identyfikacja domeny i kontrakty bezpieczeństwa

Sprawdź:
1. Domena = zadeklarowana w parametrach
2. Jedna sesja = jedna domena (nie mieszaj)
3. Kontrakty `_system/` załadowane (AGENT_BOOTSTRAP wymagany)

### Krok 2: Ładowanie kontekstu projektu

Załaduj w kolejności (minimal context first):

```
Priorytet 1 (obowiązkowy):
  @02-active-context/now.md — aktualny stan operacyjny

Priorytet 2 (projekt):
  @20-projects/clients/<klient>/<projekt>/<projekt>-context.md
  lub
  @20-projects/internal/<projekt>/<projekt>-context.md (jeśli internal)

Priorytet 3 (opcjonalny, jeśli fokus podany):
  @40-runbooks/<kategoria>/<runbook>.md — konkretny runbook
  @20-projects/clients/<klient>/<projekt>/session-log.md — ostatnie 5 wpisów
```

### Krok 3: Wygeneruj orientację

Format (evidence-first):

```
[ORIENTACJA: <projekt> / <klient> / <data>]

## Stan projektu
- Ostatni update: <data z now.md>
- Aktywne zadanie: <z now.md>
- Open issues: <z now.md lub session-log>

## Aktywny fokus
- <z current-focus.md lub kontekstu projektu>

## Blokery / oczekiwania
- <z waiting-for.md lub kontekstu>

## Środowisko
- Stack: <z context.md>
- AWS profile: <z context.md>
- Repo: <z context.md>

## Proponowane next steps
- [ ] <krok 1 wynikający z kontekstu>
- [ ] <krok 2>
```

### Krok 4: Zaproponuj skill

Na podstawie aktywnego zadania zaproponuj konkretny skill:

```
Sugestia: aktywne zadanie dotyczy <tematu>.
Dostępne skille: @_system/superpowers/categories/<kategoria>/
Użyj: <konkretna ścieżka do skilla jeśli istnieje>
```

---

## Guardrails

- NIE zakładaj środowiska bez danych z context.md
- NIE ładuj całego session-log — tylko ostatnie 5 wpisów
- NIE mieszaj kontekstu wielu projektów w jednej sesji
- ZATRZYMAJ SIĘ jeśli context.md nie istnieje — poproś o ścieżkę

---

## Zapis do vault

Bootstrap nie generuje nowej notatki.
Jeśli orientacja ujawniła zmianę stanu:
→ zaktualizuj `02-active-context/now.md` (delta, nie rewrite)
```

- [ ] **Krok 2: Weryfikacja**

```bash
grep "blast_radius\|execution_mode\|## Wykonanie\|## Guardrails" \
  _system/superpowers/bootstrap/project-bootstrap.md
```

Oczekiwany output zawiera linie z tymi 4 elementami.

- [ ] **Krok 3: Commit**

```bash
git add _system/superpowers/bootstrap/project-bootstrap.md
git commit -m "superpowers: dodaj project-bootstrap — context loader dla sesji roboczej"
```

---

## Task 9: bootstrap/incident-bootstrap.md

**Files:**
- Create: `_system/superpowers/bootstrap/incident-bootstrap.md`

- [ ] **Krok 1: Utwórz incident-bootstrap.md**

```markdown
---
title: Incident Bootstrap — Superpowers
type: bootstrap
category: bootstrap
status: active
blast_radius: MEDIUM
execution_mode: advisory
domain: client-work
context_sources:
  - 40-runbooks/incidents/
  - 20-projects/clients/<klient>/<projekt>/<projekt>-context.md
  - 02-active-context/now.md
guardrails:
  - advisory only — brak write actions bez explicit gate
  - diagnostyka przed remediacją
  - blast_radius rośnie do HIGH jeśli remediation proposed
classification: internal
llm_exposure: allowed
created: 2026-05-18
updated: 2026-05-18
tags: [superpowers, bootstrap, incident, emergency, rca]
---

# Incident Bootstrap

Bootstrap dla incydentów i awarii. Ładuje kontekst operacyjny, inicjuje diagnostykę.

**Tryb domyślny: advisory** — analiza i rekomendacje. Write actions wymagają escalacji do `execute` z Operator Gate.

---

## Jak uruchomić

```
Użyj @_system/superpowers/bootstrap/incident-bootstrap.md.
Incydent: <opis objawu>.
Projekt: <nazwa>. Środowisko: <prod|uat>.
Czas wystąpienia: <HH:MM CEST lub "właśnie teraz">.
```

---

## Parametry

```
Wymagane:
  - opis:         <objaw, np. "5xx na ALB", "ECS tasks crashing", "Redis high latency">
  - projekt:      <nazwa projektu>
  - środowisko:   <prod|uat|dev>
  - czas:         <kiedy wystąpił lub "teraz">

Opcjonalne:
  - zakres:       <co działa, co nie działa — jeśli wiadomo>
  - alerty:       <linki do CloudWatch alarmów lub metryk>
  - last-change:  <ostatnia zmiana wdrożona przed incydentem>
```

---

## Wykonanie

### Krok 1: Triage (pierwsze 2 minuty)

Załaduj minimalny kontekst:
```
@02-active-context/now.md — ostatni znany stan
@20-projects/clients/<klient>/<projekt>/<projekt>-context.md — stack i konfiguracja
```

Zidentyfikuj natychmiast:
- Środowisko: prod/uat/dev
- Blast radius incydentu: ile użytkowników/serwisów dotkniętych
- Czy jest aktywna zmiana (deploy, IaC apply) — jeśli tak → podejrzana przyczyna

### Krok 2: Załaduj runbook

Dobierz runbook na podstawie opisu:

| Objaw | Runbook |
|-------|---------|
| ECS tasks crashing / OOMKilled | `@40-runbooks/ecs/<runbook>.md` |
| ALB 5xx / Target unhealthy | `@40-runbooks/aws/alb-*.md` |
| CloudFront errors | `@40-runbooks/aws/cloudfront-*.md` |
| Redis latency / evictions | `@40-runbooks/ecs/redis-*.md` lub context projektu |
| Terraform apply failure | `@40-runbooks/terraform/`.md` |
| DNS / cert issue | `@40-runbooks/networking/*.md` |

Jeśli brak runbooka dla danego objawu → poinformuj i kontynuuj bez niego.

### Krok 3: Diagnostyka read-only

Komendy diagnostyczne (tylko read-only — nie modyfikuj):

```bash
# ECS — stan serwisu i tasków
aws ecs describe-services --cluster <klaster> --services <serwis> \
  --profile <profil> --region <region>

# ALB — stan target group
aws elbv2 describe-target-health \
  --target-group-arn <arn> --profile <profil>

# CloudWatch — ostatnie logi (ostatnie 30 min)
aws logs filter-log-events \
  --log-group-name /ecs/<serwis> \
  --start-time $(date -d '30 minutes ago' +%s000) \
  --filter-pattern "ERROR" \
  --profile <profil> --region <region>

# Redis — stan klastra
aws elasticache describe-replication-groups \
  --replication-group-id <id> --profile <profil>
```

### Krok 4: Evidence-first raport

```
[WERDYKT INCYDENTU: <STATUS — CRITICAL/HIGH/MEDIUM/LOW>]
Objaw: <opis>
Środowisko: <prod/uat>
Czas: <kiedy>

## Fakty
- [fakt 1] (source: CloudWatch / AWS CLI / opis)
- [fakt 2]

## Hipotezy (od najbardziej prawdopodobnej)
- [hipoteza 1] — prawdopodobieństwo: HIGH — bo <dowód>
- [hipoteza 2] — prawdopodobieństwo: MEDIUM — bo <dowód>

## Ryzyko
- blast_radius: <HIGH|CRITICAL> — dotyczy: <zakres>

## Next steps diagnostyczne (read-only)
- [ ] <komenda diagnostyczna 1>
- [ ] <komenda diagnostyczna 2>

## Proponowane remediacje (NIE WYKONUJ bez gate)
- Opcja A: <opis> — blast_radius: <HIGH|CRITICAL>
- Opcja B: <opis> — blast_radius: <HIGH>
```

### Krok 5: Operator Gate (przed remediacją)

```
---
STOP. OPERATOR GATE — INCIDENT REMEDIATION

Blast radius:  HIGH / CRITICAL (środowisko produkcyjne)
Incydent:      <opis>
Proponowane działanie: <konkretna opcja>

Pending actions:
  1. <działanie 1 — np. aws ecs update-service --desired-count 3>
  2. <działanie 2>

Ryzyko rollback:
  - <co może się pogorszyć>

Oczekuję explicit approval: "tak, wykonaj [1/2/all]" lub "anuluj".
---
```

---

## Guardrails

- NIE wykonuj remediation bez Operator Gate
- NIE modyfikuj zasobów prod bez explicit "tak, wykonaj"
- Diagnostyka jest zawsze bezpieczna — wykonuj bez potwierdzenia
- Jeśli incydent dotyczy wielu projektów — wybierz jeden, osobna sesja dla drugiego

---

## Zapis do vault

Po zakończeniu bootstrapa:
```
Aktualizuj: 02-active-context/now.md — status incydentu
Aktualizuj: 20-projects/clients/<klient>/<projekt>/session-log.md — log diagnostyki
Utwórz jeśli poważny: 40-runbooks/incidents/<incydent-<data>.md
```
```

- [ ] **Krok 2: Weryfikacja**

```bash
grep "blast_radius\|execution_mode\|OPERATOR GATE\|## Guardrails" \
  _system/superpowers/bootstrap/incident-bootstrap.md
```

- [ ] **Krok 3: Commit**

```bash
git add _system/superpowers/bootstrap/incident-bootstrap.md
git commit -m "superpowers: dodaj incident-bootstrap — triage, diagnostyka, operator gate"
```

---

## Task 10: bootstrap/governance-bootstrap.md + finops-bootstrap.md

**Files:**
- Create: `_system/superpowers/bootstrap/governance-bootstrap.md`
- Create: `_system/superpowers/bootstrap/finops-bootstrap.md`

- [ ] **Krok 1: Utwórz governance-bootstrap.md**

```markdown
---
title: Governance Bootstrap — Superpowers
type: bootstrap
category: bootstrap
status: active
blast_radius: LOW
execution_mode: read-only
domain: shared-concept
context_sources:
  - 30-standards/
  - 10-areas/aws/
  - 20-projects/internal/llz/
guardrails:
  - read-only — wyniki są rekomendacjami, nie akcjami
  - nie modyfikuj SCP bez osobnej sesji execute
  - anonimizuj dane klientów przed eksportem
classification: internal
llm_exposure: allowed
created: 2026-05-18
updated: 2026-05-18
tags: [superpowers, bootstrap, governance, scp, tagging, compliance]
---

# Governance Bootstrap

Bootstrap dla przeglądów governance: tagging, SCP, LLZ compliance, standardy IaC.

**Tryb: read-only** — generuje gap report i rekomendacje. Nie modyfikuje zasobów.

---

## Jak uruchomić

```
Użyj @_system/superpowers/bootstrap/governance-bootstrap.md.
Zakres: <tagging | scp | llz-compliance | iac-standards | all>.
Projekt: <nazwa | all-projects>.
Domena: <client-work | internal-product-strategy>.
```

---

## Parametry

```
Wymagane:
  - zakres:    <tagging|scp|llz-compliance|iac-standards|all>
  - projekt:   <konkretny projekt lub "all-projects">
  - domena:    <client-work|internal-product-strategy>

Opcjonalne:
  - konto-aws: <account ID lub nazwa profilu>
  - region:    <eu-west-1|eu-central-1> [domyślnie: sprawdź context.md]
```

---

## Wykonanie

### Krok 1: Ładowanie standardów

```
@30-standards/aws-tagging.md — mandatory tags i wartości
@30-standards/iac.md — konwencje Terraform/CloudFormation
@20-projects/internal/llz/ — LLZ platform standards
```

### Krok 2: Ładowanie kontekstu projektu

```
@20-projects/clients/<klient>/<projekt>/<projekt>-context.md
lub
@20-projects/internal/<projekt>/<projekt>-context.md
```

### Krok 3: Analiza per zakres

**Tagging audit:**
```bash
aws resourcegroupstaggingapi get-resources \
  --tag-filters "Key=Environment" \
  --profile <profil> --region <region> \
  | jq '.ResourceTagMappingList[] | select(.Tags | length < 4)'
```

**SCP review (read-only):**
```bash
aws organizations list-policies --filter SERVICE_CONTROL_POLICY \
  --profile mako-dc
aws organizations describe-policy --policy-id <id> \
  --profile mako-dc
```

**IaC drift:**
```bash
cd <repo-path>
terraform plan -detailed-exitcode 2>&1 | head -100
```

### Krok 4: Gap report (evidence-first)

```
[WERDYKT GOVERNANCE: <projekt> — <COMPLIANT|NON-COMPLIANT|PARTIAL>]

## Fakty — tagging
- Zasoby bez mandatory tags: <liczba> (source: resourcegroupstaggingapi)
- Brakujące tagi: <lista>

## Fakty — SCP / LLZ
- Aktywne SCP: <lista>
- Niezgodności z LLZ baseline: <lista>

## Fakty — IaC standards
- Drift: <tak/nie, ile zasobów>

## Hipotezy
- <hipoteza 1>

## Ryzyko
- blast_radius: LOW (to jest audit)

## Rekomendacje
- [ ] <remediation 1> — priorytet: HIGH
- [ ] <remediation 2> — priorytet: MEDIUM
```

---

## Guardrails

- NIE modyfikuj SCP — generuj propozycję do review
- NIE zakładaj compliance na podstawie IaC — weryfikuj vs runtime AWS
- Anonimizuj ARNy i account IDs przed eksportem do shared vault
```

- [ ] **Krok 2: Utwórz finops-bootstrap.md**

```markdown
---
title: FinOps Bootstrap — Superpowers
type: bootstrap
category: bootstrap
status: active
blast_radius: LOW
execution_mode: read-only
domain: client-work
context_sources:
  - 70-finops/
  - 20-projects/clients/<klient>/<projekt>/finops-*.md
  - 50-patterns/finops/
guardrails:
  - read-only — wyniki są rekomendacjami, nie akcjami
  - cost data może zawierać dane wrażliwe — nie eksportuj bez anonimizacji
classification: internal
llm_exposure: allowed
created: 2026-05-18
updated: 2026-05-18
tags: [superpowers, bootstrap, finops, cost-optimization, aws-cost]
---

# FinOps Bootstrap

Bootstrap dla analiz kosztów AWS: miesięczny przegląd, anomalie, optymalizacja.

**Tryb: read-only** — generuje raport i rekomendacje. Nie modyfikuje zasobów.

---

## Jak uruchomić

```
Użyj @_system/superpowers/bootstrap/finops-bootstrap.md.
Projekt: <nazwa | all>.
Zakres: <miesięczny | anomalia | optymalizacja | all>.
Okres: <YYYY-MM | last-30-days | last-7-days>.
```

---

## Parametry

```
Wymagane:
  - projekt:   <nazwa projektu lub "all">
  - zakres:    <miesięczny|anomalia|optymalizacja|all>
  - okres:     <YYYY-MM lub last-30-days>

Opcjonalne:
  - konto-aws: <account ID lub profil>
  - próg:      <kwota USD anomalii> [domyślnie: 10% wzrost MoM]
```

---

## Wykonanie

### Krok 1: Ładowanie kontekstu FinOps

```
@70-finops/ — przeglądy historyczne
@20-projects/clients/<klient>/<projekt>/finops-*.md — projekt-specyficzny kontekst
```

### Krok 2: Dane kosztów (read-only)

```bash
# Koszty per serwis — ostatnie 30 dni
aws ce get-cost-and-usage \
  --time-period Start=$(date -d '30 days ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics "BlendedCost" \
  --group-by Type=DIMENSION,Key=SERVICE \
  --profile <profil>

# Top 10 najdroższych zasobów
aws ce get-cost-and-usage \
  --time-period Start=$(date -d '30 days ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics "BlendedCost" \
  --group-by Type=TAG,Key=Name \
  --profile <profil>
```

### Krok 3: Raport FinOps (evidence-first)

```
[WERDYKT FINOPS: <projekt> / <okres>]
Łączny koszt: $<X> (vs $<Y> poprzedni okres — <+/-Z%>)

## Fakty — koszty per serwis
| Serwis | Koszt | Delta MoM |
|--------|-------|-----------|
| EC2    | $X    | +Y%       |
| RDS    | $X    | -Y%       |

## Anomalie
- <serwis>: wzrost o <X%> — potencjalna przyczyna: <hipoteza>

## Hipotezy
- <hipoteza 1> — prawdopodobieństwo: HIGH

## Ryzyko
- blast_radius: LOW

## Rekomendacje optymalizacyjne
- [ ] <optymalizacja 1> — potencjalna oszczędność: $X/mies.
- [ ] <optymalizacja 2>
```

---

## Guardrails

- NIE zakładaj że koszt = problem bez porównania z baseline
- NIE eksportuj account IDs ani konkretnych kwot do shared vault bez anonimizacji
- Cost data: tylko `internal` lub wyżej — nigdy `public`

---

## Zapis do vault

```
Nowy raport: 70-finops/<projekt>-finops-<YYYY-MM>.md
Jeśli anomalia: 20-projects/clients/<klient>/<projekt>/session-log.md
```
```

- [ ] **Krok 3: Weryfikacja obu plików**

```bash
ls _system/superpowers/bootstrap/
```

Oczekiwany output:
```
finops-bootstrap.md
governance-bootstrap.md
incident-bootstrap.md
project-bootstrap.md
```

- [ ] **Krok 4: Commit**

```bash
git add _system/superpowers/bootstrap/governance-bootstrap.md \
        _system/superpowers/bootstrap/finops-bootstrap.md
git commit -m "superpowers: dodaj governance-bootstrap i finops-bootstrap"
```

---

## Task 11: Categories — scaffold 10 README

**Files:**
- Create: README.md w każdym z 10 katalogów categories/

- [ ] **Krok 1: aws/README.md**

```markdown
# Kategoria: AWS

Skille dla zasobów AWS: CloudFront, S3, ACM, Route53, IAM, EC2, VPC.

Zakres: operacje read-only (audyt, analiza, diagnostyka) oraz write z explicit gate.
Blast radius: LOW–CRITICAL (zależnie od serwisu).

Przykładowe skille do stworzenia:
- cloudfront-cache-analysis.md
- acm-cert-expiry-check.md
- s3-bucket-policy-audit.md
- iam-drift-analysis.md
- vpc-security-group-review.md
```

- [ ] **Krok 2: ecs/README.md**

```markdown
# Kategoria: ECS

Skille dla Amazon ECS Fargate: service health, task definitions, scaling, logging.

Zakres: diagnostyka (read-only domyślnie), scaling i deploy z operator gate.
Blast radius: MEDIUM (staging) / HIGH (prod).

Przykładowe skille do stworzenia:
- ecs-service-health-check.md
- ecs-task-definition-diff.md
- ecs-scaling-analysis.md
- ecs-container-insights-review.md
```

- [ ] **Krok 3: terraform/README.md**

```markdown
# Kategoria: Terraform

Skille dla IaC Terraform: plan review, drift detection, module audit, changeset.

Zakres: plan i drift jako read-only; apply wymaga execute mode z gate.
Blast radius: MEDIUM (plan/drift) / HIGH–CRITICAL (apply).

Przykładowe skille do stworzenia:
- terraform-plan-review.md
- terraform-drift-detection.md
- terraform-module-audit.md
- terraform-state-health.md
```

- [ ] **Krok 4: cloudformation/README.md**

```markdown
# Kategoria: CloudFormation

Skille dla AWS CloudFormation: stack analysis, rollback diagnostics, changeset review.

Zakres: describe i analiza jako read-only; update/deploy z gate.
Blast radius: MEDIUM (changeset review) / HIGH–CRITICAL (update/deploy).

Przykładowe skille do stworzenia:
- cfn-stack-analysis.md
- cfn-rollback-analysis.md
- cfn-changeset-review.md
- cfn-drift-detection.md
```

- [ ] **Krok 5: finops/README.md**

```markdown
# Kategoria: FinOps

Skille dla analizy kosztów AWS: Cost Explorer, budgets, anomaly detection, optimization.

Zakres: wyłącznie read-only i advisory — rekomendacje, nie akcje.
Blast radius: LOW (analysis).

Przykładowe skille do stworzenia:
- cost-monthly-review.md
- cost-anomaly-investigation.md
- tagging-gap-analysis.md
- reserved-instance-recommendation.md
```

- [ ] **Krok 6: governance/README.md**

```markdown
# Kategoria: Governance

Skille dla governance: SCP review, LLZ compliance, tagging standards, security posture.

Zakres: read-only dla audytu; SCP changes wymagają execute mode z CRITICAL gate.
Blast radius: LOW (audit) / CRITICAL (SCP changes).

Przykładowe skille do stworzenia:
- scp-review.md
- llz-compliance-check.md
- tagging-standards-audit.md
- security-posture-review.md
```

- [ ] **Krok 7: incidents/README.md**

```markdown
# Kategoria: Incidents

Skille dla incident response: diagnostyka, RCA, post-mortem.

Zakres: diagnostyka read-only; remediation wymaga execute mode z HIGH/CRITICAL gate.
Blast radius: MEDIUM (diagnostyka) / HIGH–CRITICAL (remediation prod).

Przykładowe skille do stworzenia:
- ecs-incident-triage.md
- alb-5xx-investigation.md
- redis-incident-response.md
- cloudfront-origin-failure.md
- rca-template.md
```

- [ ] **Krok 8: observability/README.md**

```markdown
# Kategoria: Observability

Skille dla observability: CloudWatch alarms, dashboards, log analysis, Container Insights.

Zakres: read-only dla analizy; tworzenie alarmów z advisory/dry-run.
Blast radius: LOW (analiza) / MEDIUM (konfiguracja alarmów).

Przykładowe skille do stworzenia:
- cloudwatch-alarm-review.md
- log-analysis-pattern.md
- container-insights-analysis.md
- dashboard-health-check.md
```

- [ ] **Krok 9: onboarding/README.md**

```markdown
# Kategoria: Onboarding

Skille dla onboardingu: nowy projekt (cloud-detective), nowy junior, projekt handoff.

Zakres: read-only i advisory — generowanie dokumentacji i checklist.
Blast radius: LOW.

Przykładowe skille do stworzenia:
- new-project-context.md     (cloud-detective — generowanie context.md)
- junior-onboarding.md       (guided tour po projekcie)
- project-handoff-pack.md    (przygotowanie paczki do przekazania)
```

- [ ] **Krok 10: chatgpt/README.md**

```markdown
# Kategoria: ChatGPT Workflows

Skille dla workflow ChatGPT: przygotowanie context packów, eksport, import wyników.

Zakres: read-only (przygotowanie paczek) i advisory (import wyników).
Blast radius: LOW.

Kontrakt: vault → context pack → ChatGPT → notatka z wynikiem → vault.
NIE wklejaj danych restricted do kontekstu ChatGPT.

Przykładowe skille do stworzenia:
- context-pack-generator.md
- conversation-import.md
- domain-boundary-checker.md
```

- [ ] **Krok 11: Skopiuj każdy README do właściwego katalogu (lub użyj Write tool bezpośrednio)**

Zapisz każdą treść do odpowiedniego pliku:
```bash
# Weryfikacja po zapisaniu wszystkich README
ls _system/superpowers/categories/*/README.md | wc -l
```

Oczekiwany output: `10`

- [ ] **Krok 12: Commit**

```bash
git add _system/superpowers/categories/
git commit -m "superpowers: scaffold 10 kategorii skillów z README"
```

---

## Task 12: examples/rshop-cfn-analysis.md

**Files:**
- Create: `_system/superpowers/examples/rshop-cfn-analysis.md`

- [ ] **Krok 1: Utwórz rshop-cfn-analysis.md**

Przykład demonstruje: skill cloudformation/cfn-stack-analysis w akcji dla projektu rshop.
Dane są sanitized (nie zawierają rzeczywistych ARN ani kont).

```markdown
---
title: Przykład — Analiza CloudFormation Stack (rshop)
type: example
category: cloudformation
status: active
blast_radius: LOW
execution_mode: read-only
domain: client-work
classification: internal
llm_exposure: allowed
created: 2026-05-18
updated: 2026-05-18
tags: [superpowers, example, cloudformation, rshop]
---

# Przykład: Analiza CloudFormation — rshop

Demonstruje użycie superpowers dla analizy stanu stacka CloudFormation.
Projekt: rshop (sanitized). Środowisko: staging.

---

## Jak uruchomić

```
Użyj @_system/superpowers/categories/cloudformation/cfn-stack-analysis.md.
Projekt: rshop. Środowisko: staging. Profil AWS: rshop-staging.
Stack: rshop-app-staging.
```

## Kontekst wejściowy (co załadować)

```
@20-projects/clients/mako/rshop/rshop-context.md   — runtime state
@30-standards/iac.md                                — IaC standards
```

---

## Wykonanie (przykład)

### Krok 1: Describe stack

```bash
aws cloudformation describe-stacks \
  --stack-name rshop-app-staging \
  --profile rshop-staging \
  --region eu-central-1 \
  --query 'Stacks[0].{Status:StackStatus,Updated:LastUpdatedTime,Outputs:Outputs}'
```

Przykładowy output:
```json
{
  "Status": "UPDATE_COMPLETE",
  "Updated": "2026-05-10T14:23:00Z",
  "Outputs": [
    {"OutputKey": "ALBDnsName", "OutputValue": "rshop-alb-123.eu-central-1.elb.amazonaws.com"}
  ]
}
```

### Krok 2: Drift detection

```bash
aws cloudformation detect-stack-drift \
  --stack-name rshop-app-staging \
  --profile rshop-staging

# Poczekaj ~60s, potem:
aws cloudformation describe-stack-drift-detection-status \
  --stack-drift-detection-id <id-z-powyższego>
```

### Krok 3: Resources z drift

```bash
aws cloudformation describe-stack-resource-drifts \
  --stack-name rshop-app-staging \
  --stack-resource-drift-status-filters MODIFIED DELETED \
  --profile rshop-staging
```

---

## Output (evidence-first format)

```
[WERDYKT: rshop-app-staging — STATUS: UPDATE_COMPLETE, DRIFT: 1 zasób]

## Fakty
- Stack status: UPDATE_COMPLETE (source: describe-stacks)
- Ostatnia aktualizacja: 2026-05-10 14:23 UTC
- Drift detection: 1 zasób MODIFIED (source: describe-stack-resource-drifts)
  - Zasób: AWS::ECS::Service/rshop-api-service
  - Zmiana: desiredCount 2 → 3 (zmienione poza IaC)

## Hipotezy
- Manual scaling event 2026-05-10 — prawdopodobieństwo: HIGH
  (pasuje czasowo do ostatniej aktualizacji stacka)

## Ryzyko
- blast_radius: LOW (to jest audit)
- Przy następnym `cfn deploy` desiredCount wróci do 2 z IaC

## Next steps
- [ ] Weryfikacja: czy manual scaling był intencjonalny
- [ ] Jeśli tak: zaktualizuj IaC (task definition) desiredCount → 3
- [ ] Jeśli nie: zidentyfikuj kto zmienił i kiedy (CloudTrail)
```

---

## Czego ten przykład uczy

1. **Blast radius: LOW** dla read-only analizy — brak gate
2. **Fakty z source** — każde twierdzenie ma wskazany zasób/komendę
3. **Hipoteza oddzielna od faktu** — drift jest faktem, przyczyna jest hipotezą
4. **Konkretny next step** — nie "sprawdź IaC", ale "zaktualizuj desiredCount → 3"
```

- [ ] **Krok 2: Commit**

```bash
git add _system/superpowers/examples/rshop-cfn-analysis.md
git commit -m "superpowers: dodaj przykład rshop-cfn-analysis"
```

---

## Task 13: examples/llz-governance-review.md

**Files:**
- Create: `_system/superpowers/examples/llz-governance-review.md`

- [ ] **Krok 1: Utwórz llz-governance-review.md**

```markdown
---
title: Przykład — LLZ Governance Review
type: example
category: governance
status: active
blast_radius: LOW
execution_mode: read-only
domain: internal-product-strategy
classification: internal
llm_exposure: allowed
created: 2026-05-18
updated: 2026-05-18
tags: [superpowers, example, governance, llz, scp, tagging]
---

# Przykład: LLZ Governance Review

Demonstruje użycie governance-bootstrap dla przeglądu LLZ compliance.
Domena: internal-product-strategy. Dane: sanitized.

---

## Jak uruchomić

```
Użyj @_system/superpowers/bootstrap/governance-bootstrap.md.
Zakres: llz-compliance.
Projekt: llz. Domena: internal-product-strategy.
```

---

## Kontekst wejściowy

```
@20-projects/internal/llz/llz-context.md   — LLZ platform state
@30-standards/aws-tagging.md               — mandatory tags
@20-projects/internal/llz/               — LLZ runbooki i standardy
```

---

## Wykonanie (przykład)

### Krok 1: Mandatory tags audit

```bash
aws resourcegroupstaggingapi get-resources \
  --profile mako-dc \
  --region eu-central-1 \
  --query 'ResourceTagMappingList[?!(Tags[?Key==`Environment`])].[ResourceARN]' \
  --output text | wc -l
```

Output: `47 zasobów bez tagu Environment`

### Krok 2: SCP status

```bash
aws organizations list-policies \
  --filter SERVICE_CONTROL_POLICY \
  --profile mako-dc \
  --query 'Policies[].{Name:Name,Id:Id,Description:Description}'
```

### Krok 3: LLZ baseline check

Sprawdź key resources z LLZ context.md:
- GuardDuty: enabled w każdym koncie?
- SecurityHub: enabled?
- CloudTrail: multi-region?
- Budget alerts: skonfigurowane?

---

## Output (evidence-first format)

```
[WERDYKT: LLZ Governance — PARTIAL COMPLIANCE]

## Fakty — tagging
- Zasoby bez tagu Environment: 47 (source: resourcegroupstaggingapi)
- Zasoby bez tagu Project: 23
- Affected: głównie Lambda functions i CloudWatch Log Groups

## Fakty — SCP
- Aktywne SCP: 3 (DenyRootAccess, RequireMFAForConsole, LimitRegions)
- LimitRegions: blokuje eu-north-1, ap-*, us-west-* — zgodnie z LLZ
- Gap: brak SCP dla RequireTagOnCreate

## Fakty — security baseline
- GuardDuty: enabled w 4/4 kontach ✅
- SecurityHub: enabled w 3/4 kontach ⚠️ (brak w account-dev)
- CloudTrail: multi-region w 4/4 kontach ✅
- Budget alerts: skonfigurowane w 2/4 kontach ⚠️

## Hipotezy
- Brak tagów na Lambda: provisioned bez Terraform (manual lub legacy deploy)
  — prawdopodobieństwo: HIGH (brak w IaC state)

## Ryzyko
- blast_radius: LOW (to jest audit)
- SecurityHub gap: brak visibility security findings w account-dev

## Rekomendacje
- [ ] HIGH: Dodaj RequireTagOnCreate SCP (szkic w 30-standards/aws-tagging.md)
- [ ] HIGH: Enable SecurityHub w account-dev
- [ ] MEDIUM: Tag remediation dla 47 zasobów — użyj aws-cli batch tagging
- [ ] MEDIUM: Budget alerts — skonfiguruj w brakujących kontach
```

---

## Czego ten przykład uczy

1. **Domena: internal-product-strategy** — nie client-work — separacja jest jawna
2. **Blast radius: LOW** — audit nie modyfikuje zasobów
3. **Fakty z liczb** — "47 zasobów" nie "wiele zasobów"
4. **Rekomendacje z priorytetem** — HIGH/MEDIUM/LOW, nie abstrakcyjne "rozważ"
```

- [ ] **Krok 2: Commit**

```bash
git add _system/superpowers/examples/llz-governance-review.md
git commit -m "superpowers: dodaj przykład llz-governance-review"
```

---

## Task 14: examples/finops-review.md + pbms-runtime-debug.md

**Files:**
- Create: `_system/superpowers/examples/finops-review.md`
- Create: `_system/superpowers/examples/pbms-runtime-debug.md`

- [ ] **Krok 1: Utwórz finops-review.md**

```markdown
---
title: Przykład — FinOps Monthly Review
type: example
category: finops
status: active
blast_radius: LOW
execution_mode: read-only
domain: client-work
classification: internal
llm_exposure: allowed
created: 2026-05-18
updated: 2026-05-18
tags: [superpowers, example, finops, cost-optimization]
---

# Przykład: FinOps Monthly Review

Demonstruje użycie finops-bootstrap dla miesięcznego przeglądu kosztów.
Dane: sanitized (rzeczywiste wartości zastąpione przykładowymi).

---

## Jak uruchomić

```
Użyj @_system/superpowers/bootstrap/finops-bootstrap.md.
Projekt: <projekt>.
Zakres: miesięczny.
Okres: 2026-05.
```

---

## Output (evidence-first format)

```
[WERDYKT: FinOps <projekt> — 2026-05 — ANOMALIA WYKRYTA]
Koszt miesięczny: $X.XXX (vs $Y.YYY maj → +Z%)

## Fakty — top 5 serwisów
| Serwis | Koszt | Delta MoM |
|--------|-------|-----------|
| ECS Fargate | $X | +15% |
| ElastiCache | $X | +0% |
| CloudFront | $X | -5% |
| RDS | $X | +3% |
| S3 | $X | +2% |

## Fakty — anomalia
- ECS Fargate: wzrost o 15% = $XXX więcej niż kwiecień
- Timestamp anomalii: 2026-05-11 (source: Cost Explorer daily breakdown)
- Korelacja: load test 2026-05-11 — desired_count zmieniony z 2 → 10

## Hipotezy
- Koszt wynikał z load test — prawdopodobieństwo: HIGH
  (pasuje czasowo i ilościowo do zwiększonego desired_count)
- Brak automatycznego scale-down po teście — prawdopodobieństwo: MEDIUM

## Ryzyko
- blast_radius: LOW (to jest analiza)
- Jeśli test powtórzony bez scale-down: dodatkowe $XXX/tydzień

## Rekomendacje
- [ ] HIGH: Zweryfikuj czy ECS desired_count wrócił do baseline po teście
- [ ] MEDIUM: Dodaj Cost Anomaly Alert dla ECS >20% MoM
- [ ] LOW: Rozważ Fargate Spot dla środowisk testowych (oszczędność ~70%)
```

---

## Zapis do vault

```
Utwórz: 70-finops/<projekt>-finops-2026-05.md
Aktualizuj: 20-projects/clients/<klient>/<projekt>/session-log.md
```
```

- [ ] **Krok 2: Utwórz pbms-runtime-debug.md**

`pbms` = przykładowy projekt ECS+ALB (generic — nie mapuje na konkretny projekt vault).

```markdown
---
title: Przykład — ECS/ALB Runtime Debug (pbms)
type: example
category: incidents
status: active
blast_radius: MEDIUM
execution_mode: advisory
domain: client-work
classification: internal
llm_exposure: allowed
created: 2026-05-18
updated: 2026-05-18
tags: [superpowers, example, ecs, alb, debug, incident]
---

# Przykład: ECS/ALB Runtime Debug

Demonstruje użycie incident-bootstrap dla diagnostyki problemu ECS + ALB.
`pbms` = przykładowy projekt (generic). Dane: sanitized.

Scenariusz: ALB Target Group healthcheck failing, 50% tasków draining.

---

## Jak uruchomić

```
Użyj @_system/superpowers/bootstrap/incident-bootstrap.md.
Incydent: ALB target group unhealthy — 50% tasków draining.
Projekt: pbms. Środowisko: prod.
Czas: 2026-05-18 15:30 CEST.
```

---

## Wykonanie (przykład)

### Krok 1: Triage

```bash
# Stan serwisu ECS
aws ecs describe-services \
  --cluster pbms-cluster \
  --services pbms-api \
  --profile pbms-prod \
  --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount,Pending:pendingCount}'
```

Output:
```json
{"Status": "ACTIVE", "Running": 1, "Desired": 2, "Pending": 0}
```

Znalezisko: Running 1/2 — jeden task drainuje.

### Krok 2: ALB health

```bash
aws elbv2 describe-target-health \
  --target-group-arn arn:aws:elasticloadbalancing:eu-west-1:123456789:targetgroup/pbms-api/abc123 \
  --profile pbms-prod
```

Output (sanitized):
```json
{
  "TargetHealthDescriptions": [
    {"Target": {"Id": "10.0.1.5"}, "TargetHealth": {"State": "healthy"}},
    {"Target": {"Id": "10.0.1.6"}, "TargetHealth": {"State": "draining", "Reason": "Target.DeregistrationInProgress"}}
  ]
}
```

### Krok 3: Logi drainującego taska

```bash
aws logs filter-log-events \
  --log-group-name /ecs/pbms-api \
  --filter-pattern "ERROR" \
  --start-time $(date -d '1 hour ago' +%s000) \
  --profile pbms-prod --region eu-west-1
```

Output: `OutOfMemoryError: Container killed` — OOMKilled.

---

## Output (evidence-first format)

```
[WERDYKT: pbms-api — PARTIAL OUTAGE — 1 task OOMKilled, 50% capacity]

## Fakty
- ECS running: 1/2 (source: describe-services)
- ALB target draining: 10.0.1.6 (source: describe-target-health)
- Root cause: OutOfMemoryError (source: CloudWatch Logs /ecs/pbms-api)
- Czas: 15:28 CEST (2 minuty przed alertem)

## Hipotezy
- Memory limit za niski dla obecnego obciążenia — prawdopodobieństwo: HIGH
  (OOMKilled + task definition memoryReservation = 512MB)
- Memory leak w aplikacji — prawdopodobieństwo: MEDIUM
  (brak historycznych OOM — może być nowy traffic spike)

## Ryzyko
- blast_radius: HIGH — produkcja, 50% capacity
- Jeśli drugi task też crashuje: 100% outage

## Next steps diagnostyczne (safe)
- [ ] aws ecs describe-task-definition --task-definition pbms-api (sprawdź memoryReservation)
- [ ] CloudWatch Container Insights: memory utilization ostatnia godzina

## Proponowane remediacje (NIE WYKONUJ bez gate)
- Opcja A: Zwiększ memoryReservation 512→1024MB + force new deployment
  — blast_radius: HIGH (prod deploy)
- Opcja B: Scale out desired_count 2→4 (buy time, nie fix)
  — blast_radius: HIGH (prod change)
```

### Operator Gate

```
---
STOP. OPERATOR GATE

Blast radius:  HIGH (środowisko produkcyjne)
Incydent:      pbms-api OOMKilled, 50% capacity

Pending actions:
  1. aws ecs update-service --desired-count 4 (scale out — buy time)
  2. Nowa task definition z memoryReservation 1024MB + force deployment

Ryzyko:
  - Akcja 1: bezpieczna — tylko skalowanie
  - Akcja 2: nowy deploy — ryzyko rolling update failure jeśli app nie startuje

Oczekuję explicit approval: "tak, wykonaj [1/2/all]" lub "anuluj".
---
```

---

## Czego ten przykład uczy

1. **Triage first** — stan serwisu przed logiką remediacji
2. **Fakty z konkretnych komend** — nie "ALB ma problem" ale "10.0.1.6 draining"
3. **Root cause jako hipoteza** — OOM jest faktem, przyczyna OOM jest hipotezą
4. **Gate przed write** — nawet scale out wymaga explicit approval na prod
```

- [ ] **Krok 3: Commit**

```bash
git add _system/superpowers/examples/finops-review.md \
        _system/superpowers/examples/pbms-runtime-debug.md
git commit -m "superpowers: dodaj przykłady finops-review i pbms-runtime-debug"
```

---

## Task 15: Integracja z AGENT_BOOTSTRAP.md

**Files:**
- Modify: `_system/AGENT_BOOTSTRAP.md`

- [ ] **Krok 1: Przeczytaj aktualną sekcję Krok 1 w AGENT_BOOTSTRAP.md**

```bash
grep -n "Krok 1\|superpowers\|_system/A" _system/AGENT_BOOTSTRAP.md | head -20
```

- [ ] **Krok 2: Dodaj wzmiankę o superpowers po istniejącej liście kontraktów**

W sekcji `### Krok 1 — załadowanie kontraktów systemowych`, po istniejącej liście 4 plików, dodaj:

```markdown
Jeśli sesja używa guided workflow lub bootstrap:
→ załaduj `_system/superpowers/README.md` (opcjonalne, na żądanie operatora)
→ NIE jest obowiązkowe dla każdej sesji
→ używaj gdy operator poda `@_system/superpowers/` jako kontekst
```

- [ ] **Krok 3: Weryfikacja**

```bash
grep -A3 "superpowers" _system/AGENT_BOOTSTRAP.md
```

- [ ] **Krok 4: Commit**

```bash
git add _system/AGENT_BOOTSTRAP.md
git commit -m "superpowers: dodaj wzmiankę w AGENT_BOOTSTRAP — opcjonalny guided workflow layer"
```

---

## Self-Review

### Pokrycie specyfikacji

| Wymaganie | Task | Status |
|-----------|------|--------|
| `_system/superpowers/` katalog | Task 1 | ✅ |
| README.md | Task 2 | ✅ |
| SUPERPOWERS-CONTRACT.md | Task 3 | ✅ |
| SAFETY-CONTRACT.md | Task 4 | ✅ |
| CONTEXT-GOVERNANCE.md | Task 5 | ✅ |
| EXECUTION-MODES.md | Task 6 | ✅ |
| SKILL-TEMPLATE.md | Task 7 | ✅ |
| bootstrap/project-bootstrap.md | Task 8 | ✅ |
| bootstrap/incident-bootstrap.md | Task 9 | ✅ |
| bootstrap/governance-bootstrap.md | Task 10 | ✅ |
| bootstrap/finops-bootstrap.md | Task 10 | ✅ |
| categories/ (10 katalogów) | Task 11 | ✅ |
| examples/rshop-cfn-analysis.md | Task 12 | ✅ |
| examples/llz-governance-review.md | Task 13 | ✅ |
| examples/finops-review.md | Task 14 | ✅ |
| examples/pbms-runtime-debug.md | Task 14 | ✅ |
| READ-ONLY domyślny tryb | Task 4,6 | ✅ |
| Blast radius levels | Task 4 | ✅ |
| Forbidden actions lista | Task 4 | ✅ |
| Operator Gate format | Task 4 | ✅ |
| Evidence-first format | Task 6 | ✅ |
| Domain isolation | Task 5 | ✅ |
| Minimal context | Task 5 | ✅ |
| ADHD-aware UX | Task 5 | ✅ |
| Cost-aware tiers S/M/P | Task 6 | ✅ |
| Source of truth = vault | Task 3 | ✅ |
| Integracja z istniejącymi kontraktami | Task 15 | ✅ |

### Placeholders check

Żaden plik w planie nie zawiera "TBD", "TODO", "implement later".
Każdy plik ma kompletną treść lub szczegółową strukturę z wypełnionymi sekcjami.

### Spójność nazw i ścieżek

- `SAFETY-CONTRACT.md` — spójne przez cały plan
- `CONTEXT-GOVERNANCE.md` — spójne
- `EXECUTION-MODES.md` — spójne
- `blast_radius` (frontmatter key) — spójne
- `execution_mode` (frontmatter key) — spójne
- Ścieżki vault: `_system/superpowers/` — spójne
- Wiki-links: `[[SAFETY-CONTRACT]]` format — spójne
