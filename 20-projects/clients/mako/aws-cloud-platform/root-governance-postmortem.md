---
title: root-governance-postmortem
client: mako
project: aws-cloud-platform
domain: client-work
document_type: postmortem
classification: internal
tags:
  - aws
  - security
  - root
  - mfa
  - governance
  - postmortem
  - nis2
created: "2026-05-07"
updated: "2026-05-07"
---

# AWS Root Governance — Postmortem & Hardening Review

#aws #security #governance #postmortem #mako

**Data:** 2026-05-07
**Zakres:** AWS Organizations o-5c4d5k6io1 — 12 ACTIVE kont
**Operator:** jgol_cli (arn:aws:iam::864277686382:user/jgol_cli)

---

## 1. Executive Summary

Organizacja MakoLab AWS przez wieloletni okres akumulowała dług governance w obszarze root account security. Stan wejściowy: 9/12 ACTIVE kont bez root MFA, część z personal email jako root address, współdzielone MFA w KeePass, brak zdefiniowanego procesu lifecycle konta.

Remediation przeprowadzona 2026-05-07 w trybie break-glass: tymczasowa modyfikacja SCP `llz-security-baseline`, zmiana emaili root, częściowy MFA enrollment. SCP przywrócony po zakończeniu okna.

**Stan po remediation:**

| Obszar | Przed | Po |
|--------|-------|----|
| Root MFA | 3/12 ACTIVE | 3/12 — 9 kont pending (MFA enrollment w toku) |
| Root email personal | 2/12 ACTIVE | 0/12 ACTIVE (Booking_Online + RShop zmienione) |
| Root access keys | 0/12 | 0/12 ✅ |
| SCP governance | aktywne | przywrócone ✅ |

**Kluczowy wniosek:** Remediation powiodła się technicznie. Strukturalne root cause — brak standardu governance przy zakładaniu kont — nie został jeszcze zaadresowany. Bez proceduralnej zmiany dług wróci przy nowych kontach.

---

## 2. Incident / Governance Debt Analysis

### 2.1 Jak dług narastał

Konta zakładane były ręcznie przez pojedynczą osobę lub małą grupę. Typowy pattern:
1. Konto zakładane pod adresem `imie.nazwisko+alias@makolab.com` — bo to najszybszy sposób.
2. Hasło root zapisywane do KeePass (shared vault).
3. MFA: albo pomijane, albo ten sam TOTP token "dla całego zespołu".
4. Brak formalnego owner assignment — konto "należy do projektu", nie do osoby odpowiedzialnej za security.
5. Nikt nie wraca do konfiguracji root po uruchomieniu konta — konto żyje dalej bez przeglądu.

Wynik: po 4+ latach organizacja ma konta, gdzie:
- root email = adres pracownika, który może odejść,
- MFA = nieznane lub shared w KeePass,
- Nikt nie wie "kto jest właścicielem root" dla połowy kont.

### 2.2 Procesy, które zawiodły

| Proces | Failure mode |
|--------|-------------|
| Account vending | Brak checklist root security przy zakładaniu konta |
| Offboarding pracownika | Brak kroku "czy ten pracownik jest root emailem jakiegoś konta?" |
| Periodic security review | Credential report nie był cyklicznie weryfikowany |
| Change management SCP | SCP `llz-security-baseline` wdrożony bez complementary remediation procedure |
| Ownership governance | Brak modelu RACI dla root access |

### 2.3 Technical blockers znalezione w trakcie

1. **SCP `DenyRootUserActions`** blokował root MFA enrollment (prawidłowy control, brak operational exception path).
2. **Cloud-detective role** (read-only) — nie miała `organizations:UpdatePolicy` → wymagał `jgol_cli` bezpośrednio.
3. **CT guardrails** z poprzedniego scanu (2026-05-01) już nie istniały w live — stan organizacji zmienił się między scanami bez rejestracji.
4. **Credential report** wymaga generowania per-konto — brak centralnego "org-wide MFA status dashboard".
5. **Konta Audit i Log Archive stary** usunięte z organizacji bez zapisu — znaleziono tylko przez `ChildNotFoundException`.

---

## 3. Timeline Remediation 2026-05-07

