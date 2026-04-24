---
date: 2026-04-24
project: planodkupow
tags: [meeting, brief, architecture, operations]
domain: notebooks
---

# Meeting Brief

## Co wiemy

- są dwie QA VPC o tym samym `Name`
- nowa QA VPC obsługuje aktywny QA runtime: ECS, ALB, RDS, broker
- stara QA VPC zawiera NAT i 4 standardowe endpointy
- aktywne QA ECS tasks nie siedzą w starej QA VPC
- dwa AMQ PrivateLink endpoints są aktywnymi zależnościami
- QA broker `rabbitmq-cheap` jest aktywny, ale jego ownership nie jest czytelny z perspektywy aktywnego root stacku

## Czego nie wiemy

- czy NAT jest wykorzystywany przez manual tooling, batch albo integracje poza ECS
- czy stare endpointy obsługują jakiekolwiek nieudokumentowane zależności
- kto jest formalnym ownerem QA broker outside active root lifecycle
- czy legacy QA VPC ma jakiekolwiek ukryte zależności poza tym, co wykryto read-only

## Czego NIE proponujemy robić

- nie proponujemy cleanupu starej QA VPC
- nie proponujemy usuwania NAT
- nie proponujemy usuwania legacy endpoints
- nie proponujemy usuwania retained security groups
- nie proponujemy żadnej mutacji przed walidacją z projektem

## Decyzje potrzebne od projektu

- potwierdzenie ownership starej QA VPC i jej artefaktów
- potwierdzenie ownership QA broker `rabbitmq-cheap`
- potwierdzenie, czy istnieją manual workloads/dependencies poza IaC
- decyzja, czy temat traktujemy jako:
  - preserve and document,
  - migrate then retire,
  - broader network refactor

## Ważny framing na spotkanie

To nie jest rozmowa o „co usuwamy”.
To jest rozmowa o:
- ownership
- evidence
- hidden dependencies
- bezpiecznej ścieżce do przyszłego refactoru
