---
title: ChatGPT context — vault governance i kontrakty LLM
domain: shared-concept
origin: vault-synthesis
classification: internal
llm_exposure: allowed
cross_domain_export: allowed
source_of_truth: vault
created: 2026-05-01
updated: 2026-05-01
tags: [chatgpt, context-pack, vault, llm-governance, agent-contract]
---

# ChatGPT Context Pack — Vault governance + kontrakty LLM

> Wklej całość na początku rozmowy, gdy tematem jest sam vault, jego organizacja, zasady pracy z LLM lub kontrakty agentów.
> Zakres: `shared-concept` — można używać bez ograniczeń domenowych.

**Zakres:** budowa vault, zasady organizacji, kontrakty dla Claude/ChatGPT/Codex, cost-aware routing, granice bezpieczeństwa kontekstu.
**Data przygotowania:** 2026-05-01
**Source of truth:** vault `devops-knowledge`; plik `_system/AGENTS.md`, `CLAUDE.md`, `_system/AI_COST_AWARE_AGENT_CONTRACT.md`.

---

## 1. Kim jestem / jak odpowiadać

Użytkownik to senior DevOps/SRE z ADHD. Odpowiedzi powinny być techniczne, konkretne, bez wstępów. ADHD-aware styl:
- werdykt na górze, evidence poniżej,
- krótkie sekcje z nagłówkami zamiast długich esejów,
- przy skokach tematycznych — podążaj za nowym wątkiem bez pytania o powrót,
- nie sugeruj "może wróćmy do X", tylko reaguj na to, co jest w prompcie.

---

## 2. Czym jest ten vault

Operacyjna baza wiedzy Obsidian dla DevOps/SRE. Nie wiki — narzędzie pracy. Cel: szybki powrót do kontekstu po przerwie i praca z wieloma równoległymi wątkami.

Środowisko techniczne:
- Cloud: AWS primary (eu-west-1, eu-central-1), GCP/Azure marginalnie
- IaC: Terraform + CloudFormation
- Konteneryzacja: ECS Fargate
- CI/CD: Jenkins
- Vault: Obsidian + git sync, repo `devops-knowledge`

---

## 3. Struktura katalogów

```
00-start-here/    — onboarding vault, persona
01-inbox/         — tymczasowe przechwytywanie (czyść co tydzień)
02-active-context/— żywy dashboard: now.md, open-loops.md, waiting-for.md, current-focus.md
10-areas/         — AWS, Terraform, CI/CD, observability, business
20-projects/      — internal/ (LLZ, toolkit, exam) + clients/mako/
30-standards/     — tagging, IaC, CI/CD, naming, dokumentacja
40-runbooks/      — aws/, ecs/, kubernetes/, terraform/, incidents/
50-patterns/      — debugging, migration, incident-analysis, finops, prompts
60-toolkit/       — devops-toolkit CLI (architektura, kontrakty, komendy)
70-finops/        — przeglądy kosztów, optymalizacja
80-architecture/  — ADR, mapy systemów, zasady platformy
90-reference/     — commands/, snippets/, glossary/, vendors/
_system/          — kontrakty LLM, polityki, granice domen
_chatgpt/         — context-packs/ (gotowe do wklejenia), conversations/, templates/
templates/        — kopiuj przed użyciem, nigdy nie edytuj oryginałów
```

Priorytety zapisu (od najwyższego):
1. `02-active-context/` — stan bieżącej pracy
2. `40-runbooks/` — procedury incydentowe
3. `20-projects/` — projekty klientów i wewnętrzne
4. `30-standards/`, `50-patterns/`, `90-reference/`

---

## 4. Kontrakt notatek (non-negotiable)

- Język: treść po polsku; kod, komendy, ścieżki, identyfikatory AWS/IaC — po angielsku
- Format każdej notatki: `objaw/problem → kontekst → rozwiązanie → uwagi`
- Każda notatka działa standalone — zero zależności "przeczytaj X przed Y"
- Nie duplikuj treści — linkuj `[[wiki-link]]` zamiast kopiować
- Brak pustych plików — każdy plik musi zawierać realną wartość
- Nazwy plików: `kebab-case`, krótkie, bez dat w nazwie (data do frontmatter)
- Inbox (`01-inbox/`) jest tymczasowy: elementy starsze niż tydzień = przenieś lub usuń

---

## 5. Kontrakty agentów LLM

Wspólne dla Claude, Codex, ChatGPT i każdego innego agenta. Plik źródłowy: `_system/AGENTS.md`.

### Ogólne zasady

- Inspect first: czytaj plik przed edycją
- Preferuj update istniejącej notatki zamiast tworzenia duplikatu
- Małe, konkretne zmiany nad dużymi refaktorami
- Nie twórz README ani dokumentacji bez wyraźnej prośby
- Nie usuwaj notatek archiwalnych
- Wiki-linki `[[nazwa-notatki]]` — zachowaj, nie zamieniaj na URL-e

### Triggery zapisu (wykonaj natychmiast)

| Zdarzenie | Gdzie zapisać |
|-----------|---------------|
| Zmiana aktywnego zadania | `02-active-context/now.md` |
| Decyzja architektoniczna | `80-architecture/decision-log.md` |
| Nowy incydent | `40-runbooks/incidents/` |
| Nowa konwencja | `30-standards/` |
| Koniec sesji roboczej | `now.md` + `session-log.md` projektu |
| Rozmowa generująca wiedzę operacyjną | właściwy katalog, natychmiast |

