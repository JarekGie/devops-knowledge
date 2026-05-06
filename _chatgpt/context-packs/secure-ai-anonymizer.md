---
title: ChatGPT context — secure-ai-anonymizer
domain: private-rnd
origin: own
classification: internal
llm_exposure: restricted
cross_domain_export: prohibited
source_of_truth: vault
created: 2026-05-07
updated: 2026-05-07
tags: [chatgpt, context-pack, secure-ai, anonymizer, tokenization, private-rnd]
---

# ChatGPT Context Pack — secure-ai-anonymizer

> Kontekst do pracy z ChatGPT nad projektem secure-ai-anonymizer.
> Zakres: private-rnd — projekt wewnętrzny, nie zawiera danych klientów.
> Używaj z ChatGPT Enterprise (no-training) lub Claude API.

**Data:** 2026-05-07  
**Zakres:** architektura, tokenizacja, stack technologiczny, open questions, roadmapa

---

## 1. Kim jestem / kontekst roli

Senior DevOps/SRE, AWS-primary, Cloud Practice Lead w MakoLab (software house ~150 osób). ADHD. Odpowiedzi: techniczne, konkretne, bez wstępów. Werdykt na górze.

Stack: Python, AWS, Terraform, ECS Fargate, PostgreSQL, Redis, Docker.

---

## 2. Czym jest projekt

**secure-ai-anonymizer** — lokalny pipeline anonimizacji dokumentów klientów przed ich wysyłką do zewnętrznych LLM.

**Problem:** Praca z dokumentami klientów (infrastruktura, specyfikacje, logi) przy użyciu ChatGPT/Claude wymaga ręcznej anonimizacji. Ręczny proces jest podatny na błędy i nie jest audytowalny.

**Rozwiązanie:** System który:
1. Parsuje dokument (PDF, DOCX, Terraform, YAML, logi)
2. Wykrywa dane wrażliwe (PII, AWS IDs, sekrety, networking)
3. Tokenizuje — zastępuje wartości tokenami `[KLASA_N]`
4. Tworzy zaszyfrowany token map (lokalny)
5. Generuje sanitized document gotowy do ChatGPT
6. Umożliwia rehydratację odpowiedzi LLM z przywróceniem oryginalnych wartości
7. Tworzy audit trail każdej operacji

**To NIE jest:** chatbot, RAG, AI app, generatywny AI.

**To jest:** secure pre-processing pipeline dla operator-grade AI enablement.

---

## 3. Zakres (scope boundaries)

**W MVP:**
- Lokalne parsowanie (Python: Tika, Unstructured, pdfplumber)
- Detekcja: Presidio + spaCy + custom recognizers (AWS infra, secrets, networking)
- Tokenizacja z semantic tags `[KLASA_N]`
- Storage: PostgreSQL (token maps, audit), Redis (session)
- Szyfrowanie: envelope encryption z pgcrypto
- Sanity-check: Ollama + lokalny model (llama3.2 lub mistral)
- REST API: FastAPI (parse, anonymize, rehydrate, audit)
- Offline-first, Docker Compose

**Poza MVP:**
- UI
- RBAC / multi-user
- HashiCorp Vault (Faza 2)
- OpenSearch / Qdrant (Faza 2/3)
- Automatyczny routing do LLM (NIGDY w scope)
- Multi-tenant SaaS (Faza 4)

---

## 4. Główny flow

```
INPUT: dokument (PDF/DOCX/TF/YAML/log)
  ↓ Parsing (Tika + Unstructured)
  ↓ Detection (Presidio + spaCy + custom recognizers)
  ↓ Tokenization → [KLASA_N] tokens + encrypted token map (PostgreSQL)
  ↓ Sanity-check (Ollama: czy coś wrażliwego zostało?)
  ↓ Manual review przez operatora
OUTPUT: sanitized_document.md (gotowy do ChatGPT)

OPERATOR → kopiuje sanitized doc do ChatGPT → otrzymuje odpowiedź
→ REHYDRATION: odpowiedź + token map → rehydrated response (lokalne)
→ AUDIT LOG: każda operacja zapisana (append-only)
```

**Zasada kluczowa:** System NIGDY nie wysyła automatycznie do zewnętrznego LLM. Operator zawsze robi to manualnie.

---

## 5. Stack technologiczny

