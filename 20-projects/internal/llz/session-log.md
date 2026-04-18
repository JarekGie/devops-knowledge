# LLZ — Session Log

Format: data, co zrobiono, gdzie skończono, co następne.

---

## 2026-04-18 — Inicjalizacja projektu LLZ w vault

**Co zrobiono:**
- Utworzono sekcję `20-projects/internal/llz/` w vault
- Napisano `context.md` (LLM-ready, standalone)
- Napisano `progress-tracker.md` (template do wypełnienia)
- Zmirrorowano `docs/llz-audit.md` z toolkit → `60-toolkit/llz-audit.md`
- Zidentyfikowano zakres: LLZ v1 = Terraform only, 3 obszary (A/B/C), statyczny audit

**Stan na koniec:**
- Vault gotowy do pracy z LLZ
- Projekty Terraform do audytu: nieznane — wymaga inwentaryzacji
- Toolkit LLZ: zaimplementowany, gotowy do użycia

**Następna sesja:**
- Zinwentaryzować projekty Terraform w organizacji
- Uruchomić `toolkit audit-pack llz-basic` na pierwszym projekcie
- Uzupełnić progress-tracker

---

## 2026-04-18 — Architektura LLZ: idee i backlog

**Co omówiono:**
- LLZ to nie tylko Terraform scaffold — obejmuje observability (aws-logging-audit) i tagging dla wszystkich projektów AWS
- Tryb organizacyjny: toolkit jest projektowy, przejście do org-scope to zmiana filozofii (nie ryzykowna technicznie, wymaga nowej warstwy)
- Plugin API: toolkit ma wewnętrzny system pluginów (BasePlugin), formalizacja jako public API ma sens przy 3+ external consumers
- Org-audit to orchestrator (iteracja + AssumeRole + aggregacja), nie plugin — mylenie tych dwóch to pułapka architektoniczna
- Scope model: `project` vs `org` — musi być zaprojektowany przed implementacją
- LLM wiki pattern (Karpathy): vault jako AI-friendly knowledge base, Confluence jako publish target
- SLA/SLO: availability z CloudWatch TAK, latency p95/p99 wymaga ALB access logs

**Zapisano:**
- `ideas.md` — 6 idei z oceną ryzyka i statusem
- `context.md` — rozszerzony o 3 wymiary LLZ (scaffold, observability, tagging)
- `60-toolkit/observability-ready.md` — mirror capabilities observability

**Stan:**
- Vault LLZ gotowy do pracy
- Brak konkretnego następnego kroku implementacyjnego — materiał do przemyślenia

---

<!-- Template:

## YYYY-MM-DD — [opis]

**Co zrobiono:**
-

**Stan na koniec:**
-

**Następna sesja:**
-

-->
