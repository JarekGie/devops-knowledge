#!/usr/bin/env bash
# new-chatgpt-context.sh — tworzy nową notatkę podsumowania rozmowy z ChatGPT
# Użycie: ./scripts/new-chatgpt-context.sh "Tytuł rozmowy" "zakres/projekt"
# Lub bez argumentów — interaktywny tryb

set -euo pipefail

VAULT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONVERSATIONS_DIR="$VAULT_ROOT/_chatgpt/conversations"
INDEX_FILE="$VAULT_ROOT/_chatgpt/INDEX.md"
TEMPLATE="$VAULT_ROOT/_chatgpt/templates/conversation-note-template.md"

DATE=$(date +%Y-%m-%d)
TIMESTAMP=$(date +%Y-%m-%d_%H%M)

# Argumenty lub tryb interaktywny
if [ $# -ge 1 ]; then
  TITLE="$1"
else
  echo "Tytuł rozmowy:"
  read -r TITLE
fi

if [ $# -ge 2 ]; then
  SCOPE="$2"
else
  echo "Projekt / zakres:"
  read -r SCOPE
fi

# Bezpieczna nazwa pliku
SLUG=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//')
FILENAME="${TIMESTAMP}_${SLUG}.md"
FILEPATH="$CONVERSATIONS_DIR/$FILENAME"

# Kopiuj szablon i podmień placeholdery
sed \
  -e "s/{{TYTUŁ}}/$TITLE/g" \
  -e "s/{{DATA}}/$DATE/g" \
  -e "s/{{PROJEKT}}/$SCOPE/g" \
  "$TEMPLATE" > "$FILEPATH"

echo "✓ Utworzono: $FILEPATH"

# Aktualizuj INDEX.md — dodaj wpis na początku tabeli rozmów
INDEX_LINE="| \`$FILENAME\` | $TITLE | $DATE | $SCOPE |"

# Wstaw po nagłówku tabeli rozmów (linia z "Brak notatek" lub istniejące wpisy)
if grep -q "| — | — | — | Brak notatek |" "$INDEX_FILE"; then
  sed -i '' "s~| — | — | — | Brak notatek |~$INDEX_LINE~" "$INDEX_FILE"
else
  # Dodaj przed ostatnią linią separatora lub na koniec tabeli
  sed -i '' "/^## Podsumowania rozmów/,/^---/{/^\| — \|/{
    i\\
$INDEX_LINE
  }}" "$INDEX_FILE" 2>/dev/null || echo "⚠ Zaktualizuj INDEX.md ręcznie: $INDEX_LINE"
fi

echo "✓ INDEX.md zaktualizowany"
echo ""
echo "Następne kroki:"
echo "  1. Otwórz plik i uzupełnij sekcje"
echo "  2. Zapisz kontekst do ponownego użycia"
echo "  3. Zaktualizuj 02-active-context/now.md jeśli zmienił się kontekst pracy"
echo ""
echo "  \$EDITOR $FILEPATH"
