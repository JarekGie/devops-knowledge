---
title: Observability & Alerting Audit — LLZ AWS Organization
date: 2026-05-09
author: Jarosław Gołąb (CloudOps/SRE)
classification: internal
tags: [audit, observability, cloudwatch, guardduty, security-hub, oam, glpi, wazuh]
---

# Observability & Alerting Audit — LLZ AWS Organization

> **Tryb:** READ-ONLY. Żadnych zmian nie wprowadzono.  
> **Cel:** Mały koszt, wysoki signal/noise, actionable alerts, central visibility, minimal overhead.  
> **Data:** 2026-05-09 | Org ID: o-5c4d5k6io1

---

## PHASE 1 — Organization Inventory

### Konta AWS

| Account | AccountId | OU | Workload | Env | OAM Coverage |
|---|---|---|---|---|---|
| makolab_dc | 864277686382 | **ROOT (!)** | Management | - | brak |
| Admin MakoLab | 647075515164 | Platform | Admin/tools | - | **BRAK** |
| monitoring-nagios-bot | 814662658531 | Platform | Monitoring hub | - | destynacja |
| LogArchiveNew | 771354139056 | Security | Log archive | - | **BRAK** |
| dacia-asystent | 074412166613 | Workloads/Prod | AI assistant | PROD | ✅ Logs+Metrics+Traces |
| planodkupow | 333320664022 | Workloads/Prod | Plan odkupow | PROD (+UAT biz) | ✅ + ⚠️ duplikat |
| CC | 943696080604 | Workloads/Prod | CC platform | PROD | ✅ Logs+Metrics+Traces |
| RShop | 943111679945 | Workloads/Prod | E-commerce | PROD | ✅ + ⚠️ duplikat |
| Booking_Online | 128264038676 | Workloads/Prod | Booking | PROD | ✅ Logs+Metrics+Traces |
| planodkupowv1 | 292464762806 | Workloads/NonProd | Plan v1 | NONPROD | ✅ Logs+Metrics+Traces |
| DRP-TFS | 613448424242 | Workloads/NonProd | DRP/legacy | NONPROD | **BRAK** |
| lab | 052845428574 | Sandbox | Lab | DEV | **BRAK** |
| MakolabDev | 442703586623 | Quarantine | — | SUSPENDED | — |
| makolab_monitoring | 400837535641 | Quarantine | — | SUSPENDED | — |
| pbms | 378131232770 | Quarantine | — | SUSPENDED | — |

**Uwagi:**
- `makolab_dc` (management) jest **na poziomie root**, poza jakimkolwiek OU — anomalia, utrudnia SCP governance
- Delegated admin dla SecurityHub, GuardDuty, Config: `monitoring-nagios-bot` (814662658531) ✅

### Aktywnych kont: 12 | Suspended: 3 | OAM coverage: 6/12 = **50%**

---

## PHASE 2 — OAM / Central Observability

### Sinks

| Sink | Account | ARN | Status |
|---|---|---|---|
| observabilitySink | monitoring-nagios-bot | eu-central-1:sink/dc0f8121 | ACTIVE |
| (unnamed) | makolab_dc (management) | eu-central-1:sink/47f25ad... | ACTIVE — **SHADOW SINK** |

**⚠️ Znaleziono drugi sink w koncie management.** RShop i planodkupow wysyłają metryki do obu sinków jednocześnie.

### OAM Links

| Account | Metrics | Logs | Traces | Sink | Status |
|---|---|---|---|---|---|
| dacia-asystent | ✅ | ✅ | ✅ | monitoring | OK |
| CC | ✅ | ✅ | ✅ | monitoring | OK |
| planodkupow | ✅ | ✅ | ✅ | monitoring | OK |
| planodkupow | ✅ | ❌ | ❌ | **management** | ⚠️ DUPLIKAT |
| RShop | ✅ | ✅ | ✅ | monitoring | OK |
| RShop | ✅ | ❌ | ❌ | **management** | ⚠️ DUPLIKAT |
| Booking_Online | ✅ | ✅ | ✅ | monitoring | OK |
| planodkupowv1 | ✅ | ✅ | ✅ | monitoring | OK |

### Konta bez OAM link

| Account | Priorytet | Uzasadnienie |
|---|---|---|
| Admin MakoLab | MEDIUM | Brak workloadów produkcyjnych, ale ma IAM |
| DRP-TFS | **HIGH** | NONPROD ale aktywny — root credentials usage alert |
| LogArchiveNew | LOW | Tylko archiwum logów, nie generuje własnych workloadów |
| lab | LOW | Sandbox, akceptowalny gap |
| makolab_dc | MEDIUM | Management account, CloudTrail tam aktywny |

### Coverage: 6/10 aktywnych (poza hub) = **60%** | Prod coverage: 5/5 = **100%** ✅

### Problemy
- Duplikaty RShop + planodkupow → shadow sink w management → metryki duplikowane, potencjalnie podwójny koszt
- DRP-TFS brak OAM — mimo aktywnego konca z alertami root credential usage