```
T+00:00  Discovery start
         aws organizations list-accounts → emaile root per konto
         aws iam generate-credential-report (12 kont) → MFA status

T+00:10  Discovery findings:
         - 3/12 ma MFA (makolab_dc, Admin MakoLab, monitoring-nagios-bot)
         - 0/12 ma root access keys
         - CT guardrails z 2026-05-01 już nie istnieją
         - Nowy SCP llz-security-baseline (p-8wat7tjs) z DenyRootUserActions

T+00:15  SCP modification #1 (NotAction - 5 MFA akcji):
         Action:"*" → NotAction:[iam:CreateVirtualMFADevice, iam:EnableMFADevice, ...]
         ⚠ HIGHEST RISK: root MFA-only window otwarte dla wszystkich 9 kont

T+00:30  SCP modification #2 (Option B — account exclusion):
         Dodano StringNotEquals:aws:PrincipalAccount:[8 kont]
         root unrestrykowany (poza security services) dla wskazanych kont
         ⚠ HIGHEST RISK: pełne root okno dla 8 kont

T+00:30 – T+02:00  Maintenance window:
         - Emaile root zmienione dla Booking_Online, RShop + 8 innych kont
         - Enrollment MFA częściowy (dokładna liczba enrolled nieznana — w toku)

T+02:00  SCP rollback:
         Przywrócono pełny DenyRootUserActions
         Weryfikacja live: describe-policy potwierdzone

T+02:10  Post-remediation verification:
         - 9 kont nadal bez MFA (credential report może mieć propagation lag)
         - 10/12 emaile na infra.makolab.pl
         - 2 konta (makolab_dc, monitoring-nagios-bot) — email accepted state
```

**Momenty highest risk:**
- SCP modification #1 i #2: root mógł wykonać dowolne operacje (poza security service disabling) we wskazanych kontach. Okno trwało ~2h. Brak incydentów — CloudTrail bez anomalii.

**Unexpected AWS behavior:**
- CT guardrails (p-wacgblah, p-yncf8tm8) z poprzedniego scanu nie istniały. Prawdopodobnie usunięte przy reorganizacji SCP między 2026-05-01 a 2026-05-07. Bez zapisu w vault.
- `ChildNotFoundException` dla Audit i Log Archive stary — konta usunięte z org bez dokumentacji.

**Propagation delays:**
- SCP: ~15-30s po `update-policy` — sprawdzone empirycznie.
- Credential report: może być nieaktualny do ~4h po zmianach MFA (AWS gwarancja: "eventually consistent").

---

## 4. Root Cause Analysis

### Bezpośrednia przyczyna (proximate cause)

Brak egzekwowanego standardu root account security przy zakładaniu kont AWS.

### Przyczyny systemowe (systemic causes)

**1. Brak Account Vending Process**

Konta zakładane ad-hoc, bez checklist. Wymagany standard: przed przekazaniem konta do użytku — root email = organizational alias, MFA enrolled, hasło w dedykowanym vault, access keys = none.

**2. Brak cyklicznego audytu credential report**

AWS credential report per konto zawiera: root MFA status, root access key status. Nikt nie generował go regularnie na poziomie organizacyjnym. Security Hub (po włączeniu) rozwiązuje to automatycznie przez FSBP findings.

**3. SCP deployment bez operational exception path**

`llz-security-baseline` z `DenyRootUserActions` wdrożony jako guardrail bez odpowiedzi na pytanie: "co robimy, gdy potrzebujemy zmodyfikować root account?". Brak Recovery OU, brak documented exception procedure → improvised podczas remediation.

**4. Brak ownership modelu dla root accounts**

"Root account konta X należy do..." — nie było zdefiniowane dla żadnego konta. W efekcie: brak odpowiedzialności za stan root, brak trigger do aktualizacji przy rotacji personelu.

**5. Shared MFA w KeePass**

KeePass jako shared vault dla MFA jest antipattern. TOTP secret widoczny dla każdego z dostępem do KeePass. Brak audytowalności "kto użył root MFA kiedy". Nie nadaje się do break-glass access control.

---

## 5. Risk Analysis

### Risk matrix (sprzed remediation)

