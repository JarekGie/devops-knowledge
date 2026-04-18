---
project: llz
type: internal
tags: [llz, aws, organizations, org-audit, inventory, governance]
created: 2026-04-18
updated: 2026-04-18
---

# LLZ — Inwentarz Organizacji AWS

> Read-only audit z konta `makolab_dc` (profil `mako-dc`). Standalone.

## Org overview

| Parametr | Wartość |
|----------|---------|
| Org ID | `o-5c4d5k6io1` |
| Root ID | `r-z8np` |
| Management account | `864277686382` — `makolab_dc` (dc@makolab.com) |
| Feature set | ALL |
| SCP | ENABLED |
| TAG_POLICY | ENABLED |

---

## Struktura OU (drzewo)

```
Root (r-z8np)
│
├── [MGMT] makolab_dc  864277686382  ACTIVE
│
├── Platform  (ou-z8np-40w1yjwg)
│   ├── Admin MakoLab          647075515164  ACTIVE  joined: 2026-03-02
│   └── monitoring-nagios-bot  814662658531  ACTIVE  joined: 2023-05-16
│
├── Quarantine  (ou-z8np-807kci0k)
│   ├── Audit             012086764624  SUSPENDED/CLOSED  joined: 2025-08-21
│   ├── MakolabDev        442703586623  SUSPENDED/CLOSED  joined: 2019-07-03
│   ├── Log Archive       518286664393  SUSPENDED/CLOSED  joined: 2025-08-21
│   └── makolab_monitoring 400837535641 SUSPENDED/CLOSED  joined: 2023-05-11
│
├── Sandbox  (ou-z8np-dqtp5qcx)
│   ├── pbms  378131232770  SUSPENDED/CLOSED  joined: 2026-03-22
│   └── lab   052845428574  ACTIVE            joined: 2026-02-24
│
├── Security  (ou-z8np-enuc6lre)
│   └── LogArchiveNew  771354139056  ACTIVE  joined: 2026-02-14
│
└── Workloads  (ou-z8np-ny08nzho)
    ├── Production  (ou-z8np-jomloow3)
    │   ├── planodkupow    333320664022  ACTIVE          joined: 2021-01-26
    │   ├── planodkupowv1  292464762806  ACTIVE          joined: 2023-09-13
    │   ├── Booking_Online 128264038676  ACTIVE          joined: 2021-05-05
    │   ├── RShop          943111679945  ACTIVE          joined: 2022-03-17
    │   ├── dacia-asystent 074412166613  ACTIVE          joined: 2026-03-03
    │   └── CC             943696080604  ACTIVE (INVITED) joined: 2024-09-10
    │
    └── NonProduction  (ou-z8np-ydx42f96)
        └── DRP-TFS  613448424242  ACTIVE  joined: 2023-10-19
```

---

## Aktywne konta (LLZ scope)

| Konto | Account ID | OU | Uwagi |
|-------|-----------|-----|-------|
| Admin MakoLab | 647075515164 | Platform | nowe konto platform (2026-03) |
| monitoring-nagios-bot | 814662658531 | Platform | legacy nagios monitoring |
| lab | 052845428574 | Sandbox | laboratorium |
| LogArchiveNew | 771354139056 | Security | nowy log archive (2026-02) |
| planodkupow | 333320664022 | Prod | projekt klienta |
| planodkupowv1 | 292464762806 | Prod | v1 tego samego projektu |
| Booking_Online | 128264038676 | Prod | projekt klienta |
| RShop | 943111679945 | Prod | ← już audytowany (tagging+observability) |
| dacia-asystent | 074412166613 | Prod | nowy projekt (2026-03) |
| CC | 943696080604 | Prod | konto INVITED — zewnętrzne |
| DRP-TFS | 613448424242 | NonProd | TFS/DevOps infra |

**Wykluczone z LLZ audit:** konta SUSPENDED/CLOSED (Quarantine + pbms).

---

## SCP — stan obecny

