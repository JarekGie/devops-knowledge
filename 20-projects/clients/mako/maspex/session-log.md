# Maspex — Session Log

Format: data, co zrobiono, gdzie skończono, co następne.

---

## 2026-05-15 — Campaign Day Monitoring (18 maja)

**Cel:** gotowy operatorski zestaw monitoringu na dzień kampanii.

**Branch:** `feat/campaign-day-monitoring` w `infra-maspex`

**Co zrobiono (additive-only):**
- `modules/monitoring/main.tf` — 3 nowe alarmy: `redis-high-engine-cpu` (>50% / 3 min), `redis-evictions` (>100/min), `ecs-api-pending-tasks` (>0 / 3 min)
- `modules/monitoring/main.tf` — Row 13: alarm status widget (24-wide, wszystkie alarmy operacyjne)
- `modules/monitoring/main.tf` — Row 14: ALBRequestCountPerTarget (z annotacją progu 200) + PendingTaskCount
- `terraform/envs/prod/main.tf` — Enhanced Container Insights: `container_insights = "enhanced"` (update in-place, zero ryzyka operacyjnego)
- Vault: `campaign-day-runbook.md` — runbook operatorski z progami, komendami, linkami do dashboardów

**Terraform apply wyniki:**
- UAT: 3 added, 12 changed, 0 destroyed ✅
- PROD: 3 added, 13 changed, 0 destroyed ✅ (Enhanced CI + 3 alarmy + dashboard)

**Dashboardy gotowe:**
- `maspex-prod-overview` — dashboard operatorski PROD (14 wierszy)
- `maspex-uat-overview` — dashboard UAT (14 wierszy)

**Następny krok:** przed 18 maja — weryfikacja SNS email subscription (sprawdź inbox jaroslaw.golab@makolab.com, potwierdź jeśli był pending)

---

## 2026-05-14/15 — Packer Rich AMI dla load test generatorów

**Cel:** zastąpienie wolnego user_data bootstrap (~8–12 min) Packer AMI z pełnym workspace — boot ~51s.

**Branch:** `feat/packer-ami-loadtest` w `infra-maspex`

**Co zrobiono:**
- `scripts/loadtest/token-generator/` — generate-tokens-fn.js przeniesiony z testy-qa/, hardcoded secrets zastąpione `process.env.JWT_SECRET/JWT_KID`
- `scripts/loadtest/k6/` — 7 scenariuszy z kapsel.zip wprowadzone do repo
- `scripts/loadtest/docker-compose.yml` — pin grafana:10.4.3, influxdb:1.8 bez auth
- `scripts/loadtest/bootstrap.sh` — 5 faz: SM → tokeny → compose → healthcheck → READY, logi do `/opt/loadtest/runtime/bootstrap.log`
- `scripts/loadtest/loadtest-bootstrap.service` — systemd oneshot, After=cloud-final.service
- `packer/` — ami.pkr.hcl + variables.pkr.hcl + 4 provisioner scripts
- `terraform/envs/uat/loadtest.tf` — IAM policy secretsmanager:GetSecretValue + switch LT na var.loadtest_ami_id
- `terraform/envs/uat/variables.tf` + `terraform.tfvars` — loadtest_ami_id = "ami-0c683ebe58c6bf4ee"
- `scripts/loadtest-fleet-start.sh` — fix: logi na stderr, grep-c bez || echo 0

**Bugs napotkane podczas packer build:**
1. File provisioner: `scp: /tmp/loadtest: Not a directory` → dodano `mkdir -p /tmp/loadtest` jako ec2-user przed upload
2. SCP permission denied → mkdir musiał być bez sudo (ec2-user musi być ownerem)
3. `ami_description` zawierał em-dash (—) → AWS akceptuje tylko ASCII, zamieniono na `-`

**Wyniki:**
- AMI: `ami-0c683ebe58c6bf4ee` (maspex-uat-loadtest-2026-05-15-044939, eu-west-1)
- Bootstrap na instancji: READY w **~51 sekund**
- `tokens.json`: 5000 tokenów ✅
- influxdb:1.8 + grafana:10.4.3 Up ✅
- PROD WAF zaktualizowany: 34.245.20.14, 18.203.85.84, 3.249.245.237, 54.154.135.106

