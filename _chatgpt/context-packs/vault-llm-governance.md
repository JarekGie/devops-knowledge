---
title: ChatGPT context — pełny audyt vault + governance LLM
domain: shared-concept
origin: vault-synthesis
classification: internal
llm_exposure: allowed
cross_domain_export: allowed
source_of_truth: vault
created: 2026-05-01
updated: 2026-05-20
tags: [chatgpt, context-pack, vault, llm-governance, agent-contract, audit]
---

# Audyt vaultu — Obsidian Knowledge OS
**Materiał wejściowy dla ChatGPT — dostęp tylko przez ten dokument**
**Data:** 2026-05-15 | **Źródło:** analiza 15+ plików _system/ + CLAUDE.md + CODEX.md + 02-active-context

> Wklej całość na początku rozmowy, gdy tematem jest vault, jego organizacja, governance AI, operating model lub sposób pracy użytkownika. Zakres: `shared-concept` — brak ograniczeń domenowych.

---

## SEKCJA 1 — Executive Summary

Vault to operacyjna baza wiedzy (nie wiki) dla seniora DevOps/SRE (Jarosław Gołąb, MakoLab). Projektowany pod ADHD: modularne, standalone notatki; szybki powrót do kontekstu po przerwie; zero długich linearnych dokumentów.

**Architektura systemu w jednym zdaniu:** Obsidian + git jako jedyne source of truth dla wiedzy; Claude Code jako agent wykonawczy z dostępem do plików + AWS; ChatGPT jako second opinion bez dostępu do vault; NotebookLM jako warstwa syntezy na skurowanych paczkach.

**Kluczowe fakty:**
- 15 katalogów tematycznych + 3 systemowe (`_system/`, `_chatgpt/`, `templates/`)
- 15+ kontraktów LLM w `_system/` — to najbardziej rozbudowana część systemu
- Governance wielowarstwowy: izolacja domen, klasyfikacja danych, polityki eksportu, checklista przed każdym eksportem do LLM
- Operacyjna reguła: **jedno zdarzenie → natychmiastowy zapis do vault**, nie po sesji
- IaC (Terraform) jest source of truth dla stanu runtime; vault dokumentuje — nie odwrotnie
- Język treści: polski; kod i komendy: angielski

---

## SEKCJA 2 — Vault Structure

### Fizyczna struktura katalogów

```
00-start-here/       ← onboarding, persona użytkownika, kontrakt komunikacji
01-inbox/            ← tymczasowe przechwytywanie; czyść co tydzień
02-active-context/   ← żywy dashboard (now.md, open-loops.md, waiting-for.md, current-focus.md)
10-areas/            ← wiedza domenowa: aws/, terraform/, cicd/, observability/, cloud-support/, business/
20-projects/         ← internal/ (llz, devops-toolkit, exam-prep) + clients/mako/ (rshop, maspex, puzzler-b2b, planodkupow)
30-standards/        ← aws-tagging, iac, cicd, naming, documentation
40-runbooks/         ← aws/, ecs/, kubernetes/, terraform/, networking/, incidents/
50-patterns/         ← debugging, migration, incident-analysis, finops, reusable-prompts
60-toolkit/          ← devops-toolkit CLI (architecture, contracts, commands, audits)
70-finops/           ← cost reviews, optimization, savings
80-architecture/     ← ADR decision-log, system maps, platform principles
90-reference/        ← commands/, snippets/, glossary/, vendors/, notebooklm/
_chatgpt/            ← context-packs/ (14 aktywnych), conversations/, templates/
_system/             ← 15 kontraktów LLM + bootstrap + polityki
templates/           ← kopiuj przed użyciem, nigdy nie edytuj oryginałów
```

### Taksonomia notatek

Każda notatka ma:
- **Frontmatter YAML** (obowiązkowy od 2026-04-24): `domain`, `origin`, `classification`, `llm_exposure`, `cross_domain_export`, `source_of_truth`, `created`, `updated`
- **Format standalone:** objaw/problem → kontekst → rozwiązanie/działania → uwagi
- **Wiki-linki** `[[nazwa]]` do nawigacji; treść nie duplikowana między notatkami

