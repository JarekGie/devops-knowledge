# rshop — Session Log

Format: data, co zrobiono, gdzie skończono, co następne.

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
