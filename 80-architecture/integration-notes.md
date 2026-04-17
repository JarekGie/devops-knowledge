# Notatki integracyjne

Integracje z zewnętrznymi systemami — szczegóły, gotcha, konfiguracja.

#architecture #integrations

## GitHub → AWS (OIDC)

```yaml
# Trust policy dla roli GitHub Actions
{
  "Effect": "Allow",
  "Principal": {
    "Federated": "arn:aws:iam::ACCOUNT:oidc-provider/token.actions.githubusercontent.com"
  },
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Condition": {
    "StringEquals": {
      "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
    },
    "StringLike": {
      "token.actions.githubusercontent.com:sub": "repo:ORG/REPO:*"
    }
  }
}
```

## ECR → ECS

- ECS task execution role musi mieć `ecr:GetAuthorizationToken` + `ecr:BatchGetImage`
- Image URI format: `{account}.dkr.ecr.{region}.amazonaws.com/{repo}:{tag}`

## Secrets Manager → ECS

```json
// Task definition — secrets z Secrets Manager
{
  "secrets": [
    {
      "name": "DB_PASSWORD",
      "valueFrom": "arn:aws:secretsmanager:region:account:secret:name"
    }
  ]
}
```

## Route53 → ALB

- Alias record (nie CNAME) dla domeny root
- Health check na ALB musi być skonfigurowany

## CloudFront → ALB (origin)

- ALB musi akceptować ruch tylko z CloudFront IP ranges lub via Managed Prefix List
- Custom header verification (X-Custom-Header)

## Integracje klienckie

<!-- Dodawaj per klient/projekt -->

---

*Powiązane: [[system-maps]] | [[platform-principles]]*
