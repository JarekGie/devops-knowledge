---
date: 2026-05-20
project: planodkupow
client: mako
account: "333320664022"
region: eu-central-1
profile: plan
tags: [planodkupow, finops, mq, redis, cloudwatch, delta, audit, ecs, orphan]
domain: client-work/mako
status: complete — live CLI evidence 2026-05-20
focus: [amazon-mq, elasticache, cloudwatch, cost-delta-april-may]
---

# PlanOdkupow — FinOps Delta Audit: kwiecień vs maj 2026

**Scope:** account 333320664022 | eu-central-1 | Profile `plan`  
**Metodologia:** READ ONLY — billing z Cost Explorer API, runtime z describe/list APIs  
**Zakres dat:** 2026-04-01 → 2026-05-19 (daily granularity)

> Poprzedni audyt runtime: [[planodkupow-runtime-verification-2026-04-26]]  
> CE billing source: [[planodkupow-ce-audit-2026-04-26]]

---

## Executive Summary

Kwiecień 2026 = dwa reżimy kosztowe: dni 1-18 (stary baseline ~$28/day) + dni 19-30 (post-chaos ~$33/day).  
Maj 2026 = pierwszy pełny miesiąc w post-chaos reżimie.

| Signal | Kierunek | Skala miesięczna |
|--------|----------|-----------------|
| CloudWatch retention fix | ↓ | **−$25/mo** (164 GB logów wygasło) |
| MQ m7g.medium permanentny | ↑ | **+$52/mo** vs pre-chaos |
| AWS Config org recorder (nowy maj-03) | ↑ | **+$14/mo** |
| Net change vs post-chaos April baseline | → | **~+$41/mo** |

---

## Environment inventory (live, 2026-05-20)

### CFN Stacks — wszystkie środowiska

| Środowisko | Stack | Stan | Uwagi |
|-----------|-------|------|-------|
| QA root | planodkupow-qa | UPDATE_COMPLETE | OK |
| QA | planodkupow-qa-KlasterStack | UPDATE_COMPLETE | Last: 2026-05-18 |
| QA | planodkupow-qa-CFStack | CREATE_COMPLETE | OK |
| QA | planodkupow-qa-DBStack | **UPDATE_ROLLBACK_COMPLETE** | Drift! |
| QA | planodkupow-qa-RedisStack | **UPDATE_ROLLBACK_COMPLETE** | Drift! Redis stuck |
| QA | planodkupow-qa-ALBStack | **UPDATE_ROLLBACK_COMPLETE** | Drift! |
| QA | planodkupow-qa-S3Stack | **UPDATE_ROLLBACK_COMPLETE** | Drift! |
| QA | planodkupow-qa-VPCStack | **UPDATE_ROLLBACK_COMPLETE** | Drift! |
| QA | planodkupow-qa-SecGroupStack | UPDATE_COMPLETE | OK |
| UAT | planodkupow-uat + all nested | UPDATE_COMPLETE | OK |
| DEV | planodkupow-dev | UPDATE_COMPLETE | Last: **2026-04-18** (dzień przed chaos!) |
| DEV | planodkupow-dev-VPCStack | **DELETE_FAILED** | vpc-05296c72c8fc49bd1 + igw stuck od 2021 |
| SFTP | sftp | **UPDATE_ROLLBACK_COMPLETE** | Od czerwca 2025! Transfer Server aktywny |
| Org | StackSet-aws-config-org-recorder | UPDATE_COMPLETE | **Nowy 2026-05-03** |

**Potwierdzono: brak PROD, DR, ephemeral środowisk.**

---

## Month-to-month cost delta

### Per serwis (April 30d vs May 20d MTD + projekcja)

| Serwis | Kwiecień | Maj/day | Kwiecień/day | Delta/day | Maj proj (30d) |
|--------|---------|---------|-------------|-----------|----------------|
| ECS | $409.67 | $13.75 | $13.66 | +$0.09 | $412 |
| VPC | $202.17 | $6.38 | $6.74 | −$0.36 | $191 |
| **MQ** | **$103.29** | **$5.16** | **$3.44** | **+$1.72** | **$155** |
| CloudTrail | $97.52 | $3.08 | $3.25 | −$0.17 | $92 |
| RDS | $80.05 | $2.47 | $2.67 | −$0.20 | $74 |
| **CloudWatch** | **$52.43** | **$0.67** | **$1.75** | **−$1.08** | **$20** |
| ElastiCache | $48.86 | $1.52 | $1.63 | −$0.11 | $46 |
| ELB | $38.83 | $1.21 | $1.29 | −$0.08 | $36 |
| EC2-Other | $37.44 | $1.16 | $1.25 | −$0.09 | $35 |
| Global Acc. | $18.00 | $0.56 | $0.60 | −$0.04 | $17 |
| **AWS Config** | **$0** | **$0.47** | **$0** | **+$0.47** | **$14** (NOWY) |
| Transfer Family | $10.46 | $0.43 | $0.35 | +$0.08 | $13 |
| ECR | $9.15 | $0.28 | $0.31 | −$0.03 | $8 |
| S3 | $6.21 | $0.14 | $0.21 | −$0.07 | $4 |
| WAF | $6.00 | $0.18 | $0.20 | −$0.02 | $5 |
| Tax | $258.34 | ~$8.63 | ~$8.61 | +$0.02 | ~$259 |

