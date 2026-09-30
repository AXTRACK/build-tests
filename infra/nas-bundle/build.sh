#!/usr/bin/env bash
set -euo pipefail
BUNDLE="agent-notify-synology-bundle-v2"
ROOT="$PWD/$BUNDLE"
mkdir -p "$ROOT/images" "$ROOT/config" "$ROOT/scripts"

gh release download telegram-bot-api-e3e9dd8e-amd64 --repo "$GITHUB_REPOSITORY"   --pattern 'telegram-bot-api-e3e9dd8e-linux-amd64.tar.gz' --dir "$ROOT/images"
gh release download fast-mcp-telegram-c3779a2f-amd64 --repo "$GITHUB_REPOSITORY"   --pattern 'fast-mcp-telegram-c3779a2f-linux-amd64.tar.gz' --dir "$ROOT/images"
gh release download openai-tunnel-client-0.0.15-amd64 --repo "$GITHUB_REPOSITORY"   --pattern 'openai-tunnel-client-0.0.15-linux-amd64.tar.gz' --dir "$ROOT/images"

cp infra/nas-bundle/compose.yaml "$ROOT/compose.yaml"
cp infra/nas-bundle/env.example "$ROOT/.env.example"
cp infra/nas-bundle/acl.example.yaml "$ROOT/config/acl.example.yaml"
cp infra/nas-bundle/tunnel-client.example.yaml "$ROOT/config/tunnel-client.example.yaml"
cp infra/nas-bundle/preflight.sh "$ROOT/scripts/preflight.sh"
cp infra/nas-bundle/tunnel-preflight.sh "$ROOT/scripts/tunnel-preflight.sh"
cp infra/nas-bundle/README.md "$ROOT/README.md"
chmod +x "$ROOT/scripts/"*.sh

echo "== Load and smoke all images =="
gzip -dc "$ROOT/images/telegram-bot-api-e3e9dd8e-linux-amd64.tar.gz" | docker load
gzip -dc "$ROOT/images/fast-mcp-telegram-c3779a2f-linux-amd64.tar.gz" | docker load
gzip -dc "$ROOT/images/openai-tunnel-client-0.0.15-linux-amd64.tar.gz" | docker load

docker run --rm ghcr.io/axtrack/telegram-bot-api:e3e9dd8e-amd64 --version
docker run --rm --entrypoint python ghcr.io/axtrack/fast-mcp-telegram:c3779a2f-amd64 -c "import src.server; print('FAST_MCP_IMPORT_PASS')"
docker run --rm ghcr.io/axtrack/openai-tunnel-client:0.0.15-amd64 --version

echo "== Compose syntax =="
cp "$ROOT/.env.example" "$ROOT/.env"
cp "$ROOT/config/acl.example.yaml" "$ROOT/config/acl.yaml"
cp "$ROOT/config/tunnel-client.example.yaml" "$ROOT/config/tunnel-client.yaml"
(
  cd "$ROOT"
  API_ID=1 API_HASH=dummy TELEGRAM_API_ID=1 TELEGRAM_API_HASH=dummy docker compose --profile tunnel config >/dev/null
)
rm "$ROOT/.env" "$ROOT/config/acl.yaml" "$ROOT/config/tunnel-client.yaml"

echo "== Package =="
tar -C "$PWD" -czf "$PWD/${BUNDLE}.tar.gz" "$BUNDLE"
sha256sum "$PWD/${BUNDLE}.tar.gz" > "$PWD/SHA256SUMS.txt"

if gh release view "$BUNDLE" --repo "$GITHUB_REPOSITORY" >/dev/null 2>&1; then
  gh release upload "$BUNDLE" "$PWD/${BUNDLE}.tar.gz" "$PWD/SHA256SUMS.txt" --clobber --repo "$GITHUB_REPOSITORY"
else
  gh release create "$BUNDLE" "$PWD/${BUNDLE}.tar.gz" "$PWD/SHA256SUMS.txt"     --repo "$GITHUB_REPOSITORY" --target "$GITHUB_SHA"     --title "Agent Notify Synology bundle v2"     --notes "Prebuilt stack with Telegram MCP, Local Bot API and OpenAI Secure MCP Tunnel client."
fi

echo "AGENT_NOTIFY_NAS_BUNDLE_V2_PASS"
