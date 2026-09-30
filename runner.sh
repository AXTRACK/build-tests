#!/usr/bin/env bash
set -euo pipefail

WORK="$RUNNER_TEMP/agent-notify-e2e"
mkdir -p "$WORK"
cd "$WORK"

echo "== Download validated deployment bundle =="
gh release download agent-notify-synology-bundle-v1 --repo AXTRACK/build-tests --pattern 'agent-notify-synology-bundle-v1.tar.gz' --pattern 'SHA256SUMS.txt'
grep 'agent-notify-synology-bundle-v1.tar.gz' SHA256SUMS.txt | sha256sum -c -

tar -xzf agent-notify-synology-bundle-v1.tar.gz
cd agent-notify-synology

echo "== Static validation =="
find . -type f -name '*.sh' -print0 | xargs -0 -n1 bash -n
python -m json.tool stack.lock.json >/dev/null

cp .env.example .env
sed -i 's/^API_ID=$/API_ID=12345/' .env
sed -i 's/^API_HASH=$/API_HASH=dummyhash/' .env
cp config/acl.example.yaml config/acl.yaml

docker compose -f compose.yaml config >/tmp/agent-notify-compose.yaml
grep -q 'telegram-mcp' /tmp/agent-notify-compose.yaml
grep -q 'telegram-bot-api' /tmp/agent-notify-compose.yaml
echo "COMPOSE_RENDER_PASS"

echo "== Real preflight on disposable VM =="
export AGENT_NOTIFY_ROOT="$WORK/nas-root"
bash preflight.sh

echo "== Download/load real pinned images =="
bash scripts/load-prebuilt-images.sh
docker image inspect ghcr.io/axtrack/fast-mcp-telegram:c3779a2f-amd64 >/dev/null
docker image inspect ghcr.io/axtrack/telegram-bot-api:e3e9dd8e-amd64 >/dev/null
echo "IMAGE_LOAD_PASS"

echo "== Execute real installer until unavoidable QR gate =="
set +e
SKIP_IMAGE_LOAD=1 bash scripts/install.sh >"$WORK/install-first.log" 2>&1
install_rc=$?
set -e
cat "$WORK/install-first.log"
[[ "$install_rc" -eq 10 ]] || { echo "Expected exit 10 at QR gate, got $install_rc" >&2; exit 1; }
grep -q 'MANUAL_GATE: Telegram user authorization is required.' "$WORK/install-first.log"
echo "QR_GATE_PASS"

echo "== Confirm Local Bot API container creation and binary =="
docker compose -f compose.yaml ps -a telegram-bot-api
docker inspect agent-notify-telegram-bot-api >/dev/null
docker run --rm --entrypoint /usr/local/bin/telegram-bot-api ghcr.io/axtrack/telegram-bot-api:e3e9dd8e-amd64 --version 2>&1 | grep -q 'Bot API'
echo "LOCAL_BOT_CONTAINER_CREATE_PASS"
echo "LOCAL_BOT_BINARY_PASS"
echo "NOTE: long-running Local Bot API health cannot be proven with dummy API_ID/API_HASH."

echo "== Verify fails closed before real Telegram session =="
set +e
bash scripts/verify.sh >"$WORK/verify-preauth.log" 2>&1
verify_rc=$?
set -e
cat "$WORK/verify-preauth.log"
[[ "$verify_rc" -ne 0 ]] || { echo "verify unexpectedly passed without Telegram session" >&2; exit 1; }
grep -Eq 'ACL principal placeholder still present|no Telegram session file found' "$WORK/verify-preauth.log"
echo "VERIFY_FAIL_CLOSED_PASS"

echo "== Backup primitive with real filesystem =="
mkdir -p "$AGENT_NOTIFY_ROOT/gateway/data"
printf 'probe\n' >"$AGENT_NOTIFY_ROOT/gateway/data/probe.txt"
backup_path="$(bash backup.sh "$WORK/backups")"
test -f "$backup_path"
test -f "$backup_path.sha256"
(cd "$(dirname "$backup_path")" && sha256sum -c "$(basename "$backup_path").sha256")
tar -tzf "$backup_path" | grep -q 'probe.txt'
echo "BACKUP_PASS"

echo "== Checkpoint primitive =="
checkpoint_output="$(bash scripts/checkpoint.sh)"
printf '%s\n' "$checkpoint_output"
checkpoint_path="$(printf '%s\n' "$checkpoint_output" | head -1)"
test -d "$checkpoint_path"
for f in compose.yaml .env acl.yaml stack.lock.json data-backup-path.txt; do test -f "$checkpoint_path/$f"; done
echo "CHECKPOINT_PASS"

echo "== Rollback restores configuration and still fails closed without Telegram session =="
cp .env "$WORK/env.original"
printf '\nROLLBACK_PROBE=changed\n' >> .env
set +e
bash scripts/rollback.sh "$checkpoint_path" >"$WORK/rollback.log" 2>&1
rollback_rc=$?
set -e
cat "$WORK/rollback.log"
cmp -s .env "$WORK/env.original"
[[ "$rollback_rc" -ne 0 ]] || { echo "rollback incorrectly claimed full success without Telegram session" >&2; exit 1; }
echo "ROLLBACK_CONFIG_RESTORE_PASS"

echo "== Idempotent rerun of bootstrap/preflight/config =="
bash scripts/bootstrap.sh
bash preflight.sh
docker compose -f compose.yaml config >/dev/null
echo "RERUN_PASS"

docker compose -f compose.yaml down --remove-orphans || true

echo "AGENT_NOTIFY_INSTALL_E2E_PREAUTH_PASS"
