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
status: draft
---

# AWS Root MFA Recovery & Remediation — Plan operacyjny

#aws #security #mfa #organizations #mako

**Data:** 2026-05-07
**Autor:** Claude Code (na podstawie struktury org potwierdzonej 2026-05-01)
**Zakres:** 17 kont AWS Organizations o-5c4d5k6io1
**Priorytet:** WYSOKI — brak root MFA = HRI security + NIS2 gap

---

## 1. Executive Summary

Organizacja MakoLab posiada 17 kont AWS, z czego 13 ACTIVE i 4 SUSPENDED. Historyczne zarządzanie root przez współdzielony KeePass oraz brak systematycznego MFA enrollment stwarza ryzyko operacyjne i kompliansowe (NIS2).

**Cel:** odzyskanie kontroli nad root accounts, enrollment MFA (hardware lub TOTP w kontrolowanym vault), eliminacja root access keys.

**Ograniczenia krytyczne:**
- Root MFA można ustawić WYŁĄCZNIE przez konsolę AWS — nie przez CLI/API
- Root w management account (864277686382) NIE podlega SCP — bezpieczny do operacji
- Root w member accounts podlega SCP — wymaga analizy blokerów przed akcją
- Każde konto traktuj indywidualnie — zero masowych operacji

**Stan SCP (po usunięciu LLZ SCPs ~2026-04-20):**
- Większość kont: tylko `FullAWSAccess` (permissive) → root operations SAFE
- LogArchiveNew (Security OU): + 2x CT guardrails → wymaga analizy
- Brak guardrails na Workloads/Production → okno do bezpiecznej remediacji

---

## 2. Risk Matrix

### Legenda

| Poziom | Znaczenie |
|--------|-----------|
| LOW | Ryzyko akceptowalne, można działać bezpośrednio |
| MEDIUM | Wymaga przygotowania, ale wykonalne standardową ścieżką |
| HIGH | Wymaga Recovery OU lub AWS Support |
| LOCKOUT_RISK | Zatrzymaj się — opisz ryzyko przed działaniem |

### Risk Matrix per konto

| Account | ID | OU | Status | SCP bloker | MFA status | Root keys | Poziom ryzyka |
|---------|-----|-----|--------|-----------|------------|-----------|--------------|
| makolab_dc | 864277686382 | Root | ACTIVE | **Brak** (management — immune) | NIEZNANY | NIEZNANY | **MEDIUM** |
| Admin MakoLab | 647075515164 | Platform | ACTIVE | FullAWSAccess only | NIEZNANY | NIEZNANY | **MEDIUM** |
| monitoring-nagios-bot | 814662658531 | Platform | ACTIVE | FullAWSAccess only | NIEZNANY | NIEZNANY | **MEDIUM** |
| lab | 052845428574 | Sandbox | ACTIVE | FullAWSAccess only | NIEZNANY | NIEZNANY | **LOW** |
| LogArchiveNew | 771354139056 | Security | ACTIVE | FullAWSAccess + **2x CT guardrails** | NIEZNANY | NIEZNANY | **HIGH** |
| planodkupow | 333320664022 | Workloads/Prod | ACTIVE | FullAWSAccess only | NIEZNANY | NIEZNANY | **MEDIUM** |
| planodkupowv1 | 292464762806 | Workloads/Prod | ACTIVE | FullAWSAccess only | NIEZNANY | NIEZNANY | **MEDIUM** |
| Booking_Online | 128264038676 | Workloads/Prod | ACTIVE | FullAWSAccess only | NIEZNANY | NIEZNANY | **MEDIUM** |
| RShop | 943111679945 | Workloads/Prod | ACTIVE | FullAWSAccess only | NIEZNANY | NIEZNANY | **MEDIUM** |
| dacia-asystent | 074412166613 | Workloads/Prod | ACTIVE | FullAWSAccess only | NIEZNANY | NIEZNANY | **MEDIUM** |
| CC | 943696080604 | Workloads/Prod | ACTIVE | FullAWSAccess only | NIEZNANY | NIEZNANY | **MEDIUM** |
| DRP-TFS | 613448424242 | Workloads/NonProd | ACTIVE | FullAWSAccess only | NIEZNANY | NIEZNANY | **LOW** |
| pbms | 378131232770 | Sandbox | SUSPENDED | FullAWSAccess only | NIEZNANY | NIEZNANY | **LOW** |
| Audit | 012086764624 | Quarantine | SUSPENDED | FullAWSAccess only | NIEZNANY | NIEZNANY | **LOW** |
| Log Archive stary | 518286664393 | Quarantine | SUSPENDED | FullAWSAccess only | NIEZNANY | NIEZNANY | **LOW** |
| makolab_monitoring stary | 400837535641 | Quarantine | SUSPENDED | FullAWSAccess only | NIEZNANY | NIEZNANY | **LOW** |
| MakolabDev | 442703586623 | Quarantine | SUSPENDED | FullAWSAccess + DEV SCP | NIEZNANY | NIEZNANY | **MEDIUM** |

