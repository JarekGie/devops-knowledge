---
date: 2026-04-24
project: planodkupow
tags: [hypotheses, risks, architecture]
domain: notebooks
---

# Hypotheses And Risks

Ostrzeżenie bazowe:

**Do not treat orphan suspicion as deletion evidence.**

## Likely true

- Nowa QA VPC jest obecnym aktywnym runtime dla QA.
- Stara QA VPC należy do starszego lineage po stacku dziś `DELETE_COMPLETE`.
- NAT i 4 standardowe endpointy są powiązane ze starszą QA VPC, a nie z aktualnym QA runtime.
- AMQ PrivateLink endpoints są aktywnymi zależnościami, nie residual artifacts.
- Obecny obraz ownership jest niespójny między aktywnym QA root stackiem a QA brokerem `rabbitmq-cheap`.

## Uncertain

- Czy NAT nadal obsługuje jakiś ruch spoza ECS.
- Czy legacy endpoints są jeszcze wykorzystywane przez batch, tooling albo integracje ręczne.
- Czy retained security groups mają aktywne referencje poza oczywistymi zależnościami.
- Czy QA RabbitMQ outside active root stack jest świadomą decyzją architektoniczną, czy pozostałością po awaryjnym obejściu.

## High-risk assumptions

- Założenie, że brak usage przez ECS oznacza pełny brak usage.
- Założenie, że `DELETE_COMPLETE` lineage oznacza brak wszystkich zależności runtime.
- Założenie, że stare endpointy są bezpieczne do wycofania, bo istnieje nowa QA VPC.
- Założenie, że brak datapoints dla NAT metrics oznacza zero traffic.
- Założenie, że aktywne zależności Amazon MQ są w pełni odzwierciedlone w aktualnym root stack lifecycle.

## Operating stance

Do czasu walidacji z projektem:
- hipotezy traktować jako materiał analityczny
- nie traktować ich jako podstawy do cleanupu
- nie mieszać klasyfikacji „legacy”, „active dependency” i „orphan suspect”
