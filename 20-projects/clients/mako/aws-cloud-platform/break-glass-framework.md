---
title: break-glass-framework
client: mako
project: aws-cloud-platform
domain: client-work
document_type: architecture
classification: internal
tags:
  - aws
  - security
  - governance
  - break-glass
  - organizations
  - scp
  - llz
created: "2026-05-07"
updated: "2026-05-07"
---

# AWS Organizations — Break-Glass & Recovery Governance Framework

#aws #security #governance #organizations #scp #mako

**Data:** 2026-05-07
**Org:** o-5c4d5k6io1 | Root: r-z8np | Management: 864277686382

---

## 1. Executive Summary

Remediation root accounts (2026-05-07) ujawniła systemowy brak: organizacja posiadała guardrail (`DenyRootUserActions`) bez żadnego operational exception path. Każda przyszła root remediation wymagałaby improvised SCP modification — operacji wysokiego ryzyka na żywym środowisku.

Ten framework definiuje trwałą architekturę break-glass:
- **Recovery OU** jako permanentna, zawsze pusta strefa bez DenyRootUserActions,
- **SCP exception strategy** z trzema opcjami według blast radius,
- **Maintenance window process** z checklistami BEFORE/DURING/AFTER,
- **Detective controls** alertujące na każde użycie break-glass ścieżki.

**Zasada naczelna:** każda zmiana SCP jest ryzykowna. Recovery OU eliminuje potrzebę modyfikacji SCP content podczas maintenance — zamiast tego modyfikuje się tylko OU membership konta, co jest tańsze, szybsze i bardziej audytowalne.

---

## 2. Break-Glass Architecture

### 2.1 Diagram struktury

```
Root OU (r-z8np)
├── makolab_dc (864277686382) — management, immune to SCPs
│
├── Platform OU
│   ├── Admin MakoLab (647075515164)
│   └── monitoring-nagios-bot (814662658531)
│
├── Security OU                          ← CT guardrails (jak dostępne)
│   └── LogArchiveNew (771354139056)
│
├── Workloads OU
│   ├── Production OU                    ← llz-security-baseline
│   │   ├── planodkupow (333320664022)
│   │   ├── planodkupowv1 (292464762806)
│   │   ├── Booking_Online (128264038676)
│   │   ├── RShop (943111679945)
│   │   ├── dacia-asystent (074412166613)
│   │   └── CC (943696080604)
│   └── NonProduction OU                 ← llz-security-baseline
│       └── DRP-TFS (613448424242)
│
├── Sandbox OU                           ← llz-security-baseline
│   ├── lab (052845428574)
│   └── pbms (378131232770) — SUSPENDED
│
├── Quarantine OU                        ← deny-all (do wdrożenia)
│   ├── MakolabDev (442703586623) — SUSPENDED
│   └── makolab_monitoring (400837535641) — SUSPENDED
│
└── Break-Glass OU  ◄── NOWY (permanentny, normalnie pusty)
    └── [konto przenoszone tymczasowo podczas maintenance]
        SCP attached: TYLKO DenyDisableSecurityServices
        SCP NOT attached: DenyRootUserActions
```

### 2.2 Zasady Break-Glass OU

| Zasada | Wartość |
|--------|---------|
| Normalny stan | **PUSTY** — żadne konto nie powinno tu być na stałe |
| SCP attached | `DenyDisableSecurityServices` — CloudTrail/GuardDuty chronione nawet w oknie |
| SCP NOT attached | `DenyRootUserActions` — root może działać |
| Pobyt konta | Max 4h — po tym czasie alert eskaluje do P1 |
| Audit | Każdy `MoveAccount` TO/FROM logowany przez CloudTrail + EventBridge alert |

### 2.3 Co Break-Glass OU umożliwia (root)

- Zmiana email root ✅
- Reset hasła root ✅
- MFA enrollment/zmiana ✅
- Operacje account management ✅

### 2.4 Co Break-Glass OU nadal blokuje