> **UWAGA:** Poziomy ryzyka oznaczone jako NIEZNANY dla MFA i root keys — wymagają discovery (faza 1). Poziomy ryzyka mogą wzrosnąć po discovery jeśli email root jest niedostępny lub MFA nieznane.

---

## 3. Discovery — komendy i procedura

Discovery MUSI poprzedzać remediation. Bez danych nie działaj.

### 3.1 Credential Report (root MFA + root keys)

Credential report generuje się per konto. Uruchom dla każdego ACTIVE konta.

```bash
# Management account
aws iam generate-credential-report --profile cd-management
sleep 5
aws iam get-credential-report --profile cd-management \
  --query 'Content' --output text | base64 --decode | \
  awk -F',' 'NR==1 || $1=="root" {print $1","$4","$5","$8","$9","$11}'
# Kolumny: user,password_enabled,password_last_used,mfa_active,access_key_1_active,access_key_2_active

# Member accounts — uruchom przez OrganizationAccountAccessRole
# Zastąp ACCOUNT_ID i PROFILE_NAME odpowiednio
for profile in cd-admin-makolab cd-monitoring cd-lab cd-logarchivenew \
               cd-planodkupow cd-planodkupowv1 cd-booking cd-rshop \
               cd-dacia cd-cc cd-drp-tfs; do
  echo "=== $profile ==="
  aws iam generate-credential-report --profile $profile 2>&1 || echo "BRAK DOSTEPU"
  sleep 3
  aws iam get-credential-report --profile $profile \
    --query 'Content' --output text 2>/dev/null | base64 --decode | \
    awk -F',' 'NR==1 || $1=="root" {print $1","$4","$5","$8","$9","$11}' || echo "BLAD"
done
```

> **UWAGA:** Profil cd-* to CloudDetectiveReadOnly — ma uprawnienie iam:GenerateCredentialReport i iam:GetCredentialReport. Zweryfikuj przed uruchomieniem.

### 3.2 Root email per konto (z Organizations)

```bash
# Pobierz email root dla każdego konta
aws organizations list-accounts --profile cd-management \
  --query 'Accounts[*].{ID:Id,Name:Name,Email:Email,Status:Status}' \
  --output table
```

### 3.3 Sprawdzenie SCP — zawartość CT guardrails (LogArchiveNew)

```bash
# Pobierz treść CT guardrails dla Security OU
aws organizations describe-policy \
  --policy-id p-wacgblah \
  --profile cd-management \
  --query 'Policy.Content' --output text | python3 -m json.tool

aws organizations describe-policy \
  --policy-id p-yncf8tm8 \
  --profile cd-management \
  --query 'Policy.Content' --output text | python3 -m json.tool
```

### 3.4 Tabela wyników discovery (wypełnij po uruchomieniu)

