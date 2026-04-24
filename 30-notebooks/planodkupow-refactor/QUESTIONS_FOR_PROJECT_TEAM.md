---
date: 2026-04-24
project: planodkupow
tags: [meeting, ownership, dependencies, refactor]
domain: notebooks
---

# Questions For Project Team

Checklistę poniżej należy traktować jako materiał na spotkanie discovery/decision, nie jako listę pytań zamykających temat cleanupu.

## A. Ownership

- Kto jest formalnym ownerem starej QA VPC `vpc-02f804baee8a3f048`?
- Kto jest ownerem NAT `nat-08adf3e0a226779a7`?
- Czy NAT ma znane, udokumentowane użycie operacyjne?
- Czy istnieją ręczne workloady poza CloudFormation i poza znanym ECS?
- Kto utrzymuje QA broker `planodkupow-qa-rabbitmq-cheap`?
- Czy QA broker outside active root stack jest stanem docelowym, czy przejściowym?
- Kto jest ownerem retained security groups po starszym QA lineage?

## B. Dependencies

- Czy legacy endpoints obsługują batch, integracje lub manual tooling?
- Czy istnieją prywatne routy zależne od NAT poza tym, co widać dla ECS?
- Czy istnieją consumers AMQ poza znanym ECS?
- Czy są jakieś zewnętrzne systemy lub skrypty korzystające ze starej QA VPC?
- Czy istnieją manual hosts / tools / batch korzystające z tej starej sieci?
- Czy istnieją zależności legacy, które nie są reprezentowane w bieżącym IaC?

## C. Refactor

- Czy RabbitMQ wyjmujemy poza root lifecycle w sposób formalny i trwały?
- Czy legacy QA VPC powinna być formalnie uznana za `decommission candidate`, czy na razie tylko `investigation candidate`?
- Czy endpoint strategy powinna przejść na nową QA VPC?
- Czy chcemy docelowo jeden spójny model ownership dla QA network, RabbitMQ i endpointów?
- Czy przyszły refactor ma obejmować wyłącznie ownership cleanup, czy także uproszczenie topologii sieci?

## D. Governance / FinOps

- Czy 5-tag baseline obowiązuje także legacy retained assets?
- Co jest w scope przyszłej Tag Policy?
- Czy legacy residual assets mają być raportowane oddzielnie od aktywnego runtime?
- Czy `orphan suspect` assets mają być wyłączone z aktywnych compliance blockerów do czasu walidacji?
- Jak projekt chce klasyfikować zasoby „poza aktywnym root lifecycle, ale nadal używane”?

## Desired outcome of meeting

Na końcu spotkania dobrze byłoby uzyskać odpowiedzi na trzy pytania:
- co jest aktywną zależnością,
- co jest tylko legacy residual artifact,
- co wymaga osobnego assessment przed jakąkolwiek decyzją refactor / cleanup.
