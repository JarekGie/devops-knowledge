# Execution Log: planodkupow-qa CFN Rebuild

#incident #aws #cloudformation #planodkupow

**Data:** 2026-04-19  
**Operator:** Jarosław Gołąb + Claude  
**Cel:** Delete + redeploy planodkupow-qa po UPDATE_ROLLBACK_FAILED  
**Runbook:** [[planodkupow-qa-cfn-rebuild]]  
**Status:** FAZA DELETE — COMPLETE | FAZA REDEPLOY — DO WYKONANIA

---

## Środowisko

```
Konto AWS:   333320664022 (planodkupow)
Region:      eu-central-1
Profil CLI:  plan
Root stack:  planodkupow-qa
```

---

## FAZA 0 — Diagnoza (2026-04-19 rano)

### Stan stacka przed działaniem

```
planodkupow-qa: UPDATE_ROLLBACK_FAILED
Ostatni błąd:  "Stack [RabbitMQStack] does not exist"
```

### Nested stacks — status

```bash
aws cloudformation list-stack-resources --stack-name planodkupow-qa \
  --profile plan --region eu-central-1
```

| Logical ID | Status | Powód |
|---|---|---|
| ALBStack | UPDATE_COMPLETE | — |
| CFStack | UPDATE_COMPLETE | — |
| DBStack | UPDATE_FAILED | "Resource update cancelled" |
| KlasterStack | UPDATE_COMPLETE | — |
| RabbitMQStack | UPDATE_FAILED | "Currently in UPDATE_ROLLBACK_FAILED, BasicBroker failed" |
| RedisStack | UPDATE_FAILED | "Resource update cancelled" |
| S3Stack | UPDATE_COMPLETE | — |
| SecGroupStack | UPDATE_COMPLETE | — |
| VPCStack | UPDATE_COMPLETE | — |

### Eventy nested stacków

**RabbitMQStack:**
```
19:21:46  UPDATE_ROLLBACK_IN_PROGRESS (User Initiated)
19:21:49  BasicBroker UPDATE_FAILED — "This account is suspended (Lambda 403)"
19:21:50  UPDATE_ROLLBACK_FAILED
```

**DBStack:**
```
18:32:09  UPDATE_ROLLBACK_IN_PROGRESS (Initiated by parent)
18:32:10  SQLDatabase UPDATE_FAILED — "Resource update cancelled"
20:04:14  UPDATE_ROLLBACK_FAILED — [SQLDatabase]
```

**RedisStack:**
```
18:32:04  RedisCache UPDATE_FAILED — "Cannot find version 5.0.0 for redis" (EOL)
18:32:05  UPDATE_ROLLBACK_IN_PROGRESS
19:22:04  RedisCache UPDATE_COMPLETE (rollback ZAKOŃCZONY sukcesem)
19:22:05  UPDATE_ROLLBACK_COMPLETE_CLEANUP_IN_PROGRESS
```

### Poprzednie próby continue-update-rollback (przez kogoś innego)

```
05:45  UPDATE_ROLLBACK_FAILED — "Only the resources failed during UpdateRollback are allowed to be skipped"
05:50  UPDATE_ROLLBACK_FAILED — "Only the resources failed during UpdateRollback are allowed to be skipped"
05:51  UPDATE_ROLLBACK_FAILED — "Nested stacks could not be skipped"
06:06  UPDATE_ROLLBACK_FAILED — "Stack [RabbitMQStack] does not exist"
06:11  UPDATE_ROLLBACK_FAILED — "Stack [RedisStack] does not exist"
06:21  UPDATE_ROLLBACK_FAILED — "Stack [RabbitMQStack] does not exist"
06:25  UPDATE_ROLLBACK_FAILED — "Stack [DBStack] does not exist"
06:28  UPDATE_ROLLBACK_FAILED — "Only the resources failed during UpdateRollback are allowed to be skipped"
06:34  UPDATE_ROLLBACK_FAILED — "Stack [RabbitMQStack] does not exist"
```

**Wniosek:** continue-update-rollback niewykonalny. Decyzja: delete + redeploy.

---

## FAZA 1 — Backup (2026-04-19 ~09:00)

### RDS DeletionProtection — WŁĄCZONO

