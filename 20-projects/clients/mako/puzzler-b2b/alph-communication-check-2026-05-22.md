---
title: Alph API Communication Check — DEV
project: puzzler-b2b
env: dev
date: 2026-05-22
tags: [#puzzler-b2b, #ecs, #alph, #sync, #integration]
---

# Alph API Communication Check — DEV (2026-05-22)

## Symptom

Serwis `infra-puzzler-b2b-dev-sync` (ECS DEV) nie może nawiązać połączenia z Alph API.
Błąd: `Name or service not known (alph-api-qa.makolab.net:443)`

## Stan ECS (live)

```
Service: infra-puzzler-b2b-dev-sync
Status:  ACTIVE | desired=1, running=1, pending=0
TaskDef: infra-puzzler-b2b-dev-sync:59
```

Serwis jest UP ale integracja z Alph nie działa.

## Błędy z CloudWatch (/ecs/infra-puzzler-b2b-dev-sync)

```
[05:44:50 ERR] Failed to authenticate with Alph API: Name or service not known (alph-api-qa.makolab.net:443)
[05:44:50 ERR] Failed to obtain bearer token for Alph API request
[05:44:50 WRN] Alph API returned error: Unauthorized - Failed to authenticate with Alph API
[05:44:50 ERR] Error fetching generator settings from Alph
[09:32:55 ERR] Failed to authenticate with Alph API: Name or service not known (alph-api-qa.makolab.net:443)
```

Restarty serwisu w ciągu 24h (UTC): 09:02, 11:04, 11:09 (+5 min — podejrzane), 12:30

## Root cause

### 1. Zły URL w obrazie

URL używany przez kontener: `alph-api-qa.makolab.net:443`
URL w bieżącym source code (`appsettings.json`): `https://alph-api-uat.makodev.pl`

Obraz DEV był zbudowany ze starszego kodu gdzie `appsettings.json` miał `alph-api-qa.makolab.net`.
Przy rebuildzie obraz użyje `alph-api-uat.makodev.pl`.

### 2. Prywatny hostname nie jest dostępny z VPC

`alph-api-qa.makolab.net` to prywatna domena wewnętrzna MakoLab (`.makolab.net`).
Nie ma DNS resolution z poziomu VPC AWS (`eu-west-2`). Wymaga VPN/biurowej sieci.
Domena `.makodev.pl` (np. `alph-api-uat.makodev.pl`) jest publiczna i resolwuje z VPC.

### 3. Konfiguracja Alph nie jest injectowalna

Brak w ECS task definition `infra-puzzler-b2b-dev-sync:59`:
- brak env var `AlphApiSettings__BaseUrl`
- brak Secrets Manager injection dla Alph credentials

`AlphApiSettings` jest wyłącznie baked w Docker image przez `appsettings.json`.

## Fix

### Szybki fix (infra, bez nowego buildu)

Dodać do `envs/dev/services.tf` w module sync_service:
```hcl
environment_variables = {
  # ... existing vars ...
  "AlphApiSettings__BaseUrl" = "https://alph-api-uat.makodev.pl"
}
```

ASP.NET Core automatycznie override'uje sekcję konfiguracji przez env vars z `__` jako separator.
Po `terraform apply` + force-new-deployment: ECS użyje publicznego URL.

**UWAGA:** Login i Password zostają w appsettings.json (lub dodać je też jako SM secret).

### Właściwy fix (backend, przy okazji rebuildów)

Dodać do `appsettings.DEV.json` w `PBMS.Sync.API`:
```json
{
  "AlphApiSettings": {
    "BaseUrl": "https://alph-api-dev.makodev.pl"
  }
}
```
(zakładając że istnieje dedykowany DEV endpoint, jeśli nie — użyć UAT)

## Dodatkowe obserwacje

- `AlphApiSettings.Login = "Syndication_Integration"`, `Password` w plain text w `appsettings.json` — powinny trafić do Secrets Manager (dług techniczny)
- Serwis nie crashuje z powodu błędu Alph (graceful handling) — integration po prostu nie działa
- Restarty wyglądają na schedulerowe (start 07:00 Warsaw) + 1–2 niezależne restarty

## Akcja

- [ ] Decyzja: quick fix (env var w services.tf) czy czekać na rebuild z poprawnym `appsettings.DEV.json`
- [ ] Przy okazji: wyciągnąć Alph Login/Password do Secrets Manager
