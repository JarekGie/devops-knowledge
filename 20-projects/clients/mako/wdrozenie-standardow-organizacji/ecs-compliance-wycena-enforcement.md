# ECS Compliance — wycena wdrożenia i enforcement

#aws #ecs #competency #llz #finops #scp #wycena

**Data:** 2026-04-21
**Kontekst:** Wdrożenie zmian wymaganych przez ECS Competency + LLZ standard w projektach opartych o Amazon ECS

---

## TL;DR

| Co | Czas inżyniera | Koszt AWS/mies. |
|----|---------------|-----------------|
| Remediation 3 istniejących projektów | ~6 dni | +$100–270/mies. |
| Nowy projekt "LLZ-ready" od zera | +2–3 dni vs bez standardu | +$35–90/mies. |
| Największy koszt jednorazowy | CloudFront (ECS-015) — 1 dzień/projekt | $10–40/mies./projekt |
| Największy bloker org-wide | GuardDuty Runtime (ECS-011) — EPIC 4 | $15–30/mies./projekt |

---

## Wycena per zmiana

### ECS-004 — PropagateTags + Managed Tags

| Wymiar | Wartość |
|--------|---------|
| Czas inżyniera | ~2h per projekt (IaC + PR + deploy) |
| AWS koszt | $0 — tagi są bezpłatne |
| Ryzyko | Niskie — tag change wywołuje ECS rolling deploy (akceptowalny) |
| Dla istniejących | +1h na walidację change seta (planodkupow: sprawdzić PropagateTags drift) |

```yaml
# CloudFormation
EnableECSManagedTags: true
PropagateTags: SERVICE

# Terraform
enable_ecs_managed_tags = true
propagate_tags          = "SERVICE"
```

---

### ECS-007 — Capacity Providers

| Wymiar | Wartość |
|--------|---------|
| Czas inżyniera | ~2h per klaster |
| AWS koszt | $0 jeśli zostajemy na FARGATE. Oszczędności jeśli włączymy FARGATE_SPOT (20–30% taniej dla non-critical) |
| Ryzyko | Niskie — zmiana konfiguracji klastra, bez wpływu na działające taski |

Uwaga: samo dodanie Capacity Provider strategy bez FARGATE_SPOT = zero dodatkowych kosztów. FARGATE_SPOT to opcja, nie wymóg.

---

### ECS-011 — GuardDuty Runtime Monitoring (największy koszt AWS)

| Wymiar | Wartość |
|--------|---------|
| Czas inżyniera | ~4h org-wide (Terraform EPIC 4) + ~1h per projekt |
| AWS koszt | ~$0.00216/vCPU-hour per task |
| Szacunek dla projektu (20 tasków × 0.5 vCPU × 730h) | **~$16/mies.** |
| Szacunek dla 3 projektów (rshop + booking + planodkupow) | **~$48/mies.** |
| Ryzyko wdrożenia | Niskie — agentless dla Fargate, bez zmian w task definitions |

GuardDuty Runtime Monitoring dla ECS/Fargate jest agentless — AWS wstrzykuje sidecar automatycznie po włączeniu w konfiguracji GuardDuty. Zero zmian w IaC projektów.

To **ten sam item co LLZ EPIC 4** — jedno wdrożenie pokrywa wszystkie projekty org-wide.

---

### ECS-015 — CloudFront przed ALB (największy koszt inżyniera)

| Wymiar | Wartość |
|--------|---------|
| Czas inżyniera | ~1 dzień per projekt (nowa dystrybucja CF + certyfikaty + testy) |
| AWS koszt CloudFront | ~$0.085/GB data transfer out + $0.01/10k requestów (eu-central-1) |
| Szacunek dla projektu (100GB/mies. ruch) | **~$10–20/mies.** |
| Potencjalna oszczędność | ALB data transfer tańszy przez CF → netto często koszt-neutralne |
| Ryzyko | ŚREDNIE — zmiana DNS, certyfikaty, WebSocket headers, cache invalidation |

Dla projektów z dużym ruchem statycznym (Next.js, pliki) CloudFront może być **tańszy** niż bezpośredni ALB (lepsze caching = mniej requestów do ALB).

---