```bash
aws rds modify-db-instance \
  --db-instance-identifier planodkupowqadb \
  --deletion-protection \
  --apply-immediately \
  --profile plan --region eu-central-1
# Output: DeletionProtection: True ✓
```

### RDS Snapshot

```bash
aws rds create-db-snapshot \
  --db-instance-identifier planodkupowqadb \
  --db-snapshot-identifier planodkupow-qa-pre-rebuild-20260419-0849 \
  --profile plan --region eu-central-1
# Status: available ✓ (20 GB, sqlserver-ex 15.00.4073.23.v1)
```

### Backup dir: `~/planodkupow-qa-backup-20260419/`

Zawiera:
- `BACKUP-SUMMARY.md` — główny plik z wszystkimi danymi
- `alb-qa-*.json` — ALB konfiguracja, listeners, rules, target groups
- `cloudfront-qa-full.json` — CloudFront pełna konfiguracja
- `route53-planodkupow-qa-zone.json` — 13 rekordów DNS prywatnych
- `vpc-*.json` — VPC, subnety, routing
- `ecs-services-config.json` — 14 serwisów ECS
- `mq-broker-b-81d3e96e-*.json` — RabbitMQ broker config
- `redis-qa-config.json` — ElastiCache config
- `security-groups-qa.json` — SG rules (zapisane w trakcie usuwania)

### Kluczowe wartości do redeploy

```
ALB security token:  x-sec-token: 3E4yBmL1sERAvKwT
CloudFront ID:       E30ZEJ5EBK0T8D (alias: planodkupow-qa.makotest.pl)
CloudFront ETag:     E18COAQRK5Y6C8
ACM cert (us-east-1): 7cac4e30-0aa1-4a5e-92ac-eec445ee6601
RDS endpoint:        planodkupowqadb.cdjpbne01sww.eu-central-1.rds.amazonaws.com:1433
RDS snapshot:        planodkupow-qa-pre-rebuild-20260419-0849
MQ broker ID:        b-81d3e96e-7e64-450d-970d-ec457c74a15e
MQ endpoint:         amqps://b-81d3e96e-7e64-450d-970d-ec457c74a15e.mq.eu-central-1.amazonaws.com:5671
VPC ID:              vpc-02f804baee8a3f048 (CIDR: 10.2.0.0/16)
DNS private zone:    Z09608113U2Z8FHEFIB7C (planodkupow.qa.)
```

---

## FAZA 2 — Audyt zasobów ręcznych

### Zasoby ręczne (NIE CFN)

| Zasób | Typ | Powód |
|---|---|---|
| `planodkupow-cf` | S3 bucket | `Provisioner: manual` — CFN templates |
| `planodkupow-s3-logi` | S3 bucket | `Provisioner: manual` — logi |
| `bastionhost` (sg-0c2ca2c65177931bc) | Security Group | Brak tagu CFN, brak ENI — orphan |
| Stack `sftp` | CFN top-level | AWS Transfer Family, niezależny |

### bastionhost SG — reguły (ZACHOWAĆ)

```
Inbound TCP 1433 from: 188.164.241.210/32, 195.117.107.110/32, 78.8.17.218/32
Inbound TCP 22   from: 0.0.0.0/0
```

DatabaseSG ma regułę wpuszczającą ruch z bastionhost — bezpośredni dostęp DBA do SQL Server.

### Zasoby CFN bez automatycznych tagów CFN (mylące — ale CFN managed)

ALB, ElastiCache, Amazon MQ nie propagują automatycznie tagu `aws:cloudformation:stack-name`. Zweryfikowane przez `describe-stack-resources`.

---

## FAZA 3 — Delete stacków

### Próba 1: delete root stack (09:22)

```bash
aws cloudformation delete-stack --stack-name planodkupow-qa \
  --profile plan --region eu-central-1
```

**Przebieg:** CFStack, KlasterStack, RabbitMQStack, ALBStack, RedisStack — usunięte OK.

**Fail 1 (09:36):** `DELETE_FAILED` — `[DBStack, S3Stack]`

```
DBStack/SQLDatabase: "Cannot delete protected DB Instance" (DeletionProtection)
S3Stack/S3Bucket:    "The bucket you tried to delete is not empty" (297 obj, 33MB)
S3Stack/S3FileBucket:"The bucket you tried to delete is not empty" (1302 obj, 162MB)
```

### Fix 1: delete DBStack i S3Stack z retain (09:44)

