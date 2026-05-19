# Teraz

> Aktualizuj przy każdej zmianie kontekstu. To jest twój punkt wejścia po przerwie.

## Update — 2026-05-19 — MASPEX: WAF rollback + FinOps DONE ✅

```
WAF ADMIN PANEL ROLLBACK: ZAMKNIĘTY
  commit ca12875 → push → MR #16
  default_action: allow → block
  Allowlist: MakoLab 195.117.107.110/32 + Maspex 91.233.19.251/32 + Moderia 89.228.178.218/32
  D4 drift (IAM tag uat→prod) zamknięty przy okazji

FINOPS CAPACITY ANALYSIS: ZAMKNIĘTY
  Raport: 20-projects/clients/mako/maspex/finops-capacity-analysis-2026-05-19.md
  Werdykt: CONDITIONAL GO — min=30→8, max=45→30
  Oszczędności: ~$2 190/mies. (−49%)
  Warunki: alarm RunningTaskCount<6, alarm p99>500ms, 7 dni monitoringu
  AKTUALNY STAN AWS: min=30, max=45, desired=30 (P1 jeszcze nie wdrożone)

OTWARTE DRIFTY:
  D2 — image tag w tfvars (coreapp-uat-612 ≠ running coreapp-prod-805) — bezpieczne, ignore_changes
  D3 — orphaned ACM cert w TF state (terraform state rm przed next apply)
  P1 — autoscaling min=30→8, max=45→30 (CONDITIONAL GO, nie wdrożone)
  P2 — confirm terraform plan = 0 zmian dla secret_arns fix
```

---

## RSHOP — stan zawieszony (wróć po ~10:35 UTC)

```
PROJEKT:  rshop — e-commerce Renault/Dacia
ACCOUNT:  943111679945 | eu-central-1 | profile: cd-rshop
REPO:     ~/projekty/mako/eshop-cicd (Jenkins pipelines)

ROOT CAUSE: stary Jenkinsfile → ChangeSet na parent stack → cascade FrontendDacia/FrontendRenault
  Obrazy frontendd.1364 + frontendr.1364 nie istnieją w ECR → NotStabilized po ~3h

STAN (09:46 UTC):
  dev-ECSStack-1BLAWHL0P6JKO: UPDATE_IN_PROGRESS (od 07:17 UTC)
  FrontendDacia/FrontendRenault: UPDATE_IN_PROGRESS — ECS backoff loop, stare taski żyją ✅
  api + backoffice: UPDATE_COMPLETE ✅
  Frontend ECS runtime: svc1/svc2 running=1, ruch serwowany ✅

WYKONANO:
  ✅ commit 9464f6c "fix(BE/dev): deploy backend child stacks only"
  ✅ push → origin master (aff7f1d..9464f6c)

CZEKA NA:
  dev-ECSStack-1BLAWHL0P6JKO → UPDATE_ROLLBACK_COMPLETE (ETA ~10:17–10:35 UTC)

NASTĘPNY KROK (po rollbacku):
  Trigger Jenkins build #1288 → weryfikacja: api+backoffice UPDATE_COMPLETE, parent/frontend NIE tknięte
```

---

## Update — 2026-05-19 — MASPEX: incydent IAM ZAMKNIĘTY ✅

```
STAN: stabilny
  PROD: 30/30 running (rev 25), steady state
  UAT:  2/2 running, steady state
  IAM policy maspex-api-execution-secrets: oba ARN-y ✅

WYKONANO (2026-05-18):
  ✅ IAM hotfix: put-role-policy → dodano PROD ARN (19:34 UTC)
  ✅ TF UAT fix: envs/uat/main.tf secret_arns + PROD ARN (commit 334353c)
  ✅ TF PROD fix: envs/prod/main.tf secret_arns + UAT ARN (commit a2bcd3a)
  ✅ oba commity na feat/campaign-day-monitoring → MR #16

ZABEZPIECZENIE:
  terraform apply z envs/prod nie usunie UAT ARN ✅
  terraform apply z envs/uat nie usunie PROD ARN ✅

POZOSTAŁY DRIFT (niski priorytet, nie blokuje):
  tag environment=uat na shared role maspex-api-execution
  → nie wpływa na ECS runtime
  → docelowy fix: rozdzielenie execution role per env (po kampanii)
```

OTWARTE — MASPEX:
  - ⚠️ CRITICAL: fix process-queue PRZED odnowieniem OpenAI quota
      (OpenAI 429 billing → infinite requeue loop, raport: process-queue-investigation-2026-05-18.md)
  - ✅ WAF admin panel PROD — ZAMKNIĘTY (commit ca12875)
  - REDIS_URL w prod Secrets Manager — do weryfikacji
  - maspex-bot unhealthy PROD + UAT — niezależny problem, >25 dni

---

## Update — 2026-05-18 — MASPEX: process-queue investigation DONE ✅

```
RAPORT: 20-projects/clients/mako/maspex/process-queue-investigation-2026-05-18.md

ROOT CAUSE (FAKT):
  OpenAI 429 billing quota exhaustion → infinite requeue loop (brak max_retries)
  20 UUID-ów × 224-228 requeue w 2h | storm aktywny od ~16:20 UTC

ALB: peak 109 Target 5xx @ 16:26 UTC | Redis: niezatknięty | ECS: 30/30 stable

OSOBNY (LOW): PostgreSQL 22P05 null byte — 5 zdarzeń, brak kaskady

KRYTYCZNA AKCJA (P1 — wykonać PRZED odnowieniem OpenAI):
  Naprawić klasyfikację HTTP 429 w process-queue:
  - 429 billing quota → dead-letter / stop (NIE requeue)
  - 429 rate limit → retry z backoff + max_retries cap
  Bez naprawy: nowe quota zostaną wyczerpane w minuty po odnowieniu
```

OTWARTE — MASPEX:
  - ⚠️ CRITICAL: fix process-queue before OpenAI quota renewal
  - WAF admin panel PROD tymczasowo otwarty (rollback po kampanii)
  - REDIS_URL w prod Secrets Manager do weryfikacji
  - maspex-bot unhealthy (PROD + UAT) — niezależny problem

---

## Update — 2026-05-18 — MASPEX: context pack + repo wyrównane ✅

```
WYKONANE:
  ✅ maspex ChatGPT context pack: _chatgpt/context-packs/maspex-full-context.md
  ✅ infra-maspex: 3 commity (cutover IaC, redis rotation script, testy-qa)
  ✅ push → origin/feat/campaign-day-monitoring
  ✅ MR #16: https://gitlab.makolab.net/admin-makolab/dc/aws-projects/infra-maspex-kapsel/-/merge_requests/16

POPRZEDNIE (też gotowe):
  ✅ dc-devops-team-vault: scripts/ + 50-patterns/prompts/ dosynchronizowane
  ✅ superpowers vault layer: plan gotowy (docs/superpowers/plans/2026-05-18-superpowers-vault-layer.md)
  ✅ rshop ChatGPT context pack: _chatgpt/context-packs/rshop-full-context.md

OTWARTE — MASPEX:
  - WAF admin panel PROD tymczasowo otwarty (rollback po kampanii: block {} w waf.tf)
  - REDIS_URL w prod Secrets Manager do weryfikacji
  - Monitoring 24h po cutoverze
  - maspex-bot unhealthy (PROD + UAT) — niezależny problem

OTWARTE — superpowers plan:
  - wykonanie planu: subagent-driven lub executing-plans (15 tasków)
```

## Update — 2026-05-18 — SUPERPOWERS VAULT LAYER: plan gotowy

```
PLAN:  docs/superpowers/plans/2026-05-18-superpowers-vault-layer.md
CEL:   _system/superpowers/ — execution/bootstrap layer dla Claude Code i Codex

15 tasków: scaffold → 5 kontraktów → SKILL-TEMPLATE → 4 bootstrapy → 10 category READMEs → 4 przykłady → integracja AGENT_BOOTSTRAP

KLUCZOWE: vault = jedyny SoT | domyślnie read-only | blast radius w frontmatter | Operator Gate (HIGH/CRITICAL) | evidence-first format

NASTĘPNE: wykonanie planu (subagent-driven lub executing-plans)
```

## Update — 2026-05-18 — dc-devops-team-vault: prompt library i scripts dosynchronizowane

```
REPO:    ~/projekty/mako/dc-devops-team-vault
BRANCH:  feature/vault-sync-model
COMMIT:  ddf5276

CO DODANO (pominięte w poprzednim sync z 2026-05-18):
  scripts/new-cloud-detective-invocation.sh
    — generator plików invocation dla nowych projektów
    — SAVE_PATH zaadaptowany: 20-projects/makolab/<project>/

  50-patterns/prompts/README.md
  50-patterns/prompts/TEMPLATES/prompt_template.md
  50-patterns/prompts/starter-pack/  (15 prompt templates)
    — cloud-detective-v2.md, ecs-alb-debug, terraform-safe-review, itp.

PRZENIESIONE (fix ścieżki):
  50-patterns/invocations/ → 50-patterns/prompts/invocations/
  (ujednolicenie z oczekiwaną ścieżką skryptu)

POMINIĘTE CELOWO:
  new-chatgpt-context.sh — prywatny (_chatgpt/ nie istnieje w team vault)

NASTĘPNE: merge feature/vault-sync-model do main (gdy gotowe)
```

## Update — 2026-05-18 — RSHOP: BE Jenkinsfile fix ✅ ⬅️

```
PROJEKT:  rshop (Renault/Dacia e-commerce)
PROFIL:   rshop / account 943111679945 / eu-central-1
REPO:     ~/projekty/mako/eshop-cicd (Jenkins pipelines)
CONTEXT:  20-projects/clients/mako/rshop/rshop-context.md

OSTATNIA SESJA (2026-05-18):
  ✅ BE Jenkinsfile fix (CFN-MUT-001 BE)
     Plik: jenkinsfiles/BE/eshop-dev-aws-scan-2.jenkinsfile
     Dev path → per-child ChangeSety (api, backoffice) zamiast parent stack
     Params obrazu: api / backoffice (potwierdzone z api-dev.yml + backoffice-dev.yml)
     Polling: waitUntil(60s) + timeout(4h) zamiast aws cloudformation wait
     Guards: parentStackId, denied resource types, empty changeSet, IN_PROGRESS
     ADR: decision-log.md ADR-004
     Stan: patch lokalny, NIEZCOMMITTOWANY, nieprzetestowany przez Jenkins

  W SESJI WCZEŚNIEJ (maspex):
  ✅ WAF kapsel-prod.makotest.pl: default_action: allow (tymczasowo)
  ✅ ECS UAT IAM drift fix: execution role miała ARN prod, naprawione terraform apply -target
  ✅ Supabase cron investigation: zapisane supabase-cron-connectivity-2026-05-18.md

NASTĘPNY KROK (rshop BE):
  git commit eshop-dev-aws-scan-2.jenkinsfile
  uruchomić dev BE pipeline → weryfikacja

BACKLOG (z session-log):
  - [ ] Cleanup: usuń stary cert 3be77743 (po 2026-05-23)
  - [ ] Cleanup: usuń orphaned cert dev.eshoprenault.lt (EXPIRED 2024-08-08)
  - [ ] CloudWatch alarm DaysToExpiry < 30 dla nowych certów
  - [ ] Zwiększyć retencję /ecs/rshop-dev z 1d na 14+ dni
  - [ ] Zbadać przyczynę ECS deploy failure przed kolejnym deployem
```

## Update — 2026-05-18 — MASPEX: twojkapsel.pl LIVE ✅

```
PROJEKT:  maspex / prod
STATUS:   LIVE od ~10:50 CEST 2026-05-18

twojkapsel.pl      → HTTP 200 ✅
www.twojkapsel.pl  → HTTP 200 ✅
test.twojkapsel.pl → HTTP 200 ✅

NASTĘPNE: monitoring 24h, opcjonalnie cleanup E17VHHQJ29MVAB (landing bez aliasow)
```

## Update — 2026-05-17 — MFS-ONBOARDING (GCP): analiza logów 24h — gotowa

```
PROJEKT:  mfs-onboarding / rci-orchestration (GCP)
CONTEXT:  20-projects/clients/mako/mfs-onboarding/mfs-onboarding-context.md
LOG ANALYSIS: 20-projects/clients/mako/mfs-onboarding/log-analysis-2026-05-17.md

VERDICT: System działa stabilnie (0 restartów, 0 błędów app, 0 OOMKilled).
         Brak evidence awarii. Krytyczna luka observability: brak HTTP access logów.

USTALENIA Z ANALIZY LOGÓW:
  🔴 Brak HTTP access logów — HAProxy loguje do syslog (nie stdout), brak sidecar
  🔴 Aktywne skanowanie exploit (ThinkPHP RCE, PHP pearcmd) dociera do podów
     — Tomcat odrzuca, ale brak WAF/ACL przed aplikacją
  🔴 Port 6060 HAProxy (stats) wystawiony na internet — potwierdzone przez TLS scan
  ✅ 3/3 pody Running, 0 restartów w 27h, CPU 2-3m, Memory 226-255Mi
  ✅ Ruch aplikacyjny: ~500 "Request logged" / 24h, szczyt 10:00 UTC (100/h)
  ✅ Brak non-Normal events w klastrze (ostatnie 24h)
  ✅ Node warnings: NodeSysctlChange (net.netfilter.nf_conntrack_acct) — niekrytyczne
  ℹ️ OpenSearch VM: RUNNING, ale brak logów OS w Cloud Logging, Fluent-bit disabled
  ℹ️ RequestFilter loguje tylko "Request logged" bez URL/status/latency

NASTĘPNE KROKI (read-only follow-up):
  1. gcloud compute target-pools get-health a6b33017894a44e3d88106baaa935ee0 --region europe-west2
  2. kubectl exec -n haproxy-controller -- cat /etc/haproxy/haproxy.cfg | grep log
  3. Sklonować repo ~/projekty/mako/mfs-orchestration (IaC niezweryfikowane)
```

## Update — 2026-05-17 — MASPEX: load test PROD — analiza gotowa, ECS wrócone do normy

```
LOAD TEST PROD — 2026-05-16 21:30–22:10 CEST — WYNIKI

RAPORT: 20-projects/clients/mako/maspex/load-test-analysis-2026-05-16-2130-cest-prod-vs-uat.md

WYNIKI:
  ✅ PROD zdał — 0 Target 5xx, 0 błędów aplikacyjnych w logach
  ✅ p99 peak = 0.277s (vs UAT 1.493s — 5.4× lepiej)
  ⚠️ Post-peak tail: 67 ELB 5xx, p99 8.7s o 21:45 CEST (connection queue overflow, nie app)
  ✅ Redis: 0 evictions, EngineCPU max 23.8%; hit rate 47–50% (niższy niż UAT 75%)

PO TEŚCIE:
  ✅ CF invalidation PROD E17VHHQJ29MVAB (twojkapsel.pl) — I90YBZJ4VCIWJPZSK6RYT9M90W InProgress
  ✅ CF invalidation PROD E34Y0KHR85VIR7 (assets.twojkapsel.pl) — IBYMFOBL6JYCUINZRRCQAVJT6F InProgress
  ✅ ECS maspex-api PROD: desired=5, min=5, max=30 (przywrócono po teście)
  ⚠️ Redis FLUSHALL PROD — NIE wykonano (czeka na potwierdzenie; Redis VPC-only, wymaga ECS exec)

REDIS FLUSHALL — jeśli potrzebny:
  Cluster: maspex-prod.zwowz5.0001.euw1.cache.amazonaws.com:6379
  Dostęp: ECS exec na running maspex-api task
```

## Update — 2026-05-16 — MASPEX: mail assets CDN — LIVE ✅ Czeka na finalny CNAME

```
REPO:   ~/projekty/mako/aws-projects/infra-maspex (branch: feat/campaign-day-monitoring, commit: a6661d0)

STAN:
  ✅ S3 bucket maspex-mail-assets-969209893152 — LIVE (eu-west-1)
  ✅ OAC maspex-mail-assets (E2RWD7KYG4EO5T) — LIVE
  ✅ 9 assetów w s3://maspex-mail-assets-969209893152/email/
  ✅ CloudFront E34Y0KHR85VIR7 — LIVE (d3muxmyhrve6og.cloudfront.net)
  ✅ Bucket policy — zastosowana (AllowCloudFrontOAC)
  ✅ CF invalidation IBBMQ8QFJHR922X6W9P1MVGLOW — /email/* InProgress
  ⏳ ACM assets.twojkapsel.pl — ISSUED
  ⏳ ACM auth.twojkapsel.pl — PENDING_VALIDATION

NASTĘPNY KROK — DNS CNAME finalny (u rejestratora twojkapsel.pl):
  Name:  assets.twojkapsel.pl
  Type:  CNAME
  Value: d3muxmyhrve6og.cloudfront.net

UWAGA — pre-existing issue (niezwiązany z tym PR):
  full plan pokazuje 3 destroys CloudWatch log groups /maspex/shared/*
  Używaj -target dopóki nie rozstrzygniesz log groups issue

OPEN ITEM poza IaC: app templates muszą używać EMAIL_ASSETS_BASE_URL
  base_url: https://assets.twojkapsel.pl
```

## Update — 2026-05-16 — MASPEX: IaC mail assets CDN — gotowe do apply (poprzedni stan, zastąpiony powyżej)

```
REPO:   ~/projekty/mako/aws-projects/infra-maspex (branch: analysis/maspex-load-test-2026-05-11)
ZMIANY: terraform/envs/shared/ (4 modified + 1 new file, niezcommitowane)

CO ZROBIONO (IaC only, bez app code):
  ✅ shared/providers.tf — dodany provider alias aws.us_east_1
  ✅ shared/variables.tf — mail_assets_domain + mail_assets_cf_certificate_arn
  ✅ shared/terraform.tfvars — wartości z placeholderem ARN cert
  ✅ shared/mail-assets.tf — S3 bucket + OAC + bucket policy + CloudFront module
  ✅ shared/outputs.tf — mail_assets_bucket_name, cloudfront_domain, distribution_id, base_url
  ✅ terraform fmt -check: PASS
  ✅ terraform validate: SUCCESS

PREREQ DO APPLY (blokuje):
  1. awsume maspex + request-certificate assets.twojkapsel.pl w us-east-1
  2. Dodaj DNS CNAME walidacyjny, poczekaj na ISSUED
  3. Podmień mail_assets_cf_certificate_arn w terraform.tfvars
  4. terraform init -backend-config=backend.hcl
  5. terraform plan → terraform apply

OPEN ITEM (poza IaC):
  App code musi dostać EMAIL_ASSETS_BASE_URL — dziś maile nadal używają NEXT_PUBLIC_SITE_URL
  Pełny plan: 20-projects/clients/mako/maspex/mail-assets-migration-plan.md

TARGET URL: https://assets.twojkapsel.pl/email/<plik>.png
```


## Update — 2026-05-15 — MASPEX: PROD parity — APPLIED ✅

```
REPO:   ~/projekty/mako/aws-projects/infra-maspex (branch: feat/campaign-day-monitoring)
COMMIT: 7511067

WYNIK (3 add, 7 change, 3 destroyed):
  ✅ TD families PROD: maspex-prod-api:1, maspex-prod-admin-panel:1, maspex-prod-bot:1
  ✅ IAM role tags fix: environment uat→prod (6 ról)
  ✅ IAM exec_secrets policy: UAT→PROD secret ARN
  ✅ SUPABASE_JWT_SECRET ustawiony w maspex/prod/api (88 znaków, PROD JWT)
  ✅ ECS services PROD NIEZMIENIONE — brak restartu kontenerów

SERWISY PROD teraz wskazują stare TDs — pipeline deploy podepnie maspex-prod-* przy następnym release.

OTWARTE:
  ❓ Certy caed9d07/d4bbfef0 (test.twojkapsel.pl) — decyzja czy PROD migruje na tę domenę
  Bot PROD 0/1 — brak tokenu, osobna kwestia
```

---

## Update — 2026-05-15 — MASPEX: PROD parity — plan gotowy, czeka na decyzje operatora

```
REPO:   ~/projekty/mako/aws-projects/infra-maspex (branch: feat/campaign-day-monitoring)
PLAN:   /tmp/prod-parity.tfplan (3 add, 7 change, 3 destroy)

ZROBIONE:
  ✅ moduł ecs-service: nowa var task_definition_name (backward-compat, default "")
  ✅ prod/main.tf: task_definition_name dla 3 serwisów → maspex-prod-api/admin-panel/bot
  ✅ terraform fmt + validate OK | plan OK
  plan NIE apply — blokery poniżej

PLAN EFFEKTY:
  3× replace aws_ecs_task_definition (family prod-*) — ECS service NIEZMIENIONY (ignore_changes)
  6× in-place IAM role tag fix (environment: uat→prod)
  1× in-place IAM exec_secrets policy (UAT→PROD secret ARN)

BLOKERY PRZED apply:
  ⛔ secret maspex/prod/api: SUPABASE_JWT_SECRET PUSTE → aplikacja PROD nie waliduje tokenów
     → potrzebna wartość z Supabase PROD dashboard (Project Settings → API → JWT Secret)
  ❓ certy z zadania (caed9d07 / d4bbfef0) pokrywają test.twojkapsel.pl, NIE kapsel-prod.makotest.pl
     → decyzja: czy PROD teraz migruje na test.twojkapsel.pl?

PYTANIA DO OPERATORA:
  1. SUPABASE_JWT_SECRET dla PROD (Supabase PROD project → Settings → API → JWT Secret)
  2. Czy PROD migruje na test.twojkapsel.pl (nowe certy)?
  3. Approve plan do apply?
  4. Opcjonalnie: zsynchronizować image tags w tfvars PROD?
     (live: coreapp-prod-657, admin-panel-prod-130, maspex-worker-uat-61)
```

---

## Update — 2026-05-15 — MASPEX: Zasłepka twojkapsel.pl — wdrożona + przełączamy na PROD

```
REPO:   ~/projekty/mako/aws-projects/infra-maspex (branch: feat/campaign-day-monitoring)
COMMIT: e8230ea

ZROBIONE:
  ✅ nowy index.html + PDF → S3 maspex-preprod-zaslepka-969209893152
  ✅ GTM bezwarunkowy usunięty → cookie banner GDPR-compliant (jak v11)
  ✅ CloudFront invalidation Completed (E17VHHQJ29MVAB)
  ✅ Fix PDF case: instrukcja (lowercase) + Instrukcja (uppercase) — oba w S3
  twojkapsel.pl DZIAŁA (200 w logach od 14:06 CEST)

NASTĘPNY KROK: → PROD
```

---

## Update — 2026-05-15 — MASPEX: Load test 12:00 CEST — analiza zakończona, P0 otwarte

```
REPO:   ~/projekty/mako/aws-projects/infra-maspex
STATUS: test zakończony, infrastruktura posprzątana (fleet stopped, WAF cleared)

WYNIKI TESTU (12:00–12:30 CEST):
  Verdict: CZĘŚCIOWO PASS — znacząca poprawa vs 14 maja
  Peak: 8 835 req/s | p99 latency: 1.49 s (poprzednio ~30 s) | ELB 5xx: 160 (vs 722)
  Autoscaling: 12→30 tasków o 12:24:48 (pierwsza skuteczna reakcja)
  JWT fix (SUPABASE_JWT_SECRET): 0 błędów autoryzacji podczas testu ✅
  Redis: stabilny (EngineCPU max 25.6%, 0 Evictions, hit rate 74–75%)

P0 PRZED KOLEJNYM TESTEM:
  ⛔ synthetic test users nie mają wierszy w Supabase `profiles` → 118 VOTE_RPC_ERROR
     users: user-test-uat-10001@example.com ... sub: 00000000-...-00010001
     FIX: seed profiles table w Supabase UAT
  ⛔ max capacity = 30 (osiągnięte) → przed kampanią podnieść do 50+

DO ZROBIENIA (Łukasz Fuchs / Maspex):
  ⚠️ Maspex chce testować przed 18 maja — potrzebują IP do WAF allowlist
     WAF name: maspex-uat-public-uat-allowlist
     Plik: terraform/envs/uat/terraform.tfvars → public_uat_extra_allowed_ipv4_cidrs
     Czeka: Maspex podaje swoje IP

VAULT: 20-projects/clients/mako/maspex/load-test-analysis-2026-05-15-1200-cest.md
```

---

