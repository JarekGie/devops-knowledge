# Prompt: FinOps & Capacity Analysis — maspex-prod

> Szablon prompta do analizy FinOps. Przed użyciem zaktualizuj sekcje oznaczone `← ZMIEŃ`.

---

## Prompt do wklejenia

```
TRYB PRACY: ABSOLUTE READ ONLY
NIE WOLNO: terraform apply, update-service, zmieniać autoscalingu, restartować tasków,
ECS force deployment, zmieniać alarmów, zmieniać CloudWatch retention, żadnych write
actions w AWS.
Dozwolone WYŁĄCZNIE: aws describe*, aws get*, aws list*, aws logs*,
cloudwatch metric queries, cost explorer queries, pricing estimations lokalne,
jq/python do agregacji danych.

---

ŚRODOWISKO:
- Account: 969209893152 | Region: eu-west-1
- ECS Cluster: maspex-prod | Service: maspex-api
- Profile AWS CLI: maspex-cli
- CloudFront dist (twojkapsel.pl): E33PUJBAQ533K0  ← weryfikuj jeśli zmienił się dist
- CloudFront metrics: us-east-1 (namespace AWS/CloudFront)

BIEŻĄCA KONFIGURACJA AUTOSCALINGU:  ← ZMIEŃ jeśli zmieniono po poprzedniej analizie
- min=8, max=30
- ALBRequestCountPerTarget target=200
- CPU target=60%, Memory target=75%
- Scale-out cooldown: 30–60s, Scale-in cooldown: 300s

LOAD TEST REFERENCE (nie zmienia się):
- 30 tasków, peak 6 483 req/s, ~60% CPU → pojemność per task ~216 req/s

---

OKNO ANALIZY:  ← ZMIEŃ na aktualne 24h
- Od: YYYY-MM-DD 12:00 CEST (= HH:00 UTC)
- Do: YYYY-MM-DD 12:00 CEST (= HH:00 UTC)

---

ZBIERZ NASTĘPUJĄCE METRYKI:

1. ECS (namespace: ECS/ContainerInsights, cluster: maspex-prod, service: maspex-api)
   - CPUUtilization: avg/p95/max, granulacja 5-min + hourly
   - MemoryUtilization: avg/p95/max, granulacja 5-min + hourly
   - RunningTaskCount: avg/max
   - PendingTaskCount: max
   - DesiredTaskCount: max

2. ALB (namespace: AWS/ApplicationELB)
   - RequestCount: sum per 5-min window → oblicz peak req/s, avg req/s, min req/s
   - TargetResponseTime: avg/p95/p99 (granulacja 5-min)
   - HTTPCode_ELB_5XX_Count: sum
   - HealthyHostCount: min
   - RejectedConnectionCount: sum
   - Hourly breakdown całego okna

3. CloudFront (namespace: AWS/CloudFront, region: us-east-1, dist: E33PUJBAQ533K0)
   - Requests: sum hourly
   - 4xxErrorRate + 5xxErrorRate: avg
   - Oblicz cache hit rate: (CF total - ALB total) / CF total

4. Redis (namespace: AWS/ElastiCache, cluster: maspex-prod)
   - CPUUtilization: max
   - CurrConnections: max
   - CacheHits + CacheMisses → oblicz hit rate
   - Evictions: sum
   - BytesUsedForCache: max

5. Autoscaling activities:
   aws application-autoscaling describe-scaling-activities \
     --service-namespace ecs \
     --resource-id service/maspex-prod/maspex-api \
     --profile maspex-cli
   → wylistuj wszystkie scale-out i scale-in z timestampami i powodami

---

PYTANIA DO ODPOWIEDZI:

1. Jakie było rzeczywiste obciążenie środowiska?
2. Czy bieżące min-tasks jako baseline ma sens?
3. Ile tasków REALNIE potrzebujemy jako:
   - minimum baseline (nocne minimum)
   - recommended baseline (normalny dzień)
   - campaign baseline (dzień kampanii)
4. Czy autoscaling jest przewymiarowany? Czy max jest osiągany?
5. Czy parametry scaling policies (targets, cooldowns) wymagają zmiany?
6. Jeśli rekomendacja: podaj nowe wartości z uzasadnieniem technicznym i oceną ryzyka.

---

WYMAGANY FORMAT RAPORTU:

1. Executive Summary (jedna tabela: peak/avg/min req/s, CPU avg, Memory avg, autoscaling events, werdykt GO/NO GO)
2. Real Production Load (CloudFront + ALB numbers, porównanie z load test)
3. ECS Utilization Analysis (tabela metryk + interpretacja)
4. Traffic Analysis (hourly breakdown, profil dobowy, latency)
5. Autoscaling Analysis (events, trigger analysis, ocena czy target policies wymagają korekty)
6. Redis Capacity Analysis
7. Cost Analysis — TABELA:
   | Scenariusz | min | max | Avg tasks | Miesięcznie | Delta | Oszczędność% |
8. Recommendations — FINAL RECOMMENDATION z tabelą:
   | Parametr | Bieżąco | Rekomendacja |
   + required alarms po zmianie
9. Risk Assessment (tabela: ryzyko / prawdopodobieństwo / wpływ / mitigacja)
10. GO / CONDITIONAL GO / NO GO z warunkami

Zapisz raport do vault: 20-projects/clients/mako/maspex/finops-capacity-analysis-YYYY-MM-DD.md
```

---

## Historia użycia

| Data | Okno analizy | Werdykt | Raport |
|---|---|---|---|
| 2026-05-19 | 2026-05-18 12:00 – 2026-05-19 12:00 CEST | CONDITIONAL GO: min=8, max=30, −49% | [[finops-capacity-analysis-2026-05-19]] |

## Co zaktualizować przed kolejnym użyciem

- [ ] Okno analizy (daty)
- [ ] Bieżąca konfiguracja autoscalingu (min/max) — jeśli wdrożono zmiany po poprzednim audycie
- [ ] Sprawdź CloudFront dist ID (E33PUJBAQ533K0) — niezmienne jeśli brak recreate
- [ ] Dodaj do tabeli historii po zakończeniu
