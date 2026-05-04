---
type: checklist
updated: 2026-05-04
# last update: AWS Config org-wide ✅, Security Hub 11/11 enrolled ✅, CloudTrail audit confirmed ✅
tags: [llz, waf, aws-well-architected, governance, compliance, ftr, organizations]
---

# LLZ — AWS Well-Architected Framework + FTR Checklist

> Checklista pod WAFR review z AWS SA oraz wymagania AWS Foundational Technical Review (FTR).
> Skupiona na wymiarze org-governance i platformy (LLZ scope).
> Status: ✅ done | ⚠️ partial | ❌ missing | ➖ N/A / poza scope LLZ

Ostatnia aktualizacja stanu: **2026-05-04**

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
| SEC 1 | Bezpieczna operacja: SCP, Config, CloudTrail aktywne | ✅ | CloudTrail ✅ (org, multi-region, logging active); **Config ✅ DEPLOYED 2026-05-02** (OrgConfigRules+aggregator+StackSet, 11/12 kont — brak management account recordera); **SCP ✅ DEPLOYED 2026-05-02** (Sandbox+NonProd+Prod OUs) |
| SEC 2 | Uwierzytelnianie: MFA, SSO, brak shared credentials | ⚠️ | MFA na IAM userach, brak SSO/IdP centralnego |
| SEC 3 | Zarządzanie uprawnieniami: least privilege, role per workload | ⚠️ | OrganizationAccountAccessRole używane zbyt szeroko |
| SEC 4 | Detekcja zagrożeń: GuardDuty, CloudTrail alerts | ✅ | **GuardDuty DEPLOYED 2026-05-02 ✅** — org-wide, delegated admin (monitoring), 12/12 kont, CLOUD_TRAIL+DNS+FLOW_LOGS baseline |
| SEC 5 | Ochrona sieci: VPC, SG, NACLs, VPC Flow Logs | ⚠️ | VPC Flow Logs nie wszędzie, brak centralizacji |
| SEC 6 | Ochrona compute: IMDSv2, no public SSH, patch mgmt | ⚠️ | Bez audytu — wymaga sprawdzenia |
| SEC 7 | Klasyfikacja danych (PII, confidential, public) | ❌ | Brak formalnej klasyfikacji |
| SEC 8 | Ochrona danych at rest: KMS, S3 encryption, RDS encryption | ⚠️ | S3/RDS encrypcja włączona na większości zasobów, brak audytu org-wide |
| SEC 9 | Ochrona danych in transit: TLS wszędzie, brak HTTP | ⚠️ | ALB HTTPS na prod, preprod HTTP tymczasowo |
| SEC 10 | Incident response plan: playbooki, izolacja, forensics | ❌ | Brak formalnego IR plan |
| SEC 11 | Application security: SAST, secret scanning, dependency scan | ❌ | Brak centralnego narzędzia |

