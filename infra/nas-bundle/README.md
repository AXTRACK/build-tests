# Agent Notify Synology Bundle

Target: Synology DS918+ / linux-amd64.

Contents:
- prebuilt fast-mcp-telegram image archive;
- prebuilt official Telegram Bot API image archive;
- compose.yaml;
- .env.example;
- starter fail-closed ACL;
- preflight script.

## Install

1. Verify SHA256SUMS.txt.
2. Load both images:

   gzip -dc images/fast-mcp-telegram-c3779a2f-linux-amd64.tar.gz | docker load
   gzip -dc images/telegram-bot-api-e3e9dd8e-linux-amd64.tar.gz | docker load

3. Copy .env.example to .env and fill API_ID/API_HASH.
4. Copy config/acl.example.yaml to config/acl.yaml.
5. Create data directories.
6. Run the Telegram MCP setup profile to create the personal Telegram session.
7. Replace the ACL principal placeholder.
8. Run scripts/preflight.sh.
9. docker compose up -d.

No personal Telegram credentials or bot token are included in this bundle.
