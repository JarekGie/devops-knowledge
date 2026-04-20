#!/bin/bash
# Krok 1: Zamknij obecne Chrome, a potem uruchom z portem CDP:
#   /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
#     --remote-debugging-port=9222 \
#     --user-data-dir="$HOME/Library/Application Support/Google/Chrome"
#
# Krok 2: Zweryfikuj ze CDP dziala:
#   curl -s http://localhost:9222/json/version | python3 -m json.tool
#
# Krok 3: Uruchom eksport:

source .venv/bin/activate
python -m udemy_obsidian export \
  --course-url "https://www.udemy.com/course/aws-certified-cloudops-associate/" \
  --vault "/Users/jaroslaw.golab/projekty/devops/devops-knowledge" \
  --cdp-url "http://localhost:9222" \
  --dry-run \
  --verbose
