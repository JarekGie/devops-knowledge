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

### Faza 5 — Stabilization / Refactor

- [ ] Capability consolidation po kampanii remediacji tagowania
- [ ] Redukcja duplikacji między audytami tagging / governance / attribution
- [ ] Uporządkowanie public API do modelu `core / advanced / experimental`
- [ ] Ograniczenie command sprawl przed dalszą ekspansją capability
- [ ] Stabilny baseline architektoniczny dla kolejnych etapów LLZ

### Faza 6 — LLZ Provisioning Expansion

- [ ] Wznowienie prac provisioning LLZ dopiero po zakończeniu Fazy 5
- [ ] Rozszerzenia provisioning wyłącznie na ustabilizowanej bazie capability

## Metryki sukcesu

| Faza | Definicja ukończenia |
|------|---------------------|
| MVP | Audyt IAM + tagging działa na dowolnym koncie AWS |
| FinOps | Raport kosztów generowany w <60 sekund |
| IaC | Lint przechodzi na wzorcowym module |
| Stabilization / Refactor | Capability tagging/governance/attribution skonsolidowane, a API CLI uproszczone bez nowego command sprawl |

## Powiązane

- [[contracts-index]]
- [[architecture-overview]]
- `20-projects/internal/devops-toolkit/next-steps.md`
- [[../10-architecture/adr/ADR-toolkit-stabilization-before-llz-expansion]]
