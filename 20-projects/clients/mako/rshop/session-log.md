# rshop — Session Log

Format: data, co zrobiono, gdzie skończono, co następne.

---

## 2026-05-08 — ECS deploy RCA + ACM cert migration

**Co zrobiono:**

### 1. ECS deploy failure RCA (dev)

- `dev-ECSStack-1BLAWHL0P6JKO` — pełne dochodzenie evidencyjne
- Root cause: ECS nie ustabilizował nowych kontenerów (health check lub startup crash) przez 3h → CFN `NotStabilized` → automatyczny rollback
- `ValidationError` — symptom wtórny: Jenkins uruchomił concurrent deploy podczas `UPDATE_IN_PROGRESS`
- Serwisy po rollbacku: ACTIVE, desired=1, running=1 ✅
- RCA: `rca-ecs-deploy-failure-2026-05-08.md`

### 2. ACM cert risk assessment

- Cert `*.skleprenault.pl` (`3be77743`) — wygasa 2026-05-13, `RenewalStatus=PENDING_VALIDATION`
- Blokada: `*.webshopdacia.hu` + `*.webshoprenault.hu` → NXDOMAIN w .hu TLD
- Cert używany przez: `E3LC30816FMUSK` (dev CloudFront) — produkcja niezagrożona
- Raport: `acm-cert-renewal-risk-2026-05-08.md`

### 3. ACM cert migration (zero downtime)

- Nowy cert wydany: `72123357-5a77-4b60-84b1-f59e5282270e`, NotAfter 2026-11-22
  - 7 SANów: `*.skleprenault.pl`, `skleprenault.pl`, `*.sklepdacia.pl`, `*.eshopdacia.sk`, `*.eshoprenault.sk`, `*.eshopdacia.cz`, `*.eshoprenault.cz`
  - ISSUED w ~20s (wszystkie CNAMEs walidacyjne były w DNS)
- CF `E3LC30816FMUSK` zaktualizowany:
  - Nowy cert przypisany
  - 4 martwe aliasy `.hu` usunięte (NXDOMAIN)
  - 12 aktywnych aliasów pozostało
- TLS zweryfikowany openssl (5 SNI aliasów) → `notAfter=Nov 21 2026` ✅
- Stary cert `3be77743` — nieusunięty, rollback gotowy do 2026-05-13
- Dokumentacja: `acm-cert-migration-2026-05-08.md`

**Stan na koniec sesji:**
- Dev CF: nowy cert aktywny, TLS działa ✅
- Prod: niezagrożona, osobne certy ✅
- Stary cert: ISSUED, InUseBy=[], wygasa 2026-05-13

**Następna sesja:**
- [ ] Cleanup: usuń stary cert `3be77743` (po 2026-05-23)
- [ ] Cleanup: usuń orphaned cert `dev.eshoprenault.lt` (`173ae59f`, EXPIRED 2024-08-08)
- [ ] Dodaj CloudWatch alarm `DaysToExpiry < 30` dla nowego certu
- [ ] ECS deploy failure — zbadać przyczynę przed kolejnym deployem
- [ ] Jenkins: preflight check stanu CFN stacka przed deploy (P0)
- [ ] Zwiększyć retencję `/ecs/rshop-dev` z 1 dnia na 14+ dni (P0)
