# Maspex UAT — Runbook: test kalibracyjny autoscalingu ECS

#maspex #loadtest #autoscaling #runbook

Środowisko: **UAT** | Profil AWS: `maspex-cli` | Region: `eu-west-1`

Cel: zweryfikować, że polityka `ALBRequestCountPerTarget` (TargetValue=10,000) reaguje poprawnie na każdym poziomie obciążenia i ECS skaluje się przed osiągnięciem incident zone.

---

## Zasoby

| Zasób | Wartość |
|-------|---------|
| ECS cluster | `maspex-uat` |
| ECS service | `maspex-api` |
| ALB | `app/maspex-uat/68317764a66425bd` |
| Target Group | `targetgroup/maspex-uat-api-3000/97cac4c72be43344` |
| CloudFront UAT | `E3J76RNXIE2YIG` |
| Hostname UAT | `kapsel.makotest.pl` |
| ASG generatorów | `maspex-uat-loadtest` |
| WAF UAT IP Set | `maspex-uat-loadtest-allowlist` (`76b89f7c-b8c9-4725-ad8c-56600786fe8e`) |

**Krytyczne:** Do testu UAT używaj **wyłącznie `loadtest-ctrl.sh`**.
`loadtest-fleet-start.sh` i `loadtest-fleet-stop.sh` aktualizują **PROD WAF** — nie używaj ich do UAT.

---

## Matematyka scale-out

| ALB req/s | req/task/min @ 9 tasks | Oczekiwany desired | Czas do running |
|-----------|------------------------|-------------------|-----------------|
| < 1,500   | < 10,000               | 9 (brak)          | — |
| ~2,000    | ~13,333 → 12 tasks     | **12**            | 2-4 min |
| ~2,500    | ~15,000 → 15 tasks     | **15**            | 2-4 min |
| ~3,000    | ~18,000 → 18 tasks     | **18**            | 2-4 min |
| ~3,500    | ~21,000 → cap 20       | **20**            | 2-4 min |
| ~4,500    | 13,500/task @ 20 tasks | **20** (capped)   | — |

Scale-out cooldown=30s, task start ≈ 60-90s. Od przekroczenia TargetValue do running=N: **2-4 min**.

---

## SANITY STAGE

```bash
# S1 — ECS healthy
aws ecs describe-services \
  --cluster maspex-uat --services maspex-api \
  --profile maspex-cli --region eu-west-1 \
  --query 'services[0].{desired:desiredCount,running:runningCount,pending:pendingCount}' \
  --output table
# ✅ desired=9, running=9, pending=0

# S2 — 3 autoscaling policies aktywne
aws application-autoscaling describe-scaling-policies \
  --service-namespace ecs \
  --resource-id service/maspex-uat/maspex-api \
  --profile maspex-cli --region eu-west-1 \
  --query 'ScalingPolicies[].PolicyName' --output table
# ✅ 3 policies: alb-request-count, cpu, memory

# S3 — Start floty (4 generatory, UAT WAF)
cd /path/to/infra-maspex
./scripts/loadtest-ctrl.sh --run

# S4 — Weryfikacja WAF (4 IP w UAT IP set)
aws wafv2 get-ip-set \
  --name maspex-uat-loadtest-allowlist \
  --id 76b89f7c-b8c9-4725-ad8c-56600786fe8e \
  --scope CLOUDFRONT --region us-east-1 --profile maspex-cli \
  --query 'IPSet.Addresses' --output table
# ✅ 4 adresy /32

# S5 — SSH na gen #1, sprawdź monitoring stack
ssh ec2-user@<GEN1_PUBLIC_IP>
docker ps  # influxdb i grafana muszą działać
# Jeśli nie:
cd ~/loadtest && docker compose up -d

# S6 — Zanotuj private IP gen #1 (INFLUX_HOST)
hostname -I | awk '{print $1}'

# S7 — Connectivity test z generatora
curl -o /dev/null -s -w "%{http_code} %{time_total}s\n" https://kapsel.makotest.pl/
# ✅ 200 lub 304. Błąd 403 = IP nie w WAF.
```

---

## SSH na generatory (4 terminale)

```bash
# Pobierz IP wszystkich 4 generatorów
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=maspex-uat-loadtest" \
            "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].[PublicIpAddress,PrivateIpAddress]' \
  --output table --profile maspex-cli --region eu-west-1

# Otwórz 4 terminale, na każdym:
ssh ec2-user@<PUBLIC_IP_N>
```

Alternatywnie: `./scripts/loadtest-ctrl.sh --ssh` (menu z wyborem jednego generatora).

---

## Monitoring (osobne okno terminala)

