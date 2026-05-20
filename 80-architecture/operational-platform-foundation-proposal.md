---
title: Operational Platform Foundation — Architecture Proposal
date: 2026-05-20
domain: internal-product-strategy
origin: own
classification: internal
llm_exposure: restricted
cross_domain_export: summary-only
source_of_truth: vault
status: proposal — awaiting review
tags: [architecture, platform, vault, ai-assisted, devops, proposal, adr]
---

# Operational Platform Foundation — Architecture Proposal

**Data:** 2026-05-20  
**Kontekst:** Propozycja strategiczna przebudowy vault → AI-assisted operational platform dla wielu klientów  
**Baseline:** tag `last-stable-version` → commit `449df1c`  
**Branch roboczy:** `feat/operational-platform-foundation`

> Powiązane decyzje: [[decision-log]] ADR-001  
> Stan przed propozycją: [[planodkupow-finops-delta-2026-05-20]], [[maspex/session-log]]

---

## 1. Current State Assessment

### 1.1 Mocne strony obecnego systemu

| Obszar | Stan | Ocena |
|--------|------|-------|
| Governance contracts | 20 plików w `_system/` z pełną taksonomią | ★★★★★ |
| Domain isolation | Cztery twarde domeny, MUST/MUST NOT wymuszone kontrakt | ★★★★★ |
| Operational entry point | `now.md` aktualizowany codziennie, real-time state | ★★★★☆ |
| Cost-aware AI | 3-tiered S/M/P routing z jasną eskalacją | ★★★★☆ |
| Context export | 23 context packs jako ChatGPT bridge | ★★★★☆ |
| Runbooks | 39 plików, AWS/ECS/Terraform/incidents coverage | ★★★★☆ |
| ADHD optimization | Standalone notes, modular, entry-point-first | ★★★★☆ |
| Authorship policy | Zero-AI-attribution, single-owner | ★★★★★ |

**Wniosek:** System jest operacyjnie dojrzały. Governance model jest przemyślany i działa. Problemem nie jest brak zasad — problemem jest **friction przy context switching** i **brak deterministycznego bootstrapu** gdy projektów jest 8+.

### 1.2 Bottlenecks — udokumentowane fakty (nie hipotezy)

**B1. Brak deterministycznego project bootstrap**  
Powrót do projektu po przerwie wymaga: przeczytania `now.md` → znalezienia sekcji projektu → zlokalizowania repo → ustalenia profilu AWS → odtworzenia stanu brancha. Każdy z tych kroków jest manualny i podatny na pominięcie. Przy 8 aktywnych projektach ten koszt kumuluje się codziennie.

**B2. Context packs driftują od vault**  
23 context packs w `_chatgpt/` są tworzone manualnie i aktualizowane reaktywnie. Między aktualizacjami zawierają stare dane. Brak mechanizmu wykrywania stale content.

**B3. Evidence collection jest reinventowana przy każdym audycie**  
Każdy audit FinOps (Maspex, planodkupow) wymaga pisania tych samych `aws ce get-cost-and-usage` / `aws ecs describe-services` od zera. Nie ma normalizedleyer który to absorbuje. Przy rosnącej liczbie klientów = rosnący koszt każdego audytu.

**B4. Cross-project navigation jest liniowa**  
Z 304 plikami i 8+ projektami nie istnieje machine-readable index który pozwala odpowiedzieć na: "które projekty są aktywne?", "który projekt ma otwarte incydenty?", "które zasoby są shared?" bez czytania pliku po pliku.

**B5. `now.md` nie skaluje się liniowo**  
Jeden plik jako dashboard dla wielu projektów jednocześnie staje się długi, trudny do parsowania przez AI i trudny do nawigowania przez człowieka z ADHD.

**B6. `_system/` scripts folder jest pusty**  
Contracts definiują reguły ale brak jakiejkolwiek automatyzacji. Każda "weryfikacja" jest manualna.

### 1.3 Ryzyka skalowania

| Ryzyko | Trigger | Prawdopodobieństwo |
|--------|---------|-------------------|
| Context pack staleness | >2 tygodnie bez aktualizacji | Wysokie (już widoczne) |
| now.md nieczytelny | >10 równoległych projektów | Średnie |
| Błędna ścieżka kontekstu w AI session | Zły profil/projekt podczas bootstrap | Wysokie |
| Evidence gaps w audytach | Nowy klient bez ustalonego collector pattern | Wysokie |
| Governance drift | Nowy agent bez załadowania kontraktów | Średnie |

