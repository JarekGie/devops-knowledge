---
title: ecs-alb-debug
domain: client-work
use_case: debug healthcheck / deployment ECS
llm_target: any
---

# 🎯 Cel
Zdiagnozować problem z ECS service / ALB health check.

---

# 📥 Kontekst
## Service
- nazwa: <service>
- cluster: <cluster>

## Objaw
- unhealthy targets / 5xx / restart loop

## Dane
- target group config
- health check path
- logs (jeśli są)

---

# ⚙️ Zadanie
1. Sprawdź spójność:
   - port
   - path
   - matcher
2. Oceń czy problem jest:
   - app-level
   - infra-level
3. Wskaż fix

---

# 📊 Format
## Werdykt
## Evidence
## Root cause
## Fix
## Jak zweryfikować

---

# 🚫 Guardrails
- nie zakładaj że brak logów = brak problemu
- oddziel problem aplikacji od infra