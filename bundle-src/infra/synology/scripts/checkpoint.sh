#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
root=".rollback/$stamp"
mkdir -p "$root"

cp compose.yaml "$root/compose.yaml"
cp .env "$root/.env"
cp config/acl.yaml "$root/acl.yaml"
cp stack.lock.json "$root/stack.lock.json"

docker compose -f compose.yaml images --format json > "$root/images.json" 2>/dev/null || true

backup_path="$(bash backup.sh)"
printf '%s\n' "$backup_path" > "$root/data-backup-path.txt"

ln -sfn "$stamp" .rollback/latest

echo "$root"
echo "CHECKPOINT_PASS"
