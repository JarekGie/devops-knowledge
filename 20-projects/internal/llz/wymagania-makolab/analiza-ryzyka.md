Skala
P (Probability): Niskie/Średnie/Wysokie
I (Impact): Niski/Średni/Wysoki
Mitigacja: co robimy, żeby ryzyko ograniczyć
Wykrywanie: jak szybko zobaczymy, że coś idzie źle

ID	Ryzyko	P	I	Mitigacja	Wykrywanie / kontrola
R1	Przypadkowe ograniczenie produkcji przez SCP	Śr	Wys	Rollout etapami: Sandbox/DEV → PROD; testy; “break-glass” rola; SCP tylko preventive dla governance	CloudTrail + testy pre/post; plan rollback (odpięcie SCP z OU)
R2	GuardDuty/Config wygenerują nieprzewidziane koszty	Nisk	Śr	Włączamy “lean”: bez nadmiarowych protections; mało reguł Config; monitoring kosztów CE per account/service	Monthly CE dashboard + alert budżetowy
R3	Brak ownera kont legacy → konflikt decyzyjny	Wys	Śr	OU “Legacy/Quarantine”; tagi owner=unknown; formalna decyzja “review_after”; komunikacja z IT/FinOps	Lista kont legacy w Confluence + status co tydzień
R4	Zamknięcie konta, które jednak było zależnością	Śr	Wys	Okno obserwacji 30 dni; sprawdzenie CloudTrail AssumeRole; sprawdzenie cost/usage; review z interesariuszami	Brak logowań/assume role + 0 kosztów + potwierdzenia
R5	Dostępy do Security/LogArchive będą źle ustawione i blokujące	Śr	Śr	Minimalny model dostępu; “break-glass” użytkownik; test dostępu; dokumentacja	Testy dostępu + audyt IAM + “two-person rule”
R6	KMS policy/bucket policy zablokuje dostarczanie CloudTrail	Śr	Wys	Policy wg sprawdzonego wzorca; test create trail + delivery; walidacja plików w S3	Brak nowych logów w S3 → alarm operacyjny
R7	Chaos w OU / konta w Root utrudnią governance	Wys	Śr	Szybkie uporządkowanie: Governance/Workloads/Legacy; przeniesienie kont; usunięcie pustych OU	Inwentaryzacja cykliczna + docelowy diagram
R8	Zależności ludzi/procesów (brak wsparcia)	Śr	Śr	Executive summary + plan etapów + koszt marginalny; pokazać szybkie wygrane	Checkpointy co tydzień + raport statusu
R9	“Shadow IT” – ktoś ma ukryte automaty/role	Śr	Śr	CloudTrail lookup (AssumeRole), IAM Access Analyzer (opcjonalnie), okres obserwacji	Incydenty dostępu / brak aktywności w logach
R10	Zmiany wykonywane ręcznie → drift i brak powtarzalności	Śr	Śr	Docelowo Terraform dla baseline; na start — snapshoty + repo; minimalne manuale tylko jednorazowo	Snapshots + git history + ADR
Kluczowe ryzyko nr 1 (do zarządu)
R1: SCP mogą wpłynąć na produkcję jeśli wdrożone bez rollout planu.
Mitigacja: rollout etapami + break-glass + łatwy rollback (odpięcie SCP).
