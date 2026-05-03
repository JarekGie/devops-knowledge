---
title: AWS Config — Compliance Check (Org Baseline)
tags:
  - aws
  - config
  - compliance
  - llz
  - runbook
---

# AWS Config — Compliance Check (Org Baseline)

## Symptom / cel

Zbieranie danych compliance z org-wide Config rules po wdrożeniu Phase 3 (lub w ramach regularnego przeglądu LLZ).

## Zakres

11 kont member (management account wykluczony — brak recordera).  
Aggregator: `org-aggregator` w koncie `monitoring-nagios-bot` (814662658531).

## Szybkie komendy

### Aggregate summary (wszystkie reguły, wszystkie konta)

```bash
aws configservice describe-aggregate-compliance-by-config-rules \
  --configuration-aggregator-name org-aggregator \
  --profile cd-monitoring-nagios-bot \
  --region eu-central-1 \
  --output table
```

### Per-rule per-account breakdown

```bash
RULE=cloudtrail-enabled   # zamień na nazwę reguły
aws configservice get-aggregate-compliance-details-by-config-rule \
  --configuration-aggregator-name org-aggregator \
  --config-rule-name "$RULE" \
  --profile cd-monitoring-nagios-bot \
  --region eu-central-1 \
  --output table
```

### Wszystkie 5 reguł naraz (loop)

```bash
for RULE in cloudtrail-enabled iam-root-access-key-check \
            multi-region-cloud-trail-enabled \
            s3-bucket-public-read-prohibited \
            s3-bucket-public-write-prohibited; do
  echo "=== $RULE ==="
  aws configservice get-aggregate-compliance-details-by-config-rule \
    --configuration-aggregator-name org-aggregator \
    --config-rule-name "$RULE" \
    --profile cd-monitoring-nagios-bot \
    --region eu-central-1 \
    --query 'AggregateEvaluationResults[*].{Account:EvaluationResultIdentifier.EvaluationResultQualifier.ConfigRuleArn,Compliance:ComplianceType}' \
    --output table 2>&1
done
```

## Decision points

| Wynik | Co zrobić |
|---|---|
| Wszystkie COMPLIANT | Baseline OK — proceed to optional rules |
| CloudTrail disabled | ❌ Critical — fix before FTR |
| Root key active | ❌ Critical — fix before FTR |
| No multi-region trail | ⚠️ Medium — plan fix |
| S3 public bucket | ⚠️ Low/Medium — investigate, may be intentional |
| NO_DATA po 15 min | ⚠️ Sprawdź recorder status konta |

## Klasyfikacja wyników

### Critical (przed FTR)
- `cloudtrail-enabled` → NON_COMPLIANT
- `iam-root-access-key-check` → NON_COMPLIANT (aktywny root key!)

### Medium
- `multi-region-cloud-trail-enabled` → NON_COMPLIANT

### Low
- `s3-bucket-public-read-prohibited` / `s3-bucket-public-write-prohibited` → NON_COMPLIANT  
  (może być false positive jeśli bucket jest celowo publiczny np. static website)

## Rollback / safety

Reguły są detect-only — zero wpływu na workloady.  
Żadnego rollbacku nie trzeba.

## Powiązane notatki

- [[progress-tracker]] — LLZ WAF checklist
- [[session-log]] — historia wdrożeń Config Phase 2/3
