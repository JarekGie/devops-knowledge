---
title: Redis connection string change — 2026-05-08
date: 2026-05-08
tags: [maspex, redis, elasticache, rollback]
status: PRZYWRÓCONO — aktywny ElastiCache
---

# Redis connection string change — 2026-05-08

## Zmiana

Secret: `maspex/uat/api`
Klucz: `ConnectionStrings__Redis`

| | Wartość |
|--|---------|
| **BEFORE (rollback)** | `redis://maspex-uat.zwowz5.0001.euw1.cache.amazonaws.com:6379` |
| **AFTER (nowy)** | `redis://maspex-uat-redis-9e944396060e4763.elb.eu-west-1.amazonaws.com:6379` |

Nowy endpoint: NLB/ELB przed Redis zamiast direct ElastiCache.

## Rollback

```bash
aws secretsmanager put-secret-value \
  --secret-id maspex/uat/api \
  --secret-string '{"ConnectionStrings__Redis":"redis://maspex-uat.zwowz5.0001.euw1.cache.amazonaws.com:6379"}' \
  --profile maspex-cli --region eu-west-1
```

## Apply

```bash
aws secretsmanager put-secret-value \
  --secret-id maspex/uat/api \
  --secret-string '{"ConnectionStrings__Redis":"redis://maspex-uat-redis-9e944396060e4763.elb.eu-west-1.amazonaws.com:6379"}' \
  --profile maspex-cli --region eu-west-1
```

## Po zmianie

ECS taski muszą być zrestartowane żeby pobrały nową wartość sekretu.