### Wiedza trwała vs. robocza

| Trwała | Robocza |
|--------|---------|
| `30-standards/`, `40-runbooks/`, `50-patterns/` | `02-active-context/`, `01-inbox/` |
| `80-architecture/`, `90-reference/`, `10-areas/` | `session-log.md` w projektach |

### Kluczowe pliki operacyjne

- `02-active-context/now.md` — **entry point po każdej przerwie**; aktywne zadanie, następny krok, otwarte wątki
- `80-architecture/decision-log.md` — globalny rejestr ADR
- `20-projects/<klient>/<projekt>/session-log.md` — historia pracy w projekcie
- `_system/LLM_CONTEXT_GLOBAL.md` — orientacja vaultu dla każdej sesji LLM

---

## SEKCJA 3 — AI/LLM Governance

15 kontraktów w `_system/` tworzy wielowarstwowy framework bezpieczeństwa wiedzy.

### 3.1 Model domen (7 klas)

| Domena | Znaczenie | Typowa klasyfikacja |
|--------|-----------|---------------------|
| `shared-concept` | Neutralna wiedza techniczna, wzorce | `internal` |
| `client-work` | Praca dla konkretnego klienta | `confidential` minimum |
| `internal-product-strategy` | Strategia MakoLab, roadmapy, ceny | `confidential` |
| `private-rnd` | Devops-toolkit, cloud-detective (własne projekty) | `restricted` |
| `operational-runbook` | Procedury operacyjne, playbooki | `internal` |
| `reference-material` | Komendy, snippety, docs referencyjna | `internal`/`public` |
| `inbox-transient` | Tymczasowe — przypisz w ciągu tygodnia | — |

### 3.2 Klasyfikacja wrażliwości (4 poziomy)

| Poziom | Znaczenie | LLM |
|--------|-----------|-----|
| `public` | Może być opublikowane | Dowolny LLM |
| `internal` | Wewnętrzne MakoLab | ChatGPT/Claude z minimalizacją |
| `confidential` | Dane klienta, infrastruktura, strategia | Tylko no-training LLM + anonimizacja |
| `restricted` | NDA, PII, credentiale, sekrety, surowe logi prod. | ZAKAZ zewnętrznych LLM |

### 3.3 Izolacja domen — reguły hard (DOMAIN_ISOLATION_CONTRACT)

- **R1:** Jedna sesja LLM = jedna domena wrażliwości
- **R2:** `client-work` nie może być mieszane z `private-rnd` ani `internal-product-strategy` w jednym prompcie
- **R3:** Dane dwóch różnych klientów nigdy w jednej sesji
- **R4:** Wiedza klientowska może przejść do innych domen wyłącznie przez procedurę derived insight
- **R5:** Nawet derived insight musi przejść przez `shared-concept` jako warstwę pośrednią

### 3.4 Macierz eksportu LLM (LLM_EXPORT_POLICY)

| Klasyfikacja | ChatGPT Free | ChatGPT Enterprise | Claude API | NotebookLM | Local |
|---|---|---|---|---|---|
| `public` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `internal` | ✅ z minimalizacją | ✅ | ✅ | ✅ | ✅ |
| `confidential` | ❌ | ✅ + anonimizacja | ✅ + anonimizacja | ✅ + anonimizacja | ✅ |
| `restricted` | ❌ | ❌ | ❌ | ❌ | ✅ (jeśli w pełni lokalny) |

**Uwaga:** ChatGPT Free/Plus = ryzyko trenowania; nie używać dla `confidential`. ChatGPT Enterprise i Claude API mają politykę no-training.

### 3.5 Derived Insights — jedyny legalny mechanizm cross-domain

Procedura transformacji wiedzy klientowskiej w wiedzę neutralną:
1. Zidentyfikuj obserwację w przestrzeni klienta
2. Anonimizuj: usuń nazwę klienta, systemy, osoby, konkretne liczby, daty zdarzeń
3. Generalizuj: wzorzec, nie konkretny przypadek
4. Oznacz jako `[!note] Derived insight` z datą generalizacji
5. Zapisz **najpierw** do `shared-concept` — nie bezpośrednio do `private-rnd`/`internal-product-strategy`

