---
title: "ADR-006: PostgreSQL jako mapping store"
domain: private-rnd
origin: own
classification: restricted
llm_exposure: restricted
cross_domain_export: prohibited
source_of_truth: vault
created: 2026-05-07
updated: 2026-05-07
status: accepted
---

# ADR-006 — PostgreSQL jako mapping store

**Status:** Accepted  
**Data:** 2026-05-07

---

## Kontekst

Token maps i audit log muszą być trwale przechowane. Opcje:
1. **PostgreSQL** — relacyjna baza z pgcrypto
2. **SQLite** — plik lokalny, zero config
3. **HashiCorp Vault** — secrets manager jako primary storage
4. **Filesystem (JSON + encrypted)** — pliki JSON z szyfrowaniem na poziomie OS
5. **Redis** — in-memory, z persistence

---

## Decyzja

**Wybrany: PostgreSQL + pgcrypto** dla token maps i audit log.

Redis jako session cache i task queue (Celery). PostgreSQL jako primary persistent store.

---

## Uzasadnienie

**Dlaczego PostgreSQL, nie SQLite?**

SQLite jest doskonały dla single-user, single-process. Problemy:
- Blokady przy concurrent writes (Celery workers)
- Brak wbudowanego szyfrowania (`pgcrypto` jest natywny w PostgreSQL)
- Trudniejsza migracja do distributed deployment w Fazie 2

PostgreSQL ma `pgcrypto` extension dla envelope encryption bez potrzeby zewnętrznych bibliotek.

**Dlaczego nie HashiCorp Vault jako primary storage?**

Vault jest doskonały dla key management (KEK), ale nie dla document storage. Przechowywanie token map w Vault:
- Wymaga custom path structure per document
- Brak SQL queries (jak "pokaż wszystkie tokeny klasy AWS_ARN z ostatniego tygodnia")
- Overhead dla każdej operacji (każdy token = osobny secret)

Vault wejdzie jako KEK store w Fazie 2. PostgreSQL przechowuje zaszyfrowane wartości (DEK-encrypted), Vault będzie przechowywał klucze DEK-encryption.

**Dlaczego nie filesystem?**

File-based storage wymaga własnego indeksowania, brak ACID guarantees, trudność z concurrent access, brak wbudowanego audytu.

**Dlaczego nie Redis jako primary?**

Redis jest in-memory. Restart kontenera → utrata danych jeśli persistence nie jest skonfigurowana prawidłowo. Token maps muszą przetrwać restarty. Redis używamy do session state i task queue — gdzie utrata przy restart jest akceptowalna.

---

## Envelope Encryption w MVP

```
Token value (original):     "864277686382"
         │
         ▼ pgp_sym_encrypt(value, DEK)
Encrypted value (in DB):    "[binary encrypted]"

DEK (Data Encryption Key):  per-document random key
         │
         ▼ pgp_sym_encrypt(DEK, KEK)
Encrypted DEK (in DB):      "[binary encrypted]"

KEK (Key Encryption Key):   z .env VAULT_KEK_SECRET
                            → Faza 2: HashiCorp Vault
```

W MVP: KEK w `.env` (lokalny plik, w `.gitignore`). Ryzyko: jeśli `.env` wycieknie, token maps można zdekryptować. Mitigation: rotacja KEK + re-encryption, dokumentacja operacyjna.

---

## Audit log — append-only

PostgreSQL nie ma natywnego "append-only table", ale można to egzekwować przez:
1. Brak `UPDATE` i `DELETE` grantu na audit_log dla application user
2. Triggery blokujące UPDATE/DELETE
3. Row-level security: tylko INSERT dozwolony

W MVP: implementacja przez grant restrictions + dokumentacja "nigdy nie rób DELETE na audit_log".

---

## Konsekwencje

- PostgreSQL musi być uruchamiane jako Docker service (Docker Compose)
- pgcrypto extension: `CREATE EXTENSION pgcrypto;` w init SQL
- Klucz KEK w `.env`, w `.gitignore`, z dokumentacją rotacji
- Backup: `pg_dump` z szyfrowanym outputem — nie bez szyfrowania
- Faza 2: migracja KEK do HashiCorp Vault (schema nie wymaga zmiany)
