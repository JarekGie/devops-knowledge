---
title: ChatGPT context — MakoLab projects and vault contracts
domain: client-work
origin: vault-synthesis
classification: confidential
llm_exposure: allowed
cross_domain_export: prohibited
source_of_truth: vault
created: 2026-04-29
updated: 2026-04-29
tags: [chatgpt, context-pack, makolab, rshop, planodkupow, puzzler, maspex, vault-governance]
---

# ChatGPT Context Pack — MakoLab projects + vault governance

> Wklej całość na początku rozmowy z ChatGPT, gdy rozmowa dotyczy projektów MakoLab w tym vault.
> Zakres jest klientowski (`client-work`): nie mieszać z prywatnym R&D ani strategią produktową poza neutralnymi kontraktami vault.

**Zakres:** projekty MakoLab w vault: `rshop`, `planodkupow`, `puzzler-b2b`, `maspex` + opis działania vault i kontraktów agentów.  
**Data przygotowania:** 2026-04-29  
**Source of truth:** vault `devops-knowledge`; AWS/IaC/live state nadal nadrzędne dla diagnoz runtime.

---

## 1. Kim jestem / jak odpowiadać

Użytkownik to senior DevOps/SRE pracujący głównie na AWS, Terraform, CloudFormation, ECS Fargate, Jenkins i observability. Odpowiedzi powinny być techniczne, konkretne, operator-grade, bez marketingu.

Preferowany styl:
- najpierw werdykt / RCA / decyzja,
- potem evidence,
- potem bezpieczne next steps,
- rozdzielaj fakty od hipotez,
- przy AWS/IaC nie zgaduj; jeśli coś wymaga live check, powiedz to wprost,
- nie proponuj destrukcyjnych działań bez wyraźnego oznaczenia jako `proposed, do not run`.

---

## 2. Jak działa ten vault

Vault to operacyjna baza wiedzy Obsidian, nie wiki. Ma umożliwiać szybki powrót do kontekstu po przerwie i pracę z wieloma równoległymi wątkami.

Najważniejsze katalogi:

| Katalog | Rola |
|---|---|
| `00-start-here/` | onboarding vault, persona, jak używać |
| `01-inbox/` | szybkie przechwytywanie; nie archiwum |
| `02-active-context/` | żywy dashboard bieżącej pracy |
| `10-areas/` | wiedza domenowa: AWS, Terraform, CI/CD, observability |
| `20-projects/clients/mako/` | projekty MakoLab / klientowskie |
| `40-runbooks/` | procedury operacyjne i incydenty |
| `60-toolkit/` | devops-toolkit |
| `_system/` | kontrakty agentów, granice kontekstu, workflow |
| `_chatgpt/context-packs/` | paczki do ręcznego wklejenia do ChatGPT |

Zasada notatek: `objaw/problem -> kontekst -> rozwiązanie/działania -> uwagi`. Każda notatka ma działać standalone.

---

## 3. Inbox i active-context

### `01-inbox/`

`01-inbox/` to miejsce tymczasowe:
- szybkie notatki,
- luźne linki,
- fragmenty konfiguracji bez docelowego miejsca.

Nie należy tam zostawiać finalnych runbooków, decyzji ani trwałych opisów. Jeśli coś leży w inbox dłużej niż tydzień, trzeba przenieść albo usunąć.

### `02-active-context/`

To punkt wejścia po przerwie:
- `now.md` — bieżący stan operacyjny i ostatnie zapisane sesje,
- `current-focus.md` — priorytety tygodnia / sprintu,
- `open-loops.md` — rzeczy wiszące, które zajmują RAM,
- `waiting-for.md` — blokery zależne od innych osób / danych.

Aktualny focus na 2026-04-29:
- główny aktywny projekt: `rshop`,
- `maspex` w standby,
- `puzzler-b2b` w standby,
- `planodkupow` zapisany w kontekście operacyjnym, bez aktywnej pracy.

---

