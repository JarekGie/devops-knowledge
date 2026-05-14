# rshop — Session Log

Format: data, co zrobiono, gdzie skończono, co następne.

---

## 2026-05-12 — FE dev-scan Jenkinsfile fix (CFN-MUT-001)

**Plik:** `jenkinsfiles/FE/r-shop-all-dev-scan.jenkinsfile` (branch: master, commit: `ef565fb`)

`r-shop-all-dev-scan.jenkinsfile` (pipeline z Trivy/Sonar/OWASP) celował w root stack `dev` — identyczny hazard CFN-MUT-001 jak w `r-shop-all.jenkinsfile`. Fix analogiczny.

**Zmiany:**
- `CfnStackName = 'dev-ECSStack-1BLAWHL0P6JKO'` dla dev
- Parametry dev: `frontendimg`/`frontendimg2` (ECSStack scope) + `UsePreviousValue=true`
- Usunięto hardcoded ALB DNS/TG ARNy (były dev-specific, błędnie w QA path)
- Preflight gate (sprawdza status ECSStack przed create-change-set)
- Change-set guard (blokuje execute jeśli denied resource types/logical IDs)
- `execute-change-set` i `wait` używają `${CfnStackName}`
- `def changeSetIdFrontend = ''` na poziomie pipeline (fix Groovy warning)
- QA: bez zmian (root stack params `FrontendImg`/`FrontendImgD`)

**Nie zmieniano:** DC (OWASP), Sonarqube, Trivy, build stages, post/email.

---

## 2026-05-12 — CFN root stack dev recovery + FE Jenkinsfile fix

### FE Jenkinsfile — CFN-MUT-001 fix

**Plik:** `jenkinsfiles/FE/r-shop-all.jenkinsfile` (branch: master)

Naprawiono FE pipeline analogicznie do wcześniejszej poprawki BE. Poprzedni FE deploy celował w root stack `dev` → change set modyfikował wszystkie nested stacks (VPC/DB/ECS/IAM...) → hazard CFN-MUT-001.

**Zmiany:**
- Dodano `CfnStackName = dev ? 'dev-ECSStack-1BLAWHL0P6JKO' : UpEnv`
- Dev: parametry `frontendimg`/`frontendimg2` (ECSStack scope), nie root `FrontendImg`/`FrontendImgD`
- Dev: preflight gate (describe-stacks → status check, blokuje `*_IN_PROGRESS`/`FAILED`)
- Dev: change-set guard (tokenize + denied list: VPCStack/DBStack/SGStack/IAMStack/S3Stack/CFStack + `AWS::EC2::`/`AWS::RDS::`/`AWS::IAM::`/`AWS::S3::`/`AWS::ElasticLoadBalancingV2::`)
- `execute-change-set` i `wait stack-update-complete` → `${CfnStackName}` we wszystkich envach
- QA/UAT: zachowanie bez zmian

### CFN dev stack recovery — UPDATE_ROLLBACK_FAILED odblokowany

**Przyczyna wejścia w ROLLBACK_FAILED:** Poprzedni FE deploy uruchomił root stack update → VPCStack → SiecDB (DBSubnetGroup) → `rds:ModifyDBSubnetGroup` denied dla `jenkinsit`

**Historia problemu:** Trwał od 2026-04-28 (wielokrotne nieudane próby continue-update-rollback).

**Diagnostyka:**
- Root: `UPDATE_ROLLBACK_FAILED` — 4 nested stacks failed
- VPCStack: `UPDATE_ROLLBACK_FAILED` — `SiecDB` (RDS DBSubnetGroup) = real blocker
- SiecDB error: `User jenkinsit not authorized to perform rds:ModifyDBSubnetGroup`
- IAMStack, S3Stack, ECSStack: `Resource update cancelled` = cascade noise (już w CLEANUP)

**CFN limitacje napotkane podczas recovery:**
- `VPCStack.SiecDB` w `--resources-to-skip` → `Stack [VPCStack] does not exist` — bug CFN gdy nested stack sam jest w `UPDATE_ROLLBACK_FAILED`
- `continue-update-rollback` na child stacks → `RollbackUpdatedStack cannot be invoked on child stacks` — twarde ograniczenie CFN
- Skip całego `VPCStack` = irrecoverable (VPCStack zostaje na zawsze w FAILED, brak możliwości naprawy potem)

**Zastosowane rozwiązanie:**
1. Dodano temporary inline policy do `jenkinsit`: `rds:ModifyDBSubnetGroup`, `Resource: *`
   - Policy name: `cfn-rollback-temp-rds-fix`
