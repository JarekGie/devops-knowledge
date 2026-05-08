---
title: ACM cert migration — *.skleprenault.pl — 2026-05-08
date: 2026-05-08
tags: [rshop, acm, tls, certificate, cloudfront, migration, completed]
status: completed
env: dev
---

# ACM cert migration — `*.skleprenault.pl` — 2026-05-08

#rshop #acm #tls #cloudfront #migration

**STATUS: ZAKOŃCZONE ✅**

---

## Certyfikaty — stary vs nowy

| | Stary cert | Nowy cert |
|--|-----------|-----------|
| ARN | `3be77743-...-c6193c8bc977` | `72123357-...-f59e5282270e` |
| NotAfter | **2026-05-13** (wygasał) | **2026-11-22** |
| Status | ISSUED (nadal aktywny) | ISSUED |
| InUseBy | `[]` (odpięty) | `E3LC30816FMUSK` |
| SANs | 8 (w tym 2 NXDOMAIN .hu) | 7 (bez .hu) |

---

## Co zmieniono

### CloudFront `E3LC30816FMUSK`

| Zmiana | Przed | Po |
|--------|-------|-----|
| Certyfikat | `3be77743...` (wygasający) | `72123357...` (nowy, do 2026-11-22) |
| Alias count | 16 | 12 |
| Usunięte aliasy | — | 4 × HU (NXDOMAIN, niedziałające) |
| Status | Deployed | Deployed |

Usunięte aliasy (NXDOMAIN, nigdy nie działały):
- `dev.webshopdacia.hu`
- `devb.webshopdacia.hu`
- `dev.webshoprenault.hu`
- `devb.webshoprenault.hu`

Zachowane aliasy (12):
```
dev/devb.skleprenault.pl   dev/devb.sklepdacia.pl
dev/devb.eshopdacia.sk     dev/devb.eshoprenault.sk
dev/devb.eshopdacia.cz     dev/devb.eshoprenault.cz
```

---

## Weryfikacja po migracji

```
openssl s_client -connect d35g7vof2k6bj9.cloudfront.net:443 -servername dev.skleprenault.pl
→ subject=CN=*.skleprenault.pl
→ notAfter=Nov 21 23:59:59 2026 GMT ✅

Testowane SNI: dev.skleprenault.pl, dev.eshopdacia.sk, dev.eshoprenault.cz,
               dev.sklepdacia.pl, devb.eshoprenault.sk — wszystkie OK ✅
```

---

## Rollback

Stary certyfikat `3be77743-e90b-4d21-ba97-c6193c8bc977` NIE został usunięty.
Wygasa 2026-05-13, więc rollback jest możliwy do tej daty.

### Rollback CF do starego certu

```bash
# Pobierz aktualną konfigurację
aws cloudfront get-distribution-config \
  --id E3LC30816FMUSK --profile rshop --output json > /tmp/cf-rollback.json

# Edytuj ViewerCertificate.ACMCertificateArn na:
# arn:aws:acm:us-east-1:943111679945:certificate/3be77743-e90b-4d21-ba97-c6193c8bc977
# Przywróć aliasy HU jeśli potrzebne
# Zaktualizuj Aliases.Quantity odpowiednio

# Wykonaj update
aws cloudfront update-distribution \
  --id E3LC30816FMUSK \
  --distribution-config file:///tmp/cf-rollback.json \
  --if-match <CURRENT_ETAG> \
  --profile rshop
```

**Okno rollback:** do 2026-05-13 (wygaśnięcie starego certu)
**CF propagation:** ~5-15 minut

---

## Cleanup (po 2026-05-13)

Stary certyfikat można usunąć dopiero po upewnieniu się, że:
1. Żadna dystrybucja CF nie używa starego certu (InUseBy=[])
2. Minęło co najmniej 14 dni od migracji (buffer na rollback)

```bash
# Dopiero po potwierdzeniu — nie wcześniej niż 2026-05-23
aws acm delete-certificate \
  --certificate-arn arn:aws:acm:us-east-1:943111679945:certificate/3be77743-e90b-4d21-ba97-c6193c8bc977 \
  --region us-east-1 --profile rshop
```

Dodatkowo: usunąć orphaned cert `dev.eshoprenault.lt` (`173ae59f`, EXPIRED 2024-08-08, InUse=False).

---

## Monitorowanie nowego certu

```bash
# CloudWatch alarm: DaysToExpiry < 30
aws cloudwatch put-metric-alarm \
  --alarm-name "rshop-dev-cert-expiry-30d" \
  --namespace AWS/CertificateManager \
  --metric-name DaysToExpiry \
  --dimensions Name=CertificateArn,Value=arn:aws:acm:us-east-1:943111679945:certificate/72123357-5a77-4b60-84b1-f59e5282270e \
  --statistic Minimum --period 86400 \
  --evaluation-periods 1 --threshold 30 \
  --comparison-operator LessThanOrEqualToThreshold \
  --region us-east-1 --profile rshop
```

Nowy cert: RenewalEligibility=INELIGIBLE (za krótko po wystawieniu — zmieni się w ok. 60 dni).
Auto-renewal będzie działać gdy certyfikat będzie ELIGIBLE.
DNS CNAMEs walidacyjne są w miejscu — odnowienie przyszłości będzie automatyczne.

---

## Powiązane

- [[acm-cert-renewal-risk-2026-05-08]] — assessment ryzyka, RCA blokady
- [[rshop-context]] — architektura