- `cloudtrail:StopLogging` / `DeleteTrail` ❌
- `guardduty:DeleteDetector` ❌
- `config:StopConfigurationRecorder` ❌
- `securityhub:DisableSecurityHub` ❌

---

## 3. Recovery OU — Design & Terraform

### 3.1 Terraform moduł

```hcl
# organizations/break-glass/main.tf

resource "aws_organizations_organizational_unit" "break_glass" {
  name      = "Break-Glass"
  parent_id = "r-z8np"

  tags = {
    Purpose     = "break-glass-maintenance"
    ManagedBy   = "Terraform"
    Description = "Temporary OU for root account maintenance. Must be empty in normal operations."
  }
}

# Attach tylko DenyDisableSecurityServices — NIE DenyRootUserActions
resource "aws_organizations_policy_attachment" "break_glass_security" {
  policy_id = aws_organizations_policy.deny_disable_security.id
  target_id = aws_organizations_organizational_unit.break_glass.id
}

output "break_glass_ou_id" {
  value       = aws_organizations_organizational_unit.break_glass.id
  description = "ID Break-Glass OU — wymagany do maintenance window procedure"
}
```

```hcl
# organizations/break-glass/monitoring.tf

# Alert: konto weszło do Break-Glass OU
resource "aws_cloudwatch_event_rule" "account_entered_break_glass" {
  name        = "org-account-entered-break-glass"
  description = "Alert when any account is moved to Break-Glass OU"

  event_pattern = jsonencode({
    source      = ["aws.organizations"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventName            = ["MoveAccount"]
      requestParameters = {
        destinationParentId = [aws_organizations_organizational_unit.break_glass.id]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "break_glass_alert" {
  rule      = aws_cloudwatch_event_rule.account_entered_break_glass.name
  target_id = "break-glass-sns"
  arn       = var.security_alerts_sns_arn
}

# Alert: konto w Break-Glass OU dłużej niż 4h (wymaga zewnętrznego schedulera lub Lambda)
```

### 3.2 Propagation delays — empiryczne

| Operacja | Czas propagacji | Weryfikacja |
|----------|----------------|-------------|
| `MoveAccount` | 15–30s | `list-parents --child-id ACCOUNT_ID` |
| SCP effective | 15–60s po move | Test: root próba operacji (expect allow) |
| CloudTrail event | 5–15 min | `lookup-events` |

**Praktyczna zasada:** po `MoveAccount` odczekaj 60s przed wykonaniem root operations. Nie weryfikuj przez "próbę i sprawdzanie błędu" — sprawdź `list-parents` i odczekaj.

---

## 4. SCP Exception Strategy

### 4.1 Trzy opcje według blast radius

| Opcja | Mechanizm | Blast radius | Kiedy używać |
|-------|----------|-------------|-------------|
| **A — Recovery OU** | Move account do Break-Glass OU | MINIMAL — jedno konto na raz | Default — zawsze preferowana |
| **B — Account exclusion** | `StringNotEquals: aws:PrincipalAccount` w condition | MEDIUM — lista wskazanych kont | Wiele kont jednocześnie, okno czasowe |
| **C — NotAction bypass** | `Action:"*"` → `NotAction:[lista]` | MEDIUM-HIGH — wszystkie konta w OU | Ostateczność, gdy znane są dokładne akcje |

**Nigdy:**
- Detach SCP od OU globalnie
- Disable SCP policy type
- Remove `DenyDisableSecurityServices` statement
- Dodawać `AdministratorAccess` tymczasowo

### 4.2 Opcja A — Recovery OU (preferowana)