### 1.4 Technical debt

- `01-inbox/` — brak rotacji; zbiera się bez ekspiracji
- `vpc-endpoints-dev-before-tags-*.json` — artifact w root repo (powinien być w `artifacts/`)
- `00-start-here/Bez nazwy.md` — pusty plik
- `scripts/` — zadeklarowany folder bez zawartości od początku
- Lokalny `main` branch: 28 commitów ahead of origin/main — nigdy nie wypchnięty
- README.md × 51 instancji — maintenance overhead bez proporcjonalnej wartości

---

## 2. Recommended Architecture

### Zasady projektowe (non-negotiable)

```
A. Readonly-first: żadna automatyzacja nie pisze do AWS bez human approval
B. Governance-preserved: każda zmiana musi przejść przez istniejące contracts
C. Incremental: każdy krok deployowalny niezależnie bez breaking existing vault
D. Domain-isolated: profile system nie miesza domen
E. Cost-aware: nowe komponenty nie generują nieoczekiwanych kosztów LLM
```

---

### A. Project Profiles

**Problem który rozwiązuje:** B1 (brak deterministycznego bootstrapu), B5 (now.md nie skaluje)

**Propozycja:**

```
profiles/
├── _template/
│   ├── profile.yaml        ← machine-readable config
│   └── bootstrap.md        ← human-readable session starter
├── maspex/
│   ├── profile.yaml
│   └── bootstrap.md
├── planodkupow/
│   ├── profile.yaml
│   └── bootstrap.md
└── ...
```

**profile.yaml — zawartość (przykład maspex):**

```yaml
id: maspex
display_name: Maspex / Kapsel
domain: client-work
classification: confidential

aws:
  account: "969209893152"
  region: eu-west-1
  profile: maspex-cli

repo:
  local: ~/projekty/mako/aws-projects/infra-maspex/
  remote: git@gitlab.makolab.net:...
  active_branch: feat/campaign-day-monitoring

vault:
  session_log: 20-projects/clients/mako/maspex/session-log.md
  notes_dir: 20-projects/clients/mako/maspex/
  context_pack: _chatgpt/context-packs/maspex-prod-tf-drift.md

open_items:
  - id: D3
    desc: "terraform state rm orphaned ACM cert"
    status: pending
  - id: P1
    desc: "autoscaling min=30→8"
    status: conditional_go
    conditions: ["alarm RunningTaskCount<6", "alarm p99>500ms", "7d monitoring"]

safety:
  readonly_mode: true
  requires_go: ["terraform apply", "aws update-service", "force-push"]
```

**bootstrap.md** — generowany lub ręczny plik otwierający sesję AI z pełnym kontekstem projektu w jednym miejscu. Format: executive summary stanu + otwarte zadania + ostatni commit + aktualny AWS state (z linkiem do live `now.md`).

**Korzyść:** Claude Code ładuje `profiles/maspex/profile.yaml` + `bootstrap.md` jako pierwszy krok zamiast nawigować przez `now.md`. Deterministyczny, powtarzalny, auditowy.

**Implementacja:** 8 plików YAML + 8 plików bootstrap.md. Żadnego kodu. Pure markdown + yaml.

---

### B. Operational Launcher (Session Bootstrap)

**Problem który rozwiązuje:** B1, B5 — kontekst ładowany jednym krokiem

**Propozycja:** Rozszerzenie `CLAUDE.md` o sekcję `## Project Bootstrap` z instrukcją:

