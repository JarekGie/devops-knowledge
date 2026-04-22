# AWS Distributed Load Testing — maspex

#aws #load-testing #maspex #fargate #performance

**Data:** 2026-04-22
**Kontekst:** Wyniki load testu (Łukasz Fuchs) — 7.53% błędów na `/api/slogan/vote`. Potrzebujemy powtarzalnego narzędzia do testów obciążeniowych przed każdym releaste.

---

## TL;DR

| Co | Wartość |
|----|---------|
| Rozwiązanie | AWS Distributed Load Testing (SO0062) — gotowy CloudFormation stack |
| Deployment | ~15 minut, jeden stack CFN |
| Koszt stały (idle) | ~$1–3/mies. (S3 + DynamoDB) |
| Koszt testu (10 tasków × 30 min) | ~$15–30 jednorazowo |
| Rekomendacja użycia | przed każdym releaste do prod, po każdej zmianie `/api/slogan/vote` |

---

## Architektura rozwiązania

```
Web Console (CloudFront + S3 + Cognito)
       ↓
API Gateway → Lambda microservices → Step Functions
                                          ↓
                              ECS Fargate tasks (Taurus/JMeter)
                                          ↓
                              Target: CloudFront → ALB → maspex ECS
```

**Backend stack:**
- ECS Fargate — kontenery Taurus (JMeter + K6 + Locust)
- Step Functions — orkiestracja lifecycle tasków
- Lambda (6 funkcji): `ecr-checker`, `task-runner`, `task-status-checker`, `task-canceler`, `results-parser`, `real-time-data-publisher`
- DynamoDB — konfiguracja i wyniki testów
- S3 — scenariusze (JSON) i surowe wyniki (XML)
- CloudWatch Dashboard — metryki per test w czasie rzeczywistym

---

## Wdrożenie

### Krok 1 — Deploy CFN stack (jednorazowo)

```bash
# Przez konsolę AWS CloudFormation → Create Stack → With new resources
# Template URL:
https://solutions-reference.s3.amazonaws.com/distributed-load-testing-on-aws/latest/distributed-load-testing-on-aws.template

# Lub przez AWS CLI:
aws cloudformation create-stack \
  --stack-name maspex-load-testing \
  --template-url https://solutions-reference.s3.amazonaws.com/distributed-load-testing-on-aws/latest/distributed-load-testing-on-aws.template \
  --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
  --region eu-west-1
```

**Czas deployu:** ~15 minut  
**Po deployu:** email z URL do konsoli (CloudFront) + credentials Cognito

**Uwaga regionalna:** Cognito musi być dostępny w regionie. `eu-west-1` — OK.

### Krok 2 — Gdzie deployować

Rekomendacja: **osobne konto AWS** lub przynajmniej osobny region względem maspex UAT/preprod.

Opcja prosta (szybki start): deploy do `eu-west-1` na konto maspex (969209893152).

### Krok 3 — Dostęp

Po deployu dodaj użytkowników w Cognito User Pool (nie w UI rozwiązania — tylko przez konsolę Cognito lub CLI):

```bash
aws cognito-idp admin-create-user \
  --user-pool-id <pool-id> \
  --username jaroslaw.golab@makolab.com \
  --temporary-password <haslo> \
  --region eu-west-1
```

---

## Scenariusz testowy dla maspex

### Test 1 — baseline `/api/slogan/vote` (reprodukcja błędu)

| Parametr | Wartość |
|----------|---------|
| Target | `https://kapsel.makotest.pl/api/slogan/vote` (UAT) |
| Metoda | POST |
| Concurrency | 100 users/task |
| Ramp-up | 2 min |
| Hold time | 5 min |
| Tasks | 3 (symuluje ~300 concurrent users) |
| Region | eu-west-1 |

**Headers:**
```json
{
  "Content-Type": "application/json"
}
```

**Body (przykład):**
```json
{
  "sloganId": "test-slogan-123",
  "vote": "up"
}
```

### Test 2 — stress test przed releasem

| Parametr | Wartość |
|----------|---------|
| Target | `https://kapsel.makotest.pl` (wszystkie endpointy) |
| Concurrency | 200 users/task |
| Ramp-up | 5 min |
| Hold time | 15 min |
| Tasks | 5 |
| Typ | JMeter (.jmx z mixed endpoints) |

### Test 3 — smoke test po deployu (szybki, 5 min)

| Parametr | Wartość |
|----------|---------|
| Target | `https://kapsel.makotest.pl/api/health` |
| Concurrency | 50 users |
| Hold time | 2 min |
| Tasks | 1 |

---

## Kwoty i limity krytyczne

| Limit | Wartość | Dotyczy |
|-------|---------|---------|
| Fargate vCPU quota | sprawdź przed testem | eu-west-1 może mieć niski default |
| Ruch bez zgody AWS | < 1 Gbps | testy maspex: OK |
| CloudFront bez pre-approval | < 500k req/s lub < 300 Gbps | testy maspex: OK |
| Ramp-up dla CF | min 30 min dla dużych testów | dotyczy stress testu |
| Live data points | max 5,000 | tylko podczas trwania testu |

