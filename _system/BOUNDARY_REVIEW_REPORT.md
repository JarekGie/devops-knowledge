---
title: Raport audytowy granic domeny — vault
domain: shared-concept
origin: own
classification: internal
llm_exposure: allowed
cross_domain_export: allowed
source_of_truth: vault
created: 2026-04-24
updated: 2026-04-24
---

# Raport audytowy granic domeny

> Wynik przeglądu vault pod kątem separacji domen wiedzy.
> Aktualizuj przy każdym większym przeglądzie struktury.
> Ostatni przegląd: 2026-04-24

---

## Foldery bezpieczne (bez ryzyka mieszania domen)

| Folder | Domena | Uzasadnienie |
|--------|--------|-------------|
| `40-runbooks/` | `operational-runbook` / `shared-concept` | Procedury ogólne lub klientowskie — struktura jasna |
| `30-standards/` | `shared-concept` | Standardy organizacyjne MakoLab — nie klientowskie |
| `10-areas/` | `shared-concept` | Wiedza domenowa (AWS, Terraform) — neutralna technicznie |
| `90-reference/commands/` | `reference-material` | Komendy ogólne, brak danych klienta |
| `90-reference/snippets/` | `reference-material` | Snippety ogólne |
| `90-reference/glossary/` | `reference-material` | Słownik — publiczny |
| `30-research/ai4devops/` | `shared-concept` | Wzorce neutralne — zweryfikowane 2026-04-24 |
| `80-architecture/` | `shared-concept` / `internal` | ADR ogólne — nie klientowskie |
| `20-projects/clients/bmw/ai-taskforce/` | `client-work` | Nowo utworzony, czysty |
| `20-projects/internal/cloud-support-as-a-service/` | `internal-product-strategy` | Nowo utworzony, czysty |

---

## Foldery wymagające przeglądu

### `20-projects/clients/mako/`

**Ryzyko:** Folder zawiera projekty klientowskie (maspex, pbms, puzzler-b2b, anonimizator) bez frontmatter z klasyfikacją.

**Problem:** Nie wiadomo czy poszczególne notatki są `client-work / confidential` czy `operational-runbook / internal`.

**Rekomendacja:** Dodaj frontmatter do plików `troubleshooting.md`, `00-README.md`, `session-log.md` w każdym projekcie klienta. Minimum: `domain: client-work`, `classification: confidential`.

**Priorytet:** Wysoki — te foldery mogą być ładowane do LLM bez świadomości ich wrażliwości.

---

### `20-projects/internal/`

**Ryzyko:** Folder zawiera projekty wewnętrzne MakoLab bez jednolitej klasyfikacji domeny.

**Podfoldery do przeglądu:**

| Podfolder | Potencjalna domena | Ryzyko |
|-----------|-------------------|--------|
| `llz/` | `internal-product-strategy` / `private-rnd` | LLZ jest platformą MakoLab — strategia czy R&D? |
| `devops-toolkit/` | `private-rnd` | Prywatne R&D — OK, ale brak frontmatter |
| `devops-business/` | `internal-product-strategy` | Strategia biznesowa — potrzebuje `confidential` |
| `devops-platform/` | `internal-product-strategy` | Jak wyżej |
| `aws-cloudops-exam/` | `private-rnd` / `reference-material` | Prep do egzaminu — niskie ryzyko |
| `udemy-transcript-tool/` | `private-rnd` | Prywatny projekt — OK |

**Rekomendacja:** Dodaj frontmatter do plików index/README w każdym podfolderze.

---

### `_chatgpt/context-packs/`

**Ryzyko:** Context packi mogą mieszać domeny w jednym pliku.

**Szczegółowa analiza:**

| Plik | Zawartość | Ryzyko |
|------|-----------|--------|
| `llz.md` | Platforma LLZ — MakoLab internal | `domain: internal-product-strategy` — brak frontmatter |
| `devops-toolkit.md` | Toolkit — prywatne R&D | `domain: private-rnd` — brak frontmatter |
| `maspex-load-testing.md` | Projekt klienta | `domain: client-work` — brak frontmatter |
| `maspex-uat-api-supabase-investigation-2026-04-23.md` | Projekt klienta | `domain: client-work` — brak frontmatter |

**Rekomendacja:** Dodaj frontmatter do każdego pliku w `_chatgpt/context-packs/`. Pliki klientowskie MUST mieć `classification: confidential`.

---

### `90-reference/notebooklm/`

**Ryzyko:** Nieznana zawartość — może zawierać wyjście z sesji NotebookLM mieszające domeny.

**Rekomendacja:** Przejrzyj zawartość. Pliki syntezy z sesji klientowskich → `20-projects/clients/`. Pliki syntezy z sesji toolkit → `60-toolkit/` lub `20-projects/internal/devops-toolkit/`.

---

### `60-toolkit/`

**Ryzyko:** Folder `private-rnd` bez jawnego kontraktu granic przed 2026-04-24.

**Status po 2026-04-24:** Dodano `research-boundaries.md` i `ai4devops-relationship.md` z kontraktem.

**Rekomendacja:** Dodaj frontmatter do głównych plików: `README.md`, `contracts/`, `command-catalog.md`. Brak frontmatter = domyślne `domain: private-rnd, classification: restricted`.

---

### `02-active-context/`

**Ryzyko:** `now.md` zawiera stan operacyjny z wielu projektów (klientowskich + wewnętrznych) w jednym pliku.