```bash
aws cloudformation delete-stack \
  --stack-name planodkupow-qa-DBStack-ZWZM5XD8MGCI \
  --retain-resources SQLDatabase SiecDB \
  --profile plan --region eu-central-1
# Wynik: DELETE_COMPLETE ✓ (RDS planodkupowqadb zachowany)

aws cloudformation delete-stack \
  --stack-name planodkupow-qa-S3Stack-Q99MN1145Z29 \
  --retain-resources S3Bucket S3FileBucket \
  --profile plan --region eu-central-1
# Wynik: DELETE_COMPLETE ✓ (buckety zachowane z danymi)
```

### Próba 2: retry root stack (09:51)

```bash
aws cloudformation delete-stack --stack-name planodkupow-qa \
  --profile plan --region eu-central-1
```

**Fail 2 (10:09):** `DELETE_FAILED` — `[SecGroupStack]`

```
SecGroupStack/DatabaseSG: "resource sg-031c0cd61c5d8ef88 has a dependent object"
(RDS używa DatabaseSG — nie można usunąć)
```

### Fix 2: delete SecGroupStack z retain DatabaseSG (10:13)

```bash
aws cloudformation delete-stack \
  --stack-name planodkupow-qa-SecGroupStack-1DFRR36S6WWNM \
  --retain-resources DatabaseSG \
  --profile plan --region eu-central-1
# Status: DELETE_IN_PROGRESS (w toku w momencie pisania)
```

**Odkrycie podczas fix 2:** SG `bastionhost` (sg-0c2ca2c65177931bc) w VPC — manualna, brak ENI (orphan). Zapisana w backup.

### Fail 3: SecGroupStack — TaskSG (10:31)

```
TaskSG DELETE_FAILED: "resource sg-02fc97a94aa3a036a has a dependent object"
```

**Przyczyna:** 4 manualne VPC Endpoints używają TaskSG — niewidoczne podczas audytu (brak tagów CFN):

| Endpoint | Serwis | Tag |
|---|---|---|
| vpce-0f06338f894336448 | ECR API | qa-ecr-api |
| vpce-0066f4327e86d8687 | ECR DKR | qa-ecr-dkr |
| vpce-0dcfc106af654bae6 | Secrets Manager | qa-ecr-secret-manager |
| vpce-093fc974c5ae750f4 | CloudWatch Logs | (brak) |

Backup: `~/planodkupow-qa-backup-20260419/vpc-endpoints.json`

**Fix 3:** retry z retain TaskSG + DatabaseSG:

```bash
aws cloudformation delete-stack \
  --stack-name planodkupow-qa-SecGroupStack-1DFRR36S6WWNM \
  --retain-resources DatabaseSG TaskSG \
  --profile plan --region eu-central-1
```

**Wniosek dla UAT/PROD:** przed delete sprawdź czy nie ma manualnych VPC Endpoints w VPC:
```bash
aws ec2 describe-vpc-endpoints \
  --filters "Name=vpc-id,Values=<VPC_ID>" \
  --profile <profile> --region eu-central-1 \
  --query 'VpcEndpoints[].{ID:VpcEndpointId,Service:ServiceName,Tags:Tags}'
```

### Fail 4: VPCStack (10:26+)

**Inicjacja:** root stack retry → VPCStack DELETE_IN_PROGRESS od ~10:26.

**Odkrycie blokerów w podsieciach** (audit ENI podczas oczekiwania):

Publiczne (PodsPub1 `subnet-049522191fe108784`, PodsPub2 `subnet-0f3ba588e935c435a`):
- `eni-0e9dd0667e09a945c` — GlobalAccelerator managed ENI (PodsPub1)
- `eni-06643b0b748d523f4` — NAT Gateway `nat-08adf3e0a226779a7` (PodsPub1)
- `eni-0bc3e7b87b93ce431` — GlobalAccelerator managed ENI (PodsPub2)

Prywatne (PodsPrv1 `subnet-09ab9fdda1c1d2dea`, PodsPrv2 `subnet-044777a4a035cb0ab`):
- 4x VPC Endpoint Interface ENI (vpce-0066f4327e86d8687, vpce-093fc974c5ae750f4, vpce-0dcfc106af654bae6, vpce-0f06338f894336448)
- `eni-0db3561a10a8d55e8` — RDSNetworkInterface (PodsPrv2)