Bezwzględnie zakazane bez tego procesu:
```
client-work → private-rnd                        ← PROHIBITED
client-work → internal-product-strategy          ← PROHIBITED
client A → client B                              ← PROHIBITED
```

### 3.6 Cost-Aware Execution (AI_COST_AWARE_AGENT_CONTRACT)

| Tier | Kiedy |
|------|-------|
| **S** (standard) | Rutynowe operacje, edycja plików, proste pytania |
| **M** (medium) | Planowanie, analiza, multi-step |
| **P** (premium) | Eskaluj tylko przy: nierozwiązanej niepewności, sprzeczności, wysokim ryzyku błędu |

Zasady: minimalizuj kontekst, preferuj diffy i linki nad pełnymi rewrite'ami.

### 3.7 Pre-flight checklist (PROMPT_BOUNDARY_CHECKLIST)

4 bloki kontrolne przed każdym eksportem do LLM:
1. **Zawartość:** dane klienta? credentiale? dane produkcyjne? private R&D? strategia?
2. **Mieszanie domen:** łączę więcej niż jedną domenę wrażliwości?
3. **Narzędzie:** właściwe dla tej klasy? ma no-training?
4. **Output:** gdzie w vault idzie wynik? wymaga weryfikacji?

---

## SEKCJA 4 — Workflow Mapping

### 4.1 Narzędzia i ich role

| Narzędzie | Rola | Dostęp do vault | Tryb |
|-----------|------|-----------------|------|
| Claude Code | Agent wykonawczy | Bezpośredni (filesystem) | In-session, real-time |
| ChatGPT | Second opinion | Brak — tylko context packs | Ad-hoc, manual prep |
| NotebookLM | Warstwa syntezy | Upload source packs | Asynchroniczny, curated |
| Obsidian | UI do vault | Native | Edycja ręczna |

### 4.2 Przepływ Claude Code

```
Start sesji → AGENT_BOOTSTRAP.md (5 kroków) → czytaj now.md
  ↓
Praca operacyjna (IaC, git, AWS CLI, edycja plików)
  ↓
Trigger zapisu (decyzja, implementacja, zmiana zadania, koniec sesji)
  ↓
Natychmiastowy zapis do vault → now.md + session-log.md + właściwy katalog
```

**Triggery zapisu (obowiązkowe, natychmiastowe):**

| Zdarzenie | Gdzie |
|-----------|-------|
| Zmiana aktywnego zadania | `02-active-context/now.md` |
| Implementacja / zmiana kodu | `session-log.md` projektu |
| Decyzja architektoniczna | `80-architecture/decision-log.md` |
| Nowa konwencja/standard | `30-standards/` |
| Koniec sesji roboczej | `now.md` + `session-log.md` |
| Prośba o kontekst dla ChatGPT | `_chatgpt/context-packs/<temat>.md` |

### 4.3 Przepływ ChatGPT

```
Obsidian (selekcja plików) → Claude Code (przygotowanie context pack)
  ↓
_chatgpt/context-packs/<temat>.md (zapisany, standalone)
  ↓
Użytkownik wkleja ręcznie do ChatGPT
  ↓
Wyniki → ręcznie do _chatgpt/conversations/ → Claude aktualizuje vault
```

Context pack jest zawsze domenowo izolowany. ChatGPT nigdy nie otrzymuje raw dumpów vault.

### 4.4 Przepływ NotebookLM

```
Vault (selekcja 8-12 plików, nigdy surowy dump)
  ↓
NotebookLM (synthesis z kontraktem wyjściowym)
  ↓
Wynik: Zakres / Fakty / Sprzeczności / Braki / Następny krok / Pliki do aktualizacji
  ↓
Notatka syntezy zapisana do vault
  ↓
Claude Code wykonuje akcje z sekcji "Pliki do aktualizacji"
```

NotebookLM NIGDY nie jest source of truth. Vault jest source of truth.