## 4. Kontrakty agentów i governance

### `_system/AGENTS.md`

Wspólny kontrakt dla Claude, Codex, ChatGPT i innych agentów:
- notatki po polsku,
- kod, komendy, ścieżki i identyfikatory po angielsku,
- nie duplikować treści; linkować,
- preferować małe zmiany,
- ChatGPT nie ma dostępu do filesystem, więc dostaje ręczne context packi,
- context pack format: zakres, kluczowe decyzje, stan, next step.

### `CLAUDE.md`

Kontrakt dla Claude Code:
- każdy wątek generujący wiedzę operacyjną powinien być zapisany do vault,
- obowiązkowe triggery zapisu: zmiana aktywnego zadania, implementacja, decyzja, incydent, koniec sesji,
- silny nacisk na aktualizację `02-active-context/now.md`,
- zawiera pełną mapę folderów, zasady NotebookLM i profil użytkownika.

### `CODEX.md`

Kontrakt dla Codexa:
- inspect first, potem edycja,
- czytać istniejący plik przed zmianą,
- preferować update istniejącej notatki zamiast tworzenia duplikatu,
- nie cofać cudzych zmian,
- po pracy w repo zewnętrznym wrócić z wynikiem do vault,
- działać cost-aware i nie przepisywać dużych plików bez potrzeby.

### Ważne kontrakty `_system/`

| Plik | Rola |
|---|---|
| `_system/DOMAIN_ISOLATION_CONTRACT.md` | jedna sesja LLM = jedna domena wrażliwości |
| `_system/LLM_CONTEXT_BOUNDARY_CONTRACT.md` | zasady przygotowania paczek kontekstu dla LLM |
| `_system/CHATGPT_WORKFLOW.md` | jak ręcznie eksportować/wracać z rozmów ChatGPT |
| `_system/AI_COST_AWARE_AGENT_CONTRACT.md` | AI FinOps lite: minimalny wystarczający kontekst i model tier |
| `_system/NOTEBOOKLM_CONTRACT.md` | NotebookLM jako warstwa syntezy, nie source of truth |

Zasada bezpieczeństwa: materiały klientowskie nie powinny być mieszane z `internal-product-strategy` ani `private-rnd`. Ta paczka dotyczy jednego klienta/obszaru MakoLab, więc jest dopuszczalnym `client-work` context packiem.

---

## 5. rshop — stan i kontekst

**Charakter projektu:** e-commerce Renault/Dacia, AWS ECS Fargate + CloudFormation, region `eu-central-1`, konto `943111679945`, profil CLI `rshop`.

Kluczowe zasoby:

```text
Root stack DEV: dev
ECSStack DEV: dev-ECSStack-1BLAWHL0P6JKO
Cluster DEV: rshop-dev-Klaster
Services DEV:
  rshop-dev-api-svc
  rshop-dev-backoffice-svc
  rshop-dev-frontend-svc1
  rshop-dev-frontend-svc2

Repo CFN:
  ~/projekty/mako/rshop-cloudformation/cloudformation/
Repo Jenkins:
  ~/projekty/mako/eshop-cicd/jenkinsfiles/BE/
Repo infra-rshop:
  ~/projekty/mako/aws-projects/infra-rshop/
```

Najważniejszy aktywny wzorzec: `CFN-MUT-001 — Nested Template Mutability Hazard`.

Problem:
- app-only deploy przez root stack `dev` replayował mutable nested `TemplateURL`,
- CloudFormation pobierał nowszy nested template z S3,
- VPCStack próbował zmienić `SiecDB` (`AWS::RDS::DBSubnetGroup`),
- `jenkinsit` nie miał `rds:ModifyDBSubnetGroup`,
- root stack wpadał w `UPDATE_ROLLBACK_FAILED`,
- recovery wymagało:

```bash
aws cloudformation continue-update-rollback \
  --stack-name dev \
  --resources-to-skip dev-VPCStack-FFQTYHECIX9M.SiecDB \
  --region eu-central-1 \
  --profile rshop
```