**Priorytety SEC:** SEC 2 (root MFA brak w monitoring account — CRITICAL), SEC 3 (least privilege audit), SEC 10 (IR plan)

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
| COST 1 | Cloud Financial Management: tagging, budgets, alerty | ✅ | Tagging LLZ ✅; CW log retention FIXED 2026-05-02 ✅; **Budgets: APPLIED 2026-05-02 ✅** — 21 importowanych + 7 nowych (wszystkie 12 kont), alerty email na planodkupow+Booking, DRP-TFS thresholds 150→80%; legacy budget 950 USD usunięty; FinOps proces: brak |
| COST 2 | Governance użycia: SCP deny expensive services, quota limits | ❌ | Brak SCP cost-related |
| COST 3 | Monitorowanie kosztów: Cost Explorer, anomaly detection | ✅ | **Cost Anomaly Detection: APPLIED 2026-05-02 ✅** — org-level DIMENSIONAL/SERVICE, IMMEDIATE, threshold $50+20%, SNS us-east-1, email subskrypcja potwierdzona |
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
| ORG 4 | Root account: MFA włączone, brak access keys, zadana alternatywna metoda kontaktu | ❌ | **AUDIT 2026-05-04:** monitoring account `814662658531` — root bez MFA (CRITICAL, Security Hub 1.13); Admin MakoLab `647075515164` — root access keys aktywne (Config NON_COMPLIANT); pozostałe konta nieaudytowane |
| ORG 5 | CloudTrail: org-level, multi-region, global services, validation enabled, KMS | ⚠️ | **AUDIT 2026-05-04:** org trail ✅, multi-region ✅, logging ✅ (delivery 2026-05-04); KMS encryption ❌; log file validation nieaudytowana |
| ORG 6 | Log Archive: S3 + KMS + lifecycle + block public access + MFA delete | ⚠️ | LogArchiveNew account ✅, S3 bucket ✅; KMS ❌; lifecycle ❌; EPIC 2 |
| ORG 7 | Account contact info per account (billing, security, operations) | ❌ | Nieaudytowane — wymagane przez FTR |
| ORG 8 | IAM Identity Center (SSO) zamiast indywidualnych IAM userów | ❌ | Aktualnie: IAM users z MFA — zwiększa surface attack |
| ORG 9 | Break-glass procedure (kto/jak/kiedy dostaje emergency access) | ❌ | Brak udokumentowanej procedury |
| ORG 10 | Tag Policies enforcement org-wide | ✅ | llz-project + llz-environment policies aktywne na Root ✅ |
| ORG 11 | GuardDuty: org-level, auto-enable nowych kont, delegated admin | ✅ | **GuardDuty DEPLOYED 2026-05-02 ✅** — delegated admin: monitoring-nagios-bot, auto_enable=ALL, 12/12 kont enrolled |
| ORG 12 | AWS Config: org-level recorders + aggregator + minimalne reguły | ✅ | **DEPLOYED 2026-05-02 ✅** — OrgConfigRules (5 baseline), aggregator `org-aggregator`, StackSet `aws-config-org-recorder` CURRENT 11/12 kont; management account bez recordera (⚠️ gap); 4/5 reguł 100% COMPLIANT, 1 NON_COMPLIANT (root access keys Admin MakoLab) |
| ORG 13 | Security Hub: org-level, delegated admin, standardy (CIS, FSBP) | ✅ | **DEPLOYED + ENROLLED 2026-05-04 ✅** — delegated admin: monitoring-nagios-bot (814662658531), **11/11 members Enrolled**; AutoEnableStandards=NONE (brak duplikatów); 6 CRITICAL + 14 HIGH findings (monitoring account) |
| ORG 14 | S3 Block Public Access na poziomie account (nie tylko bucket) | ⚠️ | Nieaudytowane org-wide — sprawdzić per account |
| ORG 15 | IMDSv2 enforcement (EC2, jeśli używane) | ⚠️ | ECS Fargate nie dotyczy ✅; EC2 w DRP-TFS — nieaudytowane |
| ORG 16 | SCP: deny root actions, deny disable security services, deny non-eu regions | ✅ | **SCP security-baseline DEPLOYED 2026-05-02 ✅** — DenyDisableSecurityServices + DenyRootUserActions live na Sandbox+NonProd+Prod OUs; region restrictions ❌ (future phase) |
| ORG 17 | Savings Plans lub Reserved Instances dla stabilnych workloadów | ❌ | All On-Demand; rshop/booking/planodkupow = stabilny $1100-1400/month |
| ORG 18 | AWS Trusted Advisor notifications (Business/Enterprise support) | ⚠️ | Support tier nieznany; TA checks dostępne na Basic |
| ORG 19 | Centralne zarządzanie kluczami KMS (org-wide key policy) | ❌ | Keys per account, brak org-level key governance |
| ORG 20 | VPC Flow Logs → centralna archiwizacja lub analiza | ❌ | Flow logs nie wszędzie, brak centralizacji |

