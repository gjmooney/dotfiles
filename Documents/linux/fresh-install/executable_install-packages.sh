#!/usr/bin/env bash
set -euo pipefail

# Install packages listed in packages-to-install.md
# Lines ending with ? are optional (skipped unless --optional).

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LIST_FILE="${SCRIPT_DIR}/packages-to-install.md"

INCLUDE_OPTIONAL=0
CONFIRM_ARGS=(--needed)

usage() {
	cat <<'EOF'
Usage: install-packages.sh [options]

Install packages from packages-to-install.md via pacman.

Options:
  --optional   Also install packages marked with ?
  -y           Pass --noconfirm to pacman
  -h, --help   Show this help
EOF
}

while (($#)); do
	case "$1" in
		--optional) INCLUDE_OPTIONAL=1 ;;
		-y) CONFIRM_ARGS+=(--noconfirm) ;;
		-h | --help)
			usage
			exit 0
			;;
		*)
			echo "Unknown option: $1" >&2
			usage >&2
			exit 1
			;;
	esac
	shift
done

if [[ ! -f "$LIST_FILE" ]]; then
	echo "Package list not found: $LIST_FILE" >&2
	exit 1
fi

packages=()
skipped_optional=()

while IFS= read -r line || [[ -n "$line" ]]; do
	# Trim whitespace; skip blanks and # comments
	line="${line#"${line%%[![:space:]]*}"}"
	line="${line%"${line##*[![:space:]]}"}"
	[[ -z "$line" || "$line" == \#* ]] && continue

	optional=0
	if [[ "$line" == *\? ]]; then
		optional=1
		line="${line%\?}"
		line="${line%"${line##*[![:space:]]}"}"
	fi

	[[ -z "$line" ]] && continue

	if ((optional)) && ((!INCLUDE_OPTIONAL)); then
		skipped_optional+=("$line")
		continue
	fi

	packages+=("$line")
done <"$LIST_FILE"

if ((${#packages[@]} == 0)); then
	echo "No packages to install."
	exit 0
fi

echo "Will install (${#packages[@]}):"
printf '  %s\n' "${packages[@]}"

if ((${#skipped_optional[@]})); then
	echo
	echo "Skipping optional (pass --optional to include):"
	printf '  %s\n' "${skipped_optional[@]}"
fi

echo
sudo pacman -S "${CONFIRM_ARGS[@]}" -- "${packages[@]}"
echo "Done."
