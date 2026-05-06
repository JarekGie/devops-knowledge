# Context Pack — Puzzler B2B / PBMS — Jumphost

**Data przygotowania:** 2026-05-06  
**Projekt:** puzzler-b2b / PBMS  
**Klient:** Mako / PBMS  
**AWS profile:** `puzzler-pbms`  
**Region:** `eu-west-2`  
**Konto AWS:** `698220459519`  
**Repo infra:** `~/projekty/mako/aws-projects/infra-puzzler-b2b-final`  
**Vault context:** `20-projects/clients/mako/puzzler-b2b/puzzler-b2b-context.md`

## Cel kontekstu

Ten context pack jest do przekazania ChatGPT przy pracy nad jumphostem w projekcie `puzzler-b2b / PBMS`.

Zakres:
- ECS Fargate jumphost dla dev i QA
- dostęp do DocumentDB przez tunel SSH / ECS Exec
- obraz Docker / ECR dla jumphosta
- `authorized_keys` i Secrets Manager
- znane problemy z TCP forwarding i kluczami SSH
- aktualne ryzyka IaC / repo dotyczące jumphosta

Nie zakładaj, że live state jest aktualny. Ostatnie pełne live dane pochodzą głównie z 2026-05-01, a 2026-05-05 live scan nie był możliwy przez expired credentials profilu `puzzler-pbms`.

## Najważniejszy stan wejściowy

```text
Projekt:       puzzler-b2b / PBMS
AWS profile:   puzzler-pbms
Region:        eu-west-2
Account:       698220459519
Infra repo:    ~/projekty/mako/aws-projects/infra-puzzler-b2b-final
Branch wg snapshotu: feat/dev-jumphost-runtime-secret
```

Pierwszy krok zawsze:

```bash
aws sts get-caller-identity --profile puzzler-pbms
```

Ostatni znany problem z live dostępem:
- 2026-05-05 `aws sts get-caller-identity --profile puzzler-pbms` zwracał `SignatureDoesNotMatch`.
- Statyczne klucze IAM w profilu wyglądały na zrotowane albo unieważnione.
- Dopóki STS nie przejdzie, nie traktuj runtime state jako aktualnego.

## Architektura jumphosta

Środowiska: `dev` i `qa`, oba w `eu-west-2`, konto `698220459519`.

Jumphost jest serwisem ECS Fargate, używanym do dostępu administracyjnego / tunelowania do DocumentDB. W dev jest oczekiwany jako stale działający `1/1`. W QA według ostatniego snapshotu powinien mieć desired `1`, ale był `0/1` z powodu brakującego obrazu ECR.

### ECS

```text
ECS Cluster DEV: infra-puzzler-b2b-dev-puzzler
  service: infra-puzzler-b2b-dev-jumphost
  expected state wg 2026-05-01: desired=1, running=1
  task def wg 2026-05-01: :10

ECS Cluster QA: infra-puzzler-b2b-qa-puzzler
  service: infra-puzzler-b2b-qa-jumphost
  expected desired wg 2026-05-01: desired=1
  observed state wg 2026-05-01: running=0
  task def wg 2026-05-01: :2
  problem: CannotPullContainerError / ECR image missing
```

### DocumentDB endpoints

```text
DocumentDB dev:
infra-puzzler-b2b-dev-puzzler-mongo.cluster-c1moyqeoccm2.eu-west-2.docdb.amazonaws.com:27017

DocumentDB QA:
infra-puzzler-b2b-qa-puzzler-mongo.cluster-c1moyqeoccm2.eu-west-2.docdb.amazonaws.com:27017
```

### Secrets Manager

Istnieją sekrety Terraform-managed:

```text
infra-puzzler-b2b/dev/jumphost-ssh
infra-puzzler-b2b/qa/jumphost-ssh
```

Przechowują `authorized_keys` dla jumphosta. Nie wklejaj prywatnych kluczy ani pełnej zawartości sekretów do rozmów z LLM. Jeśli trzeba opisać stan, użyj liczby wpisów, fingerprintów albo redacted fragments.

## Historia napraw jumphosta

### Pierwotny problem

Developer nie mógł otworzyć tunelu SSH do DocumentDB przez jumphost.

Objawy:
1. `Load key "...": invalid format`
   - przyczyna: klucz miał Windows CRLF albo niepoprawne kodowanie.
2. `Permission denied (publickey)`
   - przyczyna: brak publicznego klucza deva w `authorized_keys`.
3. `channel 2: open failed: administratively prohibited`
   - przyczyna: TCP forwarding wyłączony w `sshd_config`.

### Root cause techniczny

Obraz jumphosta bazuje na Alpine + `sshd`.

W Alpine domyślny `/etc/ssh/sshd_config` zawiera:

```text
AllowTcpForwarding no
```

W jednej z wersji Dockerfile dopisywał:

```bash
echo "AllowTcpForwarding yes" >> /etc/ssh/sshd_config
```

To nie działało, bo `sshd` brał pierwsze wystąpienie dyrektywy. Poprawny fix to zastąpienie istniejącej dyrektywy przez `sed`, np.:

```bash
sed -i 's/AllowTcpForwarding no/AllowTcpForwarding yes/g' /etc/ssh/sshd_config
```

### Iteracje obrazów

Znana historia:

| Tag | Stan |
|---|---|
| `jumphost-v5` | build/push do dev i QA wykonany 2026-04-30; pierwszy kontrolowany rollout |
| `jumphost-v7` | naprawiony `AllowTcpForwarding` przez `sed`; działało |
| `jumphost-v8` / `v9` | dev przerobił obraz, wrócił problem z `echo`; TCP forwarding znów broken |
| `jumphost-v10` | przywrócono `sed`, usunięto zbędne `echo`; status w troubleshooting: resolved 2026-04-30 |

Właściwy kierunek dla obrazu: bazować na wersji `v10` albo sprawdzić, czy aktualny Dockerfile nadal używa `sed` zamiast dopisywania dyrektywy.

## Znany runtime state

### DEV

Według snapshotu:

```text
service: infra-puzzler-b2b-dev-jumphost
cluster: infra-puzzler-b2b-dev-puzzler
state: desired=1, running=1
task definition: :10
```

Ostatni znany IP po deployu `v10`:

```text
18.135.17.131
```

Uwaga: IP taska zmienia się po redeploy/restart. Nie opieraj stałych skryptów na hardcoded IP. Preferuj dynamiczne pobranie ENI/public IP przez AWS CLI.

### QA

Według snapshotu 2026-05-01:

```text
service: infra-puzzler-b2b-qa-jumphost
cluster: infra-puzzler-b2b-qa-puzzler
desired=1
running=0
problem: ECR image missing / CannotPullContainerError
```

Evidence z vault:

```text
CannotPullContainerError — infra-puzzler-b2b-app-qa:jumphost not found w ECR
```

Interpretacja:
- Terraform wdrożył QA service.
- Obraz `jumphost` dla QA nie był dostępny w ECR według ostatniego live snapshotu.
- Stan aktualny trzeba zweryfikować po naprawie credentials.

## Ryzyka repo / security hygiene

Stan z 2026-05-05:

1. `authorized_keys` leży jako untracked file na root repo.
2. `.gitignore` ma literówkę:

```text
autorized_keys
```

zamiast:

```text
authorized_keys
```

Ryzyko: przy `git add .` plik z kluczami publicznymi może trafić do repozytorium. To nie jest prywatny klucz, ale nadal jest to materiał dostępowy i powinien być traktowany ostrożnie.

3. `envs/dev/.env` jest untracked i nieignorowany.
   - W snapshotcie był pusty, ale jeśli operator doda `TF_VAR_*` albo credentiale, może zostać przypadkowo zacommitowany.

4. QA IaC było rozbudowane i niezatwierdzone:
   - `envs/qa/services.tf`
   - `envs/qa/schedulers.tf`
   - `envs/qa/cloudwatch.tf`
   - `envs/qa/secrets.tf`
   - `envs/qa/iam.tf`
   - `envs/qa/alb_frontend.tf`
   - `envs/qa/service_discovery.tf`
   - inne lokalne pliki

Zalecany pierwszy krok lokalny w repo:

```bash
cd ~/projekty/mako/aws-projects/infra-puzzler-b2b-final
git status --short
git check-ignore -v authorized_keys envs/dev/.env
```

Nie wykonuj `git add .` przed naprawą ignore rules i oceną untracked files.

## Komendy diagnostyczne

### Identity

```bash
aws sts get-caller-identity --profile puzzler-pbms
```

### DEV jumphost service

```bash
aws ecs describe-services \
  --cluster infra-puzzler-b2b-dev-puzzler \
  --services infra-puzzler-b2b-dev-jumphost \
  --profile puzzler-pbms \
  --region eu-west-2 \
  --query 'services[*].{name:serviceName,desired:desiredCount,running:runningCount,pending:pendingCount,taskDef:taskDefinition,status:status,events:events[0:5].message}'
```

### QA jumphost service

```bash
aws ecs describe-services \
  --cluster infra-puzzler-b2b-qa-puzzler \
  --services infra-puzzler-b2b-qa-jumphost \
  --profile puzzler-pbms \
  --region eu-west-2 \
  --query 'services[*].{name:serviceName,desired:desiredCount,running:runningCount,pending:pendingCount,taskDef:taskDefinition,status:status,events:events[0:8].message}'
```

### QA stopped tasks

```bash
aws ecs list-tasks \
  --cluster infra-puzzler-b2b-qa-puzzler \
  --service-name infra-puzzler-b2b-qa-jumphost \
  --desired-status STOPPED \
  --profile puzzler-pbms \
  --region eu-west-2
```