| Ryzyko | Likelihood | Impact | Score |
|--------|-----------|--------|-------|
| Utrata dostępu do root konta po odejściu pracownika | HIGH | CRITICAL | **CRITICAL** |
| Root credentials compromise (shared KeePass) | MEDIUM | CRITICAL | **HIGH** |
| Root account lockout podczas incydentu | MEDIUM | HIGH | **HIGH** |
| Niezarejestrowane root operations (brak MFA audit trail) | HIGH | MEDIUM | **HIGH** |
| Konto bez root recovery path (nieznany email) | LOW-MEDIUM | CRITICAL | **HIGH** |

### Risk matrix (po remediation)

| Ryzyko | Likelihood | Impact | Score |
|--------|-----------|--------|-------|
| MFA brak na 9 kontach — root reachable bez 2FA | MEDIUM | HIGH | **HIGH** — pending MFA enrollment |
| 2 konta (makolab_dc, monitoring-nagios-bot) z non-infra email | LOW | LOW | **LOW** — accepted, operator ma kontrolę |
| Brak cyklicznego audytu root MFA | MEDIUM | MEDIUM | **MEDIUM** — do zaadresowania przez automation |
| Brak break-glass procedure dokumentacji | LOW | MEDIUM | **MEDIUM** |

---

## 6. Governance Findings

### Anti-patterns znalezione

| Anti-pattern | Przykład | Ryzyko |
|-------------|---------|--------|
| Personal email jako root | jaroslaw.golab+booking@makolab.com | Lockout po odejściu |
| Shared MFA w KeePass | jeden TOTP dla zespołu | Brak audytowalności, secrety widoczne |
| Root operations w codziennej pracy | brak — tu OK | Ryzyko accidental operations |
| SCP bez operational exception path | DenyRootUserActions bez Recovery OU | Blokuje własną remediation |
| Konta usunięte z org bez dokumentacji | Audit, Log Archive stary | Niemożność weryfikacji historycznej |
| Credential report nie monitorowany | 9/12 bez MFA przez nieznany czas | Security gap niedetekowany |

### Organizational risks

1. **Brak Account Lifecycle Policy** — kto decyduje o zakładaniu/zamykaniu kont, jakie są wymagania wstępne?
2. **Brak RACI dla root access** — kto jest Responsible/Accountable za root credentials per konto?
3. **Brak offboarding check** — czy odchodzący pracownik jest przypisany do konta jako root email?
4. **IAM Identity Center nie wdrożony** — powoduje presję na używanie root/IAM user access zamiast federated SSO.

---

## 7. SCP Findings

### 7.1 Ocena aktualnego DenyRootUserActions

```json
{
    "Sid": "DenyRootUserActions",
    "Effect": "Deny",
    "Action": "*",
    "Resource": "*",
    "Condition": {
        "StringLike": { "aws:PrincipalArn": "arn:aws:iam::*:root" }
    }
}
```

**Poprawnie zaprojektowany?** Tak, jako guardrail. Nie, jako kompletny design — brakuje:
- Recovery path (jak zrobić root remediation gdy SCP działa?)
- Exception procedure (udokumentowany workflow)
- Recovery OU lub equivalent

**Problem:** Guardrail blokuje zarówno złośliwe akcje jak i legitymne remediation. Bez udokumentowanego exception path, każda przyszła root remediation będzie wymagała improvised SCP modification — co samo w sobie jest ryzykowną operacją.

### 7.2 Rekomendowany safer SCP design

**Opcja A — Recovery OU jako stały element architektury:**

```
Root OU
├── Platform OU
├── Security OU         ← CT guardrails
├── Workloads OU        ← llz-security-baseline
│   ├── Production OU
│   └── NonProduction OU
├── Sandbox OU          ← llz-security-baseline
├── Quarantine OU       ← deny-all
└── MFA-Recovery OU     ← BRAK SCP (puste) ← stały, nieużywany normalnie
```

Recovery OU istnieje permanentnie, zawsze puste. Procedura: move konto → remediation → move back. Brak potrzeby modyfikacji SCP content.

**Opcja B — Parametryzowany exception w SCP (current approach):**

