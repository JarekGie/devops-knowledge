---
title: root-mfa-recovery-plan
client: mako
project: aws-cloud-platform
domain: client-work
document_type: operational-plan
classification: internal
tags:
  - aws
  - security
  - root
  - mfa
  - organizations
  - nis2
created: "2026-05-07"
updated: "2026-05-07"
discovery_date: "2026-05-07"
discovery_status: complete
---

# AWS Root MFA Recovery & Remediation — Plan operacyjny

#aws #security #mfa #organizations #mako

**Data discovery:** 2026-05-07 (live scan)
**Zakres:** 15 aktywnych kont w Organizations o-5c4d5k6io1 (2 konta usunięte z org)

---

## 1. Executive Summary

Discovery zakończone. Sytuacja jest poważna, ale bez aktywnych root access keys.

**Stan krytyczny:**
- 9 z 12 ACTIVE kont nie ma root MFA
- 8 z tych 9 kont jest objętych SCP `llz-security-baseline` z `DenyRootUserActions: "Action": "*"` → **root MFA enrollment zablokowany**
- 1 konto (LogArchiveNew) wymaga MFA i nie jest zablokowane SCP
- Brak root access keys w całej org — ryzyko ograniczone, ale niezamknięte

**Co jest bezpieczne:**
- makolab_dc (management): MFA=true ✅, brak kluczy ✅
- Admin MakoLab: MFA=true ✅, brak kluczy ✅
- monitoring-nagios-bot: MFA=true ✅, brak kluczy ✅

**Nowe odkrycie vs poprzedni scan (2026-05-01):**
- CT guardrails (p-wacgblah, p-yncf8tm8) już nie istnieją w org
- Nowy SCP `llz-security-baseline` (p-8wat7tjs) wdrożony — blokuje root w 3 OU
- Konta `Audit` (012086764624) i `Log Archive stary` (518286664393) usunięte z organizacji

---

## 2. Discovery Findings — wyniki live 2026-05-07

### 2.1 Root email per konto

| Account | ID | Email | Status |
|---------|-----|-------|--------|
| makolab_dc | 864277686382 | dc@makolab.com | ACTIVE |
| Admin MakoLab | 647075515164 | admin@makolab.pl | ACTIVE |
| monitoring-nagios-bot | 814662658531 | aws@makolab.pl | ACTIVE |
| lab | 052845428574 | lab@makolab.pl | ACTIVE |
| LogArchiveNew | 771354139056 | log-archive-new@makolab.pl | ACTIVE |
| planodkupow | 333320664022 | planodkupow@makolab.pl | ACTIVE |
| planodkupowv1 | 292464762806 | planodkupow1@makolab.pl | ACTIVE |
| Booking_Online | 128264038676 | jaroslaw.golab+booking@makolab.com | ACTIVE |
| RShop | 943111679945 | jaroslaw.golab+rshop@makolab.com | ACTIVE |
| dacia-asystent | 074412166613 | dacia-asystent@makolab.pl | ACTIVE |
| CC | 943696080604 | CCAWS@makolab.com | ACTIVE |
| DRP-TFS | 613448424242 | drptfs@makolab.pl | ACTIVE |
| pbms | 378131232770 | pbms@makolab.pl | SUSPENDED |
| MakolabDev | 442703586623 | jaroslaw.golab+makodev@makolab.com | SUSPENDED |
| makolab_monitoring | 400837535641 | tymur.myma@makolab.com | SUSPENDED |
| ~~Audit~~ | ~~012086764624~~ | — | **USUNIĘTE Z ORG** |
| ~~Log Archive stary~~ | ~~518286664393~~ | — | **USUNIĘTE Z ORG** |

### 2.2 Root MFA i access keys — wyniki live

