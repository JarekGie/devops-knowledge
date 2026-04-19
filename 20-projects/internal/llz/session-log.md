# LLZ — Session Log

Format: data, co zrobiono, gdzie skończono, co następne.

---

## 2026-04-18 — Inicjalizacja projektu LLZ w vault

**Co zrobiono:**
- Utworzono sekcję `20-projects/internal/llz/` w vault
- Napisano `context.md` (LLM-ready, standalone)
- Napisano `progress-tracker.md` (template do wypełnienia)
- Zmirrorowano `docs/llz-audit.md` z toolkit → `60-toolkit/llz-audit.md`
- Zidentyfikowano zakres: LLZ v1 = Terraform only, 3 obszary (A/B/C), statyczny audit

**Stan na koniec:**
- Vault gotowy do pracy z LLZ
- Projekty Terraform do audytu: nieznane — wymaga inwentaryzacji
- Toolkit LLZ: zaimplementowany, gotowy do użycia

**Następna sesja:**
- Zinwentaryzować projekty Terraform w organizacji
- Uruchomić `toolkit audit-pack llz-basic` na pierwszym projekcie
- Uzupełnić progress-tracker

---

## 2026-04-18 — Architektura LLZ: idee i backlog

**Co omówiono:**
- LLZ to nie tylko Terraform scaffold — obejmuje observability (aws-logging-audit) i tagging dla wszystkich projektów AWS
- Tryb organizacyjny: toolkit jest projektowy, przejście do org-scope to zmiana filozofii (nie ryzykowna technicznie, wymaga nowej warstwy)
- Plugin API: toolkit ma wewnętrzny system pluginów (BasePlugin), formalizacja jako public API ma sens przy 3+ external consumers
- Org-audit to orchestrator (iteracja + AssumeRole + aggregacja), nie plugin — mylenie tych dwóch to pułapka architektoniczna
- Scope model: `project` vs `org` — musi być zaprojektowany przed implementacją
- LLM wiki pattern (Karpathy): vault jako AI-friendly knowledge base, Confluence jako publish target
- SLA/SLO: availability z CloudWatch TAK, latency p95/p99 wymaga ALB access logs

**Zapisano:**
- `ideas.md` — 6 idei z oceną ryzyka i statusem
- `context.md` — rozszerzony o 3 wymiary LLZ (scaffold, observability, tagging)
- `60-toolkit/observability-ready.md` — mirror capabilities observability

**Stan:**
- Vault LLZ gotowy do pracy
- Brak konkretnego następnego kroku implementacyjnego — materiał do przemyślenia

---

## 2026-04-18 — Org audit read-only: mapa kont i SCP/tag policies

**Co zrobiono:**
- Read-only audit org `o-5c4d5k6io1` z profilu `mako-dc`
- Zmapowano pełne drzewo OU: 5 top-level OU, Workloads ma sub-OU Production/NonProduction
- Zinwentaryzowano wszystkie konta: 11 ACTIVE (scope LLZ), 5 SUSPENDED/CLOSED
- Audyt SCP: tylko Security OU ma custom SCP (2x Control Tower guardrails), reszta = FullAWSAccess
- Audyt Tag Policies (4 polityki na Root): `klient`, `zespol`, `typ`, `projekt` — wszystkie STALE, brakuje aktywnych projektów
- Zidentyfikowano kluczowe findingi (patrz `org-inventory.md`)

**Kluczowe findingi:**
- Production OU (6 kont!) bez żadnych custom SCPs — zero guardrails na prod
- Quarantine bez deny-all SCP (wzorzec zły, nieistotne bo konta CLOSED)
- Tag policies `klient` i `projekt` zawierają tylko stare wartości (renault, brewerseye, gabon) — brakuje rshop, dacia, planodkupow, cc, booking
- Control Tower — partial deployment (guardrails tylko Security OU, nie Workloads)
- CC account = INVITED (zewnętrzne konto klienta w org) — niestandardowy wzorzec

**Zapisano:**
- `org-inventory.md` — pełna mapa org: drzewo OU, konta, SCP, tag policies, findingi, implikacje dla LLZ

