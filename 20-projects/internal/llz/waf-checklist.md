---
type: checklist
updated: 2026-04-20
tags: [llz, waf, aws-well-architected, governance, compliance]
---

# LLZ — AWS Well-Architected Framework Checklist

> Checklista pod WAFR review z AWS SA. Skupiona na wymiarze org-governance i platformy (LLZ scope).
> Status: ✅ done | ⚠️ partial | ❌ missing | ➖ N/A / poza scope LLZ

Ostatnia aktualizacja stanu: **2026-04-20**

---

## Pillar 1 — Operational Excellence (OPS)

| ID | Pytanie / Best Practice | Status | Uwagi |
|----|------------------------|--------|-------|
| OPS 1 | Zdefiniowane priorytety operacyjne (KPIs, SLO) | ❌ | Brak formalnych SLO dla platform |
| OPS 2 | Struktura zespołu wspiera business outcomes | ⚠️ | DC-devops jako owner platformy — nie udokumentowane formalnie |
| OPS 3 | Kultura organizacyjna wspiera operacje (runbooki, on-call) | ⚠️ | Runbooki tworzone ad-hoc, brak formalnego on-call |
| OPS 4 | Observability: logi, metryki, tracing, health events | ⚠️ | CloudWatch OAM wdrożone, Health notifications ✅, brak centralnego dashboardu |
| OPS 5 | IaC, code review, CI/CD dla infrastruktury | ⚠️ | Terraform w repo, brak Atlantis/CI pipeline dla IaC |
| OPS 6 | Redukcja ryzyka deploymentu (blue/green, canary, rollback) | ⚠️ | ECS rolling update, brak formalnego runbooka rollback |
| OPS 7 | Readiness review przed produkcją (checklist, testy) | ❌ | Brak formalnego procesu |
| OPS 8 | Workload observability używana operacyjnie | ⚠️ | CloudWatch alarms na projektach, brak centralnej korelacji |
| OPS 9 | Health operacji monitorowany (dashboard ops) | ⚠️ | Health notifications wdrożone ✅, brak ops dashboard |
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
| COST 1 | Cloud Financial Management: tagging, budgets, alerty | ⚠️ | Tagging LLZ ✅, budgety nie wszędzie, brak FinOps procesu |
| COST 2 | Governance użycia: SCP deny expensive services, quota limits | ❌ | Brak SCP cost-related |
| COST 3 | Monitorowanie kosztów: Cost Explorer, anomaly detection | ⚠️ | Cost Explorer dostępny, brak automatycznych alertów anomalii |
| COST 4 | Decommission nieużywanych zasobów | ⚠️ | Konta legacy zidentyfikowane (Faza A), brak procesu cleanup |
| COST 5 | Selekcja serwisów z myślą o koszcie | ⚠️ | Ad-hoc, brak formalnego procesu |
| COST 6 | Right-sizing instancji i usług | ❌ | Brak systematycznego audytu |
| COST 7 | Pricing models: Reserved, Savings Plans, Spot | ❌ | Wszystko On-Demand |
| COST 8 | Planowanie transfer costs (inter-AZ, egress) | ❌ | Brak analizy |
| COST 9 | Auto-scaling dopasowany do demand (nie over-provision) | ⚠️ | ECS auto-scaling, brak testu efektywności |
| COST 10 | Regularna evaluacja nowych serwisów pod kątem kosztów | ❌ | Ad-hoc |
| COST 11 | Koszt wysiłku operacyjnego w decyzjach build vs. buy | ⚠️ | Uwzględniany nieformalnie |

**Priorytety COST:** COST 7 (Savings Plans — quick win), COST 3 (anomaly detection), COST 6 (right-sizing)

---

## Pillar 6 — Sustainability (SUS)

| ID | Pytanie / Best Practice | Status | Uwagi |
|----|------------------------|--------|-------|
| SUS 1 | Selekcja regionów z myślą o carbon footprint | ➖ | Regiony wybierane biznesowo (eu-west-1, eu-central-1) |
| SUS 2 | Zasoby cloud dopasowane do popytu (auto-scaling, idle removal) | ⚠️ | Auto-scaling ✅, dev/qa scheduler planowany w LLZ |
| SUS 3 | Wzorce architektoniczne wspierające sustainability (serverless, managed) | ⚠️ | ECS Fargate (managed) ✅, Lambda ✅ |
| SUS 4 | Data management policies (lifecycle, tiering, TTL) | ⚠️ | S3 lifecycle częściowo, brak standardu |
| SUS 5 | Hardware i serwisy efektywne energetycznie (Graviton, managed DB) | ⚠️ | RDS managed ✅, bez Graviton |
| SUS 6 | Procesy org redukujące environmental impact | ❌ | Brak formalnych celów |

**Priorytety SUS:** SUS 2 (scheduler — już w LLZ roadmapie), SUS 4 (S3 lifecycle policy standard)

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