| OU | Custom SCP | Uwagi |
|----|-----------|-------|
| Root | tylko `FullAWSAccess` | brak org-wide guardrails |
| Platform | tylko `FullAWSAccess` | brak ograniczeń |
| Quarantine | tylko `FullAWSAccess` | **PROBLEM** — brak deny-all |
| Sandbox | tylko `FullAWSAccess` | brak ograniczeń |
| Security | `FullAWSAccess` + 2x CT guardrails | jedyne custom SCP w org |
| Workloads | tylko `FullAWSAccess` | brak guardrails produkcji |
| Production | tylko `FullAWSAccess` | **PROBLEM** — brak ochrony prod |
| NonProduction | tylko `FullAWSAccess` | brak ograniczeń |

### Control Tower guardrails (Security OU only)

CT był częściowo wdrożony — guardrails tylko na Security OU. Chronią:
- `GRLOGGROUPPOLICY` — blokada usuwania CT log groups / zmiany retention
- `GRCTAUDITBUCKETPOLICYCHANGESPROHIBITED` — S3 CT audit bucket policy
- `GRCTAUDITBUCKETENCRYPTIONCHANGESPROHIBITED` — S3 CT encryption
- `GRCTAUDITBUCKETLOGGINGCONFIGURATIONCHANGESPROHIBITED`
- `GRCTAUDITBUCKETLIFECYCLECONFIGURATIONCHANGESPROHIBITED`
- `GRAUDITBUCKETDELETIONPROHIBITED` — usunięcie CT S3 bucket
- `GRCLOUDTRAILENABLED` — modyfikacja CT CloudTrail trail
- `GRCONFIGRULEPOLICY` — modyfikacja CT Config rules
- `GRCONFIGENABLED` — wyłączenie Config recordera
- `GRCONFIGAGGREGATIONAUTHORIZATIONPOLICY`
- `GRCONFIGRULETAGSPOLICY`
- `GRCLOUDWATCHEVENTPOLICY` — EventBridge CT rules
- `GRLAMBDAFUNCTIONPOLICY` — CT Lambda functions
- `GRSNSTOPICPOLICY` / `GRSNSSUBSCRIPTIONPOLICY` — CT SNS topics
- `GRIAMROLEPOLICY` — CT IAM roles i stacksets-exec-*

**Wniosek:** CT deployment jest niekompletny. Guardrails są TYLKO na Security OU — Workloads/Production nie ma żadnej ochrony CT.

---

## Tag Policies — stan obecny

Polityki zdefiniowane na Root → dziedziczone przez całą org.

| Policy | Tag key | Dozwolone wartości | Status |
|--------|---------|-------------------|--------|
| `klient` | `klient` | `renault`, `brewerseye`, `teatrmuzyczny` | **STALE** — brakuje projektów |
| `zespol` | `zespol` | `renault`, `php` | **STALE** — bardzo wąski zakres |
| Typ Projektu | `typ` | `prod`, `dev`, `uat`, `poc`, `test`, `qa` | OK — generyczny |
| `projekt` | `projekt` | `brewerseye`, `gabon` | **STALE** — brakuje projektów |

### Problemy z tag policies

Aktywne projekty NIE są objęte politykami `klient` i `projekt`:

| Konto | Projekt | W `klient`? | W `projekt`? |
|-------|---------|------------|--------------|
| planodkupow | planodkupow | NIE | NIE |
| Booking_Online | booking | NIE | NIE |
| RShop | rshop | NIE | NIE |
| dacia-asystent | dacia | NIE | NIE |
| CC | cc | NIE | NIE |

**Wniosek:** Tag policies są skonfigurowane ale nie zaktualizowane od lat. Enforcement jest aktywny ale scope `enforced_for` jest szeroki (EC2, S3, ECS, RDS itd.) — każdy zasób tych typów z tagiem `klient=X` musi mieć X z listy. W praktyce zasoby bez tagu `klient` przechodzą bez błędu (polityka enforces wartości, nie wymaga obecności tagu).