### 4.5 Integracja z zewnętrznymi repozytoriami

Notatka projektu w `20-projects/` zawiera lokalną ścieżkę do repo (`~/projekty/client/<nazwa>/`). Claude Code czyta i edytuje pliki tego repo bezpośrednio. Vault dokumentuje; IaC/kod jest source of truth dla stanu runtime.

---

## SEKCJA 5 — Context Engineering Model

### 5.1 Wejście do kontekstu — hierarchia

1. **Po przerwie:** `02-active-context/now.md`
2. **Domena techniczna:** `10-areas/<domena>/LLM_CONTEXT.md`
3. **Projekt:** `20-projects/<klient>/<projekt>/context.md` + ostatni `session-log.md`
4. **Globalny vault:** `_system/LLM_CONTEXT_GLOBAL.md`

### 5.2 Format context pack dla ChatGPT (11 obowiązkowych sekcji)

Kim jestem → Opis systemu → Zakres (scope boundaries) → Źródła prawdy → Stan obecny → Plan/roadmapa → Aktualny fokus → Ryzyka/HRI → Decyzje architektoniczne → Pytania otwarte → Jak używać

Wymagania: konkretny (ARNy, account IDs), aktualny (odzwierciedla AWS/IaC), standalone.

### 5.3 Aktywne context packs (14 tematów)

- `cloud-practice.md` — Cloud Practice Lead (AWS Technical Leader role)
- `llz.md`, `devops-toolkit.md`, `vault-llm-governance.md` — internal
- `maspex.md`, `planodkupow-ops-context-2026-04-24.md`, `puzzler-b2b-jumphost.md` — projekty klientów
- `rshop-p99-latency.md`, `rshop-tag-policy.md`, `maspex-load-testing.md` — projekty
- `dual-vault-architecture.md`, `makolab-projects-vault-context.md` — architektura/przegląd

### 5.4 Anti-patterns (explicitly prohibited)

- Raw vault dumps jako kontekst
- Mieszanie domen wrażliwości w jednej sesji
- Długie liniarne checklisty
- Puste pliki / pliki bez wartości operacyjnej
- Zależności "przeczytaj X przed Y"
- Kopiowanie treści zamiast linkowania

---

## SEKCJA 6 — Organizational/Strategic Insights

### 6.1 Profil użytkownika

- **Imię:** Jarosław Gołąb
- **Rola:** Senior DevOps/SRE → AWS Technical Leader / Cloud Practice Lead (nowa rola)
- **Firma:** MakoLab, software house, ~150 osób, projekty dla klientów + internal products
- **Doświadczenie:** 10+ lat, AWS primary (eu-west-1, eu-central-1), uzupełniająco GCP/Azure
- **Cognition:** ADHD — działa: modularne notatki, szybkie diffy, krótkie bloki; nie działa: linearne checklisty, gigantyczne dokumenty
- **Stack:** ECS Fargate, Terraform + CloudFormation, Jenkins, ALB, CloudFront, RDS, DocumentDB, SQS

### 6.2 Aktualna rola strategiczna (2026-05-06)

**AWS Technical Leader / Cloud Practice Lead** — buduje cloud practice od zera.

| Faza | Cel | ETA |
|------|-----|-----|
| 0–30 dni (aktywna) | Foundation — mapowanie, zakres roli, dostępy | 2026-06-05 |
| 30–60 dni | Standards & Competency — operating model, evidence, FinOps | 2026-07-05 |
| 60–90 dni | Scaling — cloud review w lifecycle projektów | 2026-08-05 |

Otwarte blokery: brak dostępu do AWS Partner Central, brak formalnego sign-off zakresu roli, niezinwentaryzowane certyfikacje AWS w firmie.

### 6.3 Aktywne inicjatywy techniczne

**LLZ (Light Landing Zone)** — wewnętrzny standard multi-account AWS na Terraform. Faza A wdrożona. Faza B planowana (GuardDuty, Config, SCP, Security Account).

**devops-toolkit** — bezstanowe CLI do audytów AWS. Domena `private-rnd`. Architektura: plugin/command-router, kontrakty = source of truth, implementacja wtórna.

