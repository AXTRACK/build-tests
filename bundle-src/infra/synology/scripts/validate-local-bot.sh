#!/usr/bin/env bash
set -euo pipefail

set -a
source ./.env
set +a

: "${OWNER_BOT_TOKEN:?OWNER_BOT_TOKEN is required}"

echo "== Local Bot API getMe =="
docker compose exec -T telegram-mcp   curl -fsS "http://telegram-bot-api:8081/bot${OWNER_BOT_TOKEN}/getMe"

echo
echo "LOCAL_BOT_GETME_PASS"
