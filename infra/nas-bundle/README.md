# Agent Notify Synology Bundle v2

Secret-free installation bundle for Synology DS918+ / linux-amd64.

Includes three prebuilt images:

- fast-mcp-telegram c3779a2f;
- Telegram Bot API 10.3;
- OpenAI tunnel-client v0.0.15.

Also includes:

- compose.yaml;
- environment template;
- fail-closed ACL starter;
- OpenAI tunnel profile template;
- core preflight script;
- tunnel doctor script.

## Install

1. Verify SHA256SUMS.txt.
2. Load all three image archives from images/.
3. Copy .env.example to .env.
4. Copy config/acl.example.yaml to config/acl.yaml.
5. Copy config/tunnel-client.example.yaml to config/tunnel-client.yaml when enabling Secure MCP Tunnel.
6. Create data directories.
7. Run the Telegram MCP setup profile and authenticate by QR.
8. Replace the ACL principal placeholder.
9. Run scripts/preflight.sh.
10. Start telegram-mcp and telegram-bot-api.
11. When OpenAI tunnel credentials/tunnel_id exist, fill them and run scripts/tunnel-preflight.sh.
12. Start with --profile tunnel.

No credentials or Telegram sessions are included.
