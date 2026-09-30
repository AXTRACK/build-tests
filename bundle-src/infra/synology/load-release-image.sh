#!/usr/bin/env bash
set -euo pipefail

archive="${1:-}"
checksum_file="${2:-}"

if [ -z "$archive" ] || [ -z "$checksum_file" ]; then
  echo "Usage: $0 <image.tar.gz> <SHA256SUMS.txt>" >&2
  exit 2
fi

test -f "$archive"
test -f "$checksum_file"

(
  cd "$(dirname "$archive")"
  grep " $(basename "$archive")$" "$(basename "$checksum_file")" | sha256sum -c -
)

gzip -dc "$archive" | docker load

echo "IMAGE_LOAD_PASS"
