# Post-mortem: planodkupow-qa CFN UPDATE_ROLLBACK_FAILED → pełny rebuild

#incident #aws #cloudformation #planodkupow #postmortem

**Data incydentu:** 2026-04-18 (wieczór) — 2026-04-19 (cały dzień)  
**Środowisko:** QA (`planodkupow-qa`, konto `333320664022`, `eu-central-1`)  
**Czas odzyskania:** ~6 godzin aktywnej pracy (z przerwami)  
**Autorzy:** Jarosław Gołąb + Claude  
**Log operacyjny:** [[planodkupow-qa-execution-log]]

---

## 1. Streszczenie

Deploy aktualizacji tagów LLZ na środowisku QA wywołał kaskadowy `UPDATE_ROLLBACK_FAILED` na całym nested stack. Przyczyną była wersja Redis 5.0.0 (EOL — AWS usunął wersję), która spowodowała Replace podczas deployu. Rollback nie mógł się odwrócić (RedisStack skończył rollback, ale root stack tego nie przetworzył), a wcześniejsze ręczne próby `continue-update-rollback` (8 prób od ~05:45 do 06:34) pogorszyły stan. Środowisko wymagało pełnego delete + redeploy.

Podczas odtwarzania odkryto kaskadę dodatkowych problemów EOL: RabbitMQ wersja `3.8.6` (EOL), instancja `mq.t3.micro` (nie wspierana dla RabbitMQ), oraz zewnętrzny rekord DNS blokujący CloudFront. Środowisko odzyskano po 4 nieudanych próbach create-stack i naprawieniu łącznie 5 niezależnych problemów.

---

## 2. Oś czasu

### 2026-04-18 wieczór
- Deploy LLZ tags (aktualizacja tagów na nested stackach) → `UPDATE_ROLLBACK_FAILED`
- Root cause: Redis `5.0.0` EOL → AWS odmówił wersji → Replace na RedisStack → rollback skończył się na RedisStack, ale root stack nie mógł tego przetworzyć

### 2026-04-19 rano (~05:45–06:34)
- Ktoś inny próbował `continue-update-rollback` 8 razy — wszystkie nieudane
- Błędy: "Stack [RabbitMQStack] does not exist", "Only resources failed during UpdateRollback allowed to be skipped", "Nested stacks could not be skipped"
- Stan po próbach: `UPDATE_ROLLBACK_FAILED` z trzema nested stackami w `UPDATE_ROLLBACK_FAILED` (DBStack, RabbitMQStack) i jednym w `UPDATE_ROLLBACK_COMPLETE` (RedisStack)

### 2026-04-19 ~09:00 — start odtwarzania
- Decyzja: **delete + redeploy** (continue-update-rollback niewykonalny)
- Backup RDS snapshot `planodkupow-qa-pre-rebuild-20260419-0849` (status: available)
- Backup pełnej konfiguracji: ALB, CloudFront, Route53, VPC, ECS, RabbitMQ, Redis, SGs
- Uruchomienie delete root stacka

### 2026-04-19 ~09:22–10:52 — Faza DELETE (5 iteracji)
- 6 oddzielnych `delete-stack` z `--retain-resources` zanim root stack dał `DELETE_COMPLETE`
- Kolejne blokery odkrywane jeden po drugim (patrz sekcja 3)

### 2026-04-19 ~11:25–13:30 — Faza CREATE (4 nieudane + 1 udana próba)

| Próba | Czas | Bloker |
|---|---|---|
| 1 | 11:25 | S3 buckety `planodkupow-qa` i `planodkupow-qa-pliki` już istniały (retainowane z danymi) |
| 2 | ~12:00 | RabbitMQ `EngineVersion 3.8.6` EOL (valid: `4.2`, `3.13`) |
| 3 | ~12:30 | RabbitMQ `mq.t3.micro` not supported for RabbitMQ (valid: `mq.m5.large`+) |
| 4 | ~12:45 | CloudFront alias conflict: zewnętrzny DNS `planodkupow-qa.makotest.pl → de42p9qai5kj4.cloudfront.net` (stara usunięta dystrybucja) |
| 5 | ~13:30 | **CREATE_COMPLETE** ✓ |