| Account ID | Root email znany? | Email aktywny? | MFA active | root key 1 | root key 2 | Ryzyko finalne |
|-----------|------------------|----------------|-----------|-----------|-----------|---------------|
| 864277686382 | TAK (sprawdź) | ? | ? | ? | ? | ? |
| 647075515164 | TAK (sprawdź) | ? | ? | ? | ? | ? |
| 814662658531 | TAK (sprawdź) | ? | ? | ? | ? | ? |
| 052845428574 | TAK (sprawdź) | ? | ? | ? | ? | ? |
| 771354139056 | TAK (sprawdź) | ? | ? | ? | ? | ? |
| 333320664022 | TAK (sprawdź) | ? | ? | ? | ? | ? |
| 292464762806 | TAK (sprawdź) | ? | ? | ? | ? | ? |
| 128264038676 | TAK (sprawdź) | ? | ? | ? | ? | ? |
| 943111679945 | TAK (sprawdź) | ? | ? | ? | ? | ? |
| 074412166613 | TAK (sprawdź) | ? | ? | ? | ? | ? |
| 943696080604 | TAK (sprawdź) | ? | ? | ? | ? | ? |
| 613448424242 | TAK (sprawdź) | ? | ? | ? | ? | ? |

---

## 4. SCP Analysis

### 4.1 Aktualne SCPs i impact na root operations

| SCP | ID | Targets | Impact na root MFA | Akcja |
|-----|-----|---------|-------------------|-------|
| FullAWSAccess | p-FullAWSAccess | Root (inherited) | BRAK — permissive | Brak zmian |
| aws-guardrails-WCOddW | p-26aljn7o | **brak targets** | BRAK (orphaned) | Cleanup |
| aws-guardrails-BbhyLy | p-wacgblah | Security OU | **WYMAGA SPRAWDZENIA** | Patrz sekcja 4.2 |
| aws-guardrails-zTzmTA | p-yncf8tm8 | Security OU | **WYMAGA SPRAWDZENIA** | Patrz sekcja 4.2 |
| bilingi | p-c6iuxb0c | **brak targets** | BRAK (unattached) | Brak wpływu |
| DEV | p-yfwlx134 | MakolabDev | Weryfikuj treść | Low priority (SUSPENDED) |

### 4.2 CT Guardrails — analiza dla LogArchiveNew

**RISKY** — Security OU konto LogArchiveNew ma 2 CT guardrails. Przed działaniem na root tego konta:

1. Uruchom komendy z sekcji 3.3 i pobierz treść SCP
2. Sprawdź czy SCP zawiera:
   - `Deny` na `iam:*` — blokuje enrollment MFA
   - `Deny` na `sts:AssumeRole` — blokuje OrganizationAccountAccessRole
   - `Deny` na root operations (`aws:PrincipalIsAWSService` condition)
3. Typowe CT guardrails dotyczą: blokowania CloudTrail disable, S3 bucket policy delete, Config stop — **nie** MFA operations

**Typowe CT guardrail patterns (Control Tower managed):**
```json
{
  "Effect": "Deny",
  "Action": ["cloudtrail:DeleteTrail", "cloudtrail:StopLogging",
             "s3:DeleteBucket", "config:DeleteConfigRule"],
  "Resource": "*"
}
```

Jeśli CT guardrails NIE zawierają `iam:*` deny → LogArchiveNew = MEDIUM (nie HIGH).

### 4.3 Kiedy potrzebne Recovery OU

Recovery OU potrzebne gdy:
- SCP w obecnym OU blokuje `iam:CreateVirtualMFADevice` lub `iam:EnableMFADevice`
- SCP blokuje dostęp do konsoli AWS (root login)

**Aktualna sytuacja:** LLZ SCPs usunięte, brak workloads-baseline SCP → większość kont ma tylko FullAWSAccess. Recovery OU NIE jest potrzebne dla kont POZA Security OU.

