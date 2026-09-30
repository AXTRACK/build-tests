#!/usr/bin/env bash
set -euo pipefail
set -a; source ./.env; set +a

: "${CONTROL_PLANE_API_KEY:?CONTROL_PLANE_API_KEY is required}"
: "${LOCAL_MCP_AUTHORIZATION:?LOCAL_MCP_AUTHORIZATION is required}"

grep -q REPLACE_WITH_TUNNEL_ID config/tunnel-client.yaml && {
  echo "TUNNEL_ID_PLACEHOLDER_NOT_REPLACED"
  exit 2
}

docker compose --profile tunnel run --rm openai-tunnel doctor   --profile-file /config/tunnel-client.yaml   --explain

echo "TUNNEL_PREFLIGHT_PASS"
