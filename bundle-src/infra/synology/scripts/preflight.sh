#!/usr/bin/env bash
set -euo pipefail

fail=0

required_files=(
  ".env"
  "config/acl.yaml"
  "compose.yaml"
)

for file in "${required_files[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "MISSING_FILE: $file"
    fail=1
  fi
done

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source ./.env
  set +a

  for name in API_ID API_HASH; do
    if [[ -z "${!name:-}" ]]; then
      echo "MISSING_ENV: $name"
      fail=1
    fi
  done
fi

if grep -q "REPLACE_WITH_DIGEST_PRINCIPAL" config/acl.yaml 2>/dev/null; then
  echo "ACL_PLACEHOLDER_NOT_REPLACED"
  fail=1
fi

if [[ "$fail" -ne 0 ]]; then
  echo "PREFLIGHT_BLOCKED"
  exit 2
fi

docker compose -f compose.yaml config >/dev/null

echo "PREFLIGHT_PASS"