### 4.4 Minimalny wyjątek SCP (gdyby potrzebny)

**NIE używać AdministratorAccess. NIE wyłączać SCP globalnie.**

Jeśli SCP blokuje root MFA enrollment, dodaj tymczasowy statement (tylko dla okresu remediation):

```json
{
  "Sid": "AllowRootMFAEnrollment",
  "Effect": "Allow",
  "Principal": "*",
  "Action": [
    "iam:CreateVirtualMFADevice",
    "iam:EnableMFADevice",
    "iam:ListMFADevices",
    "iam:GetUser"
  ],
  "Resource": "arn:aws:iam::ACCOUNT_ID:mfa/root-account-mfa-device",
  "Condition": {
    "StringEquals": {
      "aws:PrincipalArn": "arn:aws:iam::ACCOUNT_ID:root"
    }
  }
}
```

Po enrolled MFA → natychmiast usuń wyjątek.

---

## 5. Recovery Strategy — per konto / per ścieżka

### 5.1 Ścieżka A — Standard (email aktywny, hasło znane)

**Dotyczy:** większość kont przy założeniu KeePass ma dane

**SAFE**

```
1. Weryfikuj email root (sprawdź w Organizations)
2. Wejdź na console.aws.amazon.com → Sign in as root account
3. Podaj email → hasło (z KeePass)
4. Jeśli MFA już enrolled: podaj kod MFA
5. Jeśli MFA nie enrolled: przejdź do sekcji 6 (MFA Migration)
6. Verify: credential report → mfa_active = TRUE
7. Wyloguj
```

### 5.2 Ścieżka B — Hasło nieznane, email aktywny

**RISKY** — reset hasła root przez email

```
1. Na stronie logowania: "Forgot password?"
2. AWS wyśle link reset na root email
3. Zresetuj hasło (min. 8 znaków, uppercase/lowercase/number/special)
4. Zapisz nowe hasło w dedykowanym vault (NIE w KeePass współdzielonym)
5. Wejdź i wykonaj Ścieżkę A od kroku 4
```

> **UWAGA:** Reset hasła przez email = konieczność dostępu do skrzynki. Jeśli skrzynka to `admin@makolab.com` lub podobna shared — upewnij się, że masz dostęp zanim zaczniesz.

### 5.3 Ścieżka C — Email nieaktywny / nieznany

**HIGH** — wymaga AWS Support

```
1. Otwórz ticket AWS Support → "root account email recovery"
   - Podaj account ID
   - Potwierdź tożsamość przez billing verification (last 4 cyfry karty kredytowej)
   - Lub zweryfikuj przez dokumenty organizacji
2. AWS zmieni email root lub pomoże w odzyskaniu dostępu
3. Po odzyskaniu dostępu → Ścieżka A lub B
4. Czas: 24-72h per konto
```

> **LOCKOUT RISK:** Dla kont SUSPENDED z nieznanym emailem — ostrożnie. SUSPENDED konto nadal ma root. AWS Support może odmówić dostępu bez billing verification.

### 5.4 Ścieżka D — Email znany, brak dostępu do skrzynki (MX expired, inbox nieaktywna)

**LOCKOUT RISK** — przed działaniem opisz ryzyko i potwierdź z użytkownikiem

```
Opcje:
A) IT przywróci dostęp do skrzynki email → Ścieżka B
B) AWS Support z billing verification (card on file) → zmiana email roota
C) Jeśli konto ma OrganizationAccountAccessRole: sprawdź czy można coś zrobić bez root

ZATRZYMAJ SIĘ i opisz sytuację przed działaniem.
```

### 5.5 Kolejność priorytetów

