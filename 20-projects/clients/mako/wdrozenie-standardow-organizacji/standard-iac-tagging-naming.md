# Standard IaC + Tagging + Naming (LLZ — MakoLab)

---

## 1. Cel dokumentu

Celem jest ustalenie jednolitego standardu tworzenia infrastruktury (IaC) w MakoLab, obejmującego:

- konwencję tagowania zasobów
- konwencję nazewnictwa zasobów
- standard repozytoriów Terraform
- minimalne wymagania operacyjne (monitoring, bezpieczeństwo)

Standard jest bezpośrednio powiązany z:

- AWS Well-Architected Framework
- wymaganiami AWS Competency
- LLZ (Light Landing Zone)

---

## 2. Dlaczego to robimy (biznesowo, nie technicznie)

**Dziś mamy:**

- brak spójnych tagów → brak kontroli kosztów
- różne nazewnictwo → trudny onboarding i chaos operacyjny
- różne podejścia IaC → brak powtarzalności

**Po wdrożeniu:**

- 💰 koszty widoczne per projekt / środowisko
- 🔍 łatwe audyty (security, compliance, FinOps)
- 🔁 powtarzalne wdrożenia
- ⚡ szybsze wdrożenia nowych projektów

---

## 3. Zakres

Standard dotyczy:

- wszystkich **nowych** projektów AWS
- istniejących projektów (stopniowa migracja)
- infrastruktury zarządzanej jako kod:
  - Terraform (preferowany)
  - CloudFormation (legacy / projekty klientów)

---

## 4. Kluczowa zasada (najważniejsza)

> **Jeśli zasób nie spełnia standardu (tagging/naming) → jest traktowany jako niezgodny.**

To nie jest guideline — to jest **kontrakt operacyjny**.

---

## 5. Tagging — standard organizacyjny

### 5.1 Tagi obowiązkowe

Każdy zasób **MUSI** posiadać:

| Tag | Opis | Przykład |
|-----|------|---------|
| `Project` | identyfikator projektu | `rshop` |
| `Environment` | środowisko | `dev`, `qa`, `uat`, `prod` |
| `Owner` | właściciel techniczny | `DC-devops` |
| `CostCenter` | rozliczenia | `DC` |
| `ManagedBy` | sposób zarządzania | `terraform` / `cloudformation` |

### 5.2 Dlaczego to jest krytyczne

Bez tego:

- ❌ brak FinOps (Cost Explorer, anomaly detection)
- ❌ brak możliwości automatycznych raportów (`devops-toolkit`)
- ❌ brak zgodności z AWS Competency

### 5.3 Ważna decyzja (do zatwierdzenia)

> 👉 Czy `Owner` zawsze = MakoLab (np. `DC-devops`), czy dopuszczamy zewnętrznego maintenera (np. Tribecloud)?

**Rekomendacja:**

- `Owner` = odpowiedzialność operacyjna (MakoLab)
- `Client` = opcjonalny tag biznesowy (klient / vendor)

### 5.4 Strategia migracji (realna, nie idealna)

Zgodnie z doświadczeniem operacyjnym (planodkupow):

**Faza 1 — addytywna**
- dodajemy nowe tagi
- nie usuwamy starych

**Faza 2 — cleanup**
- usuwamy legacy tagi

> 👉 Powód: AWS NIE mapuje tagów logicznie — tylko literalnie. Cost Explorer, SCP i Tag Policies operują na realnych kluczach w AWS, nie na logicznym mapowaniu.

### 5.5 Enforcement

Tagging będzie egzekwowany przez:

- AWS Tag Policies (już wdrożone — org Root)
- audyty (`devops-toolkit audit-pack tagging`)
- pipeline (PR review + przyszły contract check)

---

## 6. Naming — standard techniczny

### 6.1 Konwencja

```
<project>-<environment>-<component>
```

**Przykłady:**

```
rshop-prod-alb
rshop-dev-ecs
planodkupow-qa-rds
```

### 6.2 Zasady

- lowercase
- bez spacji
- separator: `-`
- brak skrótów nieczytelnych dla nowego członka zespołu

### 6.3 Dlaczego to jest ważne

Umożliwia automatyczne:

- discovery (ECS, CFN, Resource Groups)
- audyty i raporty
- monitoring i alarmowanie

Redukuje błędy operacyjne (deploy na złe środowisko, nieoczekiwane zmiany).

---

## 7. Standard Terraform (IaC)

### 7.1 Struktura repo

```
.
├── envs/
│   ├── dev/
│   ├── qa/
│   ├── uat/
│   ├── prod/
│   └── shared/
├── modules/
├── versions.tf
├── providers.tf
└── README.md
```

### 7.2 Kluczowe zasady

- osobny state per environment
- brak hardcodów: region, account_id
- moduły reużywalne

### 7.3 Remote state

