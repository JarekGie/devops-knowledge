---
date: 2026-04-28
pattern_id: CFN-MUT-001
domain: operational-runbook
classification: internal
tags: [aws, cloudformation, nested-stacks, runbook-pattern, cfn-mutability, ai-finops-lite]
source_of_truth: vault
---

# CloudFormation Nested Template Mutability Hazard — Runbook Pattern

## 1. Executive Summary

**Pattern:** `AWS::CloudFormation::Stack` z `TemplateURL` wskazującym na mutowalny obiekt S3 może przy update root stacka pobrać nowszą treść nested template, nawet jeśli deploy miał dotyczyć wyłącznie aplikacji.

Skutek:
- root stack update uruchamia re-ewaluację nested stacków
- CloudFormation pobiera aktualny obiekt spod `TemplateURL`
- nowszy nested template może zawierać ukryte zmiany infra
- change set wygląda jak rutynowy `Modify` nested stacka
- resource-level update pojawia się dopiero w child stacku
- deployment może failować na pozornie niezwiązanym zasobie

Odkryty przykład:

```text
app-only rshop dev deploy
-> root stack update
-> VPCStack reevaluated
-> newer vpc-dev.yml pulled from S3
-> tag changes on SiecDB detected
-> CloudFormation attempted ModifyDBSubnetGroup
-> deployment failed due missing IAM permission
```

To nie jest klasyczny drift. Live stack może być `IN_SYNC`, a mimo to root update może wciągnąć nową wersję nested template z mutowalnego URL.

---

## 2. Symptoms

Rozpoznawalne objawy:
- app-only deploy niespodziewanie modyfikuje infra nested stacks
- change set pokazuje `Modify` na nested stacku, ale bez oczywistego replacementu
- `UPDATE_FAILED` pojawia się na zasobie niezwiązanym z aplikacją: `DBSubnetGroup`, RabbitMQ, Redis, ALB, Listener, RouteTable, SecurityGroup
- root deploy dotyka wiele nested stacków naraz
- błędy wyglądają losowo, ale korelują z podmienianymi nested templates w S3
- brakujące IAM permission wygląda jak root cause, ale jest tylko pierwszym resource-level blockerem

| Symptom | Co sprawdzić | Typowy sygnał |
|---------|--------------|---------------|
| App deploy dotyka VPC/DB/MQ | root `describe-stack-events` | kilka nested stacków `UPDATE_IN_PROGRESS` |
| Nested stack `Modify` bez replacementu | `describe-change-set` | `ResourceChange.Action=Modify`, `Replacement=False` |
| Failure na niezwiązanym zasobie | child `describe-stack-events` | `UPDATE_FAILED` na leaf resource |
| Drift check nic nie pokazuje | `detect-stack-drift` | `IN_SYNC`, ale update dalej próbuje zmienić resource |
| Zmiana pojawia się po czasie | S3 object versions | nowszy `TemplateURL` object niż ostatni świadomy infra deploy |

---

## 3. Root Cause Pattern

Mechanizm:

1. Root stack ma nested stack z mutowalnym `TemplateURL`.
2. `TemplateURL` wskazuje na stały klucz S3, np. `dev/vpc-dev.yml`.
3. Pipeline publikuje nową wersję pliku pod tym samym kluczem.
4. Późniejszy root stack update, nawet app-only, re-ewaluuje nested stack.
5. CloudFormation pobiera aktualną treść obiektu S3.
6. Jeśli nowy nested template ma zmiany resource-level, child stack próbuje je wykonać.

### Mutable TemplateURL hazard vs true drift

| Cecha | Mutable TemplateURL hazard | True CloudFormation drift |
|-------|----------------------------|---------------------------|
| Źródło różnicy | zmienił się template pod tym samym URL | live resource zmienił się poza CFN |
| Drift detection | może być `IN_SYNC` | zwykle pokazuje `MODIFIED`, `DELETED`, `NOT_CHECKED` |
| Trigger | root/nested update | wykrycie przez drift detection lub kolejny update |
| Dowód | S3 object version history / diff template versions | `describe-stack-resource-drifts` |
| Fix architektoniczny | version pin / immutable artifacts | reconciliacja live vs template |

Hazard jest szczególnie podstępny, bo wygląda jak drift-like behavior, ale formalnie driftu nie ma. CloudFormation wykonuje nowy template, którego operator nie traktował jako część bieżącego app deployu.

---

## 4. Case Study — rshop dev

Zakres:
- root stack: `dev`
- nested stack: `dev-VPCStack-FFQTYHECIX9M`
- region: `eu-central-1`
- account: `943111679945`
- deployment type: app-only