Obecny approach (NotAction lub StringNotEquals) działa, ale wymaga dokumentacji jako oficjalna procedura, nie improvizacji.

**Rekomendacja: Opcja A + Opcja B jako fallback.**

### 7.3 Operational exception flow (do udokumentowania)

```
Trigger: root remediation potrzebna dla konta X

Krok 1: Utwórz/użyj Recovery OU (permanentna struktura, pusta normalnie)
Krok 2: Move konto X do Recovery OU
         aws organizations move-account --account-id X --destination-parent-id RECOVERY_OU_ID
Krok 3: Odczekaj 30s (SCP propagation)
Krok 4: Wykonaj remediation jako root (console)
Krok 5: Verify: credential report MFA=true
Krok 6: Move konto X z powrotem do oryginalnego OU
Krok 7: Verify: describe-policy na oryginalnym OU potwierdza SCP aktywne
```

---

## 8. Target Root Account Governance Architecture

### 8.1 Root account standard (docelowy)

```
Per root account:
├── Email: aws-<purpose>@infra.makolab.pl
│   └── Skrzynka funkcyjna, dostęp IT Security Lead + 1 backup
│   └── Nie personal email pracownika
├── Hasło: 1Password Teams / Bitwarden Business — vault "aws-root-accounts"
│   └── Dostęp: AWS Account Owners (max 3 osoby)
│   └── Nigdy KeePass shared
├── MFA:
│   ├── management account + Security OU: YubiKey hardware (2 sztuki, sejf fizyczny)
│   └── pozostałe konta: TOTP w 1Password Teams, vault "aws-root-mfa"
│       └── Secret per konto, nie shared
├── Access keys: ZERO (hard requirement, Security Hub finding egzekwuje)
└── Operational usage: break-glass only
    └── Każdy root login → automated alert → GLPI ticket
```

### 8.2 Account creation checklist (wymagany przed oddaniem konta)

```
[ ] Email root = aws-<name>@infra.makolab.pl (nie personal)
[ ] Hasło root w 1Password Teams vault "aws-root-accounts"
[ ] MFA enrolled (TOTP w 1Password Teams vault "aws-root-mfa")
[ ] Root access keys = brak (verify: credential report)
[ ] OrganizationAccountAccessRole istnieje
[ ] Owner przypisany w tagu aws:RequestedBy lub Owner tag
[ ] Konto w odpowiednim OU z właściwymi SCP
```

### 8.3 Account offboarding check

Przy offboardingu pracownika, HR/IT MUSI sprawdzić:
```bash
aws organizations list-accounts --profile cd-management \
  --query "Accounts[?contains(Email, '<pracownik-email>')].{ID:Id,Name:Name,Email:Email}"
```
Jeśli pracownik jest przypisany jako root email → wymagana zmiana emaila przed offboardingiem.

### 8.4 MFA backup strategy

| Konto | Primary MFA | Backup |
|-------|-------------|--------|
| makolab_dc (management) | YubiKey #1 (sejf A) | YubiKey #2 (sejf B) |
| Security OU | YubiKey dedykowany | TOTP backup w 1Password |
| Pozostałe ACTIVE | TOTP w 1Password | Recovery code w 1Password (oddzielny wpis) |

---

## 9. Detective Controls — Rekomendacje

### 9.1 EventBridge rules (priorytet HIGH)

