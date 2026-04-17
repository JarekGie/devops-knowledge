# Standard CI/CD

#cicd #standard

## Zasady

1. **Sekrety nigdy w kodzie** — GitHub Secrets, GitLab CI Variables, AWS Secrets Manager
2. **OIDC dla AWS** — nie używaj długoterminowych access keys w CI
3. **Pinuj wersje akcji** — `uses: actions/checkout@v4` nie `@main`
4. **Approval gate na prod** — deploy na produkcję wymaga ręcznego zatwierdzenia
5. **Artefakty budowane raz** — ten sam image/artefakt przechodzi przez envs
6. **Testy przed deployem** — zawsze: unit, lint, opcjonalnie E2E

## Pipeline — wzorzec

```
trigger → lint/test → build → push → deploy-dev → deploy-staging → [approval] → deploy-prod
```

## GitHub Actions — OIDC (wzorzec)

```yaml
permissions:
  id-token: write
  contents: read

steps:
  - uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: arn:aws:iam::ACCOUNT:role/github-actions-role
      aws-region: eu-west-1
```

## Konwencje branchy

| Branch | Cel | Deploy |
|--------|-----|--------|
| `main` | produkcja | auto po approval |
| `develop` | staging | auto |
| `feature/*` | dev / PR preview | manual |

## Zmienne środowiskowe

```yaml
# GitHub Actions
env:
  AWS_REGION: eu-west-1
  ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
  IMAGE_TAG: ${{ github.sha }}
```

## Powiązane

- `10-areas/cicd/`
- [[aws-tagging-standard]]
