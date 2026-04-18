Cel projektu
Zbudowanie lekkiego, kontrolowanego modelu governance w AWS Organization Makolab, zgodnego z dobrymi praktykami AWS (partner-ready), bez reanimacji Control Tower i bez przerywania produkcji.
Zakres
W zakresie
Security Account (nowe)
Log Archive Account (jeśli istnieje i jest aktywne – utrzymanie; jeśli nie – nowe)
Org CloudTrail (już wdrożone) + centralny bucket + KMS
GuardDuty org-level + delegated admin
AWS Config org-level + aggregator
Minimalne SCP
Uporządkowanie OU + przeniesienie kont z Root
“Quarantine/Legacy OU” dla kont bez ownera + plan zamknięcia
Poza zakresem
AFT / Account Factory
pełny enterprise governance (Security Hub full, SSO/IdP rework, ISO/SOC2 hardening)
automatyczny provisioning kont
Epiki i taski
EPIC 0 — Project governance (lekko, ale serio)
E0.1 Utworzenie repo “governance” / katalogu w istniejącym repo (docs + tools)
E0.2 Konwencje: naming, tagging, owners
E0.3 Rejestr decyzji architektonicznych (ADR)
DoD: jest miejsce, gdzie lądują decyzje, dowody i status.
EPIC 1 — Inwentaryzacja i porządek organizacyjny (SAFE CLEANUP)
E1.1 OU inventory + accounts inventory (zrobione narzędziem)
E1.2 Lista pustych OU i plan ich usunięcia
E1.3 Identyfikacja kont “owner=unknown” + tagowanie + OU “Legacy/Quarantine”
E1.4 Przeniesienie kont z Root do OU (Governance/Workloads/Legacy)
E1.5 Dokument “Current state vs Target state” w Confluence
DoD: Root bez “śmietnika”, OU logiczne, konta mają owner/status.
EPIC 2 — Central Logging (Partner-ready)
E2.1 Potwierdzenie: Org CloudTrail multi-region, global services, validation
E2.2 Bucket w Log Archive: versioning, lifecycle, SSE-KMS, block public access
E2.3 KMS policy: CloudTrail + org accounts write
E2.4 Test: log delivery działa (nowe eventy trafiają do S3)
DoD: CloudTrail działa i zapisuje do Log Archive (twardy dowód: pliki w S3).
EPIC 3 — Security Account (Separation of duties)
E3.1 Utworzenie konta Security (w organizacji)
E3.2 Minimalny bootstrap: IAM roles, access model (break-glass), tagi
E3.3 Delegated admin: GuardDuty, Config (i opcjonalnie Security Hub w przyszłości)
DoD: Security account jest ownerem security tooling, nie jest workloadem.
EPIC 4 — GuardDuty org-wide
E4.1 Włączenie GuardDuty w Security jako delegated admin
E4.2 Auto-enable dla nowych kont
E4.3 Central findings i potwierdzenie działania (test finding / sample)
E4.4 (Opcjonalnie) S3 protection / EKS protection tylko jeśli potrzebne
DoD: GuardDuty aktywny na wszystkich aktywnych kontach, findings centralnie widoczne.
EPIC 5 — AWS Config org-wide + Aggregator
E5.1 Włączenie recorderów w kontach (lub org config)
E5.2 Aggregator w Security
E5.3 Minimalny zestaw reguł (5–8), bez “regułowego długu”
E5.4 Dowód: agregacja działa, dane spływają
DoD: Security widzi konfiguracje zasobów w całej org i ma podstawowe reguły.
EPIC 6 — SCP baseline (preventive controls)
E6.1 Zdefiniowanie minimalnych SCP (4–6)
E6.2 Rollout: najpierw Sandbox/DEV, potem Workloads
E6.3 “Break glass” procedura (kto i jak odblokowuje)
E6.4 Dowód: SCP przypięte do OU
DoD: Nie da się wyłączyć kluczowych usług governance “przypadkiem”.
EPIC 7 — Legacy accounts decommission
E7.1 30 dni obserwacji: koszty, logowania, CloudTrail AssumeRole
E7.2 Plan zamknięcia: komunikacja, approvals, harmonogram
E7.3 Zamknięcie kont + cleanup OU
DoD: znikają zombie konta, a decyzje są udokumentowane.