```json
// Root login detection
{
  "source": ["aws.signin"],
  "detail-type": ["AWS Console Sign In via CloudTrail"],
  "detail": {
    "userIdentity": { "type": ["Root"] },
    "eventName": ["ConsoleLogin"]
  }
}
→ Target: SNS → Lambda health_notify → GLPI ticket (severity: HIGH)

// Root password change
{
  "source": ["aws.signin"],
  "detail-type": ["AWS Console Sign In via CloudTrail"],
  "detail": {
    "eventName": ["PasswordUpdated"],
    "userIdentity": { "type": ["Root"] }
  }
}
→ Target: SNS → GLPI (severity: HIGH)

// MFA removal (root)
{
  "source": ["aws.iam"],
  "detail-type": ["AWS API Call via CloudTrail"],
  "detail": {
    "eventName": ["DeactivateMFADevice", "DeleteVirtualMFADevice"],
    "userIdentity": { "type": ["Root"] }
  }
}
→ Target: SNS → GLPI (severity: CRITICAL)

// SCP change
{
  "source": ["aws.organizations"],
  "detail-type": ["AWS API Call via CloudTrail"],
  "detail": {
    "eventName": ["UpdatePolicy", "AttachPolicy", "DetachPolicy", "CreatePolicy", "DeletePolicy"]
  }
}
→ Target: SNS → GLPI (severity: HIGH) + Slack #aws-governance

// Organizations structure change
{
  "source": ["aws.organizations"],
  "detail-type": ["AWS API Call via CloudTrail"],
  "detail": {
    "eventName": ["MoveAccount", "CreateOrganizationalUnit", "DeleteOrganizationalUnit"]
  }
}
→ Target: SNS → GLPI (severity: MEDIUM)
```

### 9.2 Security Hub findings (po włączeniu FSBP)

| Finding | Standard | Severity | Action |
|---------|---------|---------|--------|
| `iam-root-account-mfa-enabled` | FSBP | HIGH | Alert → GLPI |
| `iam-root-access-key-check` | FSBP | CRITICAL | Alert + auto-remediation |
| `iam-root-hardware-mfa-enabled` | FSBP | MEDIUM | Quarterly review |
| `iam-root-no-access-keys` | CIS | CRITICAL | Alert + auto-remediation |

### 9.3 GuardDuty

| Finding type | Severity | Action |
|-------------|---------|--------|
| `UnauthorizedAccess:IAMUser/RootCredentialUsage` | HIGH | Immediate alert → GLPI P1 |
| `Policy:IAMUser/RootCredentialUsage` | MEDIUM | Alert → review |

### 9.4 Periodic credential report audit (CRON)

```bash
# Uruchamiaj cyklicznie (np. Lambda co 24h lub skrypt w CI/CD)
# Dla każdego konta: sprawdź mfa_active dla root
# Jeśli mfa_active=false → alert SNS → GLPI ticket

for profile in $(grep "^\[profile cd-" ~/.aws/config | sed 's/\[profile //;s/\]//'); do
  result=$(aws iam get-credential-report --profile $profile \
    --query 'Content' --output text 2>/dev/null | base64 --decode | \
    awk -F',' '$1=="<root_account>" {print $8}')
  [ "$result" = "false" ] && echo "ALERT: root MFA missing in profile $profile"
done
```

---

## 10. Automation Roadmap

### Priorytet 1 — Natychmiast

| Akcja | Narzędzie | Cel |
|-------|----------|-----|
| Włączyć Security Hub (FSBP) | Terraform / Console | Automatyczne finding root MFA |
| Włączyć GuardDuty org-wide | Terraform / Console | Root credential usage detection |
| EventBridge rule: root login alert | Terraform | Alert na każdy root login |
| EventBridge rule: SCP change alert | Terraform | Alert na zmiany governance |

### Priorytet 2 — Następny sprint

| Akcja | Narzędzie | Cel |
|-------|----------|-----|
| Recovery OU — permanentna struktura | Terraform (organizations module) | Gotowość na przyszłe root remediation |
| Account creation checklist | Confluence / runbook | Zapobieganie nowemu długowi |
| Offboarding check — root email | HR process | Zapobieganie lockout |
| Root MFA cron audit | Lambda + EventBridge schedule | Cykliczne wykrywanie drift |

### Priorytet 3 — IAM Identity Center

| Akcja | Cel |
|-------|-----|
| Wdrożyć IAM Identity Center | Eliminuje potrzebę IAM users w member accounts |
| Permission sets per rola | AdministratorAccess tylko dla senior engineers |
| Zmigrować operacyjny dostęp na SSO | Redukuje presję na root/IAM user usage |
| Root = break-glass only (egzekwowane) | EventBridge alert na każde użycie |

### Toolkit audit (devops-toolkit)

Dodać komendę: `toolkit audit root-governance`

```
Output:
- Per account: root MFA status, root email domain, root access keys
- Findings: non-compliant accounts
- Risk score: per account + org aggregate
- Recommended actions: per finding
```

---

## 11. Lessons Learned

