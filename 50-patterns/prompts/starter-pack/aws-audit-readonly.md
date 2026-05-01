---
title: aws-audit-readonly
domain: client-work
use_case: read-only audit infrastruktury AWS
llm_target: any
aws_profile:
repozytorium:
---

# 🎯 Cel
Wykonać analizę infrastruktury AWS na podstawie dostarczonych danych, bez żadnych operacji write.

---

# 📥 Kontekst wejściowy
## Zakres
- konto: <account_id / profile>
- region: <region>
- środowisko: <dev/prod>

## Dane
<output z CLI / JSON / screenshots / opis zasobów>

## Ograniczenia
- read-only
- brak terraform apply / brak zmian w AWS

---

# ⚙️ Zadanie
1. Zidentyfikuj problemy i niezgodności
2. Wskaż brakujące elementy (tagi, logging, security)
3. Oceń ryzyka

---

# 📊 Format odpowiedzi
## Werdykt
## Evidence
## Problemy (priorytety)
## Rekomendacje (bezpieczne)

---

# 🚫 Guardrails
- żadnych zmian w AWS
- nie zgaduj — jeśli brak danych, zaznacz to