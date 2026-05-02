---
type: checklist
updated: 2026-05-02
# last update: Budgets all 12 accounts + Cost Anomaly Detection planned, Organizations + FTR sections added
tags: [llz, waf, aws-well-architected, governance, compliance, ftr, organizations]
---

# LLZ — AWS Well-Architected Framework + FTR Checklist

> Checklista pod WAFR review z AWS SA oraz wymagania AWS Foundational Technical Review (FTR).
> Skupiona na wymiarze org-governance i platformy (LLZ scope).
> Status: ✅ done | ⚠️ partial | ❌ missing | ➖ N/A / poza scope LLZ

Ostatnia aktualizacja stanu: **2026-05-02**

---

## Pillar 1 — Operational Excellence (OPS)

| ID | Pytanie / Best Practice | Status | Uwagi |
|----|------------------------|--------|-------|
| OPS 1 | Zdefiniowane priorytety operacyjne (KPIs, SLO) | ❌ | Brak formalnych SLO dla platform |
| OPS 2 | Struktura zespołu wspiera business outcomes | ⚠️ | DC-devops jako owner platformy — nie udokumentowane formalnie |
| OPS 3 | Kultura organizacyjna wspiera operacje (runbooki, on-call) | ⚠️ | Runbooki tworzone ad-hoc, brak formalnego on-call |
| OPS 4 | Observability: logi, metryki, tracing, health events | ⚠️ | Health notifications **12/12 kont** ✅, Lambda DLQ + CW alarm ✅; OAM: **6/6 Workloads/Production kont live (2026-05-02)** ✅; SLO alarms **8 szt. live** (rshop/booking/dacia/planodkupow bbmt-uat, error rate + latency p99) ✅; brak centralnego dashboardu |
| OPS 5 | IaC, code review, CI/CD dla infrastruktury | ⚠️ | Terraform w repo, brak Atlantis/CI pipeline dla IaC |
| OPS 6 | Redukcja ryzyka deploymentu (blue/green, canary, rollback) | ⚠️ | ECS rolling update, brak formalnego runbooka rollback |
| OPS 7 | Readiness review przed produkcją (checklist, testy) | ❌ | Brak formalnego procesu |
| OPS 8 | Workload observability używana operacyjnie | ⚠️ | SLO alarms: rshop/booking/dacia/planodkupow(bbmt-uat) **live 2026-05-02** ✅ (8 alarmów, 4 workloady prod); planodkupowv1 NONPROD excluded; CC no ALB; dacia growing ($267/Apr); brak centralnej korelacji |
| OPS 9 | Health operacji monitorowany (dashboard ops) | ⚠️ | Health notifications 12/12 kont ✅, EventBridge DLQ z CW alarm (failures widoczne) ✅, brak ops dashboard |
| OPS 10 | Zarządzanie eventami operacyjnymi (incydenty, eskalacje) | ⚠️ | Runbooki incydentowe w vault, brak formalnego procesu eskalacji |
| OPS 11 | Ciągłe doskonalenie operacji (retrospektywy, postmortem) | ⚠️ | Postmortem planodkupow-qa ✅, niesystematyczne |

**Priorytety OPS:** OPS 5 (CI/CD dla IaC), OPS 7 (readiness checklist), OPS 1 (SLO)

---

## Pillar 2 — Security (SEC)