## Update — 2026-05-15 — MASPEX: ECS SG drift fix + UAT recovery + secrets fix

```
REPO:   ~/projekty/mako/aws-projects/infra-maspex
BRANCH: feat/campaign-day-monitoring (commit: 186890c)

ZROBIONE:
  ✅ ECS SG drift fix — PROD ma własne SG (maspex-prod-*-ecs), UAT swoje (maspex-*-ecs)
     brak ryzyka kolizji przy kolejnym apply z obu środowisk
  ✅ SUPABASE_JWT_SECRET naprawiony w maspex/uat/api — 0 błędów JWT podczas testu
  ✅ loadtest-fleet-start.sh — WAF_IP_SET_NAME fix (było prod-, jest uat-)
  ✅ api-secrets.md — vault: udokumentowane wymagane sekrety z objawami braku

STAN TF:
  UAT: czysty (sprawdzony po apply o 11:xx CEST)
  PROD: czysty (Enhanced CI + 3 alarmy + dashboard apply z 2026-05-15 rano)
```

---

## Update — 2026-05-12 — PUZZLER-B2B: QA notifier fix + config audit + RSHOP: FE Jenkinsfiles

```
PUZZLER-B2B:
  REPO: ~/projekty/mako/aws-projects/infra-puzzler-b2b-final
  REPO: ~/projekty/mako/pbms-backend (branch: dev)

  ✅ QA notifier DOWN → naprawiony
     - Root cause: SM secret infra-puzzler-b2b/qa/docdb brakował connection_string_notifier
     - Task def rev 27 wdrożony 11:15 przez CI/CD (notifier-api-qa-156) — klucz w SM nie istniał
     - Fix: put-secret-value + force-new-deployment → steady state 1/1
     - TF był już aktualny (ignore_changes blokowało sync przy initial create bez klucza)

  ✅ Config audit DEV+QA (AzureAd + ExternalDashboardApi):
     - AzureAd DEV+QA: SM infra-puzzler-b2b/{env}/azuread — zgodne ✅
     - ExternalDashboardApi DEV: appsettings.DEV.json — zgodne ✅
     - ExternalDashboardApi QA: MISSING z appsettings.QA.json → dodane
     - commit: 478d5694 (pbms-backend dev), pushed
     - Runtime nie wymaga redeploya (wartości były już poprawne przez fallback z base)

RSHOP FE JENKINSFILES:
  REPO: ~/projekty/mako/eshop-cicd (branch: master)

  ✅ r-shop-all.jenkinsfile — naprawiony (poprzednia sesja, commit: d4c5b77)
  ✅ r-shop-all-dev-scan.jenkinsfile — naprawiony (commit: ef565fb)
     - Oba: CfnStackName = dev-ECSStack-1BLAWHL0P6JKO, preflight gate, change-set guard

STAN QA (2026-05-12 ~12:30):
  8/9 serwisów 1/1, worker 0/0 (intentional) — wszystko OK
  DocumentDB: available, ALB: healthy
```

---

## Update — 2026-05-14 — MASPEX: Enhanced Container Insights — IaC gotowe, czeka na apply

```
REPO:  ~/projekty/mako/aws-projects/infra-maspex
PLIK:  terraform/envs/uat/main.tf

ODKRYCIA:
  - Standard Container Insights: WŁĄCZONE (value=enabled, potwierdzone --include SETTINGS)
  - Per-task granularity: BRAK (tylko agregaty serwisowe — to dlatego max=96% ale nie wiemy który task)
  - Enhanced CI: zmienia to — dodaje dimension TaskId do CpuUtilized/MemoryUtilized

IaC ZMIANA (gotowe, czeka na terraform apply):
  module "ecs_cluster" { container_insights = "enhanced" }
  TYLKO UAT — prod i preprod bez zmian

NASTĘPNY KROK:
  cd ~/projekty/mako/aws-projects/infra-maspex/terraform/envs/uat
  terraform plan -target=module.ecs_cluster
  terraform apply -target=module.ecs_cluster

  Weryfikacja po apply:
  aws ecs describe-clusters --clusters maspex-uat --include SETTINGS --profile maspex-cli --region eu-west-1

VAULT: 20-projects/clients/mako/maspex/enhanced-container-insights-uat.md
```

---

## Update — 2026-05-14 — MASPEX: Load test walidacyjny pre-scale — ZAKOŃCZONY

```
REPO:   ~/projekty/mako/aws-projects/infra-maspex
STATUS: testy zakończone, infrastruktura posprzątana

ZROBIONE (wieczór 21:46–22:24 CEST):
  ✅ Bug fix: loadtest-ctrl.sh — info()/ok()/warn() → stderr (fix WAF ANSI injection)
  ✅ Pre-scale ECS: min=9→15, desired=15 (steady w 16s)
  ✅ Level A (3,000 req/s): 8 min, 0.00% errors, pre-scale=15 → 200 req/s/task (vs 333 bez pre-scale)
     - Autoscaling: 15→18→19→20 tasks (cascade, 6.5 min opóźnienie)
  ✅ Level B (4,500 req/s): 8 min, 0.00% errors, pre-scale=20 → 225 req/s/task
     - 270,000 req/min steady, latencja bez zmiany (~8ms avg)
  ✅ Fleet stopped, WAF cleared, autoscaling min przywrócony do 9

WYNIKI:
  Pre-scale POTWIERDZA eliminację incident zone przy 3,000 req/s
  Pre-scale=15 działa dla 2,500 req/s; dla 3,000+ → pre-scale=18–20
  System stabilny przy 4,500 req/s z max capacity (20 tasks), 0 błędów

ECS STAN (scale-in w toku ~80-90 min):
  desired=20, running=20, min=9 → scale-in stopniowy

VAULT: 20-projects/clients/mako/maspex/loadtest-prescale-validation-2026-05-14.md
```

---

## Update — 2026-05-14 — MASPEX: Kalibracja autoscalingu (rano)

```
VAULT: 20-projects/clients/mako/maspex/loadtest-calibration-results-2026-05-14.md
WYNIK: WORKING_BUT_TOO_LATE — mechanizm działa, ALE 5.5 min delay na scale-out
  Pre-scaling operacyjny KONIECZNY przed spodziewanym ruchem
```

---

## Update — 2026-05-14 — MASPEX: k6/InfluxDB/Grafana pipeline naprawiony + PROD parity

```
REPO:   ~/projekty/mako/aws-projects/infra-maspex
BRANCH: feat/prod-parity-uat, commit: 0b0ec3b

ZROBIONE:
  ✅ k6/InfluxDB/Grafana pipeline — naprawiony na obu instancjach
     - docker-compose.yml: INFLUXDB_DB=k6, named volumes, provisioning mounts
     - Grafana datasource + dashboard provisjonowane z plików (nie z UI)
     - Instancja 1 (3.249.179.8): zaktualizowana, data preserved
     - Instancja 2 (34.242.87.83): zainstalowana od zera (nie miała docker-compose)
     - Pliki wersjonowane: scripts/loadtest/ w repo (commit 0b0ec3b)
  ✅ PROD parity — cert ARNs + REDIS_URL + api_domain
     - alb_certificate_arn: a139f9a4 (kapsel-prod.makotest.pl, ISSUED)
     - alb_api_certificate_arn: fd2f0c7c (kapsel-api-prod.makotest.pl, ISSUED)
     - api_domain: kapsel-api-prod.makotest.pl (był kapsel-api.prod — niezgodne z certem)
     - REDIS_URL zamiast ConnectionStrings__Redis w secrets (jak UAT)

URUCHAMIANIE k6 Z TELEMETRIĄ:
  K6_OUT=influxdb=http://localhost:8086/k6 k6 run scripts/kapsel.js

GRAFANA (SSM port-forwarding na :3000):
  aws ssm start-session --target i-0402c9e70c6a86ae3 \
    --document-name AWS-StartPortForwardingSession \
    --parameters '{"portNumber":["3000"],"localPortNumber":["3000"]}' \
    --region eu-west-1 --profile maspex-cli
  → http://localhost:3000 (anonymous Admin)

BLOKERY PROD APPLY (wciąż otwarte):
  ⛔ api_redis_secret_arn — secret maspex/prod/api nie istnieje w SM
  ⛔ api/admin_panel/bot_image_tag — ustawić właściwe tagi prod

BRANCHES (lokalne, nie pushed):
  feat/prod-parity-uat  ← aktywny

OTWARTE (load test scripts):
  → loadtest-fleet-clear.sh (CF invalidation + ElastiCache PROD) — do napisania
  → loadtest-fleet-*.ps1 — brak PowerShell odpowiedników
  → --ssh w fleet scripts — brak helpera

VAULT: 20-projects/clients/mako/maspex/loadtest-observability.md
```

---

## Update — 2026-05-09 — LLZ: Phase 1 correction — GLPI usuniete z slo-alerts

```
BRANCH: feature/observability-routing-cleanup-phase1 (pushed)
REPO:   ~/projekty/mako/aws-projects/aws-cloud-platform
COMMIT: f1d0eb0

CO ZROBIONO:
  ✅ Usunieto glpi@infra.makolab.pl z slo_notification_emails (terraform.tfvars)
  ✅ terraform plan: 0 add, 0 change, 1 destroy (subscription glpi@)
  ✅ Commit f1d0eb0 pushed
  ✅ Vault: observability-architecture-confluence.md zaktualizowany

STAN SUBS slo-alerts SNS (po apply):
  jaroslaw.golab@makolab.com  — zostaje
  glpi@infra.makolab.pl       — USUNIETE (bylo pending_confirmation=true)

APPLY COMMAND:
  cd ~/projekty/mako/aws-projects/aws-cloud-platform/platform/monitoring
  AWS_PROFILE=mako-dc terraform apply tfplan.monitoring

WERYFIKACJA:
  AWS_PROFILE=monitoring-tbd aws sns list-subscriptions-by-topic \
    --topic-arn arn:aws:sns:eu-central-1:814662658531:slo-alerts \
    --region eu-central-1 --query "Subscriptions[].Endpoint" --output text

AWS HEALTH → GLPI: bez zmian (health-notifications topic — nie tkniety)
SLO ALARMY: bez zmian (8 alarmow, tylko routing email)
```

---

## Update — 2026-05-09 — MASPEX: load test infra KOMPLETNA, MR pushed (8 commitów) ✅

```
BRANCH: fix/uat-loadtest-docker-compose-plugin (pushed, MR otwarty, 8 commitów)
REPO:   ~/projekty/mako/aws-projects/infra-maspex

CO ZROBIONO (cała sesja):
  ✅ Docker Compose v2 plugin — naprawiony w IaC + na żywych instancjach (SSM)
  ✅ Symlink /usr/local/bin/docker-compose → v2 plugin (legacy docker-compose działa)
  ✅ Discovery WAF: blokada kapsel.makotest.pl = WAFv2 CloudFront IP Set, NIE Security Group
  ✅ Nowy WAF IP Set maspex-uat-loadtest-allowlist — Terraform applied
  ✅ loadtest-ctrl.ps1: --run dopisuje IP do WAF, --stop czyści (Clear niezależny od instancji)
  ✅ PS5.1 syntax fix: )) parser bug + apostrof
  ✅ Scheduler fix: Clear-LoadTestAllowList działa też gdy maszyny ubite o 19:00
  ✅ IAM fix: makolab-qa dostał wafv2:GetIPSet + UpdateIPSet — applied + IAM Simulator ✅
  ✅ JSON quoting fix: ConvertTo-Json → ręczny join (PS5.1 + aws CLI quote stripping)
  ✅ SG: otwarto port 3000 (Grafana) + 8086 (InfluxDB) z biurowych IP — applied
  ✅ loadtest-ctrl.sh: macOS bash — pełna paryteta z PS1 (WAF automation, jq JSON)
  ✅ Commit ae39b3a pushed

SKALOWANIE FLOTY (trzy miejsca — muszą być spójne):
  loadtest.tf:       max_size + desired_capacity w aws_autoscaling_group
  loadtest-ctrl.ps1: $DesiredCapacityRun + $MaxSizeRun
  loadtest-ctrl.sh:  DESIRED_CAPACITY_RUN + MAX_SIZE_RUN

NASTĘPNE KROKI:
  → Merge MR po weryfikacji dewelopera
  → Test end-to-end: --run → curl kapsel.makotest.pl → 200, --stop → 403
```

---

## Update — 2026-05-09 — AKTYWNY PROJEKT: MASPEX

```
LLZ ZAMKNIĘTE NA DZIŚ (branch: feature/observability-routing-cleanup-phase1):
  ✅ Phase 1 applied: Health pattern, SLO routing, MQ retention, dead SNS cleanup
  ✅ Architektura docs: docs/architecture/observability-monitoring-architecture.md
  ✅ Confluence copy: 20-projects/internal/llz/observability-architecture-confluence.md
  ⚠️  Manual cleanup pending: org-cloudwatch-alarms-to-sns + org-central-alarms (management account)
  → Phase 2 next: Security routing (GD/SH → GLPI), ECS/RDS alarms, shadow sink

PRZEŁĄCZENIE NA: MASPEX
```

---

## Update — 2026-05-09 sesja 2 — dc-anonymizer: MR PUSHED, gotowy do merge ✅

```
AKTYWNY BRANCH: feature/tfplan-polish-ui-docs (13 commitów)
REPO: ~/projekty/mako/aws-projects/dc-anonimizator
MR: pushed — GitLab (link w session-log)

STATUS KOŃCOWY:
  ✅ sample.tfplan.txt fixture (52 detekcje, CLEAN)
  ✅ Protected terms filter (KF-005 fixed — API != ORGANIZATION)
  ✅ .tfplan/.tfstate support (upload + router + regression tests)
  ✅ Polish UI (wszystkie stringi przetłumaczone)
  ✅ Demo UX: banner, expander, quick-load buttons, footer
  ✅ Docs PL: instrukcja-instalacji, instrukcja-uzycia, demo-scenariusze, faq
  ✅ README.md + demo/README.md — pełna polonizacja
  ✅ Dokumentacja rehydratacji — wymagania, ograniczenia, 6-krokowy workflow
  ✅ make test: 43 passed, 5 skipped, 6 xfailed
  ✅ make smoke: PASSED (anonymize + rehydrate round-trip)
  ✅ make demo: starts on localhost:8502

NASTĘPNE ZADANIE:
  → Review i merge MR feature/tfplan-polish-ui-docs
  → Demo dla Tomasza (quick-load: Terraform plan)
  → Fix KF-001 (S3 ARN) lub KF-003 (email .internal) — po merge
```

---

## Update — 2026-05-08 sesja 4 — Governance UI Refactor PR SUBMITTED ✅

```
AKTYWNY BRANCH: feat/governance-ui-findings-first (8 commitów ahead of main)
REPO: ~/projekty/devops/devops-toolkit
PR: #62 (open) — https://github.com/JarekGie/devops-toolkit/pull/62

GOVERNANCE UI STATUS (findings-first UX):
  ✅ Task 0 — plan gotowy (docs/superpowers/plans/2026-05-08-governance-ui-findings-first.md)
  ✅ Task 1 — CSS classes (finding cards, severity badges, summary panel)
  ✅ Task 2 — HTML restructure (findings-first layout, ID-compatible)
  ✅ Task 3 — renderGovernanceFindingCard + renderGovernanceSummaryPanel (bez resource_id)
  ✅ Task 4 — findings-first render: severity sort, FAILED banner, summary wiring
  ✅ Task 5 — exec panel hidden on governance tab, Show/Hide toggle
  ✅ Task 6 — clickable mini-runs z per-run findings loading (run_id param)
  ✅ Task 7 — full regression check: 133 tests PASS, +70 nowych, 0 regresji

TESTY:
  133 governance tests passing
  Gałąź: 3924 pass / 291 fail (291 = pre-existing na main, identyczne)

NASTĘPNE ZADANIE: review PR #62, merge do main
```

---

## Update — 2026-05-08 sesja 3 — devops-toolkit governance P2+P3 DONE ✅

```
AKTYWNY BRANCH: feat/finops-sanitizer (off main b983a6a)
REPO: ~/projekty/devops/devops-toolkit

GOVERNANCE STATUS:
  ✅ P0/P1 — collectors (Organizations, IAM, CloudTrail) — merged
  ✅ P2 — root-governance plugin (GOV-ROOT-001..005) — merged fc8c096
  ✅ P3 — scp-governance plugin (GOV-SCP-001..004) — merged b983a6a (#60)
  ⛔ P4 drift organizations — wykluczone
  ⛔ P5 break-glass status — wykluczone
  ⛔ P6 UI — wykluczone

NASTĘPNE ZADANIE: TBD na branchu feat/finops-sanitizer
  - Sprawdzić next-steps.md — część pozycji może być stale (finops sanitizer i cost norm. były zrobione wcześniej)
  - Potencjalny kandydat: ALB scaffold fix (test_init_project.py:1396) — jedyny potwierdzony otwarty dług
```

---

## Update — 2026-05-08 — rshop cert ✅ ZAMKNIĘTE + 2 otwarte wątki

### 0. rshop cert `*.skleprenault.pl` — ZMIGROWANY ✅

```
ZROBIONE (2026-05-08 ~13:50):
  ✅ Nowy cert wydany: arn:.../72123357-5a77-4b60-84b1-f59e5282270e
     NotAfter: 2026-11-22 | Status: ISSUED | 7 SANów (bez .hu)
  ✅ CF E3LC30816FMUSK: zaktualizowany → nowy cert, 12 aliasów (usunięto 4 dead HU)
  ✅ TLS zweryfikowany openssl dla 5 SNI aliasów → CN=*.skleprenault.pl 2026-11-22
  ✅ Stary cert (3be77743) NIE usunięty → rollback gotowy do 2026-05-13

CLEANUP (2026-05-23 lub później):
  [ ] Usuń stary cert 3be77743-... (wygasł, InUseBy=[])
  [ ] Usuń orphaned cert dev.eshoprenault.lt (173ae59f, EXPIRED 2024-08-08)
  [ ] Dodaj CloudWatch alarm DaysToExpiry < 30 dla nowego certu

Dokumentacja: 20-projects/clients/mako/rshop/acm-cert-migration-2026-05-08.md
```

### 1. rshop dev — RCA ECS deploy failure 2026-05-08 (ZAMKNIĘTE)

```
Stan: rollback automatyczny ✅, serwisy zdrowe
RCA: 20-projects/clients/mako/rshop/rca-ecs-deploy-failure-2026-05-08.md
Root cause: ECS nie ustabilizował nowych kontenerów (nieznana przyczyna — logi niedostępne)
ValidationError: symptom wtórny — Jenkins concurrent deploy podczas UPDATE_IN_PROGRESS

DO ZROBIENIA:
  [ ] Zbadać przyczynę nieudanej stabilizacji zanim nowy deploy dev
  [ ] Dodać preflight check stanu stacka w Jenkins (P0)
  [ ] Zwiększyć retencję /ecs/rshop-dev z 1 dnia na 14+ dni (P0)
```

## Update — 2026-05-08 sesja 2 — Maspex UAT ZAMKNIĘTE ✅

### 1. Maspex UAT — Redis + WAF — ZROBIONE ✅

```
STAN AKTUALNY (2026-05-08 ~14:30):

  Secret maspex/uat/api:
    ✅ PRZYWRÓCONY do ElastiCache:
       redis://maspex-uat.zwowz5.0001.euw1.cache.amazonaws.com:6379
       (eksperymentalny ELB Redis z sesji 1 — cofnięty)

  Task definition maspex-api:58 (Terraform commit 249e618):
    ✅ NAPRAWIONY: secret wstrzykiwany jako REDIS_URL (było: ConnectionStrings__Redis)
    ✅ Force-new-deployment → 9/9 running, Ready in 129ms, brak błędów Redis

  WAF maspex-uat-public-uat-allowlist (Terraform commit b87c415):
    ✅ Dodano IPv6 IP set maspex-uat-supabase-ipv6:
       2a05:d018:135e:16df:624:8d0e:2886:f540/128
    ✅ Reguła allow-supabase-ipv6 (P1) → Supabase pg_net przechodzi
    ✅ Sampled requests 14:26+ = ALLOW dla /api/cron/* i /api/email/process-outbox

REDIS STATE CHECK (sesja 3):
  ✅ ElastiCache: 3592 kluczy, wszystkie z TTL, 1.76M commands — zdrowy i aktywny
  ✅ Experimental ECS Redis: 0 kluczy, idle — nigdy nie był używany przez app
  ✅ Cache end-to-end działa po naprawie REDIS_URL (maspex-api:58)

LOAD TEST INFRA (sesja 4) — wdrożone ✅:
  ✅ ASG maspex-uat-loadtest: 2/2 InService, c6i.4xlarge
  ✅ Docker 25.0.14 + k6 v2.0.0-rc1 zainstalowane via SSM
  ✅ SSM Online na obu maszynach

LOAD TEST INFRA (sesja 5) — SSH + skrypty + IAM ✅:
  ✅ SSH keys: jarosław + karol + mateusz.kmiecik — potwierdzone live via SSM
  ✅ Instancje po refreshie: i-00b4dd5a06af19a7f (3.251.67.108), i-085842e07c2614a39 (3.248.207.255) — LT v4
  ✅ Auto-shutdown 19:00 Warsaw time (aws_autoscaling_schedule, time_zone=Europe/Warsaw)
  ✅ scripts/loadtest-ctrl.sh (macOS) + scripts/loadtest-ctrl.ps1 (Windows)
     --run | --stop | --clear | --ssh
  ✅ makolab-qa: AdminAccess → maspex-uat-loadtest-operator (least-privilege, 6 akcji)

PRZED PIERWSZYM TESTEM:
  [ ] WAF: dodać IPs generatorów do public_uat_extra_allowed_ipv4_cidrs
      UWAGA: IPs zmieniają się przy każdym --run → rozważyć ALB direct zamiast CF
      ALB: http://maspex-uat-1361582173.eu-west-1.elb.amazonaws.com + Host: kapsel.makotest.pl

OTWARTE (legacy):
  [ ] preprod/prod: ten sam błąd ConnectionStrings__Redis → REDIS_URL (nie naprawione)
  [ ] WAF: jeśli Supabase zmieni IPv6, blokada wróci — docelowo: custom header (Wariant C)
  [ ] Drift aws_ecs_service.redis :3→:2 w Terraform state — osobna sprawa

Logi/historia: 20-projects/clients/mako/maspex/session-log.md
```

### 2. devops-toolkit Governance Foundation P0/P1 — ZROBIONE ✅

```
Branch: feat/governance-foundation-p0-p1 (pushed)
Repo: ~/projekty/devops/devops-toolkit
33 testów, 0 failures, contract-check PASS, lint PASS

ZROBIONE (Tasks 1–10):
  ✅ Package infra: collectors/aws/{organizations,iam,cloudtrail} jako Python package
  ✅ Fixtury: 10 plików JSON/CSV (organizations, IAM, CloudTrail)
  ✅ OrganizationsCollector: collect_accounts, collect_ou_tree, check_management_account
  ✅ SCPCollector: collect_policies, collect_targets, describe_policy, collect_policies_for_target
  ✅ CredentialReportCollector: generate_report, get_report, generate_and_wait, parse, get_root_row
  ✅ CloudTrailLookupCollector: lookup_root_events, lookup_move_account_events (graceful degradation)
  ✅ Docs: docs/operator/governance-audit.md + docs/architecture/governance-commands.md
  ✅ Weryfikacja: 33/33 tests, contract-check PASS, lint PASS, branch pushed

NASTĘPNA FAZA: P2 — Plugin root-governance + pack governance-root
```

## Update — 2026-05-07 — SNS/GLPI routing: sesja zamknięta ✅