| Warstwa | Technologia | Rola |
|---------|------------|------|
| Parsing | Apache Tika, Unstructured, pdfplumber | Ekstrakcja tekstu z różnych formatów |
| Detection | Microsoft Presidio, spaCy | PII + named entity detection |
| Custom detectors | Regex + context | AWS ARN, CIDR, secrets, connection strings |
| Local AI | Ollama + llama3.2/mistral | Sanity-check (pre-send validation) |
| API | FastAPI | REST endpoints |
| Storage | PostgreSQL + pgcrypto | Token maps, audit log |
| Queue | Redis + Celery | Async processing |
| Deploy | Docker Compose | Local dev + prod |

---

## 6. Klasy danych (co jest tokenizowane)

**PII** — imiona, emaile, telefony, PESEL, adresy  
**AWS Infra** — account IDs, ARNy, access keys, regiony  
**Networking** — IP (v4/v6), CIDR bloki, FQDNy  
**Secrets** — connection strings, API keys, JWT, SSH keys, env vars z wartościami  
**Business** — nazwy klientów, budżety, kluczowe daty

Format tokenu: `[AWS_ACCOUNT_1]`, `[IP_ADDRESS_3]`, `[EMAIL_ADDRESS_1]`

---

## 7. Kluczowe decyzje architektoniczne

| Decyzja | Wybór | Uzasadnienie |
|---------|-------|-------------|
| Deployment | Local-first | Dane wrażliwe nie mogą opuszczać środowiska operatora |
| Tokenizacja | Semantic tags `[KLASA_N]` | Rehydration + LLM rozumie klasę, nie tylko placeholder |
| PII detection | Presidio + custom recognizers | NLP coverage + extensible + offline |
| Zewnętrzny LLM | Tylko po tokenizacji | Compliance z LLM_EXPORT_POLICY vault |
| Pipeline | Deterministyczny | Audytowalność + regression testing |
| Storage | PostgreSQL + pgcrypto | ACID + envelope encryption bez cloud dependency |
| Local AI | Ollama (sanity-check only) | Pre-filter, nie gatekeeper |

---

## 8. Aktualny stan

**Faza:** PoC planning (2026-05-07)  
**Repo:** TBD — `~/projekty/devops/secure-ai-anonymizer`  
**Brak kodu** — inicjacja projektu, dokumentacja architektoniczna w vault

---

## 9. Open questions

1. **Token format** — semantic `[KLASA_N]` wybrany. Czy LLM reaguje lepiej na `[AWS_ACCOUNT_1]` vs `[REDACTED_1]`? Wymaga testu.
2. **Ollama model** — llama3.2:3b vs mistral:7b dla sanity-check. Benchmark w PoC.
3. **Recognizer scope v1** — która klasa danych ma najwyższy false negative risk w cloud/infra dokumentach?
4. **FastAPI vs CLI-first** — FastAPI od początku (lepsze testability) vs CLI PoC (prostszy start)?
5. **Audit trail granularity** — per token (kompleksowość) vs per document (prostsze). Zdecydowano: per token.
6. **Rehydration authorization** — w MVP: tylko API token w `.env`. Jak uniknąć że ktoś przypadkowo uruchomi rehydration bez świadomości?

---

## 10. Roadmapa (skrócona)

| Faza | Cel | Status |
|------|-----|--------|
| PoC | CLI roundtrip test na 5 dokumentach | aktywna |
| MVP | FastAPI + PostgreSQL + Docker Compose, 10 test cases | planowana |
| Internal alpha | Użycie przez cloud practice, feedback loop | TBD |
| Controlled prod | Formalny onboarding projektów, data retention | TBD |
| Enterprise | Multi-tenant, SSO, compliance | TBD |

---

## 11. Jak używać tego pack w ChatGPT

Użyj do:
- dyskusji architektury (tokenizacja, recognizery, pipeline)
- implementacji konkretnych komponentów (custom Presidio recognizers, FastAPI endpoints, PostgreSQL schema)
- wyboru Ollama modelu do sanity-check
- projektu audit trail

Nie używaj do:
- decyzji operacyjnych dotyczących danych klientów (to jest `private-rnd`)
- rozmów łączących projekt z konkretnym klientem (DOMAIN_ISOLATION_CONTRACT)
- planowania roadmapy biznesowej / strategii produktowej