| Account | ID | OU | MFA active | Key1 | Key2 | Źródło |
|---------|-----|-----|-----------|------|------|--------|
| makolab_dc | 864277686382 | Root (direct) | **true ✅** | false ✅ | false ✅ | credential report |
| Admin MakoLab | 647075515164 | Platform | **true ✅** | false ✅ | false ✅ | credential report |
| monitoring-nagios-bot | 814662658531 | Platform | **true ✅** | false ✅ | false ✅ | credential report |
| LogArchiveNew | 771354139056 | Security | **false ❌** | false ✅ | false ✅ | credential report |
| lab | 052845428574 | Sandbox | **false ❌** | false ✅ | false ✅ | credential report |
| planodkupow | 333320664022 | Workloads/Prod | **false ❌** | false ✅ | false ✅ | credential report |
| planodkupowv1 | 292464762806 | Workloads/Prod | **false ❌** | false ✅ | false ✅ | credential report |
| Booking_Online | 128264038676 | Workloads/Prod | **false ❌** | false ✅ | false ✅ | credential report |
| RShop | 943111679945 | Workloads/Prod | **false ❌** | false ✅ | false ✅ | credential report |
| dacia-asystent | 074412166613 | Workloads/Prod | **false ❌** | false ✅ | false ✅ | credential report |
| CC | 943696080604 | Workloads/Prod | **false ❌** | false ✅ | false ✅ | credential report |
| DRP-TFS | 613448424242 | Workloads/NonProd | **false ❌** | false ✅ | false ✅ | credential report |
| pbms | 378131232770 | Sandbox | SUSPENDED | n/a | n/a | — |
| MakolabDev | 442703586623 | Quarantine | SUSPENDED | n/a | n/a | — |
| makolab_monitoring | 400837535641 | Quarantine | SUSPENDED | n/a | n/a | — |

**Podsumowanie:** 3/12 ACTIVE kont ma root MFA. 9/12 wymaga enrollment. Zero root access keys w całej org.

---

## 3. SCP Analysis — stan live 2026-05-07

### 3.1 Aktywne SCPs (zweryfikowane live)

| SCP | ID | Targets | Content |
|-----|-----|---------|---------|
| FullAWSAccess | p-FullAWSAccess | Root (inherited all) | Allow * |
| **llz-security-baseline** | **p-8wat7tjs** | **Production OU, NonProduction OU, Sandbox OU** | **DenyDisableSecurityServices + DenyRootUserActions** |
| bilingi | p-c6iuxb0c | **brak targets** | unattached |
| DEV | p-yfwlx134 | MakolabDev (SUSPENDED) | untracked |

**Uwaga:** CT guardrails (p-wacgblah, p-yncf8tm8, p-26aljn7o) z poprzedniego scanu (2026-05-01) już nie istnieją.

### 3.2 KRYTYCZNY BLOKER — llz-security-baseline DenyRootUserActions

```json
{
    "Sid": "DenyRootUserActions",
    "Effect": "Deny",
    "Action": "*",
    "Resource": "*",
    "Condition": {
        "StringLike": {
            "aws:PrincipalArn": "arn:aws:iam::*:root"
        }
    }
}
```

**Impact:** Blokuje WSZYSTKIE akcje root (w tym `iam:CreateVirtualMFADevice`, `iam:EnableMFADevice`) w:
- Production OU → 6 kont
- NonProduction OU → 1 konto
- Sandbox OU → 2 konta (1 ACTIVE: lab; 1 SUSPENDED: pbms)

**Explicit Deny wins** — FullAWSAccess Allow nie przebija tego Deny.

**Root login do konsoli (authentication): nie jest blokowany przez SCP** — możesz się zalogować.
**Root MFA enrollment (IAM API call przez konsolę): ZABLOKOWANY** — IAM nie wykona operacji.

### 3.3 Konta NIE objęte blokerem SCP

| Account | OU | SCP bloker | Ścieżka recovery |
|---------|-----|-----------|-----------------|
| makolab_dc (864277686382) | Root (bezpośrednio) | BRAK (management immune) | **DONE** ✅ |
| Admin MakoLab (647075515164) | Platform OU | BRAK | **DONE** ✅ |
| monitoring-nagios-bot (814662658531) | Platform OU | BRAK | **DONE** ✅ |
| LogArchiveNew (771354139056) | Security OU | BRAK | **Standardowa — możliwa natychmiast** |
| MakolabDev (442703586623) | Quarantine OU | BRAK (DEV SCP — sprawdź treść) | SUSPENDED — niski priorytet |
| makolab_monitoring (400837535641) | Quarantine OU | BRAK | SUSPENDED — niski priorytet |