| ID | Pytanie / Best Practice | Status | Uwagi |
|----|------------------------|--------|-------|
| SEC 1 | Bezpieczna operacja: SCP, Config, CloudTrail aktywne | ⚠️ | CloudTrail ✅, Config ⚠️ (bez aggregatora), SCP ❌ (Faza B) |
| SEC 2 | Uwierzytelnianie: MFA, SSO, brak shared credentials | ⚠️ | MFA na IAM userach, brak SSO/IdP centralnego |
| SEC 3 | Zarządzanie uprawnieniami: least privilege, role per workload | ⚠️ | OrganizationAccountAccessRole używane zbyt szeroko |
| SEC 4 | Detekcja zagrożeń: GuardDuty, CloudTrail alerts | ❌ | GuardDuty wyłączony — **HIGH RISK** |
| SEC 5 | Ochrona sieci: VPC, SG, NACLs, VPC Flow Logs | ⚠️ | VPC Flow Logs nie wszędzie, brak centralizacji |
| SEC 6 | Ochrona compute: IMDSv2, no public SSH, patch mgmt | ⚠️ | Bez audytu — wymaga sprawdzenia |
| SEC 7 | Klasyfikacja danych (PII, confidential, public) | ❌ | Brak formalnej klasyfikacji |
| SEC 8 | Ochrona danych at rest: KMS, S3 encryption, RDS encryption | ⚠️ | S3/RDS encrypcja włączona na większości zasobów, brak audytu org-wide |
| SEC 9 | Ochrona danych in transit: TLS wszędzie, brak HTTP | ⚠️ | ALB HTTPS na prod, preprod HTTP tymczasowo |
| SEC 10 | Incident response plan: playbooki, izolacja, forensics | ❌ | Brak formalnego IR plan |
| SEC 11 | Application security: SAST, secret scanning, dependency scan | ❌ | Brak centralnego narzędzia |

**Priorytety SEC:** SEC 4 (GuardDuty — HRI!), SEC 1 (SCP — Faza B), SEC 3 (least privilege audit), SEC 10 (IR plan)

---

## Pillar 3 — Reliability (REL)

| ID | Pytanie / Best Practice | Status | Uwagi |
|----|------------------------|--------|-------|
| REL 1 | Service Quotas monitorowane, request limits znane | ❌ | Brak monitorowania limitów |
| REL 2 | Network topology: multi-AZ, private subnets, redundancja | ⚠️ | Multi-AZ na większości projektów, brak standardu |
| REL 3 | Service architecture: loose coupling, bounded contexts | ⚠️ | Różne podejścia per projekt |
| REL 4 | Fail-safe interactions: retry, timeout, circuit breaker | ⚠️ | Aplikacyjnie — bez audytu |
| REL 5 | Failure mitigation: throttling, load shedding | ⚠️ | ALB + ECS auto-scaling, brak formalnego testu |
| REL 6 | Monitoring zasobów workloadu (CloudWatch alarms) | ⚠️ | Alarms na projektach, brak standardu minimalnego |
| REL 7 | Auto-scaling: reaguje na demand (ECS, ASG) | ⚠️ | ECS auto-scaling wdrożone na projektach prod |
| REL 8 | Change management: deploy z automatycznym rollback | ⚠️ | ECS rolling update, brak blue/green |
| REL 9 | Backup danych: RDS snapshots, S3 versioning, testy restore | ⚠️ | RDS snapshots włączone, testy restore nie dokumentowane |
| REL 10 | Fault isolation: AZ isolation, bulkhead pattern | ⚠️ | Multi-AZ subnety, brak formalnego testu |
| REL 11 | Workload znosi błędy komponentów (health checks, replacement) | ⚠️ | ECS health checks ✅, brak chaos testing |
| REL 12 | Testy reliability: game day, chaos engineering | ❌ | Brak |
| REL 13 | Disaster Recovery plan: RTO/RPO zdefiniowane i testowane | ❌ | DRP account istnieje (613448424242), brak formalnego planu |

**Priorytety REL:** REL 13 (DR plan — konto DRP istnieje ale plan nie), REL 9 (dokumentacja restore tests), REL 12 (chociaż basic game day)

---

## Pillar 4 — Performance Efficiency (PERF)

| ID | Pytanie / Best Practice | Status | Uwagi |
|----|------------------------|--------|-------|
| PERF 1 | Dobór architektury do wymagań (serverless vs. EC2 vs. containers) | ⚠️ | ECS Fargate jako standard ✅, decyzje per projekt |
| PERF 2 | Dobór i optymalizacja compute (right-sizing, Graviton) | ⚠️ | Brak procesu right-sizing, bez Graviton |
| PERF 3 | Storage i dostęp do danych (tiering, caching, CDN) | ⚠️ | ElastiCache na wybranych projektach, CloudFront opcjonalnie |
| PERF 4 | Networking: latencja, CDN, VPC endpoints | ⚠️ | VPC endpoints częściowo, CloudFront opcjonalnie |
| PERF 5 | Procesy org wspierają performance (benchmarking, load testing) | ❌ | Brak standardu load testów |

