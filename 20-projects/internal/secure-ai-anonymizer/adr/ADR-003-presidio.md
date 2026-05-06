---
title: "ADR-003: Microsoft Presidio jako silnik detekcji"
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

# ADR-003 — Microsoft Presidio jako silnik detekcji

**Status:** Accepted  
**Data:** 2026-05-07

---

## Kontekst

System potrzebuje silnika do wykrywania wrażliwych danych w tekście. Opcje:
1. **Microsoft Presidio** — open source, Python, extensible, NLP + regex
2. **Custom regex-only** — własny zestaw wyrażeń regularnych
3. **spaCy standalone** — NER bez warstwy recognizerów
4. **Cloud API** (AWS Comprehend, GCP DLP, Azure Text Analytics) — managed service

---

## Decyzja

**Wybrany: Microsoft Presidio + spaCy NLP + custom recognizers** (opcja 1 + rozszerzenie)

---

## Uzasadnienie

**Dlaczego Presidio?**

1. **Extensibility** — Presidio ma formalny model `EntityRecognizer` do dodawania custom recognizerów. Własne klasy (AWS ARN, CIDR, connection string) można dodać jako `PatternRecognizer` (regex) lub `RemoteRecognizer` (NLP-based).

2. **PII coverage out-of-the-box** — Presidio obsługuje standardowe klasy PII (PERSON, EMAIL_ADDRESS, PHONE_NUMBER, LOCATION, IBAN, IP_ADDRESS) z NLP-based recognizerami przez spaCy.

3. **Confidence scores** — każda detekcja ma confidence score. Pozwala na threshold-based filtering (auto-tokenize vs manual review).

4. **Python-native** — stack projektu jest Python. Zero overhead integracyjny.

5. **Offline** — spaCy models są pobierane lokalnie. Presidio nie wymaga cloud connectivity.

6. **Anonymizer built-in** — Presidio ma wbudowany `PresidioAnonymizer` który może maskować, zastępować, lub tokenizować. Używamy go jako silnik podstawienia.

**Dlaczego nie custom regex-only?**

Regex nie pokrywa NER (Named Entity Recognition). Wykrycie imion i nazwisk, nazw firm, lokalizacji bez kontekstu jest niemożliwe przez regex. Presidio + spaCy daje NLP coverage.

**Dlaczego nie cloud API (AWS Comprehend, GCP DLP)?**

- Narusza [[ADR-001-local-first]] — dane muszą być wysyłane do cloud API
- Koszt per-request
- Latencja
- Dependency na external service (offline operability)

GCP DLP i Azure Text Analytics są potencjalnie silniejsze, ale wymagają cloud — wykluczone w MVP.

**Dlaczego nie spaCy standalone?**

spaCy NER jest podstawą Presidio, ale Presidio dodaje:
- structured recognizer framework (łatwe dodawanie custom recognizerów)
- confidence scores
- operator (anonymizer) oddzielony od analyzera
- batch processing

---

## Konfiguracja i custom recognizers

Presidio jest konfigurowany z:
- Standard recognizers: `PERSON`, `EMAIL_ADDRESS`, `PHONE_NUMBER`, `IP_ADDRESS`, `IBAN_CODE`
- spaCy model: `en_core_web_lg` (duży model, lepsza precyzja)
- Custom recognizers: patrz [[tokenization-model]] (AWS, infra, secrets, networking)

---

## Trade-offs

| Cecha | Presidio | Custom regex | Cloud API |
|-------|---------|-------------|----------|
| NLP/NER coverage | Tak | Nie | Tak |
| Offline | Tak | Tak | Nie |
| Extensibility | Wysoka | Ograniczona | Zależy od API |
| Confidence scores | Tak | Nie | Tak |
| Custom classes | Tak (PatternRecognizer) | Tak | Zależy |
| Time-to-first-detector | Średni | Szybki | Szybki |

---

## Konsekwencje

- spaCy model `en_core_web_lg` (~600 MB) musi być pobrany lokalnie lub dołączony do Docker image
- Presidio ma latencję: typowo 100–500 ms na dokument kilku stron (akceptowalne)
- Custom recognizers muszą mieć testy jednostkowe (precision/recall na test corpus)
- False positive / false negative baseline: mierzone w PoC na 10 test documents
