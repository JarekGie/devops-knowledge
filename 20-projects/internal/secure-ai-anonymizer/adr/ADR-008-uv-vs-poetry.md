---
title: "ADR-008: uv jako menedżer pakietów (vs Poetry)"
domain: private-rnd
origin: own
classification: restricted
llm_exposure: restricted
cross_domain_export: prohibited
source_of_truth: vault
created: 2026-05-07
updated: 2026-05-07
status: accepted
---

# ADR-008 — uv jako menedżer pakietów (vs Poetry)

**Status:** Accepted  
**Data:** 2026-05-07

---

## Kontekst

Projekt wymaga menedżera pakietów Python do zarządzania zależnościami, środowiskiem wirtualnym i instalacją w trybie edytowalnym. Opcje:

1. **uv** — Rust-based, ~100x szybszy od pip/Poetry, standard de facto dla nowych projektów Python w 2026
2. **Poetry** — dojrzały, szeroko używany, własny lock format
3. **pip + requirements.txt** — najprostszy, brak lock file management

---

## Decyzja

**Wybrany: uv**

---

## Uzasadnienie

**Szybkość instalacji** — uv jest ~10-100x szybszy niż Poetry przy `sync`. Istotne przy Docker builds i CI.

**Standard 2026** — uv zastąpił Poetry jako domyślny wybór dla nowych projektów Python. Kompatybilny ze standardowym `pyproject.toml` (PEP 517/518/621).

**Lockfile** — `uv.lock` jest deterministyczny i cross-platform. `uv sync` gwarantuje reproducibility.

**`pyproject.toml` kompatybilność** — uv czyta standardowy `[project]` + `[tool.uv]` bez custom sections specyficznych dla Poetry. Łatwiej migrować do pip/pipx jeśli potrzeba.

**Docker integration** — `COPY uv.lock . && uv sync --frozen --no-dev` jest prostszy niż Poetry w multi-stage builds.

**Dlaczego nie Poetry?**

- Poetry ma własny format zależności (`[tool.poetry.dependencies]`) który nie jest PEP 621
- Poetry jest wolniejszy przy każdym `install`
- Lock format Poetry jest trudniejszy do auditowania security tools

**Dlaczego nie pip + requirements.txt?**

- Brak automatycznego lock file management
- Brak separation `dev` vs `prod` zależności w jednym pliku
- Manual `pip freeze` jest podatny na environment pollution

---

## Konsekwencje

- `uv sync` zamiast `poetry install`
- `uv run <cmd>` zamiast `poetry run <cmd>`
- `uv add <pkg>` zamiast `poetry add <pkg>`
- `uv.lock` jest commitowany do repozytorium
- Docker: `COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv`
- Dev dependencies w `[tool.uv]` sekcji `pyproject.toml`