```
Repo: aws-cloud-platform (main, pushed, commit 1b492e7)

STAN SNS — monitoring-nagios-bot (814662658531):

  health-notifications (eu-central-1)
    → glpi@infra.makolab.pl       ✅ confirmed
    → jaroslaw.golab@makolab.com  ✅ confirmed (dodany na końcu sesji)
    Źródło: Lambda health-notify (AWS Health issue/investigation/open)
    Terraform: platform/health-notifications

  cloudwatch-alarms-glpi (eu-central-1)   ← NOWY
    → glpi@infra.makolab.pl       ✅ confirmed
    ARN: arn:aws:sns:eu-central-1:814662658531:cloudwatch-alarms-glpi
    Przeznaczenie: CloudWatch ALARM → GLPI (tylko alarmy świadomie przypięte)
    Terraform: platform/health-notifications
    Żaden alarm jeszcze nie jest wired do tego topiku.

  health-ops-alerts (us-east-1)
    → jaroslaw.golab@makolab.com  ✅ confirmed
    Źródło: 5 pipeline alarmów (Lambda errors, DLQ, EventBridge failures)
    Terraform: platform/health-notifications

  slo-alerts (eu-central-1)
    → jaroslaw.golab@makolab.com  ✅ confirmed
    Źródło: 8 SLO alarmów (error rate, latency p99) dla rshop/booking/dacia/bbmt-uat
    Terraform: platform/monitoring
    UWAGA: platform/monitoring/terraform.tfvars odtworzony lokalnie
           slo_notification_emails = ["jaroslaw.golab@makolab.com"]

ZROBIONE W TEJ SESJI:
  ✅ health_notification_emails / ops_alert_emails — rozdzielone zmienne
  ✅ health-eventbridge-dlq SQS + DLQ config na 13 EventBridge targets
  ✅ cloudwatch-alarms-glpi topic stworzony + subskrypcja GLPI potwierdzona
  ✅ jaroslaw.golab@makolab.com dodany do health-notifications
  ✅ platform/monitoring/terraform.tfvars odtworzony (slo sub zabezpieczona)
  ✅ SNS audit raport: docs/audits/sns-topics-monitoring-nagios-bot-2026-05-07.md
  ✅ ChatGPT context pack: _chatgpt/context-packs/aws-glpi-integration.md

NASTĘPNY KROK (wiring CloudWatch alarmów do GLPI):
  [ ] Zdecydować które alarmy → cloudwatch-alarms-glpi
      Kandydaci: SLO breach? budgets? security findings?
  [ ] Wired alarm_actions w platform/monitoring/alarms.tf
  [ ] Opcjonalnie: scheduledChange → health-notifications lub osobny topic
```

## Update — 2026-05-07 — aws-cloud-platform: break-glass framework gotowy

```
Nowe dokumenty:
  20-projects/clients/mako/aws-cloud-platform/break-glass-framework.md
  40-runbooks/aws/break-glass-ou-move.md

Następny krok (priorytet 1):
  terraform apply — Break-Glass OU (organizations/break-glass/)
  MFA enrollment — 9 kont (użyć Recovery OU zamiast SCP modification)
  Security Hub + GuardDuty włączyć
```

## Update — 2026-05-07 — aws-cloud-platform: postmortem gotowy, sesja zamknięta

```
Vault:  20-projects/clients/mako/aws-cloud-platform/root-governance-postmortem.md
Stan:   sesja root MFA remediation zakończona

Wynik:
  Email:  10/12 ACTIVE na infra.makolab.pl ✅ (2 konta: accepted state)
  MFA:    3/12 ACTIVE ✅ — 9 kont wymaga enrollment
  Keys:   0/12 root access keys ✅
  SCP:    przywrócony ✅

Następny krok (priorytet 1):
  MFA enrollment — 9 kont (maintenance window Option B, target ~2026-05-14)
  Security Hub + GuardDuty włączyć
  Recovery OU permanentny (Terraform)
```

## Update — 2026-05-07 — aws-cloud-platform: SCP rollback ✅ — MFA pending

```
SCP:    llz-security-baseline (p-8wat7tjs) — PRZYWRÓCONY do pełnego DenyRootUserActions
Stan:   maintenance window ZAMKNIĘTY 2026-05-07
Email:  10/12 ACTIVE kont ma infra.makolab.pl

Email do zmiany (ACTIVE):
  [ ] makolab_dc (864277686382)           — dc@makolab.com → aws-makolabdc@infra.makolab.pl
  [ ] monitoring-nagios-bot (814662658531) — aws@makolab.pl → aws-monitoring@infra.makolab.pl

MFA do enrollment (9 kont — wymaga kolejnego maintenance window):
  [ ] LogArchiveNew (771354139056)
  [ ] planodkupow (333320664022)
  [ ] planodkupowv1 (292464762806)
  [ ] Booking_Online (128264038676)
  [ ] RShop (943111679945)
  [ ] dacia-asystent (074412166613)
  [ ] CC (943696080604)
  [ ] DRP-TFS (613448424242)
  [ ] lab (052845428574)
```

## Update — 2026-05-07 — aws-cloud-platform: root MFA discovery ZAKOŃCZONE

```
Projekt:  mako / aws-cloud-platform
Operacja: Root MFA Recovery & Remediation — discovery live 2026-05-07
Vault:    20-projects/clients/mako/aws-cloud-platform/root-mfa-recovery-plan.md

WYNIKI DISCOVERY:
  ✅ MFA OK (3 konta): makolab_dc, Admin MakoLab, monitoring-nagios-bot
  ❌ MFA brak (9 kont): LogArchiveNew + 8x Workloads/NonProd/Sandbox
  ✅ Brak root access keys w całej org

KRYTYCZNY BLOKER:
  SCP llz-security-baseline (p-8wat7tjs) DenyRootUserActions blokuje
  root MFA enrollment w 8 z 9 kont wymagających remediacji
  (Production OU + NonProduction OU + Sandbox OU)

DODATKOWE RYZYKA:
  - Booking_Online i RShop: email root = personal email pracownika
  - makolab_monitoring: email = tymur.myma@makolab.com (ex-pracownik?)

NASTĘPNY KROK:
  1. LogArchiveNew — brak SCP bloker, można działać natychmiast
     → log-archive-new@makolab.pl → zaloguj jako root → enroll MFA
  2. Utwórz Recovery OU pod Root (r-z8np) dla pozostałych 8 kont
     → aws organizations create-organizational-unit --parent-id r-z8np --name "MFA-Recovery"
  3. Jedno konto na raz: move → enroll → verify → move back

PRIORYTET remediacji:
  1. makolab_dc (864277686382) — management account
  2. LogArchiveNew (771354139056) — po analizie CT guardrails
  3. Pozostałe ACTIVE konta
```

## Update — 2026-05-07 — drp-tfs: CRITICAL issues NAPRAWIONE ✅

```
Projekt:  drp-tfs (klient mako)
AWS:      drp-tfs | 613448424242 | eu-central-1

ZAKOŃCZONE:
  ✅ make destroy / make apply / make app / make nlb / make redis — full reprovision
  ✅ MongoDB replica set: 1 PRIMARY + 2 SECONDARY
     - root cause: delegate_to → brak SSH między node'ami (SG)
     - fix: 60-replset.yml bez delegate_to, node 0 inicjuje rs
     - bug #2: Jinja2 '\t' ≠ tab → pipe-separator '|' w 50-discovery.yml
     - bug #3: race condition — retry loop 60×10s w shell discovery
  ✅ haproxy LoadBalancer: hostname przydzielony
     - fix: enablePorts.quic=false (mixed TCP+UDP usunięte)
     - user usunął stary ALB z AWS (blokował EIP)
     NLB: a6293990bdab242b191283f7b757315e-286074f3d72658d6.elb.eu-central-1.amazonaws.com

PODY tfs-prod: wszystkie 1/1 Running (leasing-filters stabilne)

NASTĘPNY KROK:
  → cloud-detective live check drp-tfs
  → sprawdzić dane po mongorestore
  → zaktualizować install.sh (quic=false)
  → opcjonalnie: powtórzyć functional check leasing-filters API
```

## Update — 2026-05-07 — switch context: puzzler-pbms zapisany, przejście na drp-tfs

```
Zamknięty kontekst roboczy: puzzler-b2b / PBMS
Status:                   standby / audit zapisany
Context:                  20-projects/clients/mako/puzzler-b2b/session-log.md

Najważniejszy stan puzzler-pbms:
  - CI/CD audit DONE: pull-and-update pattern potwierdzony (backend.yml verbatim odczytany)
  - Root cause AzureAd: CI/CD kopiuje secrets z poprzedniego ECS revision przy każdym deploy
  - DEV IAM roles w QA: intencjonalne przez terraform.tfvars — QA roles nie stworzone
  - Worker: NIE w CI/CD matrix — nigdy nie był deployowany przez pipeline
  - Rekomendacja: Wariant C (Terraform structural baseline + CI/CD explicit task def builder)
  - Quick fix: jq del AzureAd z task def + register + update-service
    → wymaga decyzji: czy QA potrzebuje AzureAd? (appsettings.QA.json ma AzureAd sekcję)
  - infra repo: staged envs/dev/services.tf (guardrail parity DEV) — do commita
  - untracked: docs/db-access.md — bez decyzji

Aktywny kontekst roboczy: drp-tfs (klient mako)
AWS profile:              drp-tfs
Region:                   eu-central-1
Account:                  613448424242
Repo:                     ~/projekty/mako/drp_tfs
                          ~/projekty/mako/dc-terraform/terraform-aws/environments/drp-tfs
Vault context:            20-projects/clients/mako/drp-tfs/drp-tfs-context.md

Stan wejściowy drp-tfs:
  CRITICAL: tfs-prod-leasing-filters-api-service 0/2, CrashLoopBackOff
            Mongo REPLICA_SET_GHOST, brak primary ReadPreference primary
  CRITICAL: haproxy-kubernetes-ingress LoadBalancer EXTERNAL-IP <pending>
            mixed TCP+UDP protocol; NLB target groups puste
  Reszta tfs-prod deploymentów: running
  EKS drp-tfs-eks-cluster v1.30, nodegroup 4/4 Ready
  MongoDB replica set na EC2 (drp-tfs-mongo-0/1/2)

Następny krok:
  → aws sts get-caller-identity --profile drp-tfs
  → zbadać Mongo replica set primary status
  → zbadać haproxy LoadBalancer mixed protocol problem
```

## Update — 2026-05-07 — puzzler-pbms: DEV DocumentDB Compass URI

```
Projekt:  puzzler-b2b / PBMS
AWS:      profile puzzler-pbms | account 698220459519 | region eu-west-2
Operacja: read-only — secret discovery + generowanie URI

SECRET: infra-puzzler-b2b/dev/docdb
  klucze: connection_string, connection_string_automation, connection_string_core,
          connection_string_notifier, database_automation, database_core,
          database_notifier, host, password, port, username
  username: dbadmin ✅
  password: niepusty ✅
  connection_string_automation: wskazuje PBMS_DB_automation ✅
  replicaSet=rs0 w secrecie: TAK — usunięty tylko z lokalnego URI (secret AWS bez zmian)

TUNNEL: localhost:27117 -> DEV DocDB:27017

URI DO COMPASS:
  mongodb://dbadmin:***@localhost:27117/PBMS_DB_automation
    ?authSource=admin&directConnection=true&tls=true
    &tlsAllowInvalidCertificates=true&retryWrites=false

ZAPIS: 20-projects/clients/mako/puzzler-b2b/session-log.md

STAN REPO (bez zmian):
  staged:    envs/dev/services.tf (guardrail parity DEV)
  untracked: docs/db-access.md
  apply:     NIE wykonany

NASTĘPNY KROK:
  → git commit -m "fix(dev): align Terraform drift guardrails with QA ownership model"
  → decyzja o docs/db-access.md
```

## Update — 2026-05-07 — switch context: Maspex zapisany, przejście na puzzler-pbms

```
Zamknięty kontekst roboczy: Maspex / Kapsel
Status:                   standby / brak nowych operacji w tej sesji
Context:                  20-projects/clients/mako/maspex/maspex-context.md

Najważniejszy stan Maspex:
  - Redis reboot + CloudFront invalidation wykonane (sesja wcześniejsza).
  - Projekt w standby — czeka na certyfikaty SSL od klienta.
  - Otwarte obserwacje: Redis circuit breaker, maspex-api memory, maspex-bot failures.
  - Terraform UAT plan może blokować stary digest w DynamoDB terraform-locks-969209893152.
  - infra-maspex lokalny patch observability/WAF nadal bez apply — nie dotykać bez plan review.

Aktywny kontekst roboczy: puzzler-b2b / PBMS
AWS profile:              puzzler-pbms
Region:                   eu-west-2
Account:                  698220459519
Repo infra:               ~/projekty/mako/aws-projects/infra-puzzler-b2b-final
Vault context:            20-projects/clients/mako/puzzler-b2b/session-log.md

Stan wejściowy puzzler-pbms:
  - DEV i QA jumphosty ustabilizowane i operator-safe (jumphost-v11, linux/amd64).
  - staged: envs/dev/services.tf
      usunięto local.azuread_secrets; 7x merge -> local.docdb_secrets
      terraform plan: No changes
  - untracked: docs/db-access.md — nie commitować bez decyzji
  - apply NIE wykonany od ostatniego przełączenia

Następny krok:
  → weryfikacja tożsamości AWS:
      aws sts get-caller-identity --profile puzzler-pbms
  → commit staged DEV guardrail change:
      git commit -m "fix(dev): align Terraform drift guardrails with QA ownership model"
  → potem zdecydować co zrobić z docs/db-access.md
```

## Update — 2026-05-07 — switch context: puzzler-pbms zapisany, przejście na Maspex

```
Zamknięty kontekst roboczy: puzzler-b2b / PBMS
Status:                   standby / snapshot zapisany
Context:                  20-projects/clients/mako/puzzler-b2b/session-log.md

Najważniejszy stan puzzler-pbms:
  - DEV/QA jumphosty ustabilizowane i operator-safe.
  - Commity:
      12fac50 fix(jumphost): stabilize sshd runtime and amd64 image build
      a5e5598 fix(terraform): enable ecs exec and normalize jumphost key handling
  - Infra repo nadal ma staged pre-existing envs/dev/services.tf
    (DEV guardrail parity: AzureAd ECS env injection removal).
  - Infra repo nadal ma untracked docs/db-access.md — nie mieszać bez decyzji.

Aktywny kontekst roboczy: Maspex / Kapsel
AWS profile:              maspex-cli
Region:                   eu-west-1
Account:                  969209893152
Repo infra:               ~/projekty/mako/aws-projects/infra-maspex
Vault context:            20-projects/clients/mako/maspex/maspex-context.md
Troubleshooting:          20-projects/clients/mako/maspex/troubleshooting.md
Last load-test report:    20-projects/clients/mako/maspex/load-test-analysis-2026-05-05-1900-cest.md

Stan wejściowy Maspex:
  - UAT CloudFront/API:
      distribution E3J76RNXIE2YIG
      alias kapsel.makotest.pl
      last sanity: /api/health HTTP/2 200 po invalidation
  - UAT ECS:
      cluster maspex-uat
      services maspex-api, maspex-admin-panel, maspex-bot
      last load-test snapshot: maspex-api desired/running 9/9, admin 1/1, bot 1/1
  - UAT Redis:
      ElastiCache maspex-uat, node 0001, standalone single-node
      reboot wykonany kontrolowanie; final status available
  - Najmocniejszy bottleneck z testu 2026-05-05 19:00 CEST:
      app-level Redis write-through / circuit breaker
      924,582 VOTE_CACHE_WRITETHROUGH_FAIL
      906,504 Redis circuit open
      Redis infrastructure zdrowy metrycznie
  - HTTP/ALB/ECS podczas testu:
      0 ELB 5XX
      0 Target 5XX
      0 unhealthy hosts
      0 task churn maspex-api
      ALB avg response 12-16 ms, p99 45-65 ms
  - Ryzyko:
      maspex-api MemoryUtilization narosła ~17% -> ~57%;
      obserwować przy kolejnym teście, bo 4. fala mogłaby zbliżyć do progu 75%.
  - Osobny problem:
      maspex-bot health check failures / replacements.
  - Preprod:
      maspex-preprod-api historycznie 0/3 DOWN przez IAM AccessDeniedException do secretu.

Otwarte prace IaC:
  - infra-maspex ma lokalny patch observability/WAF standby:
      WAF admin allowlist
      Athena/Glue per-path CloudFront logs
      monitoring/dashboard/log metric filters
  - Terraform UAT plan może blokować stary/osierocony digest w DynamoDB:
      table terraform-locks-969209893152
      key maspex/uat/terraform.tfstate-md5
  - Nie wykonywać broad apply bez ponownego plan review.

Następny krok:
  → najpierw zweryfikować bieżącą tożsamość AWS:
    aws sts get-caller-identity --profile maspex-cli
  → potem zależnie od celu: live check UAT po Redis reboot albo review/apply lokalnego patcha observability/WAF.
```

## Update — 2026-05-07 — puzzler-b2b: DEV/QA jumphost remediation DONE

```
Projekt:  puzzler-b2b / PBMS
Repo:     ~/projekty/mako/aws-projects/infra-puzzler-b2b-final
AWS:      profile puzzler-pbms | account 698220459519 | region eu-west-2

CEL ZAKOŃCZONY:
  DEV i QA jumphosty są operacyjnie używalne dla:
    - SSH access
    - TCP forwarding / DocumentDB tunnel
    - ECS Exec troubleshooting
    - controlled operator access

ROOT CAUSES:
  - QA jumphost-v10 był linux/arm64-only, a Fargate task działa jako x86_64.
  - ECS Exec był disabled na obu usługach jumphosta.
  - QA authorized_keys secret miał literal "$(cat ~/.ssh/id_rsa.pub)".
  - Dockerfile dodawał nieobsługiwane Alpine/OpenSSH "UsePAM no".
  - Terraform guardrail ignore_changes=[task_definition] wymagał jawnego update-service dla jumphosta.

WDROŻONE:
  - Dockerfile:
      removed UsePAM no
      deterministic AllowTcpForwarding yes via sed replacement
      preserved PermitRootLogin no / PasswordAuthentication no / PubkeyAuthentication yes
  - image built/pushed:
      tag: jumphost-v11
      platform: linux/amd64
      digest: sha256:4cd031cee7da3f5b874f3fadab93399a945ff4ccfecb6a333a4a7ed70f13e66d
      repos:
        698220459519.dkr.ecr.eu-west-2.amazonaws.com/infra-puzzler-b2b-app-dev:jumphost-v11
        698220459519.dkr.ecr.eu-west-2.amazonaws.com/infra-puzzler-b2b-app-qa:jumphost-v11
  - Terraform targeted apply:
      DEV/QA jumphost task definition replaced
      DEV/QA jumphost ECS service enable_execute_command false -> true
      DEV/QA jumphost_ssh secret version replaced with real authorized_keys
  - explicit ECS update-service required and executed:
      dev service -> task definition infra-puzzler-b2b-dev-jumphost:11
      qa service  -> task definition infra-puzzler-b2b-qa-jumphost:4

RUNTIME VERIFIED:
  DEV:
    service: desired=1 running=1 pending=0 rollout=COMPLETED
    task: 41dab89d34894d9e9c74aad1bfc2e819
    public IP during verification: 18.170.98.226
    ECS Exec: OK
    sshd -T: allowtcpforwarding yes, permitrootlogin no,
             passwordauthentication no, pubkeyauthentication yes
    authorized_keys: 2 lines, non-empty
    port 22: listening
    container -> DocumentDB:27017: open
    SSH login with configured RSA key: OK
    local tunnel 127.0.0.1:37017 -> DEV DocumentDB: OK

  QA:
    service: desired=1 running=1 pending=0 rollout=COMPLETED
    task: 85610ee4390b4f158c9507cbee2e32a1
    public IP during verification: 13.40.23.226
    ECS Exec: OK
    sshd -T: allowtcpforwarding yes, permitrootlogin no,
             passwordauthentication no, pubkeyauthentication yes
    authorized_keys: 2 lines, non-empty
    port 22: listening
    container -> DocumentDB:27017: open
    SSH login with configured RSA key: OK
    local tunnel 127.0.0.1:37018 -> QA DocumentDB: OK

VALIDATION:
  - terraform fmt OK
  - terraform -chdir=envs/dev validate -no-color -> Success with existing deprecated aws_region.name warnings
  - terraform -chdir=envs/qa validate -no-color -> Success with existing deprecated aws_region.name warnings
  - CloudWatch logs after deploy show no UsePAM warning; show sshd listening and accepted publickey.

COMMITS CREATED:
  - 12fac50 fix(jumphost): stabilize sshd runtime and amd64 image build
  - a5e5598 fix(terraform): enable ecs exec and normalize jumphost key handling

REPO STATE AFTER REMEDIATION:
  - staged pre-existing change preserved: envs/dev/services.tf
      (DEV guardrail parity: AzureAd ECS env injection removal)
  - untracked, do not stage accidentally: docs/db-access.md

FINAL VERDICT:
  DEV usable: YES
  QA usable: YES
  operator-safe: YES

NASTĘPNY KROK:
  → commit staged DEV guardrail parity change:
    git commit -m "fix(dev): align Terraform drift guardrails with QA ownership model"
  → potem zdecydować co zrobić z untracked docs/db-access.md
```

## Update — 2026-05-07 — switch context: drp-tfs zapisany, powrót na puzzler-pbms

```
Zamknięty kontekst roboczy: drp-tfs cloud-detective
Status:                   standby / snapshot zapisany
Context:                  20-projects/clients/mako/drp-tfs/drp-tfs-context.md

Najważniejsze otwarte sprawy drp-tfs:
  - CRITICAL: leasing-filters api/core 0/2, CrashLoopBackOff, Mongo REPLICA_SET_GHOST
  - CRITICAL: haproxy LoadBalancer EXTERNAL-IP <pending>, mixed TCP+UDP service
  - follow-up: naprawić Mongo replica set / LoadBalancer i powtórzyć live check

Aktywny kontekst roboczy: puzzler-b2b / PBMS
AWS profile:              puzzler-pbms
Region:                   eu-west-2
Account:                  698220459519
Repo infra:               ~/projekty/mako/aws-projects/infra-puzzler-b2b-final

Stan wejściowy puzzler-pbms:
  - staged: envs/dev/services.tf
  - untracked, nie mieszać bez review: docs/db-access.md
  - ostatni DEV plan: No changes
  - apply NIE wykonany

Następny krok:
  → commit staged DEV guardrail change:
    git commit -m "fix(dev): align Terraform drift guardrails with QA ownership model"
```

## Update — 2026-05-07 — drp-tfs: cloud-detective snapshot zapisany

