---
title: secure-ai-anonymizer — glossary
domain: private-rnd
origin: own
classification: restricted
llm_exposure: restricted
cross_domain_export: prohibited
source_of_truth: vault
created: 2026-05-07
updated: 2026-05-07
---

# Glossary — secure-ai-anonymizer

> Słownik pojęć używanych w projekcie. Unikaj ambiwalencji terminologicznej.

---

**Anonymization** — proces usunięcia lub zastąpienia danych identyfikujących tak, że odwrócenie nie jest możliwe bez dodatkowej informacji. W tym systemie: **tokenizacja**, nie nieodwracalna anonymizacja (reversible przez rehydration).

**Audit trail** — append-only log każdej operacji na dokumencie: kto, kiedy, jaki dokument, jakie operacje. Nie może być edytowany ani usuwany.

**Confidence score** — poziom pewności recognizera co do wykrytej wartości wrażliwej. Zakres 0.0–1.0. Poniżej progu → manual review.

**Custom recognizer** — recognizer napisany dla specyficznej klasy danych (AWS ARN, CIDR, connection string) uzupełniający standardowe recognizery Presidio.

**Data class** — kategoria danych wrażliwych (PII, Infra, Secrets, Business, Metadata). Określa: obowiązkowość tokenizacji, ryzyko wycieku, dozwolone narzędzia LLM.

**Derived insight** — wniosek wyabstrahowany i zanonimizowany z danych klientowskich, który może bezpiecznie przejść do innej domeny. → [[DERIVATIVE_INSIGHT_RULES]]

**Detection layer** — warstwa wykrywająca wrażliwe wartości w sparsowanym dokumencie. Presidio + spaCy + custom recognizers.

**Document ID** — UUID identyfikujący dokument w systemie. Per-dokument, globalnie unikalny.

**Envelope encryption** — model szyfrowania: dane zaszyfrowane kluczem DEK (Data Encryption Key), DEK zaszyfrowany kluczem KEK (Key Encryption Key). W MVP: pgcrypto. W Fazie 2: HashiCorp Vault jako KEK store.

**False negative** — nieowykryta wartość wrażliwa (recognizer ją pominął). Najniebezpieczniejszy błąd — wartość wychodzi do LLM.

**False positive** — błędna detekcja (recognizer oznaczy jako wrażliwe coś, co wrażliwe nie jest). Niegroźny dla bezpieczeństwa, ale irytujący dla operatora.

**Manual review** — krok w którym operator weryfikuje token map przed rehydratacją. Wymagany w MVP.

**Original document** — dokument wejściowy przed tokenizacją. Pozostaje lokalnie. NIGDY nie opuszcza systemu.

**Parsing layer** — warstwa ekstrakcji tekstu z formatu binarnego (PDF, DOCX) lub strukturyzacja tekstu (YAML, Terraform). Tika + Unstructured + pdfplumber.

**Presidio** — biblioteka Microsoft do wykrywania i anonymizowania PII. Obsługuje NLP (spaCy), regex, custom recognizers.

**Prompt injection** — atak: złośliwe instrukcje wbudowane w dokument wejściowy, które wpływają na zachowanie LLM gdy dokument jest mu przekazany.

**Recognizer** — komponent wykrywający konkretną klasę danych wrażliwych. Może być regex-based, NLP-based, lub context-based.

**Recognizer pack** — zestaw recognizerów dla określonego kontekstu (np. "infra" = AWS ARN + IP + CIDR, "pii" = imiona + emaile + PESEL).

**Rehydration** — odwrócenie tokenizacji w odpowiedzi LLM: zastąpienie tokenów `[KLASA_N]` oryginalnymi wartościami. Wymaga autoryzacji i tworzy audit trail.

**Sanitized document** — dokument po tokenizacji. Tokeny w miejscu wartości wrażliwych. Gotowy do eksportu do zewnętrznego LLM.

**Semantic tag** — format tokenu `[KLASA_N]`. Czytelny dla LLM, zachowuje kontekst semantyczny, nie ukrywa że coś zostało zastąpione.

**Sensitive data** — dane wrażliwe: PII, infra credentials, sekrety, dane organizacyjne. Patrz [[data-classification]].

**spaCy** — biblioteka NLP do Named Entity Recognition (NER). Używana przez Presidio i bezpośrednio do detekcji named entities.

**Token** — placeholder zastępujący wartość wrażliwą w sanitized document. Format: `[KLASA_N]`.

**Token map** — zaszyfrowane mapowanie token → oryginalna wartość. Per-dokument, przechowywane w PostgreSQL.

**Tokenization** — zastąpienie wartości wrażliwej tokenem placeholder + zapis do token map.

**Vault (HashiCorp)** — narzędzie do zarządzania sekretami i kluczami. W tym projekcie: Faza 2 jako Key Encryption Key store.

**Zero-trust review** — polityka: nie ufaj że dokument jest poprawnie zanonimizowany bez weryfikacji. Ollama sanity-check + manual review przed każdą wysyłką do LLM.
