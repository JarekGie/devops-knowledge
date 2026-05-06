---
title: "ADR-005: Deterministyczny pipeline"
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

# ADR-005 — Deterministyczny pipeline

**Status:** Accepted  
**Data:** 2026-05-07

---

## Kontekst

Pipeline przetwarzania dokumentów może być:
1. **Deterministyczny** — ten sam input → ten sam output zawsze
2. **Probabilistyczny** — output może się różnić między rundami (np. jeśli NLP model ma losowość, jeśli kolejność detekcji wpływa na output)

---

## Decyzja

**Pipeline MUSI być deterministyczny.**

Ten sam dokument wejściowy, te same parametry konfiguracyjne → ta sama token map, ten sam sanitized document.

---

## Uzasadnienie

**1. Audytowalność**

Audyt ma sens tylko jeśli można odtworzyć wyniki. Jeśli dwa uruchomienia tego samego dokumentu dają różne token mapy, operator nie może zweryfikować że document był prawidłowo tokenizowany.

**2. Debugging false negatives**

Gdy false negative jest wykryty (wartość wrażliwa wyszła do LLM), musimy wiedzieć które uruchomienie wygenerowało sanitized document. Deterministyczność pozwala odtworzyć dokładny stan tokenizacji.

**3. Regression testing**

Test corpus musi dawać powtarzalne wyniki. Jeśli pipeline jest niedeterministyczny, test "10 dokumentów z coverage > 85%" może przechodzić lub nie przechodzić losowo.

**4. Operator trust**

Operator musi ufać że manual review sanitized document który widzi to dokładnie to co zostanie wysłane do LLM — bez żadnych losowych zmian.

---

## Wymagania determinizmu

1. **Token numbering** — sekwencyjny per-klasa, w kolejności pierwszego wystąpienia w dokumencie (linia, pozycja)
2. **Detection order** — zawsze: Presidio → spaCy → custom recognizers; konflikty rozwiązywane deterministycznie (wyższy confidence wygrywa; remis → bardziej specyficzna klasa)
3. **NLP models** — spaCy modele są statyczne (brak fine-tuningu w runtime); nie mogą być aktualizowane między sesjami bez explicit wersjonowania
4. **Parsing** — Tika i Unstructured muszą dawać spójny output dla tego samego pliku (bez race conditions, bez timestamp-based differences)
5. **Konfiguracja** — confidence threshold i recognizer pack są explict parametrami wywołania, nie global state

---

## Wyjątek: multi-run consistency

Token numbering jest deterministyczny **w ramach jednego uruchomienia**. Jeśli dokument jest przetwarzany dwa razy (np. po aktualizacji recognizerów), numery tokenów mogą się różnić.

Zasada: **jedna token map per uruchomienie**. Operator nie może mieszać tokenów z różnych uruchomień.

Rozwiązanie: `document_id` + `run_id` — każde uruchomienie ma swój run_id. Rehydratacja używa zawsze konkretnego run_id.

---

## Konsekwencje

- spaCy model musi być wersjonowany i zablokowany (`requirements.txt` z exact version)
- Tika i Unstructured muszą być testowane pod kątem stabilności outputu
- Celery task retry musi używać idempotent operations (nie może generować nowych token IDs przy retry)
- Testy regresji: snapshot testing — zapisz expected output i porównuj
