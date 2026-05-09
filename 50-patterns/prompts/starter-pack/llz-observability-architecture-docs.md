---
title: llz-observability-architecture-docs
type: prompt-template
domain: client-work
use_case: LLZ observability platform — generowanie dokumentacji architektury monitoringu (diagramy Mermaid, tabele, dokumentacja operacyjna)
tags:
  - prompt
  - llz
  - observability
  - architecture
  - mermaid
  - documentation
  - cloudwatch
  - oam
  - guardduty
  - glpi
  - wazuh
created: 2026-05-09
updated: 2026-05-09
---

# LLZ Observability Architecture Documentation

Jesteś senior Cloud Architect / SRE dokumentującym AWS observability platform dla LLZ.

Pracujesz w repo:

~/projekty/mako/aws-projects/aws-cloud-platform

Cel:
Na podstawie istniejącego audytu Observability & Alerting Audit — 2026-05-09 wygenerować komplet diagramów i dokumentacji architektury monitoringu.

Źródło prawdy:
- audyt observability z 2026-05-09
- aktualny Terraform
- aktualna architektura monitoring-nagios-bot
- istniejące SNS/EventBridge/OAM/Security Hub/GuardDuty flow

TRYB:
READ-ONLY
NIE wykonuj terraform apply
NIE zmieniaj infrastruktury
NIE generuj draw.io/xml/png
Generuj wyłącznie:
- Markdown
- Mermaid diagrams
- tabele
- architekturę logiczną

Wymagania:
- dokumentacja po polsku
- techniczna ale czytelna dla tech leadów i managementu
- diagramy mają być source-of-truth w Git
- Mermaid ma być poprawny składniowo
- nie używaj emoji
- nie generuj marketingowego bełkotu

Wygeneruj nowy dokument:

docs/architecture/observability-monitoring-architecture.md

Struktura dokumentu:

# 1. Executive Summary
Krótko:
- czym jest monitoring-nagios-bot
- po co istnieje central monitoring account
- jak działa GLPI integration
- jaka jest rola Wazuh
- jakie są główne źródła alertów

# 2. High-Level Architecture Diagram

Wygeneruj Mermaid diagram pokazujący:

- source accounts:
  - RShop
  - Booking
  - dacia
  - planodkupow
  - CC
  - planodkupowv1
- monitoring-nagios-bot
- OAM
- CloudWatch
- EventBridge
- SNS
- Lambda health-notify
- GLPI
- Wazuh (future phase)

Pokaż:
- cross-account observability
- health event flow
- SLO alert flow
- security findings flow
- CloudTrail → Wazuh flow

Diagram ma być prosty i czytelny.

# 3. Operational Architecture Diagram

Drugi diagram Mermaid — bardziej techniczny.

Pokaż:
- OAM sink
- OAM links
- EventBridge rules
- SNS topics:
  - slo-alerts
  - health-notifications
  - cloudwatch-alarms-glpi
- Lambda health-notify
- Security Hub delegated admin
- GuardDuty delegated admin
- Config aggregator
- CloudTrail org trail
- LogArchiveNew

Dodaj regiony:
- eu-central-1
- us-east-1

Pokaż:
- które flow są produkcyjne
- które są future phase

# 4. Alert Routing Matrix

Tabela:

| Source | Signal | Severity | Destination | Ticket in GLPI | SLA | Status |

Uwzględnij:
- SLO alerts
- AWS Health issue
- AWS Health scheduledChange
- GuardDuty HIGH
- Security Hub CRITICAL
- Config NON_COMPLIANT
- Cost anomaly
- ECS service down
- RDS alarms
- MQ alarms

Status:
- LIVE
- PLANNED
- DASHBOARD ONLY
- IGNORED

# 5. Monitoring Coverage Matrix

Tabela:

| Account | OAM | SLO | Security Hub | GuardDuty | Config | Health Events | Notes |

Uwzględnij:
- prod coverage
- gaps
- DRP-TFS
- lab
- management account
- LogArchiveNew

# 6. Alert Classification Model

Podziel alerty na:

## Tier 1 — auto-ticket
## Tier 2 — dashboard/review
## Tier 3 — ignore/noise

Dla każdego:
- przykłady
- routing
- uzasadnienie

# 7. Signal vs Noise Philosophy

Opisz:
- dlaczego NIE zbieramy wszystkiego
- dlaczego unikamy VPC Flow Logs everywhere
- dlaczego unikamy WAF logs
- dlaczego compliance findings nie trafiają do GLPI
- dlaczego SLO są ważniejsze niż pojedyncze metryki

To ma być praktyczny dokument operatorski, nie akademicki.

# 8. Cost-Safe Observability Principles

Uwzględnij:
- minimal viable observability
- cross-account metrics przez OAM
- ograniczanie retention
- unikanie duplicate ingest
- CloudTrail → S3 zamiast CW subscriptions
- kiedy observability zaczyna szkodzić kosztowo

# 9. Current Known Gaps

Na podstawie audytu.

Uwzględnij:
- backend blind spots
- ECS/RDS alarms missing
- security routing partial
- shadow sink cleanup
- GuardDuty delay
- dead SNS cleanup

# 10. Recommended Roadmap

Podziel:
- Quick wins
- Phase 2
- Future phase

Nie projektuj enterprise SOC.
Nie proponuj Splunka.
Nie proponuj DataDog.
Nie proponuj OpenSearch SIEM migration.

Architektura ma pozostać:
- lean
- AWS-native
- low-cost
- practical
- mały zespół operacyjny

Na końcu:
- sprawdź poprawność Mermaid
- sprawdź czy diagramy są renderowalne
- pokaż listę wygenerowanych sekcji
- pokaż path dokumentu
