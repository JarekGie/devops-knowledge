# Maspex UAT API / Supabase Investigation Context - 2026-04-23

## Scope

Read-only investigation of Maspex / kapsel UAT runtime degradation around:

- `GET /api/slogan?page=1&sortBy=votes_desc`
- Supabase / PostgREST / DB path
- `maspex-api` ECS CPU spikes
- ALB request timeouts / unhealthy target symptoms
- Redis only as a dependency in the request path, not as the primary investigation target

Out of scope:

- admin-panel UI/CSS/frontend rendering
- bot crash loop
- infra changes, restarts, deploys, invalidations, Terraform edits

## Key Repositories / Paths

- App repo: `/Users/jaroslaw.golab/projekty/mako/next-core-app`
- Infra repo: `/Users/jaroslaw.golab/projekty/mako/aws-projects/infra-maspex`
- Knowledge vault: `/Users/jaroslaw.golab/projekty/devops/devops-knowledge`
- DevOps Toolkit repo for next context: `/Users/jaroslaw.golab/projekty/devops/devops-toolkit`

## AWS Context

- AWS profile: `maspex-cli`
- Region: `eu-west-1`
- ECS cluster: `maspex-uat`
- Main service: `maspex-api`
- API log group: `/maspex/uat/contest-service`
- API target group: `targetgroup/maspex-uat-api-3000/97cac4c72be43344`
- ALB: `app/maspex-uat/68317764a66425bd`
- CloudFront alias for public API: `kapsel.makotest.pl`
- CloudFront distribution: `E3J76RNXIE2YIG`
- CloudFront origin: `maspex-uat-1361582173.eu-west-1.elb.amazonaws.com`

## Current Runtime Facts

- Live ECS task definition for API: `maspex-api:36`
- Live image: `969209893152.dkr.ecr.eu-west-1.amazonaws.com/maspex-api:coreapp-uat-375`
- ECR image digest: `sha256:2c82ad37b3bc7dad4b0933571c909ec210073d9a2f195a7955d9638f17ccd20f`
- Image pushed at: `2026-04-23T12:16:33.934+02:00`
- Task CPU/memory: `1024` / `2048`
- Container port: `3000`
- ECS task env names: `HOSTNAME`, `PORT`
- ECS task secret name: `ConnectionStrings__Redis`
- ECS task definition does not inject `REDIS_URL`
- Code expects `REDIS_URL`
- Redis is nevertheless used at runtime, so `REDIS_URL` is likely coming from image-baked `.env.local` or another runtime source outside ECS env/secrets.

## Important Code Paths

### `/api/slogan`

File: `/Users/jaroslaw.golab/projekty/mako/next-core-app/app/api/slogan/route.ts`

For `GET /api/slogan?page=1&sortBy=votes_desc`:

- Creates Supabase service client via `createServiceClient()`.
- Uses `limit = 100`; fetch path requests `limit + 1`, so `101` items.
- `fetchSlogans()`:
  - If no search and `offset + limit <= CACHE_LIMITS[sortBy]`, attempts Redis cache.
  - For `votes_desc`, Redis reads:
    - `zrevrange("slogans:by_votes", start, end)`
    - `mget(...101 slogan:data keys)`
  - On Redis error, falls through to Supabase RPC.
  - DB fallback calls `supabase.rpc("get_public_slogans", { p_search, p_sort, p_limit, p_offset })`.
- `resolveCount()`:
  - Tries Redis key `slogans:total_count`.
  - On miss, calls Supabase count against `slogans`.
  - Sets Redis count TTL `60s`.
- If request has bearer token, `resolveVotedIds()` calls Supabase auth and `votes` table.
- Uses `Promise.all([slogansPromise, countPromise, votedIdsPromise])`, so downstream calls run concurrently.

### Redis client

File: `/Users/jaroslaw.golab/projekty/mako/next-core-app/lib/redis/client.ts`

- Requires `process.env.REDIS_URL`; throws if missing.
- `ioredis` options:
  - `maxRetriesPerRequest: 3`
  - `connectTimeout: 5000`
  - `commandTimeout: 5000`
- Singleton via global proxy.

### Redis cache service

File: `/Users/jaroslaw.golab/projekty/mako/next-core-app/lib/redis/services/cache.service.ts`

- `indexSloganBatch()` deletes three sorted sets, then for every slogan:
  - `set slogan:data:<id> ... EX 300`
  - `zadd slogans:by_votes`
  - `zadd slogans:by_date`
  - `zadd slogans:by_alphabet`
- Executes the entire batch as one Redis pipeline.
- `getPaginatedSlogans()` performs sorted set read plus `mget` for all page keys.

### Supabase client

