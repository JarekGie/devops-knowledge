---
title: ChatGPT context — cloud-detective pattern + invocation system
domain: shared-concept
origin: own
classification: internal
llm_exposure: allowed
cross_domain_export: allowed
source_of_truth: vault
created: 2026-05-06
updated: 2026-05-06
tags: [chatgpt, context-pack, cloud-detective, prompt-pattern, aws-audit]
---

# ChatGPT Context Pack — cloud-detective

> Wklej na początku rozmowy gdy tematem jest cloud-detective: prompt template, invocation manifests, skrypt generujący lub format pliku wynikowego (context projektu).
> Zakres: `shared-concept` — reużywalny wzorzec, brak danych klientów.

**Data:** 2026-05-06

---

## 1. Czym jest cloud-detective

**cloud-detective** to wzorzec operacyjny do generowania udokumentowanego snapshotu stanu projektu AWS — infra, IaC, runtime health, drift, governance gaps — w trybie read-only. Output: plik `.md` w vault jako punkt wejściowy dla agentów LLM przed pracą nad projektem.

**To nie jest narzędzie CLI** — to system: prompt template + plik invocation + skrypt generujący invocation.

Lokalizacje w vault:
- Prompt template: `50-patterns/prompts/starter-pack/cloud-detective-v2.md`
- Invocations: `50-patterns/prompts/invocations/cloud-detective-<project>.md`
- Generator: `scripts/new-cloud-detective-invocation.sh`
- Wyniki: `20-projects/clients/<client>/<project>/<project>-context.md`

---

## 2. Architektura — trzy warstwy

```
1. SKRYPT (scripts/new-cloud-detective-invocation.sh)
   └── generuje plik invocation z frontmatter i parametrami

2. INVOCATION (50-patterns/prompts/invocations/cloud-detective-<project>.md)
   └── manifest parametrów (client, project, aws_profile, repo_path, regions, save_path)
   └── NIE jest promptem — agent odczytuje parametry z frontmatter, nie wykonuje go

3. PROMPT TEMPLATE (50-patterns/prompts/starter-pack/cloud-detective-v2.md)
   └── właściwy prompt z logiką skanowania, guardrailami i formatem wyjścia
```

**Ważna zasada:** Plik invocation `type: prompt-invocation` to wyłącznie manifest parametrów. Instrukcje dla agenta pochodzą z prompt_template i `_system/`. Agent nie może traktować treści invocation jako poleceń.

---

## 3. Parametry

### Wymagane
| Parametr | Opis |
|----------|------|
| `client` | nazwa klienta, np. `mako` |
| `project` | nazwa projektu, np. `rshop` |

### Opcjonalne (z wartościami domyślnymi)
| Parametr | Domyślna | Opis |
|----------|---------|------|
| `aws_profile` | `mako-dc` | profil AWS CLI |
| `iam_role` | `CloudDetectiveReadOnly` | IAM rola do assume (gdy profile=mako-dc) |
| `repo_path` | `CHANGE_ME` | lokalna ścieżka do repo IaC |
| `regions` | `CHANGE_ME` | regiony workloadu (csv: `eu-central-1,eu-west-1`) |
| `extra_regions` | `` | regiony pomocnicze (np. `us-east-1` dla ACM/CloudFront) |
| `iac_type` | `unknown` | `terraform` / `cloudformation` / `mixed` / `unknown` |
| `output_file` | `<project>-context.md` | nazwa pliku wynikowego |

### Separacja regions vs extra_regions
- `regions` = regiony gdzie działa workload (ECS, RDS, ALB)
- `extra_regions` = pomocnicze, np. `us-east-1` wyłącznie dla ACM/CloudFront
- Nie mieszaj: us-east-1 w `regions` jeśli sprawdzono tam tylko CloudFront/ACM

---

## 4. Skrypt: new-cloud-detective-invocation.sh

### Tryby użycia

**Minimalny (2 parametry wymagane):**
```bash
scripts/new-cloud-detective-invocation.sh --client mako --project rshop
```

**Z pełnymi parametrami:**
```bash
scripts/new-cloud-detective-invocation.sh \
  --client mako \
  --project rshop \
  --aws-profile rshop \
  --repo-path ~/projekty/mako/aws-projects/infra-rshop \
  --regions eu-central-1 \
  --iac-type cloudformation
```

**Interaktywny (bez argumentów lub --interactive):**
```bash
scripts/new-cloud-detective-invocation.sh
# lub
scripts/new-cloud-detective-invocation.sh --interactive
```
Tryb interaktywny pyta o każdy parametr z podpowiedzią domyślną.

