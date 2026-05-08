---
title: ACM cert renewal risk — *.skleprenault.pl — 2026-05-08
date: 2026-05-08
tags: [rshop, acm, tls, certificate, cloudfront, incident-risk]
severity: critical
env: dev
status: action-required
cert-arn: arn:aws:acm:us-east-1:943111679945:certificate/3be77743-e90b-4d21-ba97-c6193c8bc977
expires: 2026-05-13
---

# ACM cert renewal risk — `*.skleprenault.pl` wygasa 2026-05-13

#rshop #acm #tls #cloudfront #cert

**WYMAGANA AKCJA DZIŚ** — cert dev wygasa za 5 dni, auto-renewal zablokowany.

---

## Podsumowanie

Certyfikat `*.skleprenault.pl` wygasa **2026-05-13 01:59 UTC**. ACM próbuje odnowić (status `PENDING_VALIDATION`, last update dziś 11:21), ale jest zablokowany przez 2 domeny z SANów:

- `*.webshopdacia.hu` — CNAME brakuje, domena **NXDOMAIN** (.hu TLD)
- `*.webshoprenault.hu` — CNAME brakuje, domena **NXDOMAIN** (.hu TLD)

Certyfikat używany wyłącznie przez **dev** dystrybucję CloudFront `E3LC30816FMUSK` (dev-CZ/SK/HU/PL). **Produkcja niezagrożona.**

---

## Stan certyfikatu

| Pole | Wartość |
|------|---------|
| ARN | `arn:aws:acm:us-east-1:943111679945:certificate/3be77743-e90b-4d21-ba97-c6193c8bc977` |
| Status | ISSUED |
| NotAfter | **2026-05-13 01:59 UTC (5 dni)** |
| RenewalStatus | **PENDING_VALIDATION** |
| InUseBy | `E3LC30816FMUSK` (dev CloudFront, 16 aliasów dev) |
| Route53 | brak stref publicznych — DNS zewnętrzny |

---

## Blokujące domeny

| SAN | Status renewal | DNS |
|-----|---------------|-----|
| `*.webshopdacia.hu` | PENDING_VALIDATION | NXDOMAIN — brak strefy DNS w .hu |
| `*.webshoprenault.hu` | PENDING_VALIDATION | NXDOMAIN — brak strefy DNS w .hu |

CNAME walidacyjne których brakuje:
```
_825d9e7a67cee4a887aa43176c18577b.webshopdacia.hu.
  → _86711e5f882000ca898d4245b4887376.tjztrygkxr.acm-validations.aws.

_0ac2cd30805e2e7578dfaa200aec4b1a.webshoprenault.hu.
  → _86eb2afd1dd5a98de68d097ba3d6b82a.tjztrygkxr.acm-validations.aws.
```

Te rekordy nie mogą być dodane — domeny HU nie mają skonfigurowanej strefy DNS ani delegacji NS w TLD .hu. Dev aliasy `dev.webshopdacia.hu` etc. są NXDOMAIN i nigdy nie działały.

---

## Blast radius

**Dev środowisko — 12 działających aliasów straci HTTPS po 2026-05-13:**

```
dev/devb.skleprenault.pl    dev/devb.sklepdacia.pl
dev/devb.eshopdacia.sk      dev/devb.eshoprenault.sk
dev/devb.eshopdacia.cz      dev/devb.eshoprenault.cz
```

4 aliasy HU (dev.webshopdacia.hu etc.) — już NXDOMAIN, nie działają.

**Produkcja niezagrożona** — inne certyfikaty, wygasają 2026-07 i 2026-10.

---

## Rekomendowana akcja: Nowy certyfikat bez domen HU (~30 min)

### Krok 1 — Usuń HU aliasy z CloudFront E3LC30816FMUSK

```bash
aws cloudfront get-distribution-config \
  --id E3LC30816FMUSK \
  --profile rshop --output json > /tmp/cf-e3lc-config.json

# Edytuj: usuń z Aliases.Items:
#   dev.webshopdacia.hu, devb.webshopdacia.hu
#   dev.webshoprenault.hu, devb.webshoprenault.hu
# Zmień Aliases.Quantity: 16 → 12
```

### Krok 2 — Wydaj nowy certyfikat

```bash
aws acm request-certificate \
  --domain-name "*.skleprenault.pl" \
  --validation-method DNS \
  --subject-alternative-names \
    "*.eshoprenault.sk" \
    "*.eshopdacia.sk" \
    "*.eshopdacia.cz" \
    "*.eshoprenault.cz" \
    "*.sklepdacia.pl" \
  --region us-east-1 \
  --profile rshop
```

Wszystkie 6 CNAME walidacyjnych istnieją w DNS → wydanie ~5 min.

### Krok 3 — Przypisz nowy cert do CF

```bash
# Po ISSUED — zaktualizuj ViewerCertificate w konfiguracji CF
# CloudFront propagation: ~5-15 min
```

### Krok 4 — Usuń stary certyfikat

```bash
aws acm delete-certificate \
  --certificate-arn arn:aws:acm:us-east-1:943111679945:certificate/3be77743-e90b-4d21-ba97-c6193c8bc977 \
  --region us-east-1 --profile rshop
```

---

## Monitoring (do dodania)

```bash
# CloudWatch alarm: DaysToExpiry < 30
aws cloudwatch put-metric-alarm \
  --alarm-name "acm-cert-expiry-30d-warning" \
  --namespace AWS/CertificateManager \
  --metric-name DaysToExpiry \
  --dimensions Name=CertificateArn,Value=<NEW_ARN> \
  --statistic Minimum \
  --period 86400 \
  --evaluation-periods 1 \
  --threshold 30 \
  --comparison-operator LessThanOrEqualToThreshold \
  --alarm-actions <SNS_ARN> \
  --region us-east-1 --profile rshop
```

---

## Powiązane

- [[rshop-context]] — architektura cert + CloudFront
- Wygasły orphan cert do usunięcia: `dev.eshoprenault.lt` (`173ae59f`, EXPIRED 2024-08-08, InUse=False)