Potem dla zwróconych task ARN:

```bash
aws ecs describe-tasks \
  --cluster infra-puzzler-b2b-qa-puzzler \
  --tasks <task-arn-1> <task-arn-2> \
  --profile puzzler-pbms \
  --region eu-west-2 \
  --query 'tasks[*].{taskArn:taskArn,lastStatus:lastStatus,stoppedReason:stoppedReason,containers:containers[*].{name:name,lastStatus:lastStatus,reason:reason,exitCode:exitCode,image:image}}'
```

### ECR repositories / image tags

```bash
aws ecr describe-repositories \
  --profile puzzler-pbms \
  --region eu-west-2 \
  --query 'repositories[?contains(repositoryName,`puzzler-b2b-app`)].{name:repositoryName,uri:repositoryUri}'
```

Sprawdzenie tagów dev/QA:

```bash
aws ecr describe-images \
  --repository-name infra-puzzler-b2b-app-dev \
  --profile puzzler-pbms \
  --region eu-west-2 \
  --query 'imageDetails[*].imageTags'

aws ecr describe-images \
  --repository-name infra-puzzler-b2b-app-qa \
  --profile puzzler-pbms \
  --region eu-west-2 \
  --query 'imageDetails[*].imageTags'
```

### ECS Exec do dev jumphosta

VPN / allowlist może być wymagana. Historycznie wskazano `195.117.107.110/32`.

```bash
aws ecs list-tasks \
  --cluster infra-puzzler-b2b-dev-puzzler \
  --service-name infra-puzzler-b2b-dev-jumphost \
  --desired-status RUNNING \
  --profile puzzler-pbms \
  --region eu-west-2

aws ecs execute-command \
  --cluster infra-puzzler-b2b-dev-puzzler \
  --task <task-id> \
  --container infra-puzzler-b2b-dev-jumphost \
  --interactive \
  --command "/bin/bash" \
  --region eu-west-2 \
  --profile puzzler-pbms
```

## Typowy tunel SSH do DocumentDB

Założenie: developer używa klucza ed25519 dodanego do `authorized_keys`.

W troubleshooting zapisano:

```text
Właściwy klucz SSH do jumphostu: ~/.ssh/jumphost_dev
id_rsa / RSA nie działa, bo authorized_keys ma tylko ed25519.
```

Przykładowy tunel:

```bash
ssh -i ~/.ssh/jumphost_dev \
  -N -L 27017:<docdb-endpoint>:27017 \
  <user>@<jumphost-public-ip>
```

Uwaga:
- `<jumphost-public-ip>` może zmieniać się po redeploy.
- `<user>` zależy od konfiguracji obrazu / sshd w Dockerfile.
- Jeśli pojawi się `administratively prohibited`, sprawdź `AllowTcpForwarding`.
- Jeśli pojawi się `Permission denied (publickey)`, sprawdź Secrets Manager `jumphost-ssh` i format klucza publicznego.
- Jeśli pojawi się `invalid format`, sprawdź format prywatnego klucza po stronie developera: CRLF/UTF-16/PowerShell `Set-Content` są częstą przyczyną.

## Najbardziej prawdopodobne zadania następne

1. Potwierdzić, że `puzzler-pbms` działa:

```bash
aws sts get-caller-identity --profile puzzler-pbms
```

2. Zweryfikować aktualny stan `infra-puzzler-b2b-dev-jumphost` i `infra-puzzler-b2b-qa-jumphost`.

3. Sprawdzić, czy QA nadal ma `CannotPullContainerError`.

4. Sprawdzić ECR tagi:
   - czy `infra-puzzler-b2b-app-qa` ma tag `jumphost`, `jumphost-v5`, `jumphost-v10` albo inny tag wskazany przez QA task definition.

5. Sprawdzić lokalne repo przed pracą:

```bash
cd ~/projekty/mako/aws-projects/infra-puzzler-b2b-final
git status --short
git check-ignore -v authorized_keys envs/dev/.env
```

6. Naprawić `.gitignore`, zanim zostanie wykonane jakiekolwiek `git add .`.

7. Jeśli trzeba naprawić QA:
   - zbudować/pushować właściwy obraz do `infra-puzzler-b2b-app-qa`,
   - upewnić się, że QA `terraform.tfvars` / task definition wskazuje istniejący tag,
   - wykonać kontrolowany deploy tylko po prechecku Terraform state i working tree.

## Źródła w vault

- `20-projects/clients/mako/puzzler-b2b/puzzler-b2b-context.md`
- `20-projects/clients/mako/puzzler-b2b/troubleshooting.md`
- `20-projects/clients/mako/puzzler-b2b/context.md`
- `02-active-context/now.md`
- `02-active-context/current-focus.md`

