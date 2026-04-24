---
title: Maspex — Wycena kosztów AWS as-is
date: 2026-04-24
tags: [finops, maspex, aws, estimate]
---

# Maspex — Wycena AWS as-is (2026-04-24)

**Zakres:** środowisko UAT + Preprod, region eu-west-1, konto 969209893152
**Metoda:** analiza Terraform (infra-maspex) + dane z CloudWatch investigation 2026-04-23

Pełna szczegółowa wycena wygenerowana jako odpowiedź Claude — przechowywana tutaj jako odniesienie.

## Kluczowe niepewności (do weryfikacji w AWS)

1. **ECS API task size (UAT)**: Live stan 2026-04-23 = 1024 CPU / 2048 MB; TF code = 4096 CPU / 8192 MB — czy apply był wykonany?
2. **NAT Gateway**: ECS ma `assign_public_ip = false`, brak VPC endpoints w TF → musi być NAT, ale niepotwierdzony
3. **CloudWatch logs volume**: zależy od intensywności load testów
4. **Container Insights**: włączone na klastrze ECS — dodaje ~$24/mies przy 4 vCPU

## Szacunek miesięczny (po korekcie zakresu — 2026-04-24)

Koszty shared VPC (NAT Gateway ~$35, NAT EIP ~$3,6) wyłączone z alokacji.

| Wariant | Przed korektą | Po korekcie |
|---------|--------------|-------------|
| Minimalny (API 1024/2048) | ~$420 | **~$420** (NAT był już $0 w tym wariancie) |
| Najbardziej prawdopodobny (API 1024/2048) | ~$470 | **~$431** |
| Ostrożny (API 4096/8192 jeśli TF apply) | ~$790 | **~$751** |

## Top 3 cost drivery

1. ECS Fargate compute (dominuje — zwłaszcza przy 4096/8192 API)
2. NAT Gateway (~$35/mies stały koszt)
3. Container Insights (~$24–79/mies zależnie od vCPU)

## Gdzie sprawdzić w AWS

```bash
# Task definition aktualny
AWS_PROFILE=maspex-cli aws ecs describe-services \
  --cluster maspex-uat \
  --services maspex-api \
  --query 'services[0].{taskDef:taskDefinition,running:runningCount,desired:desiredCount}' \
  --region eu-west-1

# NAT Gateway
AWS_PROFILE=maspex-cli aws ec2 describe-nat-gateways \
  --filter Name=state,Values=available \
  --region eu-west-1 \
  --query 'NatGateways[*].{ID:NatGatewayId,State:State,SubnetId:SubnetId}'

# Cost Explorer (ostatnie 30 dni)
AWS_PROFILE=maspex-cli aws ce get-cost-and-usage \
  --time-period Start=2026-03-24,End=2026-04-24 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=SERVICE,Key=SERVICE
```

## Powiązane

- [[troubleshooting]] — bieżące problemy UAT
- [[distributed-load-testing]] — koszty testów obciążeniowych (~$15-40/mies dodatkowe)
