---
title: AWS Health / Events Monitoring Coverage — LLZ MakoLab
date: 2026-05-02
author: Claude Code (read-only audit)
domain: client-work
status: findings
---

# AWS Health / Events Monitoring Coverage

## VERDICT

**Pokrycie: 11/12 aktywnych kont — PRAWIE KOMPLETNE, jeden gap krytyczny.**

Infrastruktura EventBridge → health-aggregation bus → Lambda → SNS → email jest wdrożona i działa poprawnie na wszystkich kontach z wyjątkiem `makolab_dc` (konto zarządzające organizacją, Root). Brak DLQ w całym łańcuchu. GLPI nie jest jeszcze podpięte — na razie wyłącznie email.

```
FAKTY:
  - 11 kont: reguła ENABLED, target poprawny → health-aggregation bus
  - 1 konto (makolab_dc): brak reguły, brak roli — MISSING
  - Łańcuch: EventBridge → health-aggregation → Lambda health-notify → SNS eu-central-1 → email

HIPOTEZY (nieweryfikowalne read-only):
  - Lambda przetwarza eventy poprawnie (kod nie był czytany — tylko metadane)
  - SNS email jest aktywna subskrypcja (widać SubscriptionArn, bez potwierdzenia dostarczenia)
```

---

## 1. Struktura organizacji (Organizations)

**Org ID:** `o-5c4d5k6io1`  
**Management account:** `864277686382` (makolab_dc)

### OU hierarchy

```
Root (r-z8np)
├── makolab_dc [864277686382] — ACTIVE (konto zarządzające)
├── Platform (ou-z8np-40w1yjwg)
│   ├── Admin MakoLab [647075515164] — ACTIVE
│   └── monitoring-nagios-bot [814662658531] — ACTIVE ← central monitoring
├── Quarantine (ou-z8np-807kci0k)
│   ├── Audit [012086764624] — SUSPENDED/CLOSED
│   ├── MakolabDev [442703586623] — SUSPENDED/CLOSED
│   ├── Log Archive [518286664393] — SUSPENDED/CLOSED
│   └── makolab_monitoring [400837535641] — SUSPENDED/CLOSED
├── Sandbox (ou-z8np-dqtp5qcx)
│   ├── pbms [378131232770] — SUSPENDED/CLOSED
│   └── lab [052845428574] — ACTIVE
├── Security (ou-z8np-enuc6lre)
│   └── LogArchiveNew [771354139056] — ACTIVE
└── Workloads (ou-z8np-ny08nzho)
    ├── Production (ou-z8np-jomloow3)
    │   ├── planodkupow [333320664022] — ACTIVE
    │   ├── planodkupowv1 [292464762806] — ACTIVE
    │   ├── Booking_Online [128264038676] — ACTIVE
    │   ├── RShop [943111679945] — ACTIVE
    │   ├── dacia-asystent [074412166613] — ACTIVE
    │   └── CC [943696080604] — ACTIVE
    └── NonProduction (ou-z8np-ydx42f96)
        └── DRP-TFS [613448424242] — ACTIVE
```

Konta SUSPENDED/CLOSED są w Quarantine. Nie wymagają monitoringu.

---

## 2. Architektura przepływu eventów

```
[Konto źródłowe]
  default event bus
    └── Rule: health-to-monitoring [ENABLED]
          Pattern: source=aws.health, detail-type=AWS Health Event
                   eventTypeCategory=[issue, investigation]
                   statusCode=[open]
          Target: arn:aws:events:us-east-1:814662658531:event-bus/health-aggregation
          Role: health-eventbridge-forward (events.amazonaws.com trust, PutEvents only)
                |
                v
[monitoring-nagios-bot — 814662658531]
  event-bus: health-aggregation
    Policy: OrgPutEvents — allows * from org o-5c4d5k6io1
    └── Rule: health-to-lambda [ENABLED]
          Pattern: (identyczny — issue/investigation, open)
          Target: Lambda health-notify
                |
                v
  Lambda: health-notify (python3.12, handler: main.handler)
    Opis: "Enriches AWS Health events with account name and publishes to SNS"
    Env: SNS_TOPIC_ARN = arn:aws:sns:eu-central-1:814662658531:health-notifications
         ACCOUNT_NAMES = {11 kont: id → name}
                |
                v
  SNS: health-notifications (eu-central-1)
    Subscription: email → jaroslaw.golab@makolab.com
```

**Uwaga:** monitoring-nagios-bot ma własną regułę `health-to-aggregation-bus` na default busie — forwarduje własne health eventy na ten sam aggregation bus. Pattern identyczny.

---

## 3. Coverage Matrix