---

## PHASE 3 — CloudWatch Audit

### Alarms Overview

| Account | Total | ALARM | INSUF_DATA | No Action | Disabled |
|---|---|---|---|---|---|
| monitoring-nagios-bot | 8 | 0 | 0 | 0 | 0 |
| Wszystkie inne | 0 | 0 | 0 | — | — |

**Architektura alarmów:** Scentralizowana w koncie monitoring. Alarmy pobierają metryki cross-account via OAM metric math. Dobry wzorzec.

### Istniejące alarmy (monitoring-nagios-bot)

| Alarm | Typ | Target SNS | Signal Quality |
|---|---|---|---|
| slo-rshop-error-rate | ALB 5xx > 1%, 3/5min | slo-alerts | ✅ HIGH — właściwy SLO |
| slo-rshop-latency-p99 | ALB p99 > 2s, 2/3min | slo-alerts | ✅ HIGH |
| slo-booking-error-rate | ALB 5xx > 1%, 3/5min | slo-alerts | ✅ HIGH |
| slo-booking-latency-p99 | ALB p99 > 3s, 2/3min | slo-alerts | ✅ HIGH |
| slo-dacia-error-rate | ALB 5xx > 1%, 3/5min | slo-alerts | ✅ HIGH |
| slo-dacia-latency-p99 | ALB p99 > 3s, 2/3min | slo-alerts | ✅ HIGH |
| slo-bbmt-uat-error-rate | ALB 5xx > 1%, 3/5min | slo-alerts | ✅ HIGH (prod-on-uat) |
| slo-bbmt-uat-latency-p99 | ALB p99 > 3s, 2/3min | slo-alerts | ✅ HIGH (prod-on-uat) |

**Ocena jakości:** Alarmy są dobrze zaprojektowane — datapoints_to_alarm zapobiega false positives, treat_missing_data=notBreaching jest właściwe dla cross-account.

### Gaps — czego brakuje

| Gap | Dotkniete konta | Priorytet | Uzasadnienie |
|---|---|---|---|
| ECS task count / CPU/Memory | wszystkie prod | HIGH | ECS jest 1350 USD/mies, 0 alertów |
| ECS service stopped tasks | wszystkie prod | HIGH | silent failure gdy taski crashują |
| RDS connections / CPU | planodkupow, dacia, rshop | HIGH | RDS = 300 USD/mies, 0 alertów |
| Redis evictions / connections | planodkupow (ElastiCache 147 USD) | MEDIUM | cache eviction = latency bomb |
| AmazonMQ queue depth | planodkupow | HIGH | 103 USD/mies broker, 0 alertów |
| Lambda errors / duration | - | MEDIUM | zależy od zużycia |
| health-notify Lambda errors | monitoring | MEDIUM | DLQ alarm jest, ale 0 subskrypcji |
| DLQ depth dla event bus | monitoring | MEDIUM | alarm istnieje, ale routing niejasny |
| NAT Gateway bytes | wszystkie | LOW | 803 USD VPC, głównie NAT |

### Signal/Noise ratio obecny: **BARDZO NISKI NOISE** ✅ (8 alarmów total, wszystkie SLO)
Problemem jest nie noise — tylko **brak pokrycia**, nie szum.

---

## PHASE 4 — SNS / Event Routing

### SNS Topics

| Topic | Region | Account | Subscriptions | Status |
|---|---|---|---|---|
| cloudwatch-alarms-glpi | eu-central-1 | monitoring | glpi@infra.makolab.pl ✅ | **DEAD — żaden alarm nie wysyła tu** |
| health-notifications | eu-central-1 | monitoring | glpi@infra.makolab.pl ✅, dc@makolab.com ⚠️ PENDING | Health Lambda → tu działa |
| slo-alerts | eu-central-1 | monitoring | jaroslaw.golab@makolab.com ✅ | OSOBISTY EMAIL — nie GLPI |
| health-ops-alerts | us-east-1 | monitoring | jaroslaw.golab@makolab.com ✅ | DLQ alarm target — osobisty |
| org-central-alarms | eu-central-1 | management | **BRAK** | DEAD — rule istnieje, 0 subskrypcji |
| cost-anomaly-alerts | us-east-1 | management | jaroslaw.golab@makolab.com ✅ | Osobisty email |

### Krytyczne problemy routingu

1. **`cloudwatch-alarms-glpi` jest DEAD** — topic istnieje, glpi@infra.makolab.pl potwierdzony, ale żaden alarm CloudWatch nie wysyła na ten topic. Topic powstał "dla przyszłości" ale nigdy nie podłączono alarmów.

2. **`slo-alerts` → email osobisty** — SLO breaches dla prod workloadów idą wyłącznie do jaroslaw.golab@makolab.com. Brak team inbox, brak GLPI.

3. **`org-central-alarms` → 0 subskrypcji** — zarządzana przez EventBridge rule `org-cloudwatch-alarms-to-sns` w management account. Rule łapie CloudWatch Alarm State Change events, ale SNS nie ma żadnego odbiorcy. Martwy koniec.