**Terraform apply:**
- `aws_iam_role_policy.loadtest_secrets` — CREATE ✅
- `aws_launch_template.loadtest` — UPDATE (ami-0c683ebe58c6bf4ee) ✅
- `module.ecs_cluster` — Enhanced Container Insights drift zastosowany przy okazji ✅

**Następny krok:** ~~PR z `feat/packer-ami-loadtest` → main~~ DONE

---

## 2026-05-15 — Prod terraform apply — rename ECS service names

**Problem:** nazwy ECS serwisów zawierały zmienną env (`maspex-prod-api`), wymagana zmiana na `maspex-api`.

**Zmiana:** `terraform/envs/prod/main.tf` — 3 serwisy:
- `${var.project}-${var.environment}-api` → `${var.project}-api`
- `${var.project}-${var.environment}-admin-panel` → `${var.project}-admin-panel`
- `${var.project}-${var.environment}-bot` → `${var.project}-bot`

**Problemy napotkane podczas apply:**
1. IAM role `maspex-api-task`, `maspex-admin-panel-task`, `maspex-bot-task` już istniały w AWS (stworzone przez CI `makolab-ci`) — `EntityAlreadyExists` → import do state
2. SG `maspex-api-ecs`, `maspex-admin-panel-ecs`, `maspex-bot-ecs` już istniały w AWS (sierot, stworzone przez CI) — duplikat → state swap: stare SG (`maspex-prod-*-ecs`) usunięte ze state, sieroty zaimportowane (miały już prawidłowe nazwy i opisy) → plan zmienił się z `replace` na `update in-place`

**Import wykonane:**
- 6 IAM ról (task + execution dla 3 serwisów)
- 3 SG (po usunięciu starych ze state i zaimportowaniu sierot)

**Wynik apply:** 20 added, 18 changed, 0 destroyed ✅

**Commit:** `3f75a8e` — push do `main`

---

## 2026-05-14 — Enhanced Container Insights UAT — discovery + IaC change

**Cel:** włączyć per-task metryki CPU/memory, żeby zidentyfikować hotspot z anomalii Memory avg 45% / max 96%.

**Odkrycia:**
- Standard CI był już włączony (`containerInsights=enabled` na klastrze)
- `describe-clusters` bez `--include SETTINGS` zwraca `settings: []` — gotcha
- Namespace `ECS/ContainerInsights` publikuje metryki, ALE tylko na poziomie ServiceName/TaskDefinitionFamily — nie ma TaskId dimension
- Enhanced CI (`value=enhanced`) doda TaskId dimension → per-task CPU + memory

**Zmiana IaC:**
- Plik: `terraform/envs/uat/main.tf` — `module "ecs_cluster"`: `container_insights = "enhanced"`
- Branch: `analysis/maspex-load-test-2026-05-11` (obecny)
- Tylko UAT, prod/preprod bez zmian

**Status:** czeka na `terraform apply -target=module.ecs_cluster` w UAT env

**Vault:** `enhanced-container-insights-uat.md` — pełna analiza + plan walidacji na kolejny load test

---

## 2026-05-11/12 — Preprod zaslepka v10 + UAT autoscaling + PROD parity + loadtest scripts

### Preprod zaslepka v10 — PDF politykaprywatnosci

**Branch:** `feat/preprod-zaslepka-polityka-prywatnosci`  
**Commit:** `dc893f5`

- Dockerfile: dodano `COPY --chmod=644 politykaprywatnosci.pdf /usr/share/nginx/html/`
- `terraform/envs/preprod/main.tf`: `zaslepka-v9` → `zaslepka-v10` (service_admin_panel + service_bot)
- Image zbudowany: `--platform linux/amd64`, push do ECR jako `zaslepka-v10`
- Apply preprod: nowa task definition `:9` (admin_panel + bot), service_admin_panel zaktualizowany ✅
- ⚠️ Bot service preprod **nie zaktualizowany** — pre-existing błąd: `maspex-preprod-bot` TG bez associated load balancer (`InvalidParameterException`). Task def `:9` istnieje, ale service tkwi na `:1`.

