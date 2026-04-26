---
tags: [#finops, #maspex, #aws, #cost]
date: 2026-04-26
status: as-is snapshot
account: 969209893152
region: eu-west-1
---

# Maspex UAT + Preprod — wycena as-is (kwiecień 2026)

Wycena wykonana na podstawie danych z AWS API (2026-04-26). Środowiska: UAT (`kapsel.makotest.pl`) i Preprod. Brak historii Cost Explorer — wszystkie liczby to kalkulacja z parametrów infrastruktury.

---

## 1. Potwierdzony inwentarz zasobów

| Zasób | UAT | Preprod | Uwaga |
|-------|-----|---------|-------|
| ECS maspex-api | **6 tasks × 4 vCPU / 8 GB** | desired=3, **running=0** (serwis down) | x86_64, awsvpc, no public IP |
| ECS maspex-admin-panel | 1 task × 0.5 vCPU / 2 GB | 1 task × 0.5 vCPU / 2 GB | |
| ECS maspex-bot | 1 task × 0.5 vCPU / 2 GB | 1 task × 0.5 vCPU / 2 GB | |
| ECS assignPublicIp | **DISABLED** (wszystkie serwisy) | **DISABLED** (wszystkie serwisy) | brak IP charges z ECS tasks |
| ElastiCache | **cache.t3.medium** Redis 7.1, 1 node | **cache.t3.micro** Redis 7.1, 1 node | bez replikacji, brak cluster mode |
| ALB | 1x internet-facing, **2 AZs** (1a+1b) | 1x internet-facing, **2 AZs** (1a+1b) | EIP per AZ |
| CloudFront | 3 dystrybucje PriceClass_100 | (shared) | patrz tabela CF |
| S3 | 2.24 GB (access-logs) | ~2.4 MB (access-logs) | + terraform-state 0.5 MB (shared) |
| ECR | 3 repozytoria, **7.43 GB** (53 images) | (shared) | maspex-api 6.32 GB, frontend 1.04 GB, worker 0.07 GB |
| Public IPv4 (EIPs) | 2 EIPs (ALB 1a+1b) | 2 EIPs (ALB 1a+1b) | **łącznie 4 EIPs = $14.60/mies** |
| NAT Gateway | **BRAK** | **BRAK** | potwierdzone |
| Route53 hosted zones | **BRAK** w tym koncie | — | DNS w innym koncie |
| Container Insights | **enabled** | **enabled** | oba klastry |
| SNS topics | 1 (maspex-uat-alarms) | — | |

### CloudFront — szczegóły (dane 30-dniowe, 2026-03-26 → 2026-04-26)

| Distribution | Domena | Bytes Downloaded | Requests |
|---|---|---|---|
| E3R9U1TWNUJZ11 | kapsel-admin-uat.makotest.pl | 70 MB | 27k |
| E3J76RNXIE2YIG | kapsel.makotest.pl | **1,091 GB** | **24.4M** |
| E17VHHQJ29MVAB | twojkapsel.pl, www.twojkapsel.pl | 28 MB | 4k |

> **⚠️ Flaga:** 1.09 TB i 24.4M requestów na kapsel.makotest.pl może być artefaktem load testów. Zweryfikować w Cost Explorer czy to typowy miesiąc.

---

## 2. Założenia i szacunki

| # | Założenie | Pewność |
|---|-----------|---------|
| 1 | Fargate on-demand (brak Savings Plans / Reserved) | Wysoka — brak SP widocznych w koncie |
| 2 | x86_64 (arch=null w TD → default Linux/amd64) | Wysoka |
| 3 | 730 h/mies (24/7, bez scale-down) | Wysoka dla UAT; Preprod api=0 potwierdzone |
| 4 | Ceny eu-west-1: vCPU $0.04048/hr, GB $0.004445/hr | Wysoka (AWS pricing page) |
| 5 | ElastiCache: t3.medium $0.0714/hr, t3.micro $0.0179/hr | Wysoka |
| 6 | CF data transfer EU: $0.0085/GB; HTTPS req: $0.0085/10k req | Wysoka |
| 7 | Ingestion CW Logs: $0.50/GB; storage $0.03/GB | Wysoka |
| 8 | Container Insights metrics: $0.50/task/month (standard tier) | Niska — szacunek; zweryfikuj w Cost Explorer (namespace ContainerInsights) |
| 9 | 4 EIPs = 2 ALB × 2 AZs; ECS tasks bez public IP | Potwierdzone przez ENI inspection |
| 10 | Brak cross-AZ transferu cache (single-node ElastiCache) | Wysoka |
| 11 | CF access logs → S3: operacje minimalne, objętość 2.24 GB | Potwierdzone |

---

## 3. Wycena per usługa

### Fargate

| Komponent | vCPU-h/mies | GB-h/mies | $ vCPU | $ RAM | $ razem |
|-----------|-------------|-----------|--------|-------|---------|
| UAT api (6 tasks × 4vCPU/8GB × 730h) | 17,520 | 35,040 | $709 | $156 | **$865** |
| UAT admin-panel (1 × 0.5/2 × 730h) | 365 | 1,460 | $15 | $6 | **$21** |
| UAT bot (1 × 0.5/2 × 730h) | 365 | 1,460 | $15 | $6 | **$21** |
| **UAT łącznie** | | | | | **$907** |
| Preprod api | 0 (running=0) | 0 | $0 | $0 | **$0** |
| Preprod admin-panel | 365 | 1,460 | $15 | $6 | **$21** |
| Preprod bot | 365 | 1,460 | $15 | $6 | **$21** |
| **Preprod łącznie** | | | | | **$43** |
| **FARGATE TOTAL** | | | | | **$950** |

### Pozostałe usługi

| Usługa | UAT | Preprod | Shared | Razem | Pewność |
|--------|-----|---------|--------|-------|---------|
| ElastiCache | $52 | $13 | — | **$65** | Wysoka |
| CloudFront (data + req) | $30 | — | — | **$30** | Wysoka (może być anomalia) |
| ALB (base $16.43 + LCU est.) | $19 | $17 | — | **$36** | Wysoka |
| CW Logs (ingestion + storage) | $0.15 | $0.05 | — | **$0.20** | Wysoka |
| CW Metrics (Container Insights) | $4–15 | $1–5 | — | **$5–20** | Niska — est. |
| CW Alarms (~12) + custom metrics (~5) | — | — | $2.75 | **$3** | Średnia |
| CW Dashboard (1 szt., w free tier) | — | — | $0 | **$0** | Wysoka |
| Public IPv4 (4 EIPs — ALBs) | — | — | $14.60 | **$15** | Wysoka |
| ECR storage (7.43 GB − 0.5 free) | — | — | $0.69 | **$0.70** | Wysoka |
| S3 (storage + GET/PUT ops) | $0.15 | $0 | $0.05 | **$0.20** | Wysoka |
| Data transfer cross-AZ / inter-svc | $1 | $0.50 | — | **$1.50** | Niska est. |
| SNS / Route53 / ACM | — | — | $0 | **$0** | Wysoka |

---

## 4. Trzy warianty sumaryczne

| Linia | Minimal | Likely | Conservative |
|-------|---------|--------|--------------|
| ECS Fargate | $950 | $950 | $950 |
| ElastiCache | $65 | $65 | $65 |
| CloudFront | $30 | $30 | $60* |
| ALB | $36 | $38 | $42 |
| CW (łącznie) | $5 | $15 | $25 |
| Public IPv4 | $15 | $15 | $15 |
| ECR + S3 + SNS | $1 | $1 | $2 |
| Data transfer | $1 | $2 | $5 |
| **SUMA** | **~$1,103** | **~$1,116** | **~$1,164** |

> \* Conservative CF: zakłada że 1.09 TB/mies to normalny ruch (nie jednorazowy load test) i rośnie dalej.

**Zakres: $1,100–$1,165/miesiąc** dla bieżącej konfiguracji (UAT fully running, Preprod z api=0).

---

## 5. Flagi niepewności

| Flaga | Opis | Potencjalny wpływ |
|-------|------|-------------------|
| **CF data volume** | 1.09 TB/mies może być load test artefakt | -$9/mies jeśli jednorazowy; +$9-50 jeśli ruch rośnie |
| **Container Insights metryki** | Brak Cost Explorer danych; $0.50/resource/mies est. | $5–25/mies w zależności od liczby monitorowanych zasobów |
| **Preprod api uruchomienie** | desired=3, running=0; gdy włączony: +3 tasks | +$108/mies |
| **Savings Plans** | Brak SP dla Fargate = on-demand ceny | 1-yr SP: ~-20% = ok. -$190/mies na ECS |
| **Graviton (ARM64)** | arch=null → x86; migacja do arm64 prosta | -20% ECS = ok. -$190/mies |
| **ALB LCU** | Szacunek 1-2 LCU; jeśli wyższy ruch → wyższe LCU | Niski; maks +$15/mies |

---

## 6. Największy koszt + Quick Wins FinOps

**Dominanta: ECS Fargate UAT = $907/mies = ~82% całego budżetu**

Szczegółowo:
- maspex-api (6 tasks) = $865 = **78%** całego rachunku
- Konfiguracja: 6 × 4 vCPU × 8 GB RAM przez całą dobę, 7 dni w tygodniu

### Quick wins (kolejność ROI):

| # | Akcja | Oszczędność | Złożoność | Ryzyko |
|---|-------|-------------|-----------|--------|
| 1 | **ECS Scheduled Scaling UAT** — skaluj api do min=1 po 19:00 PL, przywróć o 8:00 | $400–600/mies | Niska | Niska |
| 2 | **Graviton (ARM64)** — zmiana TD platform to `arm64`; ~20% taniej bez zmiany rozmiaru | ~$190/mies | Niska | Średnia (wymaga testów) |
| 3 | **Compute Savings Plans 1yr** dla ECS Fargate | ~$190/mies | Niska | Brak (committed) |
| 4 | **maspex-preprod-api desired=0** — serwis i tak nie działa; zredukuj desired, oszczędź na EIP/ALB LCU | $5–10/mies | Brak | Brak |
| 5 | **Container Insights Preprod wyłącz** — jeśli CI metrics dają >$5/mies | $3–10/mies | Niska | Brak |
| 6 | **ElastiCache Preprod downgrade** — patrz sekcja 10 | $39/mies | Średnia | Niska |

---

## 7. Dane niedostępne lub niezebrane

| Dane | Powód braku | Wpływ na wycenę |
|------|-------------|----------------|
| Cost Explorer history | Brak dostępu lub konto zbyt nowe | Nie można zweryfikować CI metrics, CF anomalii |
| ECR data transfer | Nie mierzono pull frequency | Zazwyczaj $0 (same-region free) |
| Dokładna liczba CW Alarms | Nie zliczono z AWS API | ±$2/mies |
| ALB access logs do S3 | Nie sprawdzono czy włączone dla preprod ALB | ±$0.10 |
| Backup/snapshot koszty | Brak RDS/EBS; nie dotyczy | $0 |

---

## 8. Następny krok weryfikacji

1. **Cost Explorer → Services → CloudWatch** → wybierz `ContainerInsights` namespace → sprawdź rzeczywisty koszt CI metrics
2. **Cost Explorer → Services → CloudFront** → grupuj po DistributionId → potwierdź czy 1.09 TB to normalny miesiąc
3. **Cost Explorer → Services → EC2-Other** → szukaj `PublicIPv4` line item → potwierdź $14.60
4. Włącz **Cost Allocation Tags** (`Environment`, `Project`) — brak tagów utrudnia przyszłe analizy

---

## 9. Koszt gdyby preprod-api wróciło (desired=3)

Dodatkowe 3 tasks × (1 vCPU / 2 GB) × 730h:

| Komponent | Koszt |
|-----------|-------|
| vCPU: 3 × 1 × $0.04048 × 730 | $88.65 |
| RAM: 3 × 2 GB × $0.004445 × 730 | $19.51 |
| **Łącznie** | **+$108/mies** |

Preprod z uruchomionym api: $43 → **$151/mies**  
Całość środowisk: ~$1,116 → **~$1,224/mies**

---

## 10. ElastiCache Preprod: t3.medium vs t3.micro?

**Stan obecny:** Preprod ma **cache.t3.micro** ($13/mies) — to już właściwy sizing dla środowiska testowego.

UAT ma cache.t3.medium ($52/mies) — tu można dyskutować:

| | cache.t3.micro | cache.t3.medium |
|-|----------------|-----------------|
| RAM | 0.555 GB | 3.22 GB |
| Cena/mies | $13 | $52 |
| Różnica | — | +$39/mies |

**Dla UAT downgrade do t3.micro ma sens jeśli:**
- Aplikacja nie korzysta z Redis intensywnie (nie ma session cache lub pubsub heavy load)
- Load testy można zatrzymać / ograniczyć
- Akceptowalny eviction gdy cache full

**Dla UAT zostaw t3.medium jeśli:**
- maspex-bot lub maspex-api używa Redis jako primary session store
- Load testy UAT mają symulować produkcję (potrzeba realistycznego cache)

**Rekomendacja:** Sprawdź `redis-cli INFO memory` → `used_memory_human`. Jeśli < 400 MB — downgrade do t3.micro zaoszczędzi $39/mies w UAT.

Preprod: **zostaw t3.micro** — właściwy sizing.

---

## 11. Container Insights — koszt wyodrębniony

Container Insights włączony na obu klastrach (confirmed).

**Metodologia szacunku ($0.50/task/month, standard tier):**

| Zasób | UAT | Preprod |
|-------|-----|---------|
| Uruchomione tasks | 8 | 2 |
| Szacowany koszt CI metrics | **$4/mies** | **$1/mies** |

**Koszt CI via CW Logs ingestion (performance log groups):**

| Log group | Retention | Stored | Est. ingestion/mies | Koszt |
|-----------|-----------|--------|---------------------|-------|
| /containerinsights/maspex-uat/performance | 1 dzień | 12 MB | ~361 MB | $0.18 |
| /containerinsights/maspex-preprod/performance | 1 dzień | 3.67 MB | ~110 MB | $0.06 |

**Łącznie Container Insights (metryki + logi):** ~$5–25/mies  
⚠️ Niepewność wysoka — zweryfikuj w Cost Explorer przed optymalizacją.

---

## Final recommendation for owner

**Bieżące środowisko kosztuje ~$1,100–1,165/mies** przy obecnej konfiguracji (UAT pełna skala 24/7, Preprod z wyłączonym api).

**Top 3 akcje bez ryzyka:**

1. **Scheduled Scaling UAT api** (po godzinach → min=1 task): potencjalnie **$400–600/mies** oszczędności. ECS Application Auto Scaling + Scheduled Actions; implementacja ~30 minut.

2. **Graviton dla ECS Tasks** (zmiana `runtimePlatform.cpuArchitecture` z null→ARM64): **~$190/mies** przy zachowaniu tej samej liczby tasks. Wymaga smoke testów po redeploymencie.

3. **Cost Explorer CI verification**: zanim zoptymalizujesz CW, sprawdź rzeczywisty koszt Container Insights. Jeśli >$20/mies — rozważ wyłączenie w Preprod.

**Nie ruszaj bez analizy:**
- Rozmiary ElastiCache UAT — sprawdź used_memory przed downgrade
- CF data volume — ustal czy 1.09 TB to jednorazowy load test czy trend

**Uwaga:** `maspex-preprod-api` ma `desired=3, running=0` — coś utrzymuje ten serwis w stanie zatrzymanym. Zbadaj zanim automatycznie przywrócisz lub zredukujesz do desired=0.