4. **dc@makolab.com PENDING** — subskrypcja health-notifications nigdy nie potwierdzona. Email może nie docierać.

5. **DLQ alarm target = health-ops-alerts** → osobisty email J.G. Jeśli Health Lambda zacznie failować, alert pójdzie tylko do jednej osoby.

### Routing — aktualny flow end-to-end

```
AWS Health Event (us-east-1)
    ↓ EventBridge rule (każde konto: health-to-monitoring)
    ↓ health-aggregation bus (monitoring, us-east-1)
    ↓ health-to-lambda rule
    ↓ health-notify Lambda (us-east-1)
    ↓ SNS health-notifications (eu-central-1)
    → glpi@infra.makolab.pl (email ✅)
    → dc@makolab.com (email ⚠️ PENDING)

SLO Breach (ALB cross-account metric)
    ↓ CloudWatch alarm (monitoring-nagios-bot)
    ↓ SNS slo-alerts
    → jaroslaw.golab@makolab.com (email) ← SINGLE POINT OF FAILURE
    [nie trafia do GLPI]
```

---

## PHASE 5 — AWS Health / Action Required

### Health Event Flow — co działa ✅

- Wszystkie 12 aktywnych kont mają regułę `health-to-monitoring` w us-east-1 (ENABLED)
- `health-aggregation` event bus w monitoring jest poprawnie skonfigurowany
- Lambda `health-notify` działa (0 błędów w ostatnich 7d)
- DLQ: 0 wiadomości ✅
- Routing do glpi@infra.makolab.pl działa (email potwierdzony)

### Problemy krytyczne

**1. Brak `scheduledChange` w event pattern**

```json
// AKTUALNY pattern (plik locals.tf):
"eventTypeCategory": ["issue", "investigation"]

// BRAKUJE:
"scheduledChange"  // maintenance windows, planned outages
"accountNotification"  // quota limits, deprecations
```

Skutek: CloudOps nie dostaje powiadomień o planowanych maintenance'ach AWS. Operator dowiaduje się o oknie maintenance dopiero po fakcie lub z komunikacji manualnej.

**2. Brak RESOLVED events**

Pattern `statusCode: ["open"]` oznacza że zamknięcie incydentu AWS nie jest obserwowane. Dla GLPI: nie można auto-zamknąć ticketu. Operator musi ręcznie sprawdzać stan.

**3. dc@makolab.com PENDING**

Jeśli był zamiar wysyłania do drugiego odbiorcy — subscription wygasła bez potwierdzenia. Albo usunąć albo potwierdzić.

**4. health-ops-alerts → personal email**

Alarmy infrastruktury routingu (DLQ depth, DLQ alarm on EventBridge delivery failures) idą wyłącznie do jaroslaw.golab@makolab.com. Brak redundancji.

### Ocena gotowości pod GLPI: **CZĘŚCIOWA**
- Email do glpi@infra.makolab.pl działa dla issues/investigations
- Brakuje scheduled changes
- Brakuje resolution events (auto-close)
- Format emaila z Lambda: wymaga weryfikacji czy GLPI parsuje go poprawnie jako ticket

---

## PHASE 6 — Security Signals

### Security Hub Findings (stan na 2026-05-09)

| Severity | Count | Actionable? | Rec. GLPI? |
|---|---|---|---|
| CRITICAL | 5 | ✅ TAK | ✅ TAK |
| HIGH | 14 | Częściowo | Selektywnie |
| MEDIUM | 31 | Głównie nie | ❌ NIE (noise) |
| LOW | 42 | NIE | ❌ NIE |

**Rozkład po kontach:**
- monitoring-nagios-bot: 70 findings (!) — paradoksalnie najbardziej "widoczne" konto
- DRP-TFS: 12 findings — `Policy:IAMUser-RootCredentialUsage` (CRITICAL wg GuardDuty, HIGH wg SH)
- Pozostałe konta: 1 finding każde

**Typy findings:**
- 69 × "Software and Configuration Checks / Industry and Regulatory Standards" = FSBP/CIS compliance = **NOISE dla ticketingu operacyjnego** — do dashboard/audytu, nie GLPI
- 12 × "TTPs/Policy:IAMUser-RootCredentialUsage" = **ACTIONABLE** — root bez MFA używany w DRP-TFS
- 11 × "TTPs/Discovery/Recon:EC2-PortProbeUnprotectedPort" = GuardDuty findings

**CRITICAL findings szczegółowo (wszystkie w monitoring-nagios-bot):**
- Hardware MFA nie włączone dla root (×2 — CIS + FSBP)
- SSM documents block public sharing nie włączone
- AWS Config nie skonfigurowany z service-linked role (×2)

### GuardDuty

| Severity | Count | Status |
|---|---|---|
| HIGH (≥7) | 0 | Brak |
| MEDIUM (4-6.9) | 0 | Brak |
| LOW (≤3.9) | 32 | Port scan, recon |

