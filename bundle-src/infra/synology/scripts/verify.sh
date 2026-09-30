#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

fail() { echo "ERROR: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

[[ -f .env ]] || fail ".env missing"
[[ -f config/acl.yaml ]] || fail "config/acl.yaml missing"

docker compose -f compose.yaml config >/dev/null || fail "compose config invalid"
pass "compose config"

for image in \
  ghcr.io/axtrack/fast-mcp-telegram:c3779a2f-amd64 \
  ghcr.io/axtrack/telegram-bot-api:e3e9dd8e-amd64; do
  docker image inspect "$image" >/dev/null 2>&1 || fail "image missing: $image"
done
pass "required images"

grep -q 'REPLACE_WITH_DIGEST_PRINCIPAL' config/acl.yaml && fail "ACL principal placeholder still present"
pass "ACL principal configured"

session_count=$(find data/telegram-sessions -maxdepth 1 -type f -name '*.session*' 2>/dev/null | wc -l | tr -d ' ')
[[ "${session_count:-0}" -gt 0 ]] || fail "no Telegram session file found"
pass "Telegram session persistence file exists"

docker compose -f compose.yaml ps --status running telegram-bot-api | grep -q telegram-bot-api || fail "telegram-bot-api not running"
pass "telegram-bot-api running"

docker compose -f compose.yaml ps --status running telegram-mcp | grep -q telegram-mcp || fail "telegram-mcp not running"
pass "telegram-mcp running"

docker compose -f compose.yaml exec -T telegram-mcp curl -fsS http://127.0.0.1:8000/health >/tmp/agent-notify-mcp-health.json || fail "telegram-mcp health failed"
pass "telegram-mcp health"

docker compose -f compose.yaml exec -T telegram-bot-api bash -lc "exec 3<>/dev/tcp/127.0.0.1/8082" || fail "telegram-bot-api stats port unavailable"
pass "telegram-bot-api stats port"

echo "VERIFY_CORE_PASS"