### UAT autoscaling — ALBRequestCountPerTarget

**Branch:** `feat/uat-autoscaling-alb-request-count`  
**Commit:** `ac6f94f`  
**Status: APPLIED ✅**

- `terraform/envs/uat/autoscaling.tf`: nowa policy `api_alb_request_count`
  - TargetValue=200, ScaleOut=30s, ScaleIn=300s
  - ResourceLabel: `${element(split(":loadbalancer/", module.alb.arn), 1)}/${module.alb_routing.api_tg_arn_suffix}`
- Istniejące policy CPU + memory zachowane jako safety nets
- Uzasadnienie: Node.js I/O-wait na PostgREST/Supabase — CPU wygląda zdrowo gdy requesty się kolejkują

### PROD parity z UAT

**Branch:** `feat/prod-parity-uat`  
**Status: VALIDATE ✅ — APPLY ZABLOKOWANY** (oczekiwanie na cert + tagflagi)

Pliki zmienione:
- `terraform/envs/prod/autoscaling.tf` — identyczna policy `api_alb_request_count` jak UAT
- `terraform/envs/prod/main.tf` — dodano `/email/*` do `cloudfront_site_api.static_path_origin_request_policy_ids`
- `terraform/envs/prod/waf.tf` — dodano:
  - `aws_wafv2_ip_set.public_app_supabase_ipv6` (Supabase pg_net: `2a05:d018:135e:16df:624:8d0e:2886:f540/128`)
  - rule `allow-supabase-ipv6` (priority=1) w `public_app_allowlist`
  - `aws_wafv2_ip_set.loadtest_allowlist` (empty, IPv4, CLOUDFRONT scope)
  - rule `allow-loadtest-fleet` (priority=2) w `public_app_allowlist`
- `terraform/envs/prod/outputs.tf` — `loadtest_waf_ip_set_id` + `loadtest_waf_ip_set_name`
- `terraform/envs/prod/terraform.tfvars`:
  - `cloudfront_domain = "kapsel-prod.makotest.pl"`
  - `cloudfront_certificate_arn = "arn:aws:acm:us-east-1:969209893152:certificate/369af310-e1da-41db-b91c-4d7c4f1a3822"`
  - `api_domain = "kapsel-api.prod.makotest.pl"`
  - `api_cloudfront_certificate_arn = "arn:aws:acm:us-east-1:969209893152:certificate/3247fa27-4cab-476f-a025-a64ab509412c"`
  - `alb_certificate_arn` = PLACEHOLDER (eu-west-1 cert nie dostarczony)

**Blokery przed apply:**
- Certy ACM `369af310` i `3247fa27` muszą być ISSUED (CloudFront us-east-1)
- `alb_certificate_arn` eu-west-1 — nie ma wartości
- `api_redis_secret_arn` — sufiks `REPLACE` do usunięcia
- `api_image_tag`, `admin_panel_image_tag`, `bot_image_tag` — ustawić właściwe tagi

### Loadtest fleet scripts

**Branch:** `feat/prod-parity-uat`  
**Commit:** `a7c6c43`

Nowe skrypty w `scripts/`:
- `loadtest-fleet-start.sh` — scale ASG do `--desired` (default 2), czeka na public IPs (timeout 300s), aktualizuje WAF `maspex-prod-loadtest-allowlist` (CLOUDFRONT, us-east-1) z /32 CIDRs
- `loadtest-fleet-stop.sh` — czyści WAF IP set NAJPIERW (przed scale-down), potem ASG desired=0
- Oba: `--dry-run` mode, `AWS_PROFILE=maspex-cli`
- WAF empty list przez `--cli-input-json` (bash array z pustą listą jest zawodny)

Terraform header w `uat/loadtest.tf` zaktualizowany — odsyła do skryptów zamiast ręcznych komend.

