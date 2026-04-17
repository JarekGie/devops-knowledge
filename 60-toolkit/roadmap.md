# devops-toolkit — Roadmapa

#toolkit #roadmap

## Fazy

### Faza 1 — MVP Audyt (aktualnie)

- [ ] Kontrakt i implementacja `audit iam`
- [ ] Kontrakt i implementacja `audit tagging`
- [ ] Kontrakt i implementacja `audit s3`
- [ ] Output: JSON + Markdown report
- [ ] CLI entry point z podstawowym routingiem

### Faza 2 — FinOps Reporting

- [ ] `finops report` — raport kosztów per tag
- [ ] Integracja z Cost Explorer API
- [ ] Output: Markdown raport dla klienta
- [ ] `finops optimize` — rekomendacje rightsizing

### Faza 3 — IaC Audit

- [ ] `iac lint` — walidacja Terraform wg standardów
- [ ] Integracja z [[iac-standard]] i [[aws-tagging-standard]]
- [ ] Output: lista findings z severity

### Faza 4 — Platform

- [ ] Composability — pipe między komendami
- [ ] Plugin system — zewnętrzne rozszerzenia
- [ ] Multi-account support
- [ ] CI/CD integration (GitHub Actions action)

## Metryki sukcesu

| Faza | Definicja ukończenia |
|------|---------------------|
| MVP | Audyt IAM + tagging działa na dowolnym koncie AWS |
| FinOps | Raport kosztów generowany w <60 sekund |
| IaC | Lint przechodzi na wzorcowym module |

## Powiązane

- [[contracts-index]]
- [[architecture-overview]]
- `20-projects/internal/devops-toolkit/next-steps.md`
