---
title: secure-ai-anonymizer — architecture
domain: private-rnd
origin: own
classification: restricted
llm_exposure: restricted
cross_domain_export: prohibited
source_of_truth: vault
created: 2026-05-07
updated: 2026-05-07
---

# Architektura — secure-ai-anonymizer

> System jest lokalnym pipeline przetwarzania dokumentów. Nie jest AI — jest warstwą bezpieczeństwa przed AI.

---

## Główny flow systemu

```
INPUT DOCUMENT
(PDF / DOCX / XLSX / Terraform / YAML / TXT / logi)
        │
        ▼
[1] PARSING LAYER
  Apache Tika (structure extraction)
  Unstructured (layout-aware chunking)
  pdfplumber (tabele w PDF)
        │
        ▼
[2] CLASSIFICATION LAYER
  Ollama + lokalny model (sanity-check: czy dokument zawiera dane wrażliwe?)
  Heuristic rules (pre-filter)
        │
        ▼
[3] DETECTION LAYER
  Microsoft Presidio (PII: imiona, emaile, numery telefonów, daty)
  spaCy NER (named entities)
  Custom recognizers (infra, cloud, sekrety, networking — patrz niżej)
        │
        ▼
[4] TOKENIZATION LAYER
  Każda wykryta wartość → token [KLASA_N] (np. [AWS_ACCOUNT_3], [IP_ADDRESS_1])
  Token map: { token → { original_value, class, position, confidence } }
  Token map: szyfrowany envelope encryption (PostgreSQL + pgcrypto / Vault w Fazie 2)
        │
        ▼
[5] SANITIZED OUTPUT
  sanitized_document.md (lub .txt / .json)
  → gotowy do eksportu do zewnętrznego LLM
        │
        ▼ (opcjonalnie, po odpowiedzi LLM)
[6] REHYDRATION LAYER
  Wczytaj token map (wymaga autoryzacji)
  Zastąp tokeny oryginalnymi wartościami
  Audit trail: kto rehydratował, kiedy, jaki dokument
        │
        ▼
[7] AUDIT LOG
  PostgreSQL: append-only log wszystkich operacji
  Per document, per token, per session
```

---

## Komponenty — stack MVP

### Parsing

| Komponent | Rola | Format |
|-----------|------|--------|
| Apache Tika | Ekstrakcja tekstu z PDF, DOCX, XLSX | → raw text |
| Unstructured | Layout-aware chunking, sekcje, nagłówki | → structured chunks |
| pdfplumber | Tabele w PDF (gdy Tika traci strukturę) | → tabele jako CSV |

**Zasada:** Parser nie modyfikuje treści — tylko ekstrahuje. Klasyfikacja i detekcja są osobną warstwą.

### Detection — recognizery v1

Presidio domyślnie pokrywa klasy PII. Custom recognizery dla klas cloud/infra:

```python
# Klasy custom recognizerów (regex + NLP):

INFRA_RECOGNIZERS = [
    "AWS_ACCOUNT_ID",          # 12-cyfrowy number
    "AWS_ARN",                 # arn:aws:...
    "AWS_ACCESS_KEY",          # AKIA..., ASIA...
    "AWS_SECRET_KEY",          # 40-char base64-like
    "AWS_REGION",              # eu-west-1, us-east-1...
    "CIDR_BLOCK",              # 10.0.0.0/8
    "IP_ADDRESS",              # IPv4, IPv6
    "HOSTNAME_FQDN",           # *.internal, *.local
    "DOCKER_IMAGE_TAG",        # registry.example.com/image:sha
    "K8S_NAMESPACE",           # namespace patterns
]

SECRETS_RECOGNIZERS = [
    "DB_CONNECTION_STRING",    # mongodb://, postgresql://
    "API_KEY_GENERIC",         # Bearer ..., api_key = ...
    "JWT_TOKEN",               # eyJ... header
    "SSH_PRIVATE_KEY",         # -----BEGIN RSA...
    "CERTIFICATE_PEM",         # -----BEGIN CERTIFICATE...
    "ENV_SECRET",              # SECRET=, PASSWORD=, TOKEN=
]

APP_RECOGNIZERS = [
    "GITHUB_REPO",             # github.com/org/repo
    "JIRA_TICKET",             # PROJ-1234
    "INTERNAL_URL",            # *.makolab.*, *.internal
    "SLACK_WEBHOOK",           # hooks.slack.com/...
]

SECURITY_RECOGNIZERS = [
    "CVE_ID",                  # CVE-YYYY-NNNN
    "VULNERABILITY_DETAILS",   # combined heuristic
]
```

### Tokenization

Format tokenów w MVP: **semantic tags z numerem** — `[KLASA_N]`