---

## 2026-05-11 — Load test analysis + LT docker-compose fix

### Docker Compose fix (Launch Template)

**Problem**: LT v4 nie miał sekcji Docker Compose — `terraform apply` nie był uruchamiany po commitach `ee72c24`/`0f1eead`. Nowe instancje po scale-down/up nie miały docker-compose.

**Fix**:
- `terraform apply -target=aws_launch_template.loadtest` → LT v5 z docker-compose + symlink + nowy AMI (`ami-021aafe982d496ca8`)
- SSM install na żywych instancjach `i-0582638efb544461f`, `i-0ae9783517c9b9d03` → Docker Compose v5.1.3 ✅

### Load test analysis 2026-05-11 00:00–01:00 CEST

Pełna analiza: `load-test-analysis-2026-05-11-0000-cest.md`

**Kluczowe wnioski:**
- BRAK `VOTE_CACHE_WRITETHROUGH_FAIL` — poprawka Redis z 2026-05-08 zadziałała (było 924k błędów w 2026-05-05 19:00)
- Peak 00:20 CEST: ALB 1.249M req/5min, ECS CPU avg 46.1%, p99 **15.8 s**, 3464 target-5xx
- Redis zdrowy: CPU max 14.7%, evictions=0, swap=0, hit ratio ~70%
- **Post-test anomalia**: latencja ALB (health checks) nie wraca do baseline przez >1h (460–520 ms), memory ECS zatrzymuje się na 67% avg
- Bottleneck: application-level — Node.js event loop saturation lub DB connection pool exhaustion (nie Redis, nie ALB, nie CF)
- Odkrycie: logi maspex-api trafiają do `/maspex/uat/contest-service` (nie do `/maspex/shared/maspex-api` która jest pusta)

**Otwarte:**
- [ ] Zbadać przyczynę post-test elevated latency (460ms health checks)
- [ ] Zbadać memory retencję (67% avg po teście, baseline 13–18%)
- [ ] Poprawić konfigurację log group w task definition (lub uaktualnić dokumentację)
- [ ] APM/distributed tracing przed testem produkcyjnym

---

## 2026-05-09 sesja 5 — Load test: loadtest-ctrl.sh — WAF automation dla macOS

**Commit:** `ae39b3a` (branch: `fix/uat-loadtest-docker-compose-plugin`, pushed)

### loadtest-ctrl.sh — pełna paryteta z PS1

Skrypt bash portowany z PowerShell, obsługuje te same flagi (`--run`, `--stop`, `--clear`, `--ssh`) z identyczną logiką WAF.

Kluczowe różnice techniczne vs PS1:
- JSON budowany przez `jq`: `printf '%s\n' "${merged[@]}" | jq -R . | jq -sc .` — bez problemów z quote stripping
- `mapfile -t ips < <(get_loadtest_public_ips)` — bash array z process substitution
- `exec ssh ec2-user@$target_ip` — zastępuje proces skryptu (bez wrapper shella)
- `check_deps` sprawdza `aws` + `jq` na starcie

Skalowanie floty — dwa miejsca (muszą być spójne):
1. `loadtest.tf`: `aws_autoscaling_group.max_size`, `desired_capacity`
2. `loadtest-ctrl.sh`: `DESIRED_CAPACITY_RUN`, `MAX_SIZE_RUN`
3. `loadtest-ctrl.ps1`: `$DesiredCapacityRun`, `$MaxSizeRun`

---

## 2026-05-09 sesja 4 — Load test: SG porty Grafana/InfluxDB + skalowanie floty

**Commit:** `d5e63e5`

### SG — Grafana i InfluxDB

Grafana (`0.0.0.0:3000`) i InfluxDB (`0.0.0.0:8086`) działały w Dockerze, ale SG miał tylko port 22. Dodano:
- `3000/tcp` z biurowych IP (Grafana)
- `8086/tcp` z biurowych IP (InfluxDB)
- `8086/tcp` self (inter-instance — k6 → InfluxDB między instancjami)

