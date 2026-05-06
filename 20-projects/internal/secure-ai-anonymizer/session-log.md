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

---

## 2026-05-07 — Bootstrap repozytorium

**Akcja:** Pełny bootstrap `~/projekty/mako/aws-projects/dc-anonimizator`.

**Wykonane:**

Struktura katalogów:
- `src/dc_anonymizer/` — główny pakiet Python
- `src/dc_anonymizer/ingest/` — router + text/yaml/pdf extractors
- `src/dc_anonymizer/detection/` — Presidio engine + recognizers (aws, network, secrets)
- `src/dc_anonymizer/tokenization/` — tokenizer, token_map (envelope encryption), rehydration
- `src/dc_anonymizer/storage/` — database (SQLAlchemy), repositories
- `src/dc_anonymizer/audit/` — audit_log (append-only)
- `src/dc_anonymizer/pipeline/` — anonymize.py (główny orchestrator)
- `tests/unit/` — test_tokenizer.py, test_recognizers.py
- `tests/integration/` — test_pipeline.py (roundtrip + rehydration)
- `tests/fixtures/input/` — 7 dokumentów testowych (aws_account_id, aws_arn, cidr, hostname, connection_string, email, mixed)
- `docs/` — architecture.md, mvp-scope.md, adr/
- `scripts/` — init-db.sql (4 tabele + pgcrypto), smoke-test.sh

Pliki konfiguracyjne:
- `pyproject.toml` — uv, Python 3.12, pełne zależności
- `.python-version` — 3.12
- `.gitignore` — blokuje .env, client_input/, token_maps/, rehydrated/, db_dumps/
- `.env.example` — szablon z DATABASE_URL, KEK_HEX, OLLAMA_*
- `docker-compose.yml` — PostgreSQL:16 + Ollama (profile: ai)
- `Makefile` — install, test, lint, format, db-up, db-down, db-reset, smoke, ollama-up

ADR-008 dodany do vault: uv vs Poetry — wybór uv.

**Kluczowe decyzje:**
- **uv** zamiast Poetry (ADR-008) — szybszy, PEP 621, standard 2026
- CLI-first (MVP) — bez FastAPI/Redis/Celery w tym etapie
- Envelope encryption w Python (cryptography AESGCM) — pgcrypto tylko na poziomie bazy
- Audit log: append-only przez aplikację (REVOKE DELETE/UPDATE jako TODO na Phase 2)

**Stan:** repo bootstrapped, gotowy do `uv sync` + `make db-up` + implementacji PoC.

**Następny krok:**
→ `uv sync` + `python -m spacy download en_core_web_lg`
→ `make db-up`
→ Implementacja pierwszego roundtrip: `dc-anonymizer anonymize --input tests/fixtures/input/mixed_document.txt`
→ Benchmark Ollama: llama3.2:3b vs mistral:7b na fixture documents
