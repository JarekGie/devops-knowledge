# Context Pack — maspex Load Testing (AWS DLT SO0062)

**Użycie:** Wklej ten plik do nowej rozmowy z ChatGPT / Codex gdy pracujesz nad scenariuszami testów obciążeniowych dla maspex lub integracją DLT z CI/CD.

---

## Projekt: maspex

**Infrastruktura:**
- Cloud: AWS, region eu-west-1, konto 969209893152
- ECS Fargate: klaster `maspex-uat`, 3 serwisy: `maspex-api` (3 tasks, 1024 CPU, 2048 MB), `maspex-admin-panel` (1 task), `maspex-bot` (1 task)
- Architektura ingress: CloudFront → ALB → ECS
- UAT: `kapsel.makotest.pl` (api), `kapsel-admin-uat.makotest.pl` (admin panel)
- Preprod: `twojkapsel.pl`
- IaC: Terraform, repo `infra-maspex`, envs/uat + envs/preprod
- Monitoring: CloudWatch alarms → SNS → `jaroslaw.golab@makolab.com`
- Brak ECS Auto Scaling (known gap)

**Znany problem:**
- Load test (Łukasz Fuchs, kwiecień 2026): 7.53% błędów na `POST /api/slogan/vote` przy nieznanej liczbie concurrent users
- Hipoteza: Redis connection pool exhaustion lub brak auto scaling

---

## AWS Distributed Load Testing (DLT) — SO0062

**Co to jest:** Gotowe rozwiązanie AWS (CloudFormation) do testów obciążeniowych na ECS Fargate z web console i REST API.

**Stack resources po deploy:**
- Web Console: CloudFront + S3 + Cognito (ReactJS)
- Backend: API Gateway → Lambda (6 funkcji) → Step Functions → ECS Fargate (Taurus/JMeter)
- Storage: S3 (scenariusze + wyniki), DynamoDB (metadata + wyniki agregowane)
- Monitoring: CloudWatch Dashboard per test

**Deploy (projekt używa Terraform, ale DLT nie ma modułu TF — opcje):**
```
Opcja A (rekomendowana): AWS CLI poza Terraform — tooling stack, nie app infra
Opcja B: aws_cloudformation_stack resource w envs/load-testing/main.tf

Template URL: https://solutions-reference.s3.amazonaws.com/distributed-load-testing-on-aws/latest/distributed-load-testing-on-aws.template
Czas: ~15 min
Region: eu-west-1 (Cognito wymagany)
Profile: maspex-cli
```

**Typy testów:** Simple HTTP, JMeter (.jmx), K6, Locust

**Parametry testu:**
- `concurrency` — virtual users per task
- `rampUpTime` — czas nabiegania (sekundy)
- `holdFor` — czas utrzymania obciążenia
- `tasksPerRegion` — liczba równoległych kontenerów Fargate
- `regions` — lista regionów AWS

**Fargate task size (default):** 2 vCPU, 4 GB RAM → ~200 concurrent users/task

**Koszty Fargate (eu-west-1):** $0.04048/vCPU-h + $0.004445/GB-h
- 1 task × 2 vCPU × 1h = ~$0.08
- 5 tasks × 30 min = ~$0.20 Fargate + overhead ~$0.05

**REST API (uruchomienie testu):**
```bash
POST /prod/scenarios
Authorization: Bearer <cognito-jwt>
Content-Type: application/json

{
  "testName": "maspex-vote-baseline",
  "testType": "simple-http",
  "endpoint": "https://kapsel.makotest.pl/api/slogan/vote",
  "method": "POST",
  "headers": {"Content-Type": "application/json"},
  "body": "{\"sloganId\":\"test-123\",\"vote\":\"up\"}",
  "concurrency": 100,
  "rampUp": 120,
  "holdFor": 300,
  "numRegions": 1,
  "tasksPerRegion": 3,
  "liveData": true
}
```

**Limity ważne dla maspex:**
- Ruch < 1 Gbps: bez zgody AWS → OK dla maspex UAT
- CloudFront: zalecany ramp-up ≥ 30 min przy dużych testach
- Fargate vCPU quota: sprawdź `L-3032A538` w eu-west-1 przed testem

---

## Scenariusze dla maspex (do implementacji)

### Scenariusz 1 — Reprodukcja błędu vote (priorytet)
```
Target: POST https://kapsel.makotest.pl/api/slogan/vote
Concurrency: 50 → 100 → 200 → 300 (osobne testy)
Ramp-up: 2 min
Hold: 5 min
Tasks: 1–3
Cel: znaleźć próg błędów
```

### Scenariusz 2 — Pre-release stress test
```
Target: mixed endpoints (JMeter .jmx)
Concurrency: 200/task
Hold: 15 min
Tasks: 5
Cel: smoke przed pushem na prod
```

### Scenariusz 3 — GitLab CI smoke po deploy UAT
```
Target: GET /api/health
Concurrency: 50
Hold: 2 min
Tasks: 1
Trigger: po każdym deploy na UAT
```

---

## Pliki do stworzenia w repo

```
infra-maspex/
  load-tests/
    maspex-vote-test.jmx       ← JMeter scenariusz vote endpoint
    maspex-smoke-test.jmx      ← szybki smoke po deploy
    maspex-stress-test.jmx     ← full stress pre-release
    README.md                  ← instrukcja uruchomienia
```

---

## Co Claude/Codex może tu pomóc

1. **Napisać `.jmx` scenariusze** — podaj endpointy, metody, oczekiwane kody odpowiedzi
2. **GitLab CI job** — `curl` do DLT API z Cognito JWT, wait for results, fail pipeline jeśli error rate > X%
3. **Analizować wyniki** — JSON z DynamoDB po teście, policzyć p95/p99, error rate per endpoint
4. **ECS Auto Scaling** — Terraform `aws_appautoscaling_target` + `aws_appautoscaling_policy` dla `maspex-api` na podstawie ALB RequestCountPerTarget

---

## Kontekst ECS Auto Scaling (gap do uzupełnienia)

Obecny stan: brak scaling. Moduł `modules/ecs-service/main.tf` — brak `aws_appautoscaling_*`.

Rekomendacja do dodania:
```hcl
resource "aws_appautoscaling_target" "this" {
  max_capacity       = 10
  min_capacity       = 2
  resource_id        = "service/${var.cluster_name}/${aws_ecs_service.this.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu" {
  name               = "${var.name}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.this.resource_id
  scalable_dimension = aws_appautoscaling_target.this.scalable_dimension
  service_namespace  = aws_appautoscaling_target.this.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 60.0
  }
}
```

---

*Wygenerowano: 2026-04-22*