2. `continue-update-rollback --stack-name dev` (bez skip)
3. Root → `UPDATE_ROLLBACK_COMPLETE` w ~34s
4. **Usunięto inline policy natychmiast po recovery** → `jenkinsit` wróciło do oryginalnych uprawnień

**Wynik:**
- Root `dev`: `UPDATE_ROLLBACK_COMPLETE` ✅
- VPCStack: `UPDATE_ROLLBACK_COMPLETE` ✅ — wszystkie zasoby `UPDATE_COMPLETE` / `CREATE_COMPLETE`
- SiecDB (DBSubnetGroup): `UPDATE_COMPLETE` ✅ — prawidłowo rollbackowany (zero drift)
- `jenkinsit` inline policies: `[]` (puste — cleanup done)

**Drift:** ZERO — wszystkie zasoby w stanie sprzed failed update.

**Trwałe działania prewencyjne (niezbędne):**
- FE Jenkinsfile poprawiony — deploy celuje w ECSStack, nie root
- Root stack `dev` NIE powinien być aktualizowany przez żaden CI/CD pipeline
- Rozważyć dodanie `rds:ModifyDBSubnetGroup` do `Rshop-dev-policy` (lub dedykowanej roli CFN) — brak tej akcji zablokuje każdy przyszły CFN update zawierający VPCStack

---

## 2026-05-08 — ECS deploy RCA + ACM cert migration

**Co zrobiono:**

### 1. ECS deploy failure RCA (dev)

- `dev-ECSStack-1BLAWHL0P6JKO` — pełne dochodzenie evidencyjne
- Root cause: ECS nie ustabilizował nowych kontenerów (health check lub startup crash) przez 3h → CFN `NotStabilized` → automatyczny rollback
- `ValidationError` — symptom wtórny: Jenkins uruchomił concurrent deploy podczas `UPDATE_IN_PROGRESS`
- Serwisy po rollbacku: ACTIVE, desired=1, running=1 ✅
- RCA: `rca-ecs-deploy-failure-2026-05-08.md`

### 2. ACM cert risk assessment

- Cert `*.skleprenault.pl` (`3be77743`) — wygasa 2026-05-13, `RenewalStatus=PENDING_VALIDATION`
- Blokada: `*.webshopdacia.hu` + `*.webshoprenault.hu` → NXDOMAIN w .hu TLD
- Cert używany przez: `E3LC30816FMUSK` (dev CloudFront) — produkcja niezagrożona
- Raport: `acm-cert-renewal-risk-2026-05-08.md`

### 3. ACM cert migration (zero downtime)

- Nowy cert wydany: `72123357-5a77-4b60-84b1-f59e5282270e`, NotAfter 2026-11-22
  - 7 SANów: `*.skleprenault.pl`, `skleprenault.pl`, `*.sklepdacia.pl`, `*.eshopdacia.sk`, `*.eshoprenault.sk`, `*.eshopdacia.cz`, `*.eshoprenault.cz`
  - ISSUED w ~20s (wszystkie CNAMEs walidacyjne były w DNS)
- CF `E3LC30816FMUSK` zaktualizowany:
  - Nowy cert przypisany
  - 4 martwe aliasy `.hu` usunięte (NXDOMAIN)
  - 12 aktywnych aliasów pozostało
- TLS zweryfikowany openssl (5 SNI aliasów) → `notAfter=Nov 21 2026` ✅
- Stary cert `3be77743` — nieusunięty, rollback gotowy do 2026-05-13
- Dokumentacja: `acm-cert-migration-2026-05-08.md`

**Stan na koniec sesji:**
- Dev CF: nowy cert aktywny, TLS działa ✅
- Prod: niezagrożona, osobne certy ✅
- Stary cert: ISSUED, InUseBy=[], wygasa 2026-05-13

**Następna sesja:**
- [ ] Cleanup: usuń stary cert `3be77743` (po 2026-05-23)
- [ ] Cleanup: usuń orphaned cert `dev.eshoprenault.lt` (`173ae59f`, EXPIRED 2024-08-08)
- [ ] Dodaj CloudWatch alarm `DaysToExpiry < 30` dla nowego certu
- [ ] ECS deploy failure — zbadać przyczynę przed kolejnym deployem
- [ ] Jenkins: preflight check stanu CFN stacka przed deploy (P0)
- [ ] Zwiększyć retencję `/ecs/rshop-dev` z 1 dnia na 14+ dni (P0)

---

## 2026-05-14 — rshop dev FE deploy separation / pre-deploy verification

**Zakres:** repo `~/projekty/mako/eshop-cicd`, Jenkinsfile `jenkinsfiles/FE/r-shop-all-dev-scan.jenkinsfile`, env `dev`.

