---
type: audit-note
updated: 2026-05-02
tags: [aws, cloudwatch, synthetics, canary, cleanup, monitoring, llz]
---

# CloudWatch Synthetics Canary Audit — 2026-05-02

## Interpretation

The current state is consistent with previous partial manual decommissioning of CloudWatch Synthetics canaries.

No active canaries were found, but orphaned log groups and artifact storage remain. These resources are likely leftovers from earlier manual cleanup after a cost increase was observed.

---

## Wynik audytu

**Wszystkie canaries zostały już wcześniej ręcznie usunięte** ze wszystkich kont Workloads/Production OU.

Pozostały wyłącznie zasoby sieroce (orphan resources) — log grupy i jeden bucket S3.

---

## Zakres audytu

Konta Workloads/Production OU (`ou-z8np-jomloow3`):

| Konto | ID | Canaries | Orphan zasoby |
|-------|----|----------|---------------|
| planodkupow | 333320664022 | 0 | **15 CW log groups** |
| Booking_Online | 128264038676 | 0 | **1 CW log group + 1 S3 bucket (pusty)** |
| RShop | 943111679945 | 0 | brak |
| dacia-asystent | 074412166613 | 0 | brak |
| planodkupowv1 | 292464762806 | 0 | brak |
| CC | 943696080604 | 0 | brak |
| monitoring-nagios-bot | 814662658531 | 0 | brak |

---

## Orphan Resources — szczegóły

### planodkupow (333320664022) — 15 log groups

Wszystkie grupy dostały retencję 90 dni (2026-05-02). Dane wygasną automatycznie.

```
/aws/synthetics/cwsyn-bbmt-qa-*   × 4   (dane: ~98KB–2MB)
/aws/synthetics/cwsyn-bbmt-uat-*  × 11  (dane: ~500KB–30MB)
```

### Booking_Online (128264038676) — 1 log group + 1 S3 bucket

```
/aws/synthetics/cwsyn-booking-prod-alb-hear-*   827 MB  (retencja 90d ustawiona)
s3://synthetics-artifacts                        PUSTY   (brak lifecycle)
```

---

## Operational Decision

- `planodkupow` cwsyn log groups: keep until natural expiration via 90d retention.
- `Booking_Online` 827 MB cwsyn log group: candidate for manual deletion after final confirmation.
- `Booking_Online` empty `synthetics-artifacts` bucket: candidate for deletion after confirming no active canaries or external references.

---

## Decommission Plan

### Opcja A — poczekaj na naturalny wygaśnięcie (zalecana, zero ryzyka)

Log grupy mają retencję 90 dni — wszystkie dane i metadane wygasną automatycznie do **2026-07-31**.

Bucket S3 `synthetics-artifacts` jest pusty — można go usunąć od razu.

### Opcja B — natychmiastowe usunięcie log groups

Jeśli zależy na zwolnieniu miejsca (głównie 827 MB w Booking_Online):
→ użyj komend poniżej.

---

## Komendy usunięcia (jednorazowe)

### S3 bucket (Booking_Online — pusty, usuń od razu)

```bash
CREDS=$(aws sts assume-role \
  --role-arn "arn:aws:iam::128264038676:role/OrganizationAccountAccessRole" \
  --role-session-name "synthetics-cleanup" \
  --profile mako-dc \
  --query 'Credentials' --output json)

export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | python3 -c "import json,sys; print(json.load(sys.stdin)['AccessKeyId'])")
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | python3 -c "import json,sys; print(json.load(sys.stdin)['SecretAccessKey'])")
export AWS_SESSION_TOKEN=$(echo "$CREDS" | python3 -c "import json,sys; print(json.load(sys.stdin)['SessionToken'])")

aws s3 rb s3://synthetics-artifacts --region eu-central-1

unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
```

### CW Log groups — Booking_Online (827 MB)