Timeline:

| Timestamp UTC | Event | Evidence |
|---------------|-------|----------|
| `2026-04-28T09:04:31.191Z` | root `dev` update started | `UPDATE_IN_PROGRESS User Initiated` |
| `2026-04-28T09:04:33Z` | `VPCStack`, `ECSStack`, `IAMStack`, `S3Stack` started update | root stack events |
| `2026-04-28T09:04:41.398Z` | `SiecDB` update started | child VPCStack events |
| `2026-04-28T09:04:42.267Z` | first real failure | `SiecDB UPDATE_FAILED` |
| `2026-04-28T09:05:30.268Z` | root rollback failed | root `UPDATE_ROLLBACK_FAILED` |

First real failure:

```text
Timestamp: 2026-04-28T09:04:42.267000+00:00
Stack: dev-VPCStack-FFQTYHECIX9M
Logical resource: SiecDB
Resource type: AWS::RDS::DBSubnetGroup
Action attempted: rds:ModifyDBSubnetGroup
```

Exact error:

```text
User: arn:aws:iam::943111679945:user/jenkinsit is not authorized to perform:
rds:ModifyDBSubnetGroup on resource:
arn:aws:rds:eu-central-1:943111679945:subgrp:dev-vpcstack-ffqtyhecix9m-siecdb-fspddhruuczb
because no identity-based policy allows the rds:ModifyDBSubnetGroup action
```

Drift check:

```text
StackDriftStatus: IN_SYNC
DriftedStackResourceCount: 0
SiecDB PropertyDifferences: []
```

Evidence pointing to template mutation:
- root `VPCStack` passes only `Projekt` and `Srodowisko`
- ALB/TG parameters do not cascade into `VPCStack`
- `VPCStack.TemplateURL` points to `https://rshop-cf.s3.eu-central-1.amazonaws.com/dev/vpc-dev.yml`
- S3 object `dev/vpc-dev.yml` had newer versions after original stack creation
- diff between older and newer `vpc-dev.yml` showed tag additions:
  - `Project`
  - `Environment`
  - `Owner`
  - `ManagedBy`
  - `CostCenter`
- these tags were added to `SiecDB` and multiple VPC resources

Conclusion:

```text
App deploy did not intentionally change SiecDB.
Root update replayed a newer mutable nested VPC template.
CloudFormation attempted to apply tag-related template delta to DBSubnetGroup.
IAM AccessDenied stopped the mutation.
```

---

## 5. Why IAM Was Not Root Cause

`AccessDenied: rds:ModifyDBSubnetGroup` był pierwszym twardym błędem, ale nie architektoniczną przyczyną incydentu.

Dlaczego:
- deployment miał być app-only
- `SiecDB` nie powinien być w scope aplikacyjnego deployu
- brak uprawnienia ujawnił nieoczekiwaną próbę mutacji infra
- dodanie `rds:ModifyDBSubnetGroup` pozwoliłoby CloudFormation kontynuować ukrytą zmianę
- bez wyjaśnienia przyczyny można nieświadomie dopuścić kolejne mutacje VPC/DB/MQ/Redis/ALB

Zasada operacyjna:

> Brakujące IAM permission w rollback/update jest blockerem wykonania, ale nie dowodem, że mutacja była zamierzona.

Przed dodaniem permission:
1. udowodnij, że resource-level mutation jest oczekiwana
2. sprawdź, czy nested template jest version pinned
3. porównaj template history z aktualnym change setem
4. oceń blast radius

---

## 6. Detection Runbook (Read Only)

Cel: ustalić, czy failure wynika z mutowalnego nested template, driftu, parametrów, czy realnej app zmiany.

### 6.1 Root change set

```bash
aws cloudformation describe-change-set \
  --stack-name <root-stack> \
  --change-set-name <change-set-name> \
  --region <region> \
  --profile <profile> \
  --output json
```

Sprawdź:
- które nested stacki mają `Action=Modify`
- `Replacement`
- `ResourceChange.Details`
- `Target.Name`
- czy `CausingEntity` wskazuje na `TemplateURL`, `Parameters`, `Tags`, `Properties`

Jeśli change set już nie istnieje, przejdź do eventów, S3 version history i drift.

### 6.2 Root nested stack mapping

```bash
aws cloudformation list-stack-resources \
  --stack-name <root-stack> \
  --region <region> \
  --profile <profile> \
  --query "StackResourceSummaries[?ResourceType=='AWS::CloudFormation::Stack'].[LogicalResourceId,PhysicalResourceId,ResourceStatus]" \
  --output table
```

