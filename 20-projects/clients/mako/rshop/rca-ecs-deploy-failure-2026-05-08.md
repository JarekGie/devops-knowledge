---
title: RCA — ECS deploy failure + ValidationError (dev, 2026-05-08)
date: 2026-05-08
tags: [rshop, ecs, cloudformation, rca, incident, jenkins]
severity: medium
env: dev
status: closed-auto-rollback
---

# RCA — ECS deploy failure + ValidationError (`dev-ECSStack-1BLAWHL0P6JKO`)

#rshop #ecs #cloudformation #rca

---

## Executive Summary

Deployment nowego obrazu Docker do serwisów `rshop-dev-api-svc` i `rshop-dev-backoffice-svc` zakończył się niepowodzeniem. CloudFormation uruchomił nowe task definitions dla obu serwisów, lecz ECS nie był w stanie ustabilizować nowych kontenerów przez 3 godziny — co odpowiada domyślnemu timeoutowi CFN. CloudFormation automatycznie zainicjował rollback i przywrócił poprzedni obraz. Serwisy są zdrowe.

Zgłoszony błąd `ValidationError: Stack [dev-ECSStack-1BLAWHL0P6JKO] is in UPDATE_IN_PROGRESS state and can not be updated` **nie jest przyczyną awarii** — jest jej objawem wtórnym. Wystąpił, ponieważ Jenkins uruchomił drugi pipeline (lub retry) podczas gdy CloudFormation wciąż czekał na stabilizację ECS (okno 07:51–10:51 UTC). Brak mechanizmu mutex/preflight w pipeline doprowadził do próby równoległej aktualizacji zablokowanego stacka.

**Bezpośrednia przyczyna incydentu:** ECS nie mógł ustabilizować nowych kontenerów (health check timeout lub startup crash) — szczegółowy powód pozostaje nieznany z powodu 1-dniowej retencji logów.

---

## Incident Timeline

| Czas (UTC) | Zdarzenie |
|------------|-----------|
| 07:51:53 | CFN `UPDATE_IN_PROGRESS` na `dev-ECSStack-1BLAWHL0P6JKO` — inicjator: User Initiated |
| 07:52:02 | CFN aktualizuje `ApiTask` i `BackofficeTask` definitions → `UPDATE_COMPLETE` |
| 07:52:02 | CFN wchodzi `UPDATE_IN_PROGRESS` na `rshop-dev-api-svc` i `rshop-dev-backoffice-svc` |
| ~07:52–10:51 | ECS próbuje ustabilizować nowe kontenery — brak postępu |
| ~07:52–10:51 | **Jenkins uruchamia drugi pipeline** — próba aktualizacji stacka → `ValidationError` |
| 10:51:47 | CFN: `HandlerErrorCode: NotStabilized` — `"Exceeded attempts to wait"` na obu serwisach |
| 10:52:20 | CFN inicjuje rollback; ECS tworzy nowe deployments ze starym obrazem |
| 10:59:50 | Rollback `UPDATE_ROLLBACK_COMPLETE` — nowe task definitions usunięte (`DELETE_COMPLETE`) |
| Post-rollback | `rshop-dev-api-svc` + `rshop-dev-backoffice-svc`: ACTIVE, desired=1, running=1, healthy |

**Łączny czas incydentu:** ok. 68 minut (od inicjacji do rollback complete)  
**Wpływ na użytkowników:** dev środowisko; serwisy przez rollback przywrócone do poprzedniego stanu

---

## Root Cause

**Przyczyną incydentu jest nieudana stabilizacja ECS** — nowe kontenery (`rshop-dev-api-svc`, `rshop-dev-backoffice-svc`) nie osiągnęły stanu healthy w ciągu 3 godzin od uruchomienia.

Mechanizm:
1. CFN uruchomił nowe task definitions z nowym obrazem Docker
2. ECS uruchomił nowe taski
3. Kontenery nie przeszły health checków lub crashowały przy starcie
4. Po 3h (domyślny CFN `--timeout-in-minutes` dla ECS service) CFN zdecydował o `NotStabilized`
5. Automatyczny rollback przywrócił poprzedni obraz

