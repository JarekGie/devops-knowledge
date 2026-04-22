# NotebookLM CLI capability probe

Generated: Wed Apr 22 22:28:20 CEST 2026

## notebooklm metadata --help
```
Usage: notebooklm metadata [OPTIONS]

  Export notebook metadata with sources list.

  Outputs notebook details (id, title, created_at, is_owner) along with a
  simplified list of sources (type, title, url).

  By default, outputs in human-readable format. Use --json for machine
  parsing.

  NOTEBOOK_ID supports partial matching (e.g., 'abc' matches 'abc123...').

  Examples:
    notebooklm metadata              # Human-readable for current notebook
    notebooklm metadata -n abc       # Human-readable for notebook starting with 'abc'
    notebooklm metadata --json       # JSON output
    notebooklm metadata -n abc --json  # JSON for specific notebook

Options:
  -n, --notebook TEXT  Notebook ID (uses current if not set). Supports partial
                       IDs.
  --json               Output as JSON (default: human-readable)
  --help               Show this message and exit.
```

## notebooklm source list --help
```
Usage: notebooklm source list [OPTIONS]

  List all sources in a notebook.

Options:
  -n, --notebook TEXT  Notebook ID (uses current if not set)
  --json               Output as JSON
  --help               Show this message and exit.
```

## notebooklm note save --help
```
Usage: notebooklm note save [OPTIONS] NOTE_ID

  Update note content.

  NOTE_ID can be a full UUID or a partial prefix (e.g., 'abc' matches
  'abc123...').

Options:
  -n, --notebook TEXT  Notebook ID (uses current if not set)
  --title TEXT         New title
  --content TEXT       New content
  --help               Show this message and exit.
```

## notebooklm artifact export --help
```
Usage: notebooklm artifact export [OPTIONS] ARTIFACT_ID

  Export artifact to Google Docs/Sheets.

  ARTIFACT_ID can be a full UUID or a partial prefix (e.g., 'abc' matches
  'abc123...').

Options:
  -n, --notebook TEXT   Notebook ID (uses current if not set). Supports
                        partial IDs.
  --title TEXT          Title for exported document  [required]
  --type [docs|sheets]
  --help                Show this message and exit.
```

## notebooklm generate mind-map --help
```
Usage: notebooklm generate mind-map [OPTIONS]

  Generate mind map.

  Use --json for machine-readable output.

Options:
  -n, --notebook TEXT  Notebook ID (uses current if not set)
  -s, --source TEXT    Limit to specific source IDs
  --json               Output as JSON
  --help               Show this message and exit.
```

## notebooklm download mind-map --help
```
Usage: notebooklm download mind-map [OPTIONS] [OUTPUT_PATH]

  Download mind map(s) as JSON files.

  Examples:
    # Download latest mind map to default filename
    notebooklm download mind-map

    # Download to specific path   notebooklm download mind-map my-mindmap.json

    # Download all mind maps to directory   notebooklm download mind-map --all
    ./mind-maps/

    # Download specific artifact by name   notebooklm download mind-map --name
    "chapter 3"

    # Preview without downloading   notebooklm download mind-map --all --dry-
    run

Options:
  -n, --notebook TEXT  Notebook ID (uses current context if not set)
  --latest             Download latest (default behavior)
  --earliest           Download earliest
  --all                Download all artifacts
  --name TEXT          Filter by artifact title (fuzzy match)
  -a, --artifact TEXT  Select by artifact ID
  --json               Output JSON instead of text
  --dry-run            Preview without downloading
  --force              Overwrite existing files
  --no-clobber         Skip if file exists
  --help               Show this message and exit.
```

