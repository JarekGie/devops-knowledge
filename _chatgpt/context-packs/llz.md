# Kontekst dla LLM — LLZ (Light Landing Zone)

> Wklej na początku sesji dotyczącej LLZ. Standalone — nie wymaga dodatkowych plików.
> Aktualizuj po każdej sesji implementacyjnej.

---

**Projekt:** LLZ — Light Landing Zone (MakoLab platforma AWS)
**Zaktualizowano:** 2026-04-20
**Repozytoria:** `~/projekty/mako/aws-projects/aws-cloud-platform/` (Terraform IaC)

---

## Kim jestem

Senior DevOps/SRE, AWS-primary. Właściciel platformy AWS dla MakoLab — firmy IT świadczącej usługi cloud dla klientów zewnętrznych. Org multi-account (11 aktywnych kont). Vault wiedzy w Obsidian (Claude Code jako asystent). IaC: Terraform + CloudFormation.

---

## Czym jest LLZ

**Light Landing Zone** to wewnętrzny standard platformowy MakoLab. NIE jest to AWS Control Tower ani pełny Landing Zone — jest to minimalny zestaw standardów operacyjnych obejmujący:

| Wymiar | Narzędzie | Co audytuje |
|--------|-----------|-------------|
| **Scaffold conformance** | Terraform | struktura `envs/`, `backend.tf`, `versions.tf`, `project.yaml` |
| **Observability readiness** | AWS API | ECS logi, ALB access logs, VPC Flow Logs, CloudFront logging, ElastiCache |
| **Tagging governance** | CFN + Terraform | tagi `Project`/`Environment`/`ManagedBy`/`Owner`, AWS Tag Policies |

Narzędzie: `devops-toolkit` — CLI (`toolkit audit-pack llz-basic`, `toolkit audit-pack aws-logging`, `toolkit audit-pack tagging`).

---

## Struktura organizacji AWS

```
Org ID: o-5c4d5k6io1
Management: 864277686382 (makolab_dc) — profil AWS: mako-dc

Root
├── Platform OU
│   ├── Admin MakoLab        647075515164
│   └── monitoring-nagios-bot 814662658531  ← monitoring, health notifications
├── Security OU
│   └── LogArchiveNew        771354139056  ← CloudTrail logs
├── Sandbox OU
│   └── lab                  052845428574
└── Workloads OU
    ├── Production OU
    │   ├── planodkupow       333320664022
    │   ├── planodkupowv1     292464762806
    │   ├── Booking_Online    128264038676
    │   ├── RShop             943111679945
    │   ├── dacia-asystent    074412166613
    │   └── CC                943696080604  (konto INVITED — klient zewnętrzny)
    └── NonProduction OU
        └── DRP-TFS           613448424242
```

Terraform state: S3 `864277686382-terraform-state-bucket` + DynamoDB `terraform-state-lock` (eu-central-1).

---

## Co jest już wdrożone (Faza A — DONE)

### 1. Governance (IaC: `aws-cloud-platform/organization/governance/`)

- **SCP `llz-workloads-baseline`** → Workloads OU (Production + NonProduction dziedziczą)
  - Deny: wyłączenie CloudTrail, wyłączenie Config, zmiana S3 public access block
- **SCP `llz-quarantine-deny-all`** → Quarantine OU
- **Tag Policies** (zaktualizowane, dziedziczone z Root):
  - `klient`: booking, dacia-asystent, rshop, planodkupow, cc, makolab + legacy
  - `projekt`: booking, dacia-asystent, planodkupow, rshop, cc + legacy
  - `typ`: prod, dev, qa, uat, poc, test
  - `zespol`: legacy (wymaga aktualizacji po zebraniu obecnych teamów)

### 2. Centralna observability (IaC: `aws-cloud-platform/platform/monitoring/`)

- **CloudWatch OAM** — sink `observabilitySink` w monitoring-nagios-bot (814662658531)
- 4 konta podłączone jako sources: rshop, booking, planodkupow, dacia
- Sink policy: org-wide (`PrincipalOrgID`), metryki + logi + X-Ray
- CloudTrail org trail `org-baseline-cloudtrail` → S3 w LogArchiveNew ✅

### 3. AWS Health notifications (IaC: `aws-cloud-platform/platform/health-notifications/`)

- EventBridge rules (us-east-1) w każdym z 11 kont → bus `health-aggregation` (monitoring-nagios-bot)
- Lambda (Python 3.12, us-east-1) → SNS topic (eu-central-1) → email
- Filtr: tylko `statusCode=open` + `eventTypeCategory=issue|investigation`
- Kluczowa lekcja: cross-account EventBridge target zawsze wymaga `role_arn` w source account