File: `/Users/jaroslaw.golab/projekty/mako/next-core-app/lib/supabase/client.ts`

- Service client uses:
  - `NEXT_PUBLIC_SUPABASE_URL`
  - `SUPABASE_SERVICE_ROLE_KEY`
- Singleton via `globalThis`.
- No explicit app-level Supabase HTTP timeout or DB pool settings found in inspected code.

### Cron routes

Files:

- `/Users/jaroslaw.golab/projekty/mako/next-core-app/app/api/cron/sync-redis/route.ts`
- `/Users/jaroslaw.golab/projekty/mako/next-core-app/app/api/cron/process-queue/route.ts`

`sync-redis` route:

- Protected by `CRON_SECRET`.
- Calls `supabase.rpc("get_slogans_for_cache")`.
- Calls `cacheService.indexSloganBatch(slogans)`.
- Current local code logs `[CRON DATABASE ERROR]` and `[CRON REDIS SYNC ERROR]`.

`process-queue` route:

- `BATCH_LIMIT = 150`
- `CONCURRENCY_LIMIT = 10`
- Reads pending `slogans_preview`.
- For each item can call OpenAI moderation, Supabase write paths, email lookups/notifications.
- Uses `Promise.all(tasks)` with `p-limit(10)`.

## Important Drift / Evidence Caveat

Live CloudWatch logs contain messages such as:

- `>>> [CACHE-CRON] Start requestu`
- `>>> [CACHE-CRON] Pobieranie haseł z Supabase (RPC: get_slogans_for_cache)...`
- `>>> [CACHE-CRON] Znaleziono haseł do zindeksowania: ...`
- `>>> [CACHE-CRON] Rozpoczynam indexSloganBatch w Redis...`
- `>>> [CACHE-CRON] Synchronizacja z Redis zakończona sukcesem`

These exact strings were not found in the current local `next-core-app` checkout using `rg` or `git grep` over local refs.

Interpretation:

- There is likely drift between local checkout `dev` and live image `coreapp-uat-375`, or the image was built from a commit/branch not present locally.
- Live behavior from CloudWatch remains valid operational evidence, but exact source lines for these log strings cannot be cited from the current local checkout.

## Redis Findings From Previous Read-Only Checks

Redis cluster:

- ElastiCache cluster: `maspex-uat`
- Engine: Redis `7.1.0`
- Node type: `cache.t3.micro`
- Endpoint: `maspex-uat.zwowz5.0001.euw1.cache.amazonaws.com:6379`
- Parameter group: `default.redis7`
- `maxclients = 65000`
- `maxmemory-policy = volatile-lru`
- `timeout = 0`

Metrics checked:

- `CurrConnections`: about `8-11`
- `NewConnections`: mostly `0`, max `2`
- `EngineCPUUtilization`: max around `13.55%`
- `CPUUtilization`: low to moderate, max around `11.85%`
- `DatabaseMemoryUsagePercentage`: max around `4.94%`
- `FreeableMemory`: around `408-419 MB`
- `SwapUsage`: steady around `31,272,960 bytes`
- `Evictions`: `0`
- `Reclaimed`: present due to TTL expiration

Conclusion:

- Redis connection saturation is not supported.
- Redis memory pressure is not supported.
- Redis did show slowlog entries and later app-side `Redis circuit open`, but this does not look like maxclients or memory exhaustion.

## Live AWS / Logs Findings Around Main Degradation Window

Focused incident window:

- UTC: `2026-04-23 12:10:00` to `12:30:00`
- Europe/Warsaw: `2026-04-23 14:10:00` to `14:30:00`

### Cache cron logs

CloudWatch query over `/maspex/uat/contest-service` found:

- `CACHE-CRON` every minute from `12:10` to `12:30 UTC`.
- Aggregation showed usually `5` CACHE-CRON events per minute.
- `count_distinct(@logStream)` was `1` per minute in the queried window, meaning one task handled each cron invocation, but across the window different task streams appeared.
- Normal sync pattern:
  - start
  - fetch from Supabase RPC `get_slogans_for_cache`
  - found slogans count
  - index Redis
  - success

Observed counts:

- Around `12:10-12:26 UTC`: typically `4993` slogans indexed.
- Around `12:27-12:28 UTC`: `4592` slogans indexed.
- Around `12:29-12:30 UTC`: `4813` slogans indexed.

Important latency evidence:

- At `12:27:00.224 UTC`, CACHE-CRON started fetching from Supabase.
- At `12:27:16.918 UTC`, it began Redis indexing and logged `4592` slogans.
- At `12:27:21.868 UTC`, sync completed.
- This implies the Supabase RPC portion took about `16.7s`, and the whole sync about `21.6s`.

