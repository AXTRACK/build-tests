#!/usr/bin/env bash
set -euo pipefail

SOURCE_COMMIT="e3e9dd8e5b3d7ab8537cd5a10dc31d5ffa8f82d1"
SHORT="${SOURCE_COMMIT:0:8}"
IMAGE="ghcr.io/axtrack/telegram-bot-api"
TAG="${IMAGE}:${SHORT}-amd64"
LATEST="${IMAGE}:latest-amd64"
RELEASE_TAG="telegram-bot-api-${SHORT}-amd64"
DIST="$PWD/dist"
mkdir -p "$DIST"

echo "== Build Telegram Bot API image =="
docker build --platform linux/amd64 \
  --build-arg TELEGRAM_BOT_API_COMMIT="$SOURCE_COMMIT" \
  --build-arg BUILD_JOBS=2 \
  -t "$TAG" -t "$LATEST" \
  -f infra/telegram-bot-api/Dockerfile .

echo "== Smoke =="
docker run --rm "$TAG" --version
docker run --rm "$TAG" --help | head -40

echo "== Save image archive =="
docker save "$TAG" | gzip -9 > "$DIST/telegram-bot-api-${SHORT}-linux-amd64.tar.gz"
sha256sum "$DIST/telegram-bot-api-${SHORT}-linux-amd64.tar.gz" | tee "$DIST/SHA256SUMS.txt"

echo "== Push GHCR =="
echo "${GH_TOKEN}" | docker login ghcr.io -u "${GITHUB_ACTOR}" --password-stdin
docker push "$TAG"
docker push "$LATEST"

echo "== Persistent GitHub release =="
if gh release view "$RELEASE_TAG" --repo "$GITHUB_REPOSITORY" >/dev/null 2>&1; then
  gh release upload "$RELEASE_TAG" "$DIST/telegram-bot-api-${SHORT}-linux-amd64.tar.gz" "$DIST/SHA256SUMS.txt" --clobber --repo "$GITHUB_REPOSITORY"
else
  gh release create "$RELEASE_TAG" \
    "$DIST/telegram-bot-api-${SHORT}-linux-amd64.tar.gz" "$DIST/SHA256SUMS.txt" \
    --repo "$GITHUB_REPOSITORY" \
    --target "$GITHUB_SHA" \
    --title "Telegram Bot API ${SHORT} linux/amd64" \
    --notes "Built from official tdlib/telegram-bot-api commit ${SOURCE_COMMIT}. Target: linux/amd64 for Synology DS918+. Image: ${TAG}"
fi

echo "TELEGRAM_BOT_API_BUILD_PASS"
echo "IMAGE=$TAG"
echo "RELEASE=$RELEASE_TAG"
