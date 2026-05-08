# Maspex — Session Log

Format: data, co zrobiono, gdzie skończono, co następne.

---

## 2026-05-08 — sesja 5 — SSH keys + operator scripts + IAM least-privilege

**Zakres:** load test fleet — dostęp SSH, skrypty operacyjne, auto-shutdown, IAM hardening.

### 1. SSH keys do load test generatorów (IaC)

- Mechanizm już istniał: `var.loadtest_ssh_pubkeys` → user-data → `/home/ec2-user/.ssh/authorized_keys` (AL2023, `ec2-user`)
- Dodano 3 klucze w `terraform/envs/uat/terraform.tfvars` (`loadtest_ssh_pubkeys`):
  - `jaroslaw.golab@S004268` (RSA)
  - `karol.maslaniec@makolab.com` (ED25519)
  - `mateusz.kmiecik` (RSA, `root@s004742`)
- Każde dodanie: `terraform apply -target=aws_launch_template.loadtest` → nowa wersja LT → instance refresh (MinHealthyPercentage=50)
- Weryfikacja przez SSM `send-command` — wszystkie 3 klucze potwierdzone live na instancjach
- Instancje po ostatnim refreshie: `i-00b4dd5a06af19a7f` (3.251.67.108), `i-085842e07c2614a39` (3.248.207.255) — LT v4

### 2. Skrypty operacyjne: `loadtest-ctrl`

Nowe pliki w `scripts/`:
- `scripts/loadtest-ctrl.ps1` — Windows/PowerShell
- `scripts/loadtest-ctrl.sh` — macOS/Linux/bash

Flagi:
- `--run` / `-run` — scale ASG do 2, czeka aż InService
- `--stop` / `-stop` — scale ASG do 0, czeka aż puste
- `--clear` / `-clear` — CF invalidation `/*` + ElastiCache reboot (z potwierdzeniem YES)
- `--ssh` / `-ssh` — pobiera public IP InService instancji z ASG → przy 1 łączy od razu, przy 2 pyta o wybór → `ssh ec2-user@<ip>`

Bash używa `jq` do parsowania JSON (dodany `check_deps`). `exec ssh` zastępuje proces skryptu.

### 3. Auto-shutdown ASG — 19:00 Warsaw time

- Dodano do `terraform/envs/uat/loadtest.tf`:
  ```hcl
  resource "aws_autoscaling_schedule" "loadtest_scale_down" {
    scheduled_action_name  = "maspex-uat-loadtest-scale-down-1900"
    recurrence             = "0 19 * * *"
    time_zone              = "Europe/Warsaw"   # DST obsługiwane automatycznie
    desired_capacity       = 0
    min_size               = 0
    max_size               = -1               # max=2 bez zmian, --run nadal działa
  }
  ```
- Verified live: `aws autoscaling describe-scheduled-actions` ✅

### 4. IAM least-privilege dla makolab-qa

**Przed:** `AdministratorAccess` (pełny dostęp do konta)
**Po:** `maspex-uat-loadtest-operator` — 6 akcji, resource-scoped gdzie AWS pozwala

| Akcja | Resource |
|---|---|
| `sts:GetCallerIdentity` | `*` |
| `autoscaling:DescribeAutoScalingGroups` | `*` |
| `autoscaling:UpdateAutoScalingGroup` | ASG `maspex-uat-loadtest` |
| `ec2:DescribeInstances` | `*` |
| `cloudfront:CreateInvalidation` + `GetInvalidation` | CF `E3J76RNXIE2YIG` |
| `elasticache:RebootCacheCluster` | cluster `maspex-uat` |

- Plik: `terraform/envs/uat/iam-loadtest-operator.tf` — ARNy budowane z live state (bez hardkodowanych ID)
- `terraform apply` → policy `arn:aws:iam::969209893152:policy/maspex-uat-loadtest-operator`
- `aws iam detach-user-policy AdministratorAccess` — odepnięto ✅
- Verified: `list-attached-user-policies` zwraca tylko `maspex-uat-loadtest-operator` ✅

**Stan na koniec sesji:**
- SSH: 3 osoby mają dostęp do load test maszyn (`ec2-user@3.251.67.108`, `ec2-user@3.248.207.255`)
- Skrypty: `loadtest-ctrl.sh` (macOS) + `loadtest-ctrl.ps1` (Windows) w `scripts/`
- Auto-shutdown: 19:00 Warsaw time każdego dnia
- IAM: `makolab-qa` bez AdminAccess — tylko operacje skryptów

**Otwarte:**
- [ ] WAF allowlist: dodać nowe IPs instancji (3.251.67.108, 3.248.207.255) do `public_uat_extra_allowed_ipv4_cidrs` przed testem — przy każdym `--run` IPs się zmieniają, więc warto rozważyć alternatywę (ALB direct + Host header)

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

## 2026-05-08 — sesja 4 — Load test infrastructure

**Cel:** 2 maszyny generatorów ruchu k6 w VPC UAT.

### VPC Discovery

- VPC: `vpc-0df07c64ea8a8b00e` (10.44.0.0/16) — shared (owner: hub account)
- IGW: `igw-0c10dce685b0226e6` — attached, available
- NAT: `nat-0d1caf7eeb99c43fe` — w hub account, niewidoczny z naszego konta
- Subnety publiczne: `maspex-public-az1/az2` → `0.0.0.0/0 → IGW`, `MapPublicIpOnLaunch=False`
- Subnety app: `maspex-app-az1/az2` → `0.0.0.0/0 → NAT (hub)`
- Subnety backend: `maspex-backend-az1/az2` → NAT (hub)
- VGW: `vgw-0f7eeec82737e4797` — VPN propagowany do obydwu RT