**Ocena:** Akceptowalne — `now.md` jest narzędziem roboczym, nie źródłem dla LLM. Nie powinien być ładowany do LLM (zgodnie z `NOTEBOOKLM_CONTRACT.md`).

**Rekomendacja:** Utrzymaj istniejącą zasadę z `NOTEBOOKLM_CONTRACT.md`: `now.md` nie trafia do paczek źródłowych LLM.

---

## Potencjalne konflikty domen

| Konflikt | Opis | Rekomendacja |
|----------|------|-------------|
| `llz/` w `20-projects/internal/` | LLZ jest zarówno platformą MakoLab (`internal-product-strategy`) jak i projektem z komponentami R&D | Rozdziel: `llz/` = `internal-product-strategy`; kod toolkit powiązany z LLZ = `private-rnd` |
| `_chatgpt/context-packs/` | Mieszanie klientowskich i wewnętrznych paczek w jednym folderze | Dodaj frontmatter; rozważ podfolderowanie `clients/` vs `internal/` |
| `cloud-detective/` hipotezy w `30-research/ai4devops/` | Plik `CLOUD_DETECTIVE_CONNECTIONS.md` jest w `shared-concept` ale opisuje `private-rnd` | Ocena: plik zawiera tylko hipotezy relacji, nie specyfikę implementacji — akceptowalny jako `shared-concept`; hipotezy implementacyjne MUST być w `60-toolkit/cloud-detective/` |

---

## Rekomendowane migracje

**Nie wykonuj automatycznie — każda migracja wymaga ręcznej weryfikacji treści.**

| Co | Skąd | Dokąd | Priorytet |
|----|------|-------|-----------|
| Synthesis output z sesji NotebookLM o maspex | `90-reference/notebooklm/` | `20-projects/clients/mako/maspex/` | Średni |
| Pliki syntezy klientowskie z `_chatgpt/context-packs/` | `_chatgpt/context-packs/` | Dodać frontmatter, nie migrować | Wysoki |
| Dodanie frontmatter do projektów klientów | `20-projects/clients/mako/*/` | w miejscu | Wysoki |

---

## Rzeczy których NIE należy przenosić automatycznie

- `02-active-context/now.md` — narzędzie robocze, nie baza wiedzy
- `40-runbooks/` — ogólne runbooki nie wymagają reklasyfikacji
- `30-standards/` — standardy organizacyjne, nie klientowskie
- `80-architecture/decision-log.md` — ADR może dotyczyć różnych projektów; zachowaj, dodaj frontmatter
- Pliki historyczne w `20-projects/clients/` z zamkniętych projektów — nie ruszaj bez potrzeby

---

## Następne akcje (ręczne)

- [ ] Dodaj frontmatter do `20-projects/clients/mako/*/troubleshooting.md`
- [ ] Dodaj frontmatter do `_chatgpt/context-packs/*.md`
- [ ] Przejrzyj `90-reference/notebooklm/` i ustal co tam jest
- [ ] Dodaj frontmatter do `20-projects/internal/*/README.md`
- [ ] Rozszerz model `domain: internal-product-strategy` + `related_domains: [private-rnd]` na pozostałe notatki w `20-projects/internal/llz/`
- [ ] Dodaj frontmatter do `60-toolkit/README.md` i `60-toolkit/contracts/`

---

## Hardening Pass Delta

### New controls added

- Dodano [[BOUNDARY_EXCEPTION_PROCESS]] jako formalny proces kontrolowanych wyjątków granicznych.
- Dodano [[LLM_EXPORT_POLICY]] jako politykę egress dla ChatGPT, Claude, NotebookLM i modeli lokalnych/self-hosted.
- Dodano reguły dziedziczenia klasyfikacji do [[CLASSIFICATION_MODEL]], w tym zakaz cichego obniżania klasy wrażliwości.
- Rozszerzono [[PROMPT_BOUNDARY_CHECKLIST]] o kontrole eksportu i minimalizacji danych.
- Doprecyzowano LLZ jako domenę główną `internal-product-strategy` z `related_domains: private-rnd`.
- Dodano reguły anti-drift dla `30-research/ai4devops/`, aby chronić warstwę `shared-concept`.

### Contracts strengthened

- [[DOMAIN_ISOLATION_CONTRACT]] teraz jawnie odsyła do procesu wyjątku granicznego.
- [[DERIVATIVE_INSIGHT_RULES]] nie dopuszcza już skrótu `client-work -> private-rnd` ani `client-work -> internal-product-strategy` bez pośredniego etapu `shared-concept`.
- [[KNOWLEDGE_BOUNDARIES]] obejmuje teraz wyjątki graniczne, dziedziczenie klasyfikacji i politykę eksportu LLM.
- Model granic został doprecyzowany tak, aby `shared-concept` był jedyną warstwą neutralizacji przy przepływie z `client-work`.

### Unresolved questions to revisit later

- Czy potrzebny jest centralny rejestr wyjątków granicznych zamiast dokumentacji rozproszonej po notatkach docelowych.
- Czy `20-projects/internal/llz/README.md` i pozostałe notatki LLZ powinny otrzymać ten sam model `domain` / `related_domains`.
- Czy polityka egress powinna rozróżniać warianty narzędzi bardziej granularnie, np. ChatGPT Enterprise vs Teams vs API, Claude web vs API.
- Czy potrzebny jest osobny kontrakt dla materiałów `mixed`, aby uniknąć nadużycia tej klasy.
