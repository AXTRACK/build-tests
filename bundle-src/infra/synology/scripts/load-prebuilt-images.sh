#!/usr/bin/env bash
set -euo pipefail

mkdir -p downloads
cd downloads

download_and_verify() {
  local url="$1"
  local file="$2"
  local sha="$3"

  if [[ ! -f "$file" ]]; then
    curl -fL --retry 3 --retry-delay 2 -o "$file" "$url"
  fi

  echo "$sha  $file" | sha256sum -c -
}

download_and_verify   "https://github.com/AXTRACK/build-tests/releases/download/telegram-bot-api-e3e9dd8e-amd64/telegram-bot-api-e3e9dd8e-linux-amd64.tar.gz"   "telegram-bot-api-e3e9dd8e-linux-amd64.tar.gz"   "fcad2a7eceb1eb90811d38cb55ea9d66fff492047ab6731a6ffdf2c01295ca78"

download_and_verify   "https://github.com/AXTRACK/build-tests/releases/download/fast-mcp-telegram-c3779a2f-amd64/fast-mcp-telegram-c3779a2f-linux-amd64.tar.gz"   "fast-mcp-telegram-c3779a2f-linux-amd64.tar.gz"   "cd9109969f39e77adad67c5d742e173da63da73d8ce5f1d62cd168ff98359c20"

download_and_verify   "https://github.com/AXTRACK/build-tests/releases/download/openai-tunnel-client-0.0.15-amd64/openai-tunnel-client-0.0.15-linux-amd64.tar.gz"   "openai-tunnel-client-0.0.15-linux-amd64.tar.gz"   "3b5e53e7e011a4a6b11c282515afab4723678f93804cd0961c193a382cba57eb"

for archive in *.tar.gz; do
  echo "Loading $archive"
  gzip -dc "$archive" | docker load
done

echo "PREBUILT_IMAGES_LOAD_PASS"
