#!/usr/bin/env bash
set -euo pipefail

VERSION="v0.0.15"
SHORT="0.0.15"
IMAGE="ghcr.io/axtrack/openai-tunnel-client"
TAG="${IMAGE}:${SHORT}-amd64"
LATEST="${IMAGE}:latest-amd64"
RELEASE_TAG="openai-tunnel-client-${SHORT}-amd64"
DIST="$PWD/dist"
mkdir -p "$DIST"

docker build --platform linux/amd64 -t "$TAG" -t "$LATEST" -f infra/openai-tunnel-client/Dockerfile .

echo "== Smoke =="
docker run --rm "$TAG" help quickstart | head -80
docker run --rm "$TAG" --help | head -80

docker save "$TAG" | gzip -9 > "$DIST/openai-tunnel-client-${SHORT}-linux-amd64.tar.gz"
sha256sum "$DIST/openai-tunnel-client-${SHORT}-linux-amd64.tar.gz" | tee "$DIST/SHA256SUMS.txt"

echo "${GH_TOKEN}" | docker login ghcr.io -u "${GITHUB_ACTOR}" --password-stdin
docker push "$TAG"
docker push "$LATEST"

if gh release view "$RELEASE_TAG" --repo "$GITHUB_REPOSITORY" >/dev/null 2>&1; then
  gh release upload "$RELEASE_TAG" "$DIST/openai-tunnel-client-${SHORT}-linux-amd64.tar.gz" "$DIST/SHA256SUMS.txt" --clobber --repo "$GITHUB_REPOSITORY"
else
  gh release create "$RELEASE_TAG"     "$DIST/openai-tunnel-client-${SHORT}-linux-amd64.tar.gz" "$DIST/SHA256SUMS.txt"     --repo "$GITHUB_REPOSITORY" --target "$GITHUB_SHA"     --title "OpenAI tunnel-client ${VERSION} linux/amd64"     --notes "Containerized from official openai/tunnel-client ${VERSION} linux-amd64 release. Target: Synology DS918+."
fi

echo "OPENAI_TUNNEL_CLIENT_BUILD_PASS"
echo "IMAGE=$TAG"
echo "RELEASE=$RELEASE_TAG"
