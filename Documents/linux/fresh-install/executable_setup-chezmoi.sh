#!/usr/bin/env bash
set -euo pipefail

# Bootstrap chezmoi and add managed dotfiles.
# Wi‑Fi SSID is stored only in ~/.config/chezmoi/chezmoi.toml (not in source).
#
# Usage:
#   WIFI_SSID='MyNetwork' ./setup-chezmoi.sh
#   ./setup-chezmoi.sh              # prompts if SSID not set yet
#   ./setup-chezmoi.sh --with-dms   # also manage dms settings.json

WITH_DMS=0
for arg in "$@"; do
	case "$arg" in
		--with-dms) WITH_DMS=1 ;;
		-h | --help)
			cat <<'EOF'
Usage: setup-chezmoi.sh [--with-dms]

  WIFI_SSID=...   Set SSID non-interactively (written to chezmoi.toml [data])
  --with-dms      Also chezmoi-add ~/.config/dms/settings.json
EOF
			exit 0
			;;
		*)
			echo "Unknown option: $arg" >&2
			exit 1
			;;
	esac
done

CHEZMOI_CFG="$HOME/.config/chezmoi/chezmoi.toml"

echo "=== 1. Ensure chezmoi is installed ==="
if ! command -v chezmoi >/dev/null 2>&1; then
	echo "chezmoi not found. Install it first, e.g.: sudo pacman -S chezmoi" >&2
	exit 1
fi
echo "chezmoi: $(command -v chezmoi) ($(chezmoi --version | head -1))"

echo "=== 2. Init source repo if needed ==="
if ! chezmoi source-path >/dev/null 2>&1; then
	chezmoi init
fi
echo "source: $(chezmoi source-path)"

echo "=== 3. Local data (wifiSSID) ==="
mkdir -p "$(dirname "$CHEZMOI_CFG")"

existing_ssid=""
if [[ -f "$CHEZMOI_CFG" ]] && rg -q '^\s*wifiSSID\s*=' "$CHEZMOI_CFG"; then
	existing_ssid="$(
		awk -F'=' '/^\s*wifiSSID\s*=/ {
			gsub(/^[ \t"]+|[ \t"]+$/, "", $2)
			print $2
			exit
		}' "$CHEZMOI_CFG"
	)"
fi

ssid="${WIFI_SSID:-$existing_ssid}"
if [[ -z "$ssid" ]]; then
	if [[ -t 0 ]]; then
		read -r -p 'Wi‑Fi SSID for `wifi` alias: ' ssid
	fi
fi
if [[ -z "$ssid" ]]; then
	echo "No WIFI_SSID set; add [data] wifiSSID to $CHEZMOI_CFG before apply." >&2
else
	if [[ -f "$CHEZMOI_CFG" ]] && rg -q '^\s*wifiSSID\s*=' "$CHEZMOI_CFG"; then
		# Update existing wifiSSID line
		tmp="$(mktemp)"
		awk -v s="$ssid" '
			BEGIN { done=0 }
			/^\s*wifiSSID\s*=/ {
				print "    wifiSSID = \"" s "\""
				done=1
				next
			}
			{ print }
			END {
				if (!done) {
					print ""
					print "[data]"
					print "    wifiSSID = \"" s "\""
				}
			}
		' "$CHEZMOI_CFG" >"$tmp"
		mv -f "$tmp" "$CHEZMOI_CFG"
	elif [[ -f "$CHEZMOI_CFG" ]]; then
		printf '\n[data]\n    wifiSSID = "%s"\n' "$ssid" >>"$CHEZMOI_CFG"
	else
		cat >"$CHEZMOI_CFG" <<EOF
[data]
    wifiSSID = "$ssid"
EOF
	fi
	echo "wifiSSID configured in $CHEZMOI_CFG"
fi

add_if_exists() {
	local path="$1"
	shift
	if [[ -e "$path" ]]; then
		echo "add: $path $*"
		chezmoi add "$@" -- "$path"
	else
		echo "skip (missing): $path"
	fi
}

echo "=== 4. Add managed files ==="

# fish
add_if_exists "$HOME/.config/fish/config.fish"
add_if_exists "$HOME/.config/fish/conf.d/xdg.fish"
add_if_exists "$HOME/.config/fish/conf.d/nb.fish"
add_if_exists "$HOME/.config/fish/conf.d/navigation.fish"
add_if_exists "$HOME/.config/fish/conf.d/git.fish"
add_if_exists "$HOME/.config/fish/conf.d/micromamba.fish"
add_if_exists "$HOME/.config/fish/conf.d/jupyter.fish"
add_if_exists "$HOME/.config/fish/conf.d/fzf.fish"
add_if_exists "$HOME/.config/fish/functions/port.fish"
add_if_exists "$HOME/.config/fish/functions/grs.fish"
add_if_exists "$HOME/.config/fish/functions/sod.fish"

# general.fish as template (SSID via {{ .wifiSSID }})
if [[ -f "$HOME/.config/fish/conf.d/general.fish" ]]; then
	echo "add --template: ~/.config/fish/conf.d/general.fish"
	chezmoi add --template -- "$HOME/.config/fish/conf.d/general.fish"
	tmpl="$(chezmoi source-path)/dot_config/fish/conf.d/general.fish.tmpl"
	if [[ -f "$tmpl" ]]; then
		# Replace a concrete SSID or leave existing template alone
		if rg -q '\{\{\s*\.wifiSSID\s*\}\}' "$tmpl"; then
			echo "template already uses {{ .wifiSSID }}"
		else
			# Replace: alias wifi='dms qr wifi SOMETHING'
			sed -i -E "s/alias wifi='dms qr wifi [^']+'/alias wifi='dms qr wifi {{ .wifiSSID }}'/" "$tmpl"
			echo "templated wifi alias in $tmpl"
		fi
	fi
fi

# editors / tools
add_if_exists "$HOME/.config/git/config"
add_if_exists "$HOME/.config/micro/settings.json"
add_if_exists "$HOME/.config/micro/bindings.json"
add_if_exists "$HOME/.config/zed/settings.json"
add_if_exists "$HOME/.config/nb/nbrc"

# theming sources
add_if_exists "$HOME/.config/matugen/config.toml"
add_if_exists "$HOME/.config/matugen/templates"

# desktop
add_if_exists "$HOME/.config/ghostty/config"
add_if_exists "$HOME/.config/niri/config.kdl"
if ((WITH_DMS)); then
	add_if_exists "$HOME/.config/dms/settings.json"
else
	echo "skip (pass --with-dms): ~/.config/dms/settings.json"
fi

# bootstrap scripts (this directory)
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
add_if_exists "$SCRIPT_DIR"

echo "=== 5. Verify ==="
chezmoi managed | sort
echo
echo "=== Done ==="
echo "Preview wifi line:"
echo "  chezmoi cat ~/.config/fish/conf.d/general.fish | rg wifi"
echo "Apply everything:"
echo "  chezmoi apply"
echo
echo "Not managed (on purpose): fish_variables, empty dms.fish,"
echo "  zed/ghostty generated themes, Zen profile, caches."
