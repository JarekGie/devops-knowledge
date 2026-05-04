---
title: NIS2 Infrastructure Audit — Live AWS CLI
type: prompt-template
domain: security-compliance
use_case: nis2-aws-technical-assessment
tags:
  - prompt
  - nis2
  - security
  - compliance
  - aws
  - live-audit
created: 2026-05-04
updated: 2026-05-04
---

# NIS2 Infrastructure Audit — AWS Technical Layer (Live CLI)

## Jak używać

Podaj do LLM jako instrukcję wykonawczą. Agent przeprowadza live discovery przez AWS CLI i generuje raport evidence-based.

Wymagane profile: `mako-dc` (management), `monitoring-tbd` (monitoring/delegated admin).

---

## Prompt

```
Zrób evidence-based audyt techniczny AWS pod NIS2, ale najpierw pobierz aktualny stan z AWS CLI.

Zasady:
- Nie używaj starych notatek jako source of truth.
- Nie zgaduj.
- Jeśli czegoś nie da się sprawdzić przez CLI, oznacz jako UNVERIFIED.
- Nie oceniaj procesów, dokumentacji ani polityk — tylko AWS infrastructure.
- Pracuj read-only.
- Nie wykonuj żadnych write operations.
- Nie zmieniaj zasobów.
- Wszystkie komendy AWS mają być read-only.

Profile:
- management account: mako-dc
- monitoring account: monitoring-tbd
- pozostałe konta wykryj przez AWS Organizations z profilu mako-dc

Najpierw wykonaj discovery kont:
aws organizations list-accounts --profile mako-dc

Dla każdego ACTIVE account sprawdź:

1. IAM/root:
   - aws iam get-account-summary
   - AccountMFAEnabled
   - AccountAccessKeysPresent

2. CloudTrail:
   - aws cloudtrail describe-trails --include-shadow-trails
   - aws cloudtrail get-trail-status
   - KMSKeyId
   - LogFileValidationEnabled
   - IsOrganizationTrail
   - IsMultiRegionTrail

3. GuardDuty:
   - aws guardduty list-detectors
   - aws guardduty get-detector
   - data sources / features

4. Security Hub:
   - aws securityhub describe-hub
   - aws securityhub get-enabled-standards
   - aws securityhub get-findings --filters RecordState=ACTIVE WorkflowStatus=NEW SeverityLabel=CRITICAL,HIGH

5. AWS Config:
   - aws configservice describe-configuration-recorders
   - aws configservice describe-configuration-recorder-status
   - aws configservice describe-aggregate-compliance-by-config-rules jeśli aggregator dostępny

6. Inspector:
   - aws inspector2 batch-get-account-status
   - aws inspector2 list-coverage

7. Logging:
   - VPC Flow Logs: aws ec2 describe-flow-logs
   - ALB access logs: aws elbv2 describe-load-balancers + describe-load-balancer-attributes
   - CloudFront logging: aws cloudfront list-distributions

8. Governance:
   - aws organizations list-policies --filter SERVICE_CONTROL_POLICY
   - aws organizations list-targets-for-policy
   - sprawdź czy llz-security-baseline jest podpięty do Platform OU, Security OU, Workloads OU, Sandbox OU

9. Backup / resilience:
   - aws backup list-backup-vaults
   - aws backup list-backup-plans
   - aws backup list-protected-resources

Wynik zapisz lokalnie jako:
nis2-aws-live-state-<YYYY-MM-DD>.md

Raport ma mieć sekcje:
- ACTIVE GAPS
- RESOLVED / NOT A GAP
- UNVERIFIED
- FALSE POSITIVES

W raporcie NIE wolno pisać, że coś jest MISSING, jeśli nie zostało sprawdzone live przez AWS CLI.
Jeśli Security Hub/Config pokazuje finding, ale live IAM pokazuje stan naprawiony, oznacz finding jako POSSIBLY STALE.
```