```
Projekt:    drp-tfs (client-work / mako)
AWS:        profile drp-tfs | account 613448424242 | region eu-central-1
Zapis:      20-projects/clients/mako/drp-tfs/drp-tfs-context.md
Tryb:       read-only cloud-detective-v2

ŹRÓDŁA:
  - live AWS: STS, EC2, EKS, ELBv2, ECS, RDS, DocDB, ElastiCache, Secrets Manager,
              CFN, CloudWatch, Logs, ACM, CloudFront, ECR, EventBridge, WAF, tags
  - live Kubernetes: nodes, namespaces, deployments, services, pods, ingress,
                     describe selected deployments/services, selected pod logs
  - IaC:
      ~/projekty/mako/drp_tfs
      ~/projekty/mako/dc-terraform/terraform-aws/environments/drp-tfs

NAJWAŻNIEJSZE LIVE FINDINGS:
  - EKS drp-tfs-eks-cluster ACTIVE, v1.30, nodegroup general 4/4 Ready.
  - Większość deploymentów tfs-prod działa.
  - CRITICAL: tfs-prod-leasing-filters-api-service 0/2 i core-service 0/2,
    pody CrashLoopBackOff; logi wskazują Mongo replica set jako REPLICA_SET_GHOST
    i brak primary dla ReadPreference primary.
  - CRITICAL: tfs-prod/haproxy-kubernetes-ingress LoadBalancer ma EXTERNAL-IP <pending>;
    event: mixed protocol is not supported for LoadBalancer; target groups listenerów NLB puste.
  - ECS/RDS/DocDB/ElastiCache/Secrets Manager: brak zasobów live w eu-central-1.
  - ECR: wiele repo `tfs/*`, większość scanOnPush=false.
  - CloudWatch alarms: 0.
  - WAF regional: 0 WebACLs.

UWAGI:
  - invocation manifest ma uszkodzony repo_path (`�~/projekty/mako//drp-tfs`);
    użyty rzeczywisty checkout: ~/projekty/mako/drp_tfs.
  - repo drp_tfs jest dirty w module mongo-ec2 playbook.
  - żadnych operacji write/apply/delete nie wykonano.

NASTĘPNY KROK:
  → naprawić Mongo replica set / primary dla leasing-filters
  → rozdzielić albo poprawić HAProxy LoadBalancer mixed TCP+UDP service
  → potem powtórzyć cloud-detective live check
```

## Update — 2026-05-07 — puzzler-b2b: DEV ownership parity guardrails ready

```
Projekt:  puzzler-b2b / PBMS
Repo:     ~/projekty/mako/aws-projects/infra-puzzler-b2b-final
Branch:   main
AWS:      profile puzzler-pbms | account 698220459519 | region eu-west-2

ZROBIONE:
  - sprawdzono QA model:
      envs/qa/services.tf
      envs/qa/secrets.tf
      envs/qa/terraform.tfvars
      modules/core/ecs-service/main.tf
      modules/core/documentdb/main.tf
      docs/terraform-ownership-model.md
  - sprawdzono DEV:
      envs/dev/services.tf
      envs/dev/secrets.tf
      envs/dev/main.tf
      envs/dev/variables.tf
      envs/dev/terraform.tfvars
      envs/dev/service_discovery.tf
      envs/dev/iam.tf
      envs/dev/schedulers.tf

ZMIANA DEV:
  - envs/dev/services.tf:
      usunięto local.azuread_secrets
      7x merge(local.docdb_secrets, local.azuread_secrets) -> local.docdb_secrets
  - zakres tylko DEV; QA/shared modules/docs nietknięte
  - zachowane live-aligned image tags DEV
  - zachowane konto 698220459519
  - zachowany ALB CIDR 195.117.107.110/32
  - zachowane Cloud Map + frontend/sync/builder/jumphost definitions
  - worker nadal nginx:latest, bo live worker task definition też używa nginx i desired=0

GUARDRAILS POTWIERDZONE:
  - envs/dev/secrets.tf: ignore_changes = [secret_string] na docdb/azuread/jumphost_ssh
  - modules/core/documentdb/main.tf: ignore_changes = [master_password]
  - modules/core/ecs-service/main.tf:
      ignore_changes = [container_definitions]
      ignore_changes = [task_definition, desired_count]
  - brak account 947927348523
  - ECS Exec IAM policy istnieje

WALIDACJA:
  - terraform fmt envs/dev/services.tf -> OK
  - terraform -chdir=envs/dev init z AWS_PROFILE=puzzler-pbms -> OK
  - terraform -chdir=envs/dev validate -no-color -> Success
      tylko istniejące warningi deprecated data.aws_region.current.name
  - terraform -chdir=envs/dev plan -no-color -input=false
      z placeholderami dla wymaganych sensitive TF_VAR -> No changes

STAN ROBOCZY:
  - staged: envs/dev/services.tf
  - untracked, nietknięte: docs/db-access.md
  - apply NIE wykonany

REKOMENDOWANY COMMIT:
  git commit -m "fix(dev): align Terraform drift guardrails with QA ownership model"

NASTĘPNY KROK:
  → commit staged DEV guardrail change
  → potem opcjonalnie uat/prod/secrets.tf parity check albo runtime cleanup task definitions
```

## Update — 2026-05-07 — puzzler-b2b: Terraform ownership model documented + IaC stabilized

```
Repo:    ~/projekty/mako/aws-projects/infra-puzzler-b2b-final
Branch:  main

COMMITY:
  15ae29e fix(qa): remove AzureAd env vars and add lifecycle drift guards
  87086b0 docs(terraform): document runtime ownership and drift guardrails

IaC ZMIANY (applied):
  - envs/qa/services.tf: usunięto AzureAd vars z 7 serwisów
  - envs/qa/secrets.tf: ignore_changes = [secret_string] na 3 secret versions
  - modules/core/documentdb/main.tf: ignore_changes = [master_password] (wszystkie envs)
  - .gitignore: usunięto błędny wpis docs/

DOKUMENTACJA:
  - docs/terraform-ownership-model.md (437 linii)
  - 3-tierowy model własności: Terraform / CI/CD / Operator
  - Rationale dla każdego ignore_changes guardrail
  - Workflow operacyjny (plan-first, sts verify)
  - Krytyczne ostrzeżenia operacyjne
  - 6 TODOs architektonicznych

STAN: terraform plan QA = effectively no-op | serwisy zdrowe

NASTĘPNY KROK:
  → Weryfikacja: uat/prod/secrets.tf parity (ignore_changes gaps)
  → Opcjonalnie: force-replace task definitions dla runtime cleanup
```

## Update — 2026-05-07 — puzzler-b2b: notifier crash loop RESOLVED

```
Projekt:  Puzzler B2B (klient mako)
Serwis:   infra-puzzler-b2b-dev-notifier (ECS Fargate)
Profil:   puzzler-pbms | account 698220459519 | region eu-west-2

ROOT CAUSE:
  Task definition rev 65/69 nie miała mappingu ConnectionStrings__PBMS_DB_notifier
  w sekcji secrets → zmienna env = "" → MongoConfigurationException crash loop

FIX:
  terraform apply -replace=...aws_ecs_task_definition.this
  → rev 70 z ConnectionStrings__PBMS_DB_notifier → arn:...:connection_string_notifier::
  aws ecs update-service --task-definition ...:70
  → serwis skierowany na rev 70

INCIDENT W TRAKCIE:
  aws_docdb_cluster.master_password nadpisane "plan-placeholder" (brak ignore_changes)
  → naprawione drugim apply z prawdziwym hasłem

WERYFIKACJA:
  runningCount: 1 / desiredCount: 1 / pendingCount: 0
  logi: "PBMS Notifier API started." — brak MongoConfigurationException ✅

REKOMENDACJA (nie zrobione):
  → ignore_changes = [master_password] do modułu DocumentDB

NASTĘPNY KROK:
  → projekt w trakcie — crash loop zażegnany, dev env stabilny
```

## Update — 2026-05-07 — maspex UAT: Redis reboot + CloudFront invalidation

```
Projekt:   maspex (klient mako)
AWS:       profile maspex-cli | account 969209893152
Operacja:  kontrolowany refresh cache UAT — Redis + CloudFront

WYKONANE:
  1. Redis ElastiCache maspex-uat — reboot node 0001
     → status po operacji: available ✅
     → czas downtime: ~30–45 sek (single-node, brak failover)

  2. CloudFront E3J76RNXIE2YIG (kapsel.makotest.pl) — invalidation /*
     → Invalidation ID: IDLPGZBLCJJMAIW6ACQUPL5IDJ
     → status: Completed ✅

WYNIK: środowisko UAT gotowe do dalszych testów

NASTĘPNY KROK:
  → Czeka na certyfikaty SSL od klienta (projekt w standby)
```

## Update — 2026-05-07 — secure-ai-anonymizer: KF-006 fixed

```
Projekt:  secure-ai-anonymizer (dc-anonimizator)
Repo:     ~/projekty/mako/aws-projects/dc-anonimizator
Status:   KF-006 FIXED — priority-based overlap resolution

ZROBIONE:
  src/dc_anonymizer/tokenization/tokenizer.py — pełny rewrite
    → _ENTITY_PRIORITY: 13 poziomów (DB_CONNECTION_STRING=11 > EMAIL_ADDRESS=4)
    → _beats(): priorytet > długość spanu > score
    → _merge_overlapping(): kandydat wygrywa tylko gdy bije WSZYSTKIE nakładające się spany

  tests/unit/test_tokenizer.py — +6 testów priority resolution
  tests/regression/test_kf_002_004_006_*: xfail usunięty z 3 testów (teraz pass)
  docs/known-failures.md: KF-006/KF-002/KF-004 → status: fixed

WYNIKI:
  make test           → 27 passed, 4 skipped, 7 xfailed
  make test-regression → 11 passed, 7 xfailed  (było 8/10xfail)
  make smoke          → PASSED
  fixture analyze     → postgresql/mongodb/redis connection strings w pełni tokenizowane

NOWY EDGE CASE (nie blocking):
  API_KEY_GENERIC (priority=9) > AWS_ARN (priority=8)
  → rola IAM triggeruje API_KEY_GENERIC jako FP → partial ARN leak
  → naprawa: obniżyć priorytet API_KEY_GENERIC lub podnieść AWS_ARN

NASTĘPNY KROK:
  → KF-001: S3 ARN regex (brak account ID w bucket ARNs)
  → KF-003: email z relaxed TLD (.internal, .example, .corp)
  → Nowy KF: API_KEY_GENERIC priority edge case (ARN partial leak)
```

## Update — 2026-05-07 — secure-ai-anonymizer: bootstrap repo

```
Akcja:   Bootstrap repozytorium dc-anonimizator
Repo:    ~/projekty/mako/aws-projects/dc-anonimizator
Domena:  private-rnd | classification: restricted

ZROBIONE:
  Pełna struktura: src/dc_anonymizer/{ingest,detection,tokenization,storage,audit,pipeline}
  CLI: dc-anonymizer anonymize / detect / rehydrate / validate
  Custom recognizers: AWS ARN/account/keys, CIDR, FQDN, DB connection strings, JWT
  Envelope encryption (AESGCM) dla token map
  PostgreSQL schema: documents, token_maps, token_map_entries, audit_events (append-only)
  Docker Compose: PostgreSQL:16 + Ollama (optional profile)
  7 fixture documents (input), unit + integration tests
  Makefile, pyproject.toml (uv), .gitignore, .env.example
  ADR-008 (uv vs Poetry) w vault

NASTĘPNY KROK:
  → uv sync + python -m spacy download en_core_web_lg
  → make db-up
  → dc-anonymizer anonymize --input tests/fixtures/input/mixed_document.txt
  → Benchmark Ollama: llama3.2:3b vs mistral:7b
```

## Update — 2026-05-07 — vault audit + cloud-detective context pack

```
Akcja:   Sesja wiedzy — audyt vault + context packi

WYKONANE:
  1. Pełny audyt vaultu (8 sekcji) dla ChatGPT:
     - przeczytano 15+ plików _system/ (wszystkie kontrakty LLM)
     - zaktualizowano: _chatgpt/context-packs/vault-llm-governance.md
     - zawiera: Executive Summary, Vault Structure, AI/LLM Governance, Workflow Mapping,
       Context Engineering Model, Organizational/Strategic Insights, Risks, Most Important Files
     - gotowy do wklejenia do ChatGPT bez dostępu do vault

  2. Nowy context pack — cloud-detective:
     - utworzono: _chatgpt/context-packs/cloud-detective.md
     - zawiera: architektura 3-warstwowa (skrypt → invocation → template), workflow,
       kluczowe guardrails cloud-detective-v2, format pliku wynikowego, aktywne invocations

STAN AKTYWNYCH PROJEKTÓW (bez zmian od 2026-05-06):
  puzzler-b2b: main CLEAN, apply done, azuread rotated ✅
  cloud-practice: faza 0-30 aktywna, blokery: Partner Central access + scope sign-off
  maspex: standby — czeka na certyfikaty SSL od klienta
  planodkupow: standby — czeka na deva (RabbitMQ 3.8.6 deprecated)

NASTĘPNY KROK:
  → puzzler-b2b: developer musi pobrać RDS CA bundle (global-bundle.pem) przed użyciem db-connect.ps1
  → cloud-practice: uzyskać dostęp do AWS Partner Central
```

## Update — 2026-05-06 — puzzler-pbms: drift guardrails + apply DONE

```
Projekt:    puzzler-b2b / PBMS (klient mako)
AWS profile: puzzler-pbms | region: eu-west-2 | konto: 698220459519
Repo infra:  ~/projekty/mako/aws-projects/infra-puzzler-b2b-final
Branch:      main (CLEAN — wszystko zmergowane)

CO ZROBIONO:
  1. Drift guardrails (modules/core/ecs-service/main.tf):
     - aws_ecs_task_definition: ignore_changes = [container_definitions]
     - aws_ecs_service:         ignore_changes = [task_definition, desired_count]
  2. Secret version guardrails (envs/dev/secrets.tf):
     - aws_secretsmanager_secret_version (docdb/azuread/jumphost_ssh):
       ignore_changes = [secret_string]
  3. Notifier DB keys: gated → dodane do live secret (CLI) → przywrócone w IaC
     - infra-puzzler-b2b/dev/docdb: ma database_notifier + connection_string_notifier
  4. ALB SG: 0.0.0.0/0 → 195.117.107.110/32 (apply wykonany)
  5. db-connect.ps1: stały IP zaktualizowany, dodana instrukcja mongosh z TLS
  6. Dwa MR zmergowane do main

PLAN RESULT (po guardrails): 0 add, 1 change, 0 destroy — tylko ALB SG ✅
APPLY: success — 1 changed (ALB SG)

NASTĘPNY KROK:
  ✅ azuread_client_secret zrotowany w Azure AD (2026-05-06)
  → Decyzja: czy QA apply jest teraz bezpieczny?
  → dev-connect: developer musi pobrać RDS CA bundle przed pierwszym użyciem
```

## Update — 2026-05-06 — cloud practice space: 85-cloud-practice/ utworzona

```
Akcja:   Nowa przestrzeń strategiczno-operacyjna dla roli AWS Technical Leader
Vault:   85-cloud-practice/
Status:  GOTOWE — faza 0-30 dni aktywna

Pliki:
  dashboard.md        ← ENTRY POINT — tu zacznij każdy dzień
  roadmap.md          ← 30-60-90 roadmap + milestones + deliverables
  ownership.md        ← scope, stakeholders, granice odpowiedzialności
  partnership/status.md  ← AWS Partnership tier, PAM/PDM, MDF, programy
  competency/tracker.md  ← competency status, evidence log, WAR tracking
  opportunities/tracker.md ← presales, tech opportunities, backlog

Priorytety teraz (faza 0-30):
  → Uzyskać dostęp do AWS Partner Central
  → Zidentyfikować PAM/PDM
  → Formal scope sign-off z zarządem
  → Gap assessment: partnership tier vs. certyfikacje vs. competency requirements
```

## Update — 2026-05-06 — puzzler-b2b IaC commit: ALB ingress + ECS ownership normalization

```
Projekt:    puzzler-b2b / PBMS (klient mako)
Branch:     feat/dev-jumphost-runtime-secret
Commit:     72c3764
Akcja:      Clean commit — normalizacja własności ALB ingress + ECS task_definition
Status:     COMMIT CREATED / WORKING TREE DIRTY (pozostałe zmiany unstaged)

WYKONANE:
  ✅ commit 72c3764 — fix(terraform): normalize alb ingress and ecs task definition ownership
     Zawiera:
       - envs/dev: alb_ingress_cidr_blocks = ["195.117.107.110/32"] (main.tf, variables.tf, tfvars)
       - envs/dev/services.tf: tylko source path changes (notifier hunks wykluczone)
       - envs/qa/backend.tf: FILL_IN → 698220459519-terraform-state
       - modules/core/ + modules/pattern/ — pełny vendor (130 plików)
       - modules/core/ecs-service: ignore_changes = [task_definition] (CI/CD owns revisions)
       - .gitignore: literówka autorized_keys → authorized_keys + .env/.pem/.key
     Metoda: selective staging via git hash-object + git update-index (partial hunk staging)

WYKLUCZONE (nadal w working tree):
  ❌ Dockerfile: AllowTcpForwarding yes — jumphost SSH, osobny commit
  ❌ envs/dev/secrets.tf: database_notifier / connection_string_notifier — osobny commit
  ❌ envs/dev/services.tf (notifier hunks): PBMS_DB_NOTIFIER, ConnectionStrings__PBMS_DB_notifier
  ❌ envs/qa/* — wszystkie pliki QA: ZABLOKOWANE (patrz niżej)
  ❌ envs/dev/alb_frontend.tf (untracked, broken): ref do undeclared var.frontend_alb_certificate_arn
  ❌ scripts/: jumphost tooling (db-connect.sh/.cmd/.ps1)

🔴 KRYTYCZNY BLOCKER — SECRETS W WORKING TREE:
  envs/qa/terraform.tfvars zawiera hardcoded secrets:
    documentdb_password      = "64IAJ#<233Bt"
    azuread_client_secret    = "Kja8Q~78D4eEp~..."
    azuread_tenant_id / client_id / client_secret_id
  → Ten plik NIGDY nie może zostać commitowany w obecnej formie
  → Rekomendacja: rotate azuread_client_secret TERAZ, wyczyść plik przed QA commitem

STAN VALIDATE:
  ✅ terraform fmt: PASS
  ❌ terraform validate: FAIL (envs/dev/alb_frontend.tf — undeclared var.frontend_alb_certificate_arn)
     Błąd NIE jest wprowadzony przez commit; pre-existing untracked file

NASTĘPNE KROKI:
  1. Rotate Azure AD client secret (był eksponowany w working tree)
  2. Wyczyścić envs/qa/terraform.tfvars (usunąć hardcoded values → TF_VAR_*)
  3. Osobny commit: notifier DB (secrets.tf + services.tf notifier hunks)
  4. Osobny commit: Dockerfile (TCP forwarding) + scripts/
  5. QA IaC commit: qa/main.tf + qa/variables.tf + qa/services.tf (po cleanup secrets)
  6. Fix envs/dev/alb_frontend.tf: dodać var.frontend_alb_certificate_arn lub usunąć plik
```

## Update — 2026-05-06 — switch context: Maspex zapisany, przejście na puzzler-pbms

```
Projekt zamykany: Maspex UAT (klient mako)
Akcja:            Zapis stanu po analizie load testu 19:00 CEST + controlled cache refresh
Status:           ZAPISANE / STANDBY

MASPEX — WYKONANE:
  ✅ Raport load testu 2026-05-05 19:00 CEST zapisany:
     20-projects/clients/mako/maspex/load-test-analysis-2026-05-05-1900-cest.md

  ✅ Redis / ElastiCache UAT zrestartowany kontrolowanie przez AWS CLI:
     profile: maspex-cli
     region:  eu-west-1
     cluster: maspex-uat
     type:    standalone Redis, single node
     node:    0001
     final:   CacheClusterStatus=available, CacheNodeStatus=available

  ✅ CloudFront UAT API cache invalidated:
     distribution: E3J76RNXIE2YIG
     alias:        kapsel.makotest.pl
     path:         /*
     invalidation: I5ENTEMC80BB7GFLM005T3NK0X
     final:        Completed

  ✅ Sanity check:
     curl -I https://kapsel.makotest.pl/api/health → HTTP/2 200
     x-cache: Miss from cloudfront

MASPEX — NAJWAŻNIEJSZY STAN:
  🔴 Najmocniejszy bottleneck po load teście: app-level Redis write-through / circuit breaker
     924,582 VOTE_CACHE_WRITETHROUGH_FAIL, 906,504 Redis circuit open
     Redis infrastructure zdrowy metrycznie; problem wygląda na klient/circuit/reconnect

  ✅ Warstwa HTTP/ALB/ECS bez degradacji:
     0 ELB 5XX, 0 Target 5XX, 0 unhealthy hosts, 0 task churn maspex-api

  ⚠ Memory maspex-api narosła z ~17% do ~57% podczas testu; po restarcie Redis nie restartowano ECS.
     Przy kolejnym teście obserwować ECS MemoryUtilization i logi Redis circuit.

  ⚠ maspex-bot pozostaje osobnym problemem operacyjnym: health check failures / replacements.

  ⚠ Terraform/IaC Maspex nie ruszany:
     nie było terraform apply, nie było zmian infra; lokalny patch observability/WAF nadal standby.

Następny kontekst roboczy: puzzler-b2b / PBMS
AWS profile:              puzzler-pbms
Region:                   eu-west-2
Repo infra:               ~/projekty/mako/aws-projects/infra-puzzler-b2b-final
Vault context:            20-projects/clients/mako/puzzler-b2b/puzzler-b2b-context.md

PUZZLER — STAN WEJŚCIOWY Z OSTATNIEGO SNAPSHOTU:
  ⚠ 2026-05-05: AWS credentials puzzler-pbms były expired / SignatureDoesNotMatch.
     Pierwszy krok po przełączeniu: aws sts get-caller-identity --profile puzzler-pbms.

  🔴 Repo infra miało ryzyka working tree:
     - authorized_keys untracked + literówka w .gitignore: autorized_keys vs authorized_keys
     - envs/dev/.env untracked / brak reguły .gitignore
     - QA IaC rozbudowane, niezatwierdzone
     - modules/pattern/frontend-ecs-microservice untracked

  ⚠ QA jumphost wg ostatniego pełnego live snapshotu był DOWN przez ECR image missing.
     Stan aktualny wymaga live weryfikacji po naprawie credentials.
```

## Update — 2026-05-05 — Maspex UAT load test 12:00-13:00 CEST — analiza zakonczona

```
Projekt:    Maspex UAT (klient mako)
Akcja:      Read-only analiza load testu 2026-05-05 12:00-13:00 CEST
Wynik:      Raport zapisany do vault

KLUCZOWE USTALENIA:
  ✅ API/ALB nie zdegradowal — 0 ELB 5XX, 0 unhealthy hosts, max latency 0.8s
  🔴 Redis circuit open przez CALY test (25 min) — 305K VOTE_CACHE_WRITETHROUGH_FAIL
     Start: 10:19:58 UTC — 10 minut po anomalii CurrConnections 30→5
  ⚠ CurrConnections: 30→5 o 10:10 UTC (przed testem) — prawdopodobna przyczyna cascade
  ✅ Autoscaling: CPU max 24%, dobrze ponizej 60% progu; scale-out nie wyzwolony
  ✅ CloudFront: 0% 5xx, ~53% offload (vs 41.7% April 29)
  ⚠ maspex-bot: crash loop (Twitch auth token brakujacy) — osobny problem
  ❓ Czy votes byly tracone przez 25 min circuit open? — wymaga weryfikacji w kodzie

Raport: 20-projects/clients/mako/maspex/load-test-analysis-2026-05-05-1200-cest.md
```

Poprzedni context:

## Update — 2026-05-05 — puzzler-b2b cloud-detective scan (IaC only — credentials expired)

```
Projekt:    puzzler-b2b (klient mako)
Akcja:      Cloud Detective v2 scan — IaC only (AWS credentials wygasłe)

NOWE USTALENIA (IaC working tree 2026-05-05):
  ⚠ AWS credentials puzzler-pbms expired → live scan niemożliwy
    Fix: odświeżyć klucze IAM w ~/.aws/config (AKIA2FEJOWX7TOPU2B44 unieważniony)

  🔴 authorized_keys untracked na root repo / gitignore literówka (autorized_keys)
    Fix: poprawić .gitignore na 'authorized_keys'

  ⚠ envs/dev/.env untracked — brak w .gitignore (aktualnie pusty)
    Fix: dodać '.env' do .gitignore

  📂 QA IaC rozbudowane (niezatwierdzone): services.tf, schedulers.tf, cloudwatch.tf,
     secrets.tf, iam.tf, alb_frontend.tf, service_discovery.tf — in-progress, nie merged

  📂 Nowy moduł lokalny: modules/pattern/frontend-ecs-microservice (untracked)

RUNTIME (snapshot 2026-05-01 — nadal best available):
  QA jumphost: DOWN (ECR image missing) — niezweryfikowany stan aktualny
  Dev + QA ECS: OK (snapshot)

Context: 20-projects/clients/mako/puzzler-b2b/puzzler-b2b-context.md
```

## Update — 2026-05-05 — maspex cloud-detective scan (delta od 2026-05-01)

```
Projekt:    maspex (klient mako) — platforma konkursowa Kapsel
Akcja:      Cloud Detective v2 scan — read-only

ZMIANY vs snapshot 2026-05-01:
  ⛔ ACM twojkapsel-admin.makolab.pro: PENDING_VALIDATION → FAILED (eu-west-1 + us-east-1)
     Wymaga: re-request certificate + walidacja DNS
  ⚠ maspex-bot: eskalacja NISKI → WYSOKI
     target unhealthy od 12 dni (alarm od 2026-04-23), NIE deployment cycle
  🔴 maspex-preprod-api: nadal 0/3 DOWN — IAM AccessDeniedException (4 dni bez naprawy)
  ✅ WAF: potwierdzone GAP (wafv2 list-web-acls = puste)
  ℹ  Brak nowych commitów w infra-maspex od 2026-05-01

Context: 20-projects/clients/mako/maspex/maspex-context.md
```

## Update — 2026-05-03 — Root governance established for Admin-MakoLab ✅

```
Projekt:    Admin-MakoLab (647075515164) — FTR blocker
Akcja:      Root governance udokumentowana, klucz usunięty

ROOT EMAIL: admin@makolab.pl
ROOT KEY:   ❌ USUNIĘTY 2026-05-03 (był z 2016, nieużywany 10 lat)
MFA:        enabled (3 urządzenia)
GOVERNANCE: break-glass only, KeePass, log każdego użycia w vault

DOKUMENTACJA: 20-projects/internal/llz/root-access-governance.md

OTWARTE:
  [FILL] Kto posiada 3 urządzenia MFA?
  [FILL] Właściciel dostępu (imię/rola)
  [FILL] Dostęp awaryjny (backup osoba)

NEXT: Security Hub org-wide rollout (Phase 4)

NEXT ACTION:
  1. Uzyskaj dostęp do admin@makolab.pl (IT admin / Office365 / Google Workspace)
  2. Wykonaj password reset przez AWS Console (Forgot password)
  3. Usuń root access key
  4. Udokumentuj break-glass procedure
```

## Update — 2026-05-03 — Config Compliance Baseline: 98% ⚠️ 1 CRITICAL FINDING

```
Projekt:    aws-cloud-platform (mako) — LLZ
Akcja:      READ-ONLY — compliance check po Config Phase 3
Status:     98% compliant — 1 blocker przed FTR

❌ CRITICAL — FTR BLOCKER:
  Admin-MakoLab (647075515164): aktywny root access key
  AccountAccessKeysPresent=1 (potwierdzone)
  MFA: włączone (3 urządzenia) — mitigacja częściowa

SCORE: 52/53 = 98%

NEXT ACTION:
  Usunąć root access key z Admin-MakoLab przed FTR
  Sprawdzić czy key jest używany przed usunięciem
  Raport: 20-projects/internal/llz/config-compliance-baseline-2026-05-03.md
```

## Update — 2026-05-03 — AWS Config Phase 3: BASELINE RULES WDROŻONE ✅

```
Projekt:    aws-cloud-platform (mako) — LLZ
Akcja:      platform/security/config/ — terraform apply
Status:     LIVE — 5 reguł aktywnych na 11/11 kont member

WDROŻONE:
  ✅  cloudtrail-enabled (CLOUD_TRAIL_ENABLED)
  ✅  iam-root-access-key-check (IAM_ROOT_ACCESS_KEY_CHECK)
  ✅  multi-region-cloud-trail-enabled (MULTI_REGION_CLOUD_TRAIL_ENABLED)
  ✅  s3-bucket-public-read-prohibited (S3_BUCKET_PUBLIC_READ_PROHIBITED)
  ✅  s3-bucket-public-write-prohibited (S3_BUCKET_PUBLIC_WRITE_PROHIBITED)
  ✅  Commit: 7d14579
  ✅  terraform.tfvars persisted (ochrona przed destroy StackSet)

TRYB: detect-only, bez auto-remediation
SCP: bez zmian, StackSet: bez zmian
Initial NON_COMPLIANT findings = discovery, nie incydenty

NEXT (brak pilnego):
  - Compliance results za ~15 min
  - Management account recorder (odłożone)
  - Optional rules (ec2-ssm, rds-encrypted) — po akceptacji baseline
```

## Update — 2026-05-03 — AWS Config Phase 2: WERYFIKACJA ZAKOŃCZONA ✅

```
Projekt:    aws-cloud-platform (mako) — LLZ
Akcja:      READ-ONLY — weryfikacja nagrywania AWS Config we wszystkich aktywnych kontach
Status:     STABLE — 11/11 member accounts recording=true, SUCCESS

WYNIK:
  ✅  11 member accounts: recording=true, lastStatus=SUCCESS (wszystkie)
  ✅  StackSet: 22 CURRENT, 10 OUTDATED (suspended konta - oczekiwane)
  ⚠️  management account (864277686382): brak recordera (expected — StackSet exclusion by design)
  ✅  SCP exceptions: brak
  ✅  Żadnych akcji naprawczych — wszystko działało automatycznie

DECYZJA ODŁOŻONA:
  Management account Config recorder (wymaga osobnego TF resource)

NASTĘPNY KROK (czeka na zatwierdzenie):
  Phase 3 — Config rules (baseline): cloudtrail-enabled, iam-root-access-key-check,
  multi-region-cloud-trail-enabled, s3-bucket-public-read-prohibited, s3-bucket-public-write-prohibited
  Plik: platform/security/config/ → enable_config_rules = true
```

## Update — 2026-05-02 — rshop p99 latency investigation: ZAKOŃCZONA ✅

```
Projekt:    rshop PROD (943111679945) — SRE investigation
Akcja:      READ-ONLY — analiza degradacji latency ALB p99
Status:     Root cause zidentyfikowany, raport zapisany

ROOT CAUSE (2 niezależne problemy):
  1. /api/Services/* → external Renault DMS API bez timeout/cache → 12.4s cold start
  2. /api/Accessories/* → ORDER BY NEWID() → full table scan na każdy request

KLASYFIKACJA: Nie incydent (brak 5xx), SLO breach (p99 >2s)
RAPORT: 40-runbooks/incidents/rshop-prod-p99-latency-2026-05-02.md

REKOMENDOWANE NEXT STEPS:
  1. Cache na /api/Services/categories (TTL 60s)
  2. HTTP timeout na DMS calls (max 10s)
  3. Zastąpić ORDER BY NEWID() shuffle w aplikacji
  4. ECS desired=2 dla rshop-prod-api-svc
```

## Update — 2026-05-02 — GuardDuty org-wide: DEPLOYED ✅ (12/12 kont)

```
Projekt:    aws-cloud-platform (mako) — LLZ
Akcja:      security/guardduty/ — terraform apply, org-wide enrollment
Status:     LIVE — pierwszy raz w historii org

WDROŻONE:
  ✅  Delegated admin: monitoring-nagios-bot (814662658531)
  ✅  auto_enable_organization_members = ALL (12 kont enrolled)
  ✅  Baseline: CLOUD_TRAIL + DNS_LOGS + FLOW_LOGS na każdym koncie
  ✅  Commit: 813697b

WAŻNE — SIDE EFFECT:
  ⚠️  RShop + Booking miały premium features (S3, EBS, RDS, Lambda) od 2026-02-09
      → Po enrollment jako org members: ZRESETOWANE DO DISABLED (AWS behaviour)
      → Jeśli te features były potrzebne → przywróć per-konto lub przez org feature config

ROLLBACK:
  terraform destroy (security/guardduty/)

NASTĘPNY KROK: AWS Config org-wide (FTR 4 — ostatni blocker FTR)
```

## Update — 2026-05-02 — SCP Security Baseline: WDROŻONY ✅ (Sandbox + NonProd + Prod)

```
Projekt:    aws-cloud-platform (mako) — LLZ
Akcja:      organization/scp/ — terraform apply x3 (canary rollout COMPLETE)
Status:     LIVE — zero production impact

WDROŻONE:
  ✅  llz-security-baseline (ID: p-8wat7tjs) — wszystkie 3 OU pokryte
  ✅  Sandbox OU (lab 052845428574) — commit 11515ec
  ✅  NonProduction OU (DRP-TFS 613448424242) — commit 1c6e1ba
  ✅  Production OU (rshop/booking/planodkupow/dacia/planodkupowv1/CC) — commit 7e0738e
  ✅  Zero AccessDenied we wszystkich kontach
  ✅  GuardDuty reads nienaruszone (rshop ma aktywny GD)

Root OU: NIE podpięty — wymaga osobnej decyzji

ROLLBACK (emergency):
  aws organizations detach-policy --policy-id p-8wat7tjs --target-id <OU_ID>
  lub: terraform destroy (organization/scp/)

NASTĘPNY KROK: Faza B → GuardDuty org-wide (odblokowuje FTR 3)
```

## Update — 2026-05-02 — AWS Health → GLPI — PRZETESTOWANE, PIPELINE DZIAŁA ✅

```
Projekt:    aws-cloud-platform (mako), monitoring-nagios-bot (814662658531)
Akcja:      Lambda health-notify — ujednolicenie formatu + test end-to-end
Wynik:      email potwierdzony w skrzynce, format GLPI poprawny

WDROŻONE I PRZETESTOWANE:
  ✅  SEVERITY_MAP: issue→high, investigation→medium, inne→low
  ✅  Body: EventTypeCategory, DedupKey przed Resources, "Resources:", Source z →
  ✅  Subject: [GLPI][AWS][HEALTH][RShop][eu-central-1][RDS][ISSUE] AWS_RDS_...
  ✅  Email dotarł na jaroslaw.golab@makolab.com — format zgodny z oczekiwaniami GLPI
  ✅  docs/operator/usage.md: poprawne komendy testowe (lambda invoke, nie put-events)

WAŻNE: aws events put-events z source "aws.*" jest zablokowane przez AWS na wszystkich
       busach. Test robi się przez direct lambda invoke z OrganizationAccountAccessRole.
       Komenda w docs/operator/usage.md.

NASTĘPNY KROK:
  📋  Gdy znany email GLPI — dodaj go:
      cd platform/health-notifications
      AWS_PROFILE=mako-dc terraform apply \
        -var 'notification_emails=["jaroslaw.golab@makolab.com","glpi-aws-alerts@makolab.pl"]'
  ⚠️  Subskrypcja health-ops-alerts (us-east-1) — sprawdź czy potwierdzona
```

## Update — 2026-05-01 — AWS Health → GLPI integracja — WDROŻONA ✓

```
Projekt:    aws-cloud-platform (mako), monitoring-nagios-bot (814662658531)
Akcja:      platform/health-notifications — pełna integracja GLPI email-based
Wynik:      terraform apply complete (8 zasobów), operator docs zapisane

WDROŻONE:
  ✅  Lambda: nowy formatter [GLPI][AWS][HEALTH][<konto>][<region>][<usługa>][<kat>]
              filtrowanie: tylko issue/investigation + statusCode=open
              DedupKey w body (deduplikacja GLPI)
  ✅  notification_email → notification_emails (lista, for_each)
  ✅  SNS health-ops-alerts (us-east-1) — dla alarmów operacyjnych
  ✅  3 CloudWatch alarmy: Lambda Errors, Throttles, EventBridge FailedInvocations
  ✅  docs/operator/usage.md — instrukcja operacyjna z sekcją GLPI

CZEKA NA DZIAŁANIE:
  ⚠️  Potwierdź 2 emaile subskrypcji SNS:
      - health-notifications (eu-central-1) → jaroslaw.golab@makolab.com
      - health-ops-alerts (us-east-1) → jaroslaw.golab@makolab.com
  📋  Gdy znany email GLPI — dodaj go:
      terraform apply -var 'notification_emails=["jaroslaw.golab@makolab.com","glpi-aws-alerts@makolab.pl"]'

NASTĘPNY KROK (opcjonalne):
  - Test end-to-end: aws events put-events (komenda w docs/operator/usage.md)
  - Dodać email GLPI do notification_emails
```

## Update — 2026-05-01 — CloudTrail naprawiony + jgol_cli policy + monitoring scan ✓

```
Projekt:    aws-cloud-platform (mako)

1. CloudTrail fix (CRITICAL → NAPRAWIONY):
   - Przyczyna: kms:GrantIsForAWSResource:true w warunku AllowCloudTrailUseKey
     → ten condition key jest tylko dla kms:CreateGrant, nie dla GenerateDataKey
     → zawsze false przy bezpośrednich API calls → AccessDenied → S3 PutObject fail
   - Naprawa:
     a) KMS key policy w LogArchiveNew (771354139056) — usunięto błędny condition,
        dodano kms:Decrypt dla management account root do czytania logów
     b) aws cloudtrail update-trail --kms-key-id arn:aws:kms:eu-central-1:771354139056:key/a6ce6c61-...
   - Status: LatestDeliveryError: null ✅ (pierwsze nowe logi pojawią się za ~15 min)

2. jgol_cli policy:
   - Dodano inline policy AssumeCloudDetectiveAgent:
     sts:AssumeRole → arn:aws:iam::864277686382:role/cloud-detective-agent ✅

3. Scan monitoring-nagios-bot (814662658531):
   - Nowy plik: 20-projects/clients/mako/aws-cloud-platform/monitoring-context.md
   - Lambda health-notify: Active / Successful
   - EventBridge bus health-aggregation: ENABLED
   - OAM sink observabilitySink: potwierdzony live (korekta: NIE w management account!)
   - 4 OAM linki: rshop, booking, planodkupow, dacia (7 kont bez linków)
   - 5 CloudWatch dashboards: llz-platform-overview, booking, dacia, rshop, bbmt
   - Problemy: brak CW alarms na Lambda errors, partial OAM coverage, tagging NO-GO LLZ

NASTĘPNY KROK (opcjonalne):
  - Skan pozostałych kont member przez cd-<konto> (rshop, booking, dacia)
  - Uzupełnić OAM linki dla cc, drp_tfs, planodkupowv1, admin_makolab, lab, log_archive
  - Dodać CW alarm na Lambda errors/throttles w health-notify
```

## Update — 2026-05-01 — cloud-detective IAM cross-account module — DEPLOYED ✓

```
Projekt:    aws-cloud-platform (mako), management 864277686382, org o-5c4d5k6io1
Akcja:      Terraform module security/cloud-detective/ — wdrożony i przetestowany
Wynik:      25 zasobów IAM wdrożonych (apply complete)
            12 profili ~/.aws/config wygenerowanych (cd-management + 11 member)

ZWERYFIKOWANE:
  ✅  cd-management → cloud-detective-agent (864277686382)
  ✅  cd-rshop → CloudDetectiveReadOnly (943111679945)
  ✅  cd-booking-online → CloudDetectiveReadOnly (128264038676)
  ✅  Read (ecs list-clusters) działa, write (iam:CreateUser) AccessDenied

RĘCZNY KROK (jeszcze nie wykonany):
  Dodać do policy jgol_cli (lub grupy IAM):
  { "Effect": "Allow", "Action": "sts:AssumeRole",
    "Resource": "arn:aws:iam::864277686382:role/cloud-detective-agent" }
  (mako-dc profile działa bo ma inne uprawnienia — jgol_cli CLI może potrzebować tej zmiany)

NASTĘPNY KROK:
  - awsume cd-rshop + cloud-detective v2 scan (cross-account read-only już gotowe)
  - Wykonaj ręczny krok jgol_cli policy jeśli CLI awsume nie działa
```

## Update — 2026-05-01 — aws-cloud-platform cloud-detective snapshot (NOWY) ✓

```
Projekt:    aws-cloud-platform (mako), management account 864277686382
Akcja:      cloud-detective v2 read-only scan — Organizations platform (pierwsze skanowanie)
Wynik:      20-projects/clients/mako/aws-cloud-platform/aws-cloud-platform-context.md (NOWY)

POZIOM PEWNOŚCI: częściowa
  - Management account: w pełni sprawdzone live (org, SCPs, CloudTrail, state backend)
  - Monitoring account (814662658531): niezweryfikowane bezpośrednio (IaC/import blocks)

🔥 CRITICAL:
  CloudTrail org-baseline — delivery BROKEN od 2026-02-14 (2.5 mies.)
  KMS key policy w LogArchiveNew nie pozwala na GenerateDataKey delivery roli AWS.
  Logi organizacyjne NIE są persystowane.

WYSOKI:
  - LLZ SCPs (llz-quarantine-deny-all, llz-workloads-baseline) — NIE wdrożone w live AWS
  - Tag Policies — NIE wdrożone (IaC gotowe)
  - AWS Config / SecurityHub / GuardDuty — nie włączone w management account
  - Brak delegated administrators

NASTĘPNY KROK:
  - Fix KMS key policy w LogArchiveNew — allow cloudtrail delivery principal
  - Zbadaj: czy terraform apply dla organization/governance był kiedykolwiek odpalony?
  - Wdrożyć governance module po fix
```

## Update — 2026-05-01 — puzzler-b2b cloud-detective snapshot (nowy) ✓

```
Projekt:    puzzler-b2b / PBMS (mako), account 698220459519, eu-west-2
Akcja:      cloud-detective v2 read-only scan (IaC + live AWS — pierwsze skanowanie)
Wynik:      20-projects/clients/mako/puzzler-b2b/puzzler-b2b-context.md (NOWY)
            context.md zachowany jako dokument historyczny (2026-04-22)

POZIOM PEWNOŚCI: częściowa
  - dev + QA: w pełni potwierdzone live (ECS, DocumentDB, SQS, alarms, ACM)
  - UAT / prod: niezweryfikowane

USTALENIA (vs context.md z 2026-04-22):
  ✅  QA wdrożone! (poprzednio: CHANGE_ME) — 9 serwisów, DocumentDB, SQS, 22 CW alarmy
  ✅  Brak alarmów w ALARM — środowisko OK
  ✅  Scheduler potwierdzony: AppAutoScaling (nie EventBridge) — start 07:00, stop 19:00 Warsaw
  ✅  Dev: 4 nowe serwisy vs poprzedni snapshot (builder, sync; front i worker zaktualizowane)
  ⚠️  QA jumphost DOWN — ECR image `infra-puzzler-b2b-app-qa:jumphost` not found w ECR
  ⚠️  Worker desired:0 (dev + QA) — nie objęty schedulerem; celowe czy błąd nieustalone
  ⚠️  CloudFront bez custom domain alias (dev only, brak aliasu CNAME)
  ⚠️  Tagging / WAF: niezweryfikowane

NASTĘPNY KROK:
  - Build + push ECR image jumphost dla QA
  - Wyjaśnić czy worker desired:0 jest celowe (brak obrazu? feature flag?)
  - Sprawdź ALB target health po 07:00 (po starcie schedulera)
```

---

## Update — 2026-05-01 — maspex cloud-detective snapshot v2 (re-scan) ✓

```
Projekt:    maspex (mako), account 969209893152, eu-west-1 + us-east-1 (ACM)
Akcja:      cloud-detective v2 re-scan (ECS, ALB target health, CW alarms, ACM, Secrets)
Wynik:      20-projects/clients/mako/maspex/maspex-context.md (zaktualizowany + brakujące sekcje dodane)

POZIOM PEWNOŚCI: częściowa
  - UAT: w pełni potwierdzony live (ECS, ALB bot target health, CW alarms)
  - preprod: ECS potwierdzone, przyczyna preprod-api DOWN zidentyfikowana
  - prod: niezweryfikowane

NOWE USTALENIA (vs poprzedni snapshot):
  🔴  preprod-api DOWN (0/3) — PRZYCZYNA: AccessDeniedException na secretsmanager:GetSecretValue
      execution role `maspex-preprod-api-execution` brak policy na `maspex/preprod/api-STbBy3`
      NAPRAWA: dodać policy secretsmanager:GetSecretValue do execution role
  ⚠️  Bot UAT alarm AKTUALNY (nie stale): 1 target unhealthy (FailedHealthChecks),
      1 w initial (RegistrationInProgress) — running:2/desired:1, możliwy cykl zastępowania
  ⚠️  ACM PENDING_VALIDATION twojkapsel-admin.makolab.pro — bez zmian (eu-west-1 + us-east-1)
  ⚠️  Tagging / WAF: niezweryfikowane (resourcegroupstaggingapi nie uruchomiono)

NASTĘPNY KROK:
  - Naprawić IAM: dodać secretsmanager:GetSecretValue do roli maspex-preprod-api-execution
  - Sprawdzić bot target health po 30 min — czy nowy task zarejestrował się zdrowo
  - Opcjonalnie: zwalidować DNS dla twojkapsel-admin.makolab.pro (PENDING_VALIDATION ACM)
```

---

## Update — 2026-05-01 — booking-online cloud-detective snapshot (nowy projekt) ✓

```
Projekt:    booking-online (mako), account 128264038676, eu-central-1 + us-east-1 (ACM)
Akcja:      cloud-detective v2 read-only scan (IaC infra-booking-online + live AWS)
Wynik:      20-projects/clients/mako/booking-online/booking-online-context.md (NOWY)

POZIOM PEWNOŚCI: częściowa
  - ECS prod: w pełni potwierdzony live (describe-services, describe-clusters)
  - ALB prod backend TG: target health healthy
  - ACM prod cert: ISSUED do 2026-10-30 (SANs: umowjazde.dacia.pl/renault.pl)
  - uat/qa/dev: potwierdzony cluster level, services level, Redis — bez per-TG target health

USTALENIA:
  ✅  4 env (prod/uat/qa/dev) — wszystkie 4 ECS clusters ACTIVE, 4/4 serwisy running/healthy
  ✅  CloudFront prod: Deployed + Enabled, cert ISSUED do 2026-10-30
  ⚠️  Redis stacks UPDATE_ROLLBACK_COMPLETE — WSZYSTKIE 4 środowiska (ryzyko przyszłych zmian)
  ⚠️  Log retention: 1 dzień we wszystkich env (hardcoded w ECS.yml)
  ⚠️  0 CloudWatch alarms — brak alertingu
  ⚠️  Tagging NO-GO — ECS/ALB/clusters bez tagów, tylko Env na ElastiCache
  ⚠️  0 WAF ACLs (Regional + CloudFront) — governance gap
  ⚠️  Redis 5.0.6 EOL, single node, brak backup
  ⚠️  ECS tasks w public subnets (brak NAT Gateway)
  ⚠️  Expired orphaned cert us-east-1 (EXPIRED 2022, InUseBy=[] — bezpieczny, do usunięcia)
  ⚠️  Prod stack name typo: bokingonline-prod (zamiast bookingonline-prod)

NASTĘPNY KROK:
  - Zbadać przyczynę Redis UPDATE_ROLLBACK_COMPLETE (describe-stack-events Redis stacks)
  - Wdrożyć log retention (minimum 30 dni dla prod)
  - Dodać tagi CFN: ECS.yml (Cluster, Service), ALB.yml (LoadBalancer, TG)
  - Rozważyć WAF dla CloudFront (prod)
```

---

## Update — 2026-05-01 — rshop cloud-detective snapshot v2 (re-scan) ✓

```
Projekt:    rshop (mako), account 943111679945, eu-central-1 + us-east-1 (ACM)
Akcja:      cloud-detective v2 re-scan (pełny — nowy szablon z WAF/FinOps/LLZ/ACM)
Wynik:      20-projects/clients/mako/rshop/rshop-context.md (zaktualizowany)

POZIOM PEWNOŚCI: częściowa
  - runtime prod/dev/akcesoria2: w pełni potwierdzony live AWS
  - ALB listener rules, ECR/log group tagi, SSM: niezweryfikowane

NOWE USTALENIA (vs poprzedni snapshot):
  ⚠️  Cert *.skleprenault.pl wygasa za 12 dni (2026-05-13) — ELIGIBLE do auto-renewal
  ⚠️  Cert dev.eshoprenault.lt EXPIRED us-east-1 (InUse=False — bezpieczny, do usunięcia)
  ⚠️  0 WAF ACLs — brak WAF zarówno REGIONAL jak i CLOUDFRONT
  ✅  Tagging prod: pełne LLZ tags (Owner/ManagedBy/CostCenter) ✅
  ⚠️  Tagging dev CFN stacks: brak Owner/ManagedBy/CostCenter
  ✅  ECS tag propagation: propagateTags=SERVICE potwierdzone
  ✅  Wszystkie serwisy ECS (10/10): desired=running=1 — produkcja ZDROWA

KORYGOWANE (vs poprzedni snapshot):
  - dev stack rollback → reklasyfikacja CRITICAL → WYSOKI (rollback zakończony, nie blokada)
  - 0 CloudWatch alarms → reklasyfikacja CRITICAL → WYSOKI (brak alarmów, nie aktywna awaria)
  - ACM certs: teraz potwierdzono live (us-east-1), 5 certów, 1 EXPIRED

NASTĘPNY KROK:
  - Monitorować auto-renewal cert *.skleprenault.pl (deadline: 2026-05-13)
  - Naprawić IAM jenkinsit: dodać rds:ModifyDBSubnetGroup
  - Wdrożyć AWS WAF
```

---

## Update — 2026-05-01 — rshop cloud-detective snapshot ✓

```
Projekt:    rshop (mako), account 943111679945, eu-central-1
Akcja:      cloud-detective v2 read-only scan (IaC infra-rshop + live AWS)
Wynik:      20-projects/clients/mako/rshop/rshop-context.md (nowy plik)

POZIOM PEWNOŚCI: częściowa
  - prod / dev / akcesoria2: potwierdzone live AWS
  - qa / uat: nieaktywne, repo rshop-cloudformation nie załadowane

🔥 KRYTYCZNE:
  1. dev stack (root) UPDATE_ROLLBACK_COMPLETE od 2026-04-28
     Root cause: jenkinsit brak rds:ModifyDBSubnetGroup
     Zablokowane: VPCStack, IAMStack, S3Stack
     Obejście: ECS deployowany bezpośrednio do dev-ECSStack (poza root)
  2. BRAK CloudWatch alarms — zero alertingu

POZOSTAŁE USTALENIA:
  - prod: 4/4 ECS serwisy 1/1, ALB active, RDS available — ZDROWE
  - dev: 4/4 ECS serwisy 1/1, ALB active — ZDROWE mimo rollback root stack
  - akcesoria2-prod: 2/2 ECS serwisy 1/1 — ZDROWE
  - RDS prod sqlserver-web t3.large; dev sqlserver-ex (Express Edition!) t3.small
  - IaC drift dev RDS: root-dev.yml default sqlserver-ee, live sqlserver-ex
  - 1-dniowa retencja logów prod (brak możliwości post-incident debugging)
  - Brak MultiAZ RDS (prod i dev) — single point of failure
  - Log group typos: /esc/backoffice, /ecs/jumhost-qa
  - S3 temp buckets: rshop-temp, rshop-tmp (do cleanup)
  - 2 Terraform state buckets (projekt CFN — skąd Terraform?)

DO WERYFIKACJI:
  - stan QA/UAT (klastry nie istnieją, repozytoria ECR tak)
  - certyfikaty ACM (us-east-1 — niezweryfikowane)
  - sekrety (SM puste — SSM? Jenkins?)
  - prod templates (rshop-cloudformation repo — nie załadowane)
  - jenkinsit IAM fix plan
```

## Update — 2026-05-01 — prompt library: cloud-detective template/invocation system ✓

```
CO ZROBIONO:
  - cloud-detective-v2.md → generyczny template (bez hardcoded projektu)
  - system parametrów: CLIENT, PROJECT, AWS_PROFILE, REPO_PATH, REGIONS, SAVE_PATH
  - guardrail: pliki invocation są manifestami parametrów, nie instrukcjami
  - nowe: 50-patterns/prompts/invocations/templates/cloud-detective-invocation-template.md
  - nowe: 50-patterns/prompts/invocations/cloud-detective-rshop.md
  - nowe: scripts/new-cloud-detective-invocation.sh (generator)
  - zaktualizowano: 50-patterns/prompts/README.md

JAK UŻYĆ DLA NOWEGO PROJEKTU:
  scripts/new-cloud-detective-invocation.sh \
    --client mako --project <PROJEKT> --aws-profile <PROFIL> \
    --repo-path ~/projekty/mako/aws-projects/infra-<PROJEKT> \
    --regions eu-central-1

JAK URUCHOMIĆ W CLAUDE:
  "Użyj @50-patterns/prompts/invocations/cloud-detective-<PROJEKT>.md
   jako manifestu parametrów i wykonaj prompt_template."
```

## Update — 2026-05-01 — maspex cloud-detective v2 scan ✓

```
Projekt:    maspex (Kapsel, Maspex klient)
Akcja:      cloud-detective v2 read-only scan (IaC + live AWS)
Wynik:      20-projects/clients/mako/maspex/maspex-context.md (nowy plik)

TOP USTALENIA:
  - maspex-preprod-api: desired:3, running:0 — API nie startuje w preprod
  - twojkapsel-admin.makolab.pro: cert PENDING_VALIDATION (eu-west-1 + us-east-1)
  - maspex-uat-alb-unhealthy-hosts-bot alarm w ALARM od 23/04 (stary, wymaga weryfikacji)
  - Container Insights retencja 1 dzień (za krótka do post-incident debugging)
  - contest-service log groups bez serwisu ECS (relikt?)

DO WERYFIKACJI:
  - dlaczego preprod-api nie startuje (ecs list-tasks --desired-status STOPPED)
  - stan prod env (IaC istnieje w envs/prod/, live nieweryfikowane)
  - walidacja DNS dla twojkapsel-admin.makolab.pro
  - bot target health (verify alarm aktualności)
  - pokrycie Secrets Manager (tylko 1 secret widoczny)
```

## Update — 2026-04-30 — devops-toolkit FinOps live/UI + LLZ WAF readonly merged ✓

```
Stan:       ZMERGOWANE / MAIN SYNC
Repo:       ~/projekty/devops/devops-toolkit
Branch:     main

ZMERGOWANE PR:
  #58 feat(finops): add live mode to reports and operator UI
      merge commit: 9745e9a
      - CLI: finops-report --mode live|snapshot
      - CLI: --period custom + --start/--end
      - pipeline: mode -> resolve_period() -> build_finops_model()
      - report: Jakość danych, Estimated=true jako warning
      - Tax: non-operational cost, poza top services
      - UI: period mtd|last-full-month|custom, mode live|snapshot, helper messages

  #59 feat(audit): add LLZ WAF read-only pack
      merge commit: ff9cd46
      - pack: llz-waf-readonly
      - plugins: llz-guardduty, llz-scp, llz-cloudtrail, llz-config,
        llz-tagging, llz-observability
      - plugin: cfn-messaging-audit
      - tests: llz pack + cfn messaging audit

TESTY:
  make contract-check: PASS
  tests/unit/test_llz_waf_readonly_pack.py + test_cfn_messaging_audit.py: 149 passed
  tests/test_operator_console_v3.py: 15 passed
  tests/unit -k "ui or finops or report": PASS poza sandboxem

STAN KOŃCOWY:
  devops-toolkit main == origin/main
  git pull: Already up to date
  tracked worktree: clean

NASTĘPNY KROK:
  1. Manualny smoke UI:
     toolkit ui --project-root /path/to/project --port auto --no-open
     FinOps -> Custom range -> mode Live -> group by Service -> Markdown
  2. Manualny smoke CLI z aktywnymi AWS credentials:
     toolkit finops-report rshop --period custom --start 2026-04-01 --end 2026-05-01 --mode live --audience executive --group-by service --format md
  3. Opcjonalnie dopiąć dokumentację/command catalog dla llz-waf-readonly.
```

## Update — 2026-04-30 — devops-toolkit FinOps Reporting Contract [Task 4/8 DONE]

```
Stan:       W TOKU — przerwane po Task 4
Branch:     feat/finops-reporting-contract
Repo:       ~/projekty/devops/devops-toolkit
Spec:       docs/superpowers/specs/2026-04-30-finops-reporting-contract-design.md
Plan:       docs/superpowers/plans/2026-04-30-finops-reporting-contract.md

COMMITY NA BRANCHU:
  73123fc feat(finops): add snapshot/live mode and billing_lag to ReportingPeriod
  d24a291 feat(finops): surface CE Estimated flag in raw collect output
  ccbe6ed fix(finops): use any() for estimated flag across multi-month CE results
  d19d5ac feat(finops): add reconciliation module with R1-R5 rules and ReconciliationResult
  087282e test(finops): assert R5 severity is data_quality not warning
  68c84fc feat(finobs): wire operational_cost and R1-R5 reconciliation into build_finops_model
  3fffd2e refactor(finobs): remove redundant tagging_cost_coverage override and stale comment

ZROBIONE:
  Task 1: periods.py — mode/billing_lag/settled_days + EMPTY_WINDOW guard ✓
  Task 2: collect.py — Estimated flag detection (any() dla multi-month) ✓
  Task 3: reconciliation.py (nowy) — R1-R5, compute_operational_cost, ReconciliationResult ✓
  Task 4: normalize.py — operational_cost + non_operational_costs + reconciliation wired ✓

POZOSTAŁO:
  Task 5: report_model.py — data_quality_warnings + reconciliation_results sections
  Task 6: config/finops.yaml — mode/billing_lag_days/r3_tolerance defaults
  Task 7: commands/finobs_report.py — CLI flags, immutable snapshots, exit codes
  Task 8: integration tests

NASTĘPNY KROK:
  Wznów od Task 5 — dispatcher gotowy do uruchomienia subagenta.
  Metoda: subagent-driven-development (1 subagent per task + 2x review).

WAŻNE KONTRAKTY:
  cost_total    = AWS CE UnblendedCost INCLUDING Tax/Credit/Refund
  operational_cost = derived = cost_total - non_op_subtotal
  snapshot mode = End = today - billing_lag_days (default 2), deterministyczny
  live mode     = real-time, explicitly non-deterministic
```

## Update — 2026-04-30 — rshop FinOps CE report odtworzony ✓

```
Stan:       ZAPISANE
Aktywny:    rshop
Zakres:     FinOps / AWS Cost Explorer / MTD 2026-04

CO ZROBIONO:
  Odtworzono raport FinOps dla konta rshop z AWS Cost Explorer.
  Dane ograniczone do linked account:
    account_id: 943111679945
    profile:    mako-dc
    period:     2026-04-01 -> 2026-05-01
    metric:     UnblendedCost
    currency:   USD

WYNIK:
  total_cost:       959.9595635723 USD
  tagged_cost:      482.6346604088 USD
  untagged_cost:    477.3249031635 USD
  tagged coverage:  50.2766%
  untagged:         49.7234%
  reconciliation:   OK, difference = 0.0

TREND / DELTA:
  previous month:   1114.3550446539 USD
  delta:            -154.3954810816 USD (-13.8551%)
  avg daily 30d:    31.9986521191 USD
  avg last 7d:      22.1434649561 USD
  forecast 30d:     664.3039486830 USD

ARTEFAKTY:
  - artifacts/rshop-finops-2026-04/rshop-finops-2026-04.model.json
  - artifacts/rshop-finops-2026-04/rshop-finops-2026-04.report.md
  - artifacts/rshop-finops-2026-04/ce-*.json

UWAGA:
  Cost Explorer zwrócił Estimated=true dla bieżącego okresu.
  Komendy CE zostały doprecyzowane filtrem LINKED_ACCOUNT=943111679945,
  bo profil mako-dc działa z poziomu management/org access.

NASTĘPNY KROK RSHOP:
  1. Jeśli raport idzie do klienta/LLZ, traktować kwiecień jako estimated do zamknięcia billing cycle.
  2. Wrócić do ECS PropagateTags / EnableECSManagedTags jako osobnego zadania po stabilizacji deploy boundary.
```

## Update — 2026-04-30 — devops-toolkit FinOps hardening + AI boundary guard

```
Stan:       BRANCH GOTOWY / CZEKA NA PR
Branch:     feat/finops-hardening-ai-boundary
Repo:       ~/projekty/devops/devops-toolkit

CO ZROBIONO:
  P0: CostRecord dataclass (toolkit/finops/cost_record.py)
      - canonical typed model bridging legacy + modern FinOps pipeline
      - from_legacy_summary() + from_modern_service() factory functions
      - normalize-cost.py używa CostRecord wewnętrznie; JSON output niezmieniony
      - toolkit/finops/normalize.py: dodano to_cost_records()
  P1: AI boundary enforcement (toolkit/ai_boundary.py)
      - BoundaryViolationError(RuntimeError) — enforcement, nie helper
      - assert_ai_safe_path(path) — guard oparty na Path.parts
      - whitelist: {"sanitized", "findings"} — kod zamiast konwencji
      - guard podłączony do: evaluate-rules.py, rules-engine.py, finops_report.py
  P2: [inspect]/[audit]/[apply] prefiksy w help= CLI (7 komend)
  Testy: 175 nowych, 3451 pass, 9 fail pre-existing (test isolation na main)
  make contract-check: PASS

NASTĘPNY KROK:
  1. Otworzyć PR: feat/finops-hardening-ai-boundary → main
```

## Update — 2026-04-30 — Maspex /email/* CloudFront behavior ✓

```
Stan:       DONE / WDROŻONE
Aktywny:    pbms

MASPEX UAT — CO ZROBIONO:
  Zmiana: nowy ordered_cache_behavior /email/* na dystrybucji E3J76RNXIE2YIG (kapsel.makotest.pl)
  Pliki:
    - terraform/envs/uat/terraform.tfvars: "/email/*" dodane do api_cloudfront_static_paths
    - terraform/envs/uat/main.tf: "/email/*" dodane do static_path_origin_request_policy_ids
  Policy reuse: static_assets cache policy (ab5d9518...) + Managed-AllViewer ORP (216adef6...)
  Apply: 0 added, 1 changed, 0 destroyed — 33s
  Weryfikacja: Miss → Hit from cloudfront, Age: 12 ✓
```

## Update — 2026-04-30 — PBMS jumphost-v5 wdrożony ✓

```
Stan:       ZAPISANE / PRZEŁĄCZAM NA MASPEX
Aktywny:    maspex

PBMS JUMPHOST — CO ZROBIONO:
  Obraz:
    - Dockerfile: infra-puzzler-b2b-final/Dockerfile (alpine:3.19 + sshd)
    - Tag: jumphost-v5
    - Push: infra-puzzler-b2b-app-dev:jumphost-v5 ✓
    - Push: infra-puzzler-b2b-app-qa:jumphost-v5 ✓
    - Digest: sha256:e34a3627...

  tfvars zaktualizowane:
    - envs/dev/terraform.tfvars: v1 → jumphost-v5
    - envs/qa/terraform.tfvars:  jumphost + BLOCKER usunięty → jumphost-v5

  Terraform apply dev (targeted — TYLKO jumphost):
    - task definition: infra-puzzler-b2b-dev-jumphost rev 3 → nowa ✓
    - ECS service: wskazuje na nową task def ✓
    - Pominięte (state drift): delivery/notifier/sync mają wyższe rewizje w ECS niż w state
      delivery: ecs:53 vs tf:30 | notifier: ecs:53 vs tf:30 | sync: ecs:10 vs tf:1

  Secrets Manager fix:
    - Sekret był: {"authorized_keys":"$(cat ~/.ssh/id_rsa.pub)"} — literalny string
    - Poprawiono na: prawdziwy klucz id_rsa.pub
    - Force redeploy: nowy task IP = 18.175.150.59 (zmienił się po restarcie!)

  Scripts db-connect:
    - db-connect.sh: dynamiczny (AWS CLI → ENI → public IP) — przetestowany ✓ tunel 27017 OK
    - db-connect.ps1: zaktualizowany hardcoded IP na 52.56.205.122 (był 18.134.180.75)
      uwaga: IP zmienia się przy każdym restarcie taska — dev ustawia przez $env:JUMPHOST_HOST
    - db-connect.cmd: bez zmian (wrapper)

  QA: tfvars OK, terraform apply QA nie wykonany.
  State drift: NIE naprawiony (osobna sesja).
```

## Update — 2026-04-30 — rshop działa ✓

```
Stan:       OPERACYJNY
Aktywny:    rshop
Tryb:       mitigation CFN-MUT-001 potwierdzona, serwisy healthy

RSHOP STATUS:
  rshop-dev-api-svc:      running=1 healthy (image api.1252, task:1040)
  rshop-dev-backoffice-svc: running=1 healthy (image backoffice.1252, task:1039)
  frontends (svc1/svc2):  running=1 healthy
  Mitigation ECSStack-only deploy: POTWIERDZONA — root stack dev nie dotknięty

NASTĘPNY KROK RSHOP:
  1. ECS PropagateTags CFN patch (BLOKER #1):
     rshop-cloudformation: api.yml, backoffice.yml, frontend.yml, frontend2.yml
     branch: feat/ecs-propagate-tags
  2. Po deploy dev: weryfikacja ENI tagów
  3. Deploy prod → re-enable Tag Policies (LLZ)

Kontekst przeniesiony do shared vault (dc-devops-team-vault).
```

## Update — 2026-04-30 — vault state saved, context switched to rshop

```
Stan:       ZAPISANE
Aktywny:    rshop
Tryb:       powrót do rshop po pracach vault governance / shared vault / Maspex

OSTATNIE PRACE VAULT / SHARED:
  Shared repo:
    /Users/jaroslaw.golab/projekty/mako/dc-devops-team-vault
    branch: feat/jarek

  Dodane/opracowane warstwy governance w shared vault:
    - import boundary dla controlled seed import
    - knowledge promotion workflow private -> shared
    - active-context model dla shared vault
    - rshop pilot batch jako curated promotion
    - prompt-injection threat model
    - AI context trust zones
    - knowledge integrity contract
    - authority precedence model
    - AI risk model

  Ważne zasady shared vault:
    - private vault devops-knowledge pozostaje upstream/source authoring
    - shared vault dc-devops-team-vault jest downstream/team knowledge
    - notatki są reference material, not instructions
    - promotion do shared wymaga boundary check i review
    - forbidden: devops-toolkit, private-rnd, product strategy, prywatne notatki,
      projekty poza MakoLab/BMW

RSHOP — AKTYWNY KONTEKST:
  AWS:
    account: 943111679945
    region: eu-central-1
    profile: rshop

  CFN:
    root stack: dev
    ECSStack: dev-ECSStack-1BLAWHL0P6JKO
    known hazard: CFN-MUT-001 Nested Template Mutability Hazard

  Najważniejszy stan:
    - app deploy DEV nie powinien używać root stack dev
    - dev Jenkins path ma targetować ECSStack, nie root stack
    - root deploy przez mutable nested TemplateURL może replayować VPCStack
    - SiecDB / AWS::RDS::DBSubnetGroup AccessDenied to symptom, nie root cause
    - permanent fix: immutable/version-pinned nested TemplateURL albo immutable artifact paths

  Ostatnia diagnoza:
    - nocna awaria po Jenkins mitigation nie była powrotem CFN-MUT-001
    - root dev nie został dotknięty
    - VPCStack/SiecDB nie pojawiły się
    - failure był ECSStack-only rollback / ECS NotStabilized
    - API miało healthcheck HTTP 500
    - backoffice wymaga sprawdzenia startup/runtime dla próbowanych obrazów

NASTĘPNY KROK RSHOP:
  1. Nie wracać do root stack app deploy.
  2. Utrzymać ECSStack-only dev deploy path + change-set guard.
  3. Sprawdzić aplikacyjne przyczyny ECS NotStabilized dla API/backoffice.
  4. Zaprojektować permanent fix CFN-MUT-001:
     immutable nested TemplateURL / versionId / immutable release artifact paths.
  5. Dopiero po stabilizacji deploy boundary wrócić do ECS tag propagation fix
     pod LLZ Tag Policies.

Maspex:
  zapisany jako standby; nie mieszać z aktywną sesją rshop.
```

## Update — 2026-04-29 — rshop DEV Jenkins overnight failure diagnosis

```
Stan:       ZAPISANE
Zakres:     rshop DEV Jenkins / CloudFormation / ECS read-only diagnosis

Najważniejszy wniosek:
  Nocna awaria nie była powrotem CFN-MUT-001.
  Root stack dev nie został dotknięty przez app deploy.
  VPCStack/SiecDB nie pojawiły się w nocnej ścieżce awarii.

AWS EVIDENCE:
  Root stack:
    dev = UPDATE_ROLLBACK_COMPLETE
    LastUpdatedTime = 2026-04-28T16:41:09Z
    brak nowych nocnych zdarzeń root/VPC/SiecDB

  ECSStack:
    dev-ECSStack-1BLAWHL0P6JKO = UPDATE_ROLLBACK_COMPLETE
    UPDATE_IN_PROGRESS User Initiated = 2026-04-28T21:46:07Z
    UPDATE_ROLLBACK_IN_PROGRESS = 2026-04-29T00:46:22Z
    UPDATE_ROLLBACK_COMPLETE = 2026-04-29T00:54:05Z

  Leaf failure:
    api child stack -> ApiSvc UPDATE_FAILED
      Resource handler returned message: "Exceeded attempts to wait"
      HandlerErrorCode: NotStabilized

    backoffice child stack -> BackofficeSvc UPDATE_FAILED
      Resource handler returned message: "Exceeded attempts to wait"
      HandlerErrorCode: NotStabilized

ECS CURRENT STATE:
  rshop-dev-api-svc:
    desired=1 running=1 pending=0 rollout=COMPLETED
    task definition dev-api-task:1040
    image api.1252
    target health healthy

  rshop-dev-backoffice-svc:
    desired=1 running=1 pending=0 rollout=COMPLETED
    task definition dev-backoffice-task:1039
    image backoffice.1252
    target health healthy

  Frontends:
    unchanged, running healthy

RUNTIME SIGNALS:
  API podczas nieudanego rollout miało ALB healthcheck failures HTTP 500.
  Backoffice miało powtarzane replacement/registration/draining events.
  Późniejszy list-tasks --desired-status STOPPED nie zwrócił task ARN,
  więc szczegóły stopped task containers nie były dostępne w późnym odczycie.

JENKINS LOG:
  Nie znaleziono lokalnego aktualnego console logu z tej nocy.
  Znalezione pliki #1292 dev.txt i #1342 dev.txt są stare i pokazują dawny root deploy,
  więc nie są dowodem dla tej awarii.

KLASYFIKACJA:
  - Jenkins-only failure: NIE
  - CloudFormation rollback: TAK, ograniczony do ECSStack
  - ECS/application rollout failure: TAK
  - guard failure: brak dowodu
  - AWS CLI/Jenkins sandbox issue: brak dowodu
  - CFN-MUT-001 recurrence: NIE

ZAPIS TRWAŁY:
  - 40-runbooks/incidents/rshop-dev-ecsstack-rollback-2026-04-29.md

NASTĘPNY KROK:
  1. Nie rerunować ślepo.
  2. Sprawdzić logi aplikacyjne dla obrazów próbowanych w tym rollout:
     API healthcheck 500 i backoffice startup/runtime.
  3. Utrzymać app deploy path przez ECSStack, nie root dev.
  4. Permanentnie naprawić CFN-MUT-001 przez immutable TemplateURL / artifact paths.
```

## Podsumowanie dnia — 2026-04-28

```
Stan:       ZAPISANE
Zakres:     rshop forensics + AI Cost Optimization governance + reusable CFN runbook pattern

RSHOP:
  - Zdiagnozowano fail deployu DEV po execute-change-set:
    pierwsza realna awaria = VPCStack / SiecDB / AWS::RDS::DBSubnetGroup
    błąd = AccessDenied na rds:ModifyDBSubnetGroup dla usera jenkinsit
  - Ustalono, że IAM nie jest root cause, tylko symptomem ukrytej mutacji infra.
  - Forensics wykazał pattern:
    app-only deploy -> root stack update -> mutable nested TemplateURL -> nowszy vpc-dev.yml z S3
    -> tag delta na zasobach VPC/SiecDB -> próba ModifyDBSubnetGroup.
  - Drift check VPCStack: IN_SYNC, SiecDB PropertyDifferences=[].
  - Wniosek operacyjny:
    NIE dodawać ślepo rds:ModifyDBSubnetGroup; najpierw wyeliminować hidden VPCStack mutation
    albo jawnie zatwierdzić infra/tag rollout.

UTWORZONE / ZAKTUALIZOWANE:
  - 20-projects/clients/mako/rshop-tagging-remediation-2026-04-24.md
    dopisano DEV CFN deploy failure + forensics mutable TemplateURL.
  - 40-runbooks/aws/cloudformation-nested-template-mutability-hazard.md
    nowy reusable runbook pattern: CFN-MUT-001 Nested Template Mutability Hazard.
  - _system/AI_COST_AWARE_AGENT_CONTRACT.md
    nowy kontrakt Cost-Aware Agent Execution Policy / AI FinOps lite.
  - AGENTS.md, CLAUDE.md, CODEX.md, LLM_CONTEXT_GLOBAL.md, CHATGPT_WORKFLOW.md,
    _chatgpt/README.md, _chatgpt/templates/context-pack-template.md
    minimalne addytywne linki do cost-aware contract.
  - 100-ai-cost-optimization/prompts/
    przenośna biblioteka promptów 01-06 + README dla rollout/audit/context optimization/model tiering/AI FinOps.

NASTĘPNY KROK RSHOP:
  1. Nie retry root app deploy dopóki VPCStack mutation nie jest wyjaśniona/wyeliminowana.
  2. Rozdzielić app deploy od infra/tag rollout albo przypiąć nested TemplateURL do immutable artifactu.
  3. Dopiero potem wrócić do pierwotnego ECS PropagateTags/EnableECSManagedTags fix.

NIE RUSZANE:
  - .obsidian/workspace.json — zmiana lokalnego workspace Obsidian
  - 10-areas/private/Subskrypcje.md — osobna nieśledzona notatka
```

## Update — 2026-04-28 wieczór — rshop CFN-MUT-001 Jenkins mitigation

```
Stan:       ZAPISANE
Zakres:     rshop DEV deploy path mitigation w eshop-cicd Jenkinsfiles

AWS / CFN:
  - Root stack dev po kolejnych testach Jenkins ponownie reprodukował CFN-MUT-001:
    app-intended root deploy -> VPCStack -> SiecDB -> rds:ModifyDBSubnetGroup AccessDenied.
  - Minimalny recovery pattern nadal: continue-update-rollback z resources-to-skip:
    dev-VPCStack-FFQTYHECIX9M.SiecDB.
  - Cascade resources typu RouteTables / InternetGateway miały "Resource update cancelled";
    nie są samodzielnym powodem do rozszerzania skip listy bez świeżego evidence.

ECS HOTFIX TEST:
  - ECSStack-only change set 1253 został reviewowany i wykonany kontrolowanie.
  - Runtime 1253 nie był stabilny:
    API 1253 -> ALB healthcheck HTTP 500.
    Backoffice 1253 -> EssentialContainerExited / exit code 139.
  - CFN/ECS może zostawiać nowe TaskDefinition revisions po rollbacku;
    UPDATE_ROLLBACK_COMPLETE nie oznacza automatycznie runtime quiescence.

JENKINS MITIGATION:
  Repo: ~/projekty/mako/eshop-cicd
  Pliki zmienione:
    - jenkinsfiles/BE/eshop-dev-aws.jenkinsfile
    - jenkinsfiles/BE/eshop-dev-aws-scan-2.jenkinsfile

  Co zmieniono:
    - dla params.Envi == 'dev' CloudFormation target = dev-ECSStack-1BLAWHL0P6JKO
      zamiast root stack dev
    - qa/uat zostają na dotychczasowym UpEnv/root flow
    - dev używa ECSStack params: apiimg/backofficeimg lowercase + reszta UsePreviousValue
    - dev nie wysyła root-only params: ALBDNS, DB, CF cert/domain, Engine*, DeployDB
    - dev create-change-set ma --include-nested-stacks
    - dodany pre-execute guard blokujący VPCStack/DBStack/SGStack/IAMStack/S3Stack/CFStack/SiecDB
      oraz AWS::EC2/RDS/IAM/S3/ElasticLoadBalancingV2
    - allowed dev scope: api/backoffice nested stacks + AWS::ECS::TaskDefinition/AWS::ECS::Service

Review:
  - eshop-dev-aws-scan-2.jenkinsfile przeszedł review PASS dla:
    dev stack target, qa/uat unchanged, lowercase ECS params, no root-only dev params,
    include-nested-stacks, guard before execute, execute/wait using CfnStackName,
    changeSetIdBackend scoping unchanged.

Następny krok:
  - Kontrolowany Jenkins test dev po upewnieniu się, że root dev/ECSStack nie są w toku.
  - Nadal traktować to jako mitigation deployment path, nie permanent fix.
  - Permanent fix: immutable nested TemplateURL pinning / release artifact paths + runtime guard.
```

## Aktywne teraz: rshop — Tag Policy remediation

```
Stan:       KONTEKST PRZEŁĄCZONY (2026-04-28)
Cel:        przygotować CFN fix dla ECS Tag Policy readiness przed re-enable LLZ Tag Policies

Wejście:
  - 02-active-context/current-focus.md
  - _chatgpt/context-packs/rshop-tag-policy.md
  - 40-runbooks/incidents/rshop-tag-policy-readiness.md
  - 20-projects/clients/mako/rshop-tagging-baseline-2026-04-24.md

Następny krok:
  1. Przetestować Jenkins dev path po mitigation: app deploy ma iść do dev-ECSStack-1BLAWHL0P6JKO, nie root dev
  2. Utrzymać zakaz root stack app deploy do czasu immutable TemplateURL pinning / release artifact paths
  3. Po stabilnym deploy boundary wrócić do ECS PropagateTags/EnableECSManagedTags fix

Maspex:
  zapisany jako standby; nie mieszać z bieżącą sesją rshop.
```

## Standby: Maspex — load test analysis + Terraform observability/WAF work

```
Stan:       ZAPISANE / STANDBY (2026-04-28 późny wieczór)
Repo:       ~/projekty/mako/aws-projects/infra-maspex
Env:        terraform/envs/uat
AWS:        profile maspex-cli, region eu-west-1, account 969209893152

LOAD TEST REPORT:
  - Utworzono raport:
    20-projects/clients/mako/maspex/load-test-analysis-2026-04-28-1730-cest.md
  - Okno analizy: 2026-04-28 15:15-16:15 UTC, rozszerzone 15:00-16:30 UTC.
  - Wniosek: ruch testowy widoczny głównie 15:40-16:00 UTC.
    CloudFront ~1.04M requests, ALB/API ~575k requests.
  - Brak potwierdzonej saturacji ECS / ALB / Redis.
  - Autoscaling API nie skalował, bo CPU/memory były poniżej progów.
  - Luka: brak CloudFront CacheHitRate/OriginRequests/OriginLatency datapoints
    oraz brak per-path metrics dla /api/slogan, /_next/image*, /_next/static/*.

TERRAFORM CHANGES PREPARED, NOT APPLIED:
  Repo ma lokalne zmiany:
    - terraform/envs/uat/main.tf
    - terraform/envs/uat/waf.tf
    - terraform/envs/uat/cloudfront_observability.tf
    - terraform/modules/cloudfront-site/main.tf
    - terraform/modules/cloudfront-site/variables.tf

  Implementacja:
    - CloudFront module dostał opcjonalne web_acl_id.
    - UAT admin CloudFront ma dostać WAFv2 CLOUDFRONT allowlist:
      195.117.107.110/32, 91.233.19.251/32.
    - WAF tworzony przez provider aws.us_east_1, scope CLOUDFRONT.
    - API CloudFront nie jest ograniczane WAF-em.
    - Observability: Athena database + Glue table nad istniejącymi CloudFront standard logs
      z prefixu s3://maspex-uat-access-logs-969209893152/cloudfront/maspex-uat/api/
      oraz named query grupujące /api/slogan, /_next/image*, /_next/static/* po x_edge_result_type.

VALIDATION:
  - terraform fmt dla zmienionych plików: OK.
  - terraform validate w terraform/envs/uat: OK.
  - terraform plan: BLOKADA backendu remote state, nie błąd kodu.

REMOTE STATE BACKEND DIAGNOSIS:
  Backend UAT:
    bucket = terraform-state-969209893152
    key = maspex/uat/terraform.tfstate
    dynamodb_table = terraform-locks-969209893152
    region = eu-west-1

  Evidence:
    - S3 latest state exists, versioning enabled.
    - S3 latest LastModified: 2026-04-28T06:46:38Z
    - S3 latest ETag / local md5: 891cfb7b5e1475192a717c12ca9fae1a
    - State parses as Terraform state v4, Terraform 1.5.7, serial 123, resources 97.
    - DynamoDB UAT md5 item:
      LockID = terraform-state-969209893152/maspex/uat/terraform.tfstate-md5
      Digest = 48a21bb5c16aa5ce693a2734910bd456
    - Brak aktywnego lock itemu bez suffixu -md5.
    - Digest 48a21... odpowiada starej wersji S3 z 2026-04-23T10:00:16Z.
    - shared i preprod mają digest zgodny z aktualnym S3 ETag.

  Wniosek:
    Najbardziej prawdopodobny root cause = stary/osierocony digest w DynamoDB
    dla UAT, nie uszkodzony state.

  Safe recovery, DO NOT RUN automatically:
    conditional update tylko rekordu Digest:
      old = 48a21bb5c16aa5ce693a2734910bd456
      new = 891cfb7b5e1475192a717c12ca9fae1a
    Wykonać dopiero po freeze Terraform dla UAT i ponownym prechecku S3/DDB.

NIE ROBIĆ:
  - nie apply Terraform przed zdrowym planem
  - nie usuwać locków
  - nie cofać wersji S3 state
  - nie edytować state ręcznie
  - nie aktualizować digest bez condition-expression i świeżego prechecku

POWRÓT DO MASPEX:
  1. Precheck S3 head-object + DDB get-item + brak lock itemu.
  2. Conditional update DDB digest, jeśli ETag nadal 891cfb...
  3. terraform init -reconfigure -backend-config=backend.hcl
  4. terraform validate
  5. terraform plan -no-color
  6. Review plan: expected add WAF/IPSet/Athena/Glue + in-place web_acl_id only on admin CF.
```

## Zamknięte: vault — CloudOps/SOC-lite discovery thread ✓

```
Stan:       DONE (2026-04-24)
Lokalizacja: 20-projects/internal/cloudops-soc-lite/

Utworzone:
  README.md                           — discovery index + exploratory kanban
  CLOUDOPS_SOC_LITE_HYPOTHESIS.md     — geneza, working hypothesis (Prevent/Detect/Respond)
  EXISTING_CAPABILITIES_AS_FOUNDATION.md — mapa GLPI/Wazuh/Nagios/on-call + current/future-state diagram
  PILOT_IDEA_GLPI_CLOUD_EVENTS.md     — minimalny pilot: AWS Health → GLPI + GuardDuty → Wazuh
  INCUBATION_STRATEGY.md              — small-circle first; 3 fazy dogfooding→internal→customer-facing
  CONNECTION_TO_LLZ_AND_NIS2.md       — LLZ jako Prevent layer, NIS2 kontekst, audytowalność

Kluczowe hipotezy:
  - Nie "SOC", lecz CloudOps visibility capability na istniejącym stacku
  - Prevent (LLZ) → Detect (Wazuh + AWS findings) → Respond (GLPI + on-call)
  - Adoption before branding — najpierw dogfooding przez Cloud Support Team
  - AWS Health → GLPI Problems jako minimalny pilot (Lambda bridge + EventBridge)

Powiązania:
  ↔ 20-projects/internal/cloud-support-as-a-service/
  ↔ 20-projects/internal/llz/
  ↔ 10-areas/observability/
```

## Zamknięte: vault — governance layer knowledge boundaries ✓

```
Stan:       DONE (2026-04-24)
Zakres:     separacja domen BMW / Cloud Support as a Service / private-rnd / shared-concept

Utworzone:
  _system/:
    KNOWLEDGE_BOUNDARIES.md     — mapa domen, szybka reguła decyzyjna
    CLASSIFICATION_MODEL.md     — 7 klas domen + 4 klasy wrażliwości + dopuszczalne wartości frontmatter
    DOMAIN_ISOLATION_CONTRACT.md — 7 reguł MUST/MUST NOT
    LLM_CONTEXT_BOUNDARY_CONTRACT.md — zasady sesji LLM: jedna sesja = jedna domena
    ORIGIN_METADATA_CONTRACT.md — obowiązkowy frontmatter dla nowych notatek
    DERIVATIVE_INSIGHT_RULES.md — legalna ścieżka przeniesienia wiedzy z client-work
    PROMPT_BOUNDARY_CHECKLIST.md — 12 pytań przed każdym promptem do LLM
    BOUNDARY_REVIEW_REPORT.md   — raport audytowy + akcje ręczne do wykonania

  20-projects/clients/bmw/ai-taskforce/ — 8 plików (scaffold klientowski)
  20-projects/internal/cloud-support-as-a-service/ — 8 plików (scaffold strategii)
  60-toolkit/cloud-detective/ — research-boundaries.md + ai4devops-relationship.md

Zaktualizowane:
  30-research/ai4devops/README.md — frontmatter + kontrakt domeny + callout boundary
  _system/LLM_CONTEXT_GLOBAL.md — zasada globalna: jedna sesja = jedna domena
  00-start-here/how-to-use-this-vault.md — sekcja Knowledge safety model

Oczekujące (ręczne — z BOUNDARY_REVIEW_REPORT.md):
  - Dodać frontmatter do 20-projects/clients/mako/*/troubleshooting.md
  - Dodać frontmatter do _chatgpt/context-packs/*.md
  - Przejrzeć 90-reference/notebooklm/
  - Rozstrzygnąć klasyfikację llz/ (internal-product-strategy vs private-rnd)
  - Dodać frontmatter do 60-toolkit/README.md i kontraktów komend
```

## Zamknięte: vault — AI4DevOps research space ✓

```
Stan:       DONE (2026-04-24)
Lokalizacja: 30-research/ai4devops/

Utworzone:
  README.md                    — mapa pojęć, hipotezy, relacje z LLZ/toolkit
  AI4DEVOPS_REFERENCE_MODEL.md — 5-warstwowa architektura referencyjna
  ITSM_AI_OPPORTUNITIES.md     — mapa 6 procesów ITIL × AI
  VENDORS_AND_PATTERNS.md      — Dynatrace/IBM/PagerDuty/ServiceNow/Moogsoft
  AI_SECURITY_IN_DEVOPS.md     — prompt injection, agent security, guardrails
  CLOUD_DETECTIVE_CONNECTIONS.md — hipotezy ewolucji cloud-detective
```

## Zamknięte: puzzler-b2b — sync + builder IaC ✓

```
Stan:       DONE (2026-04-24)
Repo:       ~/projekty/mako/aws-projects/infra-puzzler-b2b-final
Zakres:     envs/dev — nowe serwisy Sync i Builder za gateway

Zmiany:
  - services.tf: module "sync_service" (L343) + module "builder_service" (L384)
  - service_discovery.tf: pbms-sync-dev.pbms.local + pbms-builder-dev.pbms.local
  - variables.tf: sync_image + builder_image (default nginx:latest)
  - terraform.tfvars: placeholders z # BLOCKER

Walidacja: terraform validate → SUCCESS
terraform plan: wymaga aktywnej sesji AWS (puzzler-pbms)

BLOCKER: Ocelot routes + SwaggerForOcelot są w kodzie gateway (pbms-backend),
nie w tym repo. Dev team musi dodać w ocelot.json:
  /sync/{everything} → pbms-sync-dev.pbms.local:8080/{everything}   [SwaggerKey: Sync]
  /builder/{everything} → pbms-builder-dev.pbms.local:8080/api/{everything}   [SwaggerKey: Builder]

BLOCKER: zastąp nginx:latest docelowymi URI ECR po zbudowaniu obrazów
Notatka: 20-projects/clients/mako/puzzler-b2b/troubleshooting.md
```

## Zamknięte: maspex — CloudFront / observability infra sprint ✓

```
Stan:       DONE (2026-04-24) — terraform apply wykonany
Repo:       ~/projekty/mako/aws-projects/infra-maspex
Branch:     feat/preprod-zaslepka
Env:        UAT | AWS profile: maspex-cli | Region: eu-west-1

Co wdrożono (terraform apply — 5 added, 2 changed, 0 destroyed):

  CloudFront `E3J76RNXIE2YIG` (kapsel.makotest.pl):
    - nowy behavior `/_next/image*` → cache policy image_optimizer (QS=all, min_ttl=0, default=86400)
    - nowy behavior `/favicon.ico` → cache policy static_assets (86400s)
    - /favicon.ico walidacja: Hit from cloudfront ✓ | Cache-Control: max-age=31536000

  CloudWatch monitoring:
    - metric filter RedisCircuitOpenCount + alarm maspex-uat-api-redis-circuit-open
    - dashboard rows 11-12: CF CacheHitRate / OriginRequests / Redis Circuit Open
    - Logs Insights: top-request-paths + next-image-and-favicon-origin-hits

Otwarte po stronie app teamu:
  - potwierdzić czy /_next/image z realnymi URL-ami daje Hit from cloudfront
  - sprawdzić minimumCacheTTL w next.config.js (jeśli < 86400: rozważyć image_cache_min_ttl=86400)
  - patch aplikacyjny next-core-app (resolveCount Redis-only) — nadal lokalny, niecommitowany

Notatka: 20-projects/clients/mako/maspex/troubleshooting.md
```

## Zamknięte: Cloud Detective — robocze miejsce w vault ✓

```
Stan:       DONE (2026-04-23)
Zakres:     robocza przestrzeń do myślenia o Cloud Detective jako capability devops-toolkit
Lokalizacja: 60-toolkit/cloud-detective/

Utworzone pliki:
  - README.md
  - vision.md
  - boundaries.md
  - use-cases.md
  - open-questions.md

Kluczowe założenia zapisane:
  - Cloud Detective nie jest osobnym produktem ani silnikiem
  - capability / warstwa rozpoznania i oceny środowiska wewnątrz prywatnego devops-toolkit
  - zachowuje granice danych toolkitu: raw nie do AI, dane klienta w repo klienta
  - decyzje o API, raporcie, UI i brandingu są nadal otwarte

Następny kontekst: Maspex troubleshooting.
```

## Zamknięte: maspex UAT admin-panel — CloudFront static origin policy ✓

```
Stan:       DONE (2026-04-23)
Repo:       ~/projekty/mako/aws-projects/infra-maspex
Branch:     feat/preprod-zaslepka
Commit:     4810f3c fix uat admin cloudfront static origin policy

Objaw:
  - /auth/login przez CloudFront 200, ale login wyglądał jak surowy HTML
  - /_next/static/* przez CloudFront zwracało 502
  - kontener/admin-panel serwował assety poprawnie lokalnie

Root cause:
  - admin CloudFront ordered behaviors /_next/static/* i /static/* miały cache policy,
    ale nie miały origin_request_policy_id
  - default behavior miał Managed-AllViewer, więc dynamiczne ścieżki działały
  - statyczne behavior'y nie forwardowały poprawnego viewer request context do ALB origin

Fix:
  - w module cloudfront_site dla admin distribution dodano:
    static_path_origin_request_policy_ids:
      /_next/static/* -> 216adef6-5c7f-47e4-b989-5492eafa07d3
      /static/*       -> 216adef6-5c7f-47e4-b989-5492eafa07d3

Apply:
  - AWS_PROFILE=maspex-cli terraform -chdir=terraform/envs/uat apply -no-color -auto-approve
  - wynik: 0 added, 1 changed, 0 destroyed
  - zmieniony zasób: module.cloudfront_site.aws_cloudfront_distribution.this[0]
  - dystrybucja: E3R9U1TWNUJZ11

Post-apply:
  - CloudFront status: Deployed
  - invalidation: IC6KFOVSRK9VLU54BZTSVGGQXE
  - /auth/login: 200
  - CSS / JS / font assety: 200

Notatka:    20-projects/clients/mako/maspex/troubleshooting.md
```

## Aktywne: PBMS backend — Swagger Core 500

```
Stan:       ZDIAGNOZOWANE KODOWO (2026-04-22)
Repo app:   ~/projekty/mako/pbms-backend
Objaw:      /swagger/docs/v1/Core -> HTTP 500

Architektura:
  - gateway używa SwaggerForOcelot
  - /swagger/docs/v1/Core pobiera downstream:
    http://pbms-core-qa:8080/swagger/v1/swagger.json

Najmocniejszy trop:
  - Core response DTO:
      MediaModel.DeliveryDefinition
      SupplyResponse.DeliveryDefinition
  - typ: IMediaDeliveryModel
  - interface ma SwaggerSubType(...)
  - konfiguracja polimorfizmu w ConfigureSwaggerOptions.cs jest zakomentowana

Wniosek:
  500 najpewniej powstaje w Core Swagger generation przy schemacie
  interfejsu IMediaDeliveryModel, nie w gateway routingu.

Minimalny fix:
  - zmienić tylko typ DeliveryDefinition w:
    PBMS.Core/Models/Media/MediaModel.cs
    PBMS.Core/Models/Supply/SupplyResponse.cs
  - z IMediaDeliveryModel -> object

Walidacja:
  1. http://pbms-core-qa:8080/swagger/v1/swagger.json
  2. /swagger/docs/v1/Core
```

## Zamknięte: LLZ audit-pack llz-waf-readonly patch ✓

```
Stan:       DONE (2026-04-20)
Co:         6 bugów naprawionych w 6 pluginach (cloudtrail/observability/tagging/scp + region fallback)
Testy:      129/129 PASS (było 121 — dodano 8 behavioral tests)
Kluczowe:   llz.required_tags + llz.monitoring_account_id + llz.workloads_ou_name wymagane w project.yaml
Notatka:    20-projects/internal/llz/session-log.md (2026-04-20 patch)
```

## Zamknięte: planodkupow QA — RabbitMQ UPDATE_ROLLBACK_FAILED + RECREATE + CUTOVER ✓

```
Stan:       DONE (2026-04-21 ~13:50 UTC+2)

Root cause: planodkupow-auto brak mq:UpdateBroker + mq:RebootBroker → AccessDenied na update + rollback
            CFN drift (frozen mq.t3.micro vs real mq.m5.large) → każdy deploy próbował UpdateBroker

Incydent 1 (09:09): mq:UpdateBroker AccessDenied → naprawa: dodano ręcznie
Incydent 2 (10:02): mq:RebootBroker AccessDenied na rollback → naprawa: policy v5
Recovery x3: continue-update-rollback z skip PN8W0DD6SK1U.BasicBroker (profil plan)

Drift fix (zamiast IMPORT): RECREATE + CUTOVER
  Nowy broker: b-f231815d, planodkupow-qa-rabbitmq-cheap, mq.m7g.medium (~$66/mies. vs $197 m5.large)
  Cutover: change set mqcs-cutover-to-new-broker na KlasterStack-1F8B7693FIMIX
           UPDATE_COMPLETE, 14/14 ECS serwisów healthy
  Stary broker: b-5cb3fcb4 — DELETION_IN_PROGRESS (usunięty 2026-04-21 profilem plan)

IAM policy planodkupow-auto-CFN-Describe-Fix:
  v5: + mq:RebootBroker
  v6: + mq:CreateBroker, mq:DeleteBroker

Stan końcowy:
  - root planodkupow-qa:              UPDATE_ROLLBACK_COMPLETE
  - planodkupow-qa-KlasterStack:      UPDATE_COMPLETE ✓
  - Broker QA aktywny: b-f231815d, mq.m7g.medium, RUNNING
  - Stary broker b-5cb3fcb4:          DELETION_IN_PROGRESS

OTWARTE:
  - cloudformation:ContinueUpdateRollback na planodkupow-auto (opcjonalnie, breakglass)
  - RabbitMQStack nadal w root stack → plan migracji gotowy (patrz niżej)

Runbook:    40-runbooks/incidents/planodkupow-qa-rabbitmq-rollback-failed.md
```

## Zamknięte: planodkupow QA — CFN refaktor (RabbitMQ poza root stack) ✓

```
Stan:       DONE (2026-04-21 22:42)

Wykonane:
  - SSM /planodkupow/qa/rabbitmq/mqcs (String, Version 2) ✓
  - ROOT.yml patchowany z deployed template jako bazy (nie z repo!) ✓
  - Change set remove-rabbitmq-safe-1776803624 — EXECUTED ✓
  - Root stack: UPDATE_COMPLETE ✓
  - RabbitMQStack: usunięty z root ✓
  - ECS: 14/14 running, 0 pending ✓

Kluczowe lekcje:
  - patchuj DEPLOYED template (get-template), nie wersję z repo
  - tag drift = DBStack DirectModification = rollback przez SQLDatabase replacement
  - ssm-secure nie działa dla nested stack params → tylko ssm + String
  - continue-update-rollback wymaga dwóch kroków (nested + root)

Runbook:    40-runbooks/planodkupow-rabbitmq-cfn-refactor.md
```

## Zamknięte: planodkupow — audyt tagów FinOps (Faza 1) ✓

```
Stan:       DONE (2026-04-21)

Wyniki:
  - QA: nowy schemat (Project/Environment/Owner/ManagedBy/CostCenter) — kompletny
  - UAT: stary schemat (Maintainer/Provisioner/Team/Client/typ) — brakuje Owner/ManagedBy/CostCenter
  - CloudFront QA (EORCEYNXGKU9K): BRAK TAGÓW — DO NOT TOUCH
  - CloudFront UAT (x3): stary schemat — DO NOT TOUCH
  - RDS UAT: tagować bezpośrednio przez rds add-tags-to-resource (NIE przez CFN)
  - CostCenter nie ma odpowiednika w starym schemacie → konieczna addytywna zmiana

Decyzja wymagana przed Fazą 3:
  - Czy Owner=DC-devops właściwy dla UAT (był Maintainer=3rd party - Tribecloud)?
  - Potwierdzenie CostCenter=DC dla UAT

Runbook:    40-runbooks/planodkupow-tagging-finops.md
```

## Zamknięte: planodkupow QA — FinOps remediation sprint ✓ (P1.1 pending compliance gate)

```
Stan:       SPRINT CLOSED (2026-04-26) — P1.1 execution pending compliance gate
Projekt:    planodkupow, 333320664022, eu-central-1, profil: plan

Zrobione:
  runtime-verification-2026-04-26.md  — skompilowane evidence ze wszystkich live CLI runs:
    ECS PropagateTags: 26/28 serwisów = NONE (UAT) → tag propagation broken
    MQ orphan: b-f231815d (nowy QA broker) — ZERO tagów, poza CFN stackiem
    CW log groups: 164.39 GB, 93 grupy NEVER_EXPIRES (UAT broker b-2d26b881 dominant)
    VPC endpoints: 4 orphan w starym VPC (out-of-scope nowego QA VPC)
    EIP: 1 unassociated ($3.60/mies. waste)
    WAF, GA, ECR: zero governance tags

  remediation-runbook-2026-04-26.md  — 4-fazowy runbook (P0/P1/P2/P3), 4 rundy patchy:
    P0: snapshot collection (read-only) — wykonany w dry-run
    P1.1: CloudWatch retention (4 etapy), DRY_RUN=true — wykonany, wynik walidowany
    Kluczowe poprawki w runbooku:
      - rollback: delete-retention-policy (NIE: retention-in-days 0 — invalid API value)
      - risk: MEDIUM compliance (NIE: zero)
      - scope: snapshot-locked targeting (NIE: live prefix re-query → scope expansion risk)
      - shell: while IFS= read -r (NIE: for-in — zsh word-split bug)
      - broker b-52e41f96 dodany do CHAOS_PATTERN (odkryty dopiero w P0.3)
      - savings: $4.67/mies. storage (NIE: $58/mies. — błąd ×12-24)
    Split retention: RETENTION_DAYS_ACTIVE=90 (Stage 1 UAT broker), RETENTION_DAYS_ORPHAN=30 (Stage 2+3 chaos)

Kluczowe ustalenia:
  - $97-126/mies. CW wzrost = ingestion z ECS logów (jednorazowy), NIE storage MQ
  - Storage CW: $4.93/mies. (164 GB × $0.03), savings po retention fix: $4.67/mies.
  - GO verdict na P1.1 — warunkowo: wymaga team confirmation na 90-day retention policy

Otwarte (poza scope zamkniętego sprintu):
  - P1.1 execution: czeka na compliance sign-off → flip DRY_RUN=false
  - P1.2–P1.9: MQ tagging, WAF/GA/ECR tagging, EIP release
  - P2 (ECS PropagateTags): wymaga scheduled deploy window
  - P3 (old VPC teardown): wymaga 7-day metric gate + business sign-off

Artefakty:
  20-projects/clients/mako/planodkupow-runtime-verification-2026-04-26.md
  20-projects/clients/mako/planodkupow-ce-audit-2026-04-26.md
  40-runbooks/incidents/planodkupow-remediation-runbook-2026-04-26.md
```

## Zamknięte: standard IaC + ECS Competency mapping ✓

```
Stan:       DONE (2026-04-21)

Pliki:
  - 20-projects/clients/mako/wdrozenie-standardow-organizacji/standard-iac-tagging-naming.md
    Dodana sekcja 8a: ECS patterns (PropagateTags, Capacity Providers, Container Insights,
    CloudFront ingress, GuardDuty Runtime Monitoring)
  - 20-projects/clients/mako/wdrozenie-standardow-organizacji/ecs-competency-llz-mapping.md
    Mapa: LLZ kontrola → ECS-XXX requirement ID, backlog remediacji, WAFR skrót
  - 20-projects/clients/mako/wdrozenie-standardow-organizacji/aws-competency-certyfikaty-bloker.md
    Twardy bloker: 0/3 Pro/Specialty, brakuje 4/8 wymaganych certyfikatów
  - _chatgpt/context-packs/llz.md — zaktualizowany (cfn_messaging_audit, planodkupow status)

Kluczowe wnioski:
  - ECS-011 (runtime security) + LLZ EPIC 4 GuardDuty = ten sam backlog item
  - ECS-018 (observability) blokuje oba projekty — priorytet #1 do naprawy
  - WAFR zero-HRI = automatyczne spełnienie Common Requirements (shortcut)
  - Certyfikaty: brak Pro/Specialty = formalny bloker aplikacji Competency
    Rekomendacja: DevOps Engineer Pro + Security Specialty (Jarosław)
```

## Zamknięte: maspex UAT/preprod — monitoring + CloudFront + .gitignore ✓

```
Stan:       DONE (2026-04-22)

UAT:
  - SNS topic maspex-uat-alarms + email subscription jaroslaw.golab@makolab.com
  - Wszystkie alarmy CloudWatch (11) podłączone do SNS
  - CloudWatch Logs Insights: nowy query errors-by-path
  - CloudFront API (E3J76RNXIE2YIG / kapsel.makotest.pl):
    behaviors /_next/static/* + /landing/* z min_ttl=86400
  - ECS service lifecycle: ignore_changes = [desired_count, task_definition]
    → GitLab CI/CD zarządza task definitions, Terraform nie nadpisuje

Preprod:
  - ALB routing fix: admin_panel_domain=twojkapsel.pl → "Not Found" naprawiony
  - CloudFront static caching: /_next/static/* + /static/* dodane

Repo:
  - terraform.tfvars commitowane (branch chore/add-tfvars, mergowane na main)
  - .gitignore: **/.claude/settings.local.json + .codex/ zignorowane
  - branch chore/add-tfvars mergowany → main aktualny

