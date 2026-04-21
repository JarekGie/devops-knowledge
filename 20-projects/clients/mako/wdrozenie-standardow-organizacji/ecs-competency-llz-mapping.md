# ECS Service Delivery Competency — mapowanie na LLZ

#aws #ecs #competency #llz #finops #governance

**Data:** 2026-04-21
**Źródło:** Amazon ECS Self-Assessment (validity: Aug 2025 – Feb 2026)
**Referencje klientów:** #1 = rshop, #2 = booking-online

---

## Jak to czytać

LLZ (Light Landing Zone) jest MakoLab wewnętrznym standardem operacyjnym.
Ten dokument pokazuje, że spełnienie LLZ = spełnienie wymagań ECS Competency.

Dwa zastosowania:
- **Roadmap LLZ** — luki w Competency (No/Partially) = backlog LLZ
- **Audit traceability** — dla AWS SA widać, które LLZ kontrole pokrywają które wymagania

---

## Skrót: WAFR zero-HRI

> Jeśli dla referencji klienta istnieje WAFR report z zerową liczbą HRI w pillars Security + Operational Excellence + Reliability → **Common Requirements są automatycznie spełnione** (DOC, ACCT, OPE, NETSEC, REL, COST).

LLZ WAF checklist (`waf-checklist.md`) jest bezpośrednim przygotowaniem do tego skrótu.
Obecny stan MakoLab: ~30% WAF-ready — HRI blokujące to GuardDuty (SEC-4) i brak SCP (SEC-1).

---

## Mapa: LLZ → ECS Competency

### LLZ Tagging → ECS-004

| ECS ID | Wymaganie | rshop | booking |
|--------|-----------|-------|---------|
| ECS-004 | ECS Managed Tags + Tag Propagation enabled | ❌ No | ✅ Yes |

**Co konkretnie:** `enableECSManagedTags: true` + `propagateTags: SERVICE` na każdym ECS Service w CFN/Terraform.

**LLZ kontrola:** `toolkit audit-pack tagging` — rozszerzyć o check `PropagateTags` w task definition / service definition.

**Backlog:** rshop — dodać `PropagateTags: SERVICE` do wszystkich serwisów. Runbook: `40-runbooks/incidents/rshop-tag-policy-remediation.md`.

---

### LLZ Naming → ECS-003

| ECS ID | Wymaganie | rshop | booking |
|--------|-----------|-------|---------|
| ECS-003 | Task definition families per singular business purpose | ✅ Yes | ✅ Yes |

**LLZ kontrola:** Naming standard `<project>-<environment>-<component>` wymusza jednoznaczność task definition families.

---

### LLZ Scaffold / IaC → ECS-002, REL-001

| ECS ID | Wymaganie | rshop | booking |
|--------|-----------|-------|---------|
| ECS-002 | Automated + reliable deployments (IaC) | ✅ Yes | ✅ Yes |
| REL-001 | Automate deployment, IaC tools | ✅ Yes | ✅ Yes |

**LLZ kontrola:** `toolkit audit-pack llz-basic` — scaffold conformance (envs/, backend.tf, versions.tf).

---

### LLZ Observability → ECS-018, OPE-001

| ECS ID | Wymaganie | rshop | booking |
|--------|-----------|-------|---------|
| ECS-018 | Observability: logi, metryki, tracing, health checks | ❌ No | ❌ No |
| OPE-001 | Zdefiniowane health KPIs, monitoring workloadów | ✅ Yes | ✅ Yes |

**Co konkretnie dla ECS-018:** wymagane:
- CloudWatch Container Insights na klastrze
- log driver `awslogs` na wszystkich task definitions
- ALB access logs włączone
- alarmy: CPU > 80%, 5xx > threshold, task count drops

**LLZ kontrola:** `toolkit audit-pack aws-logging` + `toolkit audit-pack observability-ready` — oba projekty mają findings. To jest **najszerzej blokujące wymaganie** (No dla obu referencji).

**Backlog:** ECS-018 to priorytet #1 do naprawy dla obu projektów. Pokrywa się z LLZ HRI observability.

---

### LLZ Security → ECS-005, ECS-010, ECS-011, ECS-012, ACCT-001, ACCT-002, NETSEC-002

