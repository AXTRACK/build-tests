#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

checkpoint="${1:-.rollback/latest}"
[[ -e "$checkpoint" ]] || { echo "ERROR: checkpoint not found: $checkpoint" >&2; exit 1; }
checkpoint="$(cd "$checkpoint" && pwd)"

for f in compose.yaml .env acl.yaml stack.lock.json; do
  [[ -f "$checkpoint/$f" ]] || { echo "ERROR: checkpoint file missing: $f" >&2; exit 1; }
done

echo "Restoring configuration from $checkpoint"
cp "$checkpoint/compose.yaml" compose.yaml
cp "$checkpoint/.env" .env
cp "$checkpoint/acl.yaml" config/acl.yaml
cp "$checkpoint/stack.lock.json" stack.lock.json

docker compose -f compose.yaml config >/dev/null
docker compose -f compose.yaml up -d

if bash scripts/verify.sh; then
  echo "ROLLBACK_CONFIG_PASS"
else
  echo "ROLLBACK_CONFIG_APPLIED_BUT_VERIFY_FAILED" >&2
  exit 1
fi

echo "Persistent data was NOT automatically restored."
echo "If a data restore is required, inspect: $checkpoint/data-backup-path.txt"