**Exam prep** — AWS SysOps Associate, target 2026-06-19. Luki: CloudWatch Logs, Systems Manager.

### 6.4 Aktywne projekty klientów

| Projekt | Stan | Bloker |
|---------|------|--------|
| puzzler-b2b (PBMS) | Wdrożone, clean main | — |
| maspex preprod | Wdrożone | Certyfikaty SSL od klienta |
| planodkupow UAT | Zatrzymane | RabbitMQ deprecated 3.8.6 |
| rshop | Aktywny | Latency p99, tag policy |

### 6.5 AWS profil techniczny

- Profiles: `mako-dc` = management (864277686382), `maspex-cli`, `plan`
- Partnership: tier nieznany — brak dostępu do Partner Central
- Regiony: eu-west-1 primary, eu-central-1, eu-west-2

---

## SEKCJA 7 — Ryzyka i Słabości

| # | Ryzyko | Poziom |
|---|--------|--------|
| R1 | Frontmatter adoption gap — kontrakty z 2026-04-24, większość starych notatek bez frontmatter | WYSOKI |
| R2 | Vault-IaC desynchronizacja — każda zmiana IaC pominięta przez triggery = documentation drift | WYSOKI |
| R3 | now.md volatility — nie zaktualizowany na koniec sesji = nieaktualny kontekst przy powrocie | ŚREDNI |
| R4 | ChatGPT workflow w pełni manualny — konwersacje mogą być niezapisywane | ŚREDNI |
| R5 | Domain isolation compliance = honor system — brak technicznego wymuszenia | ŚREDNI |
| R6 | NotebookLM topology aspiracyjna — aktualny stan załadowania nie jest śledzony w vault | NISKI |
| R7 | 01-inbox/ akumulacja — ADHD + wielowątkowość = ryzyko stałego backlogu | NISKI |
| R8 | Presja równoległych priorytetów — exam (2026-06-19) vs Cloud Practice Foundation (do 2026-06-05) | KONTEKSTOWY |

---

## SEKCJA 8 — Most Important Files

### Nawigacja operacyjna

| Plik | Rola |
|------|------|
| `02-active-context/now.md` | **Entry point po przerwie** — aktywne zadanie, następny krok |
| `_system/LLM_CONTEXT_GLOBAL.md` | Orientacja vaultu; środowisko techniczne, aktywne projekty |

### Governance LLM

| Plik | Rola |
|------|------|
| `_system/AGENT_BOOTSTRAP.md` | 5-krokowy mandatory startup dla Claude Code; forbidden actions |
| `_system/AGENTS.md` | Wspólny kontrakt dla wszystkich agentów (Claude, ChatGPT, Codex) |
| `_system/DOMAIN_ISOLATION_CONTRACT.md` | R1-R7 hard rules; tabela zakazanych kombinacji |
| `_system/CLASSIFICATION_MODEL.md` | 7 klas domen × 4 poziomy wrażliwości; pełny schemat frontmatter |
| `_system/LLM_EXPORT_POLICY.md` | Macierz: co można eksportować do którego LLM |
| `_system/PROMPT_BOUNDARY_CHECKLIST.md` | 4-blokowa checklista + decision tree |
| `_system/AI_COST_AWARE_AGENT_CONTRACT.md` | Reguły tieru modelu (S/M/P); token frugality |
| `_system/LLM_CONTEXT_BOUNDARY_CONTRACT.md` | Jedna-sesja-jedna-domena; tabela ryzyk narzędzi |

### Workflow

| Plik | Rola |
|------|------|
| `_system/CHATGPT_WORKFLOW.md` | Jak przygotować context pack; jak zapisać konwersację |
| `_system/NOTEBOOKLM_CONTRACT.md` | Kontrakt syntezy; dozwolone użycia; format wyjścia; 5 szablonów promptów |
| `_system/DERIVATIVE_INSIGHT_RULES.md` | Jedyny legalny mechanizm cross-domain; 5-krokowa procedura |
| `_system/ORIGIN_METADATA_CONTRACT.md` | Schemat frontmatter; wszystkie dopuszczalne wartości pól |
| `_system/BOUNDARY_EXCEPTION_PROCESS.md` | Formalny proces wyjątku; 3 wymagane role |