**Priorytety PERF:** PERF 2 (right-sizing — FinOps), PERF 5 (load testing standard)

---

## Pillar 5 — Cost Optimization (COST)

| ID | Pytanie / Best Practice | Status | Uwagi |
|----|------------------------|--------|-------|
| COST 1 | Cloud Financial Management: tagging, budgets, alerty | ✅ | Tagging LLZ ✅; CW log retention FIXED 2026-05-02 ✅; **Budgets: plan gotowy 2026-05-02** — 21 importowanych + 7 nowych (wszystkie 12 kont pokryte), alerty email na planodkupow+Booking (były BRAK), DRP-TFS thresholds obniżone 150→80%; FinOps proces: brak |
| COST 2 | Governance użycia: SCP deny expensive services, quota limits | ❌ | Brak SCP cost-related |
| COST 3 | Monitorowanie kosztów: Cost Explorer, anomaly detection | ⚠️ | **Cost Anomaly Detection: plan gotowy 2026-05-02** — org-level DIMENSIONAL/SERVICE, threshold $50+20%, SNS us-east-1; needs apply |
| COST 4 | Decommission nieużywanych zasobów | ⚠️ | Konta legacy zidentyfikowane (Faza A), brak procesu cleanup |
| COST 5 | Selekcja serwisów z myślą o koszcie | ⚠️ | Ad-hoc, brak formalnego procesu |
| COST 6 | Right-sizing instancji i usług | ❌ | Brak systematycznego audytu |
| COST 7 | Pricing models: Reserved, Savings Plans, Spot | ❌ | Wszystko On-Demand |
| COST 8 | Planowanie transfer costs (inter-AZ, egress) | ❌ | Brak analizy |
| COST 9 | Auto-scaling dopasowany do demand (nie over-provision) | ⚠️ | ECS auto-scaling, brak testu efektywności |
| COST 10 | Regularna evaluacja nowych serwisów pod kątem kosztów | ❌ | Ad-hoc |
| COST 11 | Koszt wysiłku operacyjnego w decyzjach build vs. buy | ⚠️ | Uwzględniany nieformalnie |

**Priorytety COST:** COST 7 (Savings Plans — quick win), COST 6 (right-sizing), COST 2 (SCP cost guardrails)

---

## Pillar 6 — Sustainability (SUS)

| ID | Pytanie / Best Practice | Status | Uwagi |
|----|------------------------|--------|-------|
| SUS 1 | Selekcja regionów z myślą o carbon footprint | ➖ | Regiony wybierane biznesowo (eu-west-1, eu-central-1) |
| SUS 2 | Zasoby cloud dopasowane do popytu (auto-scaling, idle removal) | ⚠️ | Auto-scaling ✅, dev/qa scheduler planowany w LLZ |
| SUS 3 | Wzorce architektoniczne wspierające sustainability (serverless, managed) | ⚠️ | ECS Fargate (managed) ✅, Lambda ✅ |
| SUS 4 | Data management policies (lifecycle, tiering, TTL) | ⚠️ | S3 lifecycle częściowo, brak standardu; CloudTrail S3 bucket bez lifecycle — remediation Terraform gotowe; CW log groups: retencja ustawiona org-wide 2026-05-02 ✅ (58 grup naprawionych); skrypt `fix-log-retention.sh` w aws-cloud-platform/scripts/ |
| SUS 5 | Hardware i serwisy efektywne energetycznie (Graviton, managed DB) | ⚠️ | RDS managed ✅, bez Graviton |
| SUS 6 | Procesy org redukujące environmental impact | ❌ | Brak formalnych celów |

**Priorytety SUS:** SUS 2 (scheduler — już w LLZ roadmapie), SUS 4 (S3 lifecycle policy standard)

---

## Pillar 7 — Organizations Governance (multi-account)

> Specyficzne dla AWS Organizations — obejmuje wymagania WAF Security Pillar (Account Management) + AWS SRA (Security Reference Architecture). Nie pokryte w standardowych 6 pillarach.

