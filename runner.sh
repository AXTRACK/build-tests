#!/usr/bin/env bash
set -euo pipefail

SRC="$GITHUB_WORKSPACE/bundle-src/infra/synology"
DIST="$GITHUB_WORKSPACE/dist"
ROOT="$DIST/agent-notify-synology"
TAG="agent-notify-synology-bundle-v1"

find "$SRC" -type f -name '*.sh' -print0 | xargs -0 -n1 bash -n
python -m json.tool "$SRC/stack.lock.json" >/dev/null

cp "$SRC/.env.example" "$SRC/.env"
sed -i 's/^API_ID=$/API_ID=12345/' "$SRC/.env"
sed -i 's/^API_HASH=$/API_HASH=dummyhash/' "$SRC/.env"
cp "$SRC/config/acl.example.yaml" "$SRC/config/acl.yaml"
(cd "$SRC" && docker compose -f compose.yaml config >/tmp/agent-notify-compose.yaml)
grep -q 'telegram-mcp' /tmp/agent-notify-compose.yaml
grep -q 'telegram-bot-api' /tmp/agent-notify-compose.yaml
rm -f "$SRC/.env" "$SRC/config/acl.yaml"

mkdir -p "$ROOT"
cp -a "$SRC/." "$ROOT/"
cd "$DIST"
tar -czf agent-notify-synology-bundle-v1.tar.gz agent-notify-synology
zip -qr agent-notify-synology-bundle-v1.zip agent-notify-synology
sha256sum agent-notify-synology-bundle-v1.tar.gz agent-notify-synology-bundle-v1.zip > SHA256SUMS.txt

if gh release view "$TAG" --repo "$GITHUB_REPOSITORY" >/dev/null 2>&1; then
  gh release upload "$TAG" agent-notify-synology-bundle-v1.tar.gz agent-notify-synology-bundle-v1.zip SHA256SUMS.txt --clobber --repo "$GITHUB_REPOSITORY"
else
  gh release create "$TAG" agent-notify-synology-bundle-v1.tar.gz agent-notify-synology-bundle-v1.zip SHA256SUMS.txt --repo "$GITHUB_REPOSITORY" --target "$GITHUB_SHA" --title 'Agent Notify Synology Bundle v1' --notes 'Validated deployment bundle for Synology DS918+ / linux-amd64. Includes staged installer, verifier, checkpoint/rollback, backup and prebuilt-image loader.'
fi

echo SYNOLOGY_BUNDLE_PASS
