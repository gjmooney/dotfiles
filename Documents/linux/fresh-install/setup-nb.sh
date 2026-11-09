#!/usr/bin/env bash
set -euo pipefail

# One-shot setup for a clean system.
# NB_DIR (~/Documents/notes) holds global notebooks. Fish sets NB_DIR /
# NBRC_PATH via ~/.config/fish/conf.d/nb.fish.

DOCS="$HOME/Documents"
NOTES="$DOCS/notes"
NBRC="${NBRC_PATH:-$HOME/.config/nb/nbrc}"

export NB_DIR="$NOTES"
export NBRC_PATH="$NBRC"
mkdir -p "$NOTES" "$(dirname "$NBRC")"

if [[ ! -f "$NBRC" ]]; then
	mkdir -p "$(dirname "$NBRC")"
	cat >"$NBRC" <<'EOF'
#!/usr/bin/env bash
###############################################################################
# .nbrc — managed by setup-nb.sh; prefer `nb settings` for changes.
###############################################################################
EOF
fi

nb notebook add home/
nb notebook add meetings/catchups/
nb notebook add meetings/yearly-reviews/
nb notebook add projects/jupytergis/meetings/
nb notebook add recipes/to-try/
nb notebook add recipes/staples/
nb notebook add reference/cheatsheets/
nb notebook add templates/

cat >"$NOTES/templates/meeting.md" <<'EOF'
# Meeting: {{title}}

**Date:** {{date +"%Y-%m-%d"}}
**Attendees:**
**Project:**

## Notes
{{content}}

## Decisions
-

## Action Items
- [ ]
EOF

cat >"$NOTES/templates/project.md" <<'EOF'
# Project: {{title}}

**Status:** active / paused / done
**Started:** {{date +"%Y-%m-%d"}}
**Related:**

## Goal
{{content}}

## Notes
-

## Open Questions
-

## Log
- {{date +"%Y-%m-%d"}}:
EOF

cat >"$NOTES/templates/recipe.md" <<'EOF'
# {{title}}

**Source:**
**Servings:**
**Active time:**
**Tags:** #recipe

## Ingredients
-

## Instructions
1.

## Notes
-
EOF

nb set editor zeditor

nb use home