---

## 4. Risk Matrix — zaktualizowana po discovery

| Account | ID | OU | MFA | SCP bloker | Email typ | Poziom ryzyka |
|---------|-----|-----|-----|-----------|----------|--------------|
| makolab_dc | 864277686382 | Root | ✅ true | brak | dc@makolab.com (shared?) | **LOW** (MFA OK) |
| Admin MakoLab | 647075515164 | Platform | ✅ true | brak | admin@makolab.pl (shared!) | **LOW** (MFA OK) |
| monitoring-nagios-bot | 814662658531 | Platform | ✅ true | brak | aws@makolab.pl (shared!) | **LOW** (MFA OK) |
| LogArchiveNew | 771354139056 | Security | ❌ false | brak | log-archive-new@makolab.pl | **MEDIUM** |
| lab | 052845428574 | Sandbox | ❌ false | DenyRootUserActions | lab@makolab.pl | **HIGH** (SCP bloker) |
| planodkupow | 333320664022 | Workloads/Prod | ❌ false | DenyRootUserActions | planodkupow@makolab.pl | **HIGH** (SCP bloker) |
| planodkupowv1 | 292464762806 | Workloads/Prod | ❌ false | DenyRootUserActions | planodkupow1@makolab.pl | **HIGH** (SCP bloker) |
| Booking_Online | 128264038676 | Workloads/Prod | ❌ false | DenyRootUserActions | +booking@makolab.com (personal!) | **HIGH + email risk** |
| RShop | 943111679945 | Workloads/Prod | ❌ false | DenyRootUserActions | +rshop@makolab.com (personal!) | **HIGH + email risk** |
| dacia-asystent | 074412166613 | Workloads/Prod | ❌ false | DenyRootUserActions | dacia-asystent@makolab.pl | **HIGH** (SCP bloker) |
| CC | 943696080604 | Workloads/Prod | ❌ false | DenyRootUserActions | CCAWS@makolab.com | **HIGH** (SCP bloker) |
| DRP-TFS | 613448424242 | Workloads/NonProd | ❌ false | DenyRootUserActions | drptfs@makolab.pl | **HIGH** (SCP bloker) |
| pbms | 378131232770 | Sandbox | SUSPENDED | DenyRootUserActions | pbms@makolab.pl | LOW (SUSPENDED) |
| MakolabDev | 442703586623 | Quarantine | SUSPENDED | DEV SCP | personal email | LOW (SUSPENDED) |
| makolab_monitoring | 400837535641 | Quarantine | SUSPENDED | brak | tymur.myma@makolab.com (ex-pracownik?) | **MEDIUM** (ex-employee email!) |

### Specjalne ryzyki email

| Ryzyko | Konta | Opis |
|--------|-------|------|
| Personal email root | Booking_Online (jaroslaw.golab+booking@), RShop (jaroslaw.golab+rshop@) | Konto root na prywatny email pracownika — po odejściu pracownika = lockout |
| Shared email bez właściciela | Admin MakoLab (admin@makolab.pl), monitoring-nagios-bot (aws@makolab.pl) | Kto ma dostęp do tej skrzynki? |
| Ex-employee email | makolab_monitoring (tymur.myma@makolab.com) | Tymur Myma — weryfikuj czy nadal pracownik |

---

## 5. Recovery Strategy

### 5.1 Priorytet remediacji

| Kolejność | Konto | Uzasadnienie |
|-----------|-------|-------------|
| 1 | LogArchiveNew (771354139056) | Security OU — brak SCP, można działać natychmiast |
| 2 | Workloads/Prod (6 kont) | Produkcja — wymaga Recovery OU procedure |
| 3 | DRP-TFS (613448424242) | NonProd — wymaga Recovery OU procedure |
| 4 | lab (052845428574) | Sandbox — wymaga Recovery OU procedure |
| 5 | SUSPENDED konta | Niski priorytet |

### 5.2 Ścieżka A — Konta bez SCP bloker (LogArchiveNew)

**SAFE**

