# nobsdash.com deployment

The NOBS portfolio is a static Vite site hosted by **Cloudflare Pages**. It no
longer depends on Tank, a Cloudflare Tunnel, or GitHub Pages for availability.

## Production configuration

| Item | Value |
| --- | --- |
| Pages project | `nobsdash` |
| Production branch | `main` |
| Pages hostname | `nobsdash.pages.dev` |
| Custom domains | `nobsdash.com`, `www.nobsdash.com` |
| DNS target | `nobsdash.pages.dev` |

Both custom domains must be attached to the Pages project, proxied by
Cloudflare, and covered by active SSL certificates. GitHub Pages must remain
disabled so it cannot compete for the custom domain.

## Build and deploy

From the repository root:

```bash
cd website
pnpm install --frozen-lockfile
pnpm build
npx wrangler pages deploy dist --project-name=nobsdash --branch=main
```

The command returns an immutable deployment URL. Verify that URL before
checking the production domains.

## Verification

```bash
curl --fail --silent --show-error https://nobsdash.com/ >/dev/null
curl --fail --silent --show-error https://www.nobsdash.com/ >/dev/null
curl --fail --silent --show-error https://nobsdash.com/privacy >/dev/null
```

Confirm the production page references the same hashed JavaScript asset as the
new Pages deployment. This proves DNS is serving the intended build rather
than a cached or competing origin.

## Rollback

Cloudflare Pages keeps immutable deployments. To roll back without rebuilding:

1. Open **Workers & Pages → nobsdash → Deployments** in Cloudflare.
2. Select the last known-good production deployment.
3. Choose **Rollback to this deployment** and confirm.
4. Re-run the three public verification requests above.

If only one hostname fails, inspect its Pages custom-domain status and DNS
record before changing the deployment. Do not restore the old Tank tunnel or
GitHub Pages as a production workaround.

## Optional support links

Edit `website/public/support.json` with GitHub Sponsors and Stripe Payment Link
URLs, then rebuild. See [`SUPPORT_AND_PAYMENTS.md`](SUPPORT_AND_PAYMENTS.md).
The Support section appears only when at least one URL is set.
