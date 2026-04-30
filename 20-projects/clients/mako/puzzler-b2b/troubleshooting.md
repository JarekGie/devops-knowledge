# puzzler-b2b — Troubleshooting

Aktywne problemy na górze. Rozwiązane zostają jako archiwum poniżej.

## Repozytorium
- lokalna ścieżka: `~/projekty/mako/aws-projects/infra-puzzler-b2b-final`
- profil AWS: `puzzler-pbms`

---

## 2026-04-22 — Swagger Core zwraca 500 na `/swagger/docs/v1/Core`

**Symptom:** Swagger UI ładuje się, ale definicja Core kończy się HTTP 500 na `/swagger/docs/v1/Core`.

**Diagnoza:**
- To nie jest lokalny dokument gatewaya.
- Gateway używa `SwaggerForOcelot` i pobiera downstream:
  `http://pbms-core-qa:8080/swagger/v1/swagger.json`
- Źródło 500 jest więc najbardziej prawdopodobnie w runtime Swagger generation w `PBMS.Core.API`.

Najmocniejszy trop z kodu:
- `MediaModel` i `SupplyResponse` mają `DeliveryDefinition` typu `IMediaDeliveryModel`
- `IMediaDeliveryModel` jest interfejsem z `SwaggerSubType(typeof(MediaSftpDeliveryModel))`
- w `PBMS.Common/Middleware/Swagger/ConfigureSwaggerOptions.cs`
  obsługa polimorfizmu Swaggera (`UseOneOfForPolymorphism` itd.) jest zakomentowana

**Konkluzja:** najbardziej prawdopodobny crash point to generacja schematu dla interfejsu
`IMediaDeliveryModel` w downstream Core swagger JSON.

**Minimalny fix:**
- `~/projekty/mako/pbms-backend/Core/PBMS.Core/Models/Media/MediaModel.cs`
- `~/projekty/mako/pbms-backend/Core/PBMS.Core/Models/Supply/SupplyResponse.cs`
- zmienić `DeliveryDefinition` z `IMediaDeliveryModel` na `object`

**Walidacja po fixie:**
- `http://pbms-core-qa:8080/swagger/v1/swagger.json`
- `/swagger/docs/v1/Core`

**Status:** [ ] open

## 2026-04-18 — kontener infra-puzzler-b2b-dev-core nie wstaje (crash loop)

**Symptom:** ECS service `infra-puzzler-b2b-dev-core` w crash loop — running: 0, desired: 1, nowe zadanie co ~30s. Exit code 134 (SIGABRT).

**Diagnoza:**
- Klaster ECS: `infra-puzzler-b2b-dev-puzzler` (region: **eu-west-2**)
- Baza: DocumentDB `infra-puzzler-b2b-dev-puzzler-mongo` v5.0
- Hangfire.Mongo przy starcie wykonuje migrację do Version09 (`CreateSignalCollection`)
- Migracja próbuje utworzyć **capped collection** — DocumentDB tego nie obsługuje
- Błąd: `Command create failed: Feature not supported: capped:true`
- Stack trace: `Hangfire.Mongo.Migration.Steps.Version09.CreateSignalCollection`

**Opcje naprawy (dla dev team):**
1. **Upgrade Hangfire.Mongo** — nowsze wersje (≥ 1.0) nie używają capped collections
2. **MongoStorageOptions** — sprawdzić czy jest opcja `UseLegacyIgnoreDataMigration` lub skip migracji
3. **Zmiana bazy** — użycie Atlas MongoDB zamiast DocumentDB (kosztowniejsze)
4. **Workaround** — ręczne stworzenie kolekcji bez capped w DocumentDB przed startem

**Rekomendacja:** opcja 1 (upgrade Hangfire.Mongo) — najczystsza, bez infrastruktury.

**Status:** [ ] open

**Do wyjaśnienia w poniedziałek z developerem:**
- Czy masz nowy build z upgradowanym Hangfire.Mongo?
- Jeśli tak: usuniemy kolekcje `hangfire.*` z bazy `core` i puszczasz nowy obraz
- Jeśli nie: najpierw upgrade, potem czysta baza — kolejność ma znaczenie

**Kolekcje do usunięcia (gdy będzie nowy build):**
`hangfire.jobs.jobGraph`, `hangfire.jobs.locks`, `hangfire.jobs.migrationLock`,
`hangfire.jobs.notifications`, `hangfire.jobs.schema`, `hangfire.jobs.server`

---

## 2026-04-24 — Dodanie serwisów Sync i Builder (IaC)

**Zakres:** Nowe wewnętrzne serwisy backendowe za gateway.

