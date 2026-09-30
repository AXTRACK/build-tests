#!/usr/bin/env bash
set -euo pipefail

fail() { echo "ERROR: $*" >&2; exit 1; }
warn() { echo "WARN: $*" >&2; }
info() { echo "OK: $*"; }

command -v docker >/dev/null 2>&1 || fail "docker is not installed or not in PATH"
docker info >/dev/null 2>&1 || fail "docker daemon is not reachable"

arch="$(uname -m)"
case "$arch" in
  x86_64|amd64) info "architecture $arch is compatible with linux/amd64 images" ;;
  *) fail "unsupported architecture for current prebuilt images: $arch" ;;
esac

if docker compose version >/dev/null 2>&1; then
  info "docker compose is available"
else
  fail "docker compose plugin is not available"
fi

root="${AGENT_NOTIFY_ROOT:-/volume1/docker/agent-notify}"
mkdir -p "$root" || fail "cannot create $root"
test -w "$root" || fail "$root is not writable"
info "deployment root is writable: $root"

free_kb="$(df -Pk "$root" | awk 'NR==2 {print $4}')"
if [ "${free_kb:-0}" -lt 5242880 ]; then
  warn "less than 5 GiB free under $root"
else
  info "at least 5 GiB free under $root"
fi

for port in 8081 8082 8000; do
  if command -v ss >/dev/null 2>&1 && ss -ltn | awk '{print $4}' | grep -Eq "[:.]${port}$"; then
    warn "port $port is already listening"
  fi
done

echo "PREFLIGHT_PASS"
