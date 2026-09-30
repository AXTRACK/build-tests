#!/usr/bin/env bash
set -euo pipefail

SOURCE_COMMIT="c3779a2f4abf093b8fac9d6776b5ad097ff73df5"
SHORT="${SOURCE_COMMIT:0:8}"
IMAGE="ghcr.io/axtrack/fast-mcp-telegram"
TAG="${IMAGE}:${SHORT}-amd64"
LATEST="${IMAGE}:latest-amd64"
RELEASE_TAG="fast-mcp-telegram-${SHORT}-amd64"
WORK="${RUNNER_TEMP}/fast-mcp-telegram"
DIST="$PWD/dist"
mkdir -p "$DIST"

git clone --filter=blob:none https://github.com/leshchenko1979/fast-mcp-telegram.git "$WORK"
cd "$WORK"
git checkout "$SOURCE_COMMIT"

echo "== Build image from pinned upstream source =="
docker build --platform linux/amd64 -t "$TAG" -t "$LATEST" .

echo "== Smoke =="
docker run --rm --entrypoint python "$TAG" -c "import src.server; print('SERVER_IMPORT_PASS')"
docker run --rm --entrypoint python "$TAG" -m src.cli_setup --help >/tmp/setup-help.txt
head -40 /tmp/setup-help.txt

echo "== Save image archive =="
docker save "$TAG" | gzip -9 > "$DIST/fast-mcp-telegram-${SHORT}-linux-amd64.tar.gz"
sha256sum "$DIST/fast-mcp-telegram-${SHORT}-linux-amd64.tar.gz" | tee "$DIST/SHA256SUMS.txt"

echo "== Push GHCR =="
echo "${GH_TOKEN}" | docker login ghcr.io -u "${GITHUB_ACTOR}" --password-stdin
docker push "$TAG"
docker push "$LATEST"

echo "== Persistent GitHub release =="
cd "$GITHUB_WORKSPACE"
if gh release view "$RELEASE_TAG" --repo "$GITHUB_REPOSITORY" >/dev/null 2>&1; then
  gh release upload "$RELEASE_TAG" "$DIST/fast-mcp-telegram-${SHORT}-linux-amd64.tar.gz" "$DIST/SHA256SUMS.txt" --clobber --repo "$GITHUB_REPOSITORY"
else
  gh release create "$RELEASE_TAG"     "$DIST/fast-mcp-telegram-${SHORT}-linux-amd64.tar.gz" "$DIST/SHA256SUMS.txt"     --repo "$GITHUB_REPOSITORY"     --target "$GITHUB_SHA"     --title "fast-mcp-telegram ${SHORT} linux/amd64"     --notes "Built from leshchenko1979/fast-mcp-telegram commit ${SOURCE_COMMIT}. Target: linux/amd64 for Synology DS918+. Image: ${TAG}"
fi

echo "FAST_MCP_TELEGRAM_IMAGE_BUILD_PASS"
echo "IMAGE=$TAG"
echo "RELEASE=$RELEASE_TAG"
