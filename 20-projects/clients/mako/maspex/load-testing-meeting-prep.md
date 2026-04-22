# Load Testing — wsad na spotkanie

#maspex #load-testing #spotkanie #decision

**Data:** 2026-04-22
**Status:** przygotowanie do spotkania, brak decyzji o wdrożeniu

---

## Problem (dlaczego rozmawiamy)

Test obciążeniowy (Łukasz Fuchs, kwiecień 2026):
- **7.53% błędów na `POST /api/slogan/vote`** przy nieznanym obciążeniu
- Nie wiemy: jaka liczba concurrent users, czy to edge case czy norma, czy powtarzalne
- Przed pushem na prod — nie mamy jak sprawdzić czy to samo się powtórzy

Brakuje: powtarzalnego narzędzia do testów obciążeniowych z historią wyników.

---

## Co proponujemy

**AWS Distributed Load Testing** — gotowe rozwiązanie AWS (nie piszemy własnego).

Działa tak: uruchamiasz test z web console lub API, AWS odpala dziesiątki kontenerów Fargate symulujących użytkowników, wyniki lądują w CloudWatch i S3.

Obsługuje: prosty HTTP, JMeter (.jmx), K6, Locust.

---

## Decyzje do podjęcia na spotkaniu

| # | Pytanie | Opcje |
|---|---------|-------|
| 1 | **Kiedy chcemy to mieć?** | przed następnym releasem na prod / nie ma pośpiechu |
| 2 | **Kto prowadzi testy?** | devops przygotowuje scenariusze / zespół dev sam uruchamia |
| 3 | **Co testujemy?** | tylko `/api/slogan/vote` / pełen smoke test przed releasem |
| 4 | **Próg błędów = blokada releasu?** | tak (CI/CD gate) / nie (informacyjnie) |
| 5 | **Środowisko testowe?** | UAT (`kapsel.makotest.pl`) / dedykowane load-test env |

---

## Koszt i nakład

| Składnik | Szacunek |
|----------|---------|
| Wdrożenie narzędzia | ~1h (jednorazowo) |
| Napisanie scenariuszy JMeter | ~2–3h |
| Analiza wyników + rekomendacje | ~1h |
| **Łącznie praca inżyniera** | **~4–5h** |
| Koszt AWS idle (miesięcznie) | ~$1–3 |
| Koszt pojedynczego testu (5 tasków, 15 min) | ~$1 |

---

## Kontekst techniczny (dla siebie na spotkaniu)

**Dlaczego 7.53% błędów na vote?** Hipotezy:
1. Redis connection pool exhaustion pod obciążeniem (najbardziej prawdopodobne)
2. Brak ECS Auto Scaling — 3 stałe taski api, zero scale-out
3. Rate limiting w aplikacji (celowe throttling)

**Żeby to rozwiązać** potrzebujemy wiedzieć przy jakiej liczbie concurrent users błędy się zaczynają — DLT to umożliwia (test ze stopniowanym obciążeniem).

**Brak Auto Scaling** to osobna rozmowa — nawet jeśli znajdziemy próg, bez scaling aplikacja nie poradzi sobie z ruchem prod.

---

## Rekomendacja (moja pozycja na spotkaniu)

1. Wdrożyć DLT — niski koszt, wysokie korzyści, 4–5h pracy
2. Pierwszym testem: reprodukcja błędu vote z rosnącym obciążeniem (50 → 100 → 200 → 300 users)
3. Równolegle: dodać ECS Auto Scaling do `maspex-api` (to jest rzeczywista naprawa, nie tylko pomiar)
4. Docelowo: smoke test jako etap GitLab CI po każdym deploy na UAT

---

## Powiązane

- [[distributed-load-testing]] — szczegóły techniczne wdrożenia
- [[troubleshooting]] — bieżące problemy maspex