```bash
# Przed: sprawdź aktualny OU konta
ACCOUNT_ID="333320664022"
ORIGINAL_OU=$(aws organizations list-parents \
  --child-id $ACCOUNT_ID --profile mako-dc \
  --query 'Parents[0].Id' --output text)
echo "Original OU: $ORIGINAL_OU"

# Move do Break-Glass OU
BREAK_GLASS_OU="ou-z8np-XXXXXXXX"  # ← wypełnić po terraform apply
aws organizations move-account \
  --account-id $ACCOUNT_ID \
  --source-parent-id $ORIGINAL_OU \
  --destination-parent-id $BREAK_GLASS_OU \
  --profile mako-dc

# Verify
sleep 60
aws organizations list-parents --child-id $ACCOUNT_ID --profile mako-dc

# [... wykonaj maintenance ...]

# Restore
aws organizations move-account \
  --account-id $ACCOUNT_ID \
  --source-parent-id $BREAK_GLASS_OU \
  --destination-parent-id $ORIGINAL_OU \
  --profile mako-dc

# Verify restore
aws organizations list-parents --child-id $ACCOUNT_ID --profile mako-dc
```

### 4.3 Opcja B — Account exclusion (wiele kont)

```json
{
  "Sid": "DenyRootUserActions",
  "Effect": "Deny",
  "Action": "*",
  "Resource": "*",
  "Condition": {
    "StringLike": {
      "aws:PrincipalArn": "arn:aws:iam::*:root"
    },
    "StringNotEquals": {
      "aws:PrincipalAccount": [
        "ACCOUNT_ID_1",
        "ACCOUNT_ID_2"
      ]
    }
  }
}
```

**Wymagane artefakty przed apply:**
- `BACKUP-scp-YYYY-MM-DD.json` — aktualny stan SCP
- `EXCEPTION-scp-YYYY-MM-DD.json` — wersja z exclusion
- `ROLLBACK-scp-YYYY-MM-DD.json` — docelowy stan po rollbacku

### 4.4 Explicit expiration (brak natywnego wsparcia AWS)

AWS nie wspiera time-based SCP expiration. Kompensacja:

```
Option 1: Lambda scheduler
  - Lambda uruchamiana przez EventBridge Schedule (np. T+4h)
  - Wykonuje rollback SCP automatycznie
  - Wymaga: IAM role z organizations:UpdatePolicy, sekret w Secrets Manager

Option 2: Manuel calendar + alert
  - EventBridge rule: CloudWatch Alarm po 4h od MoveAccount
  - Alert do operatora: "Break-Glass window aktywne >4h — wykonaj rollback"

Option 3: Ticket-based (rekomendowane minimum)
  - GLPI ticket z due time = T+4h
  - Ticket auto-closes → wymusza weryfikację stanu
```

---

## 5. Maintenance Window Process

### 5.1 BEFORE — Przygotowanie (T-30 min)

```
[ ] Identyfikacja kont wymagających maintenance (lista account IDs)
[ ] Identyfikacja oryginalnych OU (list-parents per konto)
[ ] Snapshot aktualnego SCP:
    aws organizations describe-policy --policy-id p-8wat7tjs \
      --profile mako-dc --query 'Policy.Content' --output text \
      > /tmp/scp-backup-$(date +%Y%m%dT%H%M%SZ).json
[ ] Zapis operator identity + timestamp:
    aws sts get-caller-identity --profile mako-dc
[ ] Weryfikacja CloudTrail:
    aws cloudtrail get-trail-status --name org-baseline-cloudtrail \
      --profile mako-dc --region eu-central-1 \
      --query '{IsLogging:IsLogging,LatestDeliveryError:LatestDeliveryError}'
[ ] Przygotowanie rollback command (skopiuj do schowka, NIE uruchamiaj)
[ ] Powiadomienie stakeholderów (Slack #aws-ops): "Maintenance window T+00 do T+4h"
[ ] Freeze: brak terraform apply, brak SCP edits, brak IAM refactorów
[ ] Otwarcie GLPI ticket z due time = T+4h
[ ] Rollback file gotowy w /tmp/
```

### 5.2 DURING — Wykonanie (T+00 do T+4h)

