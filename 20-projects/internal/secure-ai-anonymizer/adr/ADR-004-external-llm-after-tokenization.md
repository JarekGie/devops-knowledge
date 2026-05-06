---
title: "ADR-004: External LLM tylko po tokenizacji"
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

# ADR-004 — External LLM tylko po tokenizacji

**Status:** Accepted  
**Data:** 2026-05-07

---

## Kontekst

System może używać modeli AI w dwóch miejscach:
1. **Pre-processing** — przed tokenizacją (np. do klasyfikacji dokumentu, detekcji wrażliwości)
2. **Post-processing** — po tokenizacji (zewnętrzny LLM pracuje na sanitized document)

Pytanie: czy zewnętrzny LLM (ChatGPT, Claude) może mieć dostęp do dokumentu przed tokenizacją?

---

## Decyzja

**Zewnętrzny LLM NIGDY nie otrzymuje dokumentu przed tokenizacją.**

Dozwolone użycie zewnętrznego LLM:
- Tylko sanitized document (po pełnym pipeline tokenizacji)
- Tylko na explicit żądanie operatora (nie automatycznie)
- Tylko z manual review sanitized document przez operatora przed wysyłką

Lokalny LLM (Ollama) może być użyty w pre-processing (sanity-check), ale ma ograniczony dostęp do treści (tylko metadata + klasy danych, nie pełny tekst).

---

## Uzasadnienie

**1. Compliance z LLM_EXPORT_POLICY**

[[LLM_EXPORT_POLICY]] zabrania eksportu danych `restricted` i `confidential` bez tokenizacji do zewnętrznych LLM. Tokenizcja jest technicznym egzekutorem tej polityki — nie możemy pozwolić na shortcut.

**2. Ryzyko prompt injection**

Gdyby zewnętrzny LLM był używany do klasyfikacji dokumentu (przed tokenizacją), otrzymywałby pełny tekst z potencjalnie złośliwymi instrukcjami. Prompt injection byłby możliwy w critical pre-processing path.

**3. Brak potrzeby — lokalne modele wystarczą do pre-processing**

Klasyfikacja "czy dokument zawiera dane wrażliwe?" nie wymaga Claude / GPT-4. llama3.2 lub mistral-7b jest wystarczający do binarnej klasyfikacji / sanity-check. Używanie zewnętrznego LLM do tego byłoby naruszeniem zasady minimum necessary.

**4. Architektoniczna czystość**

Zewnętrzny LLM to consumer outputu systemu (sanitized document), nie komponent systemu. Mieszanie ról (component vs consumer) komplikuje architekturę i zarządzanie zaufaniem.

---

## Implikacje operacyjne

System NIE wysyła automatycznie do zewnętrznego LLM. Workflow:

```
System → sanitized_document.md (local file)
Operator → review → kopiuje do ChatGPT/Claude manualnie
LLM → odpowiedź
Operator → wkleja odpowiedź do systemu → rehydratacja
```

System jest "tool" dla operatora, nie agentem który sam wysyła dane.

---

## Wyjątki

Żadne wyjątki w MVP. Faza 2 może rozważyć:
- Lokalny LLM (Ollama) w pre-processing path — ale z ograniczonymi danymi wejściowymi
- Integracja CI/CD (automatyczne sanitize outputu cloud-detective) — ale bez automatycznej wysyłki do LLM

**Cross-domain export pozostaje zawsze manual.**