```markdown
## Project Bootstrap

Gdy użytkownik mówi "przełącz na <projekt>" lub "kontynuuj <projekt>":
1. Załaduj `profiles/<projekt>/profile.yaml`
2. Załaduj `profiles/<projekt>/bootstrap.md`
3. Sprawdź `20-projects/*/session-log.md` — ostatni wpis
4. Sprawdź `02-active-context/now.md` — sekcja projektu
5. Potwierdź stan: AWS account, repo branch, otwarte itemy
```

**Wynik:** Context switching z "gdzie byłem?" → "oto stan projektu w 5 krokach" bez czytania całego `now.md`.

**Nie jest to nowa architektura** — to rozszerzenie istniejącego CLAUDE.md o deterministyczny wzorzec. Koszt: zmiana 1 pliku.

---

### C. Evidence Collection Layer

**Problem który rozwiązuje:** B3 — reinventowanie każdego audytu

**Propozycja:** Biblioteka gotowych read-only evidence collectors per serwis AWS.

```
90-reference/collectors/
├── _contract.md               ← format danych wyjściowych (JSON normalized)
├── ecs-services-propagate.sh  ← ECS PropagateTags audit
├── mq-brokers-inventory.sh    ← MQ brokers + tags + CFN ownership
├── elasticache-inventory.sh   ← Redis clusters + engine version + backups
├── cw-log-groups-retention.sh ← CW log groups + retention + stored bytes
├── vpc-orphan-check.sh        ← NAT + endpoints + EIPs + GA
├── ce-monthly-delta.sh        ← Cost Explorer April vs current
└── ecs-task-sizing.sh         ← ECS desired/min/max + ALBRequestCountPerTarget
```

Każdy collector:
- `--profile <profile>` i `--region <region>` jako parametry
- Output: JSON normalized do wspólnego schema
- Zero side effects — tylko read
- Można uruchomić per-projekt z profilu YAML

**Nie jest to nowy system.** To zbiór ~8 bash scriptów które już piszemy ad-hoc podczas każdego audytu. Ustrukturyzowanie i wersjonowanie ich w repozytorium eliminuje reinwencję.

**Implementacja:** `scripts/collectors/` (10-15 plików). Nowe pliki, brak zmian w istniejącym vault.

---

### D. Metadata / Knowledge Index

**Problem który rozwiązuje:** B4 — brak cross-project navigation

**Propozycja:** Lekki `_index/` folder z machine-readable registry:

```
_index/
├── projects.yaml       ← registry aktywnych projektów
├── open-incidents.md   ← aktywne incydenty cross-projekt
└── domain-map.md       ← które pliki należą do jakiej domeny (auto-generated)
```

**projects.yaml:**

```yaml
projects:
  - id: maspex
    status: active
    client: mako
    domain: client-work
    last_activity: 2026-05-20
    open_items: 4
    profile: profiles/maspex/
    context_pack: _chatgpt/context-packs/maspex-prod-tf-drift.md

  - id: planodkupow
    status: active
    client: mako
    domain: client-work
    last_activity: 2026-05-20
    open_items: 4
    profile: profiles/planodkupow/

  - id: rshop
    status: active-incident
    client: mako
    domain: client-work
    last_activity: 2026-05-20
    ...
```

Ten plik pozwala Claude Code (lub operatorowi) odpowiedzieć na "które projekty są aktywne?" bez czytania `now.md` w całości.

**Implementacja:** 3 pliki YAML/MD. Nowy folder, zero zmian w istniejących plikach.

---

### E. AI Orchestration Layer

**Ocena:** W obecnej skali — NOT JUSTIFIED jako osobna warstwa.

Obecny model (Claude Code + kontrakty CLAUDE.md + skills) obsługuje orkiestrację wystarczająco. Dodanie osobnej warstwy AI orchestration przed solidnym ugruntowaniem A-D byłoby over-engineering.

**Co ma sens w perspektywie 6-12 miesięcy:**

- Structured prompt templates per operation type (audit, incident, deploy, finops) jako rozszerzenie `50-patterns/reusable-prompts.md`
- Evidence pack → briefing generation: script który z collectors JSON generuje markdown briefing gotowy do wklejenia do Claude

**Kiedy wróć do tego tematu:** gdy `profiles/` + collectors są stabilne i używane przez 2+ miesiące.

---

### F. Operational UI Layer

**Ocena:** NOT JUSTIFIED na tym etapie.

Obsidian + Claude Code + shell = wystarczające UI dla single operator. Dodanie internal tooling UI przed udowodnieniem że inne warstwy (A-D) generują wartość = ryzyko budowania narzędzia które nie będzie używane.

**Sygnał do powrotu:** gdy liczba klientów > 5 aktywnych równolegle LUB gdy pojawi się drugi operator wymagający onboardingu.

---

## 3. Safety Model

### Zasady w każdej fazie implementacji

| Zasada | Implementacja |
|--------|--------------|
| Blast radius reduction | Każdy krok to nowe pliki lub addytywne zmiany; ZERO modyfikacji `_system/`, `CLAUDE.md`, `30-standards/` bez explicit PR |
| Readonly-by-default | Collectors: tylko read-only AWS API calls; profile.yaml ma `safety.readonly_mode: true` domyślnie |
| Rollback strategy | Tag `last-stable-version` → commit `449df1c` dostępny; każdy krok na osobnym commicie |
| Audit logging | Każda zmiana przez PR na `feat/operational-platform-foundation` z opisem |
| Context isolation | `profiles/` folder ma własny `LLM_CONTEXT.md` z jasną domeną i scope |
| Profile isolation | Profile nie crossują domen — `maspex/profile.yaml` jest `domain: client-work`, nie miesza z `internal-product-strategy` |
| Production safeguards | `safety.requires_go` w profilu = lista akcji wymagających explicit "GO" od operatora |

### Rollback plan

```
Stan: last-stable-version (tag) → commit 449df1c
Rollback: git checkout last-stable-version
          git checkout -b recovery/from-<date>

W vault:
  - _index/ → usunąć folder
  - profiles/ → usunąć folder
  - scripts/collectors/ → usunąć folder
  - CLAUDE.md → git diff od baseline → revert sekcji

Zero zmian w istniejących _system/, 30-standards/, 40-runbooks/
```

---

## 4. Incremental Migration Plan

**Zasada:** każdy krok jest samodzielnie wartościowy i odwracalny. Żadne dwa kroki nie są ze sobą zblokowane zależnością.

### Krok 0 — Cleanup technical debt (1-2h)
*Przed jakimikolwiek nowymi strukturami*

- [ ] Przenieś `vpc-endpoints-dev-before-tags-*.json` z root do `artifacts/`
- [ ] Usuń `00-start-here/Bez nazwy.md`
- [ ] Push lokalny `main` branch (28 commitów behind) do origin
- [ ] Dodaj do `.gitignore`: pattern dla tymczasowych JSON artifacts w root

Ryzyko: zero. Czyszczenie śmieciowych plików.

### Krok 1 — Project Profiles (2-4h)
*Nowe pliki, brak zmian w istniejących*

- [ ] Utwórz `profiles/_template/profile.yaml` (schema z `TODO` placeholders)
- [ ] Utwórz `profiles/_template/bootstrap.md` (template)
- [ ] Utwórz profile dla 2 najaktywniejszych projektów: maspex + planodkupow
- [ ] Dodaj `## Project Bootstrap` sekcję do CLAUDE.md (dodaj, nie zastępuj)
- [ ] Test: czy Claude Code ładuje profil poprawnie przy "przełącz na maspex"?

Rollback: usuń `profiles/` folder + wyrevertuj CLAUDE.md do baseline.

### Krok 2 — _index/ Registry (1-2h)
*Nowe pliki, brak zmian w istniejących*

- [ ] Utwórz `_index/projects.yaml` z wszystkimi aktywnymi projektami
- [ ] Utwórz `_index/LLM_CONTEXT.md` (domenowy kontrakt dla tego folderu)
- [ ] Dodaj `_index/` do CLAUDE.md jako opcjonalne źródło cross-project query

Rollback: usuń `_index/` folder.

### Krok 3 — Evidence Collectors (3-6h)
*Nowe pliki w `scripts/collectors/`*

- [ ] Utwórz `scripts/collectors/_contract.md` (normalized output format)
- [ ] Zaimplementuj 3 priorytetowe collectors:
  1. `ecs-services-propagate.sh` (potrzebny do każdego projektu ECS)
  2. `mq-brokers-inventory.sh` (maspex + planodkupow)
  3. `ce-monthly-delta.sh` (FinOps, używany wielokrotnie)
- [ ] Test na koncie planodkupow (bezpieczny, nie prod)

Rollback: usuń `scripts/collectors/` folder.

### Krok 4 — Pozostałe profile (1h per projekt)
*Addytywne uzupełnienie profiles/*

- [ ] Profile dla: rshop, puzzler-b2b, LLZ, DRP-TFS
- [ ] Uzupełnij `_index/projects.yaml`

Rollback: usuń profile pliki.

### Krok 5 — now.md refactor (1-2h)
*Jedyna zmiana istniejącego systemu — wymaga przeglądu*

- [ ] Przenieś szczegółowe projekty z `now.md` → odpowiednie `profiles/*/bootstrap.md`
- [ ] `now.md` staje się: CURRENT_FOCUS + URGENT_ITEMS + linki do profili
- [ ] Test: czy after context switch informacje są dostępne?

Rollback: git revert zmiany w now.md.

---

## 5. Priority Matrix

### MUST HAVE

| Item | ROI | Ryzyko | Effort |
|------|-----|--------|--------|
| Project profiles (Krok 1) | Eliminuje ~15 min/dzień context switching overhead | Niskie (nowe pliki) | 4h |
| Cleanup tech debt (Krok 0) | Redukuje cognitive noise | Zero | 2h |
| Evidence collectors — 3 core (Krok 3 partial) | Eliminuje reinventowanie każdego audytu | Niskie | 6h |

**Łączny effort MUST HAVE: ~12h**

### HIGH VALUE

| Item | ROI | Ryzyko | Effort |
|------|-----|--------|--------|
| _index/projects.yaml (Krok 2) | Jednolinijkowa odpowiedź na "co jest aktywne?" | Zero | 2h |
| Pozostałe profiles (Krok 4) | Pokrycie wszystkich klientów | Niskie | 4h |
| now.md slim-down (Krok 5) | Lepsza czytelność, ADHD-friendly | Niskie (z rollbackiem) | 2h |
| Collectors: vpc-orphan + cw-retention | Powtarzalne audyty planodkupow | Niskie | 3h |

**Łączny effort HIGH VALUE: ~11h**

### OPTIONAL

| Item | Uzasadnienie | Defer do kiedy |
|------|-------------|---------------|
| Structured prompt templates per operation | Wartościowe, ale 50-patterns/ już częściowo to pokrywa | Gdy profiles są stabilne 1 miesiąc |
| Evidence pack → briefing generator script | Automatyzacja generowania markdown z JSON collectors | Gdy 5+ collectors jest w użyciu |
| Bootstrap.md auto-generation | Profile.yaml → auto-generated bootstrap | Gdy profile.yaml ma pełne dane |

### R&D

| Item | Hipoteza | Kryterium weryfikacji |
|------|---------|----------------------|
| AI Orchestration Layer | Czy structured prompt templates + collectors są wystarczające, czy potrzebna osobna warstwa? | Oceń po 3 miesiącach użycia collectors |
| Operational UI Layer | Czy shell + Obsidian przestaje wystarczać? | Gdy >1 operator na tym samym vault |
| Cross-project dependency graph | Automatyczne wykrywanie relacji między projektami | Gdy `_index/` jest w użyciu przez 6+ miesięcy |

---

## Appendix — Nierozwiązane pytania (wymagają decyzji)

1. **Profile schema versioning:** Gdy `profile.yaml` schema zmieni się, jak migrować stare profile? → Propozycja: `schema_version: 1` field + migration notes w `profiles/_template/`

2. **Domain integrity dla profiles:** `maspex/profile.yaml` zawiera ścieżki do `_chatgpt/context-packs/` (bridge do ChatGPT). Czy to narusza domain isolation? → Ocena: nie, bo profile jest `domain: client-work` i eksportuje tylko referencje, nie treść.

3. **Kto aktualizuje `_index/projects.yaml`?** → Propozycja: Claude Code aktualizuje automatycznie przy każdej zmianie statusu projektu (nowy trigger w CLAUDE.md save triggers).

4. **Czy collectors mają wchodzić w 90-reference czy scripts/?** → Propozycja: `scripts/collectors/` dla wykonywalnych skryptów, `90-reference/collectors/` dla dokumentacji jak używać.

---

## Decyzja — co dalej?

Przed implementacją: zatwierdzić priorytety z operatorem.

**Rekomendowany wariant startowy (Krok 0 + Krok 1 pilot):**

1. Krok 0: cleanup (bez ryzyka, natychmiast)
2. Pilot profile dla maspex (jeden projekt, walidacja konceptu)
3. Review i decyzja o kontynuacji pozostałych kroków

**Co NIE jest proponowane:**

- Żaden rewrite istniejącej struktury vault
- Żadne zmiany w `_system/` contracts bez osobnego ADR
- Żadna automatyzacja pisząca do AWS
- Żaden replacement `now.md` bez 2-tygodniowego równoległego testu nowego podejścia
