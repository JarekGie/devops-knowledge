# puzzler-b2b — Troubleshooting

Aktywne problemy na górze. Rozwiązane zostają jako archiwum poniżej.

## Repozytorium
- lokalna ścieżka: `~/projekty/mako/aws-projects/infra-puzzler-b2b-final`
- profil AWS: `puzzler-pbms`

---

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

<!-- nowy wpis: -->
<!-- ## YYYY-MM-DD — [symptom] -->
<!-- **Symptom:** -->
<!-- **Diagnoza:** -->
<!-- **Fix:** -->
<!-- **Status:** [ ] open / [x] resolved -->
