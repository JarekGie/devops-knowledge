---
title: secure-ai-anonymizer session log
project: anonimizator / dc-anonimizator
domain: private-rnd
classification: restricted
---

# secure-ai-anonymizer — session log

Repo lokalne: `~/projekty/mako/aws-projects/dc-anonimizator`

---

## 2026-05-07 — bootstrap + KF-006 fix

### Bootstrap repozytorium

Stworzono pełną strukturę projektu `dc-anonimizator` od zera:

```
src/dc_anonymizer/{ingest,detection,tokenization,storage,audit,pipeline}
CLI: dc-anonymizer anonymize / detect / rehydrate / validate
Custom recognizers: AWS ARN/account/keys, CIDR, FQDN, DB connection strings, JWT
Envelope encryption (AESGCM) — token map
PostgreSQL schema: documents, token_maps, token_map_entries, audit_events (append-only)
Docker Compose: PostgreSQL:16 + Ollama (optional profile)
7 fixture documents (input), unit + integration tests
Makefile, pyproject.toml (uv), .gitignore, .env.example
ADR-008 (uv vs Poetry) zapisany w vault
```

### KF-006 — priority-based overlap resolution

**Problem:** entity recognizer nakładał spany o różnych priorytetach; wygrywał przypadkowy, nie najważniejszy typ encji.

**Zmiana:** `src/dc_anonymizer/tokenization/tokenizer.py` — pełny rewrite logiki overlap:
- `_ENTITY_PRIORITY` — 13 poziomów (`DB_CONNECTION_STRING=11` > `EMAIL_ADDRESS=4`)
- `_beats()` — priorytet > długość spanu > score
- `_merge_overlapping()` — kandydat wygrywa tylko gdy bije WSZYSTKIE nakładające się spany

**Testy:**
- `tests/unit/test_tokenizer.py` — +6 testów priority resolution
- `tests/regression/test_kf_002_004_006_*` — xfail usunięty z 3 testów (teraz pass)
- `docs/known-failures.md` — KF-006/KF-002/KF-004 → status: fixed

**Wyniki po naprawie:**
```
make test            → 27 passed, 4 skipped, 7 xfailed
make test-regression → 11 passed, 7 xfailed  (było 8/10 xfail)
make smoke           → PASSED
fixture analyze      → postgresql/mongodb/redis connection strings w pełni tokenizowane
```

### Nowy edge case (nie blokujący)

`API_KEY_GENERIC` (priority=9) > `AWS_ARN` (priority=8)
→ rola IAM triggeruje `API_KEY_GENERIC` jako false positive → partial ARN leak

Decyzja do podjęcia: obniżyć priorytet `API_KEY_GENERIC` lub podnieść `AWS_ARN`.

### Następne kroki

- [ ] KF-001: S3 ARN regex (brak account ID w bucket ARNs)
- [ ] KF-003: email z relaxed TLD (.internal, .example, .corp)
- [ ] nowy KF: `API_KEY_GENERIC` priority edge case (ARN partial leak)
- [ ] benchmark Ollama: llama3.2:3b vs mistral:7b