### 2026-04-19 ~13:30+
- Stack `CREATE_COMPLETE`
- Restore S3 z backup bucketów
- DNS zaktualizowany: `planodkupow-qa.makotest.pl → d1a1zpep5vqor0.cloudfront.net`

---

## 3. Root cause analysis

### Przyczyna pierwotna

**Redis EOL w szablonie:** `REDIS.yml` miał `EngineVersion: 5.0.0`. AWS wycofał tę wersję. Deploy LLZ tags wymusił `Replace` na RedisStack (zmiana tagów na ElastiCache wymaga Replace). Replace nieudany bo AWS odmówił stworzenia nowego klastra na wersji 5.0.0.

### Przyczyny wtórne (kaskada)

1. **RabbitMQ EngineVersion 3.8.6 EOL** — `RMQ.yml` miał `EngineVersion: "3.8.6"`. AWS AmazonMQ usunął tę wersję. Blokował każdą próbę create-stack do momentu naprawy.

2. **RabbitMQ HostInstanceType mq.t3.micro** — `RMQ.yml` miał `HostInstanceType: mq.t3.micro`. Ten typ instancji nie jest wspierany dla RabbitMQ (tylko dla ActiveMQ). Wymaga minimum `mq.m5.large`.

3. **Brak DeletionPolicy: Retain na SQLDatabase i SiecDB** — podczas rollbacku (CREATE_FAILED → rollback) CFN próbował usunąć RDS będący w stanie `restoring` (restore ze snapshotu w toku). Nie mógł stworzyć final snapshot → `DELETE_FAILED` → root stack w `ROLLBACK_FAILED`. Wymagało to ręcznych delete nested stacków z `--retain-resources` przy każdej próbie.

4. **Zewnętrzny rekord DNS dla CloudFront** — po usunięciu oryginalnej dystrybucji CloudFront `E30ZEJ5EBK0T8D` (podczas delete root stacka), zewnętrzny DNS (nie Route53) nadal miał CNAME `planodkupow-qa.makotest.pl → de42p9qai5kj4.cloudfront.net`. CloudFront odmawia stworzenia nowej dystrybucji z aliasem wskazującym na usuniętą/inną dystrybucję. Rekord DNS był w zewnętrznym systemie poza kontrolą Route53 — wymagał ręcznego usunięcia przez właściciela domeny.

### Dlaczego te problemy nie były wykryte wcześniej

- Wersje EOL nie mają deprecation warning w CFN — po prostu fail przy próbie stworzenia
- `mq.t3.micro` działał dla ActiveMQ, nie dla RabbitMQ — różnica niewidoczna w szablonie
- Brak testów pre-deploy (`aws cloudformation validate-template` sprawdza składnię, nie dostępność wersji)
- Zewnętrzny DNS nie był udokumentowany jako zależność deploy procesu

---

## 4. Kompletna lista naprawek w szablonach

| Plik | Co zmieniono | Powód |
|---|---|---|
| `REDIS.yml` | `EngineVersion: '5.0.0'` → `'5.0.6'` | Redis 5.0.0 EOL |
| `RMQ.yml` | `EngineVersion: "3.8.6"` → `"3.13"` | RabbitMQ 3.8.6 EOL |
| `RMQ.yml` | `HostInstanceType: mq.t3.micro` → `mq.m5.large` | t3.micro nie wspierany dla RabbitMQ |
| `MSSQL.yml` | Dodano `DeletionPolicy: Retain` na `SQLDatabase` | Rollback podczas restore nie może usunąć RDS |
| `MSSQL.yml` | Dodano `DeletionPolicy: Retain` na `SiecDB` | SiecDB nie może być usunięty gdy SQLDatabase istnieje |
| `MSSQL.yml` | Dodano parametr `DBSnapshotIdentifier` z condition `HasSnapshot` | Restore ze snapshotu zamiast pustej bazy |
| `ROOT.yml` | Dodano parametr `DBSnapshotIdentifier`, przekazywany do DBStack | Jw. |