### CLAUDE.md specifics

- Każdy wątek generujący wiedzę operacyjną musi być zapisany do vault
- Nie czekaj na koniec rozmowy — zapisuj w trakcie
- Obowiązkowe triggery: zmiana aktywnego zadania, implementacja, decyzja, incydent, koniec sesji
- Zawiera pełne mapowanie rozmów na katalogi

### ChatGPT specifics

- Brak dostępu do filesystem — kontekst eksportowany ręcznie jako context pack
- Format paczki: `zakres → kluczowe decyzje → stan → next step`
- Context pack target: mała ~1500 tokenów, standardowa ~3000 tokenów
- Workflow po rozmowie: `_system/CHATGPT_WORKFLOW.md`
- Zawsze sprawdź czy `_chatgpt/context-packs/<temat>.md` już istnieje — jeśli tak, zaktualizuj

### Ograniczenia i zakazy

- Nie używaj `--no-verify` ani nie pomijaj hooków git bez wyraźnej prośby
- Nie rób force-push na main bez potwierdzenia
- Nie usuwaj zasobów AWS bez potwierdzenia
- Nie uruchamiaj `terraform apply` bez wyraźnego "tak" od użytkownika

---

## 6. Cost-Aware Execution (AI FinOps)

Plik źródłowy: `_system/AI_COST_AWARE_AGENT_CONTRACT.md`.

Zasada nadrzędna: użyj najtańszego modelu i najmniejszego kontekstu wystarczającego do poprawnego wykonania zadania.

### Model tiers

| Tier | Kiedy używać | Przykłady |
|------|-------------|-----------|
| **S** — low-cost | drafting, markdown, formatting, proste aktualizacje, checklist | dopisanie sekcji do runbooka, update frontmatter |
| **M** — standard | IaC review, RCA synthesis, medium-complexity architecture, review change setów | analiza CFN failure, ocena ryzyka |
| **P** — premium | deep architecture, threat modeling, długi kontekst, sprzeczne źródła, high blast radius | architektura wielokontowa, rozwiązywanie sprzeczności |

Escalation rule: S → M → P. Escalate tylko gdy niższy tier nie rozwiązał zadania, walidacja wykazała sprzeczność lub blast radius jest wysoki.

Zakazane: `premium-by-default` dla rutynowych aktualizacji vault, formatowania, prostych notatek.

### Token frugality

- Preferuj diffs i linki nad pełnymi rewrite'ami
- Nie wklejaj stabilnego kontekstu za każdym razem — odwołuj się do niego
- Przy aktualizacji `now.md` dopisuj delta, nie pełny rewrite
- Przy context packach: kompaktowy zakres + linki do źródeł prawdy

---

## 7. Granice bezpieczeństwa kontekstu

Plik źródłowy: `_system/LLM_CONTEXT_BOUNDARY_CONTRACT.md` i `_system/DOMAIN_ISOLATION_CONTRACT.md`.

Zasada: **jedna sesja LLM = jedna domena wrażliwości.**

| Domena | Przykłady |
|--------|-----------|
| `client-work` | projekty MakoLab: rshop, planodkupow, maspex, puzzler-b2b |
| `internal-product-strategy` | LLZ, devops-toolkit roadmapa |
| `private-rnd` | osobiste projekty R&D |
| `shared-concept` | standardy AWS, wzorce Terraform, zasady vault, kontrakty LLM |

Nie łącz `client-work` + `internal-product-strategy` + `private-rnd` w jednym prompcie.

Porównanie między domenami: tylko przez `shared-concept` lub zanonimizowane summary oznaczone jako `derived insight`.

---

## 8. NotebookLM — warstwa syntezy

NotebookLM **nie jest** źródłem prawdy — jest warstwą syntezy na skurowanych paczkach z vault.

Przepływ:
```
vault → NotebookLM synthesis → notatka w vault → Claude/Codex execution
```

Używaj do: briefingów, contradiction check, decision pack, gap analysis.  
Wynik NotebookLM musi trafić do vault **zanim** zostanie użyty przez agenta.  
Pełny kontrakt: `_system/NOTEBOOKLM_CONTRACT.md`  
Lokalizacja vault: `90-reference/notebooklm/`

---

## 9. Jak używać tego pack w ChatGPT

Użyj do:
- pytań o organizację vault lub zasady notatek
- debugowania promptów dla Claude/Codex przy pracy z vault
- projektowania nowych kontraktów lub polityk agentów
- generowania nowych context packów zgodnych z tym formatem

Nie używaj do:
- rozmów o konkretnych projektach klientów (użyj dedykowanego packa)
- decyzji runtime AWS bez live verification

---

## 10. Kluczowe pliki systemowe

```
_system/AGENTS.md                      — wspólny kontrakt agentów
_system/AI_COST_AWARE_AGENT_CONTRACT.md — model tiering i token frugality
_system/CHATGPT_WORKFLOW.md            — workflow eksportu/importu ChatGPT
_system/DOMAIN_ISOLATION_CONTRACT.md  — jedna sesja = jedna domena
_system/LLM_CONTEXT_BOUNDARY_CONTRACT.md — zasady przygotowania paczek
_system/LLM_CONTEXT_GLOBAL.md         — globalny kontekst vault dla LLM
_system/NOTEBOOKLM_CONTRACT.md        — NotebookLM jako warstwa syntezy
CLAUDE.md                              — kontrakt dla Claude Code
_chatgpt/templates/context-pack-template.md — szablon nowego context packa
```