---

## Obserwacje i finding dla LLZ design

### Krytyczne

1. **Quarantine bez deny-all SCP** — OU Quarantine powinno mieć SCP blokujące wszystkie akcje (`"Effect": "Deny", "Action": "*"`). Nieistotne teraz (konta CLOSED) ale wzorzec jest zły.

2. **Production bez custom SCPs** — 6 aktywnych kont produkcyjnych bez żadnych guardrails: można wyłączyć CloudTrail, tworzyć zasoby w dowolnym regionie, brak ochrony przed accidental delete. LLZ powinno to adresować.

3. **Tag policies stale** — `klient` i `projekt` nie zawierają wartości dla większości aktywnych projektów. Przed wdrożeniem `enforce_tagging` w toolkit trzeba zaktualizować listy dozwolonych wartości.

### Architektoniczne

4. **Control Tower — partial deployment** — CT guardrails tylko na Security OU. Albo CT był zaczęty i porzucony, albo selektywnie wdrożony dla log archive. LogArchiveNew + AWSControlTowerExecution role sugerują, że CT jest aktywny dla Security ale nie dla Workloads.

5. **CC account (INVITED)** — konto zewnętrzne (klienta?) dołączone do org. Niestandarowy wzorzec. Wymaga wyjaśnienia czy to konto docelowe dla delivery czy tymczasowe.

6. **Admin MakoLab (2026-03-02)** — nowe konto Platform. Może to być inicjatywa separacji platform/workloads. Kontekst nieznany — do wyjaśnienia.

7. **DRP-TFS w NonProduction** — konto TFS/Azure DevOps infra w NonProduction. Czy to nie powinna być część Platform OU?

8. **planodkupow vs planodkupowv1** — dwa konta dla tego samego projektu. v1 = refaktoring/nowa wersja w osobnym koncie. Wzorzec: konto per wersja projektu.

---

## LLZ design — implikacje

### org-audit scope (IDEA-001)

Zidentyfikowane konta do iteracji:
```yaml
org_scope:
  skip_status: [SUSPENDED, CLOSED]
  skip_accounts: [864277686382]  # management account
  workload_ous:
    - production: ou-z8np-jomloow3    # 6 kont
    - nonproduction: ou-z8np-ydx42f96  # 1 konto
  platform_ous:
    - platform: ou-z8np-40w1yjwg      # 2 konta
    - security: ou-z8np-enuc6lre      # 1 konto
    - sandbox: ou-z8np-dqtp5qcx       # 1 aktywne
```

### Tag policy alignment

Przed wdrożeniem LLZ tagging check — zaktualizować tag policies:
- `klient`: dodać `planodkupow`, `renault-booking`, `rshop`, `dacia`, `cc`, `makolab`
- `projekt`: zaktualizować do pełnej listy aktywnych projektów
- `zespol`: rozszerzyć o obecne zespoły

### SCP roadmap (pod LLZ governance)

Priorytety:
1. **Quarantine deny-all** — wzorzec, niski koszt, wysoka wartość jako demonstracja
2. **Production baseline SCP** — blokada wyłączania CloudTrail, region restriction
3. **Workloads baseline SCP** — require-tags na tworzenie zasobów (opcjonalnie)

---

## Następne kroki

- [ ] Wyjaśnić kontekst `Admin MakoLab` — co to konto robi w Platform?
- [ ] Wyjaśnić `CC` (INVITED) — konto klienta czy wewnętrzne?
- [ ] Zaktualizować tag policies (`klient`, `projekt`, `zespol`)
- [ ] Zaplanować per-konto audit: toolkit `assume-role` do każdego konta Workloads/Production
- [ ] Zdecydować czy CT rozszerzać czy zastąpić własnym SCP zestawem

## Powiązane

- [[context]] — LLZ overview
- [[ideas]] — IDEA-001 org-scope, IDEA-003 scope model
- [[session-log]] — historia sesji