- Finding frequency: **SIX_HOURS** — 6 godzin opóźnienia między wykryciem a widocznością
- Dla GLPI: przy SIX_HOURS high-severity GuardDuty finding będzie widoczny do 6h po zdarzeniu

**Disabled features (= 45 Config NON_COMPLIANT rules = Security Hub compliance noise):**

Następujące features GuardDuty są wyłączone i generują Config NON_COMPLIANT:
S3 Data Events, EKS Audit Logs, EBS Malware Protection, RDS Login Events, EKS Runtime, Lambda Network Logs, Runtime Monitoring.

Te features kosztują extra i są opcjonalne — ale ich wyłączenie tworzy compliance noise który zalewa Security Hub LOW findings. Decyzja: albo włączyć (koszt), albo suppress w SH (czynność jednorazowa).

### Config NON_COMPLIANT: 45 rules

Większość = wyłączone GuardDuty features + IAM password policy + EBS encryption.  
Nie nadają się do automatycznego ticketowania — zbyt dużo drift compliance które są decyzjami świadomymi.

### Rekomendacja: CO do GLPI

| Source | Severity | Ticket? | Warunek |
|---|---|---|---|
| Security Hub | CRITICAL | ✅ TAK | Nowy finding, WorkflowStatus=NEW |
| Security Hub | HIGH | Selektywnie | Tylko wybrane Title (root usage, MFA, public exposure) |
| Security Hub | MEDIUM | ❌ NIE | Compliance drift, informatywne |
| Security Hub | LOW | ❌ NIE | Szum |
| GuardDuty | HIGH (≥7) | ✅ TAK | Nowy finding, unarchived |
| GuardDuty | MEDIUM (4-6.9) | Warunkowo | Dla prod accounts, nie lab |
| GuardDuty | LOW (≤3.9) | ❌ NIE | Port scan noise |
| Config NON_COMPLIANT | - | ❌ NIE | Dashboard only, nie GLPI |
| Health issue/investigation | - | ✅ TAK | Działa już |
| Health scheduledChange | - | ✅ TAK | BRAKUJE — dodać do pattern |

---

## PHASE 7 — Wazuh Integration Readiness

### Ocena kandydatów

| Source | Volume/mies | Noise | Koszt ryzyka | Rekomendacja |
|---|---|---|---|---|
| CloudTrail (org-wide) | Wysoki (99.50 USD/mies dostawa) | Średni | MEDIUM | ✅ Dobry kandydat — już płacimy |
| GuardDuty findings | Niski (32 findings) | Niski | LOW | ✅ Dobry kandydat — niski volume |
| Security Hub findings | Średni (92 NEW) | WYSOKI (75% compliance) | MEDIUM | ⚠️ Tylko CRITICAL+HIGH przez filtr |
| VPC Flow Logs | Tylko dacia (240MB/mies CW) | Bardzo wysoki | **WYSOKI** | ⚠️ Nie włączać wszędzie — koszt eksploduje |
| ALB Access Logs | Nieznany (nie sprawdzone) | Bardzo wysoki | **WYSOKI** | ❌ Tylko dacia/rshop i z próbkowaniem |
| WAF Logs | Nieznany | Bardzo wysoki | **WYSOKI** | ❌ Nie teraz |
| ECS container logs | ~750MB/mies we wszystkich prod | Wysoki | MEDIUM | ❌ Za głośno, za mało wartości bezp. |

### Wnioski

**Bezpieczne do Wazuh (Faza 1):**
- CloudTrail — już zbierany, org-wide, umiarkowany koszt ingest
- GuardDuty findings przez Security Hub integration lub bezpośredni API pull

**Ostrożnie (Faza 2, tylko dla wybranych kont):**
- VPC Flow Logs tylko dla dacia (już włączone) i rshop — nie wszędzie
- Security Hub tylko CRITICAL + HIGH z filtrem

**Nie teraz:**
- WAF logs — nie ma podstawy do analizy, za drogo
- ALB access logs — terabajty danych, znikoma wartość bezpieczeństwa
- AmazonMQ logs — wyłącznie operacyjne, nie security
- ECS container logs — aplikacyjne, zero security value

**Ryzyko retention:**
- CloudTrail logi trafiają do S3 (LogArchiveNew) — Wazuh powinien czytać z S3, nie z CloudWatch
- Jeśli ingest do Wazuh = CloudWatch Logs Subscription — podwójny koszt i egress

---

## PHASE 8 — FinOps / Cost Impact

### Aktualny koszt observability (kwiecień 2026)

| Usługa | Koszt | Główny driver |
|---|---|---|
| Amazon CloudWatch | **161.27 USD** | Canary runs 36.56 + Data processing 53.06 + Metrics 41.25 |
| AWS CloudTrail | **99.50 USD** | Org trail, event delivery |
| Amazon GuardDuty | **24.30 USD** | Podstawowe features |
| AWS Security Hub | ~0 USD (w Free Tier?) | Sprawdzić |
| AWS Config | ~0 USD (w Free Tier?) | Sprawdzić |
| Amazon SNS | ~0 USD | Email subscriptions |
| **Total observability** | **~285 USD/mies** | |