**Zmiany w `envs/dev/`:**
- `services.tf` — `module "sync_service"` i `module "builder_service"` (linie 343, 384); wzorzec identyczny z core/delivery/notifier: `enable_alb = false`, VPC CIDR ingress, Cloud Map, docdb_secrets + azuread_secrets
- `service_discovery.tf` — `aws_service_discovery_service.pbms_sync` i `pbms_builder`; DNS: `pbms-sync-dev.pbms.local`, `pbms-builder-dev.pbms.local`
- `variables.tf` — `sync_image`, `builder_image` (default `nginx:latest`)
- `terraform.tfvars` — placeholder `sync_image = "nginx:latest"`, `builder_image = "nginx:latest"`

**Ocelot / Swagger:** konfiguracja nie jest w tym repo (baked w Docker image). Trasy muszą być dodane przez dev team w `pbms-backend` → gateway `ocelot.json` / `swaggerEndpoints.*.json`.

**Ocelot routes do dodania ręcznie:**
```json
{ "UpstreamPathTemplate": "/sync/{everything}", "DownstreamPathTemplate": "/{everything}", "DownstreamHostAndPorts": [{"Host": "pbms-sync-dev.pbms.local","Port": 8080}], "SwaggerKey": "Sync" }
{ "UpstreamPathTemplate": "/builder/{everything}", "DownstreamPathTemplate": "/api/{everything}", "DownstreamHostAndPorts": [{"Host": "pbms-builder-dev.pbms.local","Port": 8080}], "SwaggerKey": "Builder" }
```

**Walidacja:** `terraform validate` → Success (11 deprecation warnings pre-existing w upstream module)

**Status:** [x] resolved — IaC gotowe; BLOCKER: zastąp `nginx:latest` docelowym URI ECR po zbudowaniu obrazów

## 2026-04-30 — SSH tunnel dev: "administratively prohibited" / AllowTcpForwarding

**Symptom:** Dev (michal.grzywacz) nie może otworzyć tunelu SSH do DocumentDB przez jumphost.
Sekwencja błędów:
1. `Load key "kluczMongo2": invalid format` — klucz miał Windows CRLF line endings
2. `Permission denied (publickey)` — po naprawie klucza: brak klucza deva w authorized_keys
3. `channel 2: open failed: administratively prohibited` — klucz OK, ale TCP forwarding wyłączone

**Root cause:**
- Alpine's domyślny `/etc/ssh/sshd_config` ma `AllowTcpForwarding no`
- Dockerfile dołączał `echo "AllowTcpForwarding yes"` na końcu pliku — ignorowane, bo sshd bierze **pierwsze** wystąpienie dyrektywy
- Klucz publiczny deva nie był w Secrets Manager (`jumphost_authorized_keys`)

**Fix — trzy zmiany w `infra-puzzler-b2b-final`:**
1. **Dockerfile** — zamiana `echo "AllowTcpForwarding yes" >>` na `sed -i 's/AllowTcpForwarding no/AllowTcpForwarding yes/'`
2. **`authorized_keys`** — dodany klucz deva: `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIObTg8+N9LKADSloxkkhitNbWaTGm4aCQGlUrks482EA makolab-net\michal.grzywacz@s004411`
3. **`envs/dev/terraform.tfvars`** — `jumphost_authorized_keys` zaktualizowane (heredoc z oboma kluczami), tag obrazu `jumphost-v7`

**Deployment:**
- ECR: `698220459519.dkr.ecr.eu-west-2.amazonaws.com/infra-puzzler-b2b-app-dev:jumphost-v7`
- `terraform apply` — 1 added, 1 changed, 1 destroyed
- Jumphost IP: `18.175.150.59` (niezmienione)

**Uwaga — naprawa klucza deva (CRLF):**
Windows SSH key z CRLF: `(Get-Content key -Raw) -replace "\`r\`n","\`n"` i zapisać przez `[System.IO.File]::WriteAllText()` (nie `Set-Content` — domyślnie UTF-16LE na PS5).

**Status:** [x] resolved — jumphost-v10 wdrożony 2026-04-30

**Historia tagów i iteracji:**
- v5–v6: format klucza CRLF / UTF-16 (fix po stronie deva)
- v7: `sed` zamiast `echo` dla AllowTcpForwarding — działało
- v8–v9: dev przerobił obraz, wrócił do `echo` — AllowTcpForwarding znowu broken
- v10: przywrócono `sed -i 's/AllowTcpForwarding no/.../g'`, usunięto zbędny `echo`

**Właściwy klucz SSH do jumphostu: `~/.ssh/jumphost_dev` (ed25519)**
`id_rsa` (RSA) nie działa — authorized_keys ma tylko ed25519.
Dev musi używać klucza który wygenerował przez `ssh-keygen -t ed25519`.

**IP jumphostu po ostatnim deploy: `18.135.17.131`**

<!-- nowy wpis: -->
<!-- ## YYYY-MM-DD — [symptom] -->
<!-- **Symptom:** -->
<!-- **Diagnoza:** -->
<!-- **Fix:** -->
<!-- **Status:** [ ] open / [x] resolved -->
