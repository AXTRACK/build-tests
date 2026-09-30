#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "Creating rollback checkpoint before applying the currently staged stack definition..."
checkpoint_output="$(bash scripts/checkpoint.sh)"
checkpoint="$(printf '%s\n' "$checkpoint_output" | head -1)"
echo "Checkpoint: $checkpoint"

if [[ "${SKIP_IMAGE_LOAD:-0}" != "1" ]]; then
  bash scripts/load-prebuilt-images.sh
fi

docker compose -f compose.yaml config >/dev/null
docker compose -f compose.yaml up -d

if bash scripts/verify.sh; then
  echo "UPGRADE_PASS"
  exit 0
fi

echo "Upgrade verification failed; applying configuration rollback." >&2
bash scripts/rollback.sh "$checkpoint"
echo "UPGRADE_FAILED_ROLLED_BACK" >&2
exit 1
