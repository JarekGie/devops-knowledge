---
title: "WAF admin panel open — kapsel-prod.makotest.pl — 2026-05-18"
date: 2026-05-18
type: iac-change
environment: prod
status: plan-ready / pending-apply
classification: internal
domain: client-work
aws_profile: maspex-cli
---

# WAF admin panel — tymczasowe otwarcie kapsel-prod.makotest.pl

## Kontekst

`kapsel-prod.makotest.pl` (admin panel prod) był ograniczony przez WAF do MakoLab office IPs.
Zmiana tymczasowo otwiera host na `0.0.0.0/0` z zachowaniem starej allowlisty w kodzie.

## Co zmieniono

**Plik:** `terraform/envs/prod/waf.tf`

**Zasób:** `aws_wafv2_web_acl.admin_panel_allowlist`

```diff
- description = "Allow only MakoLab office IPs to access kapsel-prod.makotest.pl"
+ description = "TEMP: open to public (0.0.0.0/0) — rollback: revert default_action to block{}"

  default_action {
-   block {}
+   allow {}
  }
```

Stare IPs **pozostają nienaruszone** w kodzie:
- `local.admin_panel_allowed_ipv4_cidrs`: `195.117.107.110/32`, `91.233.19.251/32`
- `aws_wafv2_ip_set.admin_panel_allowlist` — IPSet nadal istnieje
- Reguła `allow-makolab-office-ips` nadal istnieje w WAF

## Plan tfplan

```
Plan: 0 to add, 1 to change, 0 to destroy.
Plik: terraform/envs/prod/admin-panel-open.tfplan
```

Jedyna zmiana: `aws_wafv2_web_acl.admin_panel_allowlist` (id: `54768929-a779-4c89-b99b-8468c7be3120`)

## Zastosowanie

```bash
cd terraform/envs/prod
AWS_PROFILE=maspex-cli terraform apply "admin-panel-open.tfplan"
```

## Rollback

**Co cofnąć:** W `waf.tf` w zasobie `aws_wafv2_web_acl.admin_panel_allowlist`:
```hcl
default_action {
  block {}  # przywróć z allow {}
}
```

**Zachowane adresy IP (rollback source):**
```hcl
# waf.tf, locals block na górze pliku:
admin_panel_allowed_ipv4_cidrs = [
  "195.117.107.110/32",  # MakoLab office
  "91.233.19.251/32",    # MakoLab office
]
```

**Apply po cofnięciu:**
```bash
AWS_PROFILE=maspex-cli terraform plan -out=admin-panel-block.tfplan
AWS_PROFILE=maspex-cli terraform apply "admin-panel-block.tfplan"
```

Rollback to **wyłącznie terraform apply** — nie wymaga żadnych zmian poza jedną linią w `waf.tf`.

## Zakres zmiany

- Dotyczy **tylko** `aws_wafv2_web_acl.admin_panel_allowlist`
- CF E32AZKJ5SJSDSV (`kapsel-prod.makotest.pl`) — jedyny host podłączony pod ten WAF
- Nie rusza `twojkapsel.pl` ani `aws_wafv2_web_acl.public_app_allowlist`
- Nie rusza ECS, ALB, ElastiCache, inne zasoby

## Powiązane

- [[cutover-twojkapsel-2026-05-17]]
- [[maspex-context]]