### Technical

1. **SCP DenyRootUserActions bez Recovery OU = operational hazard.** Poprawny guardrail, ale bez escape hatch wymusza improvised SCP modification podczas każdej remediation. Recovery OU jest tańsze i bezpieczniejsze niż modyfikacja SCP w oknie produkcyjnym.

2. **Credential report jest eventually consistent.** Po MFA enrollment wynik może być stary przez kilka godzin. Nie używaj credential report jako immediate verification po zmianie — zaloguj się ponownie jako root i sprawdź w konsoli.

3. **`organizations:DescribePolicy` wymaga poprawnego ID.** Stare IDs SCP (z poprzedniego scanu) mogą dać `PolicyNotFoundException` — zawsze weryfikuj aktualny stan przez `list-policies`.

4. **Konta `ChildNotFoundException` = usunięte z org.** Nie zakładaj że konto które było w org tydzień temu nadal tam jest. Weryfikuj live.

5. **Cloud-detective (read-only) nie wystarczy do governance operations.** Potrzebny osobny profil z `organizations:UpdatePolicy` — trzymaj go oddzielnie od read-only diagnostyki.

### Governance

1. **Guardrail bez complementary procedure = przyszły incident.** Każdy SCP Deny który może zablokować legitymne operacje musi mieć udokumentowany exception path.

2. **"Ktoś ma dostęp do tej skrzynki" to nie owner.** Ownership = named person + backup + procedure recovery. Funkcyjna skrzynka IT Security to minimum.

3. **Shared MFA nigdy nie jest acceptable.** Nie ze względów "best practice" — ale ze względów praktycznych: brak audytu, brak możliwości rotacji bez zmiany dla wszystkich, brak accountability per event.

4. **Personal email jako root = time bomb.** Nie "maybe" — jeśli pracownik odejdzie przed zmianą, konto jest zablokowane lub potrzebny jest AWS Support (24-72h per konto).

### Operational

1. **Maintenance window powinien być zaplanowany, nie improvised.** Nawet 30-minutowe okno wymaga: powiadomienia stakeholderów, zablokowania terraform apply, monitoringu CloudTrail w czasie rzeczywistym.

2. **Snapshot przed każdą zmianą SCP.** Backup JSON + timestamp + operator identity = możliwość forensics po incydencie i szybki rollback.

3. **Rollback command powinien być gotowy przed apply.** Nie "znajdę backup jak będzie potrzebny" — plik rollback gotowy, komenda skopiowana do schowka przed uruchomieniem apply.

---

## 12. Recommended Next Steps

### Natychmiast (ten tydzień)

1. **MFA enrollment — 9 kont.** Otworzyć kolejne maintenance window, użyć Option B (account exclusion). Docelowo: zamknąć 2026-05-14.
2. **Security Hub włączyć** — automatyczne finding `iam-root-account-mfa-enabled` dla wszystkich kont.
3. **GuardDuty włączyć** — `RootCredentialUsage` detection.

### Następne 2 tygodnie

4. **Recovery OU** — wdrożyć jako permanentny element struktury OU (Terraform).
5. **EventBridge rule: root login + SCP change alert** — każde użycie root = ticket.
6. **Account creation runbook** — udokumentować checklist security w Confluence + vault.

### Następny miesiąc

7. **IAM Identity Center** — wdrożyć, zmigrować operacyjny dostęp.
8. **Root MFA cron audit** — Lambda co 24h, alert na każde konto bez MFA.
9. **Offboarding process update** — dodać krok weryfikacji root email.

### Kwartał

10. **toolkit audit root-governance** — komenda w devops-toolkit dla automatycznego audytu.
11. **Governance review kwartalny** — credential report + SCP coverage + OU drift.
12. **NIS2 evidence package** — zebrać artefakty remediation jako dowód dla audytu.

---

## Powiązane

- [[root-mfa-recovery-plan]] — plan operacyjny remediation + discovery findings
- [[aws-cloud-platform-context]] — pełny snapshot org
- [[40-runbooks/aws/]] — runbooki operacyjne
- [[_system/AI_COST_AWARE_AGENT_CONTRACT.md]] — zasady pracy agenta
