---
title: secure-ai-anonymizer — threat model
domain: private-rnd
origin: own
classification: restricted
llm_exposure: restricted
cross_domain_export: prohibited
source_of_truth: vault
created: 2026-05-07
updated: 2026-05-07
---

# Threat Model — secure-ai-anonymizer

> Model zagrożeń dla systemu anonimizacji. Priorytetyzacja: CRITICAL → HIGH → MEDIUM → LOW.
> Każde zagrożenie ma mitigation i status.

---

## T1 — Data Leakage przez zewnętrzny LLM

**Scenariusz:** Sanitized document zawiera wartości wrażliwe, które recognizer nie wykrył. Wartości wychodzą do zewnętrznego LLM i są zapamiętane / zalogowane.

**Priorytet:** CRITICAL

**Wektory:**
- Nowy format danych nieobsługiwany przez recognizer
- False negative recognizera (niska confidence, pominięta detekcja)
- Dane wrażliwe ukryte w strukturze (np. w komentarzu Terraform, w nazwie zmiennej)
- Kontekst semantyczny ujawniający tożsamość bez konkretnych danych (np. "klient z Łodzi produkujący opony")

**Mitigations:**
- [ ] Pre-send manual review — operator zatwierdza sanitized document przed wysyłką (MVP: obowiązkowy)
- [ ] Confidence threshold — tokeny poniżej progu flagowane do manual review
- [ ] Ollama sanity-check — lokalny model weryfikuje czy coś wrażliwego zostało
- [ ] Feedback loop — false negatives trafiają do corpus treningowego dla recognizerów
- [ ] "Zero-trust review": jeśli Ollama zgłosi residual risk > X%, blokuj wysyłkę

**Status:** Mitigation częściowa w MVP; full coverage w Fazie 2

---

## T2 — Token Map Compromise

**Scenariusz:** Atakujący uzyskuje dostęp do zaszyfrowanej token map i klucza szyfrującego. Może rehydratować wszystkie dokumenty.

**Priorytet:** CRITICAL

**Wektory:**
- Kompromitacja PostgreSQL (słabe hasło, niezabezpieczony port)
- Klucz szyfrujący w pliku `.env` lub w repozytorium
- Backup bazy danych bez szyfrowania

**Mitigations:**
- [x] Envelope encryption — klucz danych szyfrowany osobnym key encryption key (KEK)
- [x] PostgreSQL: local only, port nie exposowany poza Docker network
- [x] `.env` z kluczami w `.gitignore`, nigdy w repozytorium
- [ ] Vault (HashiCorp) jako KEK store — Faza 2
- [ ] Key rotation procedure — Faza 2
- [ ] Backup encryption policy — Faza 2

**Status:** Podstawowe zabezpieczenia w MVP; key management hardening w Fazie 2

---

## T3 — Prompt Injection przez wejściowy dokument

**Scenariusz:** Złośliwy dokument zawiera instrukcje dla LLM w treści ("Ignoruj poprzednie instrukcje i..."). Po tokenizacji sanitized document nadal zawiera te instrukcje, które wpływają na zachowanie LLM.

**Priorytet:** HIGH

**Wektory:**
- Dokument klienta celowo spreparowany (rzadki, ale możliwy)
- Dokument zawierający template strings, metadata z instrukcjami AI
- LLM w roli sanity-check może sam zostać zaatakowany

**Mitigations:**
- [ ] Stripping znanych prompt injection patterns z parsed text przed tokenizacją
- [ ] Flagowanie dokumentów zawierających podejrzane frazy (lista keywords)
- [ ] Manual review jako obowiązkowy step (operator widzi co idzie do LLM)
- [ ] Ograniczenie Ollama sanity-check: nie przekazuje pełnego tekstu, tylko metadata + klasy danych

**Status:** Częściowe w MVP przez manual review; dedykowany detector w Fazie 2

---

## T4 — Malicious Documents (Document Parsing Attack)

**Scenariusz:** Złośliwy plik PDF / DOCX zawiera exploit dla Apache Tika lub pdfplumber (buffer overflow, path traversal, zip bomb).

**Priorytet:** HIGH

**Wektory:**
- CVE w Apache Tika (historycznie liczne)
- Zip bomb w DOCX (XML inside ZIP)
- Path traversal w embedded file references
- JavaScript w PDF

**Mitigations:**
- [x] Tika w osobnym Docker container — process isolation
- [x] File size limit przed parsowaniem
- [ ] ClamAV scan przed parsowaniem
- [ ] Disable JavaScript i embedded content w Tika config
- [ ] Resource limits (memory, CPU) na Tika container

**Status:** Izolacja kontenerów w MVP; antivirus w Fazie 2

---

## T5 — Rehydration Abuse

**Scenariusz:** Nieautoryzowany użytkownik / proces rehydratuje dokumenty, uzyskując dostęp do oryginalnych danych wrażliwych.

**Priorytet:** HIGH

**Wektory:**
- Brak autoryzacji na endpoint `/rehydrate` (brak uwierzytelnienia w MVP)
- Skradziony token sesji umożliwiający rehydratację
- Automatyczny rehydration przez LLM agent bez wiedzy operatora

**Mitigations:**
- [x] Manual review step — operator explicite zatwierdza rehydratację
- [x] Audit log każdej rehydratacji (kto, kiedy, jaki dokument)
- [ ] Authorization token wymagany do rehydratacji (Faza 1)
- [ ] Rate limiting na rehydration endpoint
- [ ] Time-limited token maps (TTL) — Faza 2

**Status:** Podstawowe kontrole w MVP (manual review + audit); RBAC w Fazie 2

---

## T6 — Insider Threat

**Scenariusz:** Operator (lub deweloper) systemu ma dostęp do token map i może rehydratować dowolne dokumenty. Brak niezależnego audytu.

