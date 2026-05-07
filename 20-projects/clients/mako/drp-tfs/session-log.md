---
title: drp-tfs session log
client: mako
project: drp-tfs
document_type: session-log
tags:
  - aws
  - mongodb
  - eks
  - drp-tfs
---

# drp-tfs — session log

## 2026-05-07 — Reprovision + MongoDB RS fix

### Cel
CRITICAL: naprawić MongoDB replica set (REPLICA_SET_GHOST) i haproxy LoadBalancer (EXTERNAL-IP `<pending>`).

### Root causes zidentyfikowane

#### 1. MongoDB REPLICA_SET_GHOST
Oryginalny `60-replset.yml` używał `delegate_to` + `run_once`. Każdy node uruchamia Ansible lokalnie (`-i "localhost," -c local`), więc `delegate_to` próbuje SSH do innego node — blokowane przez SG (port 22 tylko z jumphosta). RS nigdy nie był zainicjowany.

**Fix:** usunięto `delegate_to`, koordynacja przez lokalne zapytania mongod, node 0 wywołuje `rs.initiate()` przez `when: mongo_node_index | int == 0`.

#### 2. 50-discovery.yml — Jinja2 `'\t'` nie jest tabulatorem
`map('split', '\t')` w Jinja2 YAML block scalar (`>-`) nie splituje po prawdziwym tabulatorze — `'\t'` traktowane jest jako literal `\t` (dwa znaki). Shell zwracał output tab-separated, ale Ansible nie potrafił go parsować.

**Fix:** shell wypisuje dane jako `IP|NODE_INDEX` (separator `|`), Jinja2 splituje po `|`.

#### 3. 50-discovery.yml — race condition
Shell AWS CLI query nie czekał na dostępność wszystkich 3 node'ów w EC2 API. Przy starcie wszystkich instancji równolegle, query mogło zwrócić tylko 1-2 node'y.

**Fix:** shell retry loop (max 60 prób × 10s = 600s) z warunkiem `COUNT >= 3`.

#### 4. haproxy LoadBalancer `<pending>`
a) Mixed TCP+UDP protocol: service miał port 443/TCP i 443/UDP (QUIC). K8s cloud controller nie obsługuje mixed protocol dla jednego LoadBalancera.
b) Stary ALB wisiał w AWS po poprzednim środowisku — blokował EIP allocations.

**Fix:** `--set controller.service.enablePorts.quic=false` w helm upgrade. Po ręcznym usunięciu starego ALB przez usera — NLB dostał hostname.

### Zmiany w plikach

- `modules/mongo-ec2/playbook/roles/mongo/tasks/50-discovery.yml` — pipe-separator, retry loop, sort w shell
- `modules/mongo-ec2/playbook/roles/mongo/tasks/60-replset.yml` — usunięto delegate_to, koordynacja lokalna
- `modules/mongo-ec2/playbook/roles/mongo/tasks/70-restore.yml` — PRIMARY check przez `db.hello().isWritablePrimary`
- `modules/mongo-ec2/ansible-mongo.tar` — przebudowany, upload do `s3://613448424242-db-dump/mongodb/ansible-mongo.tar`

### Wykonane komendy

```bash
make destroy NAMESPACE=tfs-prod RELEASE=haproxy-kubernetes-ingress
make apply
make app
make nlb
make redis
# Ręcznie: 3x re-run bootstrap na mongo nodeach przez jumphost
helm upgrade haproxy-kubernetes-ingress haproxytech/kubernetes-ingress \
  --values=values.yaml --namespace tfs-prod \
  --set "controller.service.enablePorts.quic=false" ...
```

### Stan po naprawie (2026-05-07 ~19:50)

```
MongoDB replica set:
  0 mongo-0.drp-tfs.drp.internal:27017 PRIMARY
  1 mongo-1.drp-tfs.drp.internal:27017 SECONDARY
  2 mongo-2.drp-tfs.drp.internal:27017 SECONDARY

haproxy LoadBalancer:
  a6293990bdab242b191283f7b757315e-286074f3d72658d6.elb.eu-central-1.amazonaws.com
  Porty: 80/TCP, 443/TCP, 1024/TCP, 6060/TCP

Pody tfs-prod: wszystkie 1/1 Running
  - leasing-filters-api: 2/2 (16 restartów przed naprawą, teraz stabilne)
  - leasing-filters-core: 2/2
```

### Persistence audit (2026-05-07 ~20:30)

Wynik: wszystkie fixy commitnięte w `df1acd1`.

Kluczowe ustalenia:
- `playbook/ansible-mongo.tar` był budowany z self-reference (zawierał starą wersję siebie) → przebudowano z `--exclude='./ansible-mongo.tar'`
- `values.yaml enablePorts.quic: false` wystarczy — `install.sh` używa `--values=values.yaml`, Helm respektuje
- S3 bucket pre-exists (nie jest zarządzany przez Terraform) → plik trwa przez destroy/apply
- `helm-tfs-drp/install.sh` NIE aktualizuje kubeconfig → wymagany manual step przed `make app`

Pre-requisite po `make apply` przed `make app`:
```bash
AWS_PROFILE=drp-tfs aws eks update-kubeconfig --name drp-tfs-eks-cluster --region eu-central-1
```

### Do zrobienia

- [ ] dodać `aws eks update-kubeconfig` do `helm-tfs-drp/install.sh` (make app bez manual step)
- [ ] `make destroy` wymaga `NAMESPACE=tfs-prod RELEASE=haproxy-kubernetes-ingress` — brak domyślnych wartości
- [ ] Sprawdzić czy backup restore się powiódł (dane z S3 przywrócone przez `mongorestore --drop`)
- [ ] Powtórzyć cloud-detective live check po naprawie
- [ ] Sprawdzić leasing-filters-api i core-service działanie funkcjonalne (nie tylko Running)

### Środowisko

- AWS profile: `drp-tfs`
- Account: 613448424242
- Region: eu-central-1
- EKS: `drp-tfs-eks-cluster` (v1.30)
- Mongo IPs: 172.35.0.86 (0/PRIMARY), 172.35.0.153 (1), 172.35.0.32 (2)
- Jumphost: 3.121.206.54 (ubuntu), klucz: `~/.ssh/drp_key.pem`
  - do mongo nodes: ubuntu@mongo-N.drp-tfs.drp.internal z `/tmp/drp_key.pem`
