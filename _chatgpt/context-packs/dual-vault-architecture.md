---
title: ChatGPT context — architektura dual vault (devops-knowledge + dc-devops-team-vault)
domain: shared-concept
origin: vault-synthesis
classification: internal
llm_exposure: allowed
cross_domain_export: allowed
source_of_truth: vault
created: 2026-05-03
updated: 2026-05-03
tags: [chatgpt, context-pack, vault, dc-devops-team-vault, team-vault, architecture]
---

# ChatGPT Context Pack — Dual Vault Architecture

> Wklej całość na początku rozmowy, gdy tematem jest struktura, organizacja lub workflow obu vaultów.
> Zakres: `shared-concept` — brak danych klientowskich, można używać swobodnie.

**Zakres:** architektura i zasady pracy z vaultem prywatnym (`devops-knowledge`) i zespołowym (`dc-devops-team-vault`), relacja między nimi, jak z nich korzystać.  
**Data przygotowania:** 2026-05-03  
**Lokalizacje lokalne:**
- prywatny: `~/projekty/devops/devops-knowledge`
- zespołowy: `~/projekty/mako/dc-devops-team-vault`

---

## 1. Kim jestem / jak odpowiadać

Senior DevOps/SRE, AWS multi-account (Organizations), Terraform, ECS Fargate, ADHD.  
Styl odpowiedzi: werdykt na górze, evidence poniżej, krótkie sekcje z nagłówkami, podążaj za nowym wątkiem bez pytania o powrót do poprzedniego.

---

## 2. Relacja między vaultami

```
devops-knowledge (prywatny)
  → upstream / source authoring
  → pełny kontekst, notatki prywatne, R&D, drafty
  → tylko właściciel (Jarosław Gołąb)

        ↓ kontrolowana promocja (review + boundary check)

dc-devops-team-vault (zespołowy)
  → downstream / team knowledge
  → warstwa robocza przed Confluence/Jira/GLPI
  → cały DC DevOps team MakoLab
```

Zasady przepływu:
- prywatny vault jest **jedynym miejscem autorskim** — tam powstaje wiedza
- do team vault trafia tylko to, co jest: reference material (nie instrukcja), wolne od prywatnych kontekstów, zanonimizowane, bez strategii produktowej
- forbidden w shared vault: devops-toolkit internals, private-rnd, product strategy, prywatne notatki, projekty poza MakoLab/BMW
- **brak formalnego workflow promocji** — zasady istnieją, ale nie ma dokumentu proceduralnego (gap do uzupełnienia)

---

## 3. Vault prywatny — devops-knowledge

### Cel

Operacyjna baza wiedzy Obsidian dla senior DevOps/SRE. Nie wiki — narzędzie pracy. Cel: szybki powrót do kontekstu po przerwie, praca z wieloma równoległymi wątkami.

### Struktura katalogów

```
00-start-here/    — onboarding vault, persona
01-inbox/         — tymczasowe przechwytywanie (czyść co tydzień)
02-active-context/— żywy dashboard: now.md, current-focus.md, open-loops.md, waiting-for.md
10-areas/         — AWS, Terraform, CI/CD, observability, cloud-support, business
20-projects/      — internal/ (LLZ, toolkit, exam) + clients/mako/
30-standards/     — tagging, IaC, CI/CD, naming, dokumentacja
40-runbooks/      — aws/, ecs/, kubernetes/, terraform/, incidents/
50-patterns/      — debugging, migration, finops, reusable-prompts
60-toolkit/       — devops-toolkit CLI (kontrakty, komendy, architektura)
70-finops/        — przeglądy kosztów, optymalizacja
80-architecture/  — ADR (decision-log), mapy systemów
90-reference/     — commands/, snippets/, glossary/, notebooklm/
_system/          — kontrakty LLM, polityki, granice domen
_chatgpt/         — context-packs/ + conversations/ + templates/
templates/        — szablony (kopiuj przed użyciem, nie edytuj oryginałów)
```

### Kluczowe zasady notatek (non-negotiable)