**Następna sesja:**
- Zdecydować które konto audytować pierwsze (najprawdopodobniej AssumeRole do każdego konta Prod)
- Zaktualizować tag policies (`klient`, `projekt`, `zespol`)
- Rozstrzygnąć pytania otwarte: kontekst Admin MakoLab, CC account

---

## 2026-04-18 — aws-cloud-platform: scaffold + SCP + tag policies (Terraform)

**Co zrobiono:**
- Podjęto decyzję: CT porzucamy, idziemy własnym zestawem SCP przez Terraform IaC
- Nowy projekt Terraform: `~/projekty/mako/aws-projects/aws-cloud-platform` (gitlab: admin-makolab/dc/aws-cloud-platform)
- State backend: istniejący bucket `864277686382-terraform-state-bucket` + DynamoDB `terraform-state-lock` (profil `mako-dc`)
- Moduł `organization/governance/` — zaimplementowane pliki:
  - `versions.tf`, `backend.tf` — konfiguracja, state key: `organization/governance/terraform.tfstate`
  - `locals.tf` — ID wszystkich OU (z org-inventory) + lista `tag_enforced_for`
  - `scps.tf` — 2 SCP: `llz-quarantine-deny-all` (Quarantine OU) + `llz-workloads-baseline` (Workloads OU: blokada CloudTrail, Config, S3 public)
  - `tag_policies.tf` — 4 polityki zaktualizowane (klient, zespol, typ, projekt) + `import {}` bloki dla istniejących policy IDs
  - `outputs.tf` — SCP IDs
- Tag policies zamknięte: `klient` i `projekt` uzupełnione o wszystkie aktywne projekty z org-inventory
- `zespol` — pozostaje legacy (renault, php), wymaga danych z HR przed aktualizacją

**Otwarte weryfikacje (przed `terraform apply`):**
- `klient=booking-online` — zweryfikuj actual tag value na zasobach konta Booking_Online
- `klient=cc` — zweryfikuj actual tag value (konto INVITED)
- `klient=dacia` vs `klient=renault` — sprawdź tagowanie zasobów w koncie dacia-asystent
- `tag_zespol` — zaktualizuj po zebraniu aktualnych nazw zespołów

**Następna sesja:**
- Zweryfikować wartości tag policies przez: toolkit audit-pack tagging (per account AssumeRole)
- Zdecydować o dodaniu `modules/platform/` do terraform-aws-modules (pattern dla org projects)
- Rozstrzygnąć CC i Admin MakoLab pytania otwarte
- Commit + push aws-cloud-platform do gitlab

---

## 2026-04-18 — terraform apply: SCP + tag policies LIVE

**Co zrobiono:**
- `terraform apply` na `organization/governance/` — sukces, 0 błędów
- Zaaplikowane: 8 import, 4 add, 4 change, 0 destroy
- SCP `llz-quarantine-deny-all` (p-wxsdn4cy) → Quarantine OU
- SCP `llz-workloads-baseline` (p-flr98jkj) → Workloads OU (Production + NonProduction dziedziczą)
- Tag policies zaimportowane do state + zaktualizowane: klient (+6 wartości), projekt (+7 wartości)
- Koszt: $0/mies. (Organizations SCP i tag policies są free)
- Infracost skonfigurowany w workflow (tfplan)

**Stan AWS po apply:**
- Production OU: ma teraz guardrails (CloudTrail/Config nie można wyłączyć, S3 public access zablokowany)
- Quarantine OU: deny-all SCP (wzorzec na przyszłość)
- Tag policies: aktualne dla wszystkich aktywnych projektów

**Następna sesja:**
- Zdecydować o `modules/platform/` w terraform-aws-modules
- Rozstrzygnąć CC i Admin MakoLab pytania otwarte
- Wdrożyć LLZ tag standard (klient/projekt/typ) na projektach — teraz żadne konto go nie używa

---

## 2026-04-18 — weryfikacja tag values + commit do gitlab