### Cost by Environment tag

|                   | Kwiecień  | Maj (20d) | Maj/day |
| ----------------- | --------- | --------- | ------- |
| No env (untagged) | $1,017.24 | $733.61   | $36.68  |
| qa                | $184.36   | $78.84    | $3.94   |
| uat               | $179.43   | $110.74   | $5.54   |
| dev               | $0.0015   | ~$0.0003  | ~$0     |
|                   |           |           |         |

---

## Amazon MQ — deep analysis

### Brokery (live runtime)

| Broker                        | BrokerId   | Type              | Engine | Created        | Tags          | CFN          | Cost proj/mo |
| ----------------------------- | ---------- | ----------------- | ------ | -------------- | ------------- | ------------ | ------------ |
| planodkupow-uat-RabbitMQ      | b-2d26b881 | mq.t3.micro       | 3.13.7 | 2021-08-11     | 7 (EN+PL mix) | ✓ UAT stack  | ~$21         |
| planodkupow-qa-rabbitmq-cheap | b-f231815d | **mq.m7g.medium** | 3.13.7 | **2026-04-21** | **ZERO**      | **✗ manual** | **~$109+**   |

### Usage types April vs May (billing evidence)

| Usage Type | Kwiecień | Maj (20d) | Trend |
|------------|---------|----------|-------|
| mq.m5.large | $15.39 | **$0** | Chaos broker usunięty ✓ |
| mq.m7g.medium (QA) | $37.43 (9d) | $73.05 (20d) | Permanentny wzrost ↑ |
| mq.t3.micro (UAT) | $36.18 | $13.92 | Stabilny |
| TimedStorage-ByteHrs | $12.67 | **$15.69** | **ROŚNIE** +86% per-day rate |

### Dzienna chronologia MQ

| Okres | Dzień | Co się działo |
|-------|-------|--------------|
| kwiecień 1-18 | $1.72/d | Stary QA t3.micro + UAT t3.micro |
| kwiecień 19 | $4.39 | Chaos start: stary broker pada, temp brokery |
| kwiecień 20 | **$9.93** | PEAK: m5.large + m7g.medium równolegle |
| kwiecień 21 | $7.79 | m7g.medium aktywny, m5.large usuwany |
| kwiecień 22+ | **$5.57/d** | Nowy stable baseline |
| maj 1-18 | **$5.55/d** | Stabilny, storage rośnie |

### Kluczowe ustalenie: QA MQ Attribution Shift

- Kwiecień: `Environment$qa = $32.44` (stary broker miał tag, ale broker usunięty)
- Maj: `Environment$qa = $0`, `Environment$ = $87.35` (nowy broker bez tagów)
- **Cały QA MQ cost stał się invisible w CE FinOps**

---

## ElastiCache — deep analysis

### Flatline pattern (CONFIRMED)

$1.632/dzień DOKŁADNIE każdy dzień kwiecień 1 → maj 18. Zero zmian.

### Ryzyko: Redis 5.0.6 EOL (CRITICAL)

| | QA Redis | UAT Redis |
|-|----------|----------|
| Engine | **Redis 5.0.6** | **Redis 5.0.6** |
| Created | **2026-04-19 (rebuild!)** | 2021-08-11 |
| AutoMinorVersionUpgrade | **TRUE** | **TRUE** |
| SnapshotRetentionLimit | **0 (zero backups)** | **0 (zero backups)** |
| Multi-AZ | NO | NO |
| CFN stack state | **UPDATE_ROLLBACK_COMPLETE** | UPDATE_COMPLETE |

**CRITICAL:** QA Redis odtworzono 2026-04-19 z IDENTYCZNYM 5.0.6 EOL który wywołał oryginalny chaos. Brak snapshots. CFN stack drift. AutoUpgrade włączony. To jest najwyższe ryzyko operacyjne w koncie.

---

## CloudWatch — retention fix impact

### Stored bytes: 164 GB → 3.11 GB (−98%)

| Log group | Stored (kwiecień) | Stored (maj) | Retention |
|-----------|------------------|-------------|-----------|
| UAT MQ connection | 134.96 GB | **1.22 GB** | 14 dni |
| UAT MQ channel | 29.29 GB | **~0** | (wygasło) |
| QA MQ connection | — | 1.22 GB | 14 dni |
| ECS UAT | — | 0.63 GB | 7 dni |

### CloudWatch usage types: April vs May

| Type | Kwiecień | Maj (20d) | Delta |
|------|---------|----------|-------|
| DataProcessing-Bytes (ingestion) | $42.12 | $9.87 | **−65%** |
| TimedStorage-ByteHrs (storage) | $5.26 | $0.33 | **−90%** |
| GMD-Metrics | $5.05 | $3.12 | −7% |