```
Prerequisite: dostęp do log-archive-new@makolab.pl

1. Idź do console.aws.amazon.com
2. "Sign in as root account"
3. Podaj: log-archive-new@makolab.pl
4. Podaj hasło (z KeePass)
5. Jeśli hasło nieznane → "Forgot password" → link na maila
6. Po zalogowaniu: górny prawy róg → Account Name → "Security credentials"
7. MFA section → "Assign MFA device" → "Authenticator app"
8. Zeskanuj QR code przez kontrolowany vault (NIE KeePass)
9. Podaj 2 kolejne kody → "Add MFA"
10. Wyloguj → zaloguj ponownie → zweryfikuj że MFA wymagane
11. Sprawdź credential report: mfa_active = true
```

### 5.3 Ścieżka B — Konta z SCP DenyRootUserActions (8 kont)

**RISKY** — wymaga Recovery OU lub modyfikacji SCP

#### Opcja B1 — Recovery OU (preferowana, mniejszy blast radius)

```bash
# Krok 1: Utwórz Recovery OU (bez SCP llz-security-baseline)
# UWAGA: Recovery OU jest poza Production/NonProd/Sandbox → SCP nie dziedziczone
aws organizations create-organizational-unit \
  --parent-id r-z8np \
  --name "MFA-Recovery" \
  --profile cd-management
# → zapisz OU ID (np. ou-z8np-XXXXXXXX)

# Krok 2: Przesuń konto do Recovery OU (jedno na raz)
aws organizations move-account \
  --account-id TARGET_ACCOUNT_ID \
  --source-parent-id ORIGINAL_OU_ID \
  --destination-parent-id RECOVERY_OU_ID \
  --profile cd-management

# Krok 3: Odczekaj ~30 sekund (SCP propagation)
sleep 30

# Krok 4: Zaloguj się jako root konta docelowego i wykonaj Ścieżkę A

# Krok 5: Zweryfikuj MFA enrolled
aws iam generate-credential-report --profile cd-TARGET && sleep 5
aws iam get-credential-report --profile cd-TARGET \
  --query 'Content' --output text | base64 --decode | \
  awk -F',' '$1=="<root_account>" {print "MFA="$8}'
# Oczekiwane: MFA=true

# Krok 6: Przesuń konto z powrotem do oryginalnego OU
aws organizations move-account \
  --account-id TARGET_ACCOUNT_ID \
  --source-parent-id RECOVERY_OU_ID \
  --destination-parent-id ORIGINAL_OU_ID \
  --profile cd-management

# Krok 7: Zweryfikuj że SCP znów działa (root nie może wykonać testu IAM)
# Powtarzaj kroki 2-7 dla każdego konta
```

> **SAFE:** Recovery OU nie ma SCP → root może działać. Blast radius = jedno konto na raz.

#### Opcja B2 — Tymczasowe wykluczenie konta z SCP (alternatywna)

**RISKY** — zmiana SCP targets

```bash
# Odepnij llz-security-baseline od jednego OU na czas remediacji
aws organizations detach-policy \
  --policy-id p-8wat7tjs \
  --target-id ou-z8np-jomloow3 \
  --profile cd-management

# Wykonaj enrollment MFA dla wszystkich kont w tym OU
# ...

# Przywróć SCP
aws organizations attach-policy \
  --policy-id p-8wat7tjs \
  --target-id ou-z8np-jomloow3 \
  --profile cd-management
```

> **RISKY:** Przez czas remediacji całe Production OU bez DenyRootUserActions. Możliwe okno na root operations w innych kontach.

**Rekomendacja: Opcja B1 (Recovery OU) — jedno konto na raz.**

### 5.4 Specjalna uwaga — emaile personal/shared

| Konto | Email | Akcja przed remediacja |
|-------|-------|----------------------|
| Booking_Online (128264038676) | jaroslaw.golab+booking@makolab.com | Zweryfikuj dostęp do skrzynki; zaplanuj zmianę email root po MFA enrollment |
| RShop (943111679945) | jaroslaw.golab+rshop@makolab.com | Zweryfikuj dostęp do skrzynki; zaplanuj zmianę email root po MFA enrollment |
| makolab_monitoring (400837535641) | tymur.myma@makolab.com | Zweryfikuj czy Tymur Myma nadal w firmie; jeśli nie → AWS Support recovery przed remediacja |

