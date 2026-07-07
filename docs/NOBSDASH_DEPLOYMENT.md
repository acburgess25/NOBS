# nobsdash.com deployment

The NOBS portfolio is deployed to Tank as a static Vite build and published through a locally configured Cloudflare Tunnel.

## Security boundary

- The origin listens only on `127.0.0.1:4173`.
- Cloudflare Tunnel is the only public path to the site.
- No router port forwarding or public Tank administration endpoint is required.
- Tunnel credentials live only on the Tank host (for example `~/.config/nobs/<tunnel-uuid>.json`) with mode `0600`.
- The ingress configuration maps both `nobsdash.com` and `www.nobsdash.com` to `http://127.0.0.1:4173` and ends with a 404 catch-all.
- Remove temporary Cloudflare login certificates and connector tokens after provisioning.

## Build and deploy

From the repository root on your workstation:

```bash
cd website
pnpm install
pnpm run build
rsync -az --delete dist/ tank:~/services/nobsdash/current/
```

Install the checked-in user service template from `deploy/tank/nobsdash.service` at:

```text
~/.config/systemd/user/nobsdash.service
```

After replacing the static build, restart the origin and verify it locally on Tank:

```bash
systemctl --user restart nobsdash.service
curl --fail --silent --show-error http://127.0.0.1:4173/
```

## Cloudflare tunnel route

Copy `deploy/tank/cloudflared-nobsdash.yml.example` to `~/.config/nobs/cloudflared-nobsdash.yml`, replace `YOUR_TUNNEL_UUID` and `YOUR_USER`, and install `deploy/tank/cloudflared-nobsdash.service` as a user unit.

| Public hostname | Origin service |
| --- | --- |
| `nobsdash.com` | `http://127.0.0.1:4173` |
| `www.nobsdash.com` | `http://127.0.0.1:4173` |

Keep tunnel credentials out of Git and shell history.

Enable lingering for the Tank user so user services survive logout:

```bash
loginctl enable-linger "$USER"
loginctl show-user "$USER" -p Linger
```

## Operations

```bash
systemctl --user status nobsdash.service cloudflared-nobsdash.service
journalctl --user -u nobsdash.service -u cloudflared-nobsdash.service --since today
```

Rollback is a static-file replacement followed by `systemctl --user restart nobsdash.service`. Stopping `cloudflared-nobsdash.service` removes public access without exposing the origin.