**Co zrobiono:**
- Commit + push aws-cloud-platform (886364a, 3287f4c) do gitlab
- Weryfikacja live tagów w kontach booking (profil `booking`) i dacia (profil `dacia`)
- Finding: żadne konto nie używa tagów `klient`/`projekt` (lowercase) — używają `Project` (PascalCase)
- Wniosek: tag policies są bezpieczne (nie psują istniejących zasobów), ale enforcement jest martwy dopóki LLZ standard nie zostanie wdrożony
- Poprawione wartości: `booking-online` → `booking`, `dacia` → `dacia-asystent` (zweryfikowane z live tagów)
- Brak profilu AWS dla CC — nie można zweryfikować; `cc` zostaje jako placeholder

**Stan tag policies (zweryfikowany):**
- `klient`: booking ✓, dacia-asystent ✓, rshop (niezweryfikowany — profil rshop istnieje)
- `projekt`: booking ✓, dacia-asystent ✓

**Następna sesja:**
- Sprawdzić rshop: `aws resourcegroupstaggingapi get-resources --profile rshop` — jakie tagi?
- Zdecydować o `modules/platform/` w terraform-aws-modules
- Rozstrzygnąć CC i Admin MakoLab pytania otwarte

---

## 2026-04-18 — Centralne logowanie i dashboardy (CW cross-account observability)

**Co zrobiono:**
- Zinwentaryzowano konta org: `makolab_monitoring` CLOSED (nie do reaktywacji), użyto `monitoring-nagios-bot` (814662658531)
- Potwierdzono dostęp do `logArchive` (771354139056) i `monitoring-tbd` (814662658531)
- Odkryto istniejący CloudTrail org trail (`org-baseline-cloudtrail`) → S3 w LogArchiveNew ✓
- Odkryto istniejący OAM sink `observabilitySink` w monitoring-nagios-bot (ręcznie tworzony)
- Stworzono stack Terraform: `aws-cloud-platform/platform/monitoring/`
- Zaimportowano istniejące zasoby (sink, policy, linki rshop i booking)
- Dodano brakujące linki: dacia (nowy), planodkupow (import + update)
- Zaktualizowano wszystkie linki: Metric → Metric + Logs + XRay
- Sink policy zmieniona z per-account ARN → org-wide `PrincipalOrgID`

**Stan na koniec:**
- CW cross-account observability: 4 konta (rshop, booking, planodkupow, dacia) → sink w monitoring-nagios-bot
- Wszystko pod Terraformem, state w `864277686382-terraform-state-bucket`
- Koszt: $0

**Następna sesja:**
- Stworzyć dashboardy CW w koncie monitoring
- Opcjonalnie: AWS Config org aggregator (~$3-5/mies.)
- Opcjonalnie: CW Logs → S3 eksport (audit trail logów)

---

## 2026-04-18 — toolkit check na infra-bbmt: analiza tagowania

**Co zrobiono:**
- Uruchomiono `toolkit check` na infra-bbmt (konto planodkupow, 333320664022)
- Dodano `check_cfn_deployment_contexts()` do `toolkit doctor` — weryfikuje obecność `deployment_contexts` w project.yaml
- Naprawiono project.yaml: `stack_prefixes: [planodkupow]`, `root_template: ROOT.yml`, `deployment_contexts` (qa/uat/dev), `finops` tiers (bez prod)
- Zidentyfikowano i przeanalizowano 104 zasoby flagowane przez audit tagowania

**Wyniki analizy 104 zasobów:**
- 92 zasoby: mają `Environment`+`Project: planodkupow` — brakuje `Owner`, `ManagedBy`, `CostCenter`
- 12 zasobów: 0 tagów — SGs (6x), route table (1x), VPC endpoints (5x)
- Żaden zasób NIE używa starych kluczy (Client/Team/Provisioner) — te są TYLKO na CFN stackach, nie propagują się do zasobów
- Wszystkie 104 zasoby można otagować przez API bez dotykania CFN

**CFN_TAG_003 (10 warnings):**
- bbmt ROOT.yml nested stacki nie mają explicit Tags (w przeciwieństwie do infra-rshop gdzie każdy nested stack ma pełne LLZ tags)
- Tagi w bbmt przychodzą przez Jenkins pipeline ze starymi kluczami (Client/Team/Provisioner/Environment/Project)
- Fix: dodanie Tags do nested stacków w ROOT.yml — to tag-only update (nie replace), bezpieczne dla ALB i CloudFront
- Wymaga koordynacji z teamem przed wdrożeniem