---

## 6. MFA Migration Plan

### 6.1 Target State

```
Root Account — Break-Glass Only
├── Email root: dedykowana skrzynka funkcyjna (aws-root-ACCT@makolab.com lub domain-purpose@)
│   └── Dostęp: min. 2 osoby z IT security
├── Hasło root: dedykowany vault (1Password Teams / Bitwarden Business)
│   └── NIE KeePass współdzielony
├── MFA device:
│   ├── management account: YubiKey hardware (2 sztuki, przechowywanie fizyczne)
│   └── member accounts: TOTP w kontrolowanym vault (1Password Teams "aws-root" vault)
└── Root access keys: BRAK (potwierdzone ✅ dla wszystkich kont)
```

### 6.2 Procedura enrollment TOTP (po wejściu jako root do konsoli)

```
1. Górny prawy róg → kliknij Account Name → "Security credentials"
2. Sekcja "Multi-factor authentication (MFA)"
3. "Assign MFA device"
4. Wybierz "Authenticator app" → Next
5. Kliknij "Show QR code" albo "Show secret key"
6. Zeskanuj QR lub wpisz secret key w 1Password / Authy dla vault "aws-root"
7. Podaj dwa kolejne kody 6-cyfrowe
8. "Add MFA" → potwierdzenie sukcesu
9. Wyloguj → zaloguj ponownie → zweryfikuj że MFA jest wymagane
10. Zapisz nazwę urządzenia MFA w vault: "konto=ACCOUNT_ID, email=ROOT_EMAIL"
```

### 6.3 Post-enrollment: zmiana email root (dla kont z personal email)

Po enrolled MFA:
```
1. Zaloguj się jako root (email + hasło + MFA)
2. Prawy górny róg → Account → "Account settings"
3. "Email address" → zmień na adres funkcyjny
4. Potwierdź przez stary email (link weryfikacyjny)
5. Zaktualizuj vault
```

---

## 7. Rollback Procedures

### 7.1 Rollback — Recovery OU (konto nie wróciło)

```bash
# Sprawdź aktualny OU konta
aws organizations list-parents --child-id ACCOUNT_ID --profile cd-management

# Przesuń z powrotem
aws organizations move-account \
  --account-id ACCOUNT_ID \
  --source-parent-id RECOVERY_OU_ID \
  --destination-parent-id ORIGINAL_OU_ID \
  --profile cd-management
```

### 7.2 Rollback — błędnie enrolled MFA (stare urządzenie utracone)

```
Jeśli stare MFA urządzenie działa:
  1. Zaloguj root + hasło + stary MFA kod
  2. Security credentials → MFA → Delete device
  3. Re-enroll prawidłowe urządzenie

Jeśli stare MFA urządzenie NIE działa (lockout):
  → AWS Support ticket: "MFA device lost, need account recovery"
  → Weryfikacja przez billing (last 4 cyfry karty) lub dokumenty organizacji
  → Czas: 24-48h
```

### 7.3 Rollback — SCP Opcja B2 (awaryjne przywrócenie)

```bash
# Natychmiast przywróć SCP jeśli cokolwiek pójdzie nie tak
aws organizations attach-policy \
  --policy-id p-8wat7tjs \
  --target-id ORIGINAL_OU_ID \
  --profile cd-management

# Weryfikacja
aws organizations list-targets-for-policy \
  --policy-id p-8wat7tjs \
  --profile cd-management
```

---

## 8. Verification Checklist

### Per konto (po każdym enrollment)

```bash
ACCOUNT_ID="XXXXXXXXXXXX"
PROFILE="cd-XXXX"

# 1. Root MFA enabled
aws iam generate-credential-report --profile $PROFILE
sleep 8
aws iam get-credential-report --profile $PROFILE \
  --query 'Content' --output text | base64 --decode | \
  awk -F',' '$1=="<root_account>" {print "MFA="$8, "Key1="$9, "Key2="$14}'
# Oczekiwane: MFA=true Key1=false Key2=false

# 2. Konto w prawidłowym OU
aws organizations list-parents --child-id $ACCOUNT_ID --profile cd-management

# 3. CloudTrail rejestruje root login
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=ConsoleLogin \
  --profile cd-management \
  --query 'Events[?contains(Username,`root`)].{Time:EventTime,Event:EventName,Source:CloudTrailEvent}' \
  --max-results 3
```

