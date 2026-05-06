---
title: secure-ai-anonymizer — tokenization model
domain: private-rnd
origin: own
classification: restricted
llm_exposure: restricted
cross_domain_export: prohibited
source_of_truth: vault
created: 2026-05-07
updated: 2026-05-07
---

# Tokenization Model

> Opisuje jak system zastępuje wrażliwe wartości tokenami, jak są przechowywane i jak działają reguły mapowania.

---

## Definicje

**Token** — placeholder zastępujący wrażliwą wartość w sanitized document. Format: `[KLASA_N]`.

**Token map** — zaszyfrowany mapping token → oryginalna wartość, per-dokument.

**Tokenizacja** — zastąpienie wartości tokenem + zapis do token map.

**Rehydratacja** — odwrócenie tokenizacji: zastąpienie tokenów oryginalnymi wartościami w odpowiedzi LLM.

**Sanitized document** — dokument z zastąpionymi wartościami wrażliwymi. Gotowy do eksportu.

---

## Format tokenów

Wybrany format: **Semantic tags z numerem** `[KLASA_N]`

Przykłady:
```
[AWS_ACCOUNT_1]          # pierwsze konto AWS w dokumencie
[AWS_ACCOUNT_2]          # drugie (inne) konto
[IP_ADDRESS_1]           # pierwsze IP
[IP_ADDRESS_2]           # drugie IP
[DB_CONNECTION_STRING_1] # connection string do bazy
[EMAIL_ADDRESS_1]        # adres email
[PERSON_NAME_1]          # imię i nazwisko
[AWS_ARN_1]              # ARN zasobu AWS
[API_KEY_1]              # klucz API
```

Uzasadnienie wyboru formatu: → [[adr/ADR-002-tokenization-over-masking]]

---

## Reguły mapowania

### Reguła 1 — Per-document scope

Token map jest **per-dokument**. Ta sama wartość w dwóch różnych dokumentach dostaje **różne** tokeny.

```
Dokument A: "864277686382" → [AWS_ACCOUNT_1]
Dokument B: "864277686382" → [AWS_ACCOUNT_1]  ← inny token map, ta sama liczba lokalna
```

Uzasadnienie: Izolacja między dokumentami — kompromitacja token map jednego dokumentu nie ujawnia powiązań między dokumentami.

### Reguła 2 — Intra-document consistency

Ta sama wartość w tym samym dokumencie → **zawsze ten sam token** (w tym samym pipeline run).

```
"864277686382" (linia 12) → [AWS_ACCOUNT_1]
"864277686382" (linia 45) → [AWS_ACCOUNT_1]  ← ten sam token
```

Uzasadnienie: LLM widzi spójny kontekst. Jeśli account ID pojawia się 5 razy, LLM "wie" że to ten sam account.

### Reguła 3 — Klasa determinuje prefix

Token prefix odpowiada klasie detektora, który go wykrył.

```
Klasa: AWS_ACCOUNT_ID   → token prefix: AWS_ACCOUNT_
Klasa: IP_ADDRESS       → token prefix: IP_ADDRESS_
Klasa: PERSON_NAME      → token prefix: PERSON_NAME_  (z Presidio: PERSON)
Klasa: EMAIL_ADDRESS    → token prefix: EMAIL_ADDRESS_
```

### Reguła 4 — Numer jest lokalny i sekwencyjny

Numer w tokenie to counter per-klasa w dokumencie. Zaczyna od 1.

```
Pierwsze IP: [IP_ADDRESS_1]
Drugie IP:   [IP_ADDRESS_2]
Pierwsze ARN: [AWS_ARN_1]
Drugie ARN:   [AWS_ARN_2]
```

### Reguła 5 — Kontekst jest zachowany w strukturze

Token zastępuje wartość, ale otaczający tekst pozostaje niezmieniony:

```
Przed:  "account_id = 864277686382, region = eu-west-1"
Po:     "account_id = [AWS_ACCOUNT_1], region = [AWS_REGION_1]"
```

LLM widzi strukturę i kontekst, ale nie widzi wartości.

---

## Token Map Schema (PostgreSQL)