### CloudWatch — szczegóły kosztów

| Linia kosztowa | Kwiecień | Analiza |
|---|---|---|
| EUC1-DataProcessing-Bytes | 53.06 USD | Log ingest/processing — planodkupow (AmazonMQ 9.7GB!) |
| EUC1-CW:MetricsUsage | 41.25 USD | Custom/cross-account metrics |
| EUC1-CW:Canary-runs | **36.56 USD** | ⚠️ Booking Online Synthetics? Canary API shows 0 canaries |
| EUC1-CW:GMD-Metrics | 12.09 USD | GetMetricData API calls |
| EUC1-TimedStorage-ByteHrs | 6.49 USD | Log storage (planodkupow 90d retention) |
| EUC1-DashboardsUsageHour | 6.43 USD | CloudWatch Dashboards |

### Ryzyka kosztowe

**1. planodkupow / AmazonMQ logs — 9.7GB, 90-day retention**
- Dwa brokery MQ logują do CloudWatch z retencją 90 dni
- Szacowany koszt przechowywania: ~6-8 USD/mies tylko za storage + ~50 USD/mies ingest
- Fix: zmiana retencji z 90d → 7d lub 14d
- Oszczędność: ~30-40 USD/mies

**2. Canary runs — 36.56 USD/mies**
- API describe-canaries zwraca 0 canaries dla booking-online, ale log group `/aws/lambda/cwsyn-...` ma 171MB z 90d retention
- Możliwe że canary istnieje ale CloudDetectiveReadOnly nie ma do niego dostępu
- Jeśli canary jest aktywny: 36 USD/mies to dużo za 1 endpoint — sprawdzić częstotliwość wywołań

**3. VPC Flow Logs expansion risk**
- Aktualnie tylko dacia: ~140MB/mies = ~1-2 USD/mies storage
- Gdyby włączyć na wszystkich prod kontach: planodkupow ma Amazon MQ + ECS, rshop ECS — łatwo 10×
- Ryzyko: 20-50 USD/mies przy standardowej retencji

**4. Management account budget — BŁĘDNY**
- Budget: limit=40 USD, actual=1302 USD — budget jest całkowicie źle skonfigurowany (40 USD to chyba placeholder)
- Konto management zawiera CloudTrail ($99.50), część GuardDuty, część Config
- Należy zaktualizować limit do realnego (np. 200 USD) i dodać alerty przy 80%/100%

**5. GuardDuty advanced features — koszt vs compliance noise**
- 10 wyłączonych features → 45 NON_COMPLIANT Config rules → Security Hub MEDIUM/LOW findings szum
- Opcja A: suppress findings w Security Hub (0 koszt, cicha kompromis)
- Opcja B: włączyć tylko S3 Data Events i Malware Protection (realny wzrost kosztu ~+20-30%)
- Opcja C: zostawić wyłączone, zaakceptować jako known exception

### SAFE MINIMAL BASELINE dla tej organizacji

```
CloudTrail (org-wide)       : 99 USD/mies  — KEEP, konieczny
GuardDuty (podstawowe)      : 24 USD/mies  — KEEP, konieczny
Security Hub                : ~3-5 USD     — KEEP, delegated admin
CloudWatch Alarms (8 SLO)   : ~1.5 USD     — KEEP, dobre
CloudWatch Metrics (OAM)    : 41 USD       — KEEP, cross-account metryki
CloudWatch Dashboards       : 6 USD        — KEEP
CloudWatch DataProcessing   : 53 USD       — ⚠️ OPTYMALIZUJ (planodkupow MQ retention)
CloudWatch Canary           : 36 USD       — ⚠️ WERYFIKUJ (czy aktywny, jaka freq)
--------------------------------------------------
TOTAL BASELINE              : ~265-270 USD/mies
POTENCJALNA OSZCZĘDNOŚĆ     : 30-40 USD/mies (MQ logs + canary optymalizacja)
```

---

## PHASE 9 — Target Operating Model

### Rekomendowany flow

```
┌─────────────────────────────────────────────────┐
│           TIER 1 — AUTO TICKET (GLPI)           │
├─────────────────────────────────────────────────┤
│  SLO breach (error rate / latency)              │ → CloudWatch → SNS → GLPI email
│  AWS Health issue/investigation                  │ → Lambda → SNS → GLPI email
│  AWS Health scheduledChange [DO DODANIA]         │ → Lambda → SNS → GLPI email
│  GuardDuty HIGH/CRITICAL                        │ → SH Event → Lambda → GLPI [BRAKUJE]
│  Security Hub CRITICAL                          │ → SH Event → Lambda → GLPI [BRAKUJE]
└─────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────┐
│          TIER 2 — DASHBOARD + EMAIL             │
├─────────────────────────────────────────────────┤
│  ECS service health                             │ → CloudWatch Dashboard [BRAKUJE alarmów]
│  RDS metrics                                    │ → CloudWatch Dashboard [BRAKUJE alarmów]
│  GuardDuty MEDIUM                              │ → Security Hub dashboard
│  Security Hub HIGH (compliance)                 │ → Security Hub dashboard
│  Config NON_COMPLIANT                          │ → Config dashboard
│  Cost anomalies                                 │ → Email (dopuszczalne)
└─────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────┐
│               TIER 3 — IGNORE                   │
├─────────────────────────────────────────────────┤
│  Security Hub LOW/MEDIUM (compliance)            │
│  GuardDuty LOW                                  │
│  Config compliance dla wyłączonych GD features  │
│  AmazonMQ heartbeat logs                        │
│  ECS task health check noise                    │
└─────────────────────────────────────────────────┘
```