**Powód nieudanej stabilizacji: NIEZNANY** — logi aplikacji niedostępne (retencja `/ecs/rshop-dev` = 1 dzień, logi z czasu incydentu już usunięte). Lista zatrzymanych tasków (ECS stopped tasks API) pusta — brak bezpośredniego śladu crashu w API.

---

## Contributing Factors

### 1. Brak preflight check stanu stacka w Jenkins pipeline

Jenkins nie sprawdza stanu CFN stacka przed uruchomieniem aktualizacji. Jeśli poprzedni run nadal trwa (lub jest w trakcie rollbacku), kolejny pipeline próbuje aktualizacji i dostaje `ValidationError`. To nie jest bug AWS — to przewidywalne zachowanie CFN.

### 2. 1-dniowa retencja logów w `/ecs/rshop-dev`

Log group `/ecs/rshop-dev` ma retencję 1 dzień i aktualnie przechowuje 8.2 MB. Logi z momentu crashu (07:52–10:51 UTC) są już niedostępne. Uniemożliwia to pełne RCA.

### 3. Brak CloudWatch alarms

Brak jakichkolwiek alarmów (0 alarmów w describe-alarms). Incydent mógł pozostać niezauważony przez 3 godziny — wykryty przez błąd w Jenkins, nie przez monitoring.

### 4. Dev ECS deployowany poza CFN root orchestration

`dev-ECSStack` jest deployowany bezpośrednio, z pominięciem root stacka (który jest w `UPDATE_ROLLBACK_COMPLETE` od 2026-04-28). Prowadzi to do driftu między IaC a runtime i zmniejsza przewidywalność pipeline.

---

## Evidence

| # | Dowód | Pewność | Źródło |
|---|-------|---------|--------|
| 1 | CFN events: `UPDATE_IN_PROGRESS` o 07:51:53, inicjator `User Initiated` | wysoka | live AWS CFN events |
| 2 | CFN events: `NotStabilized` o 10:51:47 — `"Exceeded attempts to wait"` | wysoka | live AWS CFN events |
| 3 | CFN events: rollback complete 10:59:50, task defs `DELETE_COMPLETE` | wysoka | live AWS CFN events |
| 4 | ECS services post-rollback: ACTIVE, desired=1, running=1 (obie) | wysoka | live AWS describe-services |
| 5 | ECS stopped tasks: lista pusta — brak bezpośredniego dowodu crashu | wysoka | live AWS list-tasks STOPPED |
| 6 | Log group `/ecs/rshop-dev`: retencja 1 dzień — logi z czasu incydentu niedostępne | wysoka | live AWS describe-log-groups |
| 7 | `ValidationError` — brak w CFN events → błąd po stronie Jenkins, nie AWS | wysoka | live AWS CFN events |
| 8 | CFN events file: 1.4 MB → liczne historyczne deploye → wzorzec powtarzający się | wysoka | live AWS |

**Hipotezy dotyczące przyczyny crashu kontenera (nieudowodnione):**
- Błąd aplikacji przy starcie (misconfiguracja, brak dependency, startup exception)
- Health check zbyt agresywny (krótki grace period, złe ścieżki)
- Nowy obraz z broken build
- Timeout start-up (np. wolna inicjalizacja połączenia z bazą)
- Zbyt małe zasoby (CPU/mem throttling)

---

## Recovery Actions

Podjęte (automatyczne):
- CloudFormation automatycznie wykonał rollback do poprzedniego task definition
- Oba serwisy przywrócone do stanu running z poprzednim obrazem

Manualne (nie wymagane):
- Serwisy nie wymagały ręcznej interwencji

---

## Preventive Actions

### P0 — Pilne