TODO:
  - SNS subscription wymaga potwierdzenia email (klik "Confirm subscription")
  - Redis connection string do Secrets Manager: maspex/preprod/api (otwarte)
```

## Aktywne: planodkupow UAT — CFN refaktor (RabbitMQ poza root stack)

```
Stan:       DO WDROŻENIA
Stack:      planodkupow-uat (UPDATE_ROLLBACK_COMPLETE)
Broker UAT: b-2d26b881-79f2-4c3c-8b77-06c1a0fb0b29, mq.t3.micro, RUNNING

Następne kroki (według runbooka):
  1. Zweryfikuj stan stacka i brokera UAT
  2. aws ssm put-parameter /planodkupow/uat/rabbitmq/mqcs (String, nie SecureString)
  3. get-template ze stacka → patch (MQCS + usuń RabbitMQStack)
  4. Upload ROOT.yml → s3://planodkupow-cf/ROOT.yml
  5. Change set — walidacja (HARD STOP jeśli DBStack Static/Direct)
  6. Execute + monitoring

Runbook:    40-runbooks/planodkupow-rabbitmq-cfn-refactor.md
Repo:       ~/projekty/mako/aws-projects/infra-bbmt
```

## Zamknięte: planodkupow UAT — RabbitMQ UPDATE_ROLLBACK_FAILED ✓

```
Zadanie:    planodkupow UAT — RabbitMQ UPDATE_ROLLBACK_FAILED
Projekt:    planodkupow (333320664022), eu-central-1, profil: plan
Repo:       ~/projekty/mako/aws-projects/infra-bbmt