| Kolejność | Konto | Uzasadnienie |
|-----------|-------|-------------|
| 1 | makolab_dc (864277686382) | Management account — kontroluje całą org |
| 2 | LogArchiveNew (771354139056) | Archiwum CloudTrail — Security posture |
| 3 | Admin MakoLab (647075515164) | Administracyjne |
| 4 | monitoring-nagios-bot (814662658531) | Infra krytyczna |
| 5 | Wszystkie Workloads/Production | Produkcyjne (6 kont) |
| 6 | DRP-TFS (613448424242) | NonProduction |
| 7 | lab (052845428574) | Sandbox |
| 8 | SUSPENDED konta | Niski priorytet, ale nie pomiń |

---

## 6. MFA Migration Plan

### 6.1 Target State

```
root = break-glass only
├── MFA: hardware token (YubiKey preferred) LUB TOTP w kontrolowanym vault
├── root access keys: BRAK (delete jeśli istnieją)
├── root email: znany, aktywny, dostępny tylko przez IT security
└── hasło: w dedykowanym vault (nie KeePass współdzielonym)
```

**NIE:**
- Brak root access keys (zero tolerancji)
- Brak współdzielonego TOTP (KeePass nie nadaje się do root MFA)
- Brak root w codziennych operacjach

### 6.2 Opcje MFA

| Opcja | Zalety | Wady | Rekomendacja |
|-------|--------|------|-------------|
| Hardware token (YubiKey 5 NFC) | Najsilniejsze, FIDO2/WebAuthn | Koszt (~250 PLN/szt), potrzeba 17 lub centralizacja | **PREFERRED** dla management + Security OU |
| TOTP (Authy/1Password team) | Tanie, skalowalne | Wymaga kontrolowanego vault, nie KeePass | Akceptowalne dla reszty kont |
| TOTP w AWS Secrets Manager | Audytowalny, automatyczny rotation | Złożoność setup | Dla zaawansowanego governance |

### 6.3 Procedura enrollment MFA (TOTP)

**SAFE** (po weryfikacji Ścieżki A/B)

```
1. Zaloguj się jako root do konsoli
2. Prawy górny róg → Account Name → "Security credentials"
3. Sekcja "Multi-factor authentication (MFA)"
4. "Assign MFA device"
5. Wybierz "Authenticator app"
6. Zeskanuj QR code przez kontrolowany TOTP vault (NIE KeePass)
7. Wpisz 2 kolejne kody 6-cyfrowe dla weryfikacji
8. "Add MFA" → sukces
9. Zapisz secret (jeśli dostępny) w vault bezpiecznym
10. Wyloguj → zaloguj ponownie → zweryfikuj że MFA jest wymagane
```

### 6.4 Usunięcie root access keys (jeśli istnieją)

**RISKY** — najpierw zweryfikuj że klucze nie są aktywnie używane

```bash
# Discovery: sprawdź credential report (kolumna access_key_1_active, _last_used)
# Jeśli access_key_last_used > 90 dni: usuń bezpiecznie
# Jeśli access_key_last_used < 90 dni: ZATRZYMAJ SIĘ — ktoś używa root keys aktywnie

# Usunięcie przez konsolę (NIE przez CLI — root keys nie widać w IAM CLI dla innych użytkowników):
# Security credentials → Access keys → Delete
```

**LOCKOUT RISK:** Nigdy nie usuwaj root access keys jeśli nie masz dostępu do konsoli przez root. Bez MFA i bez keys = brak emergency access.

---

## 7. Rollback Procedures

### 7.1 Rollback — zmiana SCP (jeśli dodano wyjątek)

**SAFE** — zawsze można cofnąć SCP zmianę

```bash
# Usuń tymczasowy statement z SCP
aws organizations update-policy \
  --policy-id POLICY_ID \
  --content file://scp-original.json \
  --profile cd-management

# Weryfikacja
aws organizations describe-policy --policy-id POLICY_ID \
  --profile cd-management \
  --query 'Policy.Content' --output text | python3 -m json.tool
```

### 7.2 Rollback — błędnie enrolled MFA

Jeśli enrolled złe urządzenie MFA:

```
1. Zaloguj się jako root (email + hasło + stary TOTP jeśli działa)
2. Security credentials → MFA → Delete device
3. Re-enroll prawidłowe urządzenie
```

Jeśli stare urządzenie nie działa i nie możesz się zalogować:
- AWS Support: "root MFA device lost" → weryfikacja przez billing
- Czas recovery: 24-48h

### 7.3 Rollback — Recovery OU move (jeśli wykonany)

```bash
# Przywróć konto do oryginalnego OU
aws organizations move-account \
  --account-id ACCOUNT_ID \
  --source-parent-id RECOVERY_OU_ID \
  --destination-parent-id ORIGINAL_OU_ID \
  --profile cd-management

# Weryfikacja
aws organizations list-parents \
  --child-id ACCOUNT_ID \
  --profile cd-management
```

---

## 8. Verification Checklist

Po każdym koncie wykonaj wszystkie poniższe kroki przed przejściem do następnego.

### Per konto

```bash
ACCOUNT_ID="XXXXXXXXXXXX"
PROFILE="cd-XXXX"

# 1. Root MFA enabled
aws iam generate-credential-report --profile $PROFILE
sleep 5
aws iam get-credential-report --profile $PROFILE \
  --query 'Content' --output text | base64 --decode | \
  awk -F',' '$1=="root" {print "MFA active: "$9}'
# Oczekiwane: MFA active: true

# 2. Brak root access keys
aws iam get-credential-report --profile $PROFILE \
  --query 'Content' --output text | base64 --decode | \
  awk -F',' '$1=="root" {print "Key1: "$10, "Key2: "$13}'
# Oczekiwane: Key1: false Key2: false (lub N/A)

# 3. CloudTrail rejestruje root login
# Po zalogowaniu jako root: sprawdź CloudTrail w management account
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=ConsoleLogin \
  --profile cd-management \
  --query 'Events[?contains(Username,`root`)].{Time:EventTime,Account:recipientAccountId,Event:EventName}' \
  --max-results 5

# 4. GuardDuty (jeśli włączony) — brak aktywnych root findings
# Gdy GuardDuty będzie włączony:
# aws guardduty list-findings \
#   --detector-id DETECTOR_ID \
#   --finding-criteria '{"Criterion":{"type":{"Equals":["UnauthorizedAccess:IAMUser/RootCredentialUsage"]}}}' \
#   --profile $PROFILE

# 5. Konto jest we właściwym OU
aws organizations list-parents \
  --child-id $ACCOUNT_ID \
  --profile cd-management
```

### Organizacyjny (po zakończeniu wszystkich kont)

- [ ] Credential report dla wszystkich kont → mfa_active = true dla root
- [ ] Zero root access keys aktywnych w całej org
- [ ] CloudTrail rejestruje ConsoleLogin dla root (test per konto)
- [ ] Security Hub (po włączeniu): brak finding `iam-root-account-mfa-enabled`
- [ ] GuardDuty (po włączeniu): brak finding `RootCredentialUsage`
- [ ] Wszystkie konta z Recovery OU przeniesione z powrotem do właściwego OU
- [ ] SCP tymczasowe wyjątki usunięte (jeśli były)
- [ ] Root credentials zapisane w kontrolowanym vault (nie KeePass)
- [ ] KeePass root entries usunięte lub oznaczone jako deprecated

---

## 9. Recommended Target Architecture

### 9.1 Break-glass model

```
Root Account Access — Break-Glass Only
├── Email root: dedykowana skrzynka IT security (np. aws-root-ACCOUNTID@makolab.com)
│   └── Dostęp: IT Security Lead + backup (min. 2 osoby)
├── Hasło root: 1Password Teams / Bitwarden Business (nie KeePass współdzielony)
│   └── Dostęp: IT Security Lead + backup
├── MFA:
│   ├── management account (864277686382): YubiKey hardware (2 klucze, przechowywanie fizyczne)
│   └── member accounts: TOTP w 1Password Teams (team "aws-root", shared vault)
└── Access keys root: BRAK (zero tolerance)
```