```
Per konto (jeden na raz dla Opcji A):

[ ] MoveAccount → Break-Glass OU
    aws organizations move-account \
      --account-id $ACCOUNT_ID \
      --source-parent-id $ORIGINAL_OU \
      --destination-parent-id $BREAK_GLASS_OU \
      --profile mako-dc

[ ] Verify OU change (60s wait):
    aws organizations list-parents --child-id $ACCOUNT_ID --profile mako-dc
    # Oczekiwane: Break-Glass OU ID

[ ] Perform maintenance (console root login)

[ ] Verify maintenance complete:
    aws iam generate-credential-report --profile cd-KONTO && sleep 8
    aws iam get-credential-report --profile cd-KONTO \
      --query 'Content' --output text | base64 --decode | \
      awk -F',' '$1=="<root_account>" {print "MFA="$8}'
    # Oczekiwane: MFA=true

[ ] MoveAccount → Original OU (natychmiast po verify)
    aws organizations move-account \
      --account-id $ACCOUNT_ID \
      --source-parent-id $BREAK_GLASS_OU \
      --destination-parent-id $ORIGINAL_OU \
      --profile mako-dc

[ ] Verify restore:
    aws organizations list-parents --child-id $ACCOUNT_ID --profile mako-dc
    # Oczekiwane: oryginalny OU ID

[ ] Następne konto (powtórz)
```

### 5.3 AFTER — Restore & Validation (T+4h max)

```
[ ] Verify: Break-Glass OU jest pusty
    aws organizations list-children \
      --parent-id $BREAK_GLASS_OU \
      --child-type ACCOUNT \
      --profile mako-dc
    # Oczekiwane: pusta lista

[ ] Verify: wszystkie konta w prawidłowych OU
    aws organizations list-accounts-for-parent \
      --parent-id ou-z8np-jomloow3 --profile mako-dc  # Production
    # Porównaj z baseline

[ ] Verify: SCP aktywny dla wszystkich kont (brak accidental exclusion):
    aws organizations describe-policy --policy-id p-8wat7tjs \
      --profile mako-dc --query 'Policy.Content' --output text | python3 -m json.tool

[ ] Post-maintenance credential report audit (wszystkie konta):
    for profile in cd-*; do
      aws iam get-credential-report --profile $profile \
        --query 'Content' --output text 2>/dev/null | base64 --decode | \
        awk -F',' '$1=="<root_account>" {print "'$profile': MFA="$8}' || true
    done

[ ] CloudTrail: sprawdź root login events w oknie:
    aws cloudtrail lookup-events \
      --start-time $(date -u -v-4H '+%Y-%m-%dT%H:%M:%SZ') \
      --lookup-attributes AttributeKey=EventName,AttributeValue=ConsoleLogin \
      --profile mako-dc \
      --query 'Events[?contains(Username,`root`)].{Time:EventTime,Account:CloudTrailEvent}'

[ ] Zamknij GLPI ticket z artefaktami (credential reports, CloudTrail excerpt)
[ ] Powiadomienie: "Maintenance window zamknięty, governance przywrócone"
[ ] Zaktualizuj vault: root-mfa-recovery-plan.md (odznacz wykonane konta)
```

### 5.4 Emergency Abort

```bash
# Jeśli cokolwiek pójdzie nie tak podczas okna:

# 1. Natychmiast przesuń konto z powrotem (jeśli w Break-Glass OU)
aws organizations move-account \
  --account-id $ACCOUNT_ID \
  --source-parent-id $BREAK_GLASS_OU \
  --destination-parent-id $ORIGINAL_OU \
  --profile mako-dc

# 2. Jeśli używano Opcji B — natychmiast rollback SCP
aws organizations update-policy \
  --policy-id p-8wat7tjs \
  --content file:///tmp/scp-backup-TIMESTAMP.json \
  --profile mako-dc

# 3. Verify wszystko wróciło
aws organizations describe-policy --policy-id p-8wat7tjs \
  --profile mako-dc --query 'Policy.Content' --output text | python3 -m json.tool

# 4. Alert stakeholderów: maintenance aborted
# 5. Otwórz GLPI P2 z opisem co poszło nie tak
```

### 5.5 Partial failure handling

