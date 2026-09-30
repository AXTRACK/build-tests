#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this script as root (or via sudo) so numeric container ownership can be prepared."
  exit 2
fi

mkdir -p   data/telegram-sessions   data/telegram-bot-api   data/tunnel-client/logs   config

# fast-mcp-telegram image: appuser uid/gid 1000
chown -R 1000:1000 data/telegram-sessions

# telegram-bot-api image: telegram uid/gid 10001
chown -R 10001:10001 data/telegram-bot-api

# OpenAI tunnel-client image: tunnel uid/gid 10002
chown -R 10002:10002 data/tunnel-client

chmod 700 data/telegram-sessions
chmod 700 data/telegram-bot-api
chmod 700 data/tunnel-client

echo "PERMISSIONS_PREP_PASS"
