# Synology operator scripts

These scripts reduce the manual installation path on the target NAS.

## Preflight

```bash
bash preflight.sh
```

Checks Docker, Compose, linux/amd64 architecture, deployment-root write access, free-space threshold, and expected port conflicts.

Default root: `/volume1/docker/agent-notify`. Override with `AGENT_NOTIFY_ROOT`.

## Offline image load

```bash
bash load-release-image.sh image.tar.gz SHA256SUMS.txt
```

The checksum is verified before `docker load`.

## Backup

```bash
bash backup.sh
```

Backs up persistent deployment state that exists under the deployment root and writes a checksum beside the archive. Personal Telegram session files are secret-bearing; protect backup archives accordingly.