Sprawdź:
- które nested stacki faktycznie weszły w `UPDATE_*`
- physical ARN child stacka
- czy status failed jest root cause czy `Resource update cancelled`

### 6.3 Root template

```bash
aws cloudformation get-template \
  --stack-name <root-stack> \
  --region <region> \
  --profile <profile>
```

Sprawdź:
- `TemplateURL` każdego nested stacka
- czy URL jest mutowalny
- jakie parametry są przekazywane do child stacka
- czy app parameters trafiają do infra stacków

### 6.4 Nested template

```bash
aws cloudformation get-template \
  --stack-name <nested-stack-name-or-arn> \
  --region <region> \
  --profile <profile>
```

Sprawdź:
- definicję leaf resource, który failed
- `Tags`
- `SubnetIds`
- engine/version/type parameters
- czy resource ma custom name
- czy property update wymaga replacement lub modify API

### 6.5 Drift detection

```bash
aws cloudformation detect-stack-drift \
  --stack-name <nested-stack-name-or-arn> \
  --region <region> \
  --profile <profile>
```

Po otrzymaniu detection ID:

```bash
aws cloudformation describe-stack-drift-detection-status \
  --stack-drift-detection-id <drift-detection-id> \
  --region <region> \
  --profile <profile>
```

Następnie:

```bash
aws cloudformation describe-stack-resource-drifts \
  --stack-name <nested-stack-name-or-arn> \
  --region <region> \
  --profile <profile> \
  --output json
```

Interpretacja:
- `IN_SYNC` nie wyklucza mutable TemplateURL hazard
- `PropertyDifferences=[]` przy failed update wskazuje, że problem nie musi być live drift
- jeśli drift jest realny, rozdziel drift remediation od app deployu

### 6.6 S3 template history

```bash
aws s3api head-object \
  --bucket <template-bucket> \
  --key <template-key> \
  --region <region> \
  --profile <profile>
```

```bash
aws s3api list-object-versions \
  --bucket <template-bucket> \
  --prefix <template-key> \
  --region <region> \
  --profile <profile>
```

Sprawdź:
- `LastModified`
- `VersionId`
- czy plik był zmieniany po ostatnim świadomym infra deployu
- diff między wersją historyczną i latest
- czy latest template dodaje tagi lub properties do failed resource

---

## 7. Preventive Controls

| Control | Description | Pros | Cons |
|---------|-------------|------|------|
| A. Version pin nested `TemplateURL` using S3 `versionId` | Root stack wskazuje konkretną wersję obiektu S3 | pełna powtarzalność; root update nie pobierze przypadkowego template | wymaga obsługi versionId w pipeline; trudniejsze ręczne operacje |
| B. Immutable artifact paths per release | Każdy release publikuje template pod unikalną ścieżką, np. `releases/<build>/vpc.yml` | proste diffy; czytelna historia; brak zależności od S3 versioning | wymaga zarządzania retencją artefaktów |
| C. Separate infra deploy pipeline from app deploy pipeline | App deploy nie aktualizuje root infra stacka | zmniejsza blast radius; jasny ownership zmian | wymaga refaktoru pipeline; czasem trudne przy legacy root stackach |
| D. Avoid app deploys through root stack when possible | App image/tag update idzie przez ECS child stack lub ECS deployment path | mniej nested stack replay; szybsze deploye | może wymagać zmiany procesu i uprawnień |
| E. Review tag rollouts as dedicated change sets | Tag changes są osobnym change setem z pełnym review | tagi nie ukrywają się w app deployu; łatwiejszy rollback plan | więcej kroków operacyjnych |

Minimalny standard dla nowych stacków:

```text
No mutable nested TemplateURL in production pipelines.
No app-only deploy through root stack unless nested stack deltas are reviewed.
No tag rollout mixed with image deploy.
```

---

## 8. Failure Modes This Pattern Can Masquerade As

Mutable nested template hazard może wyglądać jak zupełnie inny problem, bo pierwszym leaf failure jest zasób, który akurat nie może przyjąć nowej właściwości.

| Pozorny problem | Dlaczego może być maską tego patternu |
|-----------------|----------------------------------------|
| RabbitMQ custom resource issue | nowszy nested MQ template zmienia engine/version/tags; root app deploy tylko go replayuje |
| Redis engine issue | latest Redis/ElastiCache template ma zmianę wersji lub tagów; app deploy aktywuje update |
| ALB/listener tagging issue | tag rollout w ALB nested stack pojawia się podczas niepowiązanego deployu |
| DBSubnetGroup/RDS permission issue | nowe tagi/subnet group properties wymagają modify API |
| SecurityGroup rollback failed | nowszy SG template zmienia reguły; CI nie ma revoke/authorize permissions |
| Random nested stack instability | każdy root deploy re-evaluuje inną aktualną wersję nested template |