Terraform applied natychmiast bez restartu instancji.

### Gdzie zwiększać rozmiar floty

Dwa miejsca — muszą być spójne:
1. `terraform/envs/uat/loadtest.tf` → `aws_autoscaling_group`: `max_size`, `desired_capacity`
2. `scripts/loadtest-ctrl.ps1` → `$DesiredCapacityRun`, `$MaxSizeRun`

---

## 2026-05-09 sesja 3 — Load test: JSON quoting fix + docker-compose symlink

**Branch:** `fix/uat-loadtest-docker-compose-plugin` (commity `d1f367f`, `0f1eead`)

### JSON quoting fix (loadtest-ctrl.ps1)

`ConvertTo-Json @($merged) -Compress` produkuje poprawny JSON, ale PowerShell 5.1 na Windows zjada cudzysłowy przy przekazaniu stringa do zewnętrznego procesu. AWS CLI dostaje `[52.49.155.58/32,...]` zamiast `["52.49.155.58/32",...]` → `ParamValidation` error.

Fix: ręczny string join:
```powershell
'["' + ($merged -join '","') + '"]'
```

Przy okazji: dodano `$LASTEXITCODE` check — skrypt nie kontynuuje po błędzie AWS CLI.

### docker-compose symlink

`docker-compose up -d` → `command not found`. Zainstalowany jest tylko v2 plugin (inwokacja przez `docker compose` ze spacją). Deweloper domyślił się i dodał symlink ręcznie.

IaC fix w `loadtest.tf` — nowe instancje dostają symlink od razu:
```bash
ln -sf /usr/local/lib/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose
```

Oba warianty (`docker compose` i `docker-compose`) działają na nowych instancjach.

---

## 2026-05-09 sesja 2 — Load test: PS5.1 fix, scheduler-safe WAF, IAM fix

**Branch:** `fix/uat-loadtest-docker-compose-plugin` (commit `4ed1e37`, `901a908`)

### PS5.1 syntax fix

Deweloper zgłosił błędy parsera PowerShell 5.1 na Windows:
- `$($i + 1))` — podwójny `)` łamał parser (`Missing closing '}'`). Fix: `-f` format operator
- `node'a` — apostrof w double-quoted string powodował `string missing terminator`. Fix: usunięty apostrof

### Obsługa schedulera 19:00

`Remove-LoadTestIpsFromAllowList` w `--stop` pobierało IP z InService → jeśli scheduler już ubił instancje, zwracało `[]` → WAF nie był czyszczony → stale IPs w allowliście.

Fix: zastąpiono `Remove-LoadTestIpsFromAllowList` przez `Clear-LoadTestAllowList` — czyści cały dedykowany IP Set niezależnie od stanu instancji (GET lock-token + UPDATE z `[]`).

Przy `--run` dodano `Clear-LoadTestAllowList` przed `Add` — usuwa stale IPs z poprzedniej sesji.

### IAM fix — makolab-qa

Błąd: `AccessDeniedException: wafv2:GetIPSet ... because no identity-based policy allows the wafv2:GetIPSet action`

Policy `maspex-uat-loadtest-operator` nie miała żadnych uprawnień WAFv2 — skrypt dodano po policy.

Fix: nowy Statement `WafLoadtestAllowlist` w `iam-loadtest-operator.tf`:
```json
{ "wafv2:GetIPSet", "wafv2:UpdateIPSet" }
Resource: arn:aws:wafv2:us-east-1:969209893152:global/ipset/maspex-uat-loadtest-allowlist/76b89f7c-...
```

Terraform applied. IAM Policy Simulator: `allowed` dla obu akcji ✅

### Stan na koniec sesji 2

- MR ma 4 commity, gotowy do merge
- makolab-qa: pełne uprawnienia do obsługi skryptu
- Oczekuje na test end-to-end przez dewelopera

---

## 2026-05-09 — Load test: Docker Compose v2 + WAF allowlist automation

**Branch:** `fix/uat-loadtest-docker-compose-plugin` (pushed, MR otwarty na GitLab)
**Repo:** `~/projekty/mako/aws-projects/infra-maspex`
**Commity:** `ee72c24`, `5572bdb`

