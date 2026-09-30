#!/usr/bin/env bash
set -euo pipefail

mkdir -p   config   data/telegram-sessions   data/telegram-bot-api   data/tunnel-client/logs

if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "CREATED: .env"
fi

if [[ ! -f config/acl.yaml ]]; then
  cp config/acl.example.yaml config/acl.yaml
  echo "CREATED: config/acl.yaml"
fi

if [[ -f config/tunnel-client.example.yaml && ! -f config/tunnel-client.yaml ]]; then
  cp config/tunnel-client.example.yaml config/tunnel-client.yaml
  echo "CREATED: config/tunnel-client.yaml"
fi

echo
echo "NEXT:"
echo "1. Fill API_ID/API_HASH in .env."
echo "2. Run: docker compose --profile setup run --rm telegram-mcp-setup"
echo "3. Replace the ACL principal placeholder in config/acl.yaml."
echo "4. Run: bash scripts/preflight.sh"
echo "5. Start core stack: docker compose up -d telegram-mcp telegram-bot-api"
echo
echo "For Secure MCP Tunnel later:"
echo "6. Fill CONTROL_PLANE_API_KEY and LOCAL_MCP_AUTHORIZATION in .env."
echo "7. Replace tunnel_id in config/tunnel-client.yaml."
echo "8. Run: bash scripts/tunnel-preflight.sh"
echo "9. Start tunnel: docker compose --profile tunnel up -d openai-tunnel"

echo "BOOTSTRAP_PREP_PASS"