- Język: treść po polsku; kod, komendy, ścieżki, identyfikatory — po angielsku
- Format: `objaw/problem → kontekst → rozwiązanie/działania → uwagi`
- Każda notatka standalone — zero zależności "przeczytaj X przed Y"
- Nie duplikuj — linkuj `[[wiki-link]]`
- Brak pustych plików — każdy plik musi mieć realną wartość operacyjną
- Nazwy plików: `kebab-case`, bez dat w nazwie (data do frontmatter)
- `01-inbox/` tymczasowy — elementy > 1 tydzień → przenieś lub usuń

### Active context (`02-active-context/`)

Punkt wejścia po przerwie:

| Plik | Rola |
|------|------|
| `now.md` | Bieżący stan operacyjny — ostatnie sesje, update bloki |
| `current-focus.md` | Priorytety tygodnia / sprintu |
| `open-loops.md` | Rzeczy wiszące, które zajmują RAM |
| `waiting-for.md` | Blokery zależne od innych |

### Governance i AI (`_system/`)

Kluczowe pliki systemowe:

| Plik | Rola |
|------|------|
| `AGENT_BOOTSTRAP.md` | Obowiązkowy bootstrap przed każdą operacją Claude |
| `AI_COST_AWARE_AGENT_CONTRACT.md` | Model tiering (S/M/P), token frugality |
| `CHATGPT_WORKFLOW.md` | Jak eksportować/importować rozmowy ChatGPT |
| `DOMAIN_ISOLATION_CONTRACT.md` | Jedna sesja LLM = jedna domena wrażliwości |
| `LLM_CONTEXT_BOUNDARY_CONTRACT.md` | Zasady przygotowania paczek kontekstu |
| `LLM_EXPORT_POLICY.md` | Co wolno/nie wolno eksportować do LLM |
| `CLASSIFICATION_MODEL.md` | public / internal / confidential / restricted |
| `NOTEBOOKLM_CONTRACT.md` | NotebookLM jako warstwa syntezy, nie source of truth |
| `ORIGIN_METADATA_CONTRACT.md` | Śledzenie źródła wiedzy w notatkach |

### Jak Claude Code pracuje z prywatnym vaultem

- Ma pełny dostęp do całego vault przez filesystem
- Obowiązkowe triggery zapisu (natychmiast gdy wystąpią):
  - Zmiana aktywnego zadania → `now.md`
  - Implementacja/commit → `session-log.md` projektu
  - Decyzja architektoniczna → `80-architecture/decision-log.md`
  - Koniec sesji → `now.md` + `session-log.md`
- Nie czeka na koniec rozmowy — zapisuje w trakcie
- ChatGPT context packs sprawdza czy istnieją przed tworzeniem nowych

### Jak ChatGPT korzysta z prywatnego vaultu

- Brak dostępu do filesystem
- Kontekst eksportowany ręcznie jako context pack (`_chatgpt/context-packs/<temat>.md`)
- Format: zakres → kluczowe fakty → stan → next step
- Target rozmiarowy: ~1500 tokenów (mały) / ~3000 tokenów (standard)
- Wyniki wracają do vault jako notatki z `generated_by: chatgpt` w frontmatter
- Workflow: `_system/CHATGPT_WORKFLOW.md`

### Domeny wrażliwości (jedna sesja = jedna domena)

| Domena | Przykłady |
|--------|-----------|
| `client-work` | rshop, planodkupow, maspex, puzzler-b2b |
| `internal-product-strategy` | LLZ, devops-toolkit roadmapa |
| `private-rnd` | osobiste projekty R&D |
| `shared-concept` | standardy AWS, wzorce Terraform, zasady vault, kontrakty LLM |

---

## 4. Vault zespołowy — dc-devops-team-vault

### Cel

Warstwa robocza DC DevOps team. Nie zastępuje Confluence, Jira ani GLPI — jest miejscem gdzie wiedza **dojrzewa** zanim trafi do właściwego systemu.

```
Vault (myślenie, prototypowanie)
    → weryfikacja przez zespół
        → publikacja w systemie docelowym
```

