#!/usr/bin/env bash
set -euo pipefail
fail=0
for file in .env config/acl.yaml compose.yaml; do
  [[ -f "$file" ]] || { echo "MISSING_FILE: $file"; fail=1; }
done
if [[ -f .env ]]; then
  set -a
  source ./.env
  set +a
  for name in API_ID API_HASH TELEGRAM_API_ID TELEGRAM_API_HASH; do
    [[ -n "${!name:-}" ]] || { echo "MISSING_ENV: $name"; fail=1; }
  done
fi
grep -q REPLACE_WITH_DIGEST_PRINCIPAL config/acl.yaml 2>/dev/null && { echo ACL_PLACEHOLDER_NOT_REPLACED; fail=1; }
[[ "$fail" -eq 0 ]] || { echo PREFLIGHT_BLOCKED; exit 2; }
docker compose -f compose.yaml config >/dev/null
echo PREFLIGHT_PASS