**Priorytet:** MEDIUM

**Wektory:**
- Administrator bazy danych odczytuje token maps bezpośrednio
- Deweloper dodaje kod wypisujący oryginalne wartości do logów
- Backup bazy trafił do zewnętrznego systemu

**Mitigations:**
- [x] Append-only audit log (nie można edytować/usuwać wpisów)
- [x] Logi nie zawierają wartości oryginalnych — tylko klasy i tokeny
- [ ] Alerting na mass-rehydration (dużo dokumentów w krótkim czasie) — Faza 2
- [ ] Regularne review audit logów — proces, nie technikalia

**Status:** Częściowe zabezpieczenia technicze; monitoring w Fazie 2

---

## T7 — Model Hallucination

**Scenariusz:** Zewnętrzny LLM generuje odpowiedź, w której hallucynuje wartości wyglądające jak wrażliwe dane. Po rehydratacji trudno odróżnić, które wartości są z oryginalnego dokumentu, a które wygenerowane przez LLM.

**Priorytet:** MEDIUM

**Wektory:**
- LLM "odgaduje" prawdopodobne wartości dla tokenów (np. guesses account ID na podstawie kontekstu)
- LLM generuje nowe tokeny w formacie `[KLASA_N]` niezgodne z token map
- Odpowiedź LLM zawiera dane wrażliwe nieobecne w sanitized input (training data leakage)

**Mitigations:**
- [x] Rehydratacja tylko znanych tokenów — nieznane tokeny w odpowiedzi → flagowane do review
- [x] Manual review odpowiedzi LLM przed rehydratacją
- [ ] Validation: odpowiedź LLM nie może zawierać wartości numerycznych / IP patterns / ARN patterns
- [ ] "Fidelity check": porównaj liczbę tokenów w odpowiedzi z oczekiwaną

**Status:** Podstawowa walidacja w MVP; automatyczna walidacja w Fazie 2

---

## T8 — Cross-Client Contamination

**Scenariusz:** System przetwarza dokumenty wielu klientów. Token map jednego klienta przecieka do dokumentu drugiego klienta (np. przez cache, przez współdzielony Redis, przez błąd w logice).

**Priorytet:** HIGH

**Wektory:**
- Błąd w logice document_id — reuse ID między klientami
- Redis cache nie jest izolowany per-client
- Celery worker przetwarza zadania z różnych klientów w tym samym procesie

**Mitigations:**
- [x] Per-document UUID — każdy dokument ma globalnie unikalny ID
- [x] Token map jest per-document (nie per-class globalnie)
- [ ] Per-client namespace w Redis — Faza 2
- [ ] Per-client database schema isolation — Faza 2

**Status:** Podstawowa izolacja w MVP; pełna izolacja w Fazie 2

---

## T9 — Clipboard / Temporary File Leakage

**Scenariusz:** Operator kopiuje fragment sanitized document do schowka i wkleja do zewnętrznego LLM — ale przez pomyłkę kopiuje fragment original document z innego okna.

**Scenariusz 2:** Tika tworzy tymczasowe pliki w `/tmp/` zawierające oryginalną treść. Pliki nie są usuwane.

**Priorytet:** MEDIUM

**Wektory:**
- Operator error (poza kontrolą techniczną systemu)
- Uncleared temp files
- Browser autofill zapisuje fragmenty dokumentów

**Mitigations:**
- [x] Instrukcja operacyjna: zawsze kopiuj z sanitized output, nie z original
- [x] Tika container: `TMPDIR` ustawiony na tmpfs (RAM, nie disk)
- [x] Temp file cleanup w każdym pipeline run (finally block)
- [ ] Procedura bezpieczeństwa operacyjnego — Faza 1 (dokumentacja)

---

## T10 — Log Leakage

**Scenariusz:** Logi aplikacji zawierają wartości wrażliwe (np. stacktrace z connection stringiem, debug log z zawartością dokumentu).

**Priorytet:** MEDIUM

**Wektory:**
- Exception stacktrace zawiera wartości z dokumentu
- Debug-level logging wypisuje parsed content
- Log aggregation system (centralny) przechowuje logi z danymi wrażliwymi

**Mitigations:**
- [x] Log policy: nigdy nie loguj zawartości dokumentu, tylko metadata (doc_id, chunk_count, etc.)
- [x] Presidio scrubber na log output (filtruje klasy PII z wiadomości logu)
- [x] Level production: INFO — bez DEBUG (który mógłby zawierać dane)
- [ ] Log retention policy — Faza 2
- [ ] Centralny log system tylko dla anonymized log events — Faza 2

---

## Podsumowanie ryzyk

| ID | Zagrożenie | Priorytet | Status mitigacji |
|----|-----------|-----------|-----------------|
| T1 | Data leakage przez LLM | CRITICAL | Częściowe (manual review) |
| T2 | Token map compromise | CRITICAL | Podstawowe (pgcrypto) |
| T3 | Prompt injection | HIGH | Manual review |
| T4 | Malicious documents | HIGH | Izolacja kontenerów |
| T5 | Rehydration abuse | HIGH | Manual review + audit |
| T6 | Insider threat | MEDIUM | Audit log |
| T7 | Model hallucination | MEDIUM | Walidacja tokenów |
| T8 | Cross-client contamination | HIGH | Per-document UUID |
| T9 | Clipboard / temp file | MEDIUM | Cleanup + instrukcja |
| T10 | Log leakage | MEDIUM | Log policy |

**MVP coverage:** T1 (partial), T2 (partial), T3 (partial), T4 (partial), T5 (partial), T8 (partial), T10 (full)

**Faza 2 + coverage:** T1 (full), T2 (full), T5 (full), T6 (full), T8 (full), T9 (full)