### 4. Tagging standard (LLZ v1)

```
Wymagane: Project, Environment
Zalecane: ManagedBy, Owner
Enforce przez AWS Tag Policies (org Root)
```

Projekty CFN tagowane przez `toolkit apply-pack tagging`.

---

## Co jest w toku / planowane (Faza B)

| Epic | Co | Status |
|------|----|--------|
| EPIC 1 | Dokument OU owners + kontakty | Planowane |
| EPIC 3 | Security Account (oddzielne konto dla Security Hub, SIEM) | Planowane |
| EPIC 4 | GuardDuty org-wide | **Priorytet — HRI** |
| EPIC 5 | AWS Config org aggregator + reguły conformance | Planowane |
| EPIC 6 | SCP baseline (deny expensive, region restriction) | Planowane |

---

## WAF stan (aktualizacja 2026-04-20)

Overall: **~30% WAF-ready**.

| Pillar | Stan | Główne luki |
|--------|------|------------|
| Operational Excellence | ~40% | Brak SLO, brak CI/CD dla IaC, brak readiness checklist |
| Security | ~25% | GuardDuty wyłączony (HRI!), brak IR plan, brak SCP Faza B |
| Reliability | ~30% | Brak DR plan (konto DRP istnieje, plan nie), brak restore tests |
| Performance | ~40% | Brak right-sizing, brak load testing standard |
| Cost | ~20% | All On-Demand (brak Savings Plans), brak anomaly detection |
| Sustainability | ~40% | Brak Graviton, brak S3 lifecycle standard |

**High Risk Issues (HRI):**
1. GuardDuty wyłączony org-wide → zagrożenia niewykrywane
2. Brak SCP preventive controls → konta mogą wyłączyć security tooling
3. Brak formalnego DR plan (konto DRP-TFS istnieje ale bez dokumentacji RTO/RPO)
4. Brak IR plan → zero procedury na incydent bezpieczeństwa

**Quick wins:**
- Cost Anomaly Detection (30 min) — COST 3
- Savings Plans analiza (1h, ~20-30% savings) — COST 7
- GuardDuty org-wide (1-2 dni) — SEC 4 HRI

---

## Tagging governance — stan projektów

| Projekt | IaC | Tagging |
|---------|-----|---------|
| rshop | CloudFormation | dev 11/14, prod 12/13 compliant |
| planodkupow (bbmt) | CloudFormation | 104 zasoby zaudytowane, fix w toku po incydencie QA |
| Terraform projekty | Terraform | niezbadane — wymaga inwentaryzacji |

**Incydent planodkupow-qa (2026-04-18):**
- ROOT.yml update triggered VPCStack deadlock → `UPDATE_ROLLBACK_FAILED`
- RabbitMQ custom resource Lambda zwracał "account suspended" — blokował rollback
- Stan: QA niedostępne, wymaga decyzji A (AWS Support) lub B (delete+redeploy)

---

## Kluczowe decyzje architektoniczne

1. **Control Tower porzucony** → własny SCP przez Terraform IaC (aws-cloud-platform)
2. **Monitoring infra na monitoring-nagios-bot** (814662658531), nie na management account
3. **Health notifications: per-account EventBridge** (bez Business Support = bez org-wide Health view)
4. **Dokumentacja LLZ pod AWS review od razu** — nie przepisywać do WAF format później
5. **CC account (INVITED)** — konto klienta zewnętrznego w org, wyjaśnienie kontekstu otwarte

---

## Pytania otwarte / do rozstrzygnięcia

- [ ] CC account — co to jest dokładnie? (INVITED = klient zewnętrzny?)
- [ ] Admin MakoLab (647075515164) — jaką pełni rolę w Platform OU?
- [ ] `zespol` tag policy — jakie są obecne nazwy zespołów? (wymaga HR)
- [ ] rshop: zostać na CFN czy migrować do Terraform?
- [ ] DRP-TFS w NonProduction OU — czy nie powinno być w Platform?

---

## Profil AWS i uruchamianie

```bash
# Management account (Terraform state, Organizations API)
AWS_PROFILE=mako-dc terraform plan/apply

# Monitoring account (bezpośrednio)
aws ... --profile monitoring-tbd

# Inne konta przez assume_role z mako-dc (OrganizationAccountAccessRole)
```

**UWAGA:** awsume ustawia env vars które nadpisują `profile` w Terraform backend. Zawsze używaj `AWS_PROFILE=mako-dc terraform ...` (nie awsume przed terraform).

---

*Vault: `20-projects/internal/llz/` — session-log.md, context.md, org-inventory.md, waf-checklist.md, ideas.md*