**Sprawdź quota przed pierwszym dużym testem:**
```bash
aws service-quotas get-service-quota \
  --service-code fargate \
  --quota-code L-3032A538 \
  --region eu-west-1
```

---

## Koszty

### Koszt stały (stack idle)

| Zasób | Koszt/mies. |
|-------|-------------|
| S3 (storage + requests) | ~$0.50 |
| DynamoDB (on-demand) | ~$0.01 |
| CloudFront (konsola) | ~$0.50 |
| **Razem idle** | **~$1–2/mies.** |

### Koszt testu

| Scenariusz | Tasks | Czas | Fargate (2vCPU/4GB) | Łącznie |
|-----------|-------|------|---------------------|---------|
| Smoke test | 1 | 5 min | ~$0.02 | ~**$0.05** |
| Baseline vote endpoint | 3 | 10 min | ~$0.18 | ~**$0.25** |
| Stress test pre-release | 5 | 25 min | ~$0.74 | ~**$1.00** |
| Full load test (10 tasków) | 10 | 30 min | ~$3.00 | ~**$3.50** |

**Koszt miesięczny przy 2–3 testach/tydzień:** ~$15–40/mies.

**Stawka Fargate eu-west-1:** ~$0.04048/vCPU-hour + $0.004445/GB-hour

---

## JMeter — gotowy skrypt dla maspex

Jeśli chcesz uruchomić mixed-endpoint test, stwórz `maspex-load-test.jmx`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<jmeterTestPlan>
  <hashTree>
    <TestPlan testname="maspex load test">
      <ThreadGroup>
        <!-- concurrency i ramp-up override z konsoli DLT -->
        <HTTPSamplerProxy>
          <stringProp name="HTTPSampler.domain">kapsel.makotest.pl</stringProp>
          <stringProp name="HTTPSampler.protocol">https</stringProp>
          <stringProp name="HTTPSampler.path">/api/slogan/vote</stringProp>
          <stringProp name="HTTPSampler.method">POST</stringProp>
        </HTTPSamplerProxy>
      </ThreadGroup>
    </TestPlan>
  </hashTree>
</jmeterTestPlan>
```

Gotowe pliki `.jmx` dla maspex — do stworzenia i commitowania do `infra-maspex/load-tests/`.

---

## Wycena wdrożenia (czas inżyniera)

| Czynność | Czas |
|----------|------|
| Deploy CFN stack + konfiguracja Cognito | ~1h |
| Napisanie scenariusza JMeter dla vote endpoint | ~2h |
| Baseline test + analiza wyników | ~1h |
| Dokumentacja wyników + rekomendacje | ~1h |
| **Łącznie** | **~5h** |

---

## Integracja z CI/CD (opcja na przyszłość)

Stack wystawia REST API (API Gateway + Cognito JWT):

```bash
# Uruchom test przez API (GitLab CI)
curl -X POST https://<api-id>.execute-api.eu-west-1.amazonaws.com/prod/scenarios \
  -H "Authorization: Bearer $DLT_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "testName": "pre-release-smoke",
    "testType": "simple-http",
    "endpoint": "https://kapsel.makotest.pl/api/health",
    "method": "GET",
    "concurrency": 50,
    "rampUp": 60,
    "holdFor": 120,
    "numRegions": 1,
    "tasksPerRegion": 1
  }'
```

Możliwe podpięcie jako job w GitLab pipeline po każdym deployu na UAT.

---

## Diagnoza błędów z testu Łukasza Fuchsa

**Obserwacja:** 7.53% błędów na `/api/slogan/vote` przy nieznanych warunkach testu.

**Hipotezy (w kolejności prawdopodobieństwa):**
1. **DB/Redis connection pool exhaustion** — przy dużej liczbie concurrent requests pool się wyczerpuje
2. **Brak ECS Auto Scaling** — 3 stałe taski api, brak scale-out pod obciążeniem
3. **Rate limiting w aplikacji** — celowe throttling na endpoint vote
4. **CloudFront cache miss storm** — pierwsze żądania do nowej wersji trafiają do origin równocześnie

**Jak to rozwiązać DLT:**
- Uruchom test baseline z 50 concurrent users → sprawdź próg błędów
- Zwiększaj do 100, 200, 300 → znajdź punkt nasycenia
- Sprawdź CloudWatch metryki Redis + ECS memory podczas testu

---

## Powiązane

- [[troubleshooting]] — bieżące problemy maspex
- [[../../../10-areas/aws/ecs]] — ECS Auto Scaling (do wdrożenia)
- `infra-maspex/terraform/envs/uat/` — konfiguracja UAT

---

*Utworzono: 2026-04-22 | Źródło: AWS DLT docs SO0062*
