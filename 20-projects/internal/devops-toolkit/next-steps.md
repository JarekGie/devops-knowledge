# devops-toolkit — Następne kroki

## Priorytet: Teraz (znane długi techniczne)

- [ ] **Cost normalization** — `normalizers/cost/normalize-cost.py:10` — plik jest stubem z TODO. Bez tego FinOps pipeline ma niekompletne dane normalizacji kosztów
- [ ] **FinOps findings sanitization** — `sanitizers/sanitize-finops-findings.py:3` — stub z `print("TODO sanitize findings")`. Bez tego FinOps audit pipeline nie jest w pełni bezpieczny dla AI
- [ ] **ALB scaffold fix** — scaffold generuje `alb_enable_https = false + alb_certificate_arn = null` z TODO; zarejestrowane jako znana regresja w `test_init_project.py:1396`

## Priorytet: Ten tydzień (do weryfikacji)

- [ ] **Terraform provider auto-detection** — częściowa implementacja, edge cases z parsowaniem HCL2; sprawdzić zakres niekompletności
- [ ] **Sprawdzić status devops-toolkit-ui** — repo istnieje, nie wiadomo czy operator console UI jest zsynchronizowane z aktualnym backendem
- [ ] **Weryfikacja devops-toolkit-usage** — repo z przykładami użycia; upewnić się że E2E testy przechodzą po ostatnich zmianach (PR #50 observability-ready)

## Backlog

- [ ] Dokończyć dokumentację kontraktów dla nowych capabilities (observability-ready, aws-logging-audit)
- [ ] Dodać contract definitions do `docs/kontrakty/` dla pluginów dodanych w PR #44–#50
- [ ] Uzupełnić templates w `templates/command-template/` i `templates/plugin-template/` (mają TODOs)
- [ ] Zweryfikować czy `devops-console-light` jest aktywnie utrzymywane czy archived

## Pomysły / nie-teraz

- [ ] Konteneryzacja toolkit'u (Docker) — umożliwiłaby uruchamianie bez lokalnego Pythona
- [ ] Publish do PyPI — ułatwiłby instalację bez klonowania repo
- [ ] Rozszerzyć coverage na GCP / Azure (toolkit jest aktualnie AWS-only)
- [ ] Automatyczne triggery audytów po deploy (webhook / GitHub Actions integration)

---

*Powiązane: [[context]] | [[decisions]] | [[session-log]]*