**Wniosek:** GlobalAccelerator i NAT Gateway są manualne — niewidoczne w CFN. VPCStack osiągnie DELETE_FAILED.

**Już usunięte przez CFN podczas DELETE_IN_PROGRESS:**
- `ServiceDiscoveryNamespace` (ns-xiknwgpztou4hjcj) — DELETE_COMPLETE ⚠️ namespace `planodkupow.qa.` usunięty, trzeba odtworzyć przy redeploy
- `LocalRoutTable`, `PubTabRout`, route table associations, `PubRouteToInternet` — DELETE_COMPLETE

**Fix 4:** gdy VPCStack osiągnie DELETE_FAILED — retain wszystkich pozostałych:

```bash
aws cloudformation delete-stack \
  --stack-name planodkupow-qa-VPCStack-1OHNJ84RQI8K2 \
  --retain-resources \
    VPC Brama BramaToVPC \
    PodsPrv1 PodsPrv2 PodsPub1 PodsPub2 \
  --profile plan --region eu-central-1
```

(LocalRoutTable, PubTabRout, route associations, ServiceDiscoveryNamespace — już DELETE_COMPLETE, nie można ich retain)

**Decyzja:** Opcja A — retain VPC (cała sieć zostaje). Redeploy odtworzy route tables i Service Discovery namespace od nowa. RDS zostaje w tych samych podsieciach.

---

## Zasoby retainowane (po zakończeniu delete)

| Zasób | Physical ID | Powód retain |
|---|---|---|
| RDS SQLDatabase | planodkupowqadb | DeletionProtection + dane |
| RDS SiecDB | planodkupow-qa-dbstack-...-siecdb-... | Używana przez RDS |
| S3 S3Bucket | planodkupow-qa | 297 obiektów, 33MB |
| S3 S3FileBucket | planodkupow-qa-pliki | 1302 obiekty, 162MB |
| SG DatabaseSG | sg-031c0cd61c5d8ef88 | Używana przez RDS |
| VPC + subnety | vpc-02f804baee8a3f048 | RDS w VPC |
| IGW | igw-0862c2814f8c0265b | Infrastruktura VPC (route tables już usunięte przez CFN) |
| ~~Service Discovery NS~~ | ~~ns-xiknwgpztou4hjcj~~ | ~~Namespace planodkupow.qa.~~ DELETE_COMPLETE — trzeba odtworzyć |

---

## Wnioski dla wyższych środowisk (UAT/PROD)

### Co pójdzie inaczej

1. **DeletionProtection** — sprawdź PRZED delete czy jest włączone. Jeśli nie — włącz ręcznie.
2. **S3 buckety z danymi** — zawsze `--retain-resources`, nigdy nie czyść w PROD.
3. **DatabaseSG zależność** — zawsze retain DatabaseSG przy retain RDS.
4. **VPC retain** — jeśli RDS ma zostać, VPC musi zostać. Zaplanuj to od początku.
5. **Ręczne SG** — sprawdź czy nie ma manualnych SG w VPC przed delete (mogą blokować).
6. **bastionhost wzorzec** — w starych projektach Tribecloud może być SG bastionhost z dostępem do DB. Udokumentuj IPs przed delete.
7. **GlobalAccelerator** — sprawdź PRZED delete czy jest w projekcie. Managed ENI blokuje subnet; nie można usunąć bez disassociation. Komenda: `aws globalaccelerator list-accelerators --region us-east-1`
8. **NAT Gateway** — jeśli manualne (poza CFN), sprawdź przed delete. Blokuje subnet, ale można usunąć bezpiecznie jeśli środowisko offline. Komenda: `aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=<VPC_ID>"`
9. **VPC Endpoints (Interface)** — blokują prywatne subnety przez ENI. Sprawdź: `aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=<VPC_ID>"` — uwzględnij w retain-resources lub usuń przed delete.
10. **ServiceDiscoveryNamespace** — przy retain VPC zostanie usunięty przez CFN (nie można retain). Trzeba odtworzyć przy redeploy: `aws servicediscovery create-private-dns-namespace --name planodkupow.qa. --vpc <VPC_ID>`

### Kolejność retain-resources (bezpieczna sekwencja)

