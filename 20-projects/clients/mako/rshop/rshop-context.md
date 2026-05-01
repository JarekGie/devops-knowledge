---
title: rshop-context
client: mako
project: rshop
domain: client-work
document_type: runtime-context
context_type: cloud-detective-snapshot
classification: internal
source_of_truth: false
runtime_snapshot: true
aws_profile: rshop
account_id: "943111679945"
regions:
  - eu-central-1
extra_regions:
  - us-east-1
iac: cloudformation
repository: "~/projekty/mako/aws-projects/infra-rshop"
created: "2026-05-01"
updated: "2026-05-01"
last_verified: "2026-05-01"
scan_method: cloud-detective-v2
last_verified_by: claude
tags:
  - aws
  - cloudformation
  - mako
  - rshop
---

# rshop — Platforma e-commerce Renault/Dacia

#aws #cloudformation #ecs #fargate #mako #rshop

**Data:** 2026-05-01
**Typ dokumentu:** snapshot runtime / context wejściowy
**Source of truth:** AWS live + IaC (infra-rshop) + CloudFormation stacki
**Tryb skanowania:** read-only
**Poziom pewności snapshotu:** częściowa — runtime prod/dev/akcesoria2 w pełni potwierdzony live; ALB listener rules i routing niezweryfikowane; tagging ECR/log groups/VPC endpoints niezweryfikowany
**Projekt:** Wielorynkowa platforma e-commerce Renault i Dacia, obsługująca PL/CZ/SK/HU/LT/LV/EE; dwie marki jako osobne frontend-svc w jednym klastrze ECS
**OrgAccountID:** nieustalone
**Account ID:** 943111679945
**IAM principal (sesja):** `OrganizationAccountAccessRole` (dostęp przez org management account) — `live AWS`
**IAM principal (CI/CD):** `jenkinsit` IAM user — `IaC / CFN events`
**AWS profile:** `rshop`
**Region główny:** `eu-central-1`
**Region dodatkowy:** `us-east-1` (ACM certs dla CloudFront)

---

## Snapshot metadata

| Pole | Wartość |
|------|---------|
| scan_date | 2026-05-01 |
| scan_scope | partial |
| regions_checked | eu-central-1, us-east-1 (ACM only) |
| repo_checked | tak (infra-rshop / cloudformation/) |
| iac_checked | częściowo (root.yml, db.yml przejrzane) |
| runtime_checked | tak |
| extra_regions_checked | us-east-1 (ACM list-certificates) |

---

## Zakres snapshotu vs audytu

| Obszar | Typ | Zakres | Źródło |
|--------|-----|--------|--------|
| Runtime health (ECS/ALB/RDS) | snapshot | 3/3 klastrów, 2 ALB, 2 RDS — live | live AWS |
| CFN stack status | snapshot | 30+ stacków, events dev-VPCStack — live | live AWS |
| IaC analiza | snapshot | root.yml, db.yml, dev/ przejrzane — partial | IaC (lokalny checkout) |
| Tagging coverage | snapshot / audit | sample-based (~15 zasobów live); pełny audyt: [[rshop-tagging-baseline-2026-04-24]] | live AWS + vault historyczny |
| FinOps / cost allocation | audit (external) | patrz [[finops-rshop]] | vault historyczny |
| Security (WAF) | gap analysis | list-web-acls REGIONAL + CLOUDFRONT — 0 ACLs; brak WAF ≠ aktywny incydent | live AWS |
| ACM certs | snapshot | eu-central-1 + us-east-1 sprawdzone osobno | live AWS |
| ALB listener rules / routing | niezweryfikowane | describe-listeners nie wywołano | — |
| SSM Parameter Store | niezweryfikowane | nie sprawdzono | — |
| ECS tag propagation | snapshot | sprawdzono 1 serwis (rshop-prod-api-svc) | live AWS |

---

## Repozytorium kodu

- lokalna ścieżka: `~/projekty/mako/aws-projects/infra-rshop`
- remote: `git@gitlab.makolab.net:admin-makolab/dc/aws-projects/infra-rshop.git`
- aktywny branch: `main`
- IaC: **CloudFormation**
- Ostatni commit: `2103f04 aktualizacja ecs tags` — `live AWS / IaC`

**IaC source of truth (multi-source):**

```
- infra-rshop / cloudformation/root.yml   — prod root (Default env: prod)
- infra-rshop / cloudformation/dev/       — dev templates (root-dev.yml + *.yml)
- infra-rshop / cloudformation/akcesoria2/— akcesoria2 templates
- rshop-cf S3 bucket                      — CFN template artifacts (TemplateURL dla deployów)
- rshop-cloudformation repo               — vault historyczny; nie potwierdzono w bieżącym skanie
```

Uwaga: Templates są publikowane do `rshop-cf` S3 bucket i deployowane przez TemplateURL. Lokalna kopia może nie być source of truth dla działających stacków — liczy się wersja na S3.

