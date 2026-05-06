---
title: "ADR-002: Tokenization Over Masking"
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

# ADR-002 — Tokenization Over Masking

**Status:** Accepted  
**Data:** 2026-05-07

---

## Kontekst

System musi zastąpić wrażliwe wartości w dokumencie przed wysyłką do LLM. Dostępne techniki:
1. **Masking** — zastąpienie wartości symbolem (np. `***`, `REDACTED`, `████`)
2. **Tokenization** — zastąpienie wartości unikalnym tokenem z przechowaniem mappingu
3. **Pseudonymization** — zastąpienie wartości inną (fałszywą) wartością tej samej klasy (np. imię → inne imię)

---

## Decyzja

**Wybrany: Tokenization z semantic tags** (opcja 2)

Format tokenów: `[KLASA_N]` (np. `[AWS_ACCOUNT_1]`, `[IP_ADDRESS_3]`)

---

## Uzasadnienie

**Dlaczego nie masking (`***`)?**

Masking jest nieodwracalny — wynik LLM nie może być przywrócony do oryginalnego kontekstu. LLM widzi `***` i nie może przeprowadzić analizy ani dać użytecznej odpowiedzi na podstawie `account_id = ***`. Tracisz semantyczność dokumentu.

Masking usuwa zbyt wiele informacji: LLM nie wie ile wartości zostało zastąpionych, nie wie czy `***` na pozycji 3 i na pozycji 7 to ta sama wartość.

**Dlaczego nie pseudonymization?**

Pseudonymizacja generuje fałszywe wartości (np. `192.168.0.1` → `10.5.3.2`, `Jan Kowalski` → `Adam Wiśniewski`). Problemy:
- LLM może traktować fałszywe IP jako rzeczywiste i dawać niepoprawne porady sieciowe
- Fałszywe nazwiska mogą "pasować" do innych danych i zaciemnić analizę
- Trudno zarządzać spójnością pseudonimów w długich dokumentach
- Musi być deterministyczna (ta sama wartość → ten sam pseudonim), inaczej traci się spójność

**Dlaczego tokenization z semantic tags?**

1. **Rehydration** — możliwe precyzyjne odwrócenie: `[IP_ADDRESS_1]` → `10.0.1.45`
2. **LLM rozumie klasę** — `[AWS_ACCOUNT_1]` mówi LLM "tu był AWS account ID", nie anonimowy placeholder
3. **Spójność intra-document** — ta sama wartość → ten sam token → LLM widzi że `[IP_ADDRESS_1]` w linii 5 i linii 45 to to samo IP
4. **Deterministyczność** — ten sam dokument → ta sama tokenizacja (przy tym samym confidence threshold)
5. **Audytowalność** — token map jest kompletnym ślad co zostało zastąpione

**Dlaczego `[KLASA_N]` a nie UUID?**

UUID (`[a3f7-c9e2...]`) jest bardziej anonimizujący, ale LLM traci kontekst klasy. Semantic tag `[AWS_ACCOUNT_1]` pozwala LLM rozumować "to był AWS account", co daje lepszą jakość odpowiedzi.

---

## Trade-offs

| Cecha | Masking | Tokenization | Pseudonymization |
|-------|---------|-------------|-----------------|
| Rehydration | Nie | Tak | Tak |
| Semantyczność dla LLM | Niska | Wysoka | Średnia (ryzyko halucynacji) |
| Złożoność implementacji | Niska | Średnia | Wysoka |
| Ryzyko rekonstrukcji | Brak | Niskie (klucz lokalny) | Niskie |
| Spójność intra-document | N/A | Tak | Tylko z determ. mapping |

---

## Konsekwencje

**Pozytywne:**
- LLM odpowiedzi są użyteczne i powiązane z kontekstem dokumentu
- Rehydratacja odtwarza oryginalny kontekst w odpowiedzi LLM
- Token format jest samodokumentujący

**Negatywne:**
- Token map musi być przechowywany bezpiecznie (ryzyko: T2 w [[threat-model]])
- Dodatkowa złożoność storage i szyfrowania
- Semantic tags mogą w teorii pozwolić na "odgadnięcie" klasy danych (ale nie wartości)
