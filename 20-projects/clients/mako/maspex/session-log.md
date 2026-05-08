# Maspex — Session Log

Format: data, co zrobiono, gdzie skończono, co następne.

---

## 2026-05-08 — sesja 2 — REDIS_URL fix + WAF Supabase IPv6

**Co zrobiono:**

### 1. Restore sekretu Redis
- Secret `maspex/uat/api` (klucz `ConnectionStrings__Redis`) przywrócony do ElastiCache:
  - `redis://maspex-uat.zwowz5.0001.euw1.cache.amazonaws.com:6379`
  - (poprzednia wersja z sesji 1 wskazywała na ELB eksperymentalny Redis)
- Przywrócono wersję `AWSPREVIOUS` przez `put-secret-value`

### 2. Diagnoza REDIS_URL vs ConnectionStrings__Redis
- **Root cause:** `maspex-api` task def (`:55`) wstrzykiwała `ConnectionStrings__Redis`, ale kod (`lib/redis/client.ts:40`) czyta wyłącznie `process.env.REDIS_URL` — Redis był niedziałający na UAT od momentu stworzenia infra
- Sampled requests z `pg_net/0.20.0` były blokowane ZANIM naprawiono WAF

### 3. Terraform fix: REDIS_URL w task definition
- Zmiana w `terraform/envs/uat/main.tf:86`:
  - `name = "ConnectionStrings__Redis"` → `name = "REDIS_URL"` (valueFrom bez zmian)
- `terraform apply -target=module.service_api.aws_ecs_task_definition.this`
- Nowa rewizja: `maspex-api:58`
- Force-new-deployment → 9/9 RUNNING, `Ready in 129ms`, brak błędów Redis
- Commit: `249e618`
- **Uwaga:** ten sam błąd istnieje w `envs/preprod/main.tf:87` i `envs/prod/main.tf:86` — nie naprawione

### 4. WAF diagnostics — Supabase IPv6 zablokowany
- Web ACL `maspex-uat-public-uat-allowlist` na CF `E3J76RNXIE2YIG`:
  - Default action: BLOCK
  - 1 reguła: allow tylko IPv4 IP set (biuro MakoLab)
  - IP set: `IPV4` only
- Supabase `pg_net` przychodzi z IPv6 `2a05:d018:135e:16df:624:8d0e:2886:f540` (IE) → default BLOCK
- 100/100 sampled requests = BLOCK, 7 dni = 0 sukcesów
- Ścieżki: `/api/cron/sync-redis`, `/api/cron/process-queue`, `/api/email/process-outbox`

### 5. Terraform fix: IPv6 IP set + WAF rule
- Dodano do `terraform/envs/uat/waf.tf`:
  - `aws_wafv2_ip_set.public_uat_supabase_ipv6` — IPV6, `2a05:d018:135e:16df:624:8d0e:2886:f540/128`
  - reguła `allow-supabase-ipv6` (priority 1) w Web ACL
- `terraform apply -target=aws_wafv2_ip_set.public_uat_supabase_ipv6 -target=aws_wafv2_web_acl.public_uat_allowlist`
- Weryfikacja: sampled requests 14:26-14:27 = **ALLOW** dla wszystkich 3 ścieżek ✅
- Commit: `b87c415`

**Stan na koniec sesji:**
- UAT: 9/9 API running na `maspex-api:58` z poprawnym `REDIS_URL`
- Redis: połączenie z ElastiCache `maspex-uat.zwowz5.0001.euw1.cache.amazonaws.com:6379`
- WAF: Supabase pg_net przechodzi przez `allow-supabase-ipv6` (P1)
- Cron/email: odblokowane ✅

**Otwarte:**
- [ ] preprod/prod Terraform: `ConnectionStrings__Redis` → `REDIS_URL` (ten sam błąd, nie naprawiony)
- [ ] WAF ryzyko: jeśli Supabase zmieni IPv6, blokada wróci — rozważyć custom header (Wariant C)
- [ ] Pre-existing drift `aws_ecs_service.redis` `:3`→`:2` — wymaga osobnego `terraform apply` lub `terraform state rm`

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