```bash
# ECS desired/running/pending — co 15s
watch -n 15 'aws ecs describe-services \
  --cluster maspex-uat --services maspex-api \
  --profile maspex-cli --region eu-west-1 \
  --query "services[0].{desired:desiredCount,running:runningCount,pending:pendingCount}" \
  --output table'

# Scaling activities (timing)
aws application-autoscaling describe-scaling-activities \
  --service-namespace ecs \
  --resource-id service/maspex-uat/maspex-api \
  --profile maspex-cli --region eu-west-1 \
  --max-results 5 \
  --query 'ScalingActivities[].{time:StartTime,status:StatusCode,cause:Cause}' \
  --output table

# ALB 5xx (ostatnie 2 min)
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name HTTPCode_ELB_5XX_Count \
  --dimensions Name=LoadBalancer,Value=app/maspex-uat/68317764a66425bd \
  --start-time $(python3 -c "import datetime; print((datetime.datetime.utcnow()-datetime.timedelta(minutes=2)).strftime('%Y-%m-%dT%H:%M:%SZ'))") \
  --end-time $(python3 -c "import datetime; print(datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ'))") \
  --period 60 --statistics Sum \
  --profile maspex-cli --region eu-west-1 --output table

# HealthyHostCount (ostatnie 2 min)
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name HealthyHostCount \
  --dimensions \
    Name=LoadBalancer,Value=app/maspex-uat/68317764a66425bd \
    Name=TargetGroup,Value=targetgroup/maspex-uat-api-3000/97cac4c72be43344 \
  --start-time $(python3 -c "import datetime; print((datetime.datetime.utcnow()-datetime.timedelta(minutes=2)).strftime('%Y-%m-%dT%H:%M:%SZ'))") \
  --end-time $(python3 -c "import datetime; print(datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ'))") \
  --period 60 --statistics Average \
  --profile maspex-cli --region eu-west-1 --output table
```

---

## STAGE 0 — Kalibracja VU (5 min)

Na każdym z 4 generatorów:
```bash
K6_OUT=influxdb=http://<INFLUX_HOST>:8086/k6 \
  k6 run --vus 10 --duration 5m scripts/kapsel.js
```

Po 2 min odczytaj ALB RequestCount (patrz monitoring powyżej).

```
rps_per_vu = alb_rps_observed / (10 vus × 4 generatory)
vus_stage_N = ceil(target_rps_N / (rps_per_vu × 4))
```

✅ Oczekiwane: desired=9, 5xx=0.

---

## STAGE 1 — ~2,000 req/s ALB (8 min)

```bash
K6_OUT=influxdb=http://<INFLUX_HOST>:8086/k6 \
  k6 run --vus <VUS_STAGE_1> --duration 8m scripts/kapsel.js
```

✅ Przejście: desired=12, running=12, 5xx<10/min, HealthyHostCount≥9

---

## STAGE 2 — ~2,500 req/s ALB (8 min)

```bash
K6_OUT=influxdb=http://<INFLUX_HOST>:8086/k6 \
  k6 run --vus <VUS_STAGE_2> --duration 8m scripts/kapsel.js
```

✅ Przejście: desired=15, running=15, 5xx<10/min

---

## STAGE 3 — ~3,500 req/s ALB (8 min)

```bash
K6_OUT=influxdb=http://<INFLUX_HOST>:8086/k6 \
  k6 run --vus <VUS_STAGE_3> --duration 8m scripts/kapsel.js
```

✅ Przejście: desired=20, running=20, req/task≈175 req/s (safe), 5xx<50/min

---

## STAGE 4 (go/no-go) — ~4,500 req/s ALB (5 min)

Uruchom tylko jeśli Stage 3: running=20, pending=0, 5xx<50/min.

```bash
K6_OUT=influxdb=http://<INFLUX_HOST>:8086/k6 \
  k6 run --vus <VUS_STAGE_4> --duration 5m scripts/kapsel.js
```

✅ Sukces: 5xx<200/min, HealthyHostCount≥16, brak killed tasks.

---

## STOP CONDITIONS

| Sygnał | Próg | Akcja |
|--------|------|-------|
| ELB 5xx | > 100/min i rośnie | Ctrl+C, oceń |
| ELB 5xx | > 300/min | ABORT |
| HealthyHostCount | < 6 | ABORT |
| ECS tasks killed (health timeout) | jakikolwiek | ABORT |
| running spada zamiast rosnąć | regresja | ABORT |
| k6 error rate (Grafana) | > 15% i rośnie | ABORT |

---

## Ramp-down i stop

1. Ctrl+C na k6 na wszystkich 4 generatorach
2. Czekaj 5-7 min (scale-in cooldown=300s) — obserwuj watch
3. desired powinno wrócić do 9

```bash
./scripts/loadtest-ctrl.sh --stop
# ✅ UAT WAF wyczyszczony, ASG desired=0
```

---

## Uwagi

- `loadtest-fleet-start/stop.sh` → **PROD WAF** — nie używaj do UAT
- `loadtest-ctrl.sh` → **UAT WAF** — jedyna rodzina skryptów dla tego testu
- Autoscaling: cooldown scale-in=300s; nie przerywaj testu wcześniej
- Grafana: `http://<GEN1_PUBLIC_IP>:3000` podczas testu
- Kalibracja load testów: [[loadtest-2026-05-14-analysis]], [[loadtest-2026-05-14-analysis-test2]]