### Routing decision tree

| Alert type | SLA | Akcja | Kanał |
|---|---|---|---|
| SLO breach (prod) | 15 min | Tier-1 GLPI ticket | slo-alerts → glpi@infra.makolab.pl |
| AWS Health issue | 30 min | Tier-1 GLPI ticket | health-notifications → glpi@infra.makolab.pl |
| AWS Health scheduled | 24h | Tier-1 GLPI ticket | dodać scheduledChange |
| GuardDuty HIGH | 1h | Tier-1 GLPI ticket | BRAKUJE implementacji |
| SH CRITICAL | 1h | Tier-1 GLPI ticket | BRAKUJE implementacji |
| ECS service down | 30 min | Tier-1 GLPI ticket | BRAKUJE alarmów |
| RDS space/connections | 4h | Tier-2 email/dashboard | BRAKUJE alarmów |
| Cost anomaly | 24h | Email tylko | ok — osobisty email akceptowalny |
| GuardDuty MEDIUM | — | Dashboard review | — |
| SH HIGH (compliance) | — | Weekly review | — |

---

## PHASE 10 — Final Report

### 1. Executive Summary

LLZ ma solidne fundamenty obserwability dla **warstwy SLO (frontend)**: 8 alarmów cross-account na ALB error rate i latency p99 dla 4 prod workloadów. Health notifications przez EventBridge → Lambda → SNS działają i dostarczają do GLPI. OAM pokrywa 100% prod kont.

Jednak **warstwa operacyjna (backend)** jest ślepa: 0 alarmów dla ECS, RDS, Redis, MQ. Routing bezpieczeństwa (GuardDuty, Security Hub) istnieje w dashboardach ale nie tworzy ticketów. Kilka SNS topics jest "dead" — istnieją, ale nic do nich nie wysyła lub nie mają subskrybentów.

**Biggest single risk:** SLO breach trafia tylko do osobistego emaila jednej osoby.

---

### 2. Current Maturity

```
OAM Coverage          : ████████░░  80% prod, 50% all accounts
CloudWatch Alarms     : ████░░░░░░  Tylko SLO/ALB. Backend = 0
SNS Routing           : ██████░░░░  Częściowe. 2 dead topics, 1 dead rule
Health Notifications  : ████████░░  Działa, brakuje scheduledChange
Security Hub routing  : ██░░░░░░░░  Brak automation rules, 0 auto-tickets
GuardDuty alerting    : ███░░░░░░░  Findings widoczne, ale 6h delay, 0 GLPI routing
Config/Compliance     : █████░░░░░  45 NON_COMPLIANT, głównie known exclusions
Cost visibility       : ████░░░░░░  Budget źle skonfigurowany, anomaly monitor działa
```

---

### 3. Biggest Gaps

1. **SLO alerts → personal email** — produkcyjne SLO breaches nie trafiają do GLPI
2. **Health scheduledChange brakuje** — maintenance windows niewidoczne w GLPI
3. **Backend blindspot** — ECS, RDS, MQ, Redis: 0 alarmów
4. **Security Hub / GuardDuty → 0 GLPI routing** — CRITICAL findings nie tworzą ticketów
5. **Dead SNS / dead rules** — cloudwatch-alarms-glpi, org-central-alarms, dc@makolab.com PENDING
6. **GuardDuty SIX_HOURS delay** — 6h lag dla security findings
7. **OAM duplikaty** — RShop, planodkupow wysyłają metryki do management account shadow sink
8. **planodkupow logs 9.7GB** — AmazonMQ 90-day retention = niepotrzebny koszt

---

### 4. Quick Wins (<1 dzień)

| # | Akcja | Efekt | Ryzyko |
|---|---|---|---|
| **QW-1** | Dodaj `slo-alerts` subskrypcję email: `glpi@infra.makolab.pl` | SLO breaches → GLPI | ZERO |
| **QW-2** | Zmień retencję AmazonMQ logów z 90d → 7d w planodkupow | ~30 USD/mies oszczędność | ZERO |
| **QW-3** | Dodaj `scheduledChange` i `accountNotification` do health event pattern | Maintenance widoczne | ZERO |
| **QW-4** | Dodaj `statusCode: ["closed"]` do health pattern (osobna reguła) | Auto-close możliwy | ZERO |
| **QW-5** | Usuń lub potwierdź `dc@makolab.com` pending subscription | Porządek | ZERO |
| **QW-6** | Usuń `org-cloudwatch-alarms-to-sns` rule lub dodaj subskrypcję | Dead rule cleanup | ZERO |
| **QW-7** | Usuń/wyczyść shadow OAM sink w management account (47f25ad) | Brak duplikatów kosztowych | LOW |
| **QW-8** | Popraw budget management account (40 USD → realistyczny) | Właściwe alerty | ZERO |