Systemy docelowe:

| Kierunek | Co trafia |
|----------|-----------|
| → Confluence | Dojrzałe runbooki (`status: published`), ADR, wiki |
| → Jira | Pomysły z `10-ideas/` → epiki/zadania |
| ← GLPI | Post-mortemy syntetyzowane z ticketów (nie kopiowane) |

### Struktura katalogów

```
00-start-here/    — onboarding dla nowych członków zespołu
01-inbox/         — szybkie notatki, niedosortowane (inbox-first rule)
02-active-context/— aktywny kontekst zespołu (aktywny-kontekst.md)
10-ideas/         — pomysły z wstępnym opisem, przed realizacją
20-systems/       — opisy systemów infrastruktury i aplikacji
30-runbooks/      — procedury operacyjne (draft → review → active → published)
40-incidents/     — post-mortemy (syntheza GLPI+Jira, anonimizowane)
50-integrations/  — jak systemy rozmawiają (Confluence, GLPI, Jira, Grafana, Nagios, Wazuh)
60-decisions/     — ADR (Architecture Decision Records)
70-workshops/     — materiały ze spotkań i warsztatów
90-ai-context/    — skompresowany, bezpieczny kontekst dla narzędzi AI
_system/          — kontrakt vaulta, zasady AI, klasyfikacja, nazewnictwo
_templates/       — szablony dla nowych notatek
```

### Lifecycle runbooka

| Etap | Status frontmatter | Lokalizacja |
|------|--------------------|-------------|
| Szkic / pomysł | `draft` | `01-inbox/` lub `10-ideas/` |
| Wersja robocza | `draft` | `30-runbooks/` |
| Weryfikacja przez zespół | `review` | `30-runbooks/` |
| Zatwierdzona | `active` | `30-runbooks/` |
| Opublikowany w Confluence | `published` | `30-runbooks/` + `confluence_url:` w frontmatter |
| Nieaktualny | `archived` | `30-runbooks/_archive/` |

### Wymagany frontmatter (każdy plik)

```yaml
---
title: Czytelny Tytuł Notatki
type: pomysł | runbook | decyzja | incydent | integracja | kontekst AI | system
status: draft | review | active | published | archived
sensitivity: public | internal | restricted
created: YYYY-MM-DD
updated: YYYY-MM-DD
tags: [tag1, tag2]
---
```

Dodatkowe pola dla runbooka: `systems: [aws, kubernetes]`, `confluence_url:`, `estimated_duration:`  
Dodatkowe pola dla incydentu: `severity: P1|P2|P3|P4`, `glpi_ticket:`, `jira_issue:`  
Dodatkowe pola dla ADR: `deciders: [team-dc-devops]`, `status: proposed | accepted | deprecated`

### Typy dokumentów i ich miejsca

| Typ | Gdzie | Kiedy do systemu docelowego |
|-----|-------|----------------------------|
| `pomysł` | `10-ideas/` | → Jira (po zatwierdzeniu przez team) |
| `runbook` | `30-runbooks/` | → Confluence (status: published) |
| `decyzja` (ADR) | `60-decisions/` | → Confluence (przestrzeń architektoniczna) |
| `incydent` | `40-incidents/` | ← synteza z GLPI + Jira |
| `integracja` | `50-integrations/` | → Confluence (opcjonalnie) |
| `kontekst AI` | `90-ai-context/` | tylko dla AI, nie do publikacji |

### Governance (_system/)

| Plik | Rola |
|------|------|
| `VAULT_CONTRACT.md` | Fundamentalne zasady działania vaulta, lifecycle runbooka, PR workflow |
| `AI_USAGE_RULES.md` | AI tylko z `90-ai-context/`, zakaz danych produkcyjnych |
| `CLASSIFICATION_MODEL.md` | Typy dokumentów + klasy wrażliwości (public/internal/restricted) |
| `NAMING_CONVENTION.md` | kebab-case bez polskich znaków, date prefix w inbox/incidents/workshops |

### Zasady bezpieczeństwa AI w team vault