### Application error logs in same window

Aggregated log findings:

- `12:21 UTC`: `1` event `[VOTE_CACHE_WRITETHROUGH_FAIL] Error: Command timed out`
- `12:23 UTC`: `4` events `[submitSlogan Error] Error: aborted`
- `12:24 UTC`: `1` event `[submitSlogan Error] Error: aborted`
- `12:25 UTC`: `3` events `[submitSlogan Error] Error: aborted`
- `12:26 UTC`: `1` event `[submitSlogan Error] Error: aborted`
- `12:26 UTC`: `46` events `[VOTE_CACHE_WRITETHROUGH_FAIL] Error: Redis circuit open`
- `12:27 UTC`: `1` event `[submitSlogan Error] Error: aborted`

No direct `[GET_SLOGANS_ERROR]` was found in that exact query window.

### ECS CPU / memory metrics, 1-minute period

`maspex-api` CPU:

- `14:10 CEST`: avg `0.77%`, max `2.12%`
- `14:13`: avg `15.50%`, max `39.71%`
- `14:16`: avg `28.55%`, max `51.39%`
- `14:19`: avg `76.28%`, max `86.85%`
- `14:20`: avg `90.65%`, max `100%`
- `14:21`: avg `97.11%`, max `100%`
- `14:22`: avg `84.59%`, max `100%`
- `14:23`: avg `32.94%`, max `99.90%`
- `14:24`: avg `54.29%`, max `100%`
- `14:25`: avg `41.21%`, max `99.99%`
- `14:26`: avg `32.92%`, max `100%`
- `14:27`: avg `21.34%`, max `100%`
- `14:28`: avg `1.74%`, max `12.80%`

`maspex-api` memory:

- Rose from about avg `26%` at `14:10` to avg `61.68%` at `14:22`.
- Max reached about `90.48%` at `14:27`.

### ALB metrics, 1-minute period

Target response time:

- `14:20 CEST`: avg `0.602s`, max `12.410s`
- `14:21`: avg `1.318s`, max `23.115s`
- `14:22`: avg `0.961s`, max `29.979s`
- `14:23`: avg `1.518s`, max `29.834s`
- `14:24`: avg `1.695s`, max `29.904s`
- `14:25`: avg `1.215s`, max `29.348s`
- `14:26`: avg `1.552s`, max `29.854s`
- `14:27`: avg `1.774s`, max `29.923s`

Target connection errors:

- `14:21 CEST`: `496`
- `14:22`: `4774`
- `14:23`: `14724`
- `14:24`: `8880`
- `14:25`: `19933`
- `14:26`: `23562`
- `14:27`: `5067`

Unhealthy hosts:

- `14:21`: avg `0.5`, max `1`
- `14:22`: avg `1.5`, max `2`
- `14:23`: avg `2.0`, max `2`
- `14:24`: avg `1.0`, max `1`
- `14:25`: avg `2.0`, max `2`
- `14:27`: avg `1.0`, max `1`

Target 5xx:

- `14:24 CEST`: `1`

### Current task health after incident

Read-only target health later showed:

- Three healthy targets.
- One old target draining.

Read-only ECS task list showed three running tasks:

- `1fcf260d433240b9b37f75105ab335b0`
- `c13b90bcaab9493bb00cdfd2e20331cc`
- `e27559455f014ca49894077162015c1b`

## Request Path

`GET https://kapsel.makotest.pl/api/slogan?page=1&sortBy=votes_desc`

Path:

1. CloudFront `E3J76RNXIE2YIG`
2. ALB origin `maspex-uat-1361582173.eu-west-1.elb.amazonaws.com`
3. ALB host routing for `kapsel.makotest.pl`
4. API target group `maspex-uat-api-3000`
5. ECS service `maspex-api`
6. Next route `app/api/slogan/route.ts`
7. Redis cache lookup
8. Supabase / PostgREST / DB fallback or count/auth path

## Evidence-Based Diagnosis Draft

Confirmed:

- The degraded window had API CPU saturation and ALB target latency/connection errors.
- Cache sync cron ran every minute during the degraded window.
- Cache sync calls Supabase RPC `get_slogans_for_cache` and indexes thousands of slogans into Redis.
- A cache sync at `12:27 UTC` had a long Supabase RPC phase of about `16.7s`.
- App logs in the same window show `submitSlogan Error: aborted`.
- Redis write-through failures occurred, including `Command timed out` and many `Redis circuit open`.
- Redis infrastructure metrics do not support maxclients or memory saturation.
- No AWS RDS exists in `eu-west-1`; app uses Supabase externally.

Strong inference:

