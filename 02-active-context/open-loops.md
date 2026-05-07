# Open Loops

Sprawy w toku, bez zakończenia. Nie todo — rzeczy, które "wiszą" i zajmują RAM.

## Format

```
- [ ] opis — kontekst — kiedy wrócić / co odblokowuje
```

---

## Maspex (klient mako)

- [ ] Redis write-through / circuit breaker — 924,582 VOTE_CACHE_WRITETHROUGH_FAIL w teście 2026-05-05 19:00; Redis infra zdrowy, problem app-level; zbadać przy kolejnym teście
- [ ] maspex-api MemoryUtilization — narosła ~17%→~57% podczas testu; obserwować przy kolejnym teście, próg autoscaling 75%
- [ ] maspex-bot health check failures / replacements — osobny problem, nie powiązany z Redisem
- [ ] Terraform UAT plan — może blokować stary digest w DynamoDB `terraform-locks-969209893152`, key `maspex/uat/terraform.tfstate-md5`; safe recovery opisane w `now.md`
- [ ] infra-maspex lokalny patch observability/WAF — WAF admin allowlist + Athena/Glue per-path CloudFront logs; standby bez apply
- [ ] preprod API historycznie 0/3 DOWN — IAM AccessDeniedException do secretu; nie ruszane

## Puzzler-B2B / PBMS (klient mako)

- [ ] **decyzja: czy QA potrzebuje AzureAd?** — `appsettings.QA.json` ma sekcję AzureAd; jeśli nie potrzebuje → quick fix jq del na task definitions; jeśli potrzebuje → problem zamknięty
- [ ] commit staged `envs/dev/services.tf` — guardrail parity DEV; commit message: `fix(dev): align Terraform drift guardrails with QA ownership model`
- [ ] decyzja o `docs/db-access.md` — untracked w infra repo; nie mieszać bez explicit review
- [ ] CI/CD refaktor: zamienić pull-and-update na explicit task def builder (Wariant C) — szczegóły w session-log.md
- [ ] stworzyć QA-specific IAM roles (`infra-puzzler-b2b-qa-ecs-*`) zamiast reużywania DEV roles
- [ ] dodać `worker` do CI/CD deploy matrix — nigdy nie był deployowany przez pipeline
- [ ] opcjonalnie: healthcheck do obrazu/modułu jumphosta — ECS healthStatus jest UNKNOWN

## DRP-TFS (klient mako)

- [x] CRITICAL: leasing-filters api/core 0/2, CrashLoopBackOff — NAPRAWIONE 2026-05-07; Mongo RS 1 PRIMARY + 2 SECONDARY; pody 2/2 Running
- [x] CRITICAL: haproxy LoadBalancer EXTERNAL-IP `<pending>` — NAPRAWIONE 2026-05-07; mixed TCP+UDP usunięto (quic=false), stary ALB usunięty ręcznie; hostname: `a6293990bdab242b191283f7b757315e-286074f3d72658d6.elb.eu-central-1.amazonaws.com`
- [ ] powtórzyć cloud-detective live check po naprawie Mongo + LoadBalancer
- [ ] sprawdzić dane po mongorestore (backup key z S3 przywrócony przez mongorestore --drop)
- [ ] zaktualizować `k8s/loadbalancer/install.sh` aby trwale ustawiał `enablePorts.quic=false`

## Rshop (klient mako)

- [ ] rshop DEV — zebrać Jenkins console log dla nocnego failed build; AWS potwierdził ECSStack-only rollback
- [ ] rshop DEV — sprawdzić logi aplikacyjne dla nieudanego rollout: API ALB healthcheck HTTP 500 oraz backoffice startup/runtime
- [ ] rshop — permanent fix CFN-MUT-001: immutable nested `TemplateURL` / release artifact paths (aktualny zakaz root deploy to mitygacja tymczasowa)
- [ ] rshop CFN — brak `PropagateTags`, `EnableECSManagedTags` w cloudformation/{api,backoffice,frontend,frontend2}.yml + akcesoria2/svc.yml
- [ ] sprawdzić `Project=akcesoria2` w allowedValues LLZ Tag Policy przed re-enable

## Decyzje do podjęcia

- [ ] secure-ai-anonymizer: obniżyć priorytet `API_KEY_GENERIC` (priority=9) lub podnieść `AWS_ARN` (priority=8) — rola IAM triggeruje API_KEY_GENERIC jako FP → partial ARN leak

## Do sprawdzenia później

- [ ] secure-ai-anonymizer KF-001: S3 ARN regex (brak account ID w bucket ARNs)
- [ ] secure-ai-anonymizer KF-003: email z relaxed TLD (.internal, .example, .corp)

---

*Powiązane: [[waiting-for]] | [[current-focus]]*