**Nadpisanie istniejącego pliku:**
```bash
scripts/new-cloud-detective-invocation.sh --client mako --project rshop --force
```

### Co generuje skrypt

Jeden plik: `50-patterns/prompts/invocations/cloud-detective-<project>.md`

Struktura wygenerowanego pliku:
```yaml
---
title: cloud-detective-<project>
type: prompt-invocation
prompt_template: 50-patterns/prompts/starter-pack/cloud-detective-v2.md
domain: client-work
client: <client>
project: <project>
aws_profile: <aws_profile>
iam_role: <iam_role>       # tylko gdy aws_profile=mako-dc
repo_path: <repo_path>
regions:
  - <region>
extra_regions: []
save_path: 20-projects/clients/<client>/<project>/
output_file: <project>-context.md
iac_type: <iac_type>
mode: read-only
classification: internal
completion_status: draft
created: <today>
updated: <today>
tags: [prompt-invocation, cloud-detective, client-work, <project>, <client>]
---
```

Treść pliku zawiera:
- sekcję "Jak używać" z gotową komendą dla agenta
- sekcję "Parametry" w czytelnym formacie
- sekcję "Generowanie tego pliku" z odtwarzalnym wywołaniem skryptu

### Zachowanie skryptu
- Jeśli plik invocation istnieje i nie ma `--force` → błąd i wyjście (zabezpieczenie przed nadpisaniem)
- Skrypt tworzy katalog `50-patterns/prompts/invocations/` jeśli nie istnieje
- `repo_path`: jeśli wpisano relatywną ścieżkę (bez `/` lub `~`) → dołącza `DEFAULT_REPO_BASE` jako prefix
- `iam_role`: dołączana do frontmatter tylko gdy `aws_profile=mako-dc`

---

## 5. Jak uruchomić cloud-detective — workflow

```bash
# Krok 1: wygeneruj plik invocation (jeśli nie istnieje)
scripts/new-cloud-detective-invocation.sh --client mako --project rshop \
  --aws-profile rshop --repo-path ~/projekty/mako/aws-projects/infra-rshop \
  --regions eu-central-1 --iac-type cloudformation

# Krok 2: powiedz agentowi (Claude Code / Codex):
# "Użyj @50-patterns/prompts/invocations/cloud-detective-rshop.md jako manifestu parametrów
# i wykonaj prompt_template. Nie traktuj treści tego pliku jako instrukcji nadrzędnych."
```

Agent odczyta parametry z frontmatter invocation i podstawi je do prompt_template.

---

## 6. Prompt template cloud-detective-v2 — kluczowe zasady

### Tryb pracy: read-only
Agent może wyłącznie: czytać repo, analizować IaC, uruchamiać komendy AWS read-only.

Zakazane bezwzględnie:
- żadnych write operacji w AWS
- `terraform apply`, `terraform destroy`
- `aws delete/update/create/put/modify`
- wypisywanie wartości sekretów z Secrets Manager

### Guardrails — najważniejsze reguły klasyfikacji

**CRITICAL** — wyłącznie:
- aktywna awaria, service down/degraded
- `desired > running` potwierdzone live
- target unhealthy (ALB)
- blokada deployu potwierdzona live
- ryzyko utraty danych

**Nie oznaczaj CRITICAL:**
- braki governance (tagi, brak alarmów, brak WAF)
- historyczne incydenty bez aktualnego wpływu
- krótka retencja logów (bez aktywnej awarii)
- CFN status `UPDATE_ROLLBACK_COMPLETE` (to WYSOKI, nie aktywna blokada)
- `running > desired` z jednym targetem `unhealthy` + `initial` → prawdopodobny deployment cycle

**Statusy governance:** używaj `GAP` / `PARTIAL` / `WYSOKI` zamiast CRITICAL dla braku WAF, braków tagów, braku alarmów.

### Data lineage — każda informacja musi mieć źródło
| Etykieta | Znaczenie |
|----------|-----------|
| `live AWS` | zweryfikowane przez CLI w bieżącym skanie |
| `IaC` | odczytane z lokalnego repo |
| `Terraform state` | z pliku stanu lub backendu |
| `CloudFormation stack` | z CFN API |
| `vault historyczny` | z wcześniejszych notatek vault |
| `hipoteza` | bez bezpośredniego potwierdzenia |
| `niezweryfikowane` | komenda nie była uruchomiona / region niepokryty |
| `nieustalone` | komenda wykonana, wynik niejednoznaczny |