| ECS ID | Wymaganie | rshop | booking |
|--------|-----------|-------|---------|
| ECS-005 | IAM role per task definition | ✅ Yes | ✅ Yes |
| ECS-010 | ECR image scanning przed deployem | ✅ Yes | ✅ Yes |
| ECS-011 | Runtime security tool dla kontenerów | ❌ No | ❌ No |
| ECS-012 | OS zoptymalizowany dla kontenerów (Fargate/Bottlerocket) | ✅ Yes | ✅ Yes |
| ACCT-001 | Secure account governance | ✅ Yes | ✅ Yes |
| ACCT-002 | IAM least privilege, identity security | ✅ Yes | ✅ Yes |
| NETSEC-002 | Szyfrowanie at rest + in transit | ⚠️ Partially | ✅ Yes |

**Co konkretnie dla ECS-011 (runtime security):**
Opcje spełnienia:
- Amazon GuardDuty Runtime Monitoring dla ECS (Fargate) — rekomendowane, natywne AWS
- Amazon Inspector dla ECR images (uzupełnienie do ECS-010)

ECS-011 + GuardDuty org-wide (LLZ EPIC 4, HRI SEC-4) to **ten sam backlog item**.

**Co konkretnie dla NETSEC-002 (rshop partial):**
Wymagane: formalna polityka szyfrowania (dokument) + enforcement: RDS encryption ON, S3 SSE, ALB HTTPS only, brak HTTP listeners.

**LLZ kontrola:** `llz-workloads-baseline` SCP (blokada S3 public), przyszły `toolkit audit-pack security`.

---

### LLZ Networking → ECS-015, ECS-016, ECS-017, NETSEC-001

| ECS ID | Wymaganie | rshop | booking |
|--------|-----------|-------|---------|
| ECS-015 | CloudFront przed ALB jako ingress | ❌ No | ✅ Yes |
| ECS-016 | Strategia na IP exhaustion (awsvpc + multi-subnet) | ✅ Yes | ✅ Yes |
| ECS-017 | Service communication (awsvpc, Service Connect/Discovery) | ✅ Yes | ✅ Yes |
| NETSEC-001 | VPC security best practices | ✅ Yes | ✅ Yes |

**Co konkretnie dla ECS-015 (rshop):**
CloudFront jako wymagana warstwa przed ALB dla ruchu internetowego. Pattern: CloudFront → ALB → ECS.
rshop aktualnie: ALB bezpośrednio eksponowany → nie spełnia.

**LLZ standard:** dodać CloudFront jako wymagany komponent architektury dla projektów z ruchem publicznym (nowy wymóg w `standard-iac-tagging-naming.md`).

---

### LLZ FinOps → ECS-007, ECS-008, COST-001

| ECS ID | Wymaganie | rshop | booking |
|--------|-----------|-------|---------|
| ECS-007 | Capacity Providers strategy (Fargate/Fargate Spot) | ❌ No | ✅ Yes |
| ECS-008 | EC2 Spot / FARGATE_SPOT (jeśli EC2 launch type) | ❌ No | n/a |
| COST-001 | TCO analysis / cost modelling | ✅ Yes | ✅ Yes |

**Co konkretnie dla ECS-007:**
Capacity Provider musi być skonfigurowany na klastrze (nawet jeśli tylko `FARGATE`). Sam Fargate bez Capacity Provider strategy nie spełnia wymagania.

**Co konkretnie dla ECS-008:**
Tylko dla projektów z EC2 launch type. Fargate-only = n/a jest akceptowalne.

**LLZ standard:** dodać Capacity Providers jako wymaganie dla ECS w sekcji 8 (Monitoring i operacje) lub nowej sekcji ECS patterns.

---

### LLZ Operations → ECS-006, ECS-009, ECS-023, OPE-002, OPE-003, REL-002

| ECS ID | Wymaganie | rshop | booking |
|--------|-----------|-------|---------|
| ECS-006 | Task sizing strategy (CPU/memory per task) | ✅ Yes | ✅ Yes |
| ECS-009 | Zarządzanie wieloma klastrami | ✅ Yes | ✅ Yes |
| ECS-023 | Multi-tenant workload isolation | ✅ Yes | ❌ No |
| OPE-002 | Runbooki / playbooki operacyjne | ✅ Yes | ✅ Yes |
| OPE-003 | Deployment readiness checklist | ✅ Yes | ✅ Yes |
| REL-002 | DR plan, RTO/RPO | ✅ Yes | ✅ Yes |