```sql
CREATE TABLE token_maps (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id  UUID NOT NULL REFERENCES documents(id),
    token        TEXT NOT NULL,           -- "[AWS_ACCOUNT_1]"
    class        TEXT NOT NULL,           -- "AWS_ACCOUNT_ID"
    confidence   FLOAT NOT NULL,          -- 0.0 - 1.0
    encrypted_value TEXT NOT NULL,        -- pgcrypto: pgp_sym_encrypt(original, key)
    occurrences  JSONB,                   -- [{chunk: 3, position: 45}, ...]
    created_at   TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (document_id, token)
);

CREATE TABLE documents (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    filename     TEXT NOT NULL,
    doc_type     TEXT NOT NULL,
    status       TEXT NOT NULL,           -- parsed | anonymized | rehydrated
    token_count  INT,
    created_at   TIMESTAMPTZ DEFAULT NOW(),
    updated_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE audit_log (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id  UUID NOT NULL,
    operation    TEXT NOT NULL,           -- parse | anonymize | review | rehydrate
    operator     TEXT,
    metadata     JSONB,
    created_at   TIMESTAMPTZ DEFAULT NOW()
    -- BRAK UPDATE / DELETE — append-only
);
```

---

## Klasy danych v1 — pełna lista

### PII (przez Presidio)
| Klasa | Przykład | Precedio entity |
|-------|---------|-----------------|
| PERSON_NAME | Jan Kowalski | PERSON |
| EMAIL_ADDRESS | jan@makolab.com | EMAIL_ADDRESS |
| PHONE_NUMBER | +48 123 456 789 | PHONE_NUMBER |
| DATE_OF_BIRTH | 1990-01-15 | DATE_TIME (filtered) |
| LOCATION | Warszawa, Łódź | LOCATION |

### AWS / Cloud Infrastructure
| Klasa | Przykład | Detektor |
|-------|---------|----------|
| AWS_ACCOUNT_ID | 123456789012 | regex: `\b\d{12}\b` + context |
| AWS_ARN | arn:aws:iam::123... | regex: `arn:aws:[a-z]+:` |
| AWS_ACCESS_KEY | AKIAIOSFODNN7EXAMPLE | regex: `(A3T|AKIA|AGPA|AIDA|AROA|AIPA|ANPA|ANVA|ASIA)[A-Z0-9]{16}` |
| AWS_SECRET_KEY | wJalrXUtnFEMI/K7MDENG | context-based (near ACCESS_KEY) |
| AWS_REGION | eu-west-2 | regex: `(us|eu|ap|sa|ca|af|me)-[a-z]+-\d` |

### Networking
| Klasa | Przykład | Detektor |
|-------|---------|----------|
| IP_ADDRESS | 10.0.1.45 | Presidio IP_ADDRESS |
| CIDR_BLOCK | 10.0.0.0/16 | regex: `\d+\.\d+\.\d+\.\d+/\d+` |
| HOSTNAME_FQDN | db.internal.makolab.com | regex: `[a-z0-9-]+\.[a-z0-9-]+\.[a-z]{2,}` + context |

### Secrets / Credentials
| Klasa | Przykład | Detektor |
|-------|---------|----------|
| DB_CONNECTION_STRING | mongodb://user:pass@host | regex: `(mongodb|postgresql|mysql)://` |
| API_KEY_GENERIC | Bearer eyJhbGci... | context: `key=`, `token=`, `Bearer ` |
| JWT_TOKEN | eyJ... | regex: `eyJ[A-Za-z0-9-_]+\.[A-Za-z0-9-_]+` |
| SSH_PRIVATE_KEY | -----BEGIN RSA... | regex: `-----BEGIN (RSA|OPENSSH|EC)` |
| ENV_SECRET | SECRET=abc123 | regex: `(SECRET|PASSWORD|TOKEN|KEY)\s*=\s*\S+` |

---

## Confidence thresholds

| Threshold | Akcja |
|-----------|-------|
| >= 0.90 | Automatyczna tokenizacja |
| 0.70 – 0.89 | Tokenizacja + flag do manual review |
| < 0.70 | Flag do manual review, brak auto-tokenizacji |

Domyślny próg tokenizacji: **0.75** (konfigurowalny).

---

## Zachowanie edge cases

**Overlapping detections** — gdy dwa recognizery wykrywają tę samą wartość:
- Wygrywa recognizer z wyższym confidence
- Jeśli confidence równy — wygrywa bardziej specifyczna klasa (AWS_ACCOUNT_ID przed NUMERIC_ID)

**Partial match** — gdy recognizer wykrywa część wartości:
- Tokenizuj cały token (rozszerzony kontekst), nie tylko wykrytą część

**Nested values** — gdy token map musi pokryć wartość wewnątrz struktury JSON/YAML:
- Tokenizuj wartość, nie klucz
- Zachowaj strukturę klucz=token

**Connection strings** — zawierają wiele wrażliwych wartości (user, pass, host):
- Tokenizuj cały string jako DB_CONNECTION_STRING_N
- Nie tokenizuj komponentów osobno (zbyt wiele tokenów, utrata czytelności)