Wspólny mianownik:
- root update formalnie dotyka nested stacków
- nested `TemplateURL` nie jest immutable
- leaf failure zależy od tego, jaki zasób pierwszy nie przyjmie ukrytej zmiany

---

## 9. Go / No-Go Checklist Before Retry

Przed dodaniem brakujących IAM permissions lub retry:

| Check | GO | NO-GO |
|-------|----|-------|
| Czy mutacja resource była zamierzona? | change set/evidence potwierdza scope | resource nie należy do app deployu |
| Czy nested template jest pinned? | `versionId` albo immutable artifact path | stały S3 key typu `dev/vpc-dev.yml` |
| Czy to hidden template replay? | S3 latest różni się od starej wersji | brak template delta |
| Czy permission maskuje problem architektoniczny? | permission potrzebne do zatwierdzonej zmiany | permission tylko pozwoli ukrytej zmianie przejść |
| Czy drift jest realny? | `PropertyDifferences` pokazują drift | drift `IN_SYNC` |
| Czy tag rollout jest osobnym change setem? | tak, review wykonane | tagi jadą razem z app deployem |

Operator decision:

```text
NO-GO: retry app deploy przez root stack, jeśli nested infra mutation nie jest wyjaśniona.
NO-GO: dodanie IAM tylko po to, żeby przejść dalej.
GO: retry dopiero po eliminacji hidden VPCStack mutation albo po jawnym zatwierdzeniu infra rollout.
```

---

## 10. Lessons Learned

1. `TemplateURL` jest częścią release boundary. Jeśli URL jest mutowalny, release boundary nie istnieje.
2. App deploy przez root stack może być infra deployem, nawet jeśli operator zmienia tylko image tag.
3. `AccessDenied` często jest symptomem hidden mutation, nie root cause.
4. Drift detection `IN_SYNC` nie wyklucza template replay.
5. Tag rollout w CloudFormation nie jest neutralny. Może uruchomić `Modify*` API dla zasobów stanowych.
6. Nested stack `Modify` bez replacementu nadal może mieć realny resource-level blast radius.
7. Immutable artifacts są tańsze niż forensic po `UPDATE_ROLLBACK_FAILED`.

---

## Appendix A — TemplateURL Anti-Pattern And Preferred Patterns

### Anti-pattern

```yaml
VPCStack:
  Type: AWS::CloudFormation::Stack
  Properties:
    TemplateURL: https://rshop-cf.s3.eu-central-1.amazonaws.com/dev/vpc-dev.yml
```

Problem:
- stały S3 key
- latest object może się zmienić między deployami
- root stack update może pobrać nieoczekiwaną treść

### Preferred pattern: S3 versionId

```yaml
VPCStack:
  Type: AWS::CloudFormation::Stack
  Properties:
    TemplateURL: https://rshop-cf.s3.eu-central-1.amazonaws.com/dev/vpc-dev.yml?versionId=<S3_VERSION_ID>
```

Uwaga:
- pipeline musi zarządzać `VersionId`
- review musi pokazywać zmianę versionId jako świadomą zmianę template

### Preferred pattern: immutable artifact path

```yaml
VPCStack:
  Type: AWS::CloudFormation::Stack
  Properties:
    TemplateURL: https://rshop-cf.s3.eu-central-1.amazonaws.com/releases/2026-04-28-1253/vpc-dev.yml
```

Lub:

```yaml
VPCStack:
  Type: AWS::CloudFormation::Stack
  Properties:
    TemplateURL: https://rshop-cf.s3.eu-central-1.amazonaws.com/releases/<git-sha>/vpc-dev.yml
```

Zalety:
- artifact path sam dokumentuje release
- łatwiejszy rollback do poprzedniego artifactu
- diff release-to-release jest jawny

---

## Appendix B — Pattern Name

```text
CFN-MUT-001 Nested Template Mutability Hazard
```

Sugestia:
- trackować podobne incydenty pod `CFN-MUT-001`
- w postmortemach rozróżniać:
  - `CFN-MUT-001` — mutable nested template replay
  - true drift
  - IAM baseline gap
  - resource-specific update failure

Minimalny wpis w incident log:

```text
Pattern: CFN-MUT-001
Trigger: root stack update
Mutable TemplateURL: <url>
Hidden template delta: <property/resource>
First real failure: <timestamp/resource/action>
Decision: pin template / split pipeline / approve infra rollout
```