**Poprawki w project.yaml (lokalne, gitignore):**
- `tag_semantics.project.values`: dodano `planodkupow` (bo zasoby mają `Project: planodkupow`, nie `bbmt`)

**Następna sesja:**
- Zdecydować czy/kiedy dodać LLZ tags do ROOT.yml nested stacków (maintenance window)
- Uruchomić `toolkit apply-pack tagging --dry-run` → review → apply (bezpieczne, bez CFN)
- Sprawdzić rshop live tags (pending z poprzedniej sesji)
- AWS Config org aggregator (~$3-5/mies.) — decyzja

---

## 2026-04-18 — CFN tagging deployment na bbmt: incydent i RCA

**Co zrobiono:**
- Dodano LLZ Tags do ROOT.yml nested stacków (VPC, SG, S3, DB, Redis, ECS, RMQ, ALB) — bez CFStack
- Wgrano ROOT.yml i REDIS.yml na S3 `planodkupow-cf` (bucket wersjonowany)
- Deployment QA: Replace existing template → `https://planodkupow-cf.s3.eu-central-1.amazonaws.com/ROOT.yml`

**Kluczowe odkrycia:**
- "Use existing template" w konsoli AWS używa wersji przechowywanej w CFN, NIE pobiera z S3 — wymagane "Replace existing template"
- "Replace existing template" triggeruje update WSZYSTKICH nested stacków, nie tylko zmodyfikowanych — strategia "pomijamy ALBStack" działa tylko gdy template nie jest podmieniony
- ALBStack i CFStack zaktualizowały się mimo braku Tags w poprzednim deploy (Replace = wszystko)

**Incydent — Redis EOL:**
- RedisStack → `UPDATE_FAILED`: `Cannot find version 5.0.0 for redis — InvalidParameterCombination`
- Redis 5.0.0 wycofany przez AWS (EOL), live klastry już na 5.0.6 (ręcznie zupgradowane, drift z template)
- Fix: `REDIS.yml` → `EngineVersion: 5.0.6` (wyrównanie do live state, wgrane na S3)
- DBStack → `UPDATE_FAILED` (anulowany, nie własna awaria)

**Stan po incydencie:**
- planodkupow-qa: `UPDATE_ROLLBACK_IN_PROGRESS` — zakleszczony na VPCStack rollback
- VPCStack: `UPDATE_ROLLBACK_IN_PROGRESS` od 18:32:22 — zero eventów po tym, deadlock
- `continue-update-rollback` niedostępne (działa tylko na `UPDATE_ROLLBACK_FAILED`)
- Czekamy na timeout CFN (30-60 min) → przejście do `UPDATE_ROLLBACK_FAILED` → odblokowanie

**Stan rollbacku (sobota wieczór — zostawione do poniedziałku):**
- `planodkupow-qa`: `UPDATE_ROLLBACK_FAILED` — nie kasujemy, nie deployujemy
- Kolejne błędy rollbacku: VPCStack (Internal Failure), RabbitMQStack/BasicBroker (Lambda: "This account is suspended")
- CFN nie pozwala skipować nested stacków z root stacka → pętla bez wyjścia przez API
- QA niedostępne do poniedziałku

**Do zbadania w poniedziałek:**
- Dlaczego Lambda "account suspended" dla AmazonMQ custom resource?
- Opcja A: AWS Support ticket o custom resource Lambda issue
- Opcja B: delete planodkupow-qa + redeploy (~30-60 min, utrata stanu QA)

**Pliki zmienione lokalnie i na S3:**
- `infra-bbmt/cloudformation/ROOT.yml` — Tags na 8 nested stackach (bez CFStack), wgrane na S3
- `infra-bbmt/cloudformation/REDIS.yml` — EngineVersion: 5.0.6, wgrane na S3
- Poprzednia wersja ROOT.yml na S3: `VersionId: Qn8EJ.mwtuYz43GF1JEl.JeV6t2OOsEQ` (2023-06-15)

---

<!-- Template:

## YYYY-MM-DD — [opis]

**Co zrobiono:**
-

**Stan na koniec:**
-

**Następna sesja:**
-

-->