### 9.2 Operacyjny model (docelowo z IAM Identity Center)

```
Codzienne operacje:
├── IAM Identity Center (SSO) → permission sets per rola
│   ├── AdministratorAccess: tylko senior engineers
│   ├── ReadOnlyAccess: monitoring, audit
│   └── Workload-specific: per team
├── OrganizationAccountAccessRole: break-glass emergency dla member accounts
└── Root: NIGDY w codziennych operacjach
```

### 9.3 Detective controls (po włączeniu Security Hub + GuardDuty)

```
Security Hub:
├── Finding: iam-root-account-mfa-enabled → alert jeśli MFA wyłączone
├── Finding: iam-root-access-key-check → alert jeśli root keys istnieją
└── Standard: AWS Foundational Security Best Practices (FSBP)

GuardDuty:
├── UnauthorizedAccess:IAMUser/RootCredentialUsage → High severity alert
└── → SNS → health-notifications Lambda → GLPI ticket

CloudTrail:
└── ConsoleLogin eventName z rootAccount = true → EventBridge rule → alert
```

### 9.4 Governance roadmap dla root accounts

| Etap | Akcja | Kiedy |
|------|-------|-------|
| 1 | Discovery (credential reports dla wszystkich kont) | Natychmiast |
| 2 | Root MFA enrollment — management account | Priorytet 1 |
| 3 | Root MFA enrollment — Security OU (LogArchiveNew) | Po analizie CT guardrails |
| 4 | Root MFA enrollment — Production accounts | Kolejne 2 tygodnie |
| 5 | Root MFA enrollment — reszta kont | Kolejne 2 tygodnie |
| 6 | Usunięcie root access keys (gdzie istnieją) | Po enrollment MFA |
| 7 | Włączenie Security Hub + GuardDuty | Równolegle |
| 8 | IAM Identity Center setup | Następny sprint |
| 9 | CloudTrail alert na root login | Po Security Hub |

---

## Powiązane

- [[aws-cloud-platform-context]] — pełny snapshot org + SCP stan
- [[40-runbooks/aws/]] — runbooki AWS operacyjne
- [[_system/DOMAIN_ISOLATION_CONTRACT.md]] — zasady izolacji domen

---

## Appendix — Szybkie komendy discovery

```bash
# === DISCOVERY PACK — uruchom przed jakąkolwiek remediacja ===

# 1. Lista kont + emaile root
aws organizations list-accounts --profile cd-management \
  --output table \
  --query 'Accounts[*].{ID:Id,Name:Name,Email:Email,Status:Status}'

# 2. Credential report — management
aws iam generate-credential-report --profile cd-management && sleep 5
aws iam get-credential-report --profile cd-management \
  --query 'Content' --output text | base64 --decode | \
  grep "^root"

# 3. Treść CT guardrails (dla LogArchiveNew)
for pol in p-wacgblah p-yncf8tm8; do
  echo "=== SCP: $pol ==="
  aws organizations describe-policy --policy-id $pol \
    --profile cd-management \
    --query 'Policy.Content' --output text | python3 -m json.tool
done

# 4. DEV SCP treść (dla MakolabDev)
aws organizations describe-policy --policy-id p-yfwlx134 \
  --profile cd-management \
  --query 'Policy.Content' --output text | python3 -m json.tool

# 5. Weryfikacja OrganizationAccountAccessRole w member accounts
for profile in cd-admin-makolab cd-monitoring cd-lab cd-logarchivenew \
               cd-planodkupow cd-planodkupowv1 cd-booking cd-rshop \
               cd-dacia cd-cc cd-drp-tfs; do
  echo -n "$profile: "
  aws iam get-role --role-name OrganizationAccountAccessRole \
    --profile $profile --query 'Role.RoleName' --output text 2>/dev/null \
    || echo "BRAK ROLI"
done
```