```
1. RDS DeletionProtection ON
2. RDS Snapshot
3. Audyt manualnych zasobów: SG, VPC Endpoints, NAT GW, GlobalAccelerator
4. delete root stack → fail na DBStack (DeletionProtection)
5. delete DBStack --retain-resources SQLDatabase SiecDB
6. delete S3Stack --retain-resources S3Bucket S3FileBucket
7. retry root → fail na SecGroupStack (DatabaseSG dep.)
8. delete SecGroupStack --retain-resources DatabaseSG TaskSG (TaskSG jeśli VPC Endpoints istnieją)
9. retry root → fail na VPCStack
10. delete VPCStack --retain-resources VPC Brama BramaToVPC PodsPrv1 PodsPrv2 PodsPub1 PodsPub2
    UWAGA: ServiceDiscoveryNamespace zostanie usunięty — odtwórz przy redeploy
11. retry root → DELETE_COMPLETE
```

### Parametry stacka (do redeploy)

Pełna lista parametrów zapisana w describe-stacks output (w tym DBMasterPass).  
Kluczowe:
```
DBMasterUser:  planodkupowadm
DBMasterPass:  nEObqF963WYdX1AtEvx0IY2ry3Y28Pxn3W|ayX5z
SecToken:      3E4yBmL1sERAvKwT
Srodowisko:    qa
Domena:        planodkupow-qa.makotest.pl
```

> ⚠️ Powyższe credentials są z aktywnego stacka QA — zmień przed użyciem w PROD.

---

## Status na moment zapisu

```
09:22  delete-stack planodkupow-qa — zainicjowany
09:36  DELETE_FAILED — DBStack, S3Stack
09:44  DBStack retain, S3Stack retain — DELETED
09:51  retry root stack
10:09  DELETE_FAILED — SecGroupStack (DatabaseSG dep.)
10:13  SecGroupStack retain DatabaseSG — DELETE_IN_PROGRESS
10:31  DELETE_FAILED — SecGroupStack (TaskSG dep., VPC Endpoints)
10:3x  SecGroupStack retain DatabaseSG TaskSG — DELETE_IN_PROGRESS
10:3x  SecGroupStack — DELETE_COMPLETE
10:3x  retry root stack
10:3x  VPCStack — DELETE_IN_PROGRESS
10:48  VPCStack — DELETE_FAILED (blokery: GlobalAccelerator ENI, NAT GW, VPC Endpoints, RDS ENI)
10:51  VPCStack retain VPC Brama BramaToVPC PodsPrv1 PodsPrv2 PodsPub1 PodsPub2 — DELETE_IN_PROGRESS
10:52  VPCStack — DELETE_COMPLETE ✓
10:52  retry root stack planodkupow-qa
10:52  planodkupow-qa — DELETE_COMPLETE ✓ (stack nie istnieje)
```

**FAZA 3 ZAKOŃCZONA — wszystkie stacks usunięte.**

---

## FAZA 4 — Redeploy (2026-04-19 ~11:25)

### Próba 1: create-stack (11:25)

```bash
aws cloudformation create-stack \
  --stack-name planodkupow-qa \
  --template-url https://planodkupow-cf.s3.eu-central-1.amazonaws.com/ROOT.yml \
  --parameters \
    ParameterKey=Srodowisko,ParameterValue=qa \
    ParameterKey=Domena,ParameterValue=planodkupow-qa.makotest.pl \
    ParameterKey=Certyfikat,ParameterValue=arn:aws:acm:us-east-1:333320664022:certificate/7cac4e30-0aa1-4a5e-92ac-eec445ee6601 \
    [obrazy .1244 + front.609] \
  --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
  --profile plan --region eu-central-1
```

**ROLLBACK_COMPLETE (11:25):**
```
S3Stack: S3Bucket (planodkupow-qa) i S3FileBucket (planodkupow-qa-pliki) już istnieją — retainowane
```

**Przyczyna:** S3.yml próbuje stworzyć buckety z hardcoded nazwami, ale te buckety już istnieją (retainowaliśmy je z danymi).

**Fix:** backup danych → usunięcie bucketów → create-stack → restore danych.
Decyzja: **backup + delete + restore** (dane zachowane, buckety odtworzone przez CFN).

### Następne kroki — ZAKTUALIZOWANE (~11:40)