---

### 5. Medium Improvements (1-5 dni)

| # | Akcja | Czas | Efekt |
|---|---|---|---|
| **MI-1** | Dodaj ECS alarmy: RunningTaskCount, CPUUtilization, MemoryUtilization per service | 2-3h | Backend visibility |
| **MI-2** | Dodaj RDS alarmy: DatabaseConnections, CPUUtilization, FreeStorageSpace | 2h | DB visibility |
| **MI-3** | Dodaj MQ alarmy: QueueSize, ProducerCount, ConsumerCount | 1h | planodkupow visibility |
| **MI-4** | GuardDuty → Security Hub → EventBridge → Lambda → SNS cloudwatch-alarms-glpi | 4h | Security GLPI routing |
| **MI-5** | Security Hub automation rules: suppress known compliance noise (GD disabled features) | 2h | Signal/noise +50% |
| **MI-6** | GuardDuty finding frequency: SIX_HOURS → FIFTEEN_MINUTES | 5 min | Security response time |
| **MI-7** | Dodaj OAM link dla DRP-TFS | 30 min | Brak coverage gap |

---

### 6. Dangerous Ideas to Avoid

| Pomysł | Dlaczego NIE |
|---|---|
| VPC Flow Logs wszędzie | planodkupow + rshop + booking = 100x koszt obecny. Dane bez wartości security jeśli nie masz SIEM |
| WAF logging | Terabajty/dzień, ogromny koszt S3 + ingest, zero wartości bez regul analizy |
| CloudWatch Container Insights wszędzie | 53 USD/mies już za processing. CI dodaje 2x custom metrics = kolejne 40-60 USD |
| GuardDuty Runtime Monitoring prod | Runtime agent w ECS taskach = performance overhead, niestabilność, ogromny koszt |
| Security Hub → Wazuh direct stream | 92 findings dziś, tysiące findings po włączeniu compliance rules = SIEM pożre budżet |
| Subskrypcja CloudWatch Logs do Wazuh | Egress + ingest + Wazuh storage = 3x koszt logów |
| ALB Access Logs → CloudWatch | S3 + CloudWatch to podwójny koszt. Trzymać ALB logs w S3 tylko |
| Osobny Nagios per workload account | Koliduje z OAM design. Scentralizowane alarmy w monitoring-nagios-bot to właściwy wzorzec |

---

### 7. Cost-Safe Recommendations

1. **Nie włączaj żadnych nowych log sources** bez kalkulacji kosztu
2. **Zmień MQ retention** w planodkupow: 90d → 7d — pierwsza akcja, darmowa
3. **Sprawdź canary** w Booking_Online — 36 USD/mies to dużo; jeśli sprawdza 1 endpoint co minutę, zmień na co 5 min (-80% koszt)
4. **OAM metryki tylko dla prod accounts** — planodkupowv1 (nonprod) ma pełny OAM link; jeśli nie potrzeba traces, można ograniczyć do Metrics only
5. **Nie dodawaj Security Hub standard NIST** — aktualny coverage FSBP/CIS jest wystarczający i generuje już 69 compliance findings
6. **Wazuh ingest przez S3 (CloudTrail)** — nie przez CloudWatch Logs Subscription (2x koszt egress)

---

### 8. Recommended Phase 1 — GLPI Integration

**Cel:** Każdy actionable alert trafia do GLPI jako ticket. Brak nowego kodu.

**Krok 1 (QW-1):** Dodaj glpi@infra.makolab.pl do SNS `slo-alerts`
```bash
# terraform: dodaj glpi@infra.makolab.pl do var.slo_notification_emails w monitoring/terraform.tfvars
```

**Krok 2 (QW-3):** Dodaj scheduledChange do health event pattern w `locals.tf`

**Krok 3 (MI-4):** Security Hub → EventBridge → Lambda → SNS cloudwatch-alarms-glpi
- EventBridge rule na Security Hub findings CRITICAL
- Lambda enrichment (account name lookup, finding link)
- SNS cloudwatch-alarms-glpi → glpi@infra.makolab.pl (topic już istnieje, email już potwierdzony)

**Krok 4:** GLPI email intake — sprawdzić czy glpi@infra.makolab.pl tworzy ticket automatycznie z emaila

Rezultat: GLPI dostaje tickety z:
- SLO breach (prod)
- AWS Health issue + scheduled maintenance
- Security Hub CRITICAL
- GuardDuty HIGH (przez SH integration)

---

### 9. Recommended Phase 1 — Wazuh Integration

**Cel:** Minimalne, wartościowe dane bezpieczeństwa w Wazuh bez eksplozji kosztów.