| account_id | account_name | OU | source_rule_exists | source_rule_enabled | target_central_bus | central_bus_accepts | effective_status | evidence |
|---|---|---|:---:|:---:|:---:|:---:|:---:|---|
| 864277686382 | makolab_dc | Root | **NO** | N/A | N/A | YES (org policy) | **MISSING** | brak reguły, brak roli health-eventbridge-forward |
| 647075515164 | Admin MakoLab | Platform | YES | YES | YES | YES | **OK** | rule health-to-monitoring, target health-aggregation |
| 814662658531 | monitoring-nagios-bot | Platform | YES | YES | YES (własny bus) | YES | **OK** | rule health-to-aggregation-bus na default bus |
| 052845428574 | lab | Sandbox | YES | YES | YES | YES | **OK** | rule health-to-monitoring, target health-aggregation |
| 771354139056 | LogArchiveNew | Security | YES | YES | YES | YES | **OK** | rule health-to-monitoring, target health-aggregation |
| 333320664022 | planodkupow | Workloads/Prod | YES | YES | YES | YES | **OK** | rule health-to-monitoring, target health-aggregation |
| 292464762806 | planodkupowv1 | Workloads/Prod | YES | YES | YES | YES | **OK** | rule health-to-monitoring, target health-aggregation |
| 128264038676 | Booking_Online | Workloads/Prod | YES | YES | YES | YES | **OK** | rule health-to-monitoring, target health-aggregation |
| 943111679945 | RShop | Workloads/Prod | YES | YES | YES | YES | **OK** | rule health-to-monitoring, target health-aggregation |
| 074412166613 | dacia-asystent | Workloads/Prod | YES | YES | YES | YES | **OK** | rule health-to-monitoring, target health-aggregation |
| 943696080604 | CC | Workloads/Prod | YES | YES | YES | YES | **OK** | rule health-to-monitoring, target health-aggregation |
| 613448424242 | DRP-TFS | Workloads/NonProd | YES | YES | YES | YES | **OK** | rule health-to-monitoring, target health-aggregation |

**Konta SUSPENDED** (Quarantine): pominięte — zamknięte, eventy nie są generowane.

---

## 4. Wzorzec eventów — co jest łapane

### Pattern stosowany we WSZYSTKICH regułach (source i central)

```json
{
  "source": ["aws.health"],
  "detail-type": ["AWS Health Event"],
  "detail": {
    "eventTypeCategory": ["issue", "investigation"],
    "statusCode": ["open"]
  }
}
```

### Pełna tabela wzorców

| source | detail-type | eventTypeCategory | statusCode | affectedAccount | target | konta źródłowe |
|---|---|---|---|---|---|---|
| aws.health | AWS Health Event | issue | open | brak filtra (wszystkie konta) | health-aggregation bus | 11 kont + monitoring-nagios-bot |

### Co NIE jest łapane (poza wzorcem)

| event category | statusCode | dlaczego poza filtrem |
|---|---|---|
| scheduledChange | upcoming / open | maintenance windows — nie w pattern |
| accountNotification | open | powiadomienia billing/compliance — nie w pattern |
| issue / investigation | resolved / closed | zamknięte eventy — statusCode nie ma "resolved" |

---

## 5. Szczegóły komponentów

### Central event bus: health-aggregation

```
ARN:     arn:aws:events:us-east-1:814662658531:event-bus/health-aggregation
Created: 2026-04-20
Policy:  OrgPutEvents — Principal: *, Condition: aws:PrincipalOrgID = o-5c4d5k6io1
         → Wszystkie konta organizacji mogą PutEvents na ten bus
```

### IAM rola: health-eventbridge-forward

Istnieje na każdym koncie z regułą (wdrożona przez Terraform — policy name: `terraform-20260420172337518100000001`):

```json
Trust: {"Service": "events.amazonaws.com"}
Policy: {
  "Action": "events:PutEvents",
  "Effect": "Allow",
  "Resource": "arn:aws:events:us-east-1:814662658531:event-bus/health-aggregation"
}
```

**NIE istnieje na:** makolab_dc (864277686382)

### Lambda: health-notify

```
ARN:         arn:aws:lambda:us-east-1:814662658531:function:health-notify
Runtime:     python3.12
Handler:     main.handler
Timeout:     30s
Memory:      128 MB
DLQ:         BRAK (brak EventInvokeConfig)
Description: Enriches AWS Health events with account name and publishes to SNS
SNS target:  arn:aws:sns:eu-central-1:814662658531:health-notifications
```

**ACCOUNT_NAMES w Lambda (11 kont):**

