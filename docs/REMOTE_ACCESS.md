# Reaching the Tank from outside the house

**Short version:** use a VPN (Tailscale or WireGuard). Never put a reverse
proxy, a Cloudflare tunnel, `tailscale serve`, or `tailscale funnel` in front of
the Tank API port.

Run [`scripts/setup-tank-remote-access.sh`](../scripts/setup-tank-remote-access.sh)
on the Tank while you are at home. It is safe to re-run.

## Why a proxy breaks the security model

The Tank decides whether a request is physically at the Tank by reading the
**connection's peer address**:

```python
# app/pairing.py
def is_loopback_client(host: str | None) -> bool:
    """Return True only when `host` is a literal loopback address."""
```

`require_local_request` in `app/dependencies.py` uses that to gate
`/dashboard/pairing` — the route that hands out the **device token**, the single
credential unlocking every authenticated route. The reasoning is: a loopback
peer means someone is standing at the Tank.

Put anything that proxies in front of port 8000 and that inverts. cloudflared,
nginx, Caddy, `tailscale serve`, and `tailscale funnel` all connect to the API
*from localhost*, so the peer address becomes `127.0.0.1` for every caller. Then:

- every request from the open internet looks like it came from the Tank itself;
- anyone who finds the hostname can `GET /dashboard/pairing`;
- they read the device token and own the Tank — calendar, reminders, agent
  workspace, home control, the lot.

There is no configuration that makes this safe, because the header a proxy would
use to pass the real client address (`X-Forwarded-For`) is supplied by the
caller and can be forged. `is_loopback_client` refuses to read it for exactly
this reason.

## Why a VPN is fine

A VPN keeps the peer address honest. Your phone joins the tailnet and shows up
as `100.x.x.x`, so:

- `is_loopback_client` correctly reports **not local**;
- the pairing routes stay refused from the road, as intended;
- every other route still requires the device token.

Nothing is exposed to the internet, no router ports are opened, and the auth
model is untouched. This is what `PRODUCT_DECISIONS.md` §16 means by
"private-tunnel remote access with no exposed home ports".

## Pair before you leave

Pairing is refused from anywhere that is not the Tank itself — **including over
the VPN**. That is deliberate, not a bug.

So pair each device at the Tank display before you need it remotely. If you are
already away and unpaired, there is no remote path in; someone has to be at the
Tank.

## What the public domain is for

A domain such as `nobsdash.com` should point at the **static site only**, never
the API. The existing tunnel config gets this right:

```yaml
# deploy/tank/cloudflared-nobsdash.yml.example
ingress:
  - hostname: nobsdash.com
    service: http://127.0.0.1:4173   # the built website, not port 8000
```

Serving a personal or portfolio site from a domain is fine. Serving the Tank API
from one is the failure described above.

## Checklist

- [ ] Tailscale installed on the Tank and on every device that needs it.
- [ ] `tailscale serve status` shows nothing forwarding to port 8000.
- [ ] No router port forwarding to 8000.
- [ ] No `ingress` entry anywhere pointing at `127.0.0.1:8000`.
- [ ] Each device paired at the Tank display before it travels.
