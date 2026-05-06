---
date: 2026-04-27
tags: [#incident, #terraform, #acm, #alb, #qa]
project: puzzler-b2b
env: qa
region: eu-central-1
---

# Problem: ALB HTTPS listener — certyfikat ACM w złym regionie

## Objaw

```
Error: creating ELBv2 Listener
api error ValidationError: Certificate ARN
'arn:aws:acm:eu-west-2:698220459519:certificate/f4c062f3-5476-41df-9204-e8afbebe036a'
is not valid
```

## Diagnoza

ALB `infra-puzzler-b2b-qa-puzzler` jest w `eu-central-1`.
Certyfikat ACM jest w `eu-west-2` (Londyn).
ACM cert dla ALB musi być w tym samym regionie co ALB — cross-region nie działa.

- Cert w eu-west-2: `pbms-api-qa.makotest.pl` + `www.pbms-api-qa.makotest.pl` — status ISSUED
- Certyfikaty w eu-central-1: **brak**

## Rozwiązanie

1. Zażądaj nowego certyfikatu ACM w `eu-central-1` dla domeny `pbms-api-qa.makotest.pl` (z SAN `www.pbms-api-qa.makotest.pl`)
2. Walidacja DNS — jeśli Route53 i rekordy walidacyjne już istnieją z eu-west-2, cert zostanie wydany automatycznie
3. Zaktualizuj ARN certu w Terraform (zmienna lub tfvars dla QA) na nowy ARN z eu-central-1
4. Ponów `terraform apply`

## Uwagi

- Nie przenoś certu z eu-west-2 — ACM nie obsługuje migracji między regionami, trzeba stworzyć nowy
- Profil AWS do tego konta: `puzzler-pbms` (konto 698220459519)
- Plik Terraform: `.terraform/modules/app_stack/modules/core/alb/main.tf` line 73, resource `aws_lb_listener.https[0]`
