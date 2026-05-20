# Bootstrap — Maspex / Kapsel

> Punkt wejścia po przerwie. Przeczytaj w całości zanim wykonasz cokolwiek.

## Szybki stan

```
PROJEKT:  Maspex / Kapsel (kampania skupu akcji)
ACCOUNT:  969209893152 | eu-west-1 | profile: maspex-cli
REPO:     ~/projekty/mako/aws-projects/infra-maspex/
BRANCH:   feat/campaign-day-monitoring
VAULT:    20-projects/clients/mako/maspex/
GITLAB:   dostępny wyłącznie przez VPN korporacyjny
```

## Otwarte zadania

| ID | Opis | Stan | GO? |
|----|------|------|-----|
| D2 | image tag w tfvars `coreapp-uat-612` ≠ running `coreapp-prod-805` | open | nie — `ignore_changes` |
| D3 | orphaned ACM cert w TF state — `terraform state rm` przed next apply | open | nie (state operacja, nie apply) |
| P1 | autoscaling `min=30→8, max=45→30` (oszczędność ~$2 190/mies.) | conditional_go | **TAK** — warunki poniżej |
| P2 | potwierdź `terraform plan = 0 zmian` dla secret_arns fix | open | nie |
| PUSH | commit `6a14525` (WAF moderatorzy) niepushowany | pending_push | wymaga VPN |

**P1 — warunki przed GO:**
1. Alarm `RunningTaskCount < 6` skonfigurowany i przetestowany
2. Alarm `p99 latency > 500ms` skonfigurowany i przetestowany
3. 7 dni spokojnego monitoringu po kampanii

## Stan AWS PROD (ostatnia weryfikacja: 2026-05-20)

```
ECS:  min=30, max=45, desired=30
WAF:  DefaultAction=Block
      Allowlist: 195.117.107.110/32 (MakoLab) | 91.233.19.251/32 (Maspex) |
                 89.228.178.218/32 (Moderia) | 194.15.120.193/32 | 46.205.197.124/32 | 46.205.201.198/32 (moderatorzy)
ALB:  AlbRequestCount scaling target=200 (trigger ~123 req/s)
```

## Zasady bezpieczeństwa

- **AWS:** READ ONLY domyślnie — tylko `describe*`, `get*`, `list*`, metryki CloudWatch
- **Terraform:** `plan` wolny; `apply` wymaga osobnego GO
- **Git push:** wymaga VPN korporacyjnego; force push zabroniony
- **ECS:** nie zmieniaj `min/max/desired` bez GO i bez alarmów z P1
- **WAF:** `DefaultAction=Block` — nie otwieraj bez GO

## Kluczowe pliki

| Plik | Zawartość |
|------|-----------|
| `terraform/envs/prod/waf.tf` | WAF CloudFront-scope, IP allowlist |
| `terraform/envs/prod/ecs.tf` | ECS service config, autoscaling |
| `terraform/envs/prod/main.tf` | root module, provider config |
| `20-projects/clients/mako/maspex/session-log.md` | historia operacyjna |
| `20-projects/clients/mako/maspex/finops-capacity-analysis-2026-05-19.md` | analiza FinOps i uzasadnienie P1 |

## Startup checklist

1. Przeczytaj `profiles/maspex/profile.yaml` — sprawdź open_items
2. Przeczytaj ostatnie 2 wpisy w `session-log.md`
3. Sprawdź `02-active-context/now.md` — bieżący focus
4. Jeśli przerwa > 24h: uruchom `aws ecs describe-services` żeby potwierdzić stan ECS
5. **Nie wykonuj terraform apply bez GO**

## Cross-references

- [[maspex-session-log]] — historia operacyjna
- [[finops-capacity-analysis-2026-05-19]] — uzasadnienie P1 autoscaling
- [[now]] — bieżący aktywny kontekst
