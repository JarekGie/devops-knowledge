---
title: secure-ai-anonymizer — roadmap
domain: private-rnd
origin: own
classification: restricted
llm_exposure: restricted
cross_domain_export: prohibited
source_of_truth: vault
created: 2026-05-07
updated: 2026-05-07
---

# Roadmap — secure-ai-anonymizer

> Fazy projektowe od PoC do Enterprise. Każda faza ma jasne exit criteria.
> Nie eskaluj do następnej fazy bez zamknięcia current.

---

## Faza 0 — PoC (aktywna)

**Cel:** udowodnić że lokalny pipeline tokenizacji działa na realnych dokumentach cloud/infra.

**Czas:** 2–4 tygodnie (poza godzinami pracy, iteracyjnie)

**Deliverables:**
- [ ] CLI script: `anonymize.py --input file.md --output sanitized.md --map tokens.json`
- [ ] Presidio + spaCy: podstawowa detekcja PII + custom recognizer dla AWS ARNs / IPs
- [ ] Token format: decyzja i implementacja (→ ADR-002)
- [ ] Roundtrip test: dokument → tokenizacja → LLM → rehydratacja → porównanie
- [ ] 5 realnych dokumentów z cloud-detective jako test cases (zanonimizowane)

**Exit criteria:**
- Roundtrip działa deterministycznie na 5 dokumentach
- False positive rate recognizerów < 15% na test cases
- Czas tokenizacji: < 5 sek na dokument < 50 stron

---

## Faza 1 — MVP

**Cel:** działający lokalny service, audytowalny, z manual review.

**Czas:** 4–8 tygodni od startu

**Stack:**
- FastAPI (REST API)
- PostgreSQL (token mapping, audit log)
- Redis (session cache)
- Celery (async processing)
- Apache Tika + Unstructured (parsing)
- Presidio + spaCy (detection)
- Ollama + lokalny model (sanity-check klasyfikacji)

**Deliverables:**
- [ ] REST API: `POST /documents/anonymize`, `POST /documents/rehydrate`, `GET /audit/{doc_id}`
- [ ] Envelope encryption dla token map (PostgreSQL + pgcrypto)
- [ ] Recognizer pack v1: PII, AWS infra, secrets (regex + Presidio)
- [ ] Manual review UI (prostą tabelę przez FastAPI /docs)
- [ ] Audit log: każda operacja, kto, kiedy, jaki dokument, które tokeny
- [ ] Docker Compose dla local dev
- [ ] 10+ test cases z dokumentami cloud/infra

**Exit criteria:**
- System działa offline (brak zewnętrznych zależności runtime)
- Audit log jest kompletny i nieedytowalny
- Rehydratacja wymaga explicite authorization (nie auto)
- Testy jednostkowe recognizerów: coverage > 80%

---

## Faza 2 — Internal Alpha

**Cel:** użycie przez kilka osób w cloud practice z realnymi dokumentami klientów (zanonimizowanymi przed testem).

**Czas:** 2–3 miesiące po MVP

**Dodaje:**
- HashiCorp Vault dla key management (zamiast pgcrypto envelope)
- Access control: kto może rehydratować, per-project isolation
- OpenSearch: wyszukiwanie w sanitized documents
- Integracja z cloud-detective: automatyczne sanitize output scanu
- Feedback loop: manual correction recognizerów
- Logging centralne (ELK lub CloudWatch jeśli deployed on AWS)

**Exit criteria:**
- 3+ osób w cloud practice używa systemu regularnie
- Zero incydentów wycieku danych
- False positive < 5%, false negative < 2% na znanych klasach danych

---

## Faza 3 — Controlled Production

**Cel:** formalne wdrożenie w MakoLab dla cloud practice, z procesem onboardingu projektów.

**Czas:** TBD — po Internal Alpha

**Dodaje:**
- Formalny process onboardingu projektu (klient, zakres, data retention)
- Data retention policy + automatyczne czyszczenie token map po X dniach
- Audit export (PDF/CSV) dla compliance
- Qdrant jako opcjonalny vector store dla semantic search
- Integracja z NotebookLM workflow (sanitized source packs)

---

## Faza 4 — Enterprise Hardening

**Cel:** produkcja dla większej liczby zespołów lub klientów zewnętrznych.

**Czas:** TBD — po stabilizacji Fazy 3

**Obejmuje:**
- Multi-tenant isolation
- SSO (Keycloak lub Azure AD)
- Compliance reporting (GDPR, ISO 27001)
- Rate limiting + quota management
- SLA monitoring

> **Uwaga:** Fazy 3 i 4 to planing horizon — nie design now. Decyzje architektoniczne MVP nie mogą tworzyć long-term lockin jeśli nie są konieczne.

---

## Priorytety MVP — co MA być, czego NIE

### MA BYĆ w MVP

- Deterministyczny pipeline (ten sam input → ten sam output)
- Audit trail kompletny i append-only
- Manual review jako domyślny krok przed rehydratacją
- Offline-first (zero cloud dependencies runtime)
- Recognizery dla klas danych faktycznie obserwowanych w pracy (infra, PII, sekrety)

### NIE MA BYĆ w MVP

- UI (FastAPI /docs wystarczy)
- Automatyczne wysyłanie do LLM (to jest poza scope systemu)
- Multi-user / RBAC (pojedynczy operator)
- Batch processing ponad 100 dokumentów
- OCR (nie robimy skanów zdjęć w MVP)