---

## Środowiska

| Env | Region | Account ID | CFN Root Status | ECS | ALB | VPC CIDR | Pewność |
|-----|--------|------------|-----------------|-----|-----|----------|---------|
| prod | eu-central-1 | 943111679945 | UPDATE_COMPLETE (2026-04-30) | 4 svc ACTIVE | prod-ALB active | 10.0.0.0/16 | wysoka |
| dev | eu-central-1 | 943111679945 | **UPDATE_ROLLBACK_COMPLETE (2026-04-28)** | 4 svc ACTIVE | dev-ALB active | 10.0.0.0/16 | wysoka |
| akcesoria2-prod | eu-central-1 | 943111679945 | UPDATE_COMPLETE (2026-04-24) | 2 svc ACTIVE | prod-ALB (shared) | wymaga potwierdzenia | wysoka (ECS) |
| qa | eu-central-1 | 943111679945 | brak stacka | brak klastra | nieznany | nieustalone | niska |
| uat | eu-central-1 | 943111679945 | brak stacka | brak klastra | nieznany | nieustalone | niska |

---

## Architektura

```text
Internet
  │
  ├── CloudFront (4 dystrybucje, globalne) — live AWS
  │     ├── prod-PL (EHVSOBMPOXLM7 / d2m4t0ndr5frvj.cloudfront.net)
  │     │     aliases: sklep.renault.pl, sklep.dacia.pl, bo.sklep.*
  │     ├── prod-Foreign (ET4SVT8DC9P9M / dqwx8oyilev42.cloudfront.net)
  │     │     aliases: bo.webshop.renault.hu, eshop.dacia.cz, eshop.dacia.sk
  │     ├── dev-Baltic (E12KV5NOV0I551 / d2ieg406iivznt.cloudfront.net)
  │     │     aliases: dev.eshoprenault.lt, dev.eshoprenault.lv, devb.eshopdacia.lv
  │     └── dev-CZ/SK/HU (E3LC30816FMUSK / d35g7vof2k6bj9.cloudfront.net)
  │           aliases: dev.eshopdacia.sk, devb.webshopdacia.hu, dev.eshopdacia.cz
  │
  ├── prod-ALB (internet-facing, active) — live AWS
  │     ├── prod-frontend-ALB-TG  → rshop-prod-Klaster / rshop-prod-frontend-svc1 (Renault, :3000)
  │     ├── prod-frontend2-ALB-TG → rshop-prod-Klaster / rshop-prod-frontend-svc2 (Dacia, :3000)
  │     ├── prod-api-ALB-TG1      → rshop-prod-Klaster / rshop-prod-api-svc (:8080)
  │     ├── prod-backoffice-ALB-TG1 → rshop-prod-Klaster / rshop-prod-backoffice-svc (:8080)
  │     ├── akcesoria2-prod-renault-TG → akcesoria2-prod-Klaster / akcesoria2-prod-renault-svc (:3000)
  │     └── akcesoria2-prod-dacia-TG   → akcesoria2-prod-Klaster / akcesoria2-prod-dacia-svc (:3000)
  │
  └── dev-ALB (internet-facing, active) — live AWS
        ├── dev-frontend-ALB-TG  → rshop-dev-Klaster / rshop-dev-frontend-svc1 (Renault)
        ├── dev-frontend2-ALB-TG → rshop-dev-Klaster / rshop-dev-frontend-svc2 (Dacia)
        ├── dev-api-ALB-TG       → rshop-dev-Klaster / rshop-dev-api-svc
        └── dev-backoffice-ALB-TG → rshop-dev-Klaster / rshop-dev-backoffice-svc

ECS Fargate → RDS SQL Server (eu-central-1) — live AWS
  ├── prod: sqlserver-web, db.t3.large, 20GB, no MultiAZ
  └── dev:  sqlserver-ex (Express Edition), db.t3.small, 20GB, no MultiAZ

Uwaga: Routing CloudFront → ALB / S3 wymaga potwierdzenia listener rules (describe-listeners niezweryfikowane).
```

---

## Mikroserwisy / komponenty

**Zakres walidacji ECS:** describe-services wykonano na wszystkich 3 klastrach (3/3). Każdy serwis potwierdzony live — desired=running=1, pending=0. Listener rules ALB → serwis: `wymaga potwierdzenia` (describe-listeners niezweryfikowane).