- Primary bottleneck is likely a combination of downstream Supabase/PostgREST/DB latency and API CPU saturation.
- The cache sync route likely amplifies load because it performs a heavy Supabase RPC and then writes thousands of items to Redis every minute.
- During incident, this background cache sync overlapped with API CPU saturation and ALB timeouts.
- Redis symptoms are probably secondary or collateral, not primary connection saturation.

Not yet confirmed:

- Direct Supabase DB CPU/memory/swap/connection pool metrics.
- Direct PostgREST pool usage during the incident.
- Exact request volume for `/api/slogan` during the spike; application logs do not currently show per-request access logs.
- Exact live source commit for `coreapp-uat-375`.
- Whether cron is invoked externally once per minute or by internal/runtime scheduler. Logs show a request per minute, but current local code has no scheduler.

## Root Cause Ranking Draft

1. Most likely: Supabase/PostgREST/DB path latency or pool pressure, amplified by API background cache sync and request concurrency.
2. Also likely: API CPU saturation as a co-cause or cascade effect, especially from concurrent request load plus cache sync/indexing.
3. Possible: Redis command latency/circuit breaker as a secondary symptom that worsened fallback behavior.
4. Not supported: Redis connection saturation.
5. Not supported from AWS evidence: AWS RDS swap/memory pressure.

## Restart Assessment Draft

Restarting everything would likely be symptomatic only:

- It may clear in-process state/circuit breaker conditions and replace hot tasks.
- It does not address recurring every-minute cache sync, Supabase RPC latency, PostgREST/DB pool pressure, or traffic/request amplification.
- Because the incident correlates with periodic background work and downstream latency, restart alone is not proven to remove the cause.

## Exact Read-Only Commands Already Run Or Used

Representative commands:

- `rg -n "cron|sync-redis|CACHE-CRON|setInterval|setTimeout|Promise\\.all|indexSloganBatch|get_public_slogans|fromDB|cacheService|Redis unavailable|aborted|statement timeout|connection pool" app lib`
- `nl -ba app/api/slogan/route.ts | sed -n '1,240p'`
- `nl -ba app/api/cron/sync-redis/route.ts | sed -n '1,220p'`
- `nl -ba app/api/cron/process-queue/route.ts | sed -n '1,220p'`
- `nl -ba lib/redis/client.ts | sed -n '1,220p'`
- `nl -ba lib/redis/services/cache.service.ts | sed -n '1,260p'`
- `nl -ba lib/supabase/client.ts | sed -n '1,180p'`
- `AWS_PROFILE=maspex-cli AWS_REGION=eu-west-1 aws ecs describe-task-definition --task-definition maspex-api:36 ...`
- `AWS_PROFILE=maspex-cli AWS_REGION=eu-west-1 aws ecr describe-images --repository-name maspex-api --image-ids imageTag=coreapp-uat-375 ...`
- `AWS_PROFILE=maspex-cli AWS_REGION=eu-west-1 aws logs start-query --log-group-name /maspex/uat/contest-service ...`
- `AWS_PROFILE=maspex-cli AWS_REGION=eu-west-1 aws logs get-query-results --query-id ...`
- `AWS_PROFILE=maspex-cli AWS_REGION=eu-west-1 aws cloudwatch get-metric-statistics --namespace AWS/ECS --metric-name CPUUtilization ...`
- `AWS_PROFILE=maspex-cli AWS_REGION=eu-west-1 aws cloudwatch get-metric-statistics --namespace AWS/ECS --metric-name MemoryUtilization ...`
- `AWS_PROFILE=maspex-cli AWS_REGION=eu-west-1 aws cloudwatch get-metric-statistics --namespace AWS/ApplicationELB --metric-name TargetResponseTime ...`
- `AWS_PROFILE=maspex-cli AWS_REGION=eu-west-1 aws cloudwatch get-metric-statistics --namespace AWS/ApplicationELB --metric-name TargetConnectionErrorCount ...`
- `AWS_PROFILE=maspex-cli AWS_REGION=eu-west-1 aws cloudwatch get-metric-statistics --namespace AWS/ApplicationELB --metric-name UnHealthyHostCount ...`
- `AWS_PROFILE=maspex-cli AWS_REGION=eu-west-1 aws cloudwatch get-metric-statistics --namespace AWS/ApplicationELB --metric-name HTTPCode_Target_5XX_Count ...`
- `AWS_PROFILE=maspex-cli AWS_REGION=eu-west-1 aws rds describe-db-instances ...`
- `AWS_PROFILE=maspex-cli aws cloudfront list-distributions ...`

## Next Context

The user asked to switch context to `devops-toolkit`.

Use:

- `/Users/jaroslaw.golab/projekty/devops/devops-toolkit`

No repo or AWS changes were applied during this investigation.
