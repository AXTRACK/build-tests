#!/usr/bin/env bash
set -euo pipefail

root="${AGENT_NOTIFY_ROOT:-/volume1/docker/agent-notify}"
dest="${1:-$root/backups}"
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$dest"

items=(
  "$root/fast-mcp/sessions"
  "$root/gateway/data"
  "$root/gateway/sqlite"
  "$root/telegram-bot-api/data"
)

existing=()
for item in "${items[@]}"; do
  [ -e "$item" ] && existing+=("$item")
done

if [ "${#existing[@]}" -eq 0 ]; then
  echo "No deployment data found under $root" >&2
  exit 1
fi

archive="$dest/agent-notify-backup-$stamp.tar.gz"
tar -czf "$archive" "${existing[@]}"
sha256sum "$archive" > "$archive.sha256"
echo "$archive"
