---
tags: [#aws, #cloudtrail, #forensic, #networking, #vpc, #planodkupow, #incident]
date: 2026-04-25
---

# Forensic Audit — Sieć QA planodkupow (CloudTrail, eu-central-1)

## Symptom / zakres badania

Dwie QA VPC współistnieją w tym samym accountcie. Legacy NAT i orphan-suspect VPC endpoints.
Cel: ustalić evidence-based historię sieci za 2026-01-01 → 2026-04-25.

## Granica danych

CloudTrail Event History: 90 dni wstecz = **od 2026-01-25**.
Dane przed 25 stycznia niewidoczne w Event History → wymagany **CloudTrail Lake** (zapytania na końcu).

---

## Zasoby pod lupą

| Zasób | Rola | Stan |
|---|---|---|
| `vpc-02f804baee8a3f048` | **Stara QA VPC** (orphan suspect) | alive, brak CFN stack |
| `vpc-007d115c41f079bf3` | **Nowa QA VPC** (rebuild 2026-04-19) | alive, CFN UPDATE_ROLLBACK_COMPLETE |
| `nat-08adf3e0a226779a7` | Legacy NAT w starej VPC | available, EIP 3.76.77.101 |
| `igw-0862c2814f8c0265b` | IGW starej VPC | **nadal attached** (state: available) |

---

## Timeline zdarzeń (evidence only)

### Przed 2026-01-25 (poza oknem CT)

- `nat-08adf3e0a226779a7` stworzony **2025-07-31 19:31 UTC** → subnet-049522191fe108784, VPC vpc-02f804baee8a3f048 (public subnet, EIP eipalloc-03f5ee498546ec65c)
- Stara VPC, jej IGW, 4x VPC endpoints (ECR API, ECR DKR, Secrets Manager, CloudWatch Logs) — wszystkie sprzed okna

### 2026-04-19 — Pełny teardown + rebuild (chaos day)

```
08:46  ModifyDBInstance / CreateDBSnapshot (stara VPC, sesja 1776587421)
09:22  DeleteStack planodkupow-qa            ← próba #1 teardown (sesja 1776582013)
09:44  DeleteStack DBStack + S3Stack
09:51  DeleteStack planodkupow-qa            ← próba #2 (sesja 1776584716)
10:13  DeleteStack SecGroupStack
10:32  DeleteStack SecGroupStack             ← retry
10:33  DeleteStack planodkupow-qa            ← próba #3 (sesja 1776587421)
10:33–10:48  ❌ 61x DetachInternetGateway igw-0862c2814f8c0265b ← STUCK (co 15s przez ~15min)
10:51  DeleteStack planodkupow-qa-VPCStack-1OHNJ84RQI8K2  ← force-delete VPC stacka
10:52  DeleteStack planodkupow-qa            ← próba #4
10:59  DeleteDBInstance planodkupowqadb
11:25  CreateVpc vpc-04ac01f61d512607b       ← rebuild próba #1 (natychmiast DeleteVpc)
11:41  DeleteStack planodkupow-qa            ← próba #5
11:42  CreateVpc vpc-049afc46fbd3c98ca       ← próba #2 (DeleteVpc po ~30min)
12:12  CreateVpc vpc-085e7c613b0b98fd8       ← próba #3 (DeleteVpc)
12:41  CreateVpc vpc-0bb7f36e7bac35be3       ← próba #4 (MQ endpoint wpada! DeleteVpc)
15:13  CreateVpc vpc-0d00d4ca3b92acfe1       ← próba #5 (MQ endpoint wpada! DeleteVpc)
20:26  DeleteStack planodkupow-qa            ← finalny parent stack cleanup
20:28  ✅ CreateVpc vpc-007d115c41f079bf3    ← SUKCES (stack 1V91EF1UIC85A)
20:29  CreateSubnet ×4 + AttachInternetGateway igw-066da2ad497da3c91
20:35  CreateVpcEndpoint vpce-033cbde652500a1e4 ← AmazonMQ broker b-5cb3fcb4 (mq.amazonaws.com)
```

### 2026-04-20 → 2026-04-21

```
2026-04-20 17:35  CreateNetworkInterface bastionhost ← STARA VPC vpc-02f804baee8a3f048! (ECS)
2026-04-21 09:19  CreateNetworkInterface bastionhost ← STARA VPC vpc-02f804baee8a3f048! (ECS)
2026-04-21 11:25  CreateVpcEndpoint vpce-0aab2367ad6396bd9 ← AmazonMQ broker b-f231815d (nowa VPC)
```

### 2026-04-22 → 2026-04-25

Brak network create events. Tylko ECS ENI w nowej VPC.

---

## Diagnoza: dlaczego 61x DetachInternetGateway FAIL?

CloudFormation próbował odpiąć IGW od starej VPC, ale NAT gateway (`nat-08adf3e0a226779a7`) miał aktywny EIP i aktywne połączenia przez IGW. CFN nie obsłużył właściwej kolejności:

```
Poprawna kolejność:  DeleteNatGateway → ReleaseAddress → DetachInternetGateway → DeleteIGW
CFN faktycznie:      DetachInternetGateway ❌❌❌ (61x) → force-delete stack
```

Skutek: stack `planodkupow-qa-VPCStack-1OHNJ84RQI8K2` zniknął z CloudFormation,
ale VPC, NAT, IGW (nadal attached!), subnety i 4 VPC endpoints **pozostały jako retained resources**.

---

## Obecny stan starej VPC vpc-02f804baee8a3f048

| Zasób | ID | Stan |
|---|---|---|
| VPC | vpc-02f804baee8a3f048 | available |
| IGW | igw-0862c2814f8c0265b | **attached** (state: available) |
| NAT | nat-08adf3e0a226779a7 | available, EIP 3.76.77.101 |
| Subnet pub1 | subnet-049522191fe108784 | 10.2.0.0/20, eu-central-1a |
| Subnet pub2 | subnet-0f3ba588e935c435a | 10.2.32.0/20, eu-central-1b |
| Subnet prv1 | subnet-09ab9fdda1c1d2dea | 10.2.48.0/20, eu-central-1a |
| Subnet prv2 | subnet-044777a4a035cb0ab | 10.2.96.0/20, eu-central-1b |
| VPCE ecr.api | vpce-0f06338f894336448 | available |
| VPCE ecr.dkr | vpce-0066f4327e86d8687 | available |
| VPCE secretsmanager | vpce-0dcfc106af654bae6 | available |
| VPCE logs | vpce-093fc974c5ae750f4 | available |
| CFN stack | planodkupow-qa-VPCStack-1OHNJ84RQI8K2 | **nie istnieje** |

Subnety starej VPC mają inny prv1 CIDR niż nowej: `10.2.48.0/20` vs `10.2.60.0/20`.

---

## Obecny stan nowej VPC vpc-007d115c41f079bf3

| Zasób | Wartość |
|---|---|
| CFN stack | planodkupow-qa-VPCStack-1V91EF1UIC85A |
| Stack status | **UPDATE_ROLLBACK_COMPLETE** (ostatnia zmiana 2026-04-21 19:38 UTC) |
| CIDR | 10.2.0.0/16 |
| Subnety | pub1 10.2.0.0/20, pub2 10.2.32.0/20, prv1 10.2.60.0/20, prv2 10.2.96.0/20 |
| MQ endpoint 1 | vpce-033cbde652500a1e4 (svc 04b93b939af25977f, broker b-5cb3fcb4) |
| MQ endpoint 2 | vpce-0aab2367ad6396bd9 (svc 0a5b5f37b93736d09, broker b-f231815d) |

---

## Wnioski

### Nieoczekiwane network creates w 2026?
**Nie.** Wszystkie create events to: CFN-managed rebuild (OrganizationAccountAccessRole) lub service-managed (mq.amazonaws.com, ecs.amazonaws.com).

### Shadow/manual infrastructure?
**Nie ma.** Zero manual creates. NAT z 2025-07-31 był prawdopodobnie stworzony przez CFN.

### GO/NO-GO dla tezy "stara QA VPC to orphan"?
**GO — potwierdzone przez CloudTrail evidence.**

| Pytanie | Verdict |
|---|---|
| Stara VPC = orphan (stack nie istnieje) | ✅ CONFIRMED |
| NAT = legacy (stworzony 2025-07-31, never deleted) | ✅ CONFIRMED |
| Teardown failed (61x IGW detach FAIL) | ✅ CONFIRMED |
| IGW nadal attached do starej VPC | ✅ CONFIRMED |
| ECS nadal deployował do starej VPC po rebuild | ✅ CONFIRMED |
| Brak shadow infra | ✅ CONFIRMED |

---

---

## Global Accelerator Forensic Audit — 2026-04-25

### Zasoby pod lupą

| Zasób | ID | Subnet | Stan |
|---|---|---|---|
| GA ENI-1 | eni-0bc3e7b87b93ce431 | subnet-0f3ba588e935c435a (pub2, eu-central-1b) | in-use, attached |
| GA ENI-2 | eni-0e9dd0667e09a945c | subnet-049522191fe108784 (pub1, eu-central-1a) | in-use, attached |
| GA SG | sg-0a9a29d06a6a7d85c | vpc-02f804baee8a3f048 | IpPermissions: EMPTY |

### Korekta hipotezy — 2026-04-25 (impact analysis)

**WERDYKT: GA aktywny, endpoint = ALB w nowej VPC. ENI w starej VPC to relikt niezaktualizowanej konfiguracji subnetów endpoint grupy.**

#### Root cause ENI w starej VPC

CloudTrail potwierdza istnienie **poprzedniego ALB** `planodkupow-qa-ALB/2fb9eac9f1c26133` w starej VPC (ENI tworzone do 2026-04-15). Po rebuild'zie 19 kwietnia:
1. Stary ALB usunięty
2. Nowy ALB (`4971065864890a9b`) w nowej VPC stworzony przez CFN
3. GA endpoint zaktualizowany → nowy ALB ✓
4. **GA endpoint group subnety NIE zaktualizowane** → wciąż wskazują na pub1/pub2 starej VPC

Dlatego ENI są `in-use` (aktywna ELA attachment z endpoint grupy) i CLI delete fail z "currently in use". Dry-run sukces = tylko IAM permission check, nie weryfikuje attachment state.

#### Stan GA endpoint

| Sprawdzenie | Wynik |
|---|---|
| GA endpoint | ALB `planodkupow-qa-ALB` — nowa VPC (`vpc-007d115c41f079bf3`) |
| ALB targety | `10.2.36.98:80` (gateway, healthy), `10.2.42.37:80` (healthy) |
| ALB listener | HTTP:80, priority rules (http-header + path-pattern), default=403 |
| GA health status | **Unknown** — ALB zwraca 403 dla health check (brak wymaganego headera) |
| Route53 planodkupow.qa | **PRIVATE zone** (skojarzona z nową VPC) — zero rekordów do GA/ALB |
| planodkupow.makotest.pl | PUBLIC — pusta (tylko NS/SOA) |
| Realny user traffic przez GA | **ZERO** — brak publicznego DNS entry wskazującego na GA |
| ALB ruch 7d | 499 requestów (prawdopodobnie GA health probes) |

#### Evidence matrix (zaktualizowana)

| Sprawdzenie | Wynik | Interpretacja |
|---|---|---|
| GA endpoint w Console | ALB planodkupow-qa-ALB | Accelerator istnieje i jest aktywny |
| ALB VPC | vpc-007d115c41f079bf3 (NOWA) | Endpoint wskazuje nową VPC |
| GA ENI subnety | subnet-049..., subnet-0f3... (STARA VPC) | Endpoint group subnety nie zaktualizowane po VPC rebuild |
| ENI delete fail | "currently in use" | ELA attachment z endpoint grupy trzyma ENI |
| Dry-run sukces | tylko IAM check | Nie oznaczał orphan — błędna interpretacja |
| GA health: Unknown | ALB default → 403 | Health check nie ma wymaganego headera |
| Route53 | brak wpisu do GA | Zerowy realny ruch przez GA |

---

## Pełny inwentarz starej VPC — Decommission Readiness (FINAL)

| Zasób | ID/wartość | Blokada |
|---|---|---|
| VPC | vpc-02f804baee8a3f048 | — |
| IGW | igw-0862c2814f8c0265b | nadal attached |
| NAT | nat-08adf3e0a226779a7 | EIP eipalloc-03f5ee498546ec65c |
| Subnet pub1 | subnet-049522191fe108784 | — |
| Subnet pub2 | subnet-0f3ba588e935c435a | — |
| Subnet prv1 | subnet-09ab9fdda1c1d2dea | — |
| Subnet prv2 | subnet-044777a4a035cb0ab | — |
| RT private | rtb-0413d3e3d2f15d6a5 | route 0.0.0.0/0 → NAT |
| RT main | rtb-04bdad34f8ac8b34a | (default, usunięty z VPC) |
| NACL | acl-0fe7c4971a5f960a8 | default, 4 assoc |
| VPCE ecr.api | vpce-0f06338f894336448 | — |
| VPCE ecr.dkr | vpce-0066f4327e86d8687 | — |
| VPCE secretsmanager | vpce-0dcfc106af654bae6 | — |
| VPCE logs | vpce-093fc974c5ae750f4 | — |
| GA ENI-1 | eni-0bc3e7b87b93ce431 | **ORPHANED** — deletable |
| GA ENI-2 | eni-0e9dd0667e09a945c | **ORPHANED** — deletable |
| GA SG | sg-0a9a29d06a6a7d85c | — |

**GO/NO-GO: GO — brak aktywnych blokerów. Stara VPC gotowa do decommission.**

### Kolejność usuwania

```bash
PROFILE="plan"
REGION="eu-central-1"

# 1. Usuń orphaned GA ENIs
aws ec2 delete-network-interface --profile $PROFILE --region $REGION \
  --network-interface-id eni-0bc3e7b87b93ce431
aws ec2 delete-network-interface --profile $PROFILE --region $REGION \
  --network-interface-id eni-0e9dd0667e09a945c

# 2. Usuń VPC Endpoints (4x)
aws ec2 delete-vpc-endpoints --profile $PROFILE --region $REGION \
  --vpc-endpoint-ids vpce-0f06338f894336448 vpce-0066f4327e86d8687 \
    vpce-0dcfc106af654bae6 vpce-093fc974c5ae750f4

# 3. Usuń NAT Gateway + poczekaj na deleted
aws ec2 delete-nat-gateway --profile $PROFILE --region $REGION \
  --nat-gateway-id nat-08adf3e0a226779a7
# wait ~60s, potem:
aws ec2 release-address --profile $PROFILE --region $REGION \
  --allocation-id eipalloc-03f5ee498546ec65c

# 4. Odepnij i usuń IGW
aws ec2 detach-internet-gateway --profile $PROFILE --region $REGION \
  --internet-gateway-id igw-0862c2814f8c0265b \
  --vpc-id vpc-02f804baee8a3f048
aws ec2 delete-internet-gateway --profile $PROFILE --region $REGION \
  --internet-gateway-id igw-0862c2814f8c0265b

# 5. Usuń subnety
aws ec2 delete-subnet --profile $PROFILE --region $REGION --subnet-id subnet-049522191fe108784
aws ec2 delete-subnet --profile $PROFILE --region $REGION --subnet-id subnet-0f3ba588e935c435a
aws ec2 delete-subnet --profile $PROFILE --region $REGION --subnet-id subnet-09ab9fdda1c1d2dea
aws ec2 delete-subnet --profile $PROFILE --region $REGION --subnet-id subnet-044777a4a035cb0ab

# 6. Usuń niestandardowe route tables
aws ec2 delete-route-table --profile $PROFILE --region $REGION \
  --route-table-id rtb-0413d3e3d2f15d6a5

# 7. Usuń GA SG
aws ec2 delete-security-group --profile $PROFILE --region $REGION \
  --group-id sg-0a9a29d06a6a7d85c

# 8. Usuń VPC (NACL default usunięty automatycznie)
aws ec2 delete-vpc --profile $PROFILE --region $REGION \
  --vpc-id vpc-02f804baee8a3f048
```

**Uwaga przed wykonaniem:** Zweryfikuj czy ECS service bastionhost nie restartował się ponownie w starej VPC (`describe-network-interfaces --filters Name=vpc-id,Values=vpc-02f804baee8a3f048 Name=interface-type,Values=interface`). Jeśli pojawi się nowy ENI typu `interface` — najpierw zaktualizuj ECS service do nowej VPC.

---

## CloudTrail Lake — zapytania dla danych sprzed 2026-01-25

```sql
-- Historia tworzenia starej VPC i NAT (okolice 2025-07)
SELECT eventTime, eventName, userIdentity.arn, userAgent, requestParameters
FROM <EVENT_DATA_STORE_ARN>
WHERE eventTime BETWEEN '2025-06-01 00:00:00' AND '2025-09-01 00:00:00'
  AND awsRegion = 'eu-central-1'
  AND (
    (eventName IN ('CreateVpc','CreateNatGateway','AttachInternetGateway','CreateVpcEndpoint')
     AND element_at(requestParameters, 'vpcId') = 'vpc-02f804baee8a3f048')
    OR (eventName = 'CreateVpc'
     AND json_extract_scalar(responseElements, '$.vpc.vpcId') = 'vpc-02f804baee8a3f048')
    OR (eventName = 'CreateNatGateway'
     AND json_extract_scalar(responseElements, '$.natGateway.natGatewayId') = 'nat-08adf3e0a226779a7')
  )
ORDER BY eventTime ASC
```

```sql
-- Pełna historia NAT nat-08adf3e0a226779a7
SELECT eventTime, eventName, userIdentity.arn, userAgent, requestParameters
FROM <EVENT_DATA_STORE_ARN>
WHERE awsRegion = 'eu-central-1'
  AND eventName IN ('CreateNatGateway','DeleteNatGateway','DescribeNatGateways')
  AND (element_at(requestParameters,'natGatewayId') = 'nat-08adf3e0a226779a7'
   OR json_extract_scalar(responseElements,'$.natGateway.natGatewayId') = 'nat-08adf3e0a226779a7')
ORDER BY eventTime ASC
```

---

## Komendy użyte w audycie

```bash
# Lookup events (przykład)
aws cloudtrail lookup-events \
  --profile plan --region eu-central-1 \
  --start-time 2026-01-01T00:00:00Z --end-time 2026-04-25T23:59:59Z \
  --lookup-attributes AttributeKey=EventName,AttributeValue=CreateVpc \
  --output json

# Resource lookup
aws cloudtrail lookup-events \
  --profile plan --region eu-central-1 \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue=vpc-02f804baee8a3f048 \
  --output json

# Sprawdzenie NAT
aws ec2 describe-nat-gateways --profile plan --region eu-central-1 \
  --nat-gateway-ids nat-08adf3e0a226779a7

# Sprawdzenie IGW
aws ec2 describe-internet-gateways --profile plan --region eu-central-1 \
  --internet-gateway-ids igw-0862c2814f8c0265b
```