---

## 5. Szczegółowy przebieg DELETE fazy — pułapki

Delete root stacka wymagał 6 oddzielnych operacji z powodu zależności między zasobami. Kolejność dla przyszłych rebuild:

```
1. RDS DeletionProtection ON (ręcznie, PRZED delete)
2. RDS manual snapshot
3. Audyt manualnych zasobów: SG, VPC Endpoints, NAT GW, GlobalAccelerator
4. delete root stack → fail na DBStack (DeletionProtection)
5. delete DBStack --retain-resources SQLDatabase SiecDB
6. delete S3Stack --retain-resources S3Bucket S3FileBucket  (jeśli buckety nie puste)
7. retry root → fail na SecGroupStack (DatabaseSG dep.)
8. delete SecGroupStack --retain-resources DatabaseSG TaskSG
   (TaskSG jeśli istnieją manualne VPC Endpoints używające TaskSG)
9. retry root → fail na VPCStack (GlobalAccelerator ENI, NAT GW, VPC Endpoints, RDS ENI)
10. delete VPCStack --retain-resources VPC Brama BramaToVPC PodsPrv1 PodsPrv2 PodsPub1 PodsPub2
    UWAGA: ServiceDiscoveryNamespace ZOSTANIE usunięty (nie można retain) — odtworzone przy redeploy
11. retry root → DELETE_COMPLETE
```

**Zasoby manualne, które blokują delete (niewidoczne w CFN):**

| Zasób | Typ | Blokuje |
|---|---|---|
| GlobalAccelerator ENI | Managed ENI | Subnet delete |
| NAT Gateway (jeśli manualny) | NAT GW | Subnet delete |
| VPC Endpoints Interface | ENI | Prywatne subnety |
| bastionhost SG | Security Group (manual) | Nie blokuje, ale istnieje |
| planodkupow-cf | S3 bucket (Provisioner: manual) | Nie blokuje, ale istnieje |
| planodkupow-s3-logi | S3 bucket (Provisioner: manual) | Nie blokuje, ale istnieje |

**Komendy audytu przed delete:**
```bash
# Manualne VPC Endpoints
aws ec2 describe-vpc-endpoints \
  --filters "Name=vpc-id,Values=<VPC_ID>" \
  --profile plan --region eu-central-1 \
  --query 'VpcEndpoints[].{ID:VpcEndpointId,Service:ServiceName}'

# GlobalAccelerator (region us-east-1!)
aws globalaccelerator list-accelerators --region us-east-1 --profile plan

# NAT Gateways
aws ec2 describe-nat-gateways \
  --filter "Name=vpc-id,Values=<VPC_ID>" \
  --profile plan --region eu-central-1
```

---

## 6. Plan dla PROD — jak uniknąć katastrofy

### 6.1 Problemy, które NA PEWNO wystąpią na PROD

**A. Domeną zarządza ktoś inny — KRYTYCZNE**

Na QA mogłeś sam usunąć CNAME. Na PROD nie masz dostępu do DNS. Jeśli CNAME dla domeny PROD wskazuje na stary CloudFront, deploy się zablokuje i będziesz potrzebował interwencji zewnętrznej (rejestrator/właściciel domeny) w trakcie okna maintenance.

**Wymagane działania PRZED deployem na PROD:**
1. Ustal kto zarządza DNS dla domeny PROD
2. Uzgodnij dostęp lub procedurę — musisz być w stanie zaktualizować CNAME w ciągu 5 minut
3. Opcja: podczas deploy usuń alias z CF dystrybucji PROD, zaktualizuj DNS, potem dodaj z powrotem przez update-stack