| Scenariusz | Akcja |
|-----------|-------|
| Konto utknęło w Break-Glass OU (operator niedostępny) | EventBridge alert po 4h → drugi operator wykonuje MoveAccount back |
| SCP rollback file utracony | `describe-policy` + ręczna rekonstrukcja z vault backup |
| Root login nie działa (hasło nieznane) | AWS Support ticket "root password reset", billing verification — 24-72h |
| MFA enrollment failed (QR błąd) | Wygeneruj nowy QR: usuń urządzenie → powtórz enrollment |

---

## 6. Detective Controls

### 6.1 EventBridge rules — JSON

```json
// Rule 1: Konto weszło do Break-Glass OU (CRITICAL)
{
  "source": ["aws.organizations"],
  "detail-type": ["AWS API Call via CloudTrail"],
  "detail": {
    "eventName": ["MoveAccount"],
    "requestParameters": {
      "destinationParentId": ["BREAK_GLASS_OU_ID"]
    }
  }
}
```

```json
// Rule 2: Root login — dowolne konto (HIGH)
{
  "source": ["aws.signin"],
  "detail-type": ["AWS Console Sign In via CloudTrail"],
  "detail": {
    "userIdentity": { "type": ["Root"] },
    "eventName": ["ConsoleLogin"]
  }
}
```

```json
// Rule 3: Root MFA removal (CRITICAL)
{
  "source": ["aws.iam"],
  "detail-type": ["AWS API Call via CloudTrail"],
  "detail": {
    "eventName": ["DeactivateMFADevice", "DeleteVirtualMFADevice"],
    "userIdentity": { "type": ["Root"] }
  }
}
```

```json
// Rule 4: Root password change (HIGH)
{
  "source": ["aws.signin"],
  "detail-type": ["AWS Console Sign In via CloudTrail"],
  "detail": {
    "eventName": ["PasswordUpdated"],
    "userIdentity": { "type": ["Root"] }
  }
}
```

```json
// Rule 5: SCP modification (HIGH)
{
  "source": ["aws.organizations"],
  "detail-type": ["AWS API Call via CloudTrail"],
  "detail": {
    "eventName": [
      "UpdatePolicy", "CreatePolicy", "DeletePolicy",
      "AttachPolicy", "DetachPolicy"
    ]
  }
}
```

```json
// Rule 6: OU structure change (MEDIUM)
{
  "source": ["aws.organizations"],
  "detail-type": ["AWS API Call via CloudTrail"],
  "detail": {
    "eventName": [
      "MoveAccount",
      "CreateOrganizationalUnit",
      "DeleteOrganizationalUnit",
      "UpdateOrganizationalUnit"
    ]
  }
}
```

```json
// Rule 7: CloudTrail disable attempt (CRITICAL — powinien fail przez SCP)
{
  "source": ["aws.cloudtrail"],
  "detail-type": ["AWS API Call via CloudTrail"],
  "detail": {
    "eventName": ["StopLogging", "DeleteTrail", "UpdateTrail"],
    "errorCode": ["AccessDenied"]
  }
}
```

### 6.2 Severity mapping & notification paths

| Event | Severity | Primary | Escalation |
|-------|---------|---------|-----------|
| Konto w Break-Glass OU | CRITICAL | SNS → GLPI P1 + Slack #aws-security | +30 min: call |
| Root login | HIGH | SNS → GLPI P2 + Slack #aws-ops | +4h bez ticketu: P1 |
| Root MFA removal | CRITICAL | SNS → GLPI P1 + Slack #aws-security | Immediate call |
| Root password change | HIGH | SNS → GLPI P2 | +1h: weryfikacja |
| SCP modification | HIGH | SNS → GLPI P2 + Slack #aws-governance | +1h: code review |
| OU structure change | MEDIUM | Slack #aws-governance | — |
| CloudTrail disable (AccessDenied) | HIGH | SNS → GLPI P2 | +4h bez resolution: P1 |