### Docker Compose v2 plugin

Problem: maszyny load testowe (ASG `maspex-uat-loadtest`, 2× c6i.4xlarge) uruchamiały się bez `docker compose` (v2). AL2023 nie pakuje `docker-compose-plugin` w swoich repozytoriach.

Naprawa dwutorowa:
- **IaC** (`loadtest.tf`): dodano instalację binarki z GitHub Releases do `/usr/local/lib/docker/cli-plugins/docker-compose` — wchodzi przy każdym nowym spin-upie
- **Żywe instancje**: naprawione przez SSM Send-Command — `Docker Compose version v5.1.3` potwierdzone na obu instancjach (`i-035c3a2af554ffbf7`, `i-0e3c308a34aeb7c49`)

Przy okazji: scheduled scale-down (19:00 Warsaw) i rzeczywiste SSH keys (`jaroslaw.golab`, `karol.maslaniec`) wypełnione w `terraform.tfvars`.

### WAF allowlist automation

**Discovery:** blokada `kapsel.makotest.pl` = CloudFront WAFv2 IP Set, **nie Security Group**. ALB SG jest `0.0.0.0/0` — nie jest punktem kontroli. Potwierdzone przez SSM curl: maszyny dostają `403` od WAF, `kapsel-uat.makotest.pl` (osobna domena, IP `193.239.136.82`) to inna infrastruktura.

**Terraform (`waf.tf` + `outputs.tf`):**
- Nowy `aws_wafv2_ip_set.loadtest_allowlist` (`maspex-uat-loadtest-allowlist`, pusty, `lifecycle.ignore_changes = [addresses]`)
- Nowa reguła `allow-loadtest-ips` (priority 2) w `aws_wafv2_web_acl.public_uat_allowlist`
- Output `loadtest_waf_ip_set_id = "76b89f7c-b8c9-4725-ad8c-56600786fe8e"`
- **Terraform applied** (maspex-cli, lock=false — DynamoDB locks niedostępne przez mako-dc)

**Skrypt (`scripts/loadtest-ctrl.ps1`):**
- `Get-LoadTestPublicIps` — zwraca `x.x.x.x/32` dla InService instancji
- `Add-LoadTestIpsToAllowList` — GET lock-token + merge + UPDATE (idempotentny)
- `Remove-LoadTestIpsFromAllowList` — GET lock-token + filter + UPDATE (idempotentny)
- `--run`: po InService dopisuje IP do dedykowanego WAF IP Set
- `--stop`: **najpierw** usuwa IP z WAF (gdy instancje żyją), **potem** `desired=0`
- Bezpieczeństwo: oddzielny IP Set — nigdy nie dotykamy biurowych IP z `public_uat_allowlist`

### Stan na koniec sesji

- MR na GitLabie: gotowy do przeglądu przez dewelopera
- WAF IP Set: aktywny, pusty (maszyny stoją, poprawny stan)
- `kapsel.makotest.pl`: zwraca 403 dla maszyn loadtest (prawidłowe — IP nie ma w WAF)

### Następne kroki

- [ ] Test end-to-end: `--run` → curl `kapsel.makotest.pl` → 200, `--stop` → 403
- [ ] Merge MR po weryfikacji
- [ ] Bot UAT unhealthy (FailedHealthChecks) — osobny problem, niezmieniony

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

---

## 2026-05-14 — Load test observability fix + PROD first terraform apply

### Load test observability pipeline (k6 → InfluxDB → Grafana)

- Docker Compose na EC2 UAT load generators poprawiony: dodano `INFLUXDB_DB=k6`, named volumes
- Grafana file provisioning: datasource YAML (UID `dfm0hl1zdovswd`), dashboard provider YAML
- Dashboard JSON (`k6-load-testing-by-groups.json`, 67KB) przeniesiony z EC2 instancji 2 przez gzip+base64 i zapisany do repo
- Pliki dodane do `scripts/loadtest/` w repo
- SSM deployment obu instancji ✅