- S3 + DynamoDB (lock)
- versioning: ON
- encryption: ON
- brak local state na jakimkolwiek środowisku

---

## 8. Monitoring i operacje

Minimalny baseline per projekt:

- CloudWatch Logs (ECS, Lambda, RDS)
- alarmy: CPU, 5xx, health checks
- dashboard per environment
- centralny dashboard (konto monitoring-nagios-bot)

---

## 8a. ECS — wymagania dodatkowe (AWS Competency)

Dla projektów opartych na Amazon ECS, oprócz baseline z sekcji 5–8, obowiązkowe są:

### Tagging ECS (ECS-004)

```yaml
# CloudFormation — każdy AWS::ECS::Service
EnableECSManagedTags: true
PropagateTags: SERVICE
```

```hcl
# Terraform — każdy aws_ecs_service
enable_ecs_managed_tags = true
propagate_tags          = "SERVICE"
```

Bez tego tagi nie propagują się do tasków → Cost Explorer nie widzi kosztów per serwis.

### Capacity Providers (ECS-007)

Każdy klaster ECS musi mieć zdefiniowaną strategię Capacity Provider — nawet jeśli używamy wyłącznie Fargate:

```hcl
capacity_providers = ["FARGATE", "FARGATE_SPOT"]

default_capacity_provider_strategy {
  capacity_provider = "FARGATE"
  weight            = 1
}
```

Klaster bez Capacity Provider strategy = niezgodny z ECS Competency.

### Observability ECS (ECS-018)

Wymagane dla każdego klastra:

- **Container Insights** włączone (`setting { name = "containerInsights", value = "enabled" }`)
- log driver `awslogs` na **wszystkich** task definitions (brak = niezgodny)
- alarmy CloudWatch: CPU > 80%, pamięć > 80%, running tasks < desired
- ALB access logs włączone (bucket S3)

### Ingress — CloudFront przed ALB (ECS-015)

Dla projektów z ruchem publicznym (internet-facing):

```
Internet → CloudFront → ALB → ECS
```

Bezpośrednia ekspozycja ALB na internet = niezgodna z ECS Competency.
Wyjątek wymaga dokumentacji uzasadnienia.

### Runtime security (ECS-011)

Po wdrożeniu GuardDuty org-wide (LLZ EPIC 4):

- GuardDuty Runtime Monitoring dla ECS/Fargate — obowiązkowe
- ECR image scanning (basic lub Enhanced z Inspector) — obowiązkowe

---

## 9. Bezpieczeństwo (baseline)

- brak publicznych zasobów (domyślnie private)
- szyfrowanie danych at rest i in transit (formalna polityka — dokument)
- CloudTrail ON (org-level — już wdrożone)
- GuardDuty Runtime Monitoring (w trakcie wdrożenia — **HRI**, LLZ EPIC 4)

---

## 10. Powiązanie z LLZ

Ten standard:

- jest częścią **LLZ (Light Landing Zone)**
- będzie audytowany automatycznie przez `devops-toolkit`
- jest podstawą do **AWS Competency**

Narzędzie: `toolkit audit-pack llz-basic` (scaffold), `toolkit audit-pack tagging`, `toolkit audit-pack aws-logging`.

---

## 11. Jak to będzie egzekwowane

Docelowo:

```
PR → review
     └── terraform validate
     └── toolkit audit-pack tagging
     └── toolkit audit-pack llz-basic
         └── niezgodność → blokada merge
```

Zgodne z kontraktowym podejściem toolkitu: stateless engine, audyty jako artefakty w repo projektu.

---

## 12. Co wymaga decyzji (na spotkaniu)

| Priorytet | Decyzja | Opcje |
|-----------|---------|-------|
| 🔴 1 | **Owner vs Client** — kto jest Ownerem? | `Owner=DC-devops` zawsze / `Owner=klient` dla zewnętrznych? |
| 🔴 2 | **Naming** — czy trzymamy 100% standard? | zero wyjątków / dopuszczamy legacy z oznaczeniem |
| 🔴 3 | **Migracja** — jak podchodzimy do istniejących projektów? | projekt po projekcie / tylko nowe projekty |
| 🔴 4 | **Enforcement** — brak tagów = blokada deploymentu? | TAK dla nowych (rekomendacja) / tylko warning |

---

## 13. Kolejny krok (po tym dokumencie)

Po akceptacji:

1. 🔧 wdrożenie jako kontrakt w `devops-toolkit`
2. 🔍 audyt wszystkich projektów (`toolkit audit-pack tagging` per konto)
3. 📊 raport zgodności (Confluence)
4. 🚀 rollout LLZ standardu na kolejne projekty

---

## 14. Najważniejsze zdanie (do zapamiętania)

> **Tagging i naming to nie dokumentacja — to mechanizm kontroli kosztów i bezpieczeństwa.**
