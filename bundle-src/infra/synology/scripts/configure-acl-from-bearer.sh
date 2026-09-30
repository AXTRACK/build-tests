#!/usr/bin/env bash
set -euo pipefail

set -a
source ./.env
set +a

: "${LOCAL_MCP_AUTHORIZATION:?LOCAL_MCP_AUTHORIZATION is required}"

prefix="Bearer "
if [[ "$LOCAL_MCP_AUTHORIZATION" != "$prefix"* ]]; then
  echo "LOCAL_MCP_AUTHORIZATION must start with 'Bearer '"
  exit 2
fi

principal="${LOCAL_MCP_AUTHORIZATION#Bearer }"
if [[ -z "$principal" ]]; then
  echo "Empty bearer principal"
  exit 2
fi

acl="config/acl.yaml"
[[ -f "$acl" ]] || { echo "MISSING_FILE: $acl"; exit 2; }

if grep -q "REPLACE_WITH_DIGEST_PRINCIPAL" "$acl"; then
  python3 - "$acl" "$principal" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
principal = sys.argv[2]
text = path.read_text(encoding="utf-8")
text = text.replace("REPLACE_WITH_DIGEST_PRINCIPAL", principal, 1)
path.write_text(text, encoding="utf-8")
PY
  echo "ACL_PRINCIPAL_CONFIGURED"
else
  echo "ACL principal placeholder is already absent; no change made."
fi

echo "Review config/acl.yaml and replace the starter 'me' lane with the exact digest sources before unattended use."
