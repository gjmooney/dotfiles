#!/usr/bin/env bash
set -euo pipefail

# One-shot setup for a clean system.
# NB_DIR (~/Documents/notes) holds global notebooks. Fish sets NB_DIR /
# NBRC_PATH via ~/.config/fish/conf.d/nb.fish.

DOCS="$HOME/Documents"
NOTES="$DOCS/notes"
NBRC="${NBRC_PATH:-$HOME/.config/nb/nbrc}"

NOTEBOOKS=(
	home
	journal
	meetings
	projects
	recipes
	reference
	templates
)

# notebook -> space-separated folders to create inside it
declare -A NOTEBOOK_FOLDERS=(
	[recipes]='to-try staples'
)

echo "=== 1. Ensure nb is installed ==="
if command -v nb >/dev/null 2>&1; then
	echo "nb: $(command -v nb)"
elif [[ -x "$HOME/.local/bin/nb" ]]; then
	export PATH="$HOME/.local/bin:$PATH"
else
	mkdir -p "$HOME/.local/bin"
	tmp="$(mktemp)"
	cleanup_tmp() {
		rm -f "$tmp"
	}
	trap cleanup_tmp EXIT
	curl -fsSL https://raw.github.com/xwmx/nb/master/nb -o "$tmp"
	chmod +x "$tmp"
	mv -f "$tmp" "$HOME/.local/bin/nb"
	trap - EXIT
	export PATH="$HOME/.local/bin:$PATH"
fi

echo "=== 2. Point NB_DIR at the vault ==="
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

echo "=== 3. Create notebooks ==="
for name in "${NOTEBOOKS[@]}"; do
	if [[ -d "$NOTES/$name" ]]; then
		echo "exists: $name"
	else
		nb notebooks add "$name"
		echo "added: $name"
	fi
done

echo "=== 4. Create notebook folders ==="
for name in "${!NOTEBOOK_FOLDERS[@]}"; do
	# shellcheck disable=SC2206
	folders=(${NOTEBOOK_FOLDERS[$name]})
	for folder in "${folders[@]}"; do
		if [[ -d "$NOTES/$name/$folder" ]]; then
			echo "exists: $name/$folder"
		else
			nb "$name:add" folder "$folder"
			echo "added: $name/$folder"
		fi
	done
done

echo "=== 5. Write templates ==="
mkdir -p "$NOTES/templates"
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

echo "=== 6. Set editor ==="
EDITOR_CHOICE="${EDITOR:-$(command -v zeditor || command -v micro || echo vi)}"
nb set editor "$EDITOR_CHOICE"

echo "=== 7. Default notebook ==="
nb use home

echo "=== 8. Verify ==="
echo "NB_DIR: $NOTES"
nb notebooks --names
echo
echo "=== Done ==="
echo "Add a recipe:"
echo "  nb recipes:to-try:add --template \"$NOTES/templates/recipe.md\" --title \"Name\""
nb_path="$(command -v nb)"
case "$nb_path" in
"$HOME/.local/bin/"*)
	echo "If a new shell cannot find nb:"
	echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
	;;
esac
