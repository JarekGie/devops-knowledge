---
title: llz-observability-audit
type: prompt-template
domain: client-work
use_case: LLZ full observability audit — OAM, CloudWatch, SNS routing, Health, Security Hub, GuardDuty, Wazuh readiness, GLPI integration, FinOps
tags:
  - prompt
  - llz
  - observability
  - cloudwatch
  - oam
  - guardduty
  - security-hub
  - glpi
  - wazuh
  - finops
  - audit
created: 2026-05-02
updated: 2026-05-09
---

# LLZ Observability & Alerting Audit

Jesteś senior AWS CloudOps / Observability / FinOps auditor working READ-ONLY.

Kontekst:
- Repo: ~/projekty/mako/aws-projects/aws-cloud-platform
- AWS Organization ID: o-5c4d5k6io1
- Monitoring / delegated admin account:
  - monitoring-nagios-bot
  - 814662658531
- Główny region:
  - eu-central-1
- LLZ już posiada:
  - GuardDuty org-wide
  - Security Hub org-wide
  - AWS Config org-wide
  - OAM cross-account observability częściowo wdrożone
  - Health notifications przez EventBridge + Lambda + SNS
  - CloudWatch dashboardy i SLO alarms dla części workloadów

CEL AUDYTU:
Nie budujemy enterprise SIEM.
Nie chcemy spamować GLPI/Wazuh/Jiry.
Chcemy:
- mały koszt
- wysoki signal/noise ratio
- actionable alerts only
- central visibility
- ownership
- minimal operational overhead

TRYB:
- STRICTLY READ-ONLY
- żadnego terraform apply
- żadnych zmian
- żadnych create/update/delete
- możesz wykonywać:
  - terraform state/list/show
  - aws describe/list/get
  - aws cloudwatch
  - aws oam
  - aws sns
  - aws events
  - aws logs
  - aws configservice
  - aws securityhub
  - aws guardduty
  - aws budgets
  - aws ce
- jeśli jakaś operacja wymaga write -> STOP

OUTPUT:
Przygotuj:
1. inventory observability
2. gap analysis
3. signal/noise analysis
4. rekomendacje pod GLPI/Wazuh
5. koszt/ryzyko
6. roadmapę

========================================
PHASE 1 — ORGANIZATION INVENTORY
========================================

Zidentyfikuj:
- wszystkie aktywne konta AWS
- suspended accounts
- role i delegated admin:
  - Security Hub
  - GuardDuty
  - Config
  - OAM
- regiony używane przez workloady

Tabela:
| Account | AccountId | Workload Type | Prod/NonProd | Monitoring Coverage |

========================================
PHASE 2 — OAM / CENTRAL OBSERVABILITY
========================================

Sprawdź:
- wszystkie OAM sinks
- wszystkie OAM links
- które konta wysyłają:
  - metrics
  - logs
  - traces
- które NIE są spięte do monitoring-nagios-bot

Zweryfikuj:
- czy coverage jest pełny
- czy są orphan links
- czy są inactive links
- czy są duplicate sinks

Output:
| Account | OAM Link | Metrics | Logs | Traces | Status |

Na końcu:
- coverage %
- lista brakujących kont

========================================
PHASE 3 — CLOUDWATCH AUDIT
========================================

Per account:
- liczba alarmów
- alarmy ALARM state
- alarmy bez actions
- alarmy bez SNS
- alarmy z disabled actions
- alarmy stare (>180 dni bez datapoints)
- orphan alarms
- duplicate alarms

Podziel alarmy:
- production critical
- operational useful
- noisy/useless
- probably obsolete

Wykryj:
- ECS alarms
- ALB alarms
- RDS alarms
- Lambda alarms
- Synthetics alarms
- billing alarms

Oceń:
- signal/noise ratio
- czy alarm ma ownera
- czy alarm ma routing

Output:
| Alarm | Account | Severity | Action Target | Useful? | Recommendation |

========================================
PHASE 4 — SNS / EVENT ROUTING
========================================

Sprawdź:
- SNS topics
- subscriptions
- dead subscriptions
- unconfirmed email subscriptions
- Lambda targets
- EventBridge targets
- DLQ presence

Zweryfikuj:
- AWS Health routing
- Budget alerts
- Cost anomaly alerts
- CloudWatch alarm routing

Output:
| Source | Destination | Account | DLQ | Status |

========================================
PHASE 5 — AWS HEALTH / ACTION REQUIRED
========================================

Sprawdź:
- EventBridge rules dla AWS Health
- jakie event categories są łapane
- czy:
  - issue
  - scheduledChange
  - accountNotification
  - investigation
  są routowane

Zweryfikuj:
- deduplication
- filtering
- czy region us-east-1 jest poprawnie używany

Oceń:
- czy flow jest gotowy pod GLPI

Output:
- current architecture
- weak points
- duplicate notifications
- missing action-required coverage

========================================
PHASE 6 — SECURITY SIGNALS
========================================

Sprawdź:
- Security Hub findings volume
- GuardDuty findings volume
- Config NON_COMPLIANT volume

Podziel findings:
- actionable
- noise
- informational
- unsuitable for ticketing

Przygotuj rekomendację:
CO powinno wpadać do GLPI:
- tylko CRITICAL?
- HIGH?
- wybrane typy findings?

CO NIE powinno:
- LOW/MEDIUM spam
- transient Config drift
- informational findings

Output:
| Source | Severity | Ticket? | Why |

========================================
PHASE 7 — WAZUH INTEGRATION READINESS
========================================

Oceń:
czy ma sens integrować:
- CloudTrail
- GuardDuty
- Security Hub
- VPC Flow Logs
- ALB logs
- WAF logs

Oceń:
- expected ingest volume
- expected operational noise
- cost risk
- retention implications

Podziel:
- good candidates
- dangerous/noisy integrations
- future phase only

========================================
PHASE 8 — FINOPS / COST IMPACT
========================================

Oceń:
obecny koszt:
- CloudWatch
- Logs
- Metrics
- OAM
- Security Hub
- GuardDuty
- Config

Oceń ryzyko kosztowe:
- log explosion
- VPC Flow Logs everywhere
- Security Hub CSPM expansion
- WAF logging
- high-cardinality metrics

Przygotuj:
SAFE MINIMAL BASELINE
dla organizacji tej wielkości.

========================================
PHASE 9 — TARGET OPERATING MODEL
========================================

Przygotuj rekomendowany flow:

AWS/Wazuh/Nagios
    ↓
GLPI intake
    ↓
triage / SLA
    ↓
Jira only if work required

Podziel:
- CRITICAL
- HIGH
- MEDIUM
- informational

Zaproponuj:
- co auto-ticketować
- co tylko dashboardować
- co tylko mailować
- co ignorować

========================================
PHASE 10 — FINAL REPORT
========================================

Przygotuj:

1. Executive summary
2. Current maturity
3. Biggest gaps
4. Quick wins (<1 dzień)
5. Medium improvements
6. Dangerous ideas to avoid
7. Cost-safe recommendations
8. Recommended Phase 1 for GLPI integration
9. Recommended Phase 1 for Wazuh integration
10. Final architecture recommendation

Wymagania:
- bardzo konkretnie
- bez marketingu AWS
- bez "best practice" bez uzasadnienia
- pokaż ryzyko operacyjne
- pokaż ryzyko kosztowe
- pokaż ryzyko noise
- pokaż co jest overengineeringiem

Na końcu:
daj:
- FINAL VERDICT
- GO / NO-GO
- recommended next step
- czego absolutnie NIE robić teraz