### Organizacyjny (po zakończeniu wszystkich kont)

- [ ] Credential report: mfa_active=true dla wszystkich ACTIVE kont
- [ ] Zero root access keys (wszystkie false) — potwierdzone już dziś ✅
- [ ] Recovery OU usunięte (po zakończeniu prac)
- [ ] Konta z personal email → email root zmieniony na funkcyjny
- [ ] Konto makolab_monitoring → zweryfikowane email Tymur Myma
- [ ] Root credentials w dedykowanym vault (nie KeePass)
- [ ] CloudTrail rejestruje ConsoleLogin root
- [ ] Security Hub włączony → finding `iam-root-account-mfa-enabled` zielony
- [ ] GuardDuty włączony → monitoring `RootCredentialUsage`

---

## 9. Recommended Target Architecture

### 9.1 Detective controls (po włączeniu Security Hub + GuardDuty)

```
Security Hub FSBP → finding: iam-root-account-mfa-enabled
GuardDuty → finding: UnauthorizedAccess:IAMUser/RootCredentialUsage
CloudTrail → ConsoleLogin root → EventBridge rule → SNS → GLPI
```

### 9.2 Governance roadmap

| Etap | Akcja | Status |
|------|-------|--------|
| 1 | Discovery credential reports | **DONE** 2026-05-07 |
| 2 | Root MFA enrollment — LogArchiveNew | Gotowe do wykonania |
| 3 | Utworzenie Recovery OU | Wymagane przed Production |
| 4 | Root MFA enrollment — Workloads/Prod (6 kont) | Po Recovery OU |
| 5 | Root MFA enrollment — DRP-TFS, lab | Po Recovery OU |
| 6 | Zmiana email root (personal → funkcyjny) | Po enrollment |
| 7 | Usunięcie Recovery OU | Po zakończeniu |
| 8 | Security Hub + GuardDuty włączenie | Równolegle |
| 9 | IAM Identity Center setup | Następny sprint |

---

## Appendix — Quick Reference

### Komendy per konto

```bash
# Credential report (zastąp PROFILE)
PROFILE=cd-XXXX
aws iam generate-credential-report --profile $PROFILE
sleep 8
aws iam get-credential-report --profile $PROFILE \
  --query 'Content' --output text | base64 --decode | \
  awk -F',' '$1=="<root_account>" {print "MFA="$8, "Key1="$9, "Key2="$14}'

# Przesuń konto do Recovery OU
aws organizations move-account \
  --account-id ACCOUNT_ID \
  --source-parent-id SOURCE_OU_ID \
  --destination-parent-id RECOVERY_OU_ID \
  --profile cd-management

# Utwórz Recovery OU pod Root
aws organizations create-organizational-unit \
  --parent-id r-z8np \
  --name "MFA-Recovery" \
  --profile cd-management

# Usuń Recovery OU (po zakończeniu)
aws organizations delete-organizational-unit \
  --organizational-unit-id RECOVERY_OU_ID \
  --profile cd-management
```

### Mapowanie kont do OU (do użycia przy move-account)

| Account | ID | Current OU ID | OU Name |
|---------|-----|--------------|---------|
| planodkupow | 333320664022 | ou-z8np-jomloow3 | Production |
| planodkupowv1 | 292464762806 | ou-z8np-jomloow3 | Production |
| Booking_Online | 128264038676 | ou-z8np-jomloow3 | Production |
| RShop | 943111679945 | ou-z8np-jomloow3 | Production |
| dacia-asystent | 074412166613 | ou-z8np-jomloow3 | Production |
| CC | 943696080604 | ou-z8np-jomloow3 | Production |
| DRP-TFS | 613448424242 | ou-z8np-ydx42f96 | NonProduction |
| lab | 052845428574 | ou-z8np-dqtp5qcx | Sandbox |

---

## Powiązane

- [[aws-cloud-platform-context]] — pełny snapshot org + SCP stan
- [[40-runbooks/aws/]] — runbooki AWS operacyjne