### Decyzja architektoniczna: Wariant A

Public subnets + `associate_public_ip_address=true` + SSH.  
Uzasadnienie: znane IP źródłowe (dla WAF), bezpośredni SSH, brak zmian w shared routing.

### Zmiany Terraform

- Commit: `af18cb5` (infra-maspex)
- Nowy plik: `terraform/envs/uat/loadtest.tf`
  - `data.aws_ami.loadtest_al2023` — najnowszy AL2023 AMI
  - `aws_security_group.loadtest` — SSH z biura MakoLab (195.117.107.110, 91.233.19.251)
  - `aws_iam_role.loadtest` + `aws_iam_role_policy_attachment.loadtest_ssm` — SSM access
  - `aws_iam_instance_profile.loadtest`
  - `aws_launch_template.loadtest` — c6i.4xlarge, 50GB gp3, AL2023, user_data bootstrap
  - `aws_autoscaling_group.loadtest` — min=0, desired=2, max=2, no scaling policies
- Zmodyfikowane: `variables.tf` (+loadtest_ssh_pubkeys, +loadtest_extra_ssh_cidrs), `outputs.tf`, `terraform.tfvars`

### Stan po deploy

- ASG: `maspex-uat-loadtest` (min=0, max=2, desired=2)
- Instancje:
  - `i-0ee2df328caa07706` → `54.170.233.211` (eu-west-1a, 10.44.0.236)
  - `i-0890054b5bf36fb7b` → `34.255.6.69` (eu-west-1b, 10.44.1.89)
- Docker 25.0.14 ✅ | k6 v2.0.0-rc1 ✅ | SSM Online ✅
- Outbound: HTTP 403 z kapsel.makotest.pl — maszyny docierają do CloudFront, WAF blokuje (oczekiwane)

### Uwagi bootstrap

`dnf update -y` fail na AL2023 — conflict `curl`/`curl-minimal`. Fix: `--allowerasing`.  
Pierwsze uruchomienie naprawione ręcznie przez SSM. LT zaktualizowane do wersji z fixem.

**Otwarte (przed pierwszym testem):**
- [ ] SSH keys: dodać klucze Karola i Jarosława do `loadtest_ssh_pubkeys` w tfvars + `terraform apply`
- [ ] WAF allowlist: dodać `54.170.233.211/32` i `34.255.6.69/32` do `public_uat_extra_allowed_ipv4_cidrs` + apply
- [ ] Alternatywnie: testy przez ALB bezpośrednio (pomijając CloudFront+WAF): `http://maspex-uat-1361582173.eu-west-1.elb.amazonaws.com` z `Host: kapsel.makotest.pl`
- [ ] Po zakończeniu testów: scale to 0 → `aws autoscaling set-desired-capacity --auto-scaling-group-name maspex-uat-loadtest --desired-capacity 0 --profile maspex-cli --region eu-west-1`

---

## 2026-05-08 — sesja 3 — Redis state check (ElastiCache vs experimental)

**Co zrobiono:**

Weryfikacja stanu Redis po naprawie `REDIS_URL` — sprawdzono oba klastry via ECS Exec.

### ElastiCache `maspex-uat.zwowz5.0001.euw1.cache.amazonaws.com:6379`

- `DBSIZE`: 3592 kluczy
- Keyspace: `db0: keys=3592, expires=3592, avg_ttl=~235000ms`
- **Wszystkie klucze mają TTL** — brak "zapomnianego" garbage
- Typy kluczy:
  - `slogan:data:<uuid>-v2` → STRING, TTL ~300s (SLOGAN_CACHE_TTL_SECONDS)
  - `slogans:by_votes`, `slogans:by_date`, `slogans:by_alphabet` → ZSET, TTL ~900s (RANKING_ZSET_TTL_SECONDS), ~3584 members
  - `stage:active`, `slogans:total_count` — nieobecne (generowane dopiero gdy cache zimny lub specyficzny trigger)
- Stats: `total_commands_processed=1.76M`, `expired_keys=64k` → cache aktywnie używany od ~14:30 (po naprawie task def)
- `connected_clients=9` (9 tasków API)

### Experimental ECS Redis (z sesji 1)

- `DBSIZE=0` — zero kluczy
- `expired_keys=4` — krótkie połączenie rano podczas testów ELB endpoint (sesja 1)
- `connected_clients=0` — nikt już nie łączy
- Status: **idle, bezpieczny do usunięcia**

### Wnioski

- ElastiCache jest aktywny i zdrowy — aplikacja poprawnie pisze i odczytuje cache po naprawie REDIS_URL
- Experimental Redis był nigdy naprawdę nie używany przez aplikację (0 kluczy, tylko 4 expired z testów)
- Sekwencja `maspex-api:55` (błędna zmienna) → `maspex-api:58` (REDIS_URL) naprawia cache end-to-end

**Stan na koniec sesji:**
- Redis (ElastiCache): 3592 kluczy, aktywny, healthy ✅
- Experimental ECS Redis: idle, 0 kluczy ✅

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