### 6.3 Security Hub findings (po włączeniu FSBP)

| Finding ID | Severity | Trigger | Auto-remediation |
|-----------|---------|---------|-----------------|
| `iam-root-account-mfa-enabled` | HIGH | root MFA = false | Alert → GLPI |
| `iam-root-access-key-check` | CRITICAL | root key active | Alert → manual delete |
| `iam-root-hardware-mfa-enabled` | MEDIUM | software MFA zamiast hardware | Quarterly review |
| `cloudtrail-enabled` | CRITICAL | CloudTrail off | Alert → investigate |
| `guardduty-enabled-centralized` | HIGH | GuardDuty off | Alert → re-enable |

### 6.4 GuardDuty findings

| Finding | Severity | Action |
|---------|---------|--------|
| `UnauthorizedAccess:IAMUser/RootCredentialUsage` | HIGH | GLPI P1, verify root usage |
| `Policy:IAMUser/RootCredentialUsage` | MEDIUM | GLPI P2, review |
| `Recon:IAMUser/MaliciousIPCaller` | HIGH | GLPI P1, rotate credentials |

---

## 7. Root Governance Standard

### 7.1 Root account definition

```
root account = break-glass access only

Dozwolone operacje root:
  - Zmiana payment method
  - Zmiana root email
  - Root MFA enrollment/reset
  - Account closure
  - Support tier change
  - Odwołanie od IAM policy lockout

Niedozwolone operacje root:
  - Tworzenie IAM users/roles
  - Zarządzanie zasobami AWS
  - CI/CD operations
  - Terraform apply
  - Jakakolwiek operacja dostępna przez IAM role
```

### 7.2 Ownership matrix per konto

| Zasób | Owner | Backup | Recovery |
|-------|-------|--------|---------|
| Root email | IT Security Lead | IT Manager | AWS Support |
| Root hasło | Root Vault (1Password Teams) | Backup w sejfie fizycznym | Email reset |
| Root MFA | IT Security Lead (fizyczny token lub 1Password Teams) | Backup token w sejfie | AWS Support |

### 7.3 Email aliasy — model

```
Format: aws-<purpose>@infra.makolab.pl

Przykłady:
  aws-makolabdc@infra.makolab.pl       (management account)
  aws-planodkupow@infra.makolab.pl     (workload account)
  aws-logarchivenew@infra.makolab.pl   (security account)

Skrzynka:
  - Distribution group (min. 2 odbiorców: IT Security Lead + backup)
  - Nie personal email
  - Dostęp: IT Security team (nie całe IT, nie DevOps)
  - Recovery mailbox: dostęp zewnętrzny z 2FA (nie ActiveDirectory only)

Weryfikacja kwartalna:
  - Czy skrzynka dostarcza maile?
  - Czy odbiorcy są aktualni?
  - Czy hasła/dostępy nie wygasły?
```

### 7.4 MFA strategy

```
Management account (864277686382):
  Primary:  YubiKey 5 NFC #1 — sejf IT Security, lokalizacja A
  Backup:   YubiKey 5 NFC #2 — sejf IT Security, lokalizacja B
  Recovery: AWS Support (billing verification)

Security OU konta (LogArchiveNew):
  Primary:  YubiKey dedykowany lub TOTP w 1Password Teams vault "aws-root-security"
  Backup:   Recovery codes w 1Password (osobny wpis)

Workloads / Sandbox / Platform konta:
  Primary:  TOTP w 1Password Teams vault "aws-root-accounts"
            Secret unikalny per konto, NIE shared
  Backup:   Recovery codes w 1Password (osobny wpis)
  Nigdy:    KeePass shared, Google Authenticator personal phone

Rotacja:
  - MFA device replacement co 3 lata (hardware) lub po incydencie
  - TOTP secret re-enrollment po wykrytym breach
```

---

## 8. Operational Governance Model

### 8.1 Quarterly Recovery Test

Raz na kwartał wykonaj:

