# Current Focus

> Co jest ważne w tym tygodniu / sprincie. Nie lista todo — priorytety.

## Główny cel

```
Przełączony kontekst roboczy: maspex troubleshooting.
Skupić się na UAT load-test readiness i stabilizacji ścieżki API `kapsel.makotest.pl`.
Wejście przez aktywne wpisy w `20-projects/clients/mako/maspex/troubleshooting.md`.
Cloud Detective zapisany w `60-toolkit/cloud-detective/`; wraca do tła.
```

## Projekty aktywne

| Projekt | Status | Następny krok |
|---------|--------|---------------|
| maspex | aktywny | review/apply patcha monitoringowego UAT; review patcha `next-core-app` dla `/api/slogan`; potem kontrolowany load test 3000 users / 1h |
| puzzler-b2b | standby | IaC sync+builder gotowe; czeka na: ECR obrazy + Ocelot config w pbms-backend |
| vault governance | standby | Knowledge Boundaries wdrożone; oczekuje ręcznego frontmatter w clients/mako/ + _chatgpt/ + llz/ |
| BMW AI Taskforce | scaffold gotowy | 20-projects/clients/bmw/ai-taskforce/ — czeka na pierwsze materiały od klienta |
| cloud-support-as-a-service | scaffold gotowy | 20-projects/internal/cloud-support-as-a-service/ — czeka na wypełnienie |
| devops-toolkit | w tle | Cloud Detective zapisany jako robocza capability; bez aktywnej pracy |
| devops-platform | w tle | |
| devops-business | w tle | |

## Priorytety tygodnia

1. Maspex: dokończyć observability pod UAT load test bez tworzenia równoległego alertingu.
2. Maspex: przejrzeć i ewentualnie wdrożyć minimalny app patch ograniczający Supabase exact count fallback w `/api/slogan`.
3. Maspex: po apply monitoringu uruchomić kontrolowany test 3000 users / 1h i korelować ECS / ALB / CloudFront / log-derived signals / Redis.
4. Utrzymać pozostałe tematy jako kontekst poboczny, nie aktywny.

## Aktywni klienci

| Klient | Temat | Deadline |
|--------|-------|----------|
| Mako | Maspex troubleshooting | |

## Blokery / otwarte pętle

- [ ] `infra-maspex` ma lokalne zmiany monitoringu UAT: `terraform/modules/monitoring/*`, `terraform/envs/uat/main.tf`
- [ ] `next-core-app` ma lokalny patch `app/api/slogan/route.ts`; lokalnie `npm run typecheck` nie działa, bo brakuje `tsc`
- [ ] `infra-maspex` ma wcześniejszy lokalny commit `4810f3c` niepushowany (`feat/preprod-zaslepka` ahead 1)
- [ ] Redis connection string do Secrets Manager `maspex/preprod/api` nadal otwarte

## Powiązane

- [[now]] — co robię w tej chwili
- [[open-loops]] — rzeczy w toku bez zakończenia
- [[waiting-for]] — czekam na
- [[decision-log]] — decyzje do podjęcia

---

*Tydzień: 2026-W17*