| account_id | name |
|---|---|
| 052845428574 | lab |
| 074412166613 | dacia-asystent |
| 128264038676 | Booking_Online |
| 292464762806 | planodkupowv1 |
| 333320664022 | planodkupow |
| 613448424242 | DRP-TFS |
| 647075515164 | Admin MakoLab |
| 771354139056 | LogArchiveNew |
| 814662658531 | monitoring-nagios-bot |
| 943111679945 | RShop |
| 943696080604 | CC |

**BRAKUJE:** 864277686382 (makolab_dc)

### SNS topics

| topic | region | subskrypcja | używany przez |
|---|---|---|---|
| health-notifications | eu-central-1 | email: jaroslaw.golab@makolab.com | Lambda health-notify |
| health-ops-alerts | us-east-1 | email: jaroslaw.golab@makolab.com | **NIEZNANY** — nie używany przez Lambda |

> **HIPOTEZA:** `health-ops-alerts` (us-east-1) może być reliktem poprzedniej konfiguracji lub planowanym topiciem dla GLPI. Wymaga wyjaśnienia — nie jest używany przez żaden znany komponent.

### Retry / DLQ — cały łańcuch

| komponent | retry | DLQ | uwagi |
|---|---|---|---|
| EventBridge rule target (source→central bus) | domyślny EventBridge (185 prób / 24h) | BRAK DeadLetterConfig | jeśli central bus niedostępny — eventy w retry queue 24h, potem utrata |
| EventBridge rule target (central bus→Lambda) | domyślny EventBridge | BRAK DeadLetterConfig | jak wyżej |
| Lambda EventInvokeConfig | N/A (EventBridge invoke) | BRAK DLQ | jeśli Lambda rzuci wyjątek — EventBridge retry, ale Lambda nie ma DLQ na invoke |

---

## 6. Kandydaci do filtrowania przed GLPI

| event category | przykładowy pattern | wysyłać do GLPI | priorytet w GLPI | uzasadnienie |
|---|---|:---:|---|---|
| issue | eventTypeCategory=issue, statusCode=open | **YES** | MEDIUM → escalate jeśli długo open | Potwierdzony problem AWS — wymaga śledzenia |
| investigation | eventTypeCategory=investigation, statusCode=open | **YES** | LOW | AWS bada — może się samorozwiązać, ale chcemy wiedzieć |
| scheduledChange | eventTypeCategory=scheduledChange, statusCode=upcoming | maybe | LOW / informational | Maintenance — warto mieć w GLPI dla change management |
| accountNotification | eventTypeCategory=accountNotification | **NO** | N/A | Billing, compliance notices — nie nadają się do ticketów GLPI |
| issue/investigation | statusCode=resolved/closed | **NO** (auto-close) | N/A | Zamknięte — powinny zamykać ticket, nie otwierać nowy |

---

## 7. Minimalny bezpieczny filtr na start do GLPI

### Co wysyłać na start (LOW dla wszystkiego)

```json
{
  "source": ["aws.health"],
  "detail-type": ["AWS Health Event"],
  "detail": {
    "eventTypeCategory": ["issue"],
    "statusCode": ["open"]
  }
}
```

Tylko `issue` + `open`. Poza filtrem: `investigation` (zbyt wiele fałszywych alarmów na start), `scheduledChange` (dodać po stabilizacji).

### Reguła priorytetyzacji dla GLPI

| warunek | GLPI priority | ticket action |
|---|---|---|
| eventTypeCategory=issue, statusCode=open | LOW na start | open |
| eventTypeCategory=issue, statusCode=resolved | — | close / update |
| eventTypeCategory=investigation, statusCode=open | (faza 2) LOW | open |

### Co zostawić tylko w mailu / logu

- `investigation` — do obserwacji ręcznej; nie blokuje, ale warto wiedzieć
- `scheduledChange` — na dashboard/mail; zbędny szum w GLPI dopóki nie ma change management workflow
- `accountNotification` — tylko mail/log, nigdy GLPI
- statusCode=resolved/closed — tylko mail; GLPI auto-close jeśli będzie implementacja

---

## 8. Findings — lista luk i problemów

### [F1] KRYTYCZNY: makolab_dc bez health forwarding

**Konto:** 864277686382 (makolab_dc) — konto zarządzające organizacji (Root OU)  
**Problem:** Brak reguły EventBridge, brak roli `health-eventbridge-forward`  
**Konsekwencja:** Health eventy dla konta zarządzającego (np. service issues dotyczące Organizations, Billing, SCP) nie trafiają do monitoringu  
**Evidence:** `aws events list-rules --profile mako-dc` → brak reguł; `aws iam get-role --role-name health-eventbridge-forward --profile mako-dc` → NoSuchEntity  

### [F2] ŚREDNI: Brak DLQ w całym łańcuchu