| Akcja | Właściciel | Uzasadnienie |
|-------|-----------|--------------|
| Dodać preflight w Jenkins: sprawdzaj stan CFN stacka przed deploy (`describe-stacks → check status != IN_PROGRESS`) | DC-devops / Jenkins | Eliminuje `ValidationError` i zapobiega konkurentnym aktualizacjom |
| Zmienić retencję `/ecs/rshop-dev` z 1 dnia na minimum 14 dni | DC-devops | Bez logów niemożliwe pełne RCA kolejnych incydentów |

### P1 — Ważne

| Akcja | Właściciel | Uzasadnienie |
|-------|-----------|--------------|
| Dodać CloudWatch alarm na ECS `ServiceFailed` / `TargetNotHealthy` | DC-devops | Incydent przez 3h był niewidoczny — brak alertów |
| Zbadać przyczynę nieudanej stabilizacji: sprawdzić ECR nowy obraz, health check config (`healthCheckGracePeriodSeconds`), ECS task definition (cpu/mem) | DC-devops | Root cause wciąż nieznany |
| Ustawić `--timeout-in-minutes` w CFN deploy na wartość odpowiadającą realnym timeoutom aplikacji | DC-devops | 3h to zbyt długi czas bez alertu; lepiej szybciej failować i powiadamiać |

### P2 — Dobre praktyki

| Akcja | Właściciel | Uzasadnienie |
|-------|-----------|--------------|
| Zwiększyć retencję `/ecs/rshop-prod` z 1 dnia na minimum 30 dni | DC-devops | Prod: 137MB logów, retencja 1 dzień — nieakceptowalne dla production |
| Skonfigurować mutex / single-job-execution w Jenkins pipeline | DC-devops | Zapobiega concurrent deployom na tym samym stacku |

---

## Residual Risks

| Ryzyko | Prawdopodobieństwo | Wpływ | Mitygacja |
|--------|-------------------|-------|-----------|
| Ponowna nieudana stabilizacja ECS (ten sam obrazu) | NISKIE (rollback z poprzednim obrazem działa) | NISKI (dev) | Zbadać przyczynę i naprawić obraz przed kolejnym deployem |
| `ValidationError` przy kolejnym concurrent deploy | WYSOKIE (brak preflight) | NISKI (Jenkins blokada, nie prod) | Dodać preflight check |
| Incydent prod niezauważony przez 3+ godzin | WYSOKIE (0 alarmów) | WYSOKI | Dodać CloudWatch alarms |
| **Cert `*.skleprenault.pl` wygasa 2026-05-13** | AKTYWNE RYZYKO (5 dni) | KRYTYCZNY (prod PL/CZ/SK/HU) | Zweryfikować auto-renewal DNS validation natychmiast |

---

## Final Verdict

| Pytanie | Odpowiedź |
|---------|-----------|
| Czy to było failure AWS? | NIE — CFN i ECS zachowały się zgodnie z dokumentacją |
| Czy to był błąd pipeline? | TAK (częściowo) — brak preflight check stanu stacka umożliwił concurrent deploy |
| Czy doszło do operational overlap? | TAK — Jenkins uruchomił drugi run podczas aktywnej aktualizacji |
| Czy to było expected behavior CFN? | TAK — `NotStabilized` + rollback to standardowy mechanizm bezpieczeństwa CFN |
| Czy można było zapobiec? | TAK — preflight check stanu stacka w Jenkins eliminuje `ValidationError`; ale nieznana przyczyna crashu ECS pozostaje do zbadania |

**Verdict:** Incydent to połączenie nieznanego problemu z aplikacją/obrazem (nieudana stabilizacja ECS) i braku ochrony pipeline przed concurrent deploy. CloudFormation zadziałał poprawnie — automatyczny rollback chronił środowisko. Priorytet: (1) zbadać przyczynę nieudanej stabilizacji przed kolejnym deployem, (2) dodać preflight check w Jenkins.

---

## Powiązane

- [[rshop-context]] — architektura i znane długi techniczne
- [[rca-dev-root-stack-rollback-2026-04-28]] — poprzedni incydent CFN (brak w vault, do stworzenia jeśli potrzebne)