**B. DeletionProtection na RDS PROD**

RDS PROD prawdopodobnie ma DeletionProtection. To dobrze — ale przy delete stacka musisz go wyłączyć RęCZNIE lub użyć `--retain-resources`.

Nigdy nie wyłączaj DeletionProtection na PROD bez robienia snapshotu.

**C. Dane w S3 PROD**

S3 buckety PROD będą niepuste. Zawsze `--retain-resources` dla S3 bucketów na PROD. Po redeploy — restore ręczny z backup/crossover.

**D. GlobalAccelerator na PROD**

Jeśli PROD ma GlobalAccelerator — ENI zablokuje delete subnetów. Sprawdź PRZED delete i albo disassociate accelerator albo retain VPC.

### 6.2 Pre-deploy checklist dla PROD rebuild

```
[ ] 1. Ustalono kto zarządza DNS PROD i jest dostępny w oknie maintenance
[ ] 2. Snapshot RDS PROD — status: available
[ ] 3. RDS DeletionProtection ON (weryfikacja)
[ ] 4. S3 backup (sync do temp bucketów)
[ ] 5. CloudFront ID i ETag zapisane (do ewentualnego rollbacku)
[ ] 6. ALB konfiguracja zapisana (SecToken, listenery, reguły)
[ ] 7. VPC ID i subnety zapisane
[ ] 8. ECS task definitions i serwisy zapisane
[ ] 9. Audyt manualnych zasobów: GlobalAccelerator, NAT GW, VPC Endpoints, bastionhost SG
[ ] 10. dig <domena-prod> +short — zapisz aktualny CloudFront domain
[ ] 11. Freeze Jenkins/CI na PROD
[ ] 12. Szablony CFN zwalidowane (wersje Redis, RabbitMQ, typy instancji)
```

### 6.3 Walidacja szablonów przed deployem

Sprawdź zawsze przed deploy na wyższe środowiska:

```bash
# Aktualnie wspierane wersje (2026-04-19):
# Redis: 5.0.6, 6.2, 7.0, 7.1
# RabbitMQ: 3.13, 4.2
# RabbitMQ instance types: mq.m5.large i wyżej
# SQL Server: 15.00.4073.23.v1 (Express), wyższe

# Weryfikacja Redis
aws elasticache describe-cache-engine-versions \
  --engine redis --region eu-central-1 \
  --query 'CacheEngineVersions[].EngineVersion' --output table

# Weryfikacja RabbitMQ
aws mq describe-broker-engine-types \
  --engine-type RABBITMQ --region eu-central-1 \
  --query 'BrokerEngineTypes[0].EngineVersions[].Name' --output table
```

### 6.4 Strategia deploy na PROD (rekomendowana)

Zamiast delete + redeploy na PROD, rozważ:

**Opcja A: Blue-Green (preferowana)**
1. Stwórz nowy stack `planodkupow-prod-new` obok istniejącego
2. Po weryfikacji — przenieś DNS na nowy stack
3. Usuń stary stack

Wymaga: duplicate kosztów przez ~2h, ale ZERO downtime i możliwość szybkiego rollbacku.

**Opcja B: continue-update-rollback z pominięciem**
Tylko jeśli failed resources są STATELESS (nie RDS, nie MQ):
```bash
aws cloudformation continue-update-rollback \
  --stack-name <stack> \
  --resources-to-skip <LogicalId1> <LogicalId2>
```

**Opcja C: delete + redeploy (jak QA)**
Akceptowalny jeśli:
- Masz snapshot RDS i pewność restore
- Masz dostęp do DNS
- Masz backup wszystkich manualnych zasobów
- Masz freeze CI/CD
- Masz okno maintenance

### 6.5 Obsługa DNS przy CloudFront na PROD

Jeśli nie masz dostępu do DNS PROD:

