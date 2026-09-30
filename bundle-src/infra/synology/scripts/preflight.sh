#!/usr/bin/env bash
set -euo pipefail

mode="full"
if [[ "${1:-}" == "--preauth" ]]; then
  mode="preauth"
elif [[ -n "${1:-}" ]]; then
  echo "Usage: $0 [--preauth]" >&2
  exit 2
fi

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

if [[ "$mode" == "full" ]] && grep -q "REPLACE_WITH_DIGEST_PRINCIPAL" config/acl.yaml 2>/dev/null; then
  echo "ACL_PLACEHOLDER_NOT_REPLACED"
  fail=1
fi

if [[ "$fail" -ne 0 ]]; then
  if [[ "$mode" == "preauth" ]]; then
    echo "PREAUTH_PREFLIGHT_BLOCKED"
  else
    echo "PREFLIGHT_BLOCKED"
  fi
  exit 2
fi

docker compose -f compose.yaml config >/dev/null

if [[ "$mode" == "preauth" ]]; then
  echo "PREAUTH_PREFLIGHT_PASS"
else
  echo "PREFLIGHT_PASS"
fi