**Problem:** Żaden komponent nie ma Dead Letter Queue  
- EventBridge target (source→central bus): brak `DeadLetterConfig`  
- EventBridge target (central→Lambda): brak `DeadLetterConfig`  
- Lambda `health-notify`: brak `EventInvokeConfig` (DLQ/on-failure destination)  
**Konsekwencja:** Jeśli Lambda rzuca wyjątek lub central bus chwilowo niedostępny, eventy mogą zginąć po retry window  
**Evidence:** ResourceNotFoundException na GetFunctionEventInvokeConfig; brak DeadLetterConfig w ListTargetsByRule  

### [F3] INFORMACYJNY: Niespójność regionów

**Problem:** Lambda działa w us-east-1 (wymóg AWS Health API), ale SNS target jest w eu-central-1  
**Konsekwencja:** Cross-region SNS publish — działa, ale dodaje latency ~100ms i koszt cross-region  
**Evidence:** Lambda env `SNS_TOPIC_ARN=arn:aws:sns:eu-central-1:...` vs Lambda w us-east-1  

### [F4] INFORMACYJNY: Nieużywany SNS topic

**Problem:** `arn:aws:sns:us-east-1:814662658531:health-ops-alerts` — istnieje, ma subskrypcję email, ale nie jest używany przez żaden znany komponent  
**Konsekwencja:** Ewentualnie pomylenie podczas konfiguracji GLPI/przyszłych integracji  
**Evidence:** Lambda nie używa tego ARN; żadna reguła EventBridge nie wskazuje na ten topic  

### [F5] INFORMACYJNY: scheduledChange poza filtrem

**Problem:** Bieżący pattern nie łapie `scheduledChange` (maintenance windows)  
**Konsekwencja:** Zaplanowane maintenance serwisów AWS (np. EC2, RDS) nie trafiają do monitoringu  
**Evidence:** Pattern we wszystkich regułach: `eventTypeCategory: ["issue", "investigation"]`  

### [F6] INFORMACYJNY: ACCOUNT_NAMES w Lambda nie zawiera makolab_dc

**Problem:** Brak wpisu 864277686382 w env var ACCOUNT_NAMES  
**Konsekwencja:** Jeśli kiedyś makolab_dc zacznie forwardować eventy, Lambda wzbogaci je z account_id bez nazwy  

---

## 9. Rekomendacje

| prio | rekomendacja | scope | effort |
|---|---|---|---|
| HIGH | Dodaj health forwarding na makolab_dc: reguła `health-to-monitoring` + rola `health-eventbridge-forward` (taki sam wzorzec jak inne konta) | Terraform, konto 864277686382 | S — kopiuj moduł z innego konta |
| HIGH | Zaktualizuj ACCOUNT_NAMES w Lambda o `864277686382 → makolab_dc` po wdrożeniu F1 | Lambda env var | XS |
| MEDIUM | Dodaj DLQ/on-failure destination do Lambda `health-notify` (SQS queue jako dead letter) | Lambda config | S |
| MEDIUM | Dodaj DeadLetterConfig na EventBridge rule targets (SQS DLQ) dla reguł forwardujących | EventBridge rules, wszystkie konta | M (Terraform moduł) |
| LOW | Wyjaśnij przeznaczenie SNS `health-ops-alerts` (us-east-1) — usunąć lub udokumentować | SNS | XS |
| LOW | Rozważ dodanie `scheduledChange` do wzorca — szczególnie przed GLPI | EventBridge pattern | S |
| LOW | Przed GLPI: Lambda musi publikować do dedykowanego topicu/queue dla GLPI, NIE bezpośrednio do email-SNS | Lambda + GLPI connector | M |

---

## Next steps

1. **Natychmiast:** wdrożyć Terraform dla makolab_dc — skopiować `health_forwarding` moduł z istniejącego konta, dodać konto do ACCOUNT_NAMES w Lambda
2. **Przed GLPI:** dodać DLQ do Lambda i zdefiniować target dla GLPI (SNS lub SQS HTTP endpoint)
3. **GLPI faza 1:** tylko `issue + open`, wszystko jako LOW, bez `scheduledChange`
4. **Po stabilizacji:** dodać `scheduledChange`, rozważyć auto-close przy resolved events, eskalację dla długo-open issues
5. **Wyjaśnić:** przeznaczenie `health-ops-alerts` topic i czy można usunąć

---

*Audyt wykonany: 2026-05-02 | Metoda: read-only AWS CLI | Regiony: us-east-1 (EventBridge/Lambda), eu-central-1 (SNS)*  
*Narzędzia: aws organizations, aws events, aws lambda, aws sns, aws sqs, aws iam — tylko operacje List/Get/Describe*