**Dodatkowy problem:** RDS USUNIĘTY — pusty RDS niedopuszczalny. Fix: MSSQL.yml i ROOT.yml zmodyfikowane — dodano `DBSnapshotIdentifier` z warunkiem (`HasSnapshot`). Gdy parametr podany: `MasterUsername`/`MasterUserPassword` pomijane (wymóg AWS), instancja odtworzona ze snapshotu.

Zmodyfikowane pliki w repo: `infra-bbmt/cloudformation/MSSQL.yml` i `ROOT.yml` — wymagają wgrania na S3 przed create-stack.

1. Wgraj MSSQL.yml i ROOT.yml na S3 (`planodkupow-cf`)
2. Skopiuj dane S3 do temp bucketów backup
3. Opróżnij i usuń oryginalne buckety
4. Usuń ROLLBACK_COMPLETE stack
5. create-stack z `DBSnapshotIdentifier=planodkupow-qa-pre-rebuild-20260419-0849`
6. Po CREATE_COMPLETE: restore S3 + cleanup temp bucketów

Szczegółowy runbook: sekcja poniżej w execution logu lub [[planodkupow-qa-cfn-rebuild]] FAZA 4.

### Obrazy z ostatnich działających jobów (build .1244)

```
GatewayImg:      planodkupow-qa:gateway.1244
AuthImg:         planodkupow-qa:auth.1244
InteropImg:      planodkupow-qa:interop.1244
MessageImg:      planodkupow-qa:message.1244
VehicleImg:      planodkupow-qa:vehicle.1244
InspectionImg:   planodkupow-qa:inspection.1244
ExpertiseImg:    planodkupow-qa:expertise.1244
InsuranceImg:    planodkupow-qa:insurance.1244
StorageImg:      planodkupow-qa:storage.1244
RegistrationImg: planodkupow-qa:registration.1244
ReportImg:       planodkupow-qa:report.1244
OfferImg:        planodkupow-qa:offer.1244
FinanceImg:      planodkupow-qa:finance.1244
FrontImg:        planodkupow-qa:front.609
```

---

## FAZA 4 — Plan odtworzenia S3 i redeploy (DO WYKONANIA)

### Krok 1: Backup S3 do tymczasowych bucketów

```bash
aws s3api create-bucket \
  --bucket planodkupow-qa-backup-main \
  --create-bucket-configuration LocationConstraint=eu-central-1 \
  --profile plan --region eu-central-1

aws s3api create-bucket \
  --bucket planodkupow-qa-backup-pliki \
  --create-bucket-configuration LocationConstraint=eu-central-1 \
  --profile plan --region eu-central-1

aws s3 sync s3://planodkupow-qa s3://planodkupow-qa-backup-main \
  --profile plan --region eu-central-1

aws s3 sync s3://planodkupow-qa-pliki s3://planodkupow-qa-backup-pliki \
  --profile plan --region eu-central-1

# Weryfikacja — oczekiwane: 297 obj / 1302 obj
aws s3 ls s3://planodkupow-qa --recursive --summarize --profile plan --region eu-central-1 | tail -2
aws s3 ls s3://planodkupow-qa-backup-main --recursive --summarize --profile plan --region eu-central-1 | tail -2
```

### Krok 2: Opróżnij i usuń oryginalne buckety

```bash
aws s3 rm s3://planodkupow-qa --recursive --profile plan --region eu-central-1
aws s3 rm s3://planodkupow-qa-pliki --recursive --profile plan --region eu-central-1
aws s3api delete-bucket --bucket planodkupow-qa --profile plan --region eu-central-1
aws s3api delete-bucket --bucket planodkupow-qa-pliki --profile plan --region eu-central-1
```

### Krok 3: Usuń ROLLBACK_COMPLETE stack

```bash
aws cloudformation delete-stack --stack-name planodkupow-qa \
  --profile plan --region eu-central-1
# Poczekaj na DELETE_COMPLETE (szybkie)
```

### Krok 4: create-stack