| Serwis | Cluster | Port | Ingress | Service Discovery | Desired | Running | Status |
|--------|---------|------|---------|-------------------|---------|---------|--------|
| rshop-prod-frontend-svc1 | rshop-prod-Klaster | 3000 | prod-ALB → CF | niezweryfikowane | 1 | 1 | ✅ ACTIVE |
| rshop-prod-frontend-svc2 | rshop-prod-Klaster | 3000 | prod-ALB → CF | niezweryfikowane | 1 | 1 | ✅ ACTIVE |
| rshop-prod-api-svc | rshop-prod-Klaster | 8080 | prod-ALB | niezweryfikowane | 1 | 1 | ✅ ACTIVE |
| rshop-prod-backoffice-svc | rshop-prod-Klaster | 8080 | prod-ALB → CF BO | niezweryfikowane | 1 | 1 | ✅ ACTIVE |
| rshop-dev-frontend-svc1 | rshop-dev-Klaster | 3000 | dev-ALB → CF | niezweryfikowane | 1 | 1 | ✅ ACTIVE |
| rshop-dev-frontend-svc2 | rshop-dev-Klaster | 3000 | dev-ALB → CF | niezweryfikowane | 1 | 1 | ✅ ACTIVE |
| rshop-dev-api-svc | rshop-dev-Klaster | 8080 | dev-ALB | niezweryfikowane | 1 | 1 | ✅ ACTIVE |
| rshop-dev-backoffice-svc | rshop-dev-Klaster | 8080 | dev-ALB | niezweryfikowane | 1 | 1 | ✅ ACTIVE |
| akcesoria2-prod-renault-svc | akcesoria2-prod-Klaster | 3000 | prod-ALB | niezweryfikowane | 1 | 1 | ✅ ACTIVE |
| akcesoria2-prod-dacia-svc | akcesoria2-prod-Klaster | 3000 | prod-ALB | niezweryfikowane | 1 | 1 | ✅ ACTIVE |

Źródło: `live AWS` — describe-services na wszystkich 3 klastrach.
ECS tag propagation: `propagateTags=SERVICE` (potwierdzone na rshop-prod-api-svc); tagi na serwisach: null (propagacja z CFN stack tags).

---

## Zasoby kluczowe

| Zasób | Identyfikator | Źródło | Pewność |
|-------|---------------|--------|---------|
| Account ID | 943111679945 | live AWS | wysoka |
| prod-ALB | prod-ALB-1431454853.eu-central-1.elb.amazonaws.com | live AWS | wysoka |
| dev-ALB | dev-ALB-2024598218.eu-central-1.elb.amazonaws.com | live AWS | wysoka |
| prod VPC | vpc-08c5016cee20ad2ae (10.0.0.0/16) | live AWS | wysoka |
| dev VPC | vpc-0befdfd9f1b71ebf6 (10.0.0.0/16) | live AWS | wysoka |
| RDS prod | pssa61v1phykq0, sqlserver-web, db.t3.large | live AWS | wysoka |
| RDS dev | dev-dbstack-ez6jh7wsba94-sqldatabase-t5q3rgolza5p, sqlserver-ex, db.t3.small | live AWS | wysoka |
| CloudFront prod-PL | EHVSOBMPOXLM7 | live AWS | wysoka |
| CloudFront prod-Foreign | ET4SVT8DC9P9M | live AWS | wysoka |
| CloudFront dev-Baltic | E12KV5NOV0I551 | live AWS | wysoka |
| CloudFront dev-CZ/SK/HU | E3LC30816FMUSK | live AWS | wysoka |
| ECR prod | rshopapp-prod | live AWS | wysoka |
| ECR dev | rshopapp-dev | live AWS | wysoka |
| S3 CF templates | rshop-cf | live AWS | wysoka |
| S3 prod assets | rshop-prod | live AWS | wysoka |
| S3 dev assets | rshop-dev | live AWS | wysoka |

---

## CloudFormation — struktura stacków

### prod (root: `prod`) — UPDATE_COMPLETE

Nested stacks: VPCStack, SGStack, IAMStack, DBStack, ALBStack, ECSStack (+ sub-stacks per serwis), S3Stack, CFStack
Ostatni update roota: 2026-04-30
Templates na S3: `rshop-cf.s3.eu-central-1.amazonaws.com/*.yml`

### dev (root: `dev`) — **UPDATE_ROLLBACK_COMPLETE**

Nested stacks: VPCStack ⚠️, SGStack, EndPiontsStack, IAMStack ⚠️, ALBStack, DBStack, ECSStack, S3Stack ⚠️, CFStack
Root status: UPDATE_ROLLBACK_COMPLETE od 2026-04-28
Sub-stacks w UPDATE_ROLLBACK_COMPLETE: dev-VPCStack, dev-IAMStack, dev-S3Stack
ECSStack i sub-stacks ECS: UPDATE_COMPLETE (deployowane niezależnie od roota)
Templates na S3: `rshop-cf.s3.eu-central-1.amazonaws.com/dev/*.yml`

**Root cause rollbacku (potwierdzono z CFN events — live AWS):**
`jenkinsit` not authorized: `rds:ModifyDBSubnetGroup` na `dev-VPCStack-FFQTYHECIX9M-siecdb-fspddhruuczb`
Dwa failed attempty: 2026-04-28 09:05 i 16:42. Rollback kompletny o 18:05.

### akcesoria2-prod (root: `akcesoria2-prod`) — UPDATE_COMPLETE

