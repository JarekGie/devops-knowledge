---
title: secure-ai-anonymizer — MVP scope
domain: private-rnd
origin: own
classification: restricted
llm_exposure: restricted
cross_domain_export: prohibited
source_of_truth: vault
created: 2026-05-07
updated: 2026-05-07
---

# MVP Scope — secure-ai-anonymizer

> Definicja granic MVP. Wszystko poza tą listą → Faza 2 lub backlog.
> Reguła: jeśli feature nie jest potrzebny do roundtrip test na 10 dokumentach, nie wchodzi do MVP.

---

## W scope MVP

### Parsing

- [x] Tekst plain (`.md`, `.txt`, `.yaml`, `.tf`, `.json`, logi)
- [x] PDF — tekst (nie skan/obraz)
- [x] DOCX — tekst i tabele
- [ ] XLSX — tylko tekst i wartości komórek (bez formuł)

### Detection

- [x] PII standard: imię, nazwisko, email, numer telefonu, data urodzenia — przez Presidio
- [x] AWS infra: account ID, ARN, region, access key, secret key
- [x] Network: IP address (IPv4/IPv6), CIDR, hostname/FQDN
- [x] Secrets/credentials: connection strings, API keys, JWT, SSH private key, env variable z wartością
- [ ] JIRA tickets, Slack webhooks, GitHub repos — opcjonalnie jeśli czas pozwoli

### Tokenizacja

- [x] Semantic tag format: `[KLASA_N]`
- [x] Per-document token map w PostgreSQL (szyfrowany)
- [x] Deterministyczność: te same wartości w jednym dokumencie → ten sam token
- [x] Cross-document: ta sama wartość w różnych dokumentach → **różne** tokeny (per-document isolation)

### API

- [x] `POST /documents/anonymize` — pełny pipeline parse → detect → tokenize → sanitized output
- [x] `GET /documents/{id}/tokens` — lista tokenów (bez wartości oryginalnych)
- [x] `POST /documents/{id}/rehydrate` — rehydratacja po explicit authorization
- [x] `GET /audit/{id}` — audit log dokumentu

### Storage

- [x] PostgreSQL: token maps, audit log
- [x] Redis: session cache, task queue
- [x] Envelope encryption pgcrypto (symetryczne, klucz per-dokument)

### Local inference

- [x] Ollama: sanity-check — czy dokument wymaga anonimizacji?
- [x] Nie używany w core detection path — tylko pre-filter

### Operacyjne

- [x] Docker Compose (dev mode)
- [x] Offline-first — zero zewnętrznych zależności runtime
- [x] Append-only audit log (no DELETE/UPDATE na wpisach)
- [x] Manual review step przed rehydratacją (nie auto)
- [x] Logowanie na poziomie INFO/WARNING/ERROR (nie debug dump wartości)

---

## Poza scope MVP

| Feature | Powód odroczenia | Faza |
|---------|-----------------|------|
| UI (web interface) | FastAPI /docs wystarczy | 2 |
| RBAC / multi-user | Jeden operator w MVP | 2 |
| HashiCorp Vault | pgcrypto wystarczy w MVP | 2 |
| OpenSearch | Wyszukiwanie nie jest blokerem | 2 |
| Qdrant / vector search | MVP nie robi semantic queries | 3 |
| Batch processing (100+ docs) | Nie potrzebne w PoC | 2 |
| OCR (skanowane PDF) | Wymaga osobnej ścieżki | 2 |
| Automatyczny routing do LLM | Poza scope — system sanitizuje, nie routuje | Nigdy w MVP |
| Multi-tenant / SaaS | Zbyt duże dla MVP | 4 |
| Keycloak / SSO | Faza 4 | 4 |
| Automatic secret rotation | Nie wymagana w dev mode | 3 |
| GDPR data retention automation | Manual wystarczy | 3 |

---

## Definicja "done" dla MVP

MVP jest done gdy:
1. Pipeline wykonuje roundtrip na 10 różnych dokumentach (mix: YAML, Terraform, logi, PDF) — deterministycznie.
2. Audit log zawiera kompletny ślad każdej operacji.
3. Rehydratacja wymaga explicit authorization (nie auto).
4. System działa offline (Docker Compose, bez zewnętrznych zależności).
5. False positive rate recognizerów < 15% na test cases.
6. Dokumentacja: README z instrukcją uruchomienia + opis API.

---

## Test cases — dokumenty MVP

Klasy dokumentów do pokrycia (zanonimizowane wersje z cloud-detective):

| # | Typ | Zawiera klasy danych |
|---|-----|---------------------|
| 1 | Terraform `.tf` | AWS ARNs, CIDR, account IDs, resource names |
| 2 | cloud-detective output `.md` | AWS IDs, IPs, endpoints, service names |
| 3 | `docker-compose.yml` | env vars z sekretami, connection strings |
| 4 | `values.yaml` (Helm) | hostnames, ports, credentials |
| 5 | Log file (CloudWatch export) | IPs, timestamps, usernames |
| 6 | DOCX spec klienta | imiona, emaile, nazwy systemów |
| 7 | PDF architektura | diagramy tekstowe, hostnames, IP |
| 8 | `secrets.env` | API keys, passwords, tokens |
| 9 | `.github/workflows/*.yml` | GitHub tokens, ECR URIs, env vars |
| 10 | Notatka ze spotkania `.md` | imiona, emaile, JIRA tickets |