Wniosek architektoniczny:
- to nie był problem permission-only,
- nie dodawać ślepo `rds:ModifyDBSubnetGroup`,
- root app deploy jest unsafe, dopóki nested `TemplateURL` nie są immutable/version pinned.

Mitigation wykonany w Jenkins:
- dla `params.Envi == 'dev'` deploy targetuje `dev-ECSStack-1BLAWHL0P6JKO`, nie root `dev`,
- dev używa parametrów ECSStack (`apiimg`, `backofficeimg` lowercase),
- root-only params nie są wysyłane dla dev,
- dodany guard przed `execute-change-set`,
- qa/uat bez zmiany zachowania.

Nocny Jenkins failure po mitigation:
- nie był powrotem CFN-MUT-001,
- root `dev` nie został dotknięty,
- VPCStack/SiecDB nie pojawiły się,
- ECSStack rollback zakończył się `UPDATE_ROLLBACK_COMPLETE`,
- leaf failures: `ApiSvc` i `BackofficeSvc` `NotStabilized`,
- runtime wrócił do obrazów 1252 i zdrowych tasków.

Otwarte pętle:
- sprawdzić logi aplikacyjne dla API healthcheck 500 i backoffice startup/runtime,
- permanent fix: immutable nested `TemplateURL` / release artifact paths,
- wrócić do ECS `PropagateTags` / `EnableECSManagedTags` CFN patch przed re-enable Tag Policies LLZ.

Źródła w vault:
- `_chatgpt/context-packs/rshop-tag-policy.md`
- `20-projects/clients/mako/rshop-tagging-baseline-2026-04-24.md`
- `20-projects/clients/mako/rshop-tagging-remediation-2026-04-24.md`
- `40-runbooks/aws/cloudformation-nested-template-mutability-hazard.md`
- `40-runbooks/incidents/rshop-dev-ecsstack-rollback-2026-04-29.md`
- `02-active-context/now.md`

---

## 6. planodkupow — stan i kontekst

**Charakter projektu:** AWS CloudFormation, nested stacks, ECS, RabbitMQ, Redis, DB; konto `333320664022`, region `eu-central-1`, profil CLI `plan`.

Kluczowe zasoby:

```text
QA root stack:  planodkupow-qa
UAT root stack: planodkupow-uat
QA cluster:     planodkupow-qa-Klaster
UAT cluster:    planodkupow-uat-Klaster
```

Historia operacyjna:
- kilka incydentów `UPDATE_ROLLBACK_FAILED`,
- root stack miał zbyt szeroki blast radius,
- zmiany pozornie aplikacyjne/taggingowe dotykały RabbitMQ / Redis / DB / ALB,
- rollbacki były blokowane przez EOL, drift, brak IAM i zależności między nested stackami.

Najważniejsze incydenty:
- QA rebuild po problemach z Redis `5.0.0` EOL i RabbitMQ `3.8.6` EOL,
- QA RabbitMQ incident: brak `mq:UpdateBroker` i `mq:RebootBroker`,
- UAT RabbitMQ incident: live broker auto-upgrade do `3.13.7`, template nadal `3.8.6`, rollback próbował wrócić do EOL.

Decyzja architektoniczna:
- RabbitMQ powinno wyjść z lifecycle root stacka,
- `KlasterStack` ma pobierać `MQCS` z SSM:

```text
/planodkupow/<env>/rabbitmq/mqcs
```

Zasady pracy:
- nie proponować szerokiego root stack update bez analizy change setu,
- rozdzielać QA / UAT / PROD,
- oznaczać działania jako `SAFE`, `CAUTION`, `DO NOT TOUCH`,
- tagowanie wdrażać etapowo i addytywnie,
- przy RabbitMQ preferować osobny lifecycle i cutover przez SSM.

