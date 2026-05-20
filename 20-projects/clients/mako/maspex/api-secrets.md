# Maspex — wymagane sekrety aplikacji API

## Symptom braku klucza

| Brakujący klucz | Objaw |
|-----------------|-------|
| `ConnectionStrings__Redis` | App nie startuje — ECS task nie przechodzi health checku, brak połączenia z Redis/ElastiCache |
| `SUPABASE_JWT_SECRET` | App startuje, ale **wszystkie uwierzytelnione endpointy zwracają 401** „Nieprawidłowy token" |
| `JWT_SECRET` (UAT) | Load test fleet bootstrap kończy się błędem, tokeny nie są generowane |
| `JWT_KID` (UAT) | j.w. |

## Sekrety obowiązkowe

### `maspex/uat/api` (ARN: `…:secret:maspex/uat/api-STbBy3`)

| Klucz | Env var w kontenerze | Opis | Gdzie znaleźć |
|-------|---------------------|------|---------------|
| `ConnectionStrings__Redis` | `REDIS_URL` | Redis connection string, format `redis://<host>:6379` | Terraform output `elasticache_connection_string` w env UAT |
| `SUPABASE_JWT_SECRET` | `SUPABASE_JWT_SECRET` | JWT secret projektu Supabase — walidacja tokenów przez `@supabase/ssr`. **Musi być identyczny z wartością z Supabase Dashboard → Project Settings → API → JWT Secret** | Supabase Dashboard |
| `JWT_SECRET` | _(nie jest injektowany do kontenera API)_ | Używany przez load test fleet (token-generator). **Musi być równy `SUPABASE_JWT_SECRET`** | Supabase Dashboard (ta sama wartość) |
| `JWT_KID` | _(nie jest injektowany do kontenera API)_ | Key ID wpisywany w nagłówku `kid` generowanych tokenów JWT. Wartość jest arbitralna ale musi być stała | Dowolna unikalna wartość, np. `lPz/N3emEyGAM/QQ` |

### `maspex/prod/api` (ARN: `…:secret:maspex/prod/api-z6g7eq`)

| Klucz | Env var w kontenerze | Opis |
|-------|---------------------|------|
| `ConnectionStrings__Redis` | `REDIS_URL` | Redis connection string PROD |
| `SUPABASE_JWT_SECRET` | `SUPABASE_JWT_SECRET` | JWT secret projektu Supabase (produkcyjnego) |

PROD nie ma `JWT_SECRET` / `JWT_KID` — load testy uruchamiane są przez UAT.

## Jak sprawdzić aktualny stan

```bash
# UAT
aws secretsmanager get-secret-value \
  --secret-id "maspex/uat/api" \
  --profile maspex-cli --region eu-west-1 \
  --query 'SecretString' --output text | python3 -c "
import json, sys
s = json.load(sys.stdin)
for k, v in s.items():
    ok = '✓' if v else '✗ PUSTE'
    print(f'{ok}  {k}: {len(v)} znaków')
"

# PROD
aws secretsmanager get-secret-value \
  --secret-id "maspex/prod/api" \
  --profile maspex-cli --region eu-west-1 \
  --query 'SecretString' --output text | python3 -c "
import json, sys
s = json.load(sys.stdin)
for k, v in s.items():
    ok = '✓' if v else '✗ PUSTE'
    print(f'{ok}  {k}: {len(v)} znaków')
"
```

## Jak naprawić pusty klucz

```bash
# Ustaw SUPABASE_JWT_SECRET = JWT_SECRET (UAT, jeśli pusty)
CURRENT=$(aws secretsmanager get-secret-value \
  --secret-id "maspex/uat/api" --profile maspex-cli --region eu-west-1 \
  --query 'SecretString' --output text)

UPDATED=$(echo "$CURRENT" | python3 -c "
import json, sys
s = json.load(sys.stdin)
s['SUPABASE_JWT_SECRET'] = s['JWT_SECRET']
print(json.dumps(s))
")

aws secretsmanager put-secret-value \
  --secret-id "maspex/uat/api" \
  --secret-string "$UPDATED" \
  --profile maspex-cli --region eu-west-1

# Wymagany force-new-deployment żeby taski pobrały nowy sekret
aws ecs update-service \
  --cluster maspex-uat --service maspex-api \
  --force-new-deployment \
  --profile maspex-cli --region eu-west-1 --no-cli-pager
```

Po force-new-deployment odczekaj ~2 min i sprawdź czy taski są healthy.

## Relacja między kluczami

```
Supabase Dashboard → JWT Secret
        │
        ├──► AWS Secret: SUPABASE_JWT_SECRET  (walidacja tokenów w @supabase/ssr)
        │
        └──► AWS Secret: JWT_SECRET           (generowanie tokenów w load test fleet)
```

Oba muszą być identyczne. Jeśli Supabase zmieni JWT Secret (rotacja), oba klucze w AWS muszą być zaktualizowane.

## Historia incydentów

**2026-05-15** — UAT API zwracało 401 na wszystkich endpointach po force-new-deployment.
Root cause: sekret `maspex/uat/api` był nadpisany przez kogoś (04:26 UTC) — `ConnectionStrings__Redis` i `SUPABASE_JWT_SECRET` zostały usunięte, pozostały tylko `JWT_SECRET` + `JWT_KID`. ECS taski nie mogły połączyć się z Redis i nie mogły walidować tokenów. Fix: przywrócenie wszystkich 4 kluczy + force-new-deployment.
