# Obsidian Git — konfiguracja auto-sync z GitHub

## Objaw / cel

Obsidian vault nie synchronizuje się automatycznie z GitHub. Każda zmiana wymaga ręcznego `git push`.

## Rozwiązanie

Plugin **Obsidian Git v2.38.2** zainstalowany bezpośrednio przez pliki (bez App Store Obsidian).

## Konfiguracja (aktywna)

| Parametr | Wartość | Co robi |
|----------|---------|---------|
| `autoSaveInterval` | 5 min | auto-commit + push co 5 minut |
| `autoPullInterval` | 10 min | pull co 10 minut |
| `autoPullOnBoot` | true | pull przy otwarciu vault |
| `pullBeforePush` | true | pull przed push (unika konfliktów) |
| `commitMessage` | `vault: {{date}}` | format ręcznych commitów |
| `autoCommitMessage` | `vault: auto {{date}}` | format auto-commitów |
| `differentIntervalCommitAndPush` | true | commit i push na tym samym interwale |

Pliki pluginu: `.obsidian/plugins/obsidian-git/`

## Aktywacja po instalacji

Po pierwszym uruchomieniu Obsidian po tej zmianie:
1. Obsidian może zapytać o zezwolenie na community plugins → **Turn on**
2. Sprawdź `Settings → Community plugins` — obsidian-git powinien być widoczny i włączony
3. Zweryfikuj w status barze (dół okna) — ikona gita powinna być widoczna

## Ręczne komendy (Command Palette — Cmd+P)

```
Obsidian Git: Commit all changes
Obsidian Git: Push
Obsidian Git: Pull
Obsidian Git: Open source control view
```

## Wymagania

- Git zainstalowany systemowo: `which git` → `/usr/bin/git` lub `/opt/homebrew/bin/git`
- SSH key skonfigurowany dla GitHub: `ssh -T git@github.com`
- Remote origin ustawiony: `git remote -v` → `git@github.com:JarekGie/devops-knowledge.git`

## Uwagi

- Plugin nie działa w Obsidian Mobile bez dodatkowej konfiguracji
- `.obsidian/` jest w repo — ustawienia pluginu synchronizują się między maszynami
