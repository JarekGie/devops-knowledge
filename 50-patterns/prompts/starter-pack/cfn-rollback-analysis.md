---
title: cfn-rollback-analysis
domain: client-work
use_case: analiza UPDATE_ROLLBACK_FAILED
llm_target: any
---

# 🎯 Cel
Zdiagnozować przyczynę failure CloudFormation i zaproponować bezpieczne wyjście.

---

# 📥 Kontekst
## Stack
- nazwa: <stack_name>
- env: <env>

## Objaw
<error message / event log>

## Dane
<events, resources, template fragment>

---

# ⚙️ Zadanie
1. Znajdź root cause
2. Określ czy problem jest:
   - template
   - drift
   - AWS limitation
3. Zaproponuj recovery:
   - continue-update-rollback
   - resources-to-skip
   - patch template

---

# 📊 Format
## Werdykt
## Root cause
## Evidence
## Recovery plan (STEP BY STEP)
## Ryzyka

---

# 🚫 Guardrails
- nie zakładaj że template = runtime
- nie proponuj pełnego redeploy bez uzasadnienia