# Paczka kontekstu — Maspex Load Test Generator ASG

> Wklej całość na początku rozmowy z ChatGPT.
> Temat: infrastruktura generatorów obciążenia (EC2 ASG), zarządzanie flotą, skrypty kontrolne.

**Zakres:** EC2 ASG `maspex-uat-loadtest`, fleet scripts, WAF integration, otwarte braki
**Data:** 2026-05-14

---

## Kim jestem / kontekst roli

Senior DevOps/SRE, AWS (eu-west-1), Terraform, ECS Fargate. Pracuję nad projektem Maspex — platforma konkursowa Kapsel. Infra jako kod w repo `infra-maspex` (GitLab).

---

## Architektura generatorów load testu

### EC2 ASG — `maspex-uat-loadtest`

| Parametr | Wartość |
|----------|---------|
| Typ instancji | `c6i.4xlarge` — 16 vCPU, 32 GiB RAM, 12.5 Gbps |
| AMI | Amazon Linux 2023 (latest x86_64, dynamic lookup) |
| min / max / desired | 0 / 2 / 2 |
| Skalowanie automatyczne | Brak — tylko ręczne (`ignore_changes = [desired_capacity]`) |
| Sieć | Public subnets, public IP via IGW |
| SSH dostęp | MakoLab office: `195.117.107.110/32`, `91.233.19.251/32` + var |
| Fallback dostęp | SSM Session Manager (IAM: AmazonSSMManagedInstanceCore) |
| Storage | 50 GB gp3 EBS, IMDSv2 required |
| Oprogramowanie (user_data) | Docker, k6 (Grafana RPM), jq, htop, ncat |
| Terraform plik | `terraform/envs/uat/loadtest.tf` |

### WAF — integracja

Generatory muszą przechodzić przez CloudFront WAF (scope: CLOUDFRONT, us-east-1). Ich publiczne IP są zarządzane dynamicznie w dwóch IP sets:

| IP Set | Środowisko | Zarządzane przez |
|--------|-----------|-----------------|
| `maspex-uat-loadtest-allowlist` | UAT CloudFront | `loadtest-ctrl.sh --run/--stop` |
| `maspex-prod-loadtest-allowlist` | PROD CloudFront | `loadtest-fleet-start.sh` / `loadtest-fleet-stop.sh` |

Oba IP sety są puste w spoczynku — skrypty dodają/czyszczą IP przed/po teście.

---

## Skrypty kontrolne — aktualny stan

### Na branchu `origin/main` (UAT-centric)

```
scripts/loadtest-ctrl.sh   — bash: --run | --stop | --clear | --ssh
scripts/loadtest-ctrl.ps1  — PowerShell 5.1: te same 4 akcje
```

**`--run`:** scale ASG desired=2 → czeka na InService → czyści stare IP → dodaje nowe IP do UAT WAF
**`--stop`:** czyści UAT WAF IP set → scale ASG desired=0 → czeka aż instancje znikną
**`--clear`:** CloudFront invalidation `/*` na `E3J76RNXIE2YIG` (UAT CF) + ElastiCache reboot `maspex-uat` node `0001`
**`--ssh`:** pobiera IP instancji InService, jeśli >1 pokazuje menu wyboru, exec `ssh ec2-user@IP`

### Na branchu `feat/prod-parity-uat` (PROD WAF support)

```
scripts/loadtest-fleet-start.sh  — bash: scale up + update PROD WAF
scripts/loadtest-fleet-stop.sh   — bash: clear PROD WAF + scale down
```

Różnica vs ctrl: brak `--clear` (CF invalidation + Redis reboot), brak `--ssh`, brak `.ps1`.

### Stan rozbieżności

Branch `feat/prod-parity-uat` odgałęził się przed dodaniem ctrl-skryptów na main. Po merge na main obydwa zestawy będą współistnieć. Nowe fleet-skrypty nie zastąpiły ctrl-skryptów — to uzupełnienie dla PROD WAF.

---

## Kluczowe zasoby AWS

```
ASG:           maspex-uat-loadtest (eu-west-1)
UAT CF:        E3J76RNXIE2YIG → kapsel.makotest.pl
PROD CF:       (znany po terraform apply PROD)
ElastiCache:   maspex-uat, node 0001 (eu-west-1)
WAF UAT:       maspex-uat-loadtest-allowlist (us-east-1, CLOUDFRONT)
WAF PROD:      maspex-prod-loadtest-allowlist (us-east-1, CLOUDFRONT)
AWS Profile:   maspex-cli
Account:       969209893152
```

---

## Braki do uzupełnienia (otwarty work item)

1. **`--clear` dla PROD** — brak skryptu do CloudFront invalidation + Redis reboot na PROD. PROD CF distribution ID będzie znany po terraform apply. Pytanie: czy reboot ElastiCache (destrukcyjny) vs FLUSHALL przez redis-cli (wymaga dostępu do klastra)?

2. **`.ps1` dla fleet scripts** — brak PowerShell odpowiednika `loadtest-fleet-start.sh` i `loadtest-fleet-stop.sh`. Potrzebny dla deweloperów na Windows.

3. **`--ssh` w fleet scripts** — brak helpera SSH w nowych skryptach.

---

## Pytanie

Chcę uzupełnić brakujące elementy. Potrzebuję pomocy z:

a) **`loadtest-fleet-clear.sh`** — CloudFront invalidation `/*` na PROD CF distribution + ElastiCache reboot (lub FLUSHALL). Parametr `--cf-distribution-id` lub hardcode po apply. Styl zgodny z `loadtest-fleet-start.sh`: `set -euo pipefail`, `log()/info()/ok()/die()`, `--dry-run` flag.

b) **`loadtest-fleet-start.ps1` + `loadtest-fleet-stop.ps1`** — PowerShell 5.1 odpowiedniki istniejących bash skryptów. Styl zgodny z `loadtest-ctrl.ps1` (już istnieje w repo): `$ErrorActionPreference = "Stop"`, `Write-Info/Write-Ok/Write-Warn`, `ConvertFrom-Json`.

c) Opcjonalnie: zunifikować wszystko w jeden `loadtest-ctrl-prod.sh` z `--run|--stop|--clear|--ssh` analogicznie do UAT ctrl script.