Nested stacks: ECRStack, IAMStack, SGStack, ECSStack, SVCStack
Ostatni update: 2026-04-24
IaC lokalne: `cloudformation/akcesoria2/`

---

## VPC / Sieć

| VPC | CIDR | Tag | ID |
|-----|------|-----|----|
| prod | 10.0.0.0/16 | rshop-prod-VPC | vpc-08c5016cee20ad2ae |
| dev | 10.0.0.0/16 | rshop-dev-VPC | vpc-0befdfd9f1b71ebf6 |
| default | 172.31.0.0/16 | cos_dev | vpc-0f46b727b63c49da3 |

Default VPC otagowany "cos_dev" — przeznaczenie nieustalone.

**VPC Endpoints (8 endpointów, oba VPC):**

| Serwis | Typ | VPC |
|--------|-----|-----|
| com.amazonaws.eu-central-1.logs | Interface | prod + dev |
| com.amazonaws.eu-central-1.ecr.api | Interface | prod + dev |
| com.amazonaws.eu-central-1.ecr.dkr | Interface | prod + dev |
| com.amazonaws.eu-central-1.s3 | Gateway | prod + dev |

Źródło: `live AWS` — describe-vpc-endpoints.

---

## S3 Buckets

| Bucket | Cel | Tagi | Uwagi |
|--------|-----|------|-------|
| rshop-cf | CFN template artifacts | niezweryfikowane | TemplateURL source |
| rshop-prod | Statyczne assety prod | pełne LLZ tags ✅ | CloudFront origin |
| rshop-dev | Statyczne assety dev | pełne LLZ tags ✅ | dev CloudFront / ALB |
| rshop-dev-backup | Backup dev | niezweryfikowane | cel wymaga potwierdzenia |
| rshop-dev-bk | Backup dev | niezweryfikowane | duplikat rshop-dev-backup? |
| rshopp-logs | Logi | niezweryfikowane | **typo: rshopp zamiast rshop** |
| rshop-temp | Tymczasowy | niezweryfikowane | do usunięcia? |
| rshop-tmp | Tymczasowy | niezweryfikowane | do usunięcia? |
| 943111679945-terraform-state-bucket | Terraform state | niezweryfikowane | skąd Terraform w projekcie CFN? |
| terraform-states-rshop | Terraform state | niezweryfikowane | drugi bucket — duplikat? |

---

## ECR repozytoria

| Repozytorium | URI | Aktywne środowisko |
|--------------|-----|--------------------|
| rshopapp-prod | 943111679945.dkr.ecr.eu-central-1.amazonaws.com/rshopapp-prod | prod |
| rshopapp-dev | 943111679945.dkr.ecr.eu-central-1.amazonaws.com/rshopapp-dev | dev |
| rshopapp-qa | 943111679945.dkr.ecr.eu-central-1.amazonaws.com/rshopapp-qa | brak klastra/stacka |
| rshopapp-uat | 943111679945.dkr.ecr.eu-central-1.amazonaws.com/rshopapp-uat | brak klastra/stacka |
| akcesoria2-prod | 943111679945.dkr.ecr.eu-central-1.amazonaws.com/akcesoria2-prod | akcesoria2-prod |

---

## Secrets Manager

Secrets Manager: 0 sekretów w regionie eu-central-1 (sprawdzone live — list-secrets zwróciła pustą listę)

Możliwe alternatywne źródła sekretów (niezweryfikowane):
- SSM Parameter Store
- CloudFormation parameters (NoEcho)
- CI/CD credentials (Jenkins)
- hardcoded — do weryfikacji

| Secret | Przeznaczenie / zawartość logiczna | Źródło |
|--------|------------------------------------|--------|

---

## ACM Certyfikaty

ACM jest usługą regionalną. Sprawdzono oba regiony osobno:
- `eu-central-1` — certyfikaty używane przez ALB
- `us-east-1` — certyfikaty używane przez CloudFront

Obie listy zwróciły te same 5 certów — potwierdzone live. Interpretacja: te same certy są zarządzane w us-east-1 (CloudFront) i eu-central-1 (ALB), lub obie listy zwracają ten sam zasób (nie rozdzielone przez AWS w tym profilu).

| Domena główna | Region | Użycie | Status | Wygasa | InUse | Zakres / SANs |
|---------------|--------|--------|--------|--------|-------|---------------|
| dev.eshoprenault.lt | us-east-1 | CloudFront (dev) | **EXPIRED** | 2024-08-08 | False | dev Baltic: LT/LV/EE — **nie używany** |
| *.skleprenault.pl | us-east-1 | CloudFront (prod PL) | ISSUED | **2026-05-13** ⚠️ | True | *.eshoprenault.sk/.cz, *.eshopdacia.sk/.cz, *.webshopdacia.hu/.webshoprenault.hu |
| webshop.renault.hu | us-east-1 | CloudFront (prod HU/CZ/SK) | ISSUED | 2026-07-09 | True | eshop.dacia.cz/.sk, eshop.renault.cz/.sk, webshop.dacia.hu |
| dev.eshopdacia.lt | us-east-1 | CloudFront (dev Baltic) | ISSUED | 2026-11-04 | True | dev/devb eshop*.lt/.lv/.ee |
| sklep.renault.pl | us-east-1 | CloudFront (prod PL) | ISSUED | 2026-10-01 | True | bo.sklep.dacia.pl, bo.sklep.renault.pl, sklep.dacia.pl |