**Source 1: CloudTrail → S3 → Wazuh**
- Org-wide CloudTrail ląduje w S3 (LogArchiveNew)
- Wazuh S3 fetcher — nie CW Subscription — zero dodatkowego kosztu
- Wartość: wszystkie API calls, IAM changes, Console logins

**Source 2: GuardDuty → Security Hub → Wazuh API pull**
- Security Hub posiada aggregated view
- Wazuh może pollować Security Hub findings API co 15 min
- Wartość: threat detection, nie compliance noise

**Source 3: VPC Flow Logs tylko dacia (już włączone)**
- Nie rozszerzać na inne konta w tej fazie

**NIE teraz:**
- WAF, ALB access logs, ECS logs, AmazonMQ logs

---

### 10. Final Architecture Recommendation

```
┌─────────────────────────────────────────────────────────────────┐
│                    SOURCE ACCOUNTS (prod)                        │
│  dacia | rshop | booking | planodkupow | CC | planodkupowv1     │
│  ALB metrics → OAM → monitoring-nagios-bot                      │
│  Health events → EventBridge → monitoring health-aggregation    │
└──────────────────────────┬──────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────────┐
│                 monitoring-nagios-bot (HUB)                      │
│                                                                  │
│  CloudWatch SLO Alarms ──→ SNS slo-alerts ──→ GLPI ✅           │
│                                              (dodaj glpi email)  │
│                                                                  │
│  Health Lambda ───────────→ SNS health-notifications ──→ GLPI ✅ │
│  (+ scheduledChange)                                             │
│                                                                  │
│  Security Hub Findings ──→ EventBridge ──→ Lambda               │
│  (CRITICAL + GD HIGH)                     ──→ SNS cloudwatch-   │
│                                               alarms-glpi ──→ GLPI │
│                                                                  │
│  CloudWatch Dashboards ──→ OAM metrics from all prod accounts    │
│  (OAM Sink: observabilitySink)                                   │
└─────────────────────────────────────────────────────────────────┘
                           ↓ (faza 2)
┌─────────────────────────────────────────────────────────────────┐
│                          WAZUH                                   │
│  CloudTrail S3 (LogArchiveNew) → Wazuh S3 fetcher               │
│  Security Hub findings API → Wazuh polling                      │
│  VPC Flow Logs dacia (CW) → Wazuh CW agent (tylko dacia)        │
└─────────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────────┐
│                          GLPI                                    │
│  Ticket intake: email glpi@infra.makolab.pl                     │
│  SLA: CRITICAL=15min, HIGH=1h, MEDIUM=4h, INFO=dashboard        │
└─────────────────────────────────────────────────────────────────┘
```

---

## FINAL VERDICT

### **GO** — z warunkami

Infrastruktura observability jest solidna. Nie potrzeba przebudowy. Potrzeba **domknięcia kilku routingowych luk** które powodują że alerty istnieją ale nie tworzą ticketów.

### GO / NO-GO Decision

| Area | Status | Verdict |
|---|---|---|
| OAM / central visibility | 100% prod | GO |
| SLO alerting | działa, zły routing | **FIX FIRST** |
| Health notifications | działa, brakuje scheduled | **FIX FIRST** |
| Security routing | 0 GLPI tickets | **FIX FIRST** |
| Backend visibility | 0 alarmów | ACCEPTABLE — faza 2 |
| Cost | ok, 1-2 optymalizacje | GO |
| Wazuh | gotowe warunki | GO — zacząć od CloudTrail S3 |
| GLPI SIEM | nie gotowe bez MI-4 | NEEDS WORK |

### Recommended Next Step

**Tydzień 1 (Quick Wins):**
1. Dodaj glpi@infra.makolab.pl do `slo-alerts` SNS (5 min, terraform.tfvars)
2. Zmień MQ log retention w planodkupow: 90d → 7d (5 min)
3. Dodaj scheduledChange do health event pattern (15 min, locals.tf)
4. Usuń dead SNS subscriptions i dead EventBridge rule (15 min)

**Tydzień 2:**
5. Security Hub CRITICAL → EventBridge → Lambda → cloudwatch-alarms-glpi
6. GuardDuty finding frequency → FIFTEEN_MINUTES

**Tydzień 3-4:**
7. ECS + RDS + MQ alarmy (Terraform)
8. Wazuh Phase 1: CloudTrail S3 + GuardDuty API

### Czego absolutnie NIE robić teraz

- **Nie włączaj VPC Flow Logs wszędzie** — koszt niekontrolowany
- **Nie włączaj GuardDuty Runtime Monitoring** — performance risk w ECS prod
- **Nie rób Enterprise SIEM** — nie ma potrzeby przy tej skali
- **Nie wdrażaj WAF logging** — bez analizy reguł to tylko koszt
- **Nie migruj SLO alarmów do source accounts** — centralizacja w monitoring-nagios-bot to właściwy wzorzec, nie zmieniaj

---

*Audyt wykonany 2026-05-09. Tryb READ-ONLY. Dane pobrane z AWS API + Terraform state.*
