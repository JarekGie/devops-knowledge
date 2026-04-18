---
project: rshop
client: mako
tags: [finops, cloudformation, tagging, rshop]
created: 2026-04-18
---

# FinOps rshop — sesja 2026-04-18

## Repozytorium kodu

- lokalna ścieżka: `~/projekty/mako/aws-projects/infra-rshop`
- toolkit slug: `mako/rshop` (nie `rshop` — projekt jest pod klientem `mako`)
- AWS profile: `rshop`, region: `eu-central-1`

## Co zostało zrobione

### 1. Raport FinOps MTD

```
toolkit finops-report mako/infra-rshop --period mtd --group-by service --project-root ~/projekty/mako/aws-projects/infra-rshop
```

Wyniki (2026-04-01 → 2026-04-18):

- Koszt całkowity: **$584.83** (poprzedni okres: $449.52, wzrost +30.1%)
- Top serwisy: VPC $125.34, ECS $125.09, RDS $123.98, CloudWatch $55.77
- Pokrycie tagów: **44.2%** — 55.8% kosztów bez tagu `Environment`
- Prognoza 30-dniowa: $694.91

### 2. Audit finops-tagging-runtime

11/27 stacków CloudFormation bez wymaganych tagów:

**dev — 10 stacków bez tagów:**
- `dev-alb-ownership` (IMPORT_COMPLETE — ręczny import)
- `dev-CFStack-1T5V9JHA4BUVG`
- `dev-DBStack-EZ6JH7WSBA94`
- `dev-ECSStack-1BLAWHL0P6JKO` (parent stack)
- `dev-S3Stack-1KHZX0UTP8Q0F`
- `dev-EndPiontsStack-1J46NEV2QF038`
- `dev-SGStack-1EFR9MHBHZPS1`
- `dev-IAMStack-1S6M9WEMCQVIT`
- `dev-VPCStack-FFQTYHECIX9M`
- `dev` (root stack)

**prod — 1 stack bez tagów:**
- `prod` (root stack)

Wzorzec: child stacki ECS mają tagi, parent/infrastrukturalne nie.

### 3. Dry-run apply-pack tagging (env=dev)

- 14 stacków dev przejrzanych, 4 już zgodne (ECS child), 10 do aktualizacji
- Plan: dodać tylko `Environment` i `Project` (required_tags w project.yaml)
- **Nie uruchamiać bez weryfikacji** — patrz uwagi poniżej

## Bug w toolkicie — naprawiony

**Problem:** `apply-pack tagging` ustawiał `Project = infra-rshop` zamiast `rshop`.

**Przyczyna:**
- Makefile wywołuje `stack-tag-updater.py --project-root /path/infra-rshop` (bez `--project`)
- `main()` line 477: `project_name = args.project or Path(args.project_root).name` → `"infra-rshop"`
- `build_proposed_tags()` line 115 używało tej zmiennej bezpośrednio jako wartości tagu

**Fix** (`tools/finops_tagging/stack-tag-updater.py` line 115):
```python
# przed:
default_values["Project"] = project
# po:
default_values["Project"] = (project_cfg or {}).get("project") or project
```

Fix zweryfikowany dry-runem — `Project = rshop (new)` ✔

## Spójność lokalnych templatek vs S3

Bucket: `s3://rshop-cf/dev/`

- 13/14 plików: **zgodne**
- `root-dev.yml`: **różnica** — lokalna wersja nowsza, nie wgrana na S3

Różnice w `root-dev.yml`:

| Linia | S3 (deployed) | Lokalnie |
|-------|---------------|----------|
| 7 | `Default: Rshop` | `Default: rshop` |
| 67 | `AllowedPattern: "[a-zA-Z0-9]+"` | `"^$\|[a-zA-Z0-9]+"` |
| 71 | `MinLength: "1"` | `MinLength: "0"` + `Default: ""` |
| 74 | DB password pattern (bez pustego) | z obsługą pustego stringa |
| 78 | `MinLength: "8"` | `MinLength: "0"` + `Default: ""` |

Zmiana wygląda jak celowe złagodzenie walidacji parametrów DB (obsługa pustego stringa). **Do wyjaśnienia przed deploy.**

## Uwagi operacyjne

- Dla projektów CloudFormation (rshop i podobne): dodajemy **tylko required_tags** (`Project`, `Environment`) — nie recommended/optional — żeby nie spowodować rozjazdu na środowisku
- `dev/migration/` na S3 zawiera dwa pliki z 2026-04-06 19:38 (późniejsze niż reszta) — artefakty ręcznego importu `dev-alb-ownership`
- Cost Explorer dla tego konta działa na linked account — brak dostępu do `ListCostAllocationTags` (AccessDeniedException)

## Wynik apply-pack tagging (2026-04-18)

apply-pack zablokował **10/10 stacków** — żadne zmiany nie zostały wprowadzone (środowisko bezpieczne).

**Przyczyna blokad:**

| Problem | Stacki | Opis |
|---------|--------|------|
| `BLOCKED_RESOURCE_CHANGE` | 9 stacków | CFN propaguje tagi stack-level do wszystkich zasobów → changeset shows resource modifications — toolkit blokuje |
| `BLOCKED_CAPABILITY_REQUIRED` | `dev-IAMStack` | `create_change_set` nie przekazuje `CAPABILITY_NAMED_IAM` — bug w toolkicie |

Stacki ze zdefiniowanymi tagami explicite w szablonie (ECS child stacks) przeszły jako `already compliant`. Wszystkie pozostałe zablokowane przez propagację.

**Root cause:** safety check w toolkicie (`validate_tag_only_changeset`) blokuje każdą modyfikację zasobu, włącznie z dodaniem tagu. Nie odróżnia tag-only change od zmiany konfiguracji.

→ Wymaga poprawki w toolkicie (`tools/finops_tagging/stack-tag-updater.py`) — temat przeniesiony do devops-toolkit.

## Następne kroki

- [ ] Wyjaśnić różnicę w `root-dev.yml` — czy zmiana jest gotowa do deploy?
- [ ] **Zablokowane:** `toolkit apply-pack tagging mako/rshop --env dev` — wymaga najpierw naprawy toolkitu (changeset check + CAPABILITY_NAMED_IAM)
- [ ] Po naprawie toolkitu: ponowić apply-pack dev, potem prod
- [ ] ECS PropagateTags — osobna zmiana szablonów, po tagowaniu stacków
- [ ] Rozważyć deployment `root-dev.yml` na S3 jeśli zmiana potwierdzona
