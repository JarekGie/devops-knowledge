---
domain: cloudops
project: rshop
environment: dev
classification: incident-note
tags:
  - rshop
  - aws
  - cloudformation
  - ecs
  - incident
  - cfn-mut-001
created: 2026-04-29
status: evidence-collected
---

# rshop DEV — ECSStack rollback after app-only Jenkins deploy — 2026-04-29

## Executive Summary

Nocny DEV deploy po zmianie Jenkinsfile nie odtworzyl problemu `CFN-MUT-001`.

Root stack `dev` nie zostal dotkniety przez nocny deploy. Nie pojawily sie nowe zdarzenia dla `VPCStack` ani `SiecDB`.

Awaria byla ograniczona do `dev-ECSStack-1BLAWHL0P6JKO`: `api` i `backoffice` nie ustabilizowaly sie w czasie, CloudFormation uruchomil rollback i zakonczyl go poprawnie do `UPDATE_ROLLBACK_COMPLETE`.

## Evidence

### CloudFormation root stack

Root stack:

```text
Stack:   dev
Status:  UPDATE_ROLLBACK_COMPLETE
Updated: 2026-04-28T16:41:09.792000+00:00
```

Ostatnie zdarzenia root stack pochodza z recovery CFN-MUT-001, nie z nocnego deployu.

Nested stack mapping root stack:

```text
CFStack        UPDATE_COMPLETE
DBStack        UPDATE_COMPLETE
ECSStack       UPDATE_COMPLETE
EndPiontsStack UPDATE_COMPLETE
IAMStack       UPDATE_COMPLETE
S3Stack        UPDATE_COMPLETE
SGStack        UPDATE_COMPLETE
VPCStack       UPDATE_COMPLETE
```

Wniosek: app deploy nie wszedl przez root `dev`.

### CloudFormation ECSStack

Target stack:

```text
Stack:   dev-ECSStack-1BLAWHL0P6JKO
Status:  UPDATE_ROLLBACK_COMPLETE
Updated: 2026-04-28T21:46:07.331000+00:00
```

Kluczowe zdarzenia:

```text
2026-04-28T21:46:07Z ECSStack UPDATE_IN_PROGRESS User Initiated
2026-04-29T00:46:22Z ECSStack UPDATE_ROLLBACK_IN_PROGRESS The following resource(s) failed to update: [api, backoffice]
2026-04-29T00:54:05Z ECSStack UPDATE_ROLLBACK_COMPLETE
```

Child stack `api`:

```text
2026-04-29T00:46:00Z ApiSvc UPDATE_FAILED
Resource handler returned message: "Exceeded attempts to wait"
HandlerErrorCode: NotStabilized
```

Child stack `backoffice`:

```text
2026-04-29T00:46:00Z BackofficeSvc UPDATE_FAILED
Resource handler returned message: "Exceeded attempts to wait"
HandlerErrorCode: NotStabilized
```

## ECS runtime state after rollback

Current services:

```text
rshop-dev-api-svc
  desired=1 running=1 pending=0
  task definition=dev-api-task:1040
  image=943111679945.dkr.ecr.eu-central-1.amazonaws.com/rshopapp-dev:api.1252
  rollout=COMPLETED

rshop-dev-backoffice-svc
  desired=1 running=1 pending=0
  task definition=dev-backoffice-task:1039
  image=943111679945.dkr.ecr.eu-central-1.amazonaws.com/rshopapp-dev:backoffice.1252
  rollout=COMPLETED

rshop-dev-frontend-svc1
  desired=1 running=1 pending=0
  task definition=dev-frontend-task:1892
  rollout=COMPLETED

rshop-dev-frontend-svc2
  desired=1 running=1 pending=0
  task definition=dev-frontend-task:1893
  rollout=COMPLETED
```

Target health:

```text
API        10.0.1.103:8080 healthy
Backoffice 10.0.1.202:8080 healthy
```

## Rollout failure signals

ECS service events during rollback window:

```text
API:
  target became unhealthy due to ALB health checks failed with codes [500]
  repeated start/register/unhealthy/stop cycles before rollback completion

Backoffice:
  repeated task replacement and target registration/draining events
  current running service is healthy after rollback
```

`aws ecs list-tasks --desired-status STOPPED` returned no current stopped task ARNs during the later read-only check, so stopped-task container exit details were not available from ECS at that point.

## Classification

| Question | Answer | Evidence |
|---|---|---|
| Jenkins-only failure? | No | CloudFormation ECSStack update was executed |
| CloudFormation temporary failure then rollback? | Yes | ECSStack reached `UPDATE_ROLLBACK_COMPLETE` |
| ECS/application rollout failure? | Yes | `ApiSvc` and `BackofficeSvc` `NotStabilized` |
| Guard failure? | Not proven | No current Jenkins console log available |
| AWS CLI / Jenkins sandbox issue? | No evidence | Failure reached AWS control plane |
| Root stack touched? | No | Root `dev` last update earlier than overnight ECSStack deploy |
| VPCStack / SiecDB appeared? | No | No new root/VPC failure path in events |

## Operational Conclusion

Jenkins mitigation for CFN-MUT-001 appears to have worked at the deployment-boundary level: DEV app deploy targeted `dev-ECSStack-1BLAWHL0P6JKO`, not root `dev`.

The failed deploy should be treated as ECS/app stabilization failure, not as recurrence of mutable nested `TemplateURL` VPC mutation.

## Recommendations

1. Do not rerun blindly until application logs for the failed image revision are checked.
2. Investigate API healthcheck HTTP 500 during the rollout window.
3. Investigate backoffice startup/runtime behavior for the attempted image revision.
4. Keep root stack `dev` out of app deploy path.
5. Keep permanent remediation open: immutable nested `TemplateURL` pinning / immutable artifact paths.
6. If Jenkins console log is needed for CAB evidence, retrieve the exact failed build log from Jenkins; it was not present locally during this vault update.

## Related

- [[../aws/cloudformation-nested-template-mutability-hazard]]
- [[../../02-active-context/now]]
- [[../../02-active-context/current-focus]]
