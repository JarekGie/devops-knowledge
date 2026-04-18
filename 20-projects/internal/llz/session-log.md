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
- `terraform init && terraform plan` — zobaczyć co Terraform importuje vs tworzy
- Zweryfikować wartości tag policies przez: toolkit audit-pack tagging (per account AssumeRole)
- Zdecydować o dodaniu `modules/platform/` do terraform-aws-modules (pattern dla org projects)
- Rozstrzygnąć CC i Admin MakoLab pytania otwarte

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
