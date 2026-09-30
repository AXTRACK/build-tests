#!/usr/bin/env bash
set -euo pipefail

set -a
source ./.env
set +a

: "${OWNER_BOT_TOKEN:?OWNER_BOT_TOKEN is required}"

echo "This logs the bot out from Telegram's cloud Bot API before local-server use."
echo "No local migration is performed unless cloud logOut succeeds."

response="$(curl -fsS -X POST "https://api.telegram.org/bot${OWNER_BOT_TOKEN}/logOut")"
echo "$response"

if ! grep -q '"ok":true' <<<"$response"; then
  echo "CLOUD_BOT_LOGOUT_FAILED"
  exit 1
fi

echo "CLOUD_BOT_LOGOUT_PASS"
echo "Start/keep telegram-bot-api running, then validate with:"
echo "  bash scripts/validate-local-bot.sh"