**Priorytety ORG:** ORG 4 (root MFA + access keys — CRITICAL, blokuje FTR), ORG 8 (IAM Identity Center), ORG 5 (CloudTrail KMS), ORG 6 (LogArchive hardening)

---

## Pillar 8 — FTR Partner Readiness

> AWS Foundational Technical Review — wymagania do walidacji "partner-ready". FTR ważny 3 lata od zatwierdzenia. Alternatywa: AWS Well-Architected Review (WAFR) może zastąpić FTR.

| ID | Wymaganie FTR | Status | Uwagi |
|----|--------------|--------|-------|
| FTR 1 | CloudTrail multi-region enabled ze wszystkimi kontami org | ✅ | **AUDIT 2026-05-04:** org trail ✅, multi-region ✅, org-wide ✅, logging aktywny ✅ (delivery 2026-05-04); KMS ❌ — pozostaje do hardening |
| FTR 2 | Centralized S3 log bucket z access controls | ⚠️ | LogArchiveNew ✅; strict access + block public access nieaudytowane |
| FTR 3 | GuardDuty enabled org-wide | ✅ | **DEPLOYED 2026-05-02 ✅** — org-wide, 12/12 kont, delegated admin, auto-enable ALL |
| FTR 4 | AWS Config + reguły conformance | ✅ | **DEPLOYED 2026-05-02 ✅** — OrgConfigRules (5 baseline) aktywne, aggregator działa, 11/12 kont ocenianych |
| FTR 5 | Security Hub lub CIS Benchmark report | ✅ | **DEPLOYED + ENROLLED 2026-05-04 ✅** — 11/11 kont, findings flow po initial sync |
| FTR 6 | Root MFA na każdym koncie | ❌ | **AUDIT 2026-05-04:** monitoring account root bez MFA (Security Hub CRITICAL); Admin MakoLab root access keys aktywne; pozostałe konta nieaudytowane — **bloker FTR** |
| FTR 7 | Brak hardcoded credentials w kodzie/repo | ⚠️ | Brak centralnego secret scanningu |
| FTR 8 | Workload isolation — oddzielne konta per projekt | ✅ | Każdy projekt w oddzielnym koncie ✅ |
| FTR 9 | Incident response playbooks | ❌ | Brak formalnych IR playbooks |
| FTR 10 | Backup + restore tested + documented | ⚠️ | RDS snapshots ✅; testy restore nieudokumentowane |
| FTR 11 | Architecture diagrams + case studies (submission artifacts) | ⚠️ | Częściowe; brak formalnych diagramów per workload |
| FTR 12 | Budgets + Cost Anomaly Detection | ✅ | **Budgets APPLIED 2026-05-02 ✅; Anomaly Detection APPLIED 2026-05-02 ✅** — wszystkie 12 kont pokryte |
| FTR 13 | Szyfrowanie danych at rest (S3, RDS, EBS) | ⚠️ | Włączone na prod, brak audytu org-wide |
| FTR 14 | Szyfrowanie in transit (TLS, no HTTP) | ⚠️ | ALB HTTPS prod ✅; preprod częściowo |
| FTR 15 | S3 Block Public Access enabled | ⚠️ | Nieaudytowane org-wide |

**FTR blockers (krytyczne dla partner readiness):** ~~FTR 3 (GuardDuty)~~ ✅, ~~FTR 4 (Config)~~ ✅, ~~FTR 5 (Security Hub)~~ ✅, **FTR 6 (Root MFA — ACTIVE BLOCKER)**

**Szacowany czas do FTR readiness:** 1-2 dni (root MFA + access keys = ręczna praca) + audyt pozostałych kont

---

## Podsumowanie — stan LLZ vs. WAF

| Pillar | ✅ Done | ⚠️ Partial | ❌ Missing | Ocena |
|--------|---------|-----------|-----------|-------|
| Operational Excellence | 0 | 8 | 3 | ~40% |
| Security | **3** | **3** | **5** | **~45%** ↑ |
| Reliability | 0 | 7 | 6 | ~30% |
| Performance Efficiency | 0 | 4 | 1 | ~40% |
| Cost Optimization | **2** | **4** | **5** | **~40%** |
| Sustainability | 0 | 4 | 2 | ~40% |
| Organizations Governance | **6** | **4** | **10** | **~40%** ↑↑ |
| FTR Partner Readiness | **6** | 5 | 4 | **~60%** ↑↑ |

