# Plugin: Terminal — zsh + oh-my-zsh w Obsidian

## Cel

Wbudowany terminal z pełnym zsh + oh-my-zsh w panelu Obsidian — bez przełączania się do iTerm2 dla szybkich komend przy pracy z vaultem.

## Status

Plugin zainstalowany i skonfigurowany. `darwinIntegratedDefault` używa `/bin/zsh --login` — oh-my-zsh ładuje się automatycznie.

## Instalacja (dla referencji)

1. `Settings → Community plugins → Browse`
2. Szukaj: **Terminal** (autor: polyipseity)
3. Install → Enable

## Konfiguracja (integrated terminal z zsh)

`Settings → Terminal`:

| Ustawienie | Wartość | Uwaga |
|------------|---------|-------|
| **Profile → Shell** | `/bin/zsh` lub `/opt/homebrew/bin/zsh` | sprawdź: `which zsh` w iTerm2 |
| **Profile → Arguments** | `-l` | login shell — ładuje `.zshrc` z oh-my-zsh |
| **Profile → Working directory** | `Vault folder` | otwiera w katalogu vault |

Weryfikacja ścieżki zsh:
```bash
which zsh
# → /bin/zsh lub /opt/homebrew/bin/zsh
```

## Otwieranie terminala

| Akcja | Skrót / sposób |
|-------|----------------|
| Nowy terminal (vault root) | Cmd+P → `Terminal: Open terminal in root folder` |
| Terminal w bieżącym folderze | Cmd+P → `Terminal: Open terminal in current folder` |
| Własny skrót klawiszowy | `Settings → Hotkeys` → szukaj "Terminal" |

## Weryfikacja po uruchomieniu

Po otwarciu terminala sprawdź:
```bash
echo $SHELL        # → /bin/zsh
echo $ZSH          # → ~/.oh-my-zsh (jeśli oh-my-zsh załadowany)
echo $0            # → -zsh (myślnik = login shell)
```

## Uwagi

- Argument `-l` jest kluczowy — bez niego `.zshrc` może się nie załadować i oh-my-zsh nie ruszy
- Jeśli zsh z Homebrew (`/opt/homebrew/bin/zsh`) — upewnij się, że jest w `/etc/shells`
- Terminal działa jako panel Obsidian — można go zadokować, pinować, otwierać w split view
- PATH i aliasy dziedziczone z `.zshrc` / `.zprofile` działają normalnie
