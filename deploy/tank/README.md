# Tank deployment templates

These are **user systemd unit templates** and example configs for a private Tank host. Copy them into `~/.config/systemd/user/` (or your preferred path), edit paths and secrets locally, then `systemctl --user daemon-reload`.

| File | Purpose |
| --- | --- |
| `nobs-api.service` | FastAPI Tank API on port 8000 |
| `nobsdash.service` | Static portfolio site on `127.0.0.1:4173` |
| `cloudflared-nobsdash.service` | Cloudflare Tunnel to the static site |
| `cloudflared-nobsdash.yml.example` | Tunnel ingress template — copy to `~/.config/nobs/` |
| `open-webui.service` | Optional local Open WebUI |
| `open-webui.env.example` | Open WebUI environment template |

Do not commit live tunnel credentials, LAN addresses, or host-specific paths. See [`docs/NOBSDASH_DEPLOYMENT.md`](../docs/NOBSDASH_DEPLOYMENT.md).
