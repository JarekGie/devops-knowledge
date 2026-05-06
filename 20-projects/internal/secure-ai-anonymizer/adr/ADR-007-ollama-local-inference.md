---
title: "ADR-007: Ollama / local inference dla sanity-check"
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

# ADR-007 — Ollama / Local Inference dla sanity-check

**Status:** Accepted  
**Data:** 2026-05-07

---

## Kontekst

System potrzebuje lokalnego modelu AI do jednego zadania: sanity-check po tokenizacji (czy sanitized document nadal zawiera coś wrażliwego?). Opcje:

1. **Ollama** — lokalny inference server, obsługuje wiele modeli (llama3.2, mistral, gemma2)
2. **Hugging Face Transformers** — bezpośrednia biblioteka Python
3. **OpenAI API (lub Claude)** — cloud API dla tego kroku
4. **Pominięcie lokalnego modelu** — tylko regex heuristics

---

## Decyzja

**Wybrany: Ollama jako lokalny inference server**

Model: do ustalenia w PoC (kandydaci: `llama3.2:3b`, `mistral:7b`, `gemma2:2b`)

Zakres użycia: **tylko sanity-check** (pre-send validation), NIE w core detection path.

---

## Uzasadnienie

**Dlaczego lokalny model, nie cloud API?**

Sanity-check jest ostatnim krokiem przed wysyłką sanitized document do zewnętrznego LLM. Jeśli sanity-check sam wysyłałby dane do cloud API — mielibyśmy wyciek jeszcze przed "oficjalną" wysyłką. Sprzeczność z [[ADR-004-external-llm-after-tokenization]] i [[LLM_EXPORT_POLICY]].

**Dlaczego Ollama, nie Hugging Face Transformers bezpośrednio?**

- Ollama jest łatwiejszy w instalacji (Docker image, CLI)
- Model management: `ollama pull llama3.2` vs pobieranie + konfiguracja HF
- REST API: prosta integracja z FastAPI przez `POST /api/generate`
- Model hot-swapping: zmiana modelu bez restartu aplikacji
- Memory management: Ollama zarządza załadowaniem/wyładowaniem modelu

Hugging Face Transformers są bardziej elastyczne, ale wymagają więcej setup. Ollama jest pragmatyczniejszy dla MVP.

**Dlaczego nie pominąć lokalnego modelu?**

Regex heuristics mogą pokryć znane wzorce, ale nie wykryją:
- Imion i nazwisk bez kontekstu
- Nazw firm ukrytych w tekście
- Semantycznych danych wrażliwych (np. "klient z branży automotive z Monachium" → bez regex, LLM to rozumie)

Lokalny model dodaje warstwę NLP sanity-check której regex nie zastąpi.

---

## Rola lokalnego modelu w architekturze

```
Sanitized document (po tokenizacji)
          │
          ▼
Ollama sanity-check prompt:
  "Poniższy tekst zawiera tokeny w formacie [KLASA_N].
   Czy w tekście nadal widoczne są jakiekolwiek:
   - imiona i nazwiska ludzi?
   - adresy IP lub CIDR bloki?
   - klucze API, hasła, sekrety?
   - nazwy firm lub organizacji?
   Odpowiedz: TAK / NIE + lista podejrzanych fragmentów."
          │
          ▼
Jeśli NIE → continue (dokument do review przez operatora)
Jeśli TAK → flag + zatrzymaj + wymagaj manual review
```

Lokalny model jest **pomocniczym filtrem**, nie gatekeeper'em. False positive = operator musi przejrzeć. False negative = wartość wrażliwa może wyjść do LLM (dlatego manual review jest obowiązkowy niezależnie od Ollama).

---

## Model selection — do ustalenia w PoC

| Model | Size | Memory | Jakość NER | Szybkość |
|-------|------|--------|-----------|---------|
| `llama3.2:3b` | ~2 GB | ~4 GB RAM | Dobra | Szybka |
| `mistral:7b` | ~4 GB | ~6 GB RAM | Bardzo dobra | Średnia |
| `gemma2:2b` | ~1.5 GB | ~3 GB RAM | Dobra | Szybka |

Decyzja w PoC: uruchom benchmark na 10 dokumentach, zmierz false negative rate dla każdego modelu.

---

## Konsekwencje

- Ollama jako Docker service w Docker Compose
- Model musi być pobrany lokalnie przy pierwszym uruchomieniu (`ollama pull <model>`)
- Lokalny model nie zastępuje manual review — jest pre-filtrem
- Prompt dla sanity-check musi być wersjonowany (zmiana promptu może zmienić zachowanie)
- Latencja: 1–5 sek dla dokumentu kilku stron (akceptowalne)
- Ollama wymaga GPU lub ~6 GB RAM dla 7b model (konfigurowalny w Docker Compose)