Źródła w vault:
- `_chatgpt/context-packs/planodkupow-ops-context-2026-04-24.md`
- `40-runbooks/incidents/planodkupow-qa-cfn-rebuild.md`
- `40-runbooks/incidents/planodkupow-qa-rabbitmq-rollback-failed.md`
- `40-runbooks/incidents/planodkupow-uat-rabbitmq-rollback-failed.md`
- `40-runbooks/planodkupow-rabbitmq-cfn-refactor.md`
- `40-runbooks/planodkupow-tagging-finops.md`
- `20-projects/clients/mako/planodkupow-runtime-verification-2026-04-26.md`
- `20-projects/clients/mako/planodkupow-ce-audit-2026-04-26.md`

---

## 7. puzzler-b2b — stan i kontekst

**Charakter projektu:** PBMS / puzzler-b2b, Terraform IaC, ECS, DocumentDB, Ocelot gateway, Swagger aggregation.

Repo:

```text
Infra repo: ~/projekty/mako/aws-projects/infra-puzzler-b2b-final
App/backend repo: ~/projekty/mako/pbms-backend
AWS profile: puzzler-pbms
Region obserwowany: eu-west-2
```

Najważniejsze zapisane problemy:

1. Swagger Core 500 na `/swagger/docs/v1/Core`
   - Gateway używa `SwaggerForOcelot`,
   - pobiera downstream `http://pbms-core-qa:8080/swagger/v1/swagger.json`,
   - podejrzany crash point: generacja Swagger schema dla `IMediaDeliveryModel`,
   - minimalny fix aplikacyjny: zmiana `DeliveryDefinition` z `IMediaDeliveryModel` na `object` w wskazanych modelach.

2. ECS service `infra-puzzler-b2b-dev-core` crash loop
   - exit code 134,
   - Hangfire.Mongo migracja `Version09` próbuje capped collection,
   - DocumentDB nie obsługuje `capped:true`,
   - rekomendacja: upgrade Hangfire.Mongo albo świadome obejście migracji.

3. Sync + Builder IaC
   - w `envs/dev` dodano moduły `sync_service` i `builder_service`,
   - dodano Cloud Map services,
   - placeholder images `nginx:latest`,
   - IaC gotowe, blocker: docelowe obrazy ECR i Ocelot config w backend image.

Źródła w vault:
- `20-projects/clients/mako/puzzler-b2b/troubleshooting.md`
- `02-active-context/current-focus.md`

---

## 8. maspex — stan i kontekst

**Charakter projektu:** Kapsel / Maspex, Terraform, CloudFront -> ALB -> ECS Fargate, Redis ElastiCache, Supabase/PostgREST jako downstream.

Kluczowe zasoby:

```text
AWS account: 969209893152
Region aplikacyjny: eu-west-1
CloudFront metrics: us-east-1
AWS profile: maspex-cli
Infra repo: ~/projekty/mako/aws-projects/infra-maspex
App repo: ~/projekty/mako/next-core-app

UAT hostname: kapsel.makotest.pl
UAT API CloudFront: E3J76RNXIE2YIG
UAT admin CloudFront: E3R9U1TWNUJZ11
ECS cluster: maspex-uat
Services:
  maspex-api
  maspex-admin-panel
  maspex-bot
Redis:
  maspex-uat.zwowz5.0001.euw1.cache.amazonaws.com:6379
```

Stan operacyjny:
- UAT monitoring i CloudFront static caching wdrożone częściowo,
- load testy 2026-04-28 i 2026-04-29 opisane w raportach,
- Terraform UAT plan blokowany przez niespójność S3 state digest vs DynamoDB digest,
- przygotowano, ale nie apply: observability/WAF/admin allowlist/per-path CloudFront logs zależnie od patcha lokalnego.

Load test 2026-04-29:
- peak około 11:25–11:27 UTC,
- ALB `HTTPCode_ELB_5XX_Count = 105`,
- API `TargetResponseTime max ≈ 29.99s`,
- 1758 logów `Redis circuit open` w jednej minucie,
- unhealthy task API przez `Request timed out`,
- ElastiCache wyglądał zdrowo: niski CPU, mała pamięć, brak evictions/swap.