**Co konkretnie dla ECS-023 (booking):**
Hard multi-tenancy (per-tenant IAM role/namespace) nie jest wdrożone. Soft multi-tenancy (shared cluster, SG separation) — akceptowalne tylko z dokumentacją uzasadnienia.

---

### LLZ Documentation → DOC-001

| ECS ID | Wymaganie | rshop | booking |
|--------|-----------|-------|---------|
| DOC-001 | Diagram architektury (scalability + HA) | ✅ Yes | ✅ Yes |

---

## Stan zgodności — podsumowanie

### Service Requirements (23 wymagania)

| Status | Count | ID |
|--------|-------|----|
| ✅ Yes (oba) | 12 | ECS-001,002,003,005,006,009,010,012,016,017,019 + jeden z 023 |
| ⚠️ Częściowo (jeden No) | 5 | ECS-004 (rshop), ECS-007 (rshop), ECS-015 (rshop), ECS-023 (booking), ECS-008 (rshop) |
| ❌ No (oba) | 2 | ECS-011, ECS-018 |
| ➖ n/a | 4 | ECS-013, ECS-014, ECS-020, ECS-021, ECS-022 |

### Common Requirements (11 wymagań)

| Status | Count | ID |
|--------|-------|----|
| ✅ Yes (oba) | 10 | DOC-001, ACCT-001/002, OPE-001/002/003, NETSEC-001, REL-001/002, COST-001 |
| ⚠️ Partially | 1 | NETSEC-002 (rshop) |

---

## Backlog LLZ — priorytety remediacji

Posortowane według wpływu na Competency i pokrycia z istniejącym LLZ backlogiem:

| Priorytet | ECS ID | Co zrobić | LLZ Epic | Projekt |
|-----------|--------|-----------|----------|---------|
| 🔴 1 | ECS-011 | GuardDuty Runtime Monitoring dla ECS/Fargate | EPIC 4 — HRI | oba |
| 🔴 2 | ECS-018 | Container Insights + kompletne logi + alarmy ECS | LLZ observability | oba |
| 🟡 3 | ECS-004 | `PropagateTags: SERVICE` + `enableECSManagedTags` | LLZ tagging | rshop |
| 🟡 4 | ECS-015 | CloudFront przed ALB — dodać do architektury | LLZ networking | rshop |
| 🟡 5 | ECS-007 | Capacity Provider strategy na klastrach | LLZ operations (nowe) | rshop |
| 🟢 6 | NETSEC-002 | Formalna polityka szyfrowania — dokument | LLZ security | rshop |
| 🟢 7 | ECS-023 | Dokumentacja izolacji multi-tenant (soft model) | LLZ operations | booking |
| 🟢 8 | ECS-008 | FARGATE_SPOT evaluation — dokument decyzji | LLZ FinOps | rshop |

---

## Co dodać do standard-iac-tagging-naming.md

Na podstawie tej mapy, `standard-iac-tagging-naming.md` wymaga rozszerzenia o:

1. **Sekcja ECS patterns** (nowa):
   - `PropagateTags: SERVICE` + `enableECSManagedTags: true` — obowiązkowe
   - Capacity Provider strategy — obowiązkowe (nawet dla Fargate-only)
   - Container Insights — obowiązkowe
   - CloudFront przed ALB — wymagane dla ruchu publicznego

2. **Sekcja Security** (rozszerzyć):
   - GuardDuty Runtime Monitoring dla ECS — obowiązkowe (po wdrożeniu EPIC 4)
   - Formalna polityka szyfrowania as document — obowiązkowe

3. **Sekcja Networking** (rozszerzyć):
   - CloudFront jako wymagana warstwa ingress dla projektów publicznych

---

## Powiązane

- [[standard-iac-tagging-naming]] — standard organizacyjny (do rozszerzenia)
- [[../../../20-projects/internal/llz/waf-checklist]] — WAF → skrót Common Requirements
- [[../../../40-runbooks/incidents/rshop-tag-policy-remediation]] — ECS-004 rshop
- `_chatgpt/context-packs/llz.md` — kontekst LLZ dla LLM

---

*Utworzono: 2026-04-21 | Źródło: Amazon ECS Self-Assessment (Aug 2025 – Feb 2026)*