Przykład:
```
Konto AWS 864277686382 → [AWS_ACCOUNT_1]
Region eu-west-2 → [AWS_REGION_1]
ARN arn:aws:ecs:eu-west-2:... → [AWS_ARN_1]
IP 10.0.1.45 → [IP_ADDRESS_1]
```

Uzasadnienie: → [[adr/ADR-002-tokenization-over-masking]]

Token map (per document, szyfrowany):
```json
{
  "document_id": "uuid",
  "tokens": {
    "[AWS_ACCOUNT_1]": {
      "original": "864277686382",
      "class": "AWS_ACCOUNT_ID",
      "confidence": 0.99,
      "occurrences": [{"chunk": 3, "position": 45}]
    }
  }
}
```

### Storage

| Komponent | Co przechowuje | Szyfrowanie |
|-----------|---------------|-------------|
| PostgreSQL | token maps, audit log, document metadata | envelope encryption (pgcrypto) |
| Redis | session state, processing queue | in-memory, TTL |
| Filesystem | original documents (input), sanitized output | opcjonalnie: encrypted volume |

**Zasada:** Original documents **NIGDY** nie opuszczają lokalnego systemu. Tylko sanitized documents mogą wyjść.

### Local inference (sanity-check)

Ollama + lokalny model do klasyfikacji wstępnej:
- Czy dokument zawiera dane wrażliwe? (binary: tak/nie, z confidence)
- Jakie klasy danych prawdopodobnie zawiera? (hints dla pipeline)

Nie jest to detektor — jest to pre-filter redukujący false positives. Właściwa detekcja: Presidio + custom recognizers.

Model: llama3.2 lub mistral (do ustalenia w PoC, → ADR-007)

---

## Architektura danych — separacja

```
┌────────────────────────────────┐
│   LOKALNE (restricted zone)    │
│                                │
│  original_document.pdf         │
│  token_map (encrypted)         │
│  audit_log                     │
│  local_model (Ollama)          │
│                                │
└────────────────────────────────┘
            │  tylko sanitized document
            ▼
┌────────────────────────────────┐
│   EXTERNAL LLM ZONE            │
│                                │
│  ChatGPT / Claude / NotebookLM │
│  (widzi tylko tokeny, nie dane)│
│                                │
└────────────────────────────────┘
            │  odpowiedź z tokenami
            ▼
┌────────────────────────────────┐
│   REHYDRATION (restricted zone)│
│                                │
│  rehydrated_response.md        │
│  audit_entry                   │
│                                │
└────────────────────────────────┘
```

---

## API — MVP endpoints

```
POST /documents/parse
  Body: { file: multipart, doc_type: "pdf"|"docx"|"yaml"|"terraform"|"text" }
  Returns: { doc_id, chunk_count, parse_status }

POST /documents/anonymize
  Body: { doc_id, recognizer_pack: "default"|"infra"|"pii"|"secrets" }
  Returns: { doc_id, token_count, confidence_avg, sanitized_text }

GET /documents/{doc_id}/tokens
  Returns: { token_count, classes_detected, requires_review: bool }
  Note: NIE zwraca wartości oryginalnych

POST /documents/{doc_id}/rehydrate
  Body: { llm_response_text, authorization_token }
  Returns: { rehydrated_text, tokens_replaced }

GET /audit/{doc_id}
  Returns: { operations: [...], created_at, last_rehydration }
```

---

## Diagram komponentów (MVP)

```
CLI / FastAPI
     │
     ├── ParseService
     │     ├── TikaClient
     │     ├── UnstructuredClient
     │     └── PdfPlumberClient
     │
     ├── DetectionService
     │     ├── PresidioAnalyzer
     │     ├── SpacyNER
     │     └── CustomRecognizerRegistry
     │
     ├── TokenizationService
     │     ├── TokenGenerator
     │     ├── TokenMapStore (PostgreSQL)
     │     └── EncryptionService (pgcrypto)
     │
     ├── SanityCheckService
     │     └── OllamaClient
     │
     ├── RehydrationService
     │     ├── AuthorizationGate
     │     └── TokenResolver
     │
     └── AuditService
           └── AuditLog (PostgreSQL, append-only)
```

---

## Decisions

| Obszar | Decyzja | ADR |
|--------|---------|-----|
| Deployment model | Local-first, Docker Compose | [[adr/ADR-001-local-first]] |
| Token format | Semantic tags vs masking | [[adr/ADR-002-tokenization-over-masking]] |
| PII detection | Microsoft Presidio | [[adr/ADR-003-presidio]] |
| LLM flow | External LLM only after tokenization | [[adr/ADR-004-external-llm-after-tokenization]] |
| Pipeline | Deterministic, no AI in core path | [[adr/ADR-005-deterministic-pipeline]] |
| Storage | PostgreSQL as mapping store | [[adr/ADR-006-postgresql-mapping-store]] |
| Local model | Ollama for sanity-check only | [[adr/ADR-007-ollama-local-inference]] |