```
Test 1: Credential report audit
  - Wygeneruj credential reports dla wszystkich ACTIVE kont
  - Verify: root MFA = true dla wszystkich
  - Verify: root access keys = false dla wszystkich
  - Czas: ~15 min

Test 2: Break-Glass OU move drill (non-production konto)
  - Wybierz konto: lab (052845428574)
  - MoveAccount → Break-Glass OU → verify → MoveAccount back
  - Verify: EventBridge alert dotarł (Slack/GLPI)
  - Czas: ~10 min

Test 3: Root email reachability
  - Wyślij test email na każdy aws-*@infra.makolab.pl
  - Verify: mail dostarczony, odczytany przez IT Security
  - Czas: ~5 min

Test 4: Rollback SCP files dostępne
  - Verify: pliki backup SCP w bezpiecznym miejscu (nie tylko /tmp/)
  - Odczytaj i potwierdź że są poprawne JSON
  - Czas: ~5 min
```

### 8.2 Annual Governance Review

| Element | Akcja | Owner |
|---------|-------|-------|
| Root email ownership | Aktualizacja distribution groups | IT Security |
| MFA hardware tokens | Weryfikacja fizycznej lokalizacji | IT Security |
| Break-Glass OU stan | Confirm puste, SCP attachment OK | Cloud Platform |
| SCP content review | Czy guardrails są aktualne? | Cloud Platform |
| OrganizationAccountAccessRole | Weryfikacja trust policy per konto | Cloud Platform |
| IAM users w management account | Audit (stare konta, klucze > 90 dni) | Cloud Platform |

### 8.3 Separation of Duties

| Operacja | Executor | Approver | Auditor |
|---------|---------|---------|--------|
| Root MFA enrollment | Cloud Platform Engineer | IT Security Lead | GLPI log |
| Break-Glass OU move | Cloud Platform Engineer | IT Security Lead (pismo) | CloudTrail |
| SCP modification | Cloud Platform Engineer | CTO / IT Security Lead | CloudTrail + GLPI |
| Root email change | IT Security Lead | IT Manager | GLPI |
| Account closure | Cloud Platform | Business Owner + IT Manager | Organizations API |

---

## 9. Automation Roadmap

### 9.1 Priorytet 1 — Zrób teraz

```bash
# a) Recovery OU w Terraform
# organizations/break-glass/main.tf (patrz sekcja 3.1)
terraform apply -target=aws_organizations_organizational_unit.break_glass

# b) EventBridge rules (rules 1-7 z sekcji 6.1) w Terraform
# platform/detective-controls/eventbridge-governance.tf

# c) Security Hub FSBP włączyć
aws securityhub enable-security-hub \
  --enable-default-standards \
  --profile mako-dc

# d) GuardDuty org-wide
aws guardduty create-detector --enable --profile mako-dc
```

### 9.2 Toolkit commands (devops-toolkit roadmap)

```bash
# toolkit audit root-governance
# Output: per konto — root MFA, email domain, access keys, last root login
# Source: credential report + organizations list-accounts + CloudTrail

# toolkit audit scp-governance
# Output: lista SCP, targets, treść, last modified, drift vs IaC
# Source: organizations list-policies + describe-policy + TF state

# toolkit drift organizations
# Output: drift OU structure vs IaC (konta w złym OU, missing SCP attachments)
# Source: organizations describe + TF state compare

# toolkit break-glass status
# Output: czy Break-Glass OU jest pusty, czas ostatniego użycia, kto
# Source: organizations list-children + CloudTrail lookup
```

### 9.3 Compliance pack (LLZ extension)

```hcl
# LLZ compliance: root governance controls
# llz/compliance/root-governance.tf

# Control 1: root MFA required
resource "aws_config_config_rule" "root_mfa_enabled" {
  name = "llz-root-mfa-enabled"
  source {
    owner             = "AWS"
    source_identifier = "ROOT_ACCOUNT_MFA_ENABLED"
  }
}

# Control 2: no root access keys
resource "aws_config_config_rule" "no_root_access_keys" {
  name = "llz-no-root-access-keys"
  source {
    owner             = "AWS"
    source_identifier = "IAM_ROOT_ACCESS_KEY_CHECK"
  }
}
```

