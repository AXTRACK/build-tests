#!/usr/bin/env bash
set -euo pipefail

echo "== Containers =="
docker compose -f compose.yaml ps

echo "== MCP health =="
docker compose -f compose.yaml exec -T telegram-mcp curl -fsS http://127.0.0.1:8000/health

echo
echo "== Local Bot API stats port =="
docker compose -f compose.yaml exec -T telegram-bot-api bash -lc "exec 3<>/dev/tcp/127.0.0.1/8082"

echo
echo "STACK_SMOKE_PASS"
