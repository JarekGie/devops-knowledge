---
title: finops-tagging-gap
domain: client-work
use_case: analiza braków tagowania
llm_target: any
---

# 🎯 Cel
Zidentyfikować przyczyny “untagged cost” i zaproponować poprawki.

---

# 📥 Kontekst
## Dane
- Cost Explorer output
- lista zasobów
- obecne tagi

---

# ⚙️ Zadanie
1. Rozdziel:
   - brak tagów
   - złe nazwy tagów
   - dane historyczne
2. Oszacuj wpływ

---

# 📊 Format
## Werdykt
## Breakdown (kategorie)
## Root cause
## Plan naprawy

---

# 🚫 Guardrails
- pamiętaj że CE = dane historyczne
- nie traktuj wszystkiego jako realny problem runtime