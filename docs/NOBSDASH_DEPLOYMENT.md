# nobsdash.com deployment

The NOBS portfolio is deployed to Tank as a static Vite build and published through a locally configured Cloudflare Tunnel.

## Security boundary

- The origin listens only on `127.0.0.1:4173`.
- Cloudflare Tunnel is the only public path to the site.
- No router port forwarding or public Tank administration endpoint is required.
- The tunnel credentials live only in `/home/alex/.config/nobs/795c612c-a1d6-488e-8045-b62c5a4e8ef7.json` on Tank with mode `0600`.
- The local ingress configuration maps both `nobsdash.com` and `www.nobsdash.com` to `http://127.0.0.1:4173` and ends with a 404 catch-all.
- The temporary Cloudflare login certificate and connector token are removed after provisioning.

## Build and deploy

From the repository root on macOS:

```bash
cd website
pnpm install
pnpm run build
rsync -az --delete dist/ tank:/home/alex/services/nobsdash/current/
```

The checked-in user service is installed at:

```text
~/.config/systemd/user/nobsdash.service
```

After replacing the static build, restart the origin and verify it locally on Tank:

```bash
systemctl --user restart nobsdash.service
curl --fail --silent --show-error http://127.0.0.1:4173/
```

## Cloudflare tunnel route

The existing tunnel named `tank` uses the checked-in ingress template at `deploy/tank/cloudflared-nobsdash.yml`:

| Public hostname | Origin service |
| --- | --- |
| `nobsdash.com` | `http://127.0.0.1:4173` |
| `www.nobsdash.com` | `http://127.0.0.1:4173` |

Both proxied DNS CNAME records point to `795c612c-a1d6-488e-8045-b62c5a4e8ef7.cfargotunnel.com`. Keep tunnel credentials out of Git and shell history.

Persistent user services are enabled with `loginctl enable-linger alex`. Verify the result with `loginctl show-user alex -p Linger`.

## Operations

```bash
systemctl --user status nobsdash.service cloudflared-nobsdash.service
journalctl --user -u nobsdash.service -u cloudflared-nobsdash.service --since today
```

Rollback is a static-file replacement followed by `systemctl --user restart nobsdash.service`. Stopping `cloudflared-nobsdash.service` removes public access without exposing the origin.