```bash
aws cloudformation create-stack \
  --stack-name planodkupow-qa \
  --template-url https://planodkupow-cf.s3.eu-central-1.amazonaws.com/ROOT.yml \
  --parameters \
    ParameterKey=Srodowisko,ParameterValue=qa \
    ParameterKey=Domena,ParameterValue=planodkupow-qa.makotest.pl \
    ParameterKey=Certyfikat,ParameterValue=arn:aws:acm:us-east-1:333320664022:certificate/7cac4e30-0aa1-4a5e-92ac-eec445ee6601 \
    ParameterKey=GatewayImg,ParameterValue=333320664022.dkr.ecr.eu-central-1.amazonaws.com/planodkupow-qa:gateway.1244 \
    ParameterKey=AuthImg,ParameterValue=333320664022.dkr.ecr.eu-central-1.amazonaws.com/planodkupow-qa:auth.1244 \
    ParameterKey=InteropImg,ParameterValue=333320664022.dkr.ecr.eu-central-1.amazonaws.com/planodkupow-qa:interop.1244 \
    ParameterKey=MessageImg,ParameterValue=333320664022.dkr.ecr.eu-central-1.amazonaws.com/planodkupow-qa:message.1244 \
    ParameterKey=VehicleImg,ParameterValue=333320664022.dkr.ecr.eu-central-1.amazonaws.com/planodkupow-qa:vehicle.1244 \
    ParameterKey=InspectionImg,ParameterValue=333320664022.dkr.ecr.eu-central-1.amazonaws.com/planodkupow-qa:inspection.1244 \
    ParameterKey=ExpertiseImg,ParameterValue=333320664022.dkr.ecr.eu-central-1.amazonaws.com/planodkupow-qa:expertise.1244 \
    ParameterKey=InsuranceImg,ParameterValue=333320664022.dkr.ecr.eu-central-1.amazonaws.com/planodkupow-qa:insurance.1244 \
    ParameterKey=StorageImg,ParameterValue=333320664022.dkr.ecr.eu-central-1.amazonaws.com/planodkupow-qa:storage.1244 \
    ParameterKey=RegistrationImg,ParameterValue=333320664022.dkr.ecr.eu-central-1.amazonaws.com/planodkupow-qa:registration.1244 \
    ParameterKey=ReportImg,ParameterValue=333320664022.dkr.ecr.eu-central-1.amazonaws.com/planodkupow-qa:report.1244 \
    ParameterKey=OfferImg,ParameterValue=333320664022.dkr.ecr.eu-central-1.amazonaws.com/planodkupow-qa:offer.1244 \
    ParameterKey=FinanceImg,ParameterValue=333320664022.dkr.ecr.eu-central-1.amazonaws.com/planodkupow-qa:finance.1244 \
    ParameterKey=FrontImg,ParameterValue=333320664022.dkr.ecr.eu-central-1.amazonaws.com/planodkupow-qa:front.609 \
  --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
  --profile plan --region eu-central-1
```

### Krok 5: Restore S3 po CREATE_COMPLETE

```bash
aws s3 sync s3://planodkupow-qa-backup-main s3://planodkupow-qa \
  --profile plan --region eu-central-1

aws s3 sync s3://planodkupow-qa-backup-pliki s3://planodkupow-qa-pliki \
  --profile plan --region eu-central-1

# Weryfikacja
aws s3 ls s3://planodkupow-qa --recursive --summarize --profile plan --region eu-central-1 | tail -2
aws s3 ls s3://planodkupow-qa-pliki --recursive --summarize --profile plan --region eu-central-1 | tail -2

# Cleanup backup
aws s3 rm s3://planodkupow-qa-backup-main --recursive --profile plan --region eu-central-1
aws s3 rm s3://planodkupow-qa-backup-pliki --recursive --profile plan --region eu-central-1
aws s3api delete-bucket --bucket planodkupow-qa-backup-main --profile plan --region eu-central-1
aws s3api delete-bucket --bucket planodkupow-qa-backup-pliki --profile plan --region eu-central-1
```

### Stan na moment zapisu (11:30)

```
planodkupow-qa stack: ROLLBACK_COMPLETE (do usunięcia przed kolejnym create)
S3 planodkupow-qa: 297 obj, 33MB — dane zachowane, bucket istnieje
S3 planodkupow-qa-pliki: 1302 obj, 162MB — dane zachowane, bucket istnieje
RDS planodkupowqadb: USUNIĘTY (snapshot: planodkupow-qa-pre-rebuild-20260419-0849)
VPC vpc-02f804baee8a3f048: istnieje (orphan — nowy stack stworzy nową VPC)
```

*Log aktualizowany na bieżąco podczas sesji 2026-04-19*
