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

<!-- nowy wpis: -->
<!-- ## YYYY-MM-DD — [symptom] -->
<!-- **Symptom:** -->
<!-- **Diagnoza:** -->
<!-- **Fix:** -->
<!-- **Status:** [ ] open / [x] resolved -->