### Projekty i architektura

| Plik | Rola |
|------|------|
| `_chatgpt/context-packs/cloud-practice.md` | Cloud Practice Lead context (rola, roadmapa, open loops) |
| `20-projects/clients/mako/puzzler-b2b/puzzler-b2b-context.md` | PBMS — architektura, decyzje, stan |
| `80-architecture/decision-log.md` | Globalny ADR |
| `00-start-here/persona.md` | Profil użytkownika, stack, ADHD design principles |

### Templates

| Plik | Rola |
|------|------|
| `_chatgpt/templates/context-pack-template.md` | Szablon nowego context pack |
| `templates/runbook-template.md` | Szablon runbooka (6 obowiązkowych sekcji) |

---

## SEKCJA 9 — Kontrakty agentów (CLAUDE.md / CODEX.md)

### 9.1 Dwa pliki, dwa agenty — jeden cel

| Aspekt | CLAUDE.md (Claude Code) | CODEX.md (Codex) |
|--------|------------------------|------------------|
| Bootstrap | `_system/AGENT_BOOTSTRAP.md` | `_system/AGENT_BOOTSTRAP.md` |
| Język treści | PL; kod/komendy EN | PL; kod/komendy EN |
| Format notatki | objaw → kontekst → rozwiązanie → uwagi | objaw → kontekst → rozwiązanie → uwagi |
| Triggery zapisu | obowiązkowe (tabela 6 zdarzeń) | obowiązkowe (tabela 6 zdarzeń) |
| Cost-aware | tak — kontrakt `AI_COST_AWARE_AGENT_CONTRACT.md` | tak — Tier S default, eskaluj do M/P przy potrzebie |
| Destrukcyjne ops | wymaga potwierdzenia | wymaga potwierdzenia; brak `--no-verify`, `git reset --hard` bez zgody |
| Inspect first | tak | tak — czytaj przed edycją, małe diffy |
| IaC safety | terraform apply/destroy wymaga zgody | terraform apply/destroy wymaga zgody |
| Mirror docs | `docs/` devops-toolkit → `60-toolkit/` vault | `docs/` devops-toolkit → `60-toolkit/` vault |
| Autorstwo | zakaz AI w commitach/PR/ADR | zakaz AI w commitach/PR/ADR |

### 9.2 Wspólne zasady niezmienne (non-negotiable)

- Jeden vault = jeden kontrakt komunikacji; claude i codex stosują te same zasady
- Triggery zapisu wyzwalają natychmiastowy zapis — nie odkładasz na koniec sesji
- Zapis do vault: najpierw sprawdź istniejącą notatkę do aktualizacji, potem twórz nową
- Ścieżki: weryfikuj przez `ls` przed zapisem; koryguj błędne ścieżki i informuj
- ChatGPT context packs: sprawdź `_chatgpt/context-packs/<temat>.md` → aktualizuj jeśli istnieje; nie generuj w odpowiedzi

### 9.3 Autorstwo (non-negotiable — obie platformy)

Zakaz we wszystkich artefaktach vault, repo, commitach, PR, ADR:
- `Co-Authored-By: Claude` / `Author: Claude`
- `Generated by Claude / Codex / AI`
- Wzmianki o AI w commit message lub PR description

Jedyny dozwolony autor: **Jarosław Gołąb**

---

## SEKCJA 10 — Stan operacyjny (2026-05-15)

### 10.1 Aktywny kontekst — now.md (ostatnie wpisy)

**Ostatni zapis: 2026-05-15 — MASPEX PROD parity — APPLIED**