Wniosek techniczny z analizy aplikacji:
- `Redis circuit open` jest rzucane przez aplikacyjny circuit breaker, nie przez ElastiCache,
- `VOTE_CACHE_WRITETHROUGH_FAIL` powstaje w fire-and-forget write-through po udanym vote,
- write-through nie jest `await`owany, więc raczej nie blokuje bezpośrednio vote response,
- może jednak powodować log storm, background promise churn, globalny circuit open i fallback GET/listing do DB/Supabase,
- zdrowy Redis backend może współistnieć z masowym `Redis circuit open` po stronie aplikacji.

Najważniejsze ścieżki kodu aplikacji:

```text
~/projekty/mako/next-core-app/app/api/slogan/vote/route.ts
~/projekty/mako/next-core-app/lib/redis/services/cache.service.ts
~/projekty/mako/next-core-app/lib/redis/client.ts
~/projekty/mako/next-core-app/app/api/slogan/route.ts
~/projekty/mako/next-core-app/app/api/health/route.ts
```

Rekomendowany kierunek dla dev teamu:
- zrate-limitować `[VOTE_CACHE_WRITETHROUGH_FAIL]`,
- metryki circuit transitions / Redis latency / write-through skipped-failed-success,
- rozdzielić circuit dla read cache i write-through,
- rozważyć bounded queue/coalescing dla vote write-through,
- instrumentować request duration per route i event-loop lag.

Źródła w vault:
- `_chatgpt/context-packs/maspex.md`
- `_chatgpt/context-packs/maspex-load-testing.md`
- `20-projects/clients/mako/maspex/troubleshooting.md`
- `20-projects/clients/mako/maspex/load-test-analysis-2026-04-28-1730-cest.md`
- `20-projects/clients/mako/maspex/load-test-analysis-2026-04-29-1300-cest.md`
- `20-projects/clients/mako/maspex/load-testing-meeting-prep.md`

---

## 9. Jak używać tej paczki w ChatGPT

Użyj tej paczki do:
- szybkiego wejścia w projekty MakoLab,
- porównania wątków operacyjnych między `rshop`, `planodkupow`, `puzzler-b2b`, `maspex`,
- przygotowania promptu do konkretnego projektu,
- streszczenia statusu dla handoffu.

Nie używaj tej paczki do:
- podejmowania decyzji produkcyjnych bez live AWS/IaC verification,
- mieszania z projektami innych klientów,
- generowania wewnętrznej strategii produktowej bez anonimizacji.

Jeśli rozmowa dotyczy konkretnego projektu, najlepiej od razu zawęzić:

```text
Na podstawie powyższego kontekstu pracujemy tylko nad projektem <rshop|planodkupow|puzzler-b2b|maspex>.
Nie mieszaj pozostałych projektów poza analogiami operacyjnymi.
Oddziel fakty z vault od hipotez.
```

---

## 10. Źródła użyte do przygotowania

```text
README.md
CLAUDE.md
CODEX.md
_system/AGENTS.md
_system/CHATGPT_WORKFLOW.md
_system/DOMAIN_ISOLATION_CONTRACT.md
_system/LLM_CONTEXT_BOUNDARY_CONTRACT.md
_system/AI_COST_AWARE_AGENT_CONTRACT.md
_system/LLM_CONTEXT_GLOBAL.md
01-inbox/README.md
02-active-context/current-focus.md
02-active-context/now.md
02-active-context/open-loops.md
_chatgpt/README.md
_chatgpt/context-packs/rshop-tag-policy.md
_chatgpt/context-packs/planodkupow-ops-context-2026-04-24.md
_chatgpt/context-packs/maspex.md
20-projects/clients/mako/puzzler-b2b/troubleshooting.md
20-projects/clients/mako/maspex/load-test-analysis-2026-04-29-1300-cest.md
```
