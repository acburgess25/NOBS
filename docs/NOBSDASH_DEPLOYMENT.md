# nobsdash.com deployment

The NOBS portfolio is a static Vite site. **Production hosting is GitHub Pages**,
deployed from `main` by [`.github/workflows/deploy-website.yml`](../.github/workflows/deploy-website.yml).

## Production configuration

| Item | Value |
| --- | --- |
| Host | GitHub Pages |
| Source | GitHub Actions (`Deploy website`) |
| Build | `website/` → `pnpm build` → `dist/` |
| Custom domains | `nobsdash.com`, `www.nobsdash.com` |
| Pages URL | `https://acburgess25.github.io/NOBS/` (until custom domain is attached) |

Cloudflare may still hold DNS for the domain. Point DNS at GitHub Pages (below).
Do not leave Cloudflare Pages also claiming `nobsdash.com` or the hosts will fight.

## One-time GitHub setup

1. Repo **Settings → Pages**
2. **Build and deployment → Source:** GitHub Actions
3. After the first green `Deploy website` run, open **Settings → Pages** again
4. **Custom domain:** `nobsdash.com` → Save → enable **Enforce HTTPS** when available
5. Add `www.nobsdash.com` as well if you use www (GitHub will show the DNS records)

## DNS (Cloudflare DNS or any registrar)

For the **apex** `nobsdash.com`, create **A** records to GitHub Pages:

| Type | Name | Value |
| --- | --- | --- |
| A | `@` | `185.199.108.153` |
| A | `@` | `185.199.109.153` |
| A | `@` | `185.199.110.153` |
| A | `@` | `185.199.111.153` |

For **www**:

| Type | Name | Value |
| --- | --- | --- |
| CNAME | `www` | `acburgess25.github.io` |

In Cloudflare DNS:

- Set those records to **DNS only** (grey cloud), not Proxied, until HTTPS works on GitHub — or keep proxy only after you know Pages is the origin.
- Remove any CNAME/A that still points at `nobsdash.pages.dev` or Cloudflare Pages.

In Cloudflare **Workers & Pages → nobsdash → Custom domains**, remove `nobsdash.com` / `www` so Pages is not also serving the hostname.

## Local build

```bash
cd website
pnpm install --frozen-lockfile
pnpm build
pnpm preview
```

## Verification

```bash
curl --fail --silent --show-error https://nobsdash.com/ >/dev/null
curl --fail --silent --show-error https://nobsdash.com/support.json
curl --fail --silent --show-error https://nobsdash.com/thanks.html >/dev/null
curl --fail --silent --show-error https://nobsdash.com/privacy.html >/dev/null
```

`support.json` should include the Square tip URL when configured.

## Optional support links

Edit `website/public/support.json` with GitHub Sponsors and Square (or Stripe) Payment Link
URLs, then merge to `main`. See [`SUPPORT_AND_PAYMENTS.md`](SUPPORT_AND_PAYMENTS.md).