Status:     DONE OPERACYJNIE (2026-04-21)

Wykonane:
  - root stack odblokowany: continue-update-rollback z skip:
    planodkupow-uat-RabbitMQStack-1XMB1IYDKWTXU.BasicBroker
  - root planodkupow-uat: UPDATE_ROLLBACK_COMPLETE
  - RabbitMQ child stack: minimalny sync EngineVersion 3.8.6 -> 3.13, UPDATE_COMPLETE
  - Redis child stack: minimalny sync EngineVersion 5.0.0 -> 5.0.6, UPDATE_COMPLETE
  - IAM dla planodkupow-auto: baseline CFN read + ValidateTemplate/CreateChangeSet/DescribeChangeSet/ExecuteChangeSet

Ważny wniosek:
  - root CFN formalnie rusza wszystkie nested stacki w eventach
  - realne resource-level zmiany przy app deployu z --use-previous-template dotyczą tylko KlasterStack (ECS)

Preflight:
  - app-only deploy na root stacku z --use-previous-template: GO
  - root deploy z aktualnym ROOT.yml jako szeroki change set: nadal NOT SAFE

Runbook:    40-runbooks/incidents/planodkupow-uat-rabbitmq-rollback-failed.md
```

## Zamknięte: LLZ context pack + AGENTS kontrakt ✓

```
Stan:       DONE (2026-04-20)
Co:         _chatgpt/context-packs/llz.md — pełny kontekst LLZ dla LLM (11 sekcji)
            _system/AGENTS.md — kontrakt dla dokumentów kontekstowych