**Overall WAF (6 pillarów): ~40%** ↑  
**FTR Partner Readiness: BLOKOWANE** przez FTR 6 (root MFA) — szacowany czas do FTR: 1-2 dni (operacyjne) + audyt root MFA na pozostałych kontach

> Zmiany 2026-05-02: COST 1 → ✅, COST 3 → ✅, FTR 12 → ✅, ORG 10 → ✅, ORG 16 → ✅, SEC 4 → ✅, ORG 11 → ✅, FTR 3 → ✅  
> Zmiany 2026-05-04: **SEC 1 → ✅** (Config+CloudTrail potwierdzony), **ORG 12 → ✅** (Config org-wide), **ORG 13 → ✅** (Security Hub 11/11 enrolled), **FTR 1 → ✅** (CloudTrail audit), **FTR 4 → ✅** (Config), **FTR 5 → ✅** (Security Hub); **ORG 4 → ❌** (root MFA brak — audyt ujawnił CRITICAL)

---

## High Risk Issues (HRI) — do rozwiązania priorytetowo

1. ~~**ORG 11 / SEC 4** — GuardDuty~~ **RESOLVED 2026-05-02** ✅ (org-wide, 12/12 kont)
2. ~~**ORG 16 / SEC 1** — SCP security-baseline~~ **RESOLVED 2026-05-02** ✅ (deployed Sandbox+NonProd+Prod)
3. **ORG 1** — Wszystkie konta w Root → SCP nie działają (nie ma gdzie ich podpiąć)
4. **REL 13** — Brak formalnego DR plan mimo istnienia konta DRP
5. **SEC 10 / FTR 9** — Brak IR plan → brak procedury na incydent bezpieczeństwa

---

## Szybkie wygrane (quick wins)

1. ~~**SCP security-baseline deploy**~~ **DONE ✅ 2026-05-02** — llz-security-baseline live (Sandbox+NonProd+Prod)
2. **Root MFA audit** — sprawdzić manualnie, 15 minut, odblokuje FTR 6
3. **S3 Block Public Access audit** — AWS CLI, 30 minut, odblokuje FTR 15 / ORG 14
4. **Savings Plans zakup** — analiza Cost Explorer 1h, ~20-30% oszczędności dla rshop/booking/planodkupow (stabilny $1100-1400/month każdy)
5. **Faza B kick-off** — GuardDuty + Config + Security Hub = FTR unblocked w 3-4 tygodnie

---

## Powiązania z LLZ Faza B

| Faza B Epic | WAF / ORG / FTR checks które adresuje |
|-------------|--------------------------------------|
| EPIC 1 — OU + owners | OPS 2, SEC 3, **ORG 1, ORG 2** |
| EPIC 2 — CloudTrail/LogArchive hardening | **ORG 5, ORG 6, FTR 1, FTR 2** |
| EPIC 3 — Security Account | SEC 1, SEC 4, REL 10, **ORG 3, ORG 13, FTR 5** |
| EPIC 4 — GuardDuty org | SEC 4 (HRI), **ORG 11 (HRI), FTR 3 (blocker)** |
| EPIC 5 — Config + Aggregator | SEC 1, OPS 4, REL 6, **ORG 12, FTR 4 (blocker)** |
| EPIC 6 — SCP baseline | SEC 1 (HRI), COST 2, **ORG 16 (HRI)** |
| EPIC 7 — Legacy decommission | COST 4, **ORG 1** |
| — (brak epiku) | IAM Identity Center | **ORG 8** — poza obecnym scope LLZ |
| — (brak epiku) | Savings Plans | **ORG 17** — 1-2 dni, quick win |