| ID | Best Practice | Status | Uwagi |
|----|--------------|--------|-------|
| ORG 1 | Accounts w OUs, NIE bezpośrednio w Root | ❌ | Wszystkie konta w Root — EPIC 1 priorytet; Root = brak SCP guardrails |
| ORG 2 | OU hierarchia odpowiada typom workloadów (Prod/NonProd/Platform/Security) | ❌ | Brak OU struktury — EPIC 1 |
| ORG 3 | Dedicated Security account (delegated admin) | ❌ | EPIC 3 — GuardDuty/Config/SecurityHub admin |
| ORG 4 | Root account: MFA włączone, brak access keys, zadana alternatywna metoda kontaktu | ⚠️ | Nieaudytowane — sprawdzić manualnie |
| ORG 5 | CloudTrail: org-level, multi-region, global services, validation enabled, KMS | ⚠️ | Org CloudTrail aktywny ✅; KMS encryption ❌; log file validation ⚠️ (nieznane); EPIC 2 |
| ORG 6 | Log Archive: S3 + KMS + lifecycle + block public access + MFA delete | ⚠️ | LogArchiveNew account ✅, S3 bucket ✅; KMS ❌; lifecycle ❌; EPIC 2 |
| ORG 7 | Account contact info per account (billing, security, operations) | ❌ | Nieaudytowane — wymagane przez FTR |
| ORG 8 | IAM Identity Center (SSO) zamiast indywidualnych IAM userów | ❌ | Aktualnie: IAM users z MFA — zwiększa surface attack |
| ORG 9 | Break-glass procedure (kto/jak/kiedy dostaje emergency access) | ❌ | Brak udokumentowanej procedury |
| ORG 10 | Tag Policies enforcement org-wide | ✅ | llz-project + llz-environment policies aktywne na Root ✅ |
| ORG 11 | GuardDuty: org-level, auto-enable nowych kont, delegated admin | ❌ | **HRI** — EPIC 4; ani jedno konto nie ma GuardDuty |
| ORG 12 | AWS Config: org-level recorders + aggregator + minimalne reguły | ❌ | EPIC 5 |
| ORG 13 | Security Hub: org-level, delegated admin, standardy (CIS, FSBP) | ❌ | EPIC 3/5 — wymagane dla FTR |
| ORG 14 | S3 Block Public Access na poziomie account (nie tylko bucket) | ⚠️ | Nieaudytowane org-wide — sprawdzić per account |
| ORG 15 | IMDSv2 enforcement (EC2, jeśli używane) | ⚠️ | ECS Fargate nie dotyczy ✅; EC2 w DRP-TFS — nieaudytowane |
| ORG 16 | SCP: deny root actions, deny disable security services, deny non-eu regions | ❌ | EPIC 6 — **HRI** |
| ORG 17 | Savings Plans lub Reserved Instances dla stabilnych workloadów | ❌ | All On-Demand; rshop/booking/planodkupow = stabilny $1100-1400/month |
| ORG 18 | AWS Trusted Advisor notifications (Business/Enterprise support) | ⚠️ | Support tier nieznany; TA checks dostępne na Basic |
| ORG 19 | Centralne zarządzanie kluczami KMS (org-wide key policy) | ❌ | Keys per account, brak org-level key governance |
| ORG 20 | VPC Flow Logs → centralna archiwizacja lub analiza | ❌ | Flow logs nie wszędzie, brak centralizacji |

**Priorytety ORG:** ORG 11 (GuardDuty — HRI), ORG 16 (SCP — HRI), ORG 1 (OU struktura), ORG 3 (Security account), ORG 5/6 (CloudTrail/LogArchive hardening)

---

## Pillar 8 — FTR Partner Readiness

> AWS Foundational Technical Review — wymagania do walidacji "partner-ready". FTR ważny 3 lata od zatwierdzenia. Alternatywa: AWS Well-Architected Review (WAFR) może zastąpić FTR.

