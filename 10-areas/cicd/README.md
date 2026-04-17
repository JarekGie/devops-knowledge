# Area — CI/CD

Wzorce i konfiguracje pipeline'ów.

**Należy tutaj:** wzorce GitHub Actions / GitLab CI, gotcha, referencje.  
**Nie należy tutaj:** runbooki (→ `40-runbooks/`), standardy (→ `30-standards/cicd-standard.md`).

## Standard

→ [[cicd-standard]]

## Platformy

| Platforma | Zastosowanie |
|-----------|-------------|
| GitHub Actions | główna platforma CI/CD |
| GitLab CI | projekty klienckie |
| Jenkins | legacy |
| Make | lokalne automatyzacje, task runner |

## Wzorce

### GitHub Actions — reusable workflow

```yaml
# .github/workflows/deploy.yml
on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment }}
    steps:
      - uses: actions/checkout@v4
```

### Sekwencja deploy

```
build → test → push image → plan → apply (z approval na prod)
```

## Gotcha

- OIDC dla AWS — rola musi mieć trust policy z `token.actions.githubusercontent.com`
- Cache w GitHub Actions — klucz musi zawierać hash lock file
- GitLab CI `needs:` — nie działa cross-pipeline bez explicit trigger
- Jenkins: unikaj `sh` z interpolacją zmiennych — ryzyko injection

## Sekrety

Sekretów nie ma w repozytorium. Przechowywane w:
- GitHub: repository / environment secrets
- GitLab: CI/CD Variables
- AWS: Secrets Manager + OIDC
