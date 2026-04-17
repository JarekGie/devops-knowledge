# Minikurs Shuttle Audit

#toolkit #e2e #minikurs #testing

Mirror: `~/projekty/devops/devops-toolkit/docs/shuttle-audit-mini-course.md`

---

## Czym jest shuttle audit

Shuttle audit nie pyta "czy środowisko teraz działa?" — pyta **"czy testy wykryją znane klasy awarii, gdy wystąpią?"**

Typowe przypadki które wykrywa:
- **routing mismatch** — gateway żyje, ale path rewrite kieruje ruch nie tam gdzie trzeba → 404 lub błędny upstream
- **wrong target group** — listener rule wygląda OK, ruch trafia do złego target group
- **DNS issues** — publiczny ingress nie rozwiązuje się poprawnie
- **partial outages** — część instancji działa, część nie → syntetyczny wynik "OK" jest mylący
- **latency** — endpoint odpowiada, ale degradacja narusza SLO

---

## Dwa poziomy toolkit

| Tryb | Co sprawdza |
|------|-------------|
| `toolkit audit --mode shuttle` | Design safety — struktura test coverage, bindings, detectability |
| `toolkit e2e` | Runtime validation — konkretne probes, evidence, verdict |

**Kolejność:** najpierw shuttle (czy testy są sensownie zbudowane), potem e2e (czy środowisko działa).

---

## Bindings — krytyczny element

Bindings mapują canonical templates na realne środowisko projektu. Bez nich toolkit nie wie jakie ścieżki są krytyczne ani jak wygląda ingress.

```yaml
bindings:
  gateway_routes_smoke:
    template: gateway-routes-smoke
    public_base_url: https://api.example.internal
    route_checks:
      - path: /health
        expected_status: 200
      - path: /core/health
        expected_status: 200
    target_override:
      ecs_service_name: prod-gateway
```

---

## Typowe błędy

| Błąd | Skutek |
|------|--------|
| Brak bindings | Route-level validation wyłączona de facto |
| Błędny `public_base_url` | Test sprawdza zły ingress, wynik wygląda OK |
| Poleganie tylko na templates | Wyniki zbyt ogólne — nie wykryją routing regression |

`partially_detected` w wyniku = sygnał do poprawy bindings, NIE zielone światło.

---

## Workflow

```bash
# 1. Upewnij się że .devops-toolkit/ istnieje
toolkit onboard

# 2. Skonfiguruj bindings (public_base_url, route checks, target_override)

# 3. Shuttle audit — ocena jakości wykrywania
toolkit audit --mode shuttle

# 4. Runtime validation
toolkit e2e

# 5. Integracja z CI gate — dopiero po obu krokach
```

---

## Powiązane

- [[minikurs-self-test]]
- [[command-catalog]]
