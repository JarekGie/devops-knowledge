# Runbook — Pod CrashLoopBackOff

#kubernetes #runbook

## Symptom

Pod w statusie `CrashLoopBackOff`. Restartuje się w pętli.

## Zakres

Jeden namespace / deployment. Sprawdź czy pattern dotyczy wszystkich podów serwisu.

---

## Komendy diagnostyczne

```bash
NS=namespace
POD=nazwa-poda
DEPLOY=nazwa-deploymentu

# Status podów
kubectl get pods -n $NS -l app=$DEPLOY

# Szczegóły poda — ostatni restart reason
kubectl describe pod $POD -n $NS | grep -A 10 "Last State"

# Logi (aktualny kontener)
kubectl logs $POD -n $NS

# Logi poprzedniego kontenera (po crashu)
kubectl logs $POD -n $NS --previous

# Events w namespace
kubectl get events -n $NS --sort-by='.lastTimestamp' | tail -20
```

## Punkty decyzyjne

| Exit code | Znaczenie | Akcja |
|-----------|-----------|-------|
| 0 | kontener zakończył się poprawnie | healthcheck/probe problem |
| 1 | błąd aplikacji | sprawdź logi |
| 137 | OOM kill | sprawdź `kubectl top pod` |
| 139 | segfault | bug w aplikacji |
| 143 | SIGTERM — graceful fail | zbyt krótki terminationGracePeriodSeconds |

## OOMKill — sprawdzenie

```bash
# Zużycie zasobów
kubectl top pod $POD -n $NS

# Limity
kubectl get pod $POD -n $NS -o jsonpath='{.spec.containers[*].resources}'
```

## Rollback

```bash
# Poprzednia wersja deploymentu
kubectl rollout undo deployment/$DEPLOY -n $NS

# Historia rolloutów
kubectl rollout history deployment/$DEPLOY -n $NS
```

## Findings

<!-- Co znalazłeś i jak rozwiązano -->