**Plan A:** Ustal z właścicielem domeny że:
1. Przed deploy: usuwa CNAME starego CloudFront
2. Po deploy: dodaje CNAME nowego CloudFront
3. Musi być dostępny telefonicznie w oknie maintenance

**Plan B (niezależny od właściciela DNS):**
Modyfikuj CF.yml żeby deploy bez aliasu był możliwy:
```yaml
# CF.yml — dodaj condition
Conditions:
  HasAlias: !Not [!Equals [!Ref Domena, '']]

# W CloudFrontDistribution:
Aliases: !If [HasAlias, [!Ref Domena], !Ref AWS::NoValue]
ViewerCertificate:
  !If
    - HasAlias
    - AcmCertificateArn: !Ref Certyfikat
      SslSupportMethod: sni-only
    - CloudFrontDefaultCertificate: true
```

Wtedy: deploy bez aliasu → środowisko działa pod domeną `*.cloudfront.net` → DNS update → `update-stack` z aliasem.

---

## 7. Lessons learned

1. **Sprawdzaj wersje EOL przed każdym deployem.** AWS cicho usuwa stare wersje (Redis, RabbitMQ, instancje). Brak deprecation warning w CFN.

2. **DeletionPolicy: Retain na WSZYSTKICH stanowych zasobach** (RDS, MQ, S3). Nigdy nie pozwól CFN automatycznie usunąć bazy danych przy rollbacku.

3. **Zewnętrzny DNS to zależność deploy procesu.** Udokumentuj kto zarządza DNS i jak szybko możesz zmienić rekord. Bez tego każdy CF rebuild jest blokowany.

4. **Nie rób continue-update-rollback na nested stackach bez dobrego powodu.** Szczególnie nie "na ślepo" 8 razy z rzędu. Jeśli pierwsze 2 próby failują z tym samym błędem — stop, diagnozuj root cause.

5. **Rób audyt manualnych zasobów przed delete.** VPC Endpoints, GlobalAccelerator, NAT GW — wszystkie blokują subnet delete i nie są widoczne w CFN.

6. **Backup S3 do tymczasowych bucketów przed delete stacka.** S3 buckety z hardcoded nazwami zawsze zablokują nowy create (bucket already exists).

7. **Snapshot RDS PRZED delete, nie podczas.** Snapshot `available` = gwarancja danych.

8. **mq.t3.micro = tylko ActiveMQ, nie RabbitMQ.** Minimalna instancja dla RabbitMQ: `mq.m5.large`.

---

## 8. Szybkie komendy na przyszłość

```bash
# Sprawdź status nested stacków
aws cloudformation list-stack-resources \
  --stack-name planodkupow-<env> \
  --profile plan --region eu-central-1 \
  --query 'StackResourceSummaries[].{ID:LogicalResourceId,S:ResourceStatus}' --output table

# Sprawdź eventy nested stacka po ARN
aws cloudformation describe-stack-events \
  --stack-name <full-arn-or-name> \
  --profile plan --region eu-central-1 \
  --query 'StackEvents[:10].{Resource:LogicalResourceId,Status:ResourceStatus,Reason:ResourceStatusReason}' \
  --output table

# Delete nested stacka z retain
aws cloudformation delete-stack \
  --stack-name <physical-stack-name> \
  --retain-resources <LogicalId1> <LogicalId2> \
  --profile plan --region eu-central-1

# Weryfikacja DNS CloudFront przed deployem
dig <domena> +short  # powinno: NXDOMAIN lub stary CF domain do usunięcia

# Aktualne wersje RabbitMQ
aws mq describe-broker-engine-types \
  --engine-type RABBITMQ --region eu-central-1 \
  --query 'BrokerEngineTypes[0].EngineVersions[].Name' --output table
```

---

*Post-mortem napisany: 2026-04-19 | Incydent: planodkupow-qa CFN UPDATE_ROLLBACK_FAILED*
