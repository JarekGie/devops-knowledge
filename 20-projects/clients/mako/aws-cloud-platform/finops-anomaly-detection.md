---
title: finops-anomaly-detection
client: mako
project: aws-cloud-platform
domain: finops
document_type: iac-context
created: "2026-05-02"
updated: "2026-05-02"
tags:
  - aws
  - terraform
  - finops
  - cost-anomaly
  - mako
  - aws-cloud-platform
---

# AWS Cost Anomaly Detection — MakoLab Org

#aws #terraform #finops #cost-anomaly #mako

**Data implementacji:** 2026-05-02  
**Moduł Terraform:** `platform/finops/`  
**Backend:** `864277686382-terraform-state-bucket / platform/finops/terraform.tfstate`  
**Status:** plan gotowy, NIE zaaplikowany

---

## Architektura

```
Cost Explorer (org-level)
  └─ Anomaly Monitor: DIMENSIONAL / SERVICE
       └─ Subscription: DAILY, threshold >= $50 AND >= 20%
            └─ SNS: cost-anomaly-alerts (us-east-1, management account)
                 └─ Email: var.notification_emails
```

### Dlaczego SERVICE, nie LINKED_ACCOUNT

`SERVICE` dimension = wykrywa anomalie per usługa AWS, aggreguje po całej organizacji.  
`LINKED_ACCOUNT` dimension = wykrywa per konto — bardziej szczegółowe ale głośniejsze.

Wybór SERVICE = mniej alertów, wykrywa ważniejsze wzorce (np. "ECS kosztuje 3x więcej niż normalnie w całej org").

### Dual threshold — logika AND (kluczowe dla niskiego szumu)

```
ANOMALY_TOTAL_IMPACT_ABSOLUTE >= 50 USD
AND
ANOMALY_TOTAL_IMPACT_PERCENTAGE >= 20%
```

- Filtruje małe wzrosty na dużym spend (np. $60 na budżecie $1200 = tylko 5%)
- Filtruje procentowy szum na małym spend (np. 50% wzrost na $2 usłudze = tylko $1)
- Alert = tylko gdy anomalia jest DUŻA i ZNACZĄCA procentowo

---

## Pliki modułu

```
platform/finops/
├── backend.tf      — S3 backend
├── versions.tf     — TF >= 1.5, AWS >= 5.0
├── providers.tf    — default (eu-central-1) + aws.us_east_1 alias
├── variables.tf    — notification_emails, anomaly_threshold_usd (50), anomaly_threshold_pct (20), tags
├── sns.tf          — SNS topic + policy (costalerts.amazonaws.com) + email subscriptions
├── anomaly.tf      — aws_ce_anomaly_monitor + aws_ce_anomaly_subscription
└── outputs.tf      — monitor ARN, subscription ARN, SNS ARN
```

### Kluczowa uwaga: provider us_east_1

SNS topic MUSI być w `us-east-1` — wymóg AWS dla `aws_ce_anomaly_subscription`.  
CE resources (monitor, subscription) są globalne — używają default provider (eu-central-1 route do us-east-1 API automatycznie).

### SNS topic policy

Policy zastępuje domyślną — zawiera 2 statements:
1. `AllowOwnerAccess` — management account root ma SNS:* (zachowanie domyślnego zachowania)
2. `AllowCostAnomalyDetectionToPublish` — `costalerts.amazonaws.com` może publishować, z condition `aws:SourceAccount` = 864277686382 (anti-confused-deputy)

---

## Plan Terraform (2026-05-02)

```
Plan: 5 to add, 0 to change, 0 to destroy
```

Zasoby:
- `aws_ce_anomaly_monitor.org`
- `aws_ce_anomaly_subscription.org`
- `aws_sns_topic.cost_anomaly` (us-east-1)
- `aws_sns_topic_policy.cost_anomaly`
- `aws_sns_topic_subscription.cost_anomaly_email["jaroslaw.golab@makolab.com"]`

---

## Zastosowanie

```bash
cd platform/finops
AWS_PROFILE=mako-dc terraform apply \
  -var 'notification_emails=["jaroslaw.golab@makolab.com"]' \
  tfplan-anomaly
```

Po apply: sprawdź email — SNS wyśle confirmation request, trzeba potwierdzić subskrypcję.

---

## Koszt

- **Cost Anomaly Detection**: bezpłatne
- **SNS topic**: bezpłatne (< 1 MB/miesiąc dla paru alertów)
- **Email notifications**: bezpłatne (pierwszych 1000 emails/miesiąc)
- **Ryzyko kosztowe**: tylko nadmierny szum → zmień progi jeśli za głośno

---

## Dalsze kroki (opcjonalne iteracje)

| Iteracja | Opis | Kiedy |
|---|---|---|
| Dostosowanie progów | Obniż USD do $30 lub % do 15% gdy masz baseline | Po 2-4 tygodniach obserwacji |
| Per-account monitory | Dodaj LINKED_ACCOUNT monitor dla prod accounts | Jeśli SERVICE monitor nie łapie account-level spikes |
| Slack integration | Lambda subskrybuje SNS → Slack webhook | Gdy email staje się niewystarczający |
| Cost Anomaly + Budgets | Cross-reference: anomalia + zbliżanie do budżetu = prio alert | Zaawansowany FinOps |
