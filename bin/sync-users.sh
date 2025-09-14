#!/bin/sh

# Periodically sync users from API to local fallback JSON.
# Defaults are suitable for the binauth.sh integration.

API_URL="${API_URL:-https://ugly-kordula-cornedpotato69-46ad695b.koyeb.app/api/users}"
OUTPUT="${USERS_JSON:-/etc/nodogsplash/users.json}"
LOG_DIR="${LOG_DIR:-/tmp/nodogsplash}"
LOG_FILE="$LOG_DIR/sync-users.log"

mkdir -p "$LOG_DIR" 2>/dev/null || true

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') [sync-users] $*" >> "$LOG_FILE" 2>/dev/null || true
}

# Ensure curl and jq are available
if ! command -v curl >/dev/null 2>&1; then
  log "curl not found"
  logger -t nds-sync-users "curl not found"
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  log "jq not found"
  logger -t nds-sync-users "jq not found"
  exit 1
fi

TMPFILE=$(mktemp /tmp/users.json.XXXXXX) || exit 1
trap 'rm -f "$TMPFILE"' EXIT INT TERM

# Fetch and validate
RESP=$(curl -sf --connect-timeout 3 --max-time 10 "$API_URL" 2>/dev/null)
if [ $? -ne 0 ] || [ -z "$RESP" ]; then
  log "Failed to fetch from $API_URL"
  logger -t nds-sync-users "Fetch failed $API_URL"
  exit 1
fi

echo "$RESP" | jq -e 'type == "array"' >/dev/null 2>&1
if [ $? -ne 0 ]; then
  log "Invalid JSON (not an array) from $API_URL"
  logger -t nds-sync-users "Invalid JSON from API"
  exit 1
fi

echo "$RESP" > "$TMPFILE"

# Ensure destination dir
DESTDIR=$(dirname "$OUTPUT")
mkdir -p "$DESTDIR" 2>/dev/null || true

# Atomically move into place (backup previous)
if [ -f "$OUTPUT" ]; then
  cp -f "$OUTPUT" "$OUTPUT.bak" 2>/dev/null || true
fi
mv -f "$TMPFILE" "$OUTPUT"

log "Synced users to $OUTPUT from $API_URL"
logger -t nds-sync-users "Synced users to $OUTPUT"
exit 0

