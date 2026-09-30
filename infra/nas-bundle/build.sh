#!/usr/bin/env bash
set -euo pipefail

BUNDLE="agent-notify-synology-bundle-v1"
ROOT="$PWD/$BUNDLE"
mkdir -p "$ROOT/images" "$ROOT/config" "$ROOT/scripts"

echo "== Download validated image releases =="
gh release download telegram-bot-api-e3e9dd8e-amd64   --repo "$GITHUB_REPOSITORY"   --pattern 'telegram-bot-api-e3e9dd8e-linux-amd64.tar.gz'   --dir "$ROOT/images"

gh release download fast-mcp-telegram-c3779a2f-amd64   --repo "$GITHUB_REPOSITORY"   --pattern 'fast-mcp-telegram-c3779a2f-linux-amd64.tar.gz'   --dir "$ROOT/images"

cp infra/nas-bundle/compose.yaml "$ROOT/compose.yaml"
cp infra/nas-bundle/env.example "$ROOT/.env.example"
cp infra/nas-bundle/acl.example.yaml "$ROOT/config/acl.example.yaml"
cp infra/nas-bundle/preflight.sh "$ROOT/scripts/preflight.sh"
cp infra/nas-bundle/README.md "$ROOT/README.md"
chmod +x "$ROOT/scripts/preflight.sh"

echo "== Validate image archives =="
gzip -dc "$ROOT/images/telegram-bot-api-e3e9dd8e-linux-amd64.tar.gz" | docker load
gzip -dc "$ROOT/images/fast-mcp-telegram-c3779a2f-linux-amd64.tar.gz" | docker load

docker run --rm ghcr.io/axtrack/telegram-bot-api:e3e9dd8e-amd64 --version
docker run --rm --entrypoint python ghcr.io/axtrack/fast-mcp-telegram:c3779a2f-amd64 -c "import src.server; print('FAST_MCP_IMPORT_PASS')"

echo "== Validate compose syntax =="
cp "$ROOT/.env.example" "$ROOT/.env"
cp "$ROOT/config/acl.example.yaml" "$ROOT/config/acl.yaml"
(
  cd "$ROOT"
  API_ID=1 API_HASH=dummy TELEGRAM_API_ID=1 TELEGRAM_API_HASH=dummy docker compose -f compose.yaml config >/dev/null
)
rm "$ROOT/.env" "$ROOT/config/acl.yaml"

echo "== Package bundle =="
tar -C "$PWD" -czf "$PWD/${BUNDLE}.tar.gz" "$BUNDLE"
sha256sum "$PWD/${BUNDLE}.tar.gz" > "$PWD/SHA256SUMS.txt"

RELEASE_TAG="$BUNDLE"
if gh release view "$RELEASE_TAG" --repo "$GITHUB_REPOSITORY" >/dev/null 2>&1; then
  gh release upload "$RELEASE_TAG" "$PWD/${BUNDLE}.tar.gz" "$PWD/SHA256SUMS.txt" --clobber --repo "$GITHUB_REPOSITORY"
else
  gh release create "$RELEASE_TAG"     "$PWD/${BUNDLE}.tar.gz" "$PWD/SHA256SUMS.txt"     --repo "$GITHUB_REPOSITORY"     --target "$GITHUB_SHA"     --title "Agent Notify Synology bundle v1"     --notes "Prebuilt secret-free installation bundle for Synology DS918+ (linux/amd64)."
fi

echo "AGENT_NOTIFY_NAS_BUNDLE_PASS"
echo "RELEASE=$RELEASE_TAG"
