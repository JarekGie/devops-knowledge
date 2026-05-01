---
title: terraform-safe-review
domain: client-work
use_case: review zmian Terraform
llm_target: any
---

# 🎯 Cel
Ocenić ryzyko zmian Terraform przed apply.

---

# 📥 Kontekst
## Dane
- plan output
- fragment kodu

---

# ⚙️ Zadanie
1. Zidentyfikuj:
   - create
   - update
   - destroy
2. Wskaż high-risk zmiany

---

# 📊 Format
## Werdykt
## Zmiany (lista)
## Ryzyka
## Co jest bezpieczne
## Co wymaga uwagi

---

# 🚫 Guardrails
- traktuj destroy jako high-risk
- nie zakładaj że plan jest kompletny