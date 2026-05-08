# Maspex — Session Log

Format: data, co zrobiono, gdzie skończono, co następne.

---

## 2026-05-08 — Redis ELB migration + UAT cache refresh

**Co zrobiono:**
- Reboot Redis `maspex-uat` (node 0001) → `available` ✅
- CloudFront invalidation `/*` na `E3J76RNXIE2YIG` (kapsel.makotest.pl) → `Completed` ✅
- Zmiana connection stringa Redis w `maspex/uat/api`:
  - STARY: `redis://maspex-uat.zwowz5.0001.euw1.cache.amazonaws.com:6379`
  - NOWY: `redis://maspex-uat-redis-9e944396060e4763.elb.eu-west-1.amazonaws.com:6379`
- Force-new-deployment `maspex-api` → 9/9 running z nowym connection stringiem ✅

**Kontekst zmiany:**
Nowy endpoint to ELB przed Redis zamiast direct ElastiCache. Motywacja: prawdopodobnie HA lub proxy layer. Po ostatnim load teście (2026-05-05 19:00) Redis write-through był uszkodzony (circuit breaker nie zamykał się — 924k błędów). Reboot + nowy endpoint = reset stanu.

**Rollback:**
Pełna dokumentacja: `redis-connection-change-2026-05-08.md`

**Stan na koniec sesji:**
- UAT: 9/9 API running, nowy Redis connection string aktywny
- Bot UAT: nadal unhealthy (FailedHealthChecks) — niezmienione, osobny problem
- Preprod API: nadal 0/3 (IAM error na secret) — niezmienione

**Następna sesja:**
- [ ] Zweryfikować logi po obciążeniu — czy VOTE_CACHE_WRITETHROUGH_FAIL zniknęły
- [ ] Ewentualny load test smoke po zmianie Redis endpoint
- [ ] Bot UAT unhealthy — diagnoza health check config i logów /maspex/uat/bot