| ID | Wymaganie FTR | Status | Uwagi |
|----|--------------|--------|-------|
| FTR 1 | CloudTrail multi-region enabled ze wszystkimi kontami org | ⚠️ | Org CloudTrail ✅; multi-region config nieaudytowana |
| FTR 2 | Centralized S3 log bucket z access controls | ⚠️ | LogArchiveNew ✅; strict access + block public access nieaudytowane |
| FTR 3 | GuardDuty enabled org-wide | ❌ | **HRI — blokuje FTR** |
| FTR 4 | AWS Config + reguły conformance | ❌ | Blokuje FTR |
| FTR 5 | Security Hub lub CIS Benchmark report | ❌ | Blokuje FTR |
| FTR 6 | Root MFA na każdym koncie | ⚠️ | Nieaudytowane — sprawdź przed FTR |
| FTR 7 | Brak hardcoded credentials w kodzie/repo | ⚠️ | Brak centralnego secret scanningu |
| FTR 8 | Workload isolation — oddzielne konta per projekt | ✅ | Każdy projekt w oddzielnym koncie ✅ |
| FTR 9 | Incident response playbooks | ❌ | Brak formalnych IR playbooks |
| FTR 10 | Backup + restore tested + documented | ⚠️ | RDS snapshots ✅; testy restore nieudokumentowane |
| FTR 11 | Architecture diagrams + case studies (submission artifacts) | ⚠️ | Częściowe; brak formalnych diagramów per workload |
| FTR 12 | Budgets + Cost Anomaly Detection | ⚠️ | **Budgets plan 2026-05-02 ✅; Anomaly Detection plan 2026-05-02 ✅** — needs apply |
| FTR 13 | Szyfrowanie danych at rest (S3, RDS, EBS) | ⚠️ | Włączone na prod, brak audytu org-wide |
| FTR 14 | Szyfrowanie in transit (TLS, no HTTP) | ⚠️ | ALB HTTPS prod ✅; preprod częściowo |
| FTR 15 | S3 Block Public Access enabled | ⚠️ | Nieaudytowane org-wide |

**FTR blockers (krytyczne dla partner readiness):** FTR 3 (GuardDuty), FTR 4 (Config), FTR 5 (Security Hub), FTR 6 (Root MFA audit)

**Szacowany czas do FTR readiness:** 3-4 tygodnie po wykonaniu Faza B EPIC 3+4+5

---

## Podsumowanie — stan LLZ vs. WAF

| Pillar | ✅ Done | ⚠️ Partial | ❌ Missing | Ocena |
|--------|---------|-----------|-----------|-------|
| Operational Excellence | 0 | 8 | 3 | ~40% |
| Security | 0 | 5 | 6 | ~25% |
| Reliability | 0 | 7 | 6 | ~30% |
| Performance Efficiency | 0 | 4 | 1 | ~40% |
| Cost Optimization | 0 | 4 | 7 | ~20% |
| Sustainability | 0 | 4 | 2 | ~40% |

**Overall: ~30% WAF-ready**

---

## High Risk Issues (HRI) — do rozwiązania priorytetowo

1. **SEC 4** — GuardDuty wyłączony org-wide → zagrożenia niewykrywane
2. **SEC 1** — Brak SCP (preventive controls) → każde konto może wyłączyć security tooling
3. **REL 13** — Brak formalnego DR plan mimo istnienia konta DRP
4. **SEC 10** — Brak IR plan → brak procedury na incydent bezpieczeństwa

---

## Szybkie wygrane (quick wins)

1. **Włączyć GuardDuty org-wide** — Faza B, 1-2 dni, eliminuje HRI
2. **AWS Cost Anomaly Detection** — 30 minut konfiguracji, alert na anomalie kosztowe
3. **Savings Plans** — analiza 1h, redukcja kosztów ~20-30% na stałym ruchu
4. **Config Aggregator** — Faza B, widoczność compliance org-wide
5. **SCP baseline (4 deny policies)** — Faza B, eliminuje HRI SEC 1

---

## Powiązania z LLZ Faza B

| Faza B Epic | WAF checks które adresuje |
|-------------|--------------------------|
| EPIC 3 — Security Account | SEC 1, SEC 4, REL 10 |
| EPIC 4 — GuardDuty org | SEC 4 (HRI) |
| EPIC 5 — Config + Aggregator | SEC 1, OPS 4, REL 6 |
| EPIC 6 — SCP baseline | SEC 1 (HRI), COST 2 |
| EPIC 1 — OU + owners | OPS 2, SEC 3 |