```
REPO:   ~/projekty/mako/aws-projects/infra-maspex (branch: feat/campaign-day-monitoring)
COMMIT: 7511067

WYNIK (3 add, 7 change, 3 destroyed):
  ✅ TD families PROD: maspex-prod-api:1, maspex-prod-admin-panel:1, maspex-prod-bot:1
  ✅ IAM role tags fix: environment uat→prod (6 ról)
  ✅ IAM exec_secrets policy: UAT→PROD secret ARN
  ✅ SUPABASE_JWT_SECRET ustawiony w maspex/prod/api

OTWARTE:
  ❓ Certy caed9d07/d4bbfef0 (test.twojkapsel.pl) — decyzja czy PROD migruje na tę domenę
  Bot PROD 0/1 — brak tokenu, osobna kwestia
  Pipeline deploy podepnie maspex-prod-* TD przy następnym release (ECS services niezmienione)
```

### 10.2 Projekty aktywne (current-focus.md)

| Projekt | Status | Następny krok |
|---------|--------|---------------|
| drp-tfs (klient mako) | Aktywny — EKS | cloud-detective live check; mongorestore verify |
| puzzler-b2b / PBMS | Standby | commit staged services.tf; decyzja AzureAd QA |
| maspex | Standby | czeka na SSL certs od klienta; PROD parity wdrożona |
| rshop | Standby | CFN-MUT-001 permanent fix; PropagateTags |
| vault governance | Standby | ręczny frontmatter w clients/mako/ + _chatgpt/ + llz/ |
| BMW AI Taskforce | Scaffold | czeka na materiały od klienta |
| devops-toolkit | W tle | — |

### 10.3 Open loops (top items)

**Maspex:**
- Redis write-through 924,582 VOTE_CACHE_WRITETHROUGH_FAIL — problem app-level, zbadać przy kolejnym teście
- maspex-api MemoryUtilization narosła ~17%→~57% — obserwować przy kolejnym teście (próg 75%)
- maspex-bot health check failures

**DRP-TFS:**
- cloud-detective live check po naprawie Mongo + LoadBalancer
- mongorestore data verify
- `k8s/loadbalancer/install.sh` — trwały fix `quic=false`

**Waiting for:**
- Maspex/Kapsel: certyfikaty SSL (projekt standby od 2026-05-06)
- AWS Partner Central: dostęp (blokuje cloud-practice faza 0-30)

### 10.4 01-inbox status

Inbox `01-inbox/` aktualnie zawiera tylko `quick-capture.md` z przykładowym wpisem z 2026-04-17 — brak realnych elementów do przetworzenia.

---

## Jak używać tego dokumentu z ChatGPT

Wklej cały dokument na początku rozmowy gdy tematem jest:
- organizacja vault lub zasady notatek
- governance AI, kontrakty agentów (CLAUDE.md, CODEX.md), polityki eksportu
- operating model (Claude ↔ ChatGPT ↔ NotebookLM)
- sposób pracy użytkownika, ADHD-aware design
- bieżący stan operacyjny (aktywne projekty, open loops)
- projektowanie nowych kontraktów lub context packów

Czego NIE rób:
- Nie traktuj jako wyczerpującego stanu wszystkich projektów (jest ich więcej)
- Nie zakładaj że frontmatter jest wszędzie — jest w trakcie adoptacji
- Dla kontekstu konkretnego projektu — poproś o dedykowany context pack z `_chatgpt/context-packs/<temat>.md`
- Sekcja 10 (stan operacyjny) wygasa — przy pytaniach o bieżący stan poproś o aktualizację z now.md

---

*Zaktualizowany 2026-05-15. Źródła: AGENT_BOOTSTRAP, AI_COST_AWARE_AGENT_CONTRACT, LLM_CONTEXT_BOUNDARY_CONTRACT, DOMAIN_ISOLATION_CONTRACT, KNOWLEDGE_BOUNDARIES, CLASSIFICATION_MODEL, CHATGPT_WORKFLOW, LLM_EXPORT_POLICY, NOTEBOOKLM_CONTRACT, LLM_CONTEXT_GLOBAL, ORIGIN_METADATA_CONTRACT, PROMPT_BOUNDARY_CHECKLIST, AGENTS, DERIVATIVE_INSIGHT_RULES, BOUNDARY_EXCEPTION_PROCESS, CLAUDE.md, CODEX.md, persona.md, 00-start-here/, 01-inbox/, 02-active-context/, 16 context packs.*