AI (Claude Code, NotebookLM) pracuje **wyłącznie** na `90-ai-context/`:
- Klasa wrażliwości: wyłącznie `internal` lub `public` — **nigdy `restricted`**
- Zakazane: hasła, klucze API, adresy IP produkcyjnych, nazwy klientów, certyfikaty SSL
- Anonimizacja przed uploadem: `klient_A`, `10.x.x.x`, `<DOMENA-WEWNETRZNA>`
- Wyniki AI wracają do vault z `generated_by: claude` lub `generated_by: notebooklm` w frontmatter
- Claude Code nie zapisuje bezpośrednio do `30-runbooks/` bez ludzkiego przeglądu

### Git workflow w team vault

```
main        — stabilna, zweryfikowana wersja
dev         — gałąź robocza, codzienne zmiany
feature/*   — nowe funkcjonalności / większe inicjatywy
hotfix/*    — pilne poprawki
```

Zmiany w `_system/` i `30-runbooks/` → Pull Request + review przez min. 1 osobę z zespołu.  
Zmiany w `_system/VAULT_CONTRACT.md` → PR + akceptacja min. 2 osób.

### Stack technologiczny zespołu (z context-for-claude.md)

- Cloud: AWS (EC2, ECS, EKS, Lambda, RDS, S3, CloudWatch, GuardDuty, EventBridge)
- IaC: Terraform + Ansible
- CI/CD: GitLab CI + GitLab
- Monitoring: Grafana + Prometheus/Victoria Metrics + Nagios + Wazuh
- ITSM: GLPI (helpdesk/CMDB) + Jira (projekty) + Confluence (wiki)

---

## 5. Jak używać tej paczki w ChatGPT

**Użyj do:**
- projektowania nowych notatek / sekcji w którymś z vaultów
- pytań o governance, lifecycle, klasyfikację
- porównania zasad prywatnego vs zespołowego vaultu
- planowania workflow promocji wiedzy private → shared
- tworzenia szablonów lub kontraktów dla obu vaultów

**Nie używaj do:**
- konkretnych projektów klientowskich (użyj dedykowanego packa: `makolab-projects-vault-context.md`)
- decyzji runtime AWS bez live verification

**Przed pytaniem podaj kontekst:**
```
Pracujemy z [prywatnym | zespołowym | obydwoma] vaultem.
Zadanie: [co chcesz osiągnąć].
```

---

## 6. Znany gap — brak formalnego workflow promocji

Zasady promocji wiedzy z prywatnego do team vault istnieją (odnotowane w `02-active-context/now.md` 2026-04-30), ale nie ma dokumentu proceduralnego.

Co wiadomo:
- promotion wymaga: boundary check (nie ma narzędzia), review przez właściciela, anonimizacja danych klientowskich
- forbidden w shared: devops-toolkit internals, private-rnd, product strategy, prywatne notatki, projekty poza MakoLab/BMW
- notatki w shared są reference material — nie instructions (inaczej niż w prywatnym)

Do uzupełnienia: `_system/KNOWLEDGE_PROMOTION_WORKFLOW.md` w prywatnym vault lub `_system/IMPORT_POLICY.md` w team vault.

---

## 7. Źródła użyte do przygotowania

```
devops-knowledge:
  CLAUDE.md
  _system/AI_COST_AWARE_AGENT_CONTRACT.md
  _system/DOMAIN_ISOLATION_CONTRACT.md
  _system/LLM_EXPORT_POLICY.md
  _system/CLASSIFICATION_MODEL.md
  _system/CHATGPT_WORKFLOW.md
  02-active-context/now.md (wpis 2026-04-30)
  _chatgpt/context-packs/vault-llm-governance.md
  _chatgpt/templates/context-pack-template.md

dc-devops-team-vault:
  README.md
  CLAUDE.md
  _system/VAULT_CONTRACT.md
  _system/AI_USAGE_RULES.md
  _system/CLASSIFICATION_MODEL.md
  _system/NAMING_CONVENTION.md
  90-ai-context/context-for-claude.md
  02-active-context/aktywny-kontekst.md
```
