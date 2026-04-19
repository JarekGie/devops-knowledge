# Execution Log: planodkupow-qa CFN Rebuild

#incident #aws #cloudformation #planodkupow

**Data:** 2026-04-19  
**Operator:** Jarosław Gołąb + Claude  
**Cel:** Delete + redeploy planodkupow-qa po UPDATE_ROLLBACK_FAILED  
**Runbook:** [[planodkupow-qa-cfn-rebuild]]  
**Status:** W TOKU

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

### Oczekiwany Fail 3: VPCStack

Po usunięciu SecGroupStack → retry root stacka → **VPCStack się wysypie** bo:
- RDS `planodkupowqadb` nadal w VPC (subnet group `SiecDB` retainowany)
- `bastionhost` SG (manualna) w VPC
- `DatabaseSG` (retainowana) w VPC

**Plan:** delete VPCStack z retain-resources WSZYSTKICH zasobów:

```bash
aws cloudformation delete-stack \
  --stack-name planodkupow-qa-VPCStack-1OHNJ84RQI8K2 \
  --retain-resources \
    VPC PodsPrv1 PodsPrv2 PodsPub1 PodsPub2 \
    LocalRoutTable PubTabRout \
    Brama BramaToVPC \
    LocRoutTabAss1 LocRoutTabAss2 \
    PubRoutTabAss1 PubRoutTabAss2 \
    PubRouteToInternet \
    ServiceDiscoveryNamespace \
  --profile plan --region eu-central-1
```

**Decyzja:** Opcja A — retain VPC (cała sieć zostaje). Redeploy zaimportuje istniejącą VPC/subnety. RDS zostaje w tych samych podsieciach bez zmian sieciowych.

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
| IGW, route tables | igw-0862c2814f8c0265b + rtb-* | Infrastruktura VPC |
| Service Discovery NS | ns-xiknwgpztou4hjcj | Namespace planodkupow.qa. |

---

## Wnioski dla wyższych środowisk (UAT/PROD)

### Co pójdzie inaczej

1. **DeletionProtection** — sprawdź PRZED delete czy jest włączone. Jeśli nie — włącz ręcznie.
2. **S3 buckety z danymi** — zawsze `--retain-resources`, nigdy nie czyść w PROD.
3. **DatabaseSG zależność** — zawsze retain DatabaseSG przy retain RDS.
4. **VPC retain** — jeśli RDS ma zostać, VPC musi zostać. Zaplanuj to od początku.
5. **Ręczne SG** — sprawdź czy nie ma manualnych SG w VPC przed delete (mogą blokować).
6. **bastionhost wzorzec** — w starych projektach Tribecloud może być SG bastionhost z dostępem do DB. Udokumentuj IPs przed delete.

### Kolejność retain-resources (bezpieczna sekwencja)

```
1. RDS DeletionProtection ON
2. RDS Snapshot
3. delete root stack → fail na DBStack (DeletionProtection)
4. delete DBStack --retain-resources SQLDatabase SiecDB
5. delete S3Stack --retain-resources S3Bucket S3FileBucket
6. retry root → fail na SecGroupStack (DatabaseSG dep.)
7. delete SecGroupStack --retain-resources DatabaseSG
8. retry root → fail na VPCStack (RDS w VPC)
9. delete VPCStack --retain-resources <wszystkie>
10. retry root → DELETE_COMPLETE
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
10:26  [W TOKU — czekamy na SecGroupStack]
```

---

*Log aktualizowany na bieżąco podczas sesji 2026-04-19*