Następne:   Faza B — GuardDuty org-wide (HRI, EPIC 4)
```

## Zamknięte: LLZ WAF checklist ✓

```
Stan:       Gotowe (2026-04-20)
Plik:       20-projects/internal/llz/waf-checklist.md
Wynik:      ~30% WAF-ready, 4 HRI, quick wins zidentyfikowane
HRI:        GuardDuty (SEC 4), SCP (SEC 1), IR plan (SEC 10), DR plan (REL 13)
```

## Zamknięte: LLZ health-notifications ✓ WDROŻONE + ZWERYFIKOWANE

```
Stan:       APPLY COMPLETE (2026-04-20) + test OK (2026-04-22)
Repo:       ~/projekty/mako/aws-projects/aws-cloud-platform/platform/health-notifications/
Architektura (finalna):
  - 11 member accounts (us-east-1): IAM role health-eventbridge-forward + EventBridge rule → monitoring bus
  - monitoring-nagios-bot (us-east-1): bus health-aggregation + rule → Lambda health-notify
  - Lambda (Python 3.12, us-east-1): nazwy kont z env var → formatuje email → SNS eu-central-1
  - SNS: nowy topic health-notifications na monitoring-nagios-bot + subskrypcja email potwierdzona
  - Filtr: tylko statusCode=open, category=issue|investigation

