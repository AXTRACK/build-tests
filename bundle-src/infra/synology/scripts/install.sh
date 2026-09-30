#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

fail() { echo "ERROR: $*" >&2; exit 1; }
info() { echo "== $* =="; }

[[ -f compose.yaml ]] || fail "compose.yaml not found"

info "Bootstrap configuration"
bash scripts/bootstrap.sh

info "Preflight"
bash scripts/preflight.sh

if [[ "${SKIP_IMAGE_LOAD:-0}" != "1" ]]; then
  info "Load pinned prebuilt images"
  bash scripts/load-prebuilt-images.sh
fi

if [[ "${EUID}" -eq 0 ]]; then
  info "Prepare persistent-volume permissions"
  bash scripts/prepare-permissions.sh
else
  echo "NOTICE: volume ownership still needs root. Run: sudo bash scripts/prepare-permissions.sh"
fi

set -a
source ./.env
set +a

: "${API_ID:?Fill API_ID in .env}"
: "${API_HASH:?Fill API_HASH in .env}"

info "Validate compose configuration"
docker compose -f compose.yaml config >/dev/null

info "Start Local Telegram Bot API"
docker compose -f compose.yaml up -d telegram-bot-api

if [[ -z "${LOCAL_MCP_AUTHORIZATION:-}" ]]; then
  cat <<'EOF'

MANUAL_GATE: Telegram user authorization is required.

Run the QR setup now:
  docker compose -f compose.yaml --profile setup run --rm telegram-mcp-setup

Then place the returned bearer value in .env:
  LOCAL_MCP_AUTHORIZATION=Bearer <token>

Then run:
  bash scripts/configure-acl-from-bearer.sh
  edit config/acl.yaml and replace the starter chat lane with approved sources
  bash scripts/install.sh
EOF
  exit 10
fi

if grep -q 'REPLACE_WITH_DIGEST_PRINCIPAL' config/acl.yaml; then
  info "Configure ACL principal from bearer"
  bash scripts/configure-acl-from-bearer.sh
fi

if grep -q 'REPLACE_WITH_DIGEST_PRINCIPAL' config/acl.yaml; then
  fail "ACL principal placeholder still exists"
fi

info "Start Telegram MCP"
docker compose -f compose.yaml up -d telegram-mcp

info "Verify core stack"
bash scripts/verify.sh

echo "INSTALL_CORE_PASS"
echo "Tunnel and owner-bot activation remain separate gated steps."
