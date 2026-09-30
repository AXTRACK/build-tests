#!/usr/bin/env bash
set -euo pipefail

set -a
source ./.env
set +a

: "${CONTROL_PLANE_TUNNEL_ID:?CONTROL_PLANE_TUNNEL_ID is required}"
: "${CONTROL_PLANE_API_KEY:?CONTROL_PLANE_API_KEY is required}"
: "${LOCAL_MCP_AUTHORIZATION:?LOCAL_MCP_AUTHORIZATION is required}"

if [[ ! -f config/tunnel-client.yaml ]]; then
  echo "MISSING_FILE: config/tunnel-client.yaml"
  exit 2
fi

docker compose --profile tunnel run --rm openai-tunnel doctor   --profile-file /config/tunnel-client.yaml   --explain

echo "TUNNEL_PREFLIGHT_PASS"