**Retention fix oszczędza ~$25/month trwale.**

---

## Orphan resources (bez zmian od kwietnia)

| Resource | ID | Cost/mo | Status |
|---------|-----|---------|--------|
| EIP unassociated | eipalloc-02f3a2a04522cff83 (3.77.136.162) | $3.60 | CONFIRMED WASTE |
| NAT Gateway | nat-08adf3e0a226779a7 (3.76.77.101) | ~$32+ | Stara QA VPC, created 2025-07-31 |
| VPC endpoints ×4 | stara QA VPC vpc-02f804baee8a3f048 | $28.80 | orphan suspect |
| Global Accelerator | 52.223.4.64/166.117.244.150 | $17 | Health Unknown, blokuje VPC cleanup |
| SFTP Transfer Server | s-24d39bfb417047f6b | ~$10 | Stack failed od 12 miesięcy |
| **Total** | | **~$91/mo** | |

---

## Governance gaps — bez zmian

| Gap | Stan |
|-----|------|
| ECS PropagateTags=NONE | **26/28 usług** — bez zmian |
| QA MQ broker bez tagów | **✗** — bez zmian |
| 6 EIPs bez tagów | **✗** — bez zmian |
| 5 QA nested stacks UPDATE_ROLLBACK_COMPLETE | **bez zmian** |
| QA Redis EOL 5.0.6 | **✗ NOWE ODKRYCIE — CRITICAL** |
| SFTP stack failed od 12 miesięcy | **✗ NOWE ODKRYCIE** |

---

## Timeline 2026

```
2021-08-11  UAT stack + broker + Redis stworzony
2025-06-13  SFTP stack wchodzi w UPDATE_ROLLBACK_COMPLETE (i zostaje tak)
2025-07-31  nat-08adf3e0a226779a7 created (stack DELETE_COMPLETE → orphan)
2026-04-18  planodkupow-dev root stack aktualizowany (24h przed chaos)
2026-04-19  CHAOS: Redis 5.0.0 EOL → Replace → rollback → rebuild
2026-04-20  CHAOS PEAK: MQ $9.93/day, CW $4.81/day
2026-04-21  planodkupow-qa-rabbitmq-cheap (m7g.medium) created — zero tags, poza CFN
2026-04-22  Nowy baseline: MQ $5.57/d, ECS $14.48/d
2026-04-27  CloudWatch zaczyna spadać (retention działa)
2026-04-28  CW wraca do normy $0.97/day
2026-05-03  AWS Config org recorder deployed — nowy koszt $14/mo
2026-05-09  CW stabilizuje się na $0.69/day (164 GB logów wygasło)
2026-05-18  MQ storage rośnie: $0.78/day vs $0.42/day kwiecień (+86% per-day rate)
```

---

## Rekomendacje

### SAFE (zero ryzyko)

| | Akcja | Efekt |
|-|-------|-------|
| S1 | Tag QA MQ broker (`aws mq create-tags`) | CE visibility |
| S2 | Tag 6 EIPs, 3 ECR repos, WAF | CE visibility |
| S3 | ECS PropagateTags=SERVICE na 26 serwisach | $267 attribution fix |
| S4 | Sprawdź CloudTrail data events | Diagnoza $92/mo |

### CAUTION (weryfikacja przed wykonaniem)

| | Akcja | Oszczędność | Prereq |
|-|-------|-------------|--------|
| C1 | Release unassociated EIP 3.77.136.162 | $3.60/mo | Confirm no DNS/firewall entries |
| C2 | MQ QA downgrade m7g.medium → t3.micro | **$83/mo** | Maintenance window, aplikacje tolerują restart |
| C3 | GA decommission (if 0 traffic) | $17/mo | ProcessedByteCount=0 przez ≥7 dni |
| C4 | 4 orphan VPC endpoints delete | $28.80/mo | GA usunięty najpierw |
| C5 | NAT decommission | ~$32/mo | GA + endpoints najpierw |
| C6 | QA Redis upgrade (5.0.6 → 7.x) | $0 cost, **zapobiega chaos** | Resolve CFN drift najpierw |
| C7 | SFTP stack investigate + resolve | ~$10/mo | Czy sftpdev używany? |

### DO NOT TOUCH

- planodkupow-qa-rabbitmq-cheap — QA workload zależy od niego
- planodkupow-uat-RabbitMQ — UAT workload
- QA Redis przed CFN drift fix
- Oba AMQ PrivateLink VPC endpoints (vpce-0aab2367, vpce-0973cb43)
- UAT i QA ECS/RDS/ALB — aktywne workloady

---

## Cross-References

- [[planodkupow-runtime-verification-2026-04-26]] — poprzedni runtime audit (baza porównawcza)
- [[planodkupow-ce-audit-2026-04-26]] — CE billing analysis kwiecień
- [[planodkupow-finops-governance-audit-2026-04-25]] — governance posture assessment
- [[planodkupow-orphan-network-investigation-2026-04-24]] — stara QA VPC forensics