Weryfikacja (2026-04-22):
  - Lambda invoke bezpośredni → StatusCode 200, brak błędów, SNS publish OK
  - Email testowy wysłany: [AWS Health] EC2 open — planodkupow (eu-central-1)
  - Infrastruktura w pełni sprawna; brak realnych eventów od 20.04 (normalny stan)

Koszt:      ~$0.00/miesiąc
Notatka:    20-projects/internal/llz/session-log.md
```

## Stan UAT po sesji 2026-04-21

```
Stan końcowy:
  - root planodkupow-uat: UPDATE_ROLLBACK_COMPLETE
  - RabbitMQStack: UPDATE_COMPLETE
  - RedisStack:    UPDATE_COMPLETE
  - DBStack:       UPDATE_COMPLETE

RabbitMQ:
  Broker: b-2d26b881-79f2-4c3c-8b77-06c1a0fb0b29
  State:  RUNNING
  Ver:    3.13.7
  Type:   mq.t3.micro

Redis:
  EngineVersion: 5.0.6
  NodeType:      cache.t3.micro
  Status:        available

IAM:
  planodkupow-auto-CFN-Describe-Fix -> default v3
  validate-template / create-change-set / describe-change-set działają profilem planodkupow-auto

Deploy pattern:
  ostatni udany root app deploy formalnie rusza 9 nested stacków,
  ale realne resource-level zmiany występują tylko w KlasterStack (ECS services + task definitions)
```

## Zamknięte: maspex preprod + CloudFront ✓

```
Stan:       DONE (2026-04-21)
            ALB: maspex-preprod-1322298306.eu-west-1.elb.amazonaws.com
            Redis: maspex-preprod.zwowz5.0001.euw1.cache.amazonaws.com:6379
            CloudFront: E17VHHQJ29MVAB → d1epwako2iigq8.cloudfront.net
            Domena: twojkapsel.pl + www.twojkapsel.pl
            HTTP→HTTPS redirect: aktywny
            Static caching: /_next/static/* + /static/* (min_ttl=86400)

TODO:       - Wpisać Redis do Secrets Manager maspex/preprod/api
            - DNS wysłany klientowi (CNAME → d1epwako2iigq8.cloudfront.net)
            - Warning w modules/alb/main.tf:65 (niekrytyczny)

Notatka:    20-projects/clients/mako/maspex/troubleshooting.md
```

## Zamknięte: maspex UAT — CloudFront static caching + lukasz.fuchs SSM ✓

```
Stan:       DONE (2026-04-21)

CloudFront static caching:
  Problem:  Cache-Control: max-age=0 → CloudFront nie cachował (Miss from cloudfront)
  Fix:      aws_cloudfront_cache_policy (min_ttl=86400) + ordered_cache_behavior
            /_next/static/* + /static/* na dystrybucji E3R9U1TWNUJZ11
  Efekt:    Statyki cachowane 24h; dynamiczne requesty bez zmian

lukasz.fuchs SSM:
  Policy:   maspex-uat-redis-ssm-access (v2) — ECS Exec + SSM + cloudshell:*
  Redis:    maspex-uat.zwowz5.0001.euw1.cache.amazonaws.com:6379
  Dostęp:   CloudShell → ecs execute-command → redis-cli

Drift ECS:  task_definition v31→v24 na service_api — NIE naprawiony (decyzja CI/CD vs TF)

Notatka:    20-projects/clients/mako/maspex/troubleshooting.md
```

## Zawieszone: udemy-transcript-tool

```
Stan:       CDP zaimplementowane, czeka na test
Blokada:    Chrome musi być uruchomiony z --remote-debugging-port=9222
Następny krok:
            1. Zamknąć Chrome (Cmd+Q)
            2. Uruchomić z flagą:
               /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
                 --remote-debugging-port=9222 \
                 --user-data-dir="$HOME/Library/Application Support/Google/Chrome" &
            3. Sprawdzić: curl -s http://localhost:9222/json/version | python3 -m json.tool
            4. bash run.sh (dry-run --verbose)
Projekt:    20-projects/internal/udemy-transcript-tool
Pliki:      udemy_obsidian/browser.py — tryb CDP w __aenter__
            udemy_obsidian/cli.py    — flaga --cdp-url
            run.sh                   — gotowe komendy
```

## Aktywne: rshop — Tag Policy remediation (audit DONE, czeka na CFN fix)

```
Stan:       AUDIT DONE (2026-04-24) — Tag Policies nadal WYŁĄCZONE
Incydent:   40-runbooks/incidents/rshop-prod-503-2026-04-20.md (RESOLVED)
Plan:       40-runbooks/incidents/rshop-tag-policy-readiness.md

Audyt AWS: 2026-04-24, konto 943111679945, eu-central-1
Pliki:
  - 20-projects/clients/mako/rshop-tagging-baseline-2026-04-24.md  ← pełny raport
  - 40-runbooks/incidents/rshop-tag-policy-readiness.md             ← runbook re-enable

Top 5 blokerów przed re-enable Tag Policies:
  1. [KRYTYCZNE] rshop-cloudformation: brak PropagateTags/Tags/EnableECSManagedTags
     w 4 plikach (api/backoffice/frontend/frontend2.yml) — każdy CFN deploy resetuje
     propagateTags do NONE → natychmiastowa awaria po re-enable
  2. [KRYTYCZNE] akcesoria2/svc.yml: Tags są, ale brak PropagateTags: SERVICE
     i EnableECSManagedTags: true — 2 linie na serwis
  3. [KRYTYCZNE] Weryfikacja allowedValues LLZ Tag Policy dla Project=akcesoria2
     (może nie być w allowedValues — sprawdzić w terraform LLZ)
  4. [WYSOKIE] dev-ALB stary schemat Tribecloud (brakuje Project/Owner/CostCenter/ManagedBy)
  5. [WYSOKIE] ECR rshopapp-prod/qa/uat: brakuje Project, Owner, ManagedBy, CostCenter

Następny krok: przygotować CFN patche (krok 1 i 2 z listy blokerów)
  → branch feat/ecs-propagate-tags w rshop-cloudformation
  → commit 4 pliki + akcesoria2/svc.yml
  → deploy na dev → weryfikacja ENI → deploy prod
```

## Zamknięte: rshop-prod-503 ✓

```
Stan:       RESOLVED (2026-04-20)
Incydent:   40-runbooks/incidents/rshop-prod-503-2026-04-20.md
Plan:       40-runbooks/incidents/rshop-tag-policy-remediation.md
```

## Zamknięte: BMW AI Taskforce — ITSM AI Mapping Excel ✓

```
Stan:       DONE (2026-04-28)
Pliki:      20-projects/clients/bmw/ai-taskforce/ai-taskforce.xlsx      ← oryginał EN
            20-projects/clients/bmw/ai-taskforce/ai-taskforce-pl.xlsx   ← kopia PL
Session:    20-projects/clients/bmw/ai-taskforce/session-log.md

Co zrobiono:
  - Arkusz Excel wzbogacony jako senior AIOps/ITSM/EA konsultant
  - Manage Problems: skorygowano 50% → 20–30% (halucynacje RCA, brak full observability)
  - Manage Knowledge: podniesiono do 40–55% (GenAI impact na drafting/search)
  - Kolumna "Saving" → "Effort Reduction Potential"
  - Nowe kolumny: Prerequisites / Maturity Required + AI Type Classification
  - Uzupełniono brakujące wiersze: Svc Configuration, Capacity, IT Service Continuity
  - Dodano 3 nowe wiersze: Change Management, CMDB/Asset Mgmt, Cloud Ops/SRE
  - Executive summary: high value/low risk vs high risk/advanced maturity
  - Polska wersja: ai-taskforce-pl.xlsx — pełne tłumaczenie treści + nazwy arkuszy

Otwarte:
  - Development section (Plan→Deploy) nadal bez AI data w arkuszu
  - Ewentualny transfer do pptx
  - Omówienie prerequisites maturity z BMW
```

## Gdzie skończyłem

```
Aktywny projekt: MASPEX
Stan:          CloudFront /api/slogan cache GOTOWE DO APPLY (przygotowane 2026-04-26)
Repo:          ~/projekty/mako/aws-projects/infra-maspex
Branch:        feat/preprod-zaslepka (wypchnięty na GitLab)

Następny krok (WEJŚCIE PO PRZERWIE):
  1. terraform apply UAT — CloudFront /api/slogan behavior
  2. Weryfikacja: curl → Miss, potem Hit na /api/slogan?page=1&sortBy=votes_desc
  3. Obserwacja CacheHitRate na dashboard maspex-uat-overview ~15 min

⚠️ Uwagi przed apply:
  - ECS lifecycle zmiana (ignore_changes bez desired_count) dotyka UAT + preprod
    Sprawdź desired_count w UAT tfvars przed apply
  - /api/slogan trailing slash: behavior nie obejmuje /api/slogan/ — sprawdzić po apply

Notatka projektu: 20-projects/clients/mako/maspex/
Ostatni raport:   20-projects/clients/mako/maspex/cloudfront-audit-2026-04-26.md
```

## Kontekst środowiska

```
AWS Account:  333320664022 (planodkupow)
Region:       eu-central-1
Profil CLI:   plan
Stack:        planodkupow-qa (CREATE_COMPLETE)
              planodkupow-uat (UPDATE_ROLLBACK_COMPLETE)
```

## Kluczowe pliki

```
Repo root:    ~/projekty/mako/aws-projects/infra-bbmt
~/projekty/mako/aws-projects/infra-bbmt/cloudformation/ROOT.yml
~/projekty/mako/aws-projects/infra-bbmt/cloudformation/ECS.yml  (LogGroup DeletionPolicy: Retain)
~/projekty/mako/aws-projects/infra-bbmt/cloudformation/MSSQL.yml (DeletionPolicy: Retain, HasSnapshot)
~/projekty/mako/aws-projects/infra-bbmt/cloudformation/RMQ.yml  (3.13, mq.m5.large)
```

## Stan repo

```bash
Branch: main
Dirty:  cloudformation/ECS.yml
        cloudformation/MSSQL.yml
        cloudformation/REDIS.yml
        cloudformation/RMQ.yml
        cloudformation/ROOT.yml
        cloudformation/ROOT_CLEANED_DEV.yml
        .gitignore (untracked)
        .DS_Store
```

## Dokumentacja

- [[planodkupow-qa-postmortem]] — pełne RCA z sesji 1+2
- [[planodkupow-qa-execution-log]] — szczegółowy log operacyjny

## UAT — czerwone flagi / otwarte kwestie

```
Root safe-minimal:
  root change set z aktualnym ROOT.yml nadal formalnie dotyka 9 nested stacków — nie używać jako "minimalnego" syncu
S3 planodkupow-uat: 0 obiektów — podejrzane, sprawdzić z dev teamem.
RDS: DeletionProtection: False — włączyć prewencyjnie.
RabbitMQ: template drift naprawiony minimalnie na child stacku; nie wracać do 3.8.6.
```

---

## Gdzie skończyłem — rshop FinOps forensic

```
Aktywny projekt: rshop FinOps / tagging forensic
Repo projektu:    /Users/jaroslaw.golab/projekty/mako/aws-projects/infra-rshop
Audit dir:        .devops-toolkit/manual-audits/finops-tagging-live-20260430-212856/
Account rshop:    943111679945
Region:           eu-central-1
Profile runtime:  rshop
Profile billing:  mako-dc
Mgmt account:     864277686382
Okres:            2026-04-01 → 2026-05-01
Boundary:         READ-ONLY ONLY
```

Najważniejszy wynik:
- Classic CUR nie istnieje (`ReportDefinitions: []`), ale istnieje AWS BCM Data Export `test`
- Export file: `s3://testdataexportjanmarchel/test/test/data/BILLING_PERIOD=2026-04/test-00001.csv.gz`
- Local copy: `/tmp/rshop-cur-2026-04.csv.gz`
- Nie użyto Athena i nie wykonano żadnych write operations w AWS

Data Export forensic:
- `TAGGED_IN_CUR`: `$488.287400` / 50.46%
- `UNTAGGED_RESOURCE_IN_CUR`: `$257.860038` / 26.65%
- `BILLING_ARTIFACT`: `$180.960000` / 18.70%
- `NO_RESOURCE_ID`: `$40.517868` / 4.19%

Runtime join top 100 `UNTAGGED_RESOURCE_IN_CUR`:
- Scope: `$249.677894`
- `A_live_tagged_billing_untagged`: `$61.776000` / 3 zasoby
- `B_live_untagged`: `$13.969005` / 10 zasobów
- `C_historical_or_ephemeral`: `$169.936491` / 83 zasoby
- `D_no_runtime_lookup_possible`: `$3.996398` / 4 zasoby

Werdykt:
- Wysoki `Environment absent` to nie tylko aktualnie nietagowane zasoby
- Duży udział mają billing artifacts, historyczne/ephemeral resource IDs oraz timing/propagation billing tags
- Faktycznie live-untagged w top100 to mniejsza część: głównie jumphost ECS taski i część ENI/PublicIPv4
- Trzy VPC endpoints teraz mają `Environment=dev`, ale billing line item nie miał Environment

Artefakty:
```
/Users/jaroslaw.golab/projekty/mako/aws-projects/infra-rshop/.devops-toolkit/manual-audits/finops-tagging-live-20260430-212856/data-export-cur-forensic-report.md
/Users/jaroslaw.golab/projekty/mako/aws-projects/infra-rshop/.devops-toolkit/manual-audits/finops-tagging-live-20260430-212856/normalized/data-export-cur-forensic-summary.json
/Users/jaroslaw.golab/projekty/mako/aws-projects/infra-rshop/.devops-toolkit/manual-audits/finops-tagging-live-20260430-212856/normalized/data-export-untagged-resource-ids.json
/Users/jaroslaw.golab/projekty/mako/aws-projects/infra-rshop/.devops-toolkit/manual-audits/finops-tagging-live-20260430-212856/normalized/data-export-runtime-join-summary.json
/Users/jaroslaw.golab/projekty/mako/aws-projects/infra-rshop/.devops-toolkit/manual-audits/finops-tagging-live-20260430-212856/data-export-runtime-join-report.md
```

Następne możliwe kroki read-only:
- Rozszerzyć join z top100 na wszystkie `UNTAGGED_RESOURCE_IN_CUR`
- Sprawdzić CloudTrail tag events/deployment history dla przypadków `A_live_tagged_billing_untagged`
- Rozbić ECS task line items po timestampach/deploymentach, bez aktualizacji service

---

*Ostatnia aktualizacja: 2026-05-19 20:18 — sesja aktywna*