### ECS-018 — Container Insights + kompletna observability

| Wymiar | Wartość |
|--------|---------|
| Czas inżyniera | ~2h per klaster (IaC + walidacja) |
| AWS koszt Container Insights | ~$0.50 per 1M metrycznych datapoint |
| Szacunek dla projektu (20 tasków) | **~$10–20/mies.** |
| CloudWatch Logs (jeśli nie ma) | ~$0.50/GB ingested + $0.03/GB stored |
| Ryzyko | Niskie |

---

### NETSEC-002 — Polityka szyfrowania (dokument)

| Wymiar | Wartość |
|--------|---------|
| Czas inżyniera | ~4h (raz, dla całej organizacji) |
| AWS koszt | $0 |
| Ryzyko | Brak — dokument, nie zmiana infrastruktury |

---

## Wycena per projekt

### Remediation istniejących projektów

| Projekt | Zmiany do wdrożenia | Czas inżyniera | AWS koszt/mies. |
|---------|-------------------|----------------|-----------------|
| **rshop** | ECS-004, ECS-007, ECS-015, ECS-018 | ~3 dni | +$25–60 |
| **booking-online** | ECS-011 (shared), ECS-018, ECS-023 | ~1.5 dnia | +$25–50 |
| **planodkupow** | ECS-018 | ~0.5 dnia | +$10–20 |
| **Org-wide (EPIC 4)** | ECS-011 GuardDuty Runtime | ~0.5 dnia | +$48 (3 projekty) |
| **ŁĄCZNIE** | | **~5.5–6 dni** | **+$108–178/mies.** |

### Nowy projekt "od zera" z LLZ-ready

Narzut względem projektu bez standardu:

| Co | Czas | Kiedy |
|----|------|-------|
| Scaffold LLZ (toolkit llz-basic) | +2h | setup |
| PropagateTags + Capacity Providers | +1h | setup |
| Container Insights + alarmy | +2h | setup |
| CloudFront (jeśli public-facing) | +1 dzień | setup |
| **Łącznie (bez CF)** | **~5h** | jednorazowo |
| **Łącznie (z CF)** | **~1.5 dnia** | jednorazowo |

Miesięczny narzut AWS: **$35–90/projekt** (Container Insights + GuardDuty Runtime + opcjonalnie CloudFront).

---

## Enforcement — co można umocować w SCP

### Matryca: SCP vs Config vs toolkit

| Wymaganie | SCP | AWS Config | devops-toolkit | Uwagi |
|-----------|-----|-----------|----------------|-------|
| Tagi obowiązkowe na ECS Service | ✅ | ✅ | ✅ | SCP najsilniejszy — blokuje na etapie API call |
| Tagi obowiązkowe na ECS Cluster | ✅ | ✅ | ✅ | |
| Zakaz wyłączania GuardDuty | ✅ | ❌ | ❌ | SCP jedyna opcja preventive |
| Container Insights enabled | ❌ | ✅ | ✅ | SCP nie ma condition key dla tej setting |
| PropagateTags: SERVICE | ❌ | ✅ | ✅ | Brak SCP condition key dla ECS service properties |
| CloudFront przed ALB | ❌ | ❌ | ✅ | Wzorzec architektoniczny — poza zakresem SCP/Config |
| Szyfrowanie RDS | ✅ | ✅ | ❌ | SCP może blokować `CreateDBInstance` bez encryption |
| Szyfrowanie S3 | ✅ | ✅ | ❌ | SCP może blokować `PutBucketPolicy` bez SSE |

**Kluczowa granica:**
- **SCP** = kontroluje *czy możesz wykonać API call* (preventive)
- **Config** = wykrywa *czy zasób jest zgodny po fakcie* (detective)
- **toolkit** = audytuje *wzorce architektoniczne i IaC* (advisory)

---

## Co konkretnie dodać do SCP

### Rozszerzenie `llz-workloads-baseline` (już istniejące SCP)

#### 1. Wymagane tagi przy tworzeniu zasobów ECS

```json
{
  "Sid": "DenyECSWithoutRequiredTags",
  "Effect": "Deny",
  "Action": [
    "ecs:CreateCluster",
    "ecs:CreateService"
  ],
  "Resource": "*",
  "Condition": {
    "Null": {
      "aws:RequestTag/Project": "true"
    }
  }
}
```

