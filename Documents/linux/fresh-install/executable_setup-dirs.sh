#!/usr/bin/env bash
set -euo pipefail

BASE="${HOME}/Documents"

# programming/scripts/<project>
SCRIPT_PROJECTS=('jupytergis')

# programming/plans/<project>
PLAN_PROJECTS=('pfeffer')

# gardening/weed/feed-schedules/<brand>
WEED_BRANDS=('athena')

# games/roms/{bios,front-ends}/<system>
SYSTEMS=('gba' 'playstation')

# games/roms/<game>/{mods,guides}
GAMES=('mass-effect')

# learning/languages/<language>
LANGUAGES=('german')

# music/tickets/<year>
TICKET_YEARS=('2026')

# fitness/plans/<plan>
FITNESS_PLANS=('helms')

# books/<author>
AUTHORS=('marx-karl')

# paperwork/quantstack/<project>/<year>
PAPERWORK_PROJECT_YEARS=('jupytergis|2026')

# money/taxes/<year>/<institution>
TAX_YEAR_INSTITUTIONS=('2026|discover')

# notes/{meetings,journal}/<year>
NOTE_YEARS=('2026')

require_segment() {
local name="$1"
if [[ -z "$name" || "$name" == *'/'* || "$name" == '.' || "$name" == '..' ]]; then
echo "invalid name: '${name}'" >&2
exit 1
fi
if [[ ! "$name" =~ ^[a-z0-9][a-z0-9._-]*$ ]]; then
echo "invalid name: '${name}' (must be lowercase alnum, dots, hyphens)" >&2
exit 1
fi
}

ensure_dir() {
local path="$1"
mkdir -p "$path"
echo "dir ${path#"${BASE}/"}"
}

ensure_file() {
local path="$1"
mkdir -p "$(dirname "$path")"
if [[ ! -e "$path" ]]; then
touch "$path"
echo "file ${path#"${BASE}/"}"
fi
}

add_named_dir() {
local parent="$1"
local name="$2"
require_segment "$name"
ensure_dir "${parent}/${name}"
}

add_pair() {
local parent="$1"
local entry="$2"
local left="${entry%%|*}"
local right=""
require_segment "$left"
if [[ "$entry" == *'|'* ]]; then
right="${entry#*|}"
if [[ -n "$right" ]]; then
require_segment "$right"
ensure_dir "${parent}/${left}/${right}"
return
fi
fi
ensure_dir "${parent}/${left}"
}

echo "base ${BASE}"

for path in \
"${BASE}/cooking/recipes/staples" \
"${BASE}/cooking/recipes/to-try" \
"${BASE}/cooking/meal-plans" \
"${BASE}/programming/job" \
"${BASE}/programming/not-job" \
"${BASE}/programming/personal" \
"${BASE}/programming/scripts" \
"${BASE}/programming/misc/gis" \
"${BASE}/programming/plans" \
"${BASE}/gardening/weed/feed-schedules" \
"${BASE}/games/roms/bios" \
"${BASE}/games/roms/front-ends" \
"${BASE}/lego/instructions" \
"${BASE}/linux/isos" \
"${BASE}/linux/fresh-install" \
"${BASE}/learning/languages" \
"${BASE}/music/tickets" \
"${BASE}/fitness/plans" \
"${BASE}/books" \
"${BASE}/watching/tv" \
"${BASE}/watching/movies" \
"${BASE}/paperwork/quantstack/payslips" \
"${BASE}/paperwork/quantstack/contract" \
"${BASE}/money/taxes" \
"${BASE}/money/returns" \
"${BASE}/notes/meetings" \
"${BASE}/notes/projects" \
"${BASE}/notes/reference" \
"${BASE}/notes/templates"
do
ensure_dir "$path"
done

ensure_file "${BASE}/music/show-tracker.md"
ensure_file "${BASE}/books/check-out.md"
ensure_file "${BASE}/watching/check-out.md"
ensure_file "${BASE}/notes/inbox.md"
ensure_file "${BASE}/notes/templates/meeting.md"
ensure_file "${BASE}/notes/templates/project.md"

for dir in cooking programming gardening games lego linux learning music fitness books watching paperwork money; do
ensure_file "${BASE}/${dir}/notes.md"
done

for name in "${SCRIPT_PROJECTS[@]}"; do
add_named_dir "${BASE}/programming/scripts" "$name"
done

for name in "${PLAN_PROJECTS[@]}"; do
add_named_dir "${BASE}/programming/plans" "$name"
done

for name in "${WEED_BRANDS[@]}"; do
add_named_dir "${BASE}/gardening/weed/feed-schedules" "$name"
done

for name in "${SYSTEMS[@]}"; do
add_named_dir "${BASE}/games/roms/bios" "$name"
add_named_dir "${BASE}/games/roms/front-ends" "$name"
done

for name in "${GAMES[@]}"; do
require_segment "$name"
ensure_dir "${BASE}/games/roms/${name}/mods"
ensure_dir "${BASE}/games/roms/${name}/guides"
done

for name in "${LANGUAGES[@]}"; do
add_named_dir "${BASE}/learning/languages" "$name"
done

for name in "${TICKET_YEARS[@]}"; do
add_named_dir "${BASE}/music/tickets" "$name"
done

for name in "${FITNESS_PLANS[@]}"; do
add_named_dir "${BASE}/fitness/plans" "$name"
done

for name in "${AUTHORS[@]}"; do
add_named_dir "${BASE}/books" "$name"
done

for entry in "${PAPERWORK_PROJECT_YEARS[@]}"; do
add_pair "${BASE}/paperwork/quantstack" "$entry"
done

for entry in "${TAX_YEAR_INSTITUTIONS[@]}"; do
add_pair "${BASE}/money/taxes" "$entry"
done

for name in "${NOTE_YEARS[@]}"; do
add_named_dir "${BASE}/notes/meetings" "$name"
add_named_dir "${BASE}/notes/journal" "$name"
done