---

## 10. Required Runbooks

Dokumenty do stworzenia (priorytet):

| Runbook | Lokalizacja | Priorytet |
|---------|------------|---------|
| Break-Glass: OU move procedure | `40-runbooks/aws/break-glass-ou-move.md` | **WYSOKI** |
| Root MFA enrollment | `40-runbooks/aws/root-mfa-enrollment.md` | **WYSOKI** |
| Root email change | `40-runbooks/aws/root-email-change.md` | MEDIUM |
| SCP exception procedure | `40-runbooks/aws/scp-exception-procedure.md` | **WYSOKI** |
| Root recovery (AWS Support path) | `40-runbooks/aws/root-recovery-aws-support.md` | MEDIUM |
| Maintenance window checklist | `40-runbooks/aws/maintenance-window.md` | **WYSOKI** |
| Quarterly governance validation | `40-runbooks/aws/quarterly-governance-check.md` | MEDIUM |

---

## 11. Risk Analysis

### 11.1 Ryzyka frameworku (po wdrożeniu)

| Ryzyko | Likelihood | Impact | Mitigation |
|--------|-----------|--------|-----------|
| Break-Glass OU użyte bez autoryzacji | LOW | HIGH | EventBridge alert + SoD (approver required) |
| Konto zapomniane w Break-Glass OU | MEDIUM | MEDIUM | Alert po 4h + quarterly check |
| SCP modyfikacja bez backupu | LOW | HIGH | Obligatoryjny snapshot w checklist |
| EventBridge alerts not delivered | LOW | HIGH | Dead-letter queue + Lambda retry |
| Break-Glass OU ID zmieniony po TF destroy | LOW | CRITICAL | Hardcode OU ID w runbooku, TF state lock |

### 11.2 Ryzyka residualne (po remediacji 2026-05-07)

| Ryzyko | Stan | Akcja |
|--------|------|-------|
| 9 kont bez MFA | AKTYWNE | Kolejne maintenance window (target 2026-05-14) |
| Brak Recovery OU w AWS | AKTYWNE | Terraform apply (target: ten tydzień) |
| Security Hub / GuardDuty wyłączone | AKTYWNE | Włączyć (target: ten tydzień) |
| Brak EventBridge detective rules | AKTYWNE | Terraform (target: następny sprint) |
| Brak quarterly validation process | AKTYWNE | Zdefiniować + wpisać w kalendarz |

---

## 12. Recommended Next Steps

### Tydzień 1 (natychmiast)

1. `terraform apply` — Break-Glass OU (organizations/break-glass/)
2. MFA enrollment — 9 kont (maintenance window z Recovery OU zamiast SCP modification)
3. Security Hub FSBP włączyć
4. GuardDuty włączyć
5. EventBridge rules #1 (Break-Glass move) i #2 (root login) — minimalne detective controls

### Tydzień 2

6. EventBridge rules #3-7 (pełne detective controls)
7. Runbook: `40-runbooks/aws/break-glass-ou-move.md`
8. Runbook: `40-runbooks/aws/maintenance-window.md`
9. Runbook: `40-runbooks/aws/root-mfa-enrollment.md`

### Miesiąc 1

10. AWS Config rules: root MFA + no root access keys
11. IAM Identity Center — planowanie wdrożenia
12. Offboarding checklist — root email verification

### Kwartał 1

13. Pierwszy quarterly recovery test
14. `toolkit audit root-governance` — implementacja w devops-toolkit
15. Annual governance review — setup w kalendarzu

---

## Powiązane

- [[root-governance-postmortem]] — postmortem + lessons learned
- [[root-mfa-recovery-plan]] — plan i wyniki remediacji 2026-05-07
- [[aws-cloud-platform-context]] — snapshot org
- [[40-runbooks/aws/]] — runbooki operacyjne