> ⚠️ **Uwaga:** `RegisterTaskDefinition` celowo pominięte — task definitions są rejestrowane przez CI/CD pipeline bardzo często. Blokada wywoła chaos w deploymentach. Tagi na task definitions egzekwować przez toolkit/Config, nie SCP.

#### 2. Zakaz wyłączania GuardDuty Runtime Monitoring (po wdrożeniu EPIC 4)

```json
{
  "Sid": "DenyDisableGuardDutyRuntime",
  "Effect": "Deny",
  "Action": [
    "guardduty:UpdateDetector",
    "guardduty:DeleteDetector",
    "guardduty:DisassociateFromMasterAccount"
  ],
  "Resource": "*",
  "Condition": {
    "StringEquals": {
      "aws:PrincipalType": "IAMUser"
    }
  }
}
```

Uzupełnienie istniejącego bloku z `llz-workloads-baseline` (który już blokuje wyłączanie CloudTrail i Config).

#### 3. Szyfrowanie RDS (NETSEC-002)

```json
{
  "Sid": "DenyUnencryptedRDS",
  "Effect": "Deny",
  "Action": "rds:CreateDBInstance",
  "Resource": "*",
  "Condition": {
    "Bool": {
      "rds:StorageEncrypted": "false"
    }
  }
}
```

---

## Co zostawić dla Config (detective)

Reguły AWS Config do dodania — wykrywają niezgodność po fakcie, nie blokują:

| Reguła Config | Wykrywa | Mapowanie |
|---------------|---------|-----------|
| `ecs-container-insights-enabled` | Container Insights wyłączone | ECS-018 |
| `ecs-task-definition-log-configuration` | brak log drivera w task def | ECS-018 |
| `guardduty-enabled-centralized` | GuardDuty wyłączony | ECS-011 / HRI |
| `rds-storage-encrypted` | niezaszyfrowane instancje | NETSEC-002 |
| `s3-bucket-server-side-encryption-enabled` | S3 bez SSE | NETSEC-002 |

Config wymaga org aggregatora (LLZ EPIC 5) żeby mieć widoczność cross-account.

---

## Co zostawić dla devops-toolkit (advisory)

Wzorce architektoniczne i IaC — poza zakresem SCP i Config:

- CloudFront przed ALB (ECS-015) → `cfn-networking-audit` (plugin do napisania)
- PropagateTags w ECS Service definition → rozszerzenie `cfn_messaging_audit` lub nowy plugin
- Capacity Provider strategy na klastrze → nowy check w `llz-basic`
- Multi-tenant isolation pattern (ECS-023) → advisory, nie enforcement

---

## Rekomendacja kolejności wdrożenia

```
Krok 1 (teraz, niski koszt):
  ✓ Dodaj DenyECSWithoutRequiredTags do llz-workloads-baseline SCP
  ✓ Dodaj DenyUnencryptedRDS do llz-workloads-baseline SCP
  Czas: ~2h (Terraform + apply)

Krok 2 (EPIC 4 — GuardDuty):
  ✓ GuardDuty Runtime Monitoring org-wide
  ✓ Dodaj DenyDisableGuardDutyRuntime do SCP
  Czas: ~1 dzień
  Koszt: ~$48/mies. dla 3 projektów

Krok 3 (remediation projektów):
  ✓ rshop: ECS-004, ECS-007, ECS-015, ECS-018 (~3 dni)
  ✓ booking: ECS-018 (~0.5 dnia)
  ✓ planodkupow: ECS-018 (~0.5 dnia)

Krok 4 (Config org aggregator — EPIC 5):
  ✓ Reguły Config dla Container Insights, GuardDuty, szyfrowania
  ✓ Dashboard compliance cross-account
```

---

## Powiązane

- [[ecs-competency-llz-mapping]] — źródło wymagań ECS
- [[standard-iac-tagging-naming]] — standard organizacyjny
- [[../../../20-projects/internal/llz/context]] — LLZ EPIC 4 (GuardDuty), EPIC 5 (Config)

---

*Utworzono: 2026-04-21*