Certyfikaty ALB (eu-central-1): te same domeny pojawiły się w obu regionach — wymaga potwierdzenia czy to duplicate lub ten sam zasób listowany przez profil.

**Uwaga `*.skleprenault.pl`:** wygasa za 12 dni (2026-05-13). `RenewalEligibility=ELIGIBLE` — ACM powinno odnowić automatycznie, ale wymaga pomyślnej walidacji DNS/HTTP. Monitorować aktywnie.
**Uwaga `dev.eshoprenault.lt`:** EXPIRED, InUse=False. Wygasł 2024-08-08 — orphaned cert, do usunięcia lub odświeżenia.

---

## Observability

**Runtime health (live, 2026-05-01):**

| Element | Status | Uwagi |
|---------|--------|-------|
| rshop-prod — wszystkie 4 serwisy | desired=1, running=1, pending=0, ACTIVE | potwierdzono live |
| rshop-dev — wszystkie 4 serwisy | desired=1, running=1, pending=0, ACTIVE | potwierdzono live |
| akcesoria2-prod — oba serwisy | desired=1, running=1, pending=0, ACTIVE | potwierdzono live |
| prod-ALB target health | 10.0.1.123 healthy (1 TG sprawdzone) | pozostałe 9 TG: niezweryfikowane |
| dev-ALB target health | niezweryfikowane | describe-target-health nie wywołane |
| prod-ALB | active, internet-facing | live AWS |
| dev-ALB | active, internet-facing | live AWS |
| prod RDS | available | sqlserver-web, db.t3.large |
| dev RDS | available | sqlserver-ex, db.t3.small |
| CloudFront (4 dist.) | Deployed | live AWS |

**CloudWatch alarms:** 0 alarmów — describe-alarms uruchomione, lista pusta (live AWS, 2026-05-01).

**Log groups:**