```bash
CREDS=$(aws sts assume-role \
  --role-arn "arn:aws:iam::128264038676:role/OrganizationAccountAccessRole" \
  --role-session-name "synthetics-cleanup" \
  --profile mako-dc \
  --query 'Credentials' --output json)

export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | python3 -c "import json,sys; print(json.load(sys.stdin)['AccessKeyId'])")
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | python3 -c "import json,sys; print(json.load(sys.stdin)['SecretAccessKey'])")
export AWS_SESSION_TOKEN=$(echo "$CREDS" | python3 -c "import json,sys; print(json.load(sys.stdin)['SessionToken'])")

# Lista grup do usunięcia
aws logs describe-log-groups --region eu-central-1 \
  --log-group-name-prefix "/aws/synthetics" \
  --query 'logGroups[].logGroupName' --output text

# Usuń każdą (zastąp <NAME> pełną nazwą grupy)
aws logs delete-log-group --log-group-name "<NAME>" --region eu-central-1

unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
```

### CW Log groups — planodkupow (15 grup)

```bash
CREDS=$(aws sts assume-role \
  --role-arn "arn:aws:iam::333320664022:role/OrganizationAccountAccessRole" \
  --role-session-name "synthetics-cleanup" \
  --profile mako-dc \
  --query 'Credentials' --output json)

export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | python3 -c "import json,sys; print(json.load(sys.stdin)['AccessKeyId'])")
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | python3 -c "import json,sys; print(json.load(sys.stdin)['SecretAccessKey'])")
export AWS_SESSION_TOKEN=$(echo "$CREDS" | python3 -c "import json,sys; print(json.load(sys.stdin)['SessionToken'])")

# Bulk delete wszystkich /aws/synthetics/* w tym koncie
aws logs describe-log-groups --region eu-central-1 \
  --log-group-name-prefix "/aws/synthetics" \
  --query 'logGroups[].logGroupName' --output text | \
  tr '\t' '\n' | \
  while read lg; do
    echo "Deleting: $lg"
    aws logs delete-log-group --log-group-name "$lg" --region eu-central-1
  done

unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
```

---

## Zmiany Terraform wykonane 2026-05-02

### platform/monitoring/ — nowe zasoby

**providers.tf** — dodano:
- `aws.planodkupowv1` → 292464762806
- `aws.cc` → 943696080604

**main.tf** — dodano:
- `aws_oam_link.planodkupowv1`
- `aws_oam_link.cc`

**alarms.tf** — nowy plik z SLO alarmami:
- `aws_sns_topic.slo_alerts` w koncie monitoring
- 6 alarmów (error rate + latency p99 × 3 workloady prod)

**variables.tf** — dodano: `slo_notification_emails`

### SLO Baseline

| Workload | Error Rate SLO | Latency p99 SLO | Alarm trigger |
|----------|---------------|-----------------|---------------|
| RShop | < 1% | < 2s | 3/5 min |
| Booking | < 1% | < 3s | 3/5 min (error), 2/3 min (latency) |
| Dacia | < 1% | < 3s | jak Booking |

---

## Status

- [x] Canary audit — kompletny
- [x] Orphan resources zinwentaryzowane
- [x] Log retention ustawiona (90d) na wszystkich orphan log groups
- [x] Terraform: OAM links dla planodkupowv1 + CC
- [x] Terraform: SLO alarms (alarms.tf)
- [x] **Terraform apply `platform/monitoring` — DONE 2026-05-02** (10 added, 0 changed, 0 destroyed)
- [x] OAM links: wszystkie 6 kont Workloads/Production podłączone do sink ✅
- [x] SLO alarms: 6 alarmów aktywnych (INSUFFICIENT_DATA → przejdą w OK po zebraniu danych) ✅
- [ ] Usunąć pusty S3 bucket `synthetics-artifacts` w Booking_Online (wymaga potwierdzenia)
- [ ] (opcjonalne) Ręczne usunięcie 827 MB cwsyn log group w Booking_Online przed wygaśnięciem
