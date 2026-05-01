---
title: <krótka nazwa prompta>
domain: <client-work | internal-product-strategy | private-rnd | shared-concept>
use_case: <co ten prompt robi w 1 zdaniu>
llm_target: <claude | codex | chatgpt | any>
classification: reference
tags: [prompt, <np. aws>, <terraform>, <finops>, <incident>]
---

# 🎯 Cel

<Co dokładnie ma zrobić agent — konkretnie, bez ogólników>

---

# 📥 Kontekst wejściowy

## Aktualna sytuacja
<Opis problemu / zadania / incydentu>

## Dane wejściowe
<tu wklejasz konkret: logi, config, fragmenty kodu, output CLI>

## Ograniczenia
- brak write access / read-only
- nie wolno robić X
- zakres środowisk: <np. dev/prod>
- inne istotne ograniczenia

---

# ⚙️ Zadanie dla agenta

Wykonaj:

1. <krok 1 — np. analiza>
2. <krok 2 — np. identyfikacja przyczyny>
3. <krok 3 — np. rekomendacja działań>

Nie rób:
- <czego agent NIE ma robić>

---

# 📊 Oczekiwany format odpowiedzi

## 1. Werdykt (TL;DR)
<Krótka odpowiedź co jest problemem / decyzją>

## 2. Evidence
<Fakty z danych wejściowych — bez zgadywania>

## 3. Hipotezy (jeśli potrzeba)
<co jest możliwe, ale niepewne>

## 4. Rekomendowane działania
<konkretne kroki do wykonania>

## 5. Ryzyka
<co może pójść źle>

---

# 🧠 Zasady pracy (ważne)

- oddziel fakty od hipotez
- nie zgaduj jeśli brak danych
- nie proponuj destrukcyjnych zmian bez oznaczenia
- jeśli coś wymaga weryfikacji w AWS → zaznacz to jasno
- preferuj konkret nad teorię

---

# 🚫 Guardrails

- nie wykonuj żadnych operacji write
- nie zakładaj brakujących danych
- nie upraszczaj problemu jeśli dane są złożone

---

# 🧩 Kontekst dodatkowy (opcjonalny)

<np. architektura, wcześniejsze decyzje, linki do vault>

---

# ▶️ Prompt

<Poniżej wklejasz finalny prompt do użycia przez LLM>

---