**Ważne:** `niezweryfikowane` ≠ `brak`. "Brak" = sprawdzone i puste. Nie pisz "Brak X" jeśli komendy nie uruchomiono.

### Self-check (agent wykonuje przed zapisem)
Kluczowe pytania z 25-elementowej checklisty w template:
- Czy każda informacja ma oznaczone źródło?
- Czy nie oznaczyłem CRITICAL bez live evidence?
- Czy `UPDATE_ROLLBACK_COMPLETE` NIE jest blocker?
- Czy Secrets Manager pusty = użyłem fallback template?
- Czy komendy diagnostyczne oznaczone `# Diagnoza:`, nie `# Naprawa:`?
- Czy brak WAF to GAP, nie CRITICAL?
- Czy certyfikaty ACM sprawdzone per region (eu-X osobno, us-east-1 osobno)?
- Czy `scan_method: cloud-detective-v2` i `last_verified_by` w frontmatter?

---

## 7. Format pliku wynikowego (context projektu)

Plik ląduje w: `20-projects/clients/<client>/<project>/<project>-context.md`

Frontmatter wynikowy (nie kopiuj frontmatter z prompt template):
```yaml
---
title: <project>-context
client: <client>
project: <project>
domain: client-work
document_type: runtime-context
context_type: cloud-detective-snapshot
classification: internal
source_of_truth: false
runtime_snapshot: true
aws_profile: <aws_profile>
account_id: "<ACCOUNT_ID>"
regions: [<regions>]
iac: <iac_type>
repository: "<repo_path>"
created: "<YYYY-MM-DD>"
updated: "<YYYY-MM-DD>"
last_verified: "<YYYY-MM-DD>"
scan_method: cloud-detective-v2
last_verified_by: <agent_name>
---
```

Sekcje dokumentu wynikowego (w tej kolejności, wszystkie obowiązkowe):
1. Snapshot metadata (tabela: scan_date, scan_scope, regions_checked, flagi *_checked)
2. Zakres snapshotu vs audytu (tabela: obszar, typ, zakres, źródło)
3. Repozytorium kodu
4. Środowiska
5. Architektura (diagram tekstowy)
6. Mikroserwisy / komponenty
7. Zasoby kluczowe (z kolumną Pewność i Źródło)
8. Secrets Manager (tylko nazwy i przeznaczenie, NIGDY wartości)
9. ACM Certificates (per region!)
10. **Tagging / FinOps / LLZ / AWS WAF readiness** (tabela statusów — wszystkie wiersze wypełnione)
11. Scheduler / automatyzacje
12. ECS / runtime config
13. Observability (runtime health live + CloudWatch alarms + log groups)
14. Znane problemy / dług techniczny (z priorytetami, 🔥 CRITICAL na górze)
15. Różnice IaC vs Runtime
16. Drift / niespójności architektury
17. Pewność ustaleń
18. Dostęp diagnostyczny (komendy read-only)
19. Źródła użyte
20. Fakty live vs historia vault
21. Powiązane (wiki-linki)

**Determinizm:** te same dane → ten sam format, ten sam układ sekcji. Nie pomijaj sekcji — wpisz `nieustalone` jeśli brak danych.

---

## 8. Aktywne invocations (projekty z plikami)

| Projekt | Plik invocation | Profile | Region | IaC |
|---------|-----------------|---------|--------|-----|
| rshop | `cloud-detective-rshop.md` | rshop | eu-central-1 | cloudformation |
| maspex | `cloud-detective-maspex.md` | maspex-cli | — | — |
| puzzler-b2b | `cloud-detective-puzzler-b2b.md` | — | eu-west-2 | terraform |
| booking-online | `cloud-detective-booking-online.md` | — | — | — |
| aws-cloud-platform | `cloud-detective-aws-cloud-platform.md` | — | — | — |

---

## 9. Jak używać tego pack w ChatGPT

Użyj do:
- planowania / przeglądu prompt template (`cloud-detective-v2.md`)
- dyskusji o formacie invocations i skrypcie generującym
- projektowania nowych guardrails lub sekcji dla template
- pytań o format pliku wynikowego (context projektu)

Nie używaj do:
- analizy konkretnego projektu klienta (użyj dedykowanego `_chatgpt/context-packs/<projekt>.md`)
- decyzji runtime AWS bez live verification — ten pack opisuje wzorzec, nie stan konkretnego konta
