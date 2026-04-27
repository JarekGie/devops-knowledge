---
date: 2026-04-27
tags: [#aws, #securitygroup, #alb, #network, #access-control]
project: puzzler-b2b
env: dev, qa
region: eu-west-2
---

# ALB IP restriction — dostęp tylko z MakoLab office

## Stan po zmianie

Dostęp do wszystkich domen dev i qa ograniczony do `195.117.107.110/32` (MakoLab office).

**Domeny objęte ograniczeniem:**
- `pbms-dev.makotest.pl` / `www.pbms-dev.makotest.pl`
- `pbms-api-dev.makotest.pl` / `www.pbms-api-dev.makotest.pl`
- `pbms-qa.makotest.pl` / `www.pbms-qa.makotest.pl`
- `pbms-api-qa.makotest.pl` / `www.pbms-api-qa.makotest.pl`

## Infrastruktura

| Środowisko | ALB | Security Group |
|---|---|---|
| DEV | `infra-puzzler-b2b-dev-puzzler` | `sg-0fdd50363ab8f15c4` |
| QA | `infra-puzzler-b2b-qa-puzzler` | `sg-0ac35997fda23085e` |

Region: `eu-west-2` (nie eu-central-1)
Konto: `698220459519` (profil: `puzzler-pbms`)

## Zastosowane reguły ingressowe (oba SG)

| Port | Protokół | CIDR | Opis |
|---|---|---|---|
| 80 | TCP | `195.117.107.110/32` | MakoLab office HTTP |
| 443 | TCP | `195.117.107.110/32` | MakoLab office HTTPS |

Poprzednie reguły (`0.0.0.0/0` na portach 80 i 443) zostały usunięte.

## Cofnięcie zmiany (rollback)

```bash
# DEV
aws ec2 revoke-security-group-ingress \
  --group-id sg-0fdd50363ab8f15c4 \
  --protocol tcp --port 80 --cidr 195.117.107.110/32 \
  --region eu-west-2 --profile puzzler-pbms

aws ec2 revoke-security-group-ingress \
  --group-id sg-0fdd50363ab8f15c4 \
  --protocol tcp --port 443 --cidr 195.117.107.110/32 \
  --region eu-west-2 --profile puzzler-pbms

aws ec2 authorize-security-group-ingress \
  --group-id sg-0fdd50363ab8f15c4 \
  --ip-permissions '[{"IpProtocol":"tcp","FromPort":80,"ToPort":80,"IpRanges":[{"CidrIp":"0.0.0.0/0","Description":"HTTP"}]}]' \
  --region eu-west-2 --profile puzzler-pbms

aws ec2 authorize-security-group-ingress \
  --group-id sg-0fdd50363ab8f15c4 \
  --ip-permissions '[{"IpProtocol":"tcp","FromPort":443,"ToPort":443,"IpRanges":[{"CidrIp":"0.0.0.0/0","Description":"HTTPS"}]}]' \
  --region eu-west-2 --profile puzzler-pbms

# QA — te same komendy z group-id sg-0ac35997fda23085e
```

## Uwagi

- Infrastruktura puzzler-b2b jest w `eu-west-2`, nie `eu-central-1` — pamiętaj przy wszystkich operacjach AWS
- Zmiana jest poza Terraform/CFN — przy następnym `terraform apply` na SG stacku reguły zostaną nadpisane z powrotem na `0.0.0.0/0` jeśli template nie zostanie zaktualizowany
- Jeśli ograniczenie ma być trwałe, należy zaktualizować SG.yaml / moduł ALB w repozytorium projektu