| Log group | Retencja | Stored | Uwagi |
|-----------|----------|--------|-------|
| /ecs/rshop-prod | 1 dzień | 137 MB | ⚠️ produkcja — bardzo niska retencja |
| /ecs/rshop-dev | 1 dzień | 8.2 MB | niska retencja |
| /ecs/akcesoria2/prod | 14 dni | ~1 KB | jedyna z wystarczającą retencją |
| /ecs/jumphost-dev | 7 dni | 1.3 MB | |
| /ecs/jumphost-prod | 7 dni | 21 KB | |
| /ecs/jumphost | 1 dzień | 0 | orphaned? |
| /ecs/jumhost-qa | 1 dzień | 0 | **typo: jumhost; QA nie istnieje** |
| /ecs/nmap | 1 dzień | 0 | artefakt diagnostyczny |
| /ecs/Rshop-frontend | 1 dzień | 0 | orphaned, wielka litera |
| /ecs/api | 1 dzień | 0 | nazwa bez środowiska — orphaned? |
| /esc/backoffice | 1 dzień | 0 | **typo: /esc/ zamiast /ecs/** |
| /aws/ecs/containerinsights/akcesoria2-prod-Klaster/performance | 1 dzień | 4.2 MB | |
| /aws/ecs/containerinsights/rshop-prod-Klaster/performance | 1 dzień | 0 | |
| /aws/ecs/containerinsights/rshop-qa-Klaster/performance | 1 dzień | 0 | **QA klaster nie istnieje — orphaned** |
| RDSOSMetrics | 1 dzień | 0 | |

---

## Tagging / FinOps / LLZ / AWS WAF readiness

Sprawdź pokrycie tagów i gotowość governance. Status: `GO` = spełnione, `PARTIAL` = częściowe braki, `NO-GO` = sprawdzone i niespełnione, `niezweryfikowane` = nie sprawdzono.

| Obszar | Status | Uwagi |
|--------|--------|-------|
| FinOps — cost allocation tags (Project/Environment/CostCenter) | PARTIAL | Prod CFN stacks + S3: ✅. Dev CFN stacks: brak CostCenter. Dev S3: ✅ |
| LLZ tagging standard (Project/Environment/Owner/ManagedBy/CostCenter) | PARTIAL | Prod: ✅ pełne (Owner=DC-devops, CostCenter=DC). Dev CFN stacks: tylko Project+Environment. Dev S3: ✅ |
| ECS/Fargate — tag propagation do tasków (`propagate_tags`) | GO | propagateTags=SERVICE potwierdzone na rshop-prod-api-svc |
| ECR — tagi na repozytoriach | niezweryfikowane | Nie sprawdzono |
| S3 — tagi na bucketach | PARTIAL | rshop-prod: ✅. rshop-dev: ✅. Pozostałe 8 bucketów: niezweryfikowane |
| CloudWatch Log Groups — tagi | niezweryfikowane | Nie sprawdzono |
| VPC / Endpoints — tagi | niezweryfikowane | Nie sprawdzono |
| AWS WAF — obecność i przypisanie właściciela | NO-GO | 0 WAF ACLs sprawdzone: wafv2 list-web-acls REGIONAL (eu-central-1) + CLOUDFRONT (us-east-1) |

### Wymagane tagi LLZ

| Tag | Prod | Dev (CFN stacks) | Dev (S3) |
|-----|------|-----------------|----------|
| Project | rshop ✅ | rshop ✅ | rshop ✅ |
| Environment | prod ✅ | dev ✅ | dev ✅ |
| Owner | DC-devops ✅ | brakuje ❌ | DC-devops ✅ |
| ManagedBy | cloudformation ✅ | brakuje ❌ | cloudformation ✅ |
| CostCenter | DC ✅ | brakuje ❌ | DC ✅ |

### Wniosek

Prod i dev S3 są w pełni otagowane zgodnie ze standardem LLZ. Dev CFN stacks (VPCStack, EndPiontsStack i inne) mają tylko `Project` i `Environment` — brakuje Owner, ManagedBy i CostCenter. Brak AWS WAF na poziomie ALB i CloudFront. Brak FinOps cost allocation dla dev środowiska przez CFN (CostCenter niezidentyfikowane). ECS tag propagation działa poprawnie.

### Następne kroki

| Akcja | Priorytet | Kto |
|-------|-----------|-----|
| Dodać Owner/ManagedBy/CostCenter do dev CFN templates (root-dev.yml stack tags) | ŚREDNI | DC-devops |
| Wdrożyć AWS WAF (min. rate limiting + managed rules) dla prod CloudFront/ALB | WYSOKI | DC-devops |
| Zweryfikować tagi ECR, log groups, VPC endpoints | NISKI | DC-devops |

---

## Scheduler / automatyzacje

| Automatyzacja | Harmonogram | Zakres | Uwagi |
|--------------|-------------|--------|-------|
| EventBridge rules | brak | — | list-rules zwróciła pustą listę (live AWS) |

---

## Znane problemy / dług techniczny

| Problem | Priorytet | Evidence | Opis |
|---------|-----------|----------|------|
| Cert `*.skleprenault.pl` wygasa 2026-05-13 (12 dni) | WYSOKI | live AWS ACM us-east-1, InUse=True, RenewalEligibility=ELIGIBLE | Pokrywa prod PL sites (sklep.renault.pl, sklep.dacia.pl, .cz, .sk, .hu). Auto-renewal możliwe, ale wymaga pomyślnej walidacji DNS/HTTP. Monitorować. |
| Dev root stack UPDATE_ROLLBACK_COMPLETE | WYSOKI | live AWS CFN describe-stacks | Rollback zakończony 2026-04-28. Ryzyko przyszłych update'ów dev infra przez CFN root. Nie aktywna blokada — ECS działa niezależnie. |
| jenkinsit brak `rds:ModifyDBSubnetGroup` | WYSOKI | live AWS CFN events: AccessDenied na dev-VPCStack SiecDB | Każda próba update VPCStack (SiecDB subnet group) kończy się failem. Wymagana zmiana IAM policy jenkinsit. |
| 0 CloudWatch alarms | WYSOKI | live AWS describe-alarms: pusta lista | Brak monitoringu na jakimkolwiek zasobie. Observability gap — awaria wykrywana przez użytkowników. |
| 1-day log retention — prod ECS | WYSOKI | live AWS describe-log-groups: /ecs/rshop-prod retention=1 | 137MB logów, retencja 1 dzień. Niemożliwe dochodzenie incydentów starszych niż 24h. |
| Brak AWS WAF | WYSOKI | live AWS wafv2: 0 ACLs REGIONAL + CLOUDFRONT | Brak ochrony OWASP top 10, rate limiting, bot protection na prod ALB i CloudFront. |
| Cert `dev.eshoprenault.lt` EXPIRED us-east-1 | ŚREDNI | live AWS ACM us-east-1, EXPIRED 2024-08-08, InUse=False | Orphaned cert. Do usunięcia lub odświeżenia jeśli dev Baltic aktywny. |
| RDS prod bez MultiAZ | ŚREDNI | live AWS describe-db-instances: MultiAZ=False | sqlserver-web, db.t3.large, SingleAZ — SPOF dla bazy produkcyjnej. |
| Dev tagging niekompletne na CFN stacks | ŚREDNI | live AWS resourcegroupstaggingapi | dev-VPCStack, dev-EndPiontsStack: tylko Project+Environment. Brak Owner/ManagedBy/CostCenter. |
| Dev ECSStack deployowany poza root stack | ŚREDNI | CFN: ECSStack UPDATE_COMPLETE 2026-04-30; root UPDATE_ROLLBACK_COMPLETE 2026-04-28 | ECS jest aktualizowany z pominięciem CFN root orchestration. Drift między stanem infra a IaC. |
| Orphaned S3 buckets | ŚREDNI | live AWS S3 | rshop-temp, rshop-tmp, rshopp-logs (typo). Niezdefiniowany cel. Do weryfikacji i usunięcia. |
| 2 terraform state buckets | ŚREDNI | live AWS S3 | 943111679945-terraform-state-bucket + terraform-states-rshop. Skąd Terraform w projekcie CFN? |
| Orphaned log groups | NISKI | live AWS describe-log-groups | /ecs/Rshop-frontend, /ecs/api, /esc/backoffice (typo), /ecs/nmap, /ecs/jumhost-qa — 0 bytes stored |
| ECR qa/uat bez środowiska | INFO | live AWS ECR | rshopapp-qa, rshopapp-uat — repozytoria istnieją, klastry nie. |
| Default VPC otagowany "cos_dev" | INFO | live AWS describe-vpcs | Przeznaczenie nieustalone. |

---

## Różnice IaC vs Runtime

| Obszar | IaC | Runtime AWS | Ocena |
|--------|-----|-------------|-------|
| RDS dev engine | IaC (db.yml): Engine comentowane, brak default; root-dev.yml hint: sqlserver-ee | live AWS: sqlserver-ex (Express Edition) | rozbieżność |
| Dev root stack state | IaC intent: UP_TO_DATE | live AWS: UPDATE_ROLLBACK_COMPLETE | rozbieżność |
| Prod IaC repo | infra-rshop/cloudformation/root.yml | vault historyczny: rshop-cloudformation repo | wymaga potwierdzenia |
| CFN templates faktyczne | lokalne w infra-rshop | na S3 rshop-cf (TemplateURL) — kopia może się różnić | wymaga potwierdzenia |

---

## Drift / niespójności architektury

| Obszar | Typ driftu | Źródło | Opis |
|--------|-----------|--------|------|
| RDS dev edition: sqlserver-ex vs IaC | IaC vs runtime | live AWS + IaC (db.yml) | Runtime: sqlserver-ex (Express, limit 10GB RAM/1CPU/10GB DB). IaC: Engine parametryzowany ale comentowany; root-dev.yml sugerował sqlserver-ee. Możliwa ręczna zmiana edycji. |
| Dev ECS deployowany poza root stack | IaC vs runtime | live AWS CFN events | ECSStack aktualizowany bezpośrednio (dev-ECSStack-1BLAWHL0P6JKO UPDATE_COMPLETE 2026-04-30), root w ROLLBACK. Brak orchestracji CFN root. |
| CFN templates: lokalny checkout vs S3 | multi-repo | IaC + live AWS | infra-rshop ma lokalne templates, ale CFN deployuje z TemplateURL → rshop-cf S3. Lokalna kopia może być nieaktualna lub inna od live. |
| Prod IaC source of truth | multi-repo | vault historyczny | Vault historyczny wspomina `rshop-cloudformation` jako prod repo. Bieżący skan: prod zarządzany z infra-rshop/cloudformation/root.yml. Nie potwierdzono ani nie obalono rshop-cloudformation. |

---

## Pewność ustaleń

| Obszar | Pewność | Evidence | Uwagi |
|--------|---------|----------|-------|
| Account ID, IAM principal | wysoka | live AWS sts get-caller-identity | |
| ECS cluster/service state | wysoka | live AWS describe-services (3 klastry) | |
| ALB target health | częściowa | live AWS: 1 TG sprawdzone (prod) | pozostałe 9 TG niezweryfikowane |
| RDS state i engine | wysoka | live AWS describe-db-instances | |
| CloudFront distributions | wysoka | live AWS list-distributions | |
| CFN stack statuses | wysoka | live AWS list-stacks | 30+ stacków |
| Dev stack root cause | wysoka | live AWS CFN events: AccessDenied na rds:ModifyDBSubnetGroup | |
| ACM certs status | wysoka | live AWS eu-central-1 + us-east-1 | oba regiony sprawdzone |
| CloudWatch alarms | wysoka | live AWS describe-alarms: 0 alarmów | |
| Secrets Manager | wysoka | live AWS list-secrets: 0 sekretów | |
| WAF | wysoka | live AWS wafv2: 0 ACLs | REGIONAL + CLOUDFRONT |
| Tagging (prod/dev S3) | wysoka | live AWS S3 get-bucket-tagging | |
| Tagging (CFN stacks sample) | częściowa | live AWS resourcegroupstaggingapi | sample z 15 zasobów |
| Tagging (ECR, log groups, endpoints) | niska | nie sprawdzono | niezweryfikowane |
| VPC / sieć | wysoka | live AWS describe-vpcs | |
| VPC endpoints | wysoka | live AWS describe-vpc-endpoints | |
| Routing ALB → serwis (listener rules) | niska | TG potwierdzone, reguły listenerów nie sprawdzone | wymaga potwierdzenia |
| IaC: prod repo source of truth | niska | infra-rshop przejrzany, rshop-cloudformation niedostępny | wymaga potwierdzenia z zespołem |
| SSM Parameter Store | niska | nie sprawdzono | niezweryfikowane |

---

## Dostęp diagnostyczny

```bash
# ECS health — wszystkie klastry
aws ecs describe-services \
  --cluster rshop-prod-Klaster \
  --services rshop-prod-api-svc rshop-prod-backoffice-svc rshop-prod-frontend-svc1 rshop-prod-frontend-svc2 \
  --profile rshop --region eu-central-1

# Zatrzymane taski (diagnoza crashu)
aws ecs list-tasks --cluster rshop-prod-Klaster --desired-status STOPPED \
  --profile rshop --region eu-central-1

# ALB target health — wszystkie TG
aws elbv2 describe-target-health --target-group-arn <arn> \
  --profile rshop --region eu-central-1

# ACM cert status prod
aws acm describe-certificate \
  --certificate-arn arn:aws:acm:us-east-1:943111679945:certificate/3be77743-e90b-4d21-ba97-c6193c8bc977 \
  --profile rshop --region us-east-1

# Dev stack rollback root cause
aws cloudformation describe-stack-events \
  --stack-name dev-VPCStack-FFQTYHECIX9M \
  --profile rshop --region eu-central-1 \
  --query 'StackEvents[?ResourceStatus==`UPDATE_FAILED`].[LogicalResourceId,ResourceStatusReason]'

# Tagging audit — zasoby bez LLZ tags
aws resourcegroupstaggingapi get-resources \
  --profile rshop --region eu-central-1 \
  --tag-filters Key=Environment,Values=dev
```

---

## Źródła użyte

| Źródło | Zakres | Status |
|--------|--------|--------|
| live AWS | ecs, elbv2, rds, cloudfront, cloudformation, s3, ecr, logs, cloudwatch, ec2, secretsmanager, wafv2, events, resourcegroupstaggingapi, acm | sprawdzone |
| live AWS us-east-1 | acm | sprawdzone |
| repo lokalne | infra-rshop/cloudformation/ (root.yml, db.yml, dev/) | sprawdzone częściowo |
| IaC | CloudFormation — root.yml (prod), root-dev.yml (dev), db.yml | sprawdzone częściowo |
| CFN stacks | wszystkie 30+ stacków przez list-stacks + describe-stack-events (dev, dev-VPCStack) | sprawdzone |
| vault historyczny | rshop-tagging-baseline-2026-04-24, poprzedni snapshot | użyte (weryfikacja rozbieżności) |
| extra_regions | us-east-1 (ACM) | sprawdzone |

## Fakty live vs historia vault

| Informacja | Status | Źródło | Uwagi |
|------------|--------|--------|-------|
| Dev root stack UPDATE_ROLLBACK_COMPLETE | live | live AWS | Potwierdzone. Root cause: jenkinsit brak rds:ModifyDBSubnetGroup. |
| Prod root stack UPDATE_COMPLETE | live | live AWS | Aktualny od 2026-04-30. |
| 0 CloudWatch alarms | live | live AWS | Potwierdzone — describe-alarms pusta lista. |
| ACM cert `*.skleprenault.pl` wygasa 2026-05-13 | live | live AWS us-east-1 | Nowe ustalenie — poprzedni snapshot nie miał statusu certów. |
| ACM cert `dev.eshoprenault.lt` EXPIRED | live | live AWS us-east-1 | Nowe ustalenie — InUse=False. |
| Brak WAF | live | live AWS | Nowe ustalenie w tym skanie. |
| ECS services: desired=running=1 | live | live AWS | Wszystkie 3 klastry w pełni sprawne. |
| Prod IaC z rshop-cloudformation | historyczna | vault historyczny | Nie potwierdzono — infra-rshop ma root.yml z Default:prod. Wymaga wyjaśnienia z zespołem. |
| Dev ECS deployowany poza root orchestration | live | live AWS | ECSStack UPDATE_COMPLETE 2026-04-30, root ROLLBACK. |
| Tagging dev CFN stacks niekompletne | live | live AWS resourcegroupstaggingapi | Potwierdzone — brak Owner/ManagedBy/CostCenter. |

---

## Powiązane

- [[rshop-tagging-baseline-2026-04-24]]
- [[rshop-tagging-remediation-2026-04-24]]
- [[vpc-endpoints-tagging-audit-2026-04-24]]
- [[finops-rshop]]
