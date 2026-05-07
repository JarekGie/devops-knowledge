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

---

## 2026-05-07 — Smoke test fixes

**Problem:** `make smoke` failowało na 2 błędach runtime.

**Root causes i naprawione pliki:**

1. **`src/dc_anonymizer/cli.py`** — `RecognizerResult` (Presidio) nie jest Pydantic — brak `model_dump()` i `text`. Fix:
   - `r.model_dump()` → `r.to_dict()`
   - `r.text` → `raw_text[r.start:r.end]` (wymagało doładowania tekstu z `ingest.router.extract`)

2. **`src/dc_anonymizer/audit/audit_log.py`** — `:meta::jsonb` PostgreSQL cast nie parsuje się poprawnie przez psycopg3+SQLAlchemy `text()`. Fix:
   - `:meta::jsonb` → `CAST(:meta AS JSONB)`

**Wynik po naprawkach:**

```
=== SMOKE PASSED ===
[OK] preflight (env, KEK, spaCy, psycopg3)
[OK] DB connection + schema
[OK] detect (20 entities)
[OK] anonymize (7 tokens, document_id zapisany)
[OK] AWS account ID usunięty z output
[OK] rehydrate (output = original)
[OK] audit events (1 event per run)
```

**Deterministyczny:** 2 uruchomienia → identyczny token count (7), zawsze PASSED.

**Następny krok:**
→ Benchmark Ollama modeli
→ Testowanie na realnych dokumentach (Terraform, YAML, logi)

---

## 2026-05-07 — Audit trail dla rehydrate

**Problem:** operacja `rehydrate` nie zapisywała eventu do `audit_events`. Smoke pokazywało tylko 1 event.

**Naprawione pliki:**

1. **`src/dc_anonymizer/tokenization/rehydration.py`** — dodano `log_event()` po udanej rehydratacji:
   - `operation = "rehydrate"`
   - metadata: `token_map_id`, `input_path`, `output_path`, `tokens_rehydrated_count`
   - NIE loguje: oryginalnych wartości, treści dokumentu, token map entries

2. **`scripts/smoke-test.sh`** — warunek audit zmieniony z `gt 0` → `ge 2`, sprawdza obecność obu eventów (`anonymize`, `rehydrate`)

3. **`tests/integration/test_pipeline.py`** — 2 nowe testy:
   - `test_rehydrate_audit_event_recorded` — weryfikuje obecność obu operacji w audit log
   - `test_rehydrate_audit_metadata_no_secrets` — weryfikuje że audit payload nie zawiera haseł z fixture

**Wyniki:**
```
make smoke → PASSED (2 events: anonymize,rehydrate)
make test  → 10 passed, 4 skipped (integration: 4 passed z DATABASE_URL)
```

**Następny krok:**
→ Coverage workflow i regression tests → patrz sekcja niżej

---

## 2026-05-07 — Recognizer coverage workflow

**Cel:** Przekształcenie ad-hoc debugowania w uporządkowany workflow jakości.

**Nowe pliki:**
- `docs/known-failures.md` — 6 znanych failures (KF-001 do KF-006) z severity, root cause, regression test pointers
- `docs/recognizer-coverage-matrix.md` — coverage table dla 12 entity types + overlap priority table
- `docs/testing-workflow.md` — 8-krokowy workflow: fixture → detect → anonymize → grep → rehydrate → diff → classify → register
- `tests/regression/` — 4 pliki, 18 testów: 8 pass (must-not-regress), 10 xfail (known broken)
- `scripts/analyze-fixture.sh` — end-to-end fixture analysis z leakage checks i audit summary
- `make analyze-fixture FILE=<path>` + `make test-regression`

**Zidentyfikowane failures:**

| ID | Severity | Problem |
|----|----------|---------|
| KF-001 | high | S3 ARN bez account ID nie matchuje (regex wymaga `\d{12}`) |
| KF-002 | **critical** | EMAIL_ADDRESS (score 1.0) bije DB_CONNECTION_STRING (0.97) → prefix leakuje |
| KF-003 | high | `.internal`/`.local` TLD nie w liście Presidio → email nie wykryty, URL partial match |
| KF-004 | **critical** | Double-`@` w password → ta sama przyczyna co KF-002 |
| KF-005 | medium | `API`, `VPC` tokenizowane jako ORGANIZATION przez spaCy NER |
| KF-006 | **critical** | `_merge_overlapping` zastępuje outer span przez inner span o wyższym score |

**Root cause priority:** KF-006 (overlap resolution) jest przyczyną KF-002 i KF-004.

**Wyniki testów:**
```
make smoke          → PASSED (2 events: anonymize,rehydrate)
make test           → 18 passed, 4 skipped, 10 xfailed
make test-regression → 8 passed, 10 xfailed
```

**Następny krok:**
→ Fix KF-006 (overlap resolution algorithm) → unblocks KF-002 i KF-004
→ Fix KF-001 (S3 ARN regex — S3 bucket ARNs bez account ID)
→ Fix KF-003 (custom email recognizer z relaxed TLD)