**Problem historyczny:**
- FE deploy aktualizował parent nested stack `dev-ECSStack-1BLAWHL0P6JKO`.
- Parent orchestration uruchamiał rollout nested stacków `api` i `backoffice`.
- ECS próbował pobrać nieistniejące obrazy `rshopapp-dev:api.650` i `rshopapp-dev:backoffice.650`.
- Skutek: `CannotPullContainerError`, CFN rollback parent stacka, mimo że fronty były poprawne.

**Naprawa Jenkinsfile:**
- Commit pushed do `origin/master`:
  - `aff7f1dc675b2a2c532344c4bb3771a95015d618`
  - message: `fix(rshop-fe): deploy dev frontend via child CloudFormation stacks only`
- Dev path:
  - loguje `DEV FE deploy uses child stacks only`
  - odkrywa fizyczne child stacki przez `describe-stack-resources` na parent stacku
  - tworzy osobne ChangeSety tylko dla:
    - `FrontendRenault`
    - `FrontendDacia`
  - używa `--stack-name ${cfg.stackName}` przy `create-change-set`
  - używa `--stack-name ${target.stackName}` przy `execute-change-set`
  - ma guard przed parent stackiem i przed logical IDs `api` / `backoffice`
  - blokuje empty/no-op ChangeSet przed execute
  - polluje child stacki custom pollingiem, timeout 4h
- Non-dev path nie był celowo refaktorowany; parent `CfnStackName` nadal występuje w ścieżce `else`.

**READ-ONLY verification przed kolejnym deployem FE:**
- AWS profile: `rshop`
- Region: `eu-central-1`
- Parent stack:
  - `dev-ECSStack-1BLAWHL0P6JKO = UPDATE_ROLLBACK_COMPLETE`
  - `LastUpdated = 2026-05-12T21:06:54Z`
- Nested stack resources z parenta:
  - `FrontendRenault = UPDATE_COMPLETE`
  - `FrontendDacia = UPDATE_COMPLETE`
  - `api = UPDATE_COMPLETE`
  - `backoffice = UPDATE_COMPLETE`
- Fizyczne FE child stacki:
  - `dev-ECSStack-1BLAWHL0P6JKO-FrontendRenault-PO8N6MN3IGSI = UPDATE_COMPLETE`
  - `dev-ECSStack-1BLAWHL0P6JKO-FrontendDacia-1F7C2JWZJFSKZ = UPDATE_COMPLETE`
- ECS services:
  - `rshop-dev-frontend-svc1`: rollout `COMPLETED`, desired/running/pending `1/1/0`, task `dev-frontend-task:1910`
  - `rshop-dev-frontend-svc2`: rollout `COMPLETED`, desired/running/pending `1/1/0`, task `dev-frontend-task:1911`
  - `rshop-dev-api-svc`: rollout `COMPLETED`, desired/running/pending `1/1/0`, task `dev-api-task:1067`
  - `rshop-dev-backoffice-svc`: rollout `COMPLETED`, desired/running/pending `1/1/0`, task `dev-backoffice-task:1066`
- ALB target health frontów:
  - `dev-frontend-ALB-TG`: target `10.0.2.127:3000`, `healthy`
  - `dev-frontend2-ALB-TG`: target `10.0.1.40:3000`, `healthy`
- Git remote:
  - `origin/master = aff7f1dc675b2a2c532344c4bb3771a95015d618`
  - remote Jenkinsfile zawiera child-stack-only logikę.

**Werdykt:** `GO` dla kolejnego FE deploya, pod warunkiem że Jenkins checkoutuje commit `aff7f1dc675b2a2c532344c4bb3771a95015d618`.

**Warunki GO w Jenkins console:**
- Checkout revision musi być `aff7f1dc675b2a2c532344c4bb3771a95015d618`.
- Log musi zawierać `DEV FE deploy uses child stacks only`.
- ChangeSet names muszą mieć postać:
  - `changeSet-<build>-FrontendRenault`
  - `changeSet-<build>-FrontendDacia`
- Nie może pojawić się:
  - `create-change-set --stack-name dev-ECSStack-1BLAWHL0P6JKO`
  - `execute-change-set --stack-name dev-ECSStack-1BLAWHL0P6JKO`

**Pozostałe ryzyka:**
- Jenkins Replay, job-level script override albo checkout innego commita/brancha może ominąć patch.
- Jeśli child template nie ma parametru `frontend`, ChangeSet failnie przed execute; nie powinno to dotknąć `api` ani `backoffice`.
- Historyczne CFN events parenta nadal zawierają rollback z `api/backoffice`, ale aktualny runtime jest terminalny i zdrowy.
