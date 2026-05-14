# Maspex Load Test — observability pipeline (k6 / InfluxDB / Grafana)

## Architektura

```
EC2 generator (i-0402c9e70c6a86ae3 lub i-0de0bd5e3752d3283)
└── Docker Compose: /home/ec2-user/qa/docker-compose.yml
    ├── influxdb:1.8  :8086  (baza k6, named volume qa_influxdb-data)
    └── grafana/grafana :3000 (dashboard k6, named volume qa_grafana-data)

k6 → K6_OUT=influxdb=http://localhost:8086/k6 → InfluxDB → Grafana :3000
```

Każda instancja ma własny stos (brak shared InfluxDB między generatorami).

## Uruchamianie k6 z telemetrią

```bash
# przez SSH (loadtest-ctrl.sh --ssh lub bezpośrednio)
cd /home/ec2-user/qa

# Uruchomienie z outputem do InfluxDB
K6_OUT=influxdb=http://localhost:8086/k6 k6 run scripts/kapsel.js

# Z custom tagiem scenariusza
K6_OUT=influxdb=http://localhost:8086/k6 k6 run \
  --tag testid=kapsel-spike-20260514 \
  scripts/kapsel-spike.js

# Dostępne skrypty w scripts/:
# kapsel.js            — główny scenariusz (UAT)
# kapsel-clean.js      — wersja bez statycznych assetów
# kapsel-spike.js      — ramp-up spike
# kapsel-submit.js     — tylko submit zgłoszeń
# kapsel-vote.js       — tylko głosowanie
# kapsel-main-page.js  — tylko strona główna
# kapsel-with-fe.js    — pełny scenariusz z frontendem
```

## Grafana — dostęp

Port 3000 otwarty tylko wewnętrznie (security group blokuje inbound z internetu).
Dostęp przez SSH tunnel:

```bash
# Na lokalnym komputerze (po połączeniu SSH na instancję lub przez SSM port forwarding)
ssh -L 3000:localhost:3000 ec2-user@<PUBLIC_IP>
# Następnie: http://localhost:3000
# Login: anonymous (Admin, bez hasła)

# Lub przez SSM port forwarding (bez SSH key):
aws ssm start-session \
  --target i-0402c9e70c6a86ae3 \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["3000"],"localPortNumber":["3000"]}' \
  --region eu-west-1 --profile maspex-cli
```

Dashboard: **k6 Load Testing Results By Groups** — automatycznie prowizjonowany.

## Zarządzanie stosem Docker

```bash
# Start (jeśli zatrzymany)
cd /home/ec2-user/qa && docker compose up -d

# Status
docker compose ps

# Logi
docker compose logs --tail 50 influxdb
docker compose logs --tail 50 grafana

# Restart po zmianie konfiguracji
docker compose down && docker compose up -d

# Weryfikacja bazy k6
docker exec qa-influxdb-1 influx -execute "SHOW DATABASES"
docker exec qa-influxdb-1 influx -database k6 -execute "SHOW MEASUREMENTS"
```

## Pliki konfiguracyjne (w repo infra-maspex, branch feat/prod-parity-uat)

```
scripts/loadtest/
  docker-compose.yml
  grafana/
    provisioning/
      datasources/influxdb.yaml   # datasource UID: dfm0hl1zdovswd
      dashboards/default.yaml     # provider: /etc/grafana/dashboards
    dashboards/
      k6-load-testing-by-groups.json  # Grafana Labs ID 13719
```

## Setup na nowej instancji

```bash
# 1. Skopiuj pliki z repo (lub skopiuj ręcznie)
mkdir -p /home/ec2-user/qa
cd /home/ec2-user/qa

# 2. Utwórz strukturę katalogów i pobierz pliki z repo
# (po wdrożeniu user_data z repo — do dodania do loadtest.tf)

# 3. Start stosu
docker compose up -d

# 4. Weryfikacja
docker exec $(docker ps -qf name=influxdb) influx -execute "SHOW DATABASES"
curl -s http://localhost:3000/api/health
```

## Diagnostyka

### InfluxDB nie ma bazy k6
```bash
docker exec $(docker ps -qf name=influxdb) influx -execute "CREATE DATABASE k6"
```

### Grafana nie widzi datasource
```bash
# Sprawdź provisioning
docker exec $(docker ps -qf name=grafana) ls /etc/grafana/provisioning/datasources/
# Powinien być influxdb.yaml

# Restart grafana
docker restart $(docker ps -qf name=grafana)
```

### Dashboard pusty po uruchomieniu k6
Sprawdź czy k6 pisze do InfluxDB:
```bash
docker exec $(docker ps -qf name=influxdb) influx -database k6 -execute "SHOW MEASUREMENTS"
# Powinny być: http_req_duration, http_reqs, iterations, vus, etc.
```
Jeśli puste — k6 był uruchomiony bez `K6_OUT`.

## Historia problemu (2026-05-14)

- docker-compose.yml na instancji 1 istniał, ale bez `INFLUXDB_DB=k6` i bez named volumes
- Grafana miała datasource i dashboard skonfigurowane przez UI (nie przez pliki)
- k6 był uruchamiany bez `K6_OUT` — żadne metryki nie trafiały do InfluxDB
- Instancja 2 nie miała docker-compose.yml w ogóle

Naprawiono: dodano env vars, named volumes, provisioning pliki, commit w repo.