### Port 8086 między generatorami

- Problem: Karol używał publicznego IP → timeout przez IGW (SG self-reference nie działa na publiczne IP)
- Fix: użyć prywatnego IP `10.44.0.211` (instancja 1) — SG self-reference działa tylko na private routing
- Brak zmian infrastruktury — tylko operacyjna wiedza

### Skrypty floty — prywatne IP

- `loadtest-ctrl.ps1`: dodano wyświetlanie prywatnych IP i `K6_OUT` hint po uruchomieniu floty
- `loadtest-fleet-start.sh`: analogicznie dodano `get_instance_private_ips()` i sekcję z K6_OUT hint
- Branch `feat/prod-parity-uat`, MR !15, merge do main ✅

### GitLab MR operations

- Wypchnięto branch `feat/prod-parity-uat`, MR !15 stworzony i merged ✅
- MR !12 (Draft by Kmicic) un-drafted i merged ✅
- Merge conflict `loadtest-ctrl.ps1` (add/add): rozwiązany `--ours` (nasze zmiany to superset)
- Local sync po merge wykonany

### PROD terraform apply — pierwsze uruchomienie

**Branch:** `analysis/maspex-load-test-2026-05-11` (tylko tfvars + waf.tf fix, nie mergowany do main)

**Problemy podczas apply:**
1. `terraform init` bez `-backend-config=backend.hcl` → `"key": required field is not set` — fixed
2. `AWS_PROFILE` potrzebny jako env var dla backend S3 auth
3. `terraform plan` error: `count` depends on `https_listener_arn` (unknown at plan time) → apply etapami
4. CloudFront apply error: em dash `—` w WAF IP set description → waf.tf poprawiony (regular dash)
5. Chicken-and-egg: ElastiCache tworzy się w apply, ale secret Redis potrzebny przed apply

**Sekwencja apply:**
1. `-target=module.alb` → ALB + HTTPS listener ✅
2. `-target=module.cloudfront_site -target=module.cloudfront_site_api -target=aws_wafv2_*` → CloudFront + WAF ✅
3. `-target=aws_wafv2_ip_set.loadtest_allowlist` (po fix em dash) ✅
4. Pełny `terraform apply` → 85 resources ✅

**Zasoby PROD po apply:**
- ALB: `maspex-prod-1795571755.eu-west-1.elb.amazonaws.com`
- CloudFront admin panel: `dfx1ac92hj3uw.cloudfront.net` → `kapsel-prod.makotest.pl`
- CloudFront API: `d1w5bz7itj42sz.cloudfront.net` → `kapsel-api-prod.makotest.pl`
- ElastiCache: `maspex-prod.zwowz5.0001.euw1.cache.amazonaws.com:6379`
- ECS: 9/9 API, 1/1 bot, 1/1 admin-panel running
- Loadtest WAF IP Set PROD: `maspex-prod-loadtest-allowlist` ID `6aab8ec9-a959-459f-a52a-88638d3ffa41`

**Secret PROD API:**
- ARN: `arn:aws:secretsmanager:eu-west-1:969209893152:secret:maspex/prod/api-z6g7eq`
- Redis URL zaktualizowany z prawdziwym endpointem po apply
- ECS forced new deployment (zadania pobiorą nowy secret przy restarcie)

**Image tags:**
- API: `coreapp-uat-612`
- Admin panel: `zaslepka-v10`
- Bot: `maspex-worker-uat-17`

**Do zrobienia po sesji:**
- [ ] PowerDNS CNAME: `kapsel-prod.makotest.pl` → `dfx1ac92hj3uw.cloudfront.net`
- [ ] PowerDNS CNAME: `kapsel-api-prod.makotest.pl` → `d1w5bz7itj42sz.cloudfront.net`
- [ ] Zweryfikować health ECS tasks po rolling deployment (Redis secret)
- [ ] Commitować waf.tf i tfvars fix do main (przez MR)
- [ ] Bot UAT unhealthy — diagnoza health check config i logów /maspex/uat/bot
