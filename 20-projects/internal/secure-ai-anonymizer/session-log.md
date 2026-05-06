---
title: secure-ai-anonymizer — session log
domain: private-rnd
origin: own
classification: restricted
llm_exposure: restricted
cross_domain_export: prohibited
source_of_truth: vault
created: 2026-05-07
updated: 2026-05-07
---

# Session Log — secure-ai-anonymizer

---

## 2026-05-07 — Inicjacja projektu

**Akcja:** Inicjacja projektu w vault. Brak kodu — tylko planowanie.

**Wykonane:**
- Utworzono strukturę projektu w `20-projects/internal/secure-ai-anonymizer/`
- context.md — definicja projektu, motywacja, scope
- roadmap.md — fazy PoC → MVP → Internal alpha → Controlled production → Enterprise
- architecture.md — główny flow, komponenty, API, schema danych
- mvp-scope.md — granice MVP, test cases, definicja "done"
- threat-model.md — 10 zagrożeń z prioritetami i mitigacjami
- tokenization-model.md — format tokenów, reguły mapowania, klasy danych, schema PostgreSQL
- data-classification.md — 5 klas danych (PII, Infra, Secrets, Business, Metadata)
- glossary.md — terminologia projektu
- adr/ — 7 ADR dla kluczowych decyzji architektonicznych
- _chatgpt/context-packs/secure-ai-anonymizer.md — context pack dla ChatGPT

**Inicjator:** Tomasz Polke (Head of Cloud)
**Właściciel:** Jarosław Gołąb

**Open questions na wejściu (do rozwiązania w PoC):**
1. Token format — semantic tags wybrany, ale wymaga weryfikacji na realnych dokumentach
2. Ollama model — llama3.2 vs mistral, do testu w PoC
3. Scope recognizerów v1 — lista klas zdefiniowana, ale coverage wymaga testu
4. MVP jako CLI vs FastAPI — wstępna decyzja: FastAPI od początku (testability)
5. Audit trail granularity — per token (zdecydowano), implementacja wymaga weryfikacji

**Następny krok:**
→ Repozytorium: `~/projekty/mako/aws-projects/dc-anonimizator` (istnieje)
→ PoC: `anonymize.py` — CLI roundtrip test na 3 dokumentach (Terraform, YAML, log)
→ Wybór Ollama model dla sanity-check
