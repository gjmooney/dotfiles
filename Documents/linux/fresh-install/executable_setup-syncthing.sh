#!/usr/bin/env bash
set -euo pipefail

# Usage: ./setup-syncthing.sh <REMOTE_DEVICE_ID> <FOLDER_PATH>
# Configures this machine's Syncthing (v2+) user service, adds the remote
# device, and shares FOLDER_PATH with it. The remote must still accept the
# device/folder (or already have auto-accept enabled).

REMOTE_ID=${1:-}
FOLDER_PATH=${2:-}

if [[ -z "$REMOTE_ID" || -z "$FOLDER_PATH" ]]; then
	echo "Usage: $0 <REMOTE_DEVICE_ID> <FOLDER_PATH>" >&2
	exit 1
fi

if ! command -v syncthing >/dev/null; then
	echo "syncthing is not installed" >&2
	exit 1
fi

if ! command -v curl >/dev/null; then
	echo "curl is not installed" >&2
	exit 1
fi

CONFIG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/syncthing"
FOLDER_ID="shared-$(date +%s)"
API_URL='http://127.0.0.1:8384'
CURL_OPTS=(-sS)

api() {
	local method=$1
	local path=$2
	local body=${3:-}
	local tmp status

	tmp=$(mktemp)
	if [[ -n "$body" ]]; then
		status=$(curl "${CURL_OPTS[@]}" -o "$tmp" -w '%{http_code}' \
			-X "$method" \
			-H "X-API-Key: $API_KEY" \
			-H 'Content-Type: application/json' \
			-d "$body" \
			"$API_URL$path")
	else
		status=$(curl "${CURL_OPTS[@]}" -o "$tmp" -w '%{http_code}' \
			-X "$method" \
			-H "X-API-Key: $API_KEY" \
			"$API_URL$path")
	fi

	if [[ "$status" -lt 200 || "$status" -ge 300 ]]; then
		echo "API $method $path failed (HTTP $status):" >&2
		cat "$tmp" >&2
		rm -f "$tmp"
		return 1
	fi
	rm -f "$tmp"
}

wait_for_api() {
	local i
	for ((i = 1; i <= 30; i++)); do
		if curl "${CURL_OPTS[@]}" -f \
			-H "X-API-Key: $API_KEY" \
			"$API_URL/rest/system/ping" >/dev/null; then
			return 0
		fi
		sleep 1
	done
	echo "Syncthing API did not become ready at $API_URL" >&2
	return 1
}

echo '[1/6] Ensuring Syncthing config exists...'
mkdir -p "$CONFIG_DIR"
syncthing generate >/dev/null

API_KEY=$(sed -n 's/.*<apikey>\(.*\)<\/apikey>.*/\1/p' "$CONFIG_DIR/config.xml")
LOCAL_ID=$(syncthing device-id)
if [[ -z "$API_KEY" || -z "$LOCAL_ID" ]]; then
	echo "Failed to read API key or local device ID from $CONFIG_DIR" >&2
	exit 1
fi

gui_tls=$(sed -n 's/.*<gui[^>]*tls="\([^"]*\)".*/\1/p' "$CONFIG_DIR/config.xml")
gui_addr=$(sed -n 's|.*<address>\(.*\)</address>.*|\1|p' "$CONFIG_DIR/config.xml" | head -n1)
if [[ -n "$gui_addr" ]]; then
	if [[ "$gui_tls" == 'true' ]]; then
		API_URL="https://$gui_addr"
		CURL_OPTS=(-sS -k)
	else
		API_URL="http://$gui_addr"
	fi
fi

echo '[2/6] Enabling and starting syncthing user service...'
systemctl --user enable --now syncthing.service

echo '[3/6] Waiting for Syncthing API...'
wait_for_api

echo "[4/6] Adding remote device ($REMOTE_ID)..."
api POST /rest/config/devices \
	"{\"deviceID\":\"$REMOTE_ID\",\"name\":\"Remote-Machine\",\"autoAcceptFolders\":true}"

echo "[5/6] Creating folder path $FOLDER_PATH..."
mkdir -p "$FOLDER_PATH"

echo "[6/6] Sharing folder (id=$FOLDER_ID)..."
api POST /rest/config/folders \
	"{\"id\":\"$FOLDER_ID\",\"label\":\"Auto-Shared-Folder\",\"path\":\"$FOLDER_PATH\",\"type\":\"sendreceive\",\"devices\":[{\"deviceID\":\"$LOCAL_ID\"},{\"deviceID\":\"$REMOTE_ID\"}]}"

echo
echo "Done. Local device ID: $LOCAL_ID"
echo "Folder ID: $FOLDER_ID"
echo "Path: $FOLDER_PATH"
echo "On the remote, accept this device (and the folder if prompted)."
