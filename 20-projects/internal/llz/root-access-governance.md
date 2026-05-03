---
title: Root Access Governance — Admin-MakoLab
project: llz
type: governance
domain: client-work
classification: internal
account_id: "647075515164"
tags:
  - aws
  - security
  - governance
  - root
  - break-glass
  - ftr
created: 2026-05-03
updated: 2026-05-03
---

# Root Access Governance — Admin-MakoLab (647075515164)

#aws #security #governance #root #break-glass

> [!success] FTR Blocker Resolved
> Legacy root access key (2016-02-11) usunięty 2026-05-03. Konto compliant z `iam-root-access-key-check`.

---

## Dane konta

| Parametr | Wartość |
|----------|---------|
| Account ID | `647075515164` |
| Account name | Admin MakoLab |
| OU | Platform |
| Root email | `admin@makolab.pl` |
| MFA | enabled (3 urządzenia) |
| Dołączyło do org | 2026-03-02 (INVITED) |

---

## Root Access Keys — historia

| Klucz | Utworzony | Ostatnie użycie | Status |
|-------|-----------|-----------------|--------|
| AKIA... (legacy) | 2016-02-11 | 2016-02-15 (elasticbeanstalk, eu-central-1) | ❌ USUNIĘTY 2026-05-03 |

**Powód usunięcia:** nieużywany przez 10 lat, FTR blocker, brak aktywności w CloudTrail (90 dni).

---

## Historia logowań root

| Data | Kontekst |
|------|----------|
| 2026-03-11 | Onboarding konta / migracja do AWS Organization |
| Wcześniej | Brak danych (konto poza org, CloudTrail nieaktywny) |

Brak użycia API (AKIA) — wyłącznie konsola AWS.

---

## Decyzja governance

> [!warning] Break-Glass Only
> Root to konto awaryjne. Żadna automatyzacja, CLI ani Terraform nie może używać root credentials.

- Metoda dostępu: **wyłącznie AWS Console**
- Tryb: **break-glass** (tylko w uzasadnionych przypadkach)
- Każde użycie musi być zalogowane w vault

---

## Przechowywanie credentials

| Element | Lokalizacja |
|---------|-------------|
| Hasło root | KeePass (team) |
| MFA seed / urządzenia | `[FILL: kto posiada 3 urządzenia MFA?]` |
| Właściciel dostępu | `[FILL: imię/rola osoby odpowiedzialnej]` |
| Dostęp awaryjny | `[FILL: kto może użyć w razie nieobecności właściciela?]` |

---

## Dozwolone użycie root

Root można użyć **wyłącznie** w przypadku:

- odzyskanie dostępu do konta (account recovery)
- reset MFA gdy inne metody niedostępne
- dostęp do billing gdy wymagany przez AWS
- awaryjne naprawy IAM (gdy nie ma innego admin access)

---

## Zabronione użycie root

- Terraform / IaC (jakiekolwiek `terraform apply`)
- CLI / skrypty (`aws` CLI, SDK)
- operacje codzienne
- konfiguracja serwisów
- tworzenie zasobów

---

## Procedura break-glass

1. **Uzasadnienie** — opisz incydent / blokada w notatce przed działaniem
2. **Dostęp** — otwórz KeePass, pobierz hasło i urządzenie MFA
3. **Logowanie** — https://console.aws.amazon.com → Root user → `admin@makolab.pl`
4. **Działanie** — wykonaj minimalną konieczną operację
5. **Log** — dopisz wpis w [[session-log]] z: kto / kiedy / co zrobiono / dlaczego

---

## Powiązane

- [[org-inventory]] — struktura organizacji, OU Platform
- [[config-compliance-baseline-2026-05-03]] — Config audit (FTR compliance)
- [[session-log]] — historia sesji LLZ
