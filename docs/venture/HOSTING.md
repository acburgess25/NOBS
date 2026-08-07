# Hosting NOBS landing page

> Note: this repo **already publishes nobsdash.com** via `.github/workflows/deploy-website.yml`
> (a pnpm site built from `website/`). Do **not** add a second GitHub Pages workflow —
> they'd fight for the same Pages environment. Weave the landing into the existing site instead.

## Recommended: integrate into the existing `website/` pipeline
1. Move the landing copy into the existing `website/` app (or serve it as a route
   `/landing` that mirrors `landing/index.html`).
2. Push to `main`; `deploy-website.yml` auto-builds + deploys to GitHub Pages.
3. Configure a custom domain in **Settings → Pages** (already used for nobsdash.com) or
   use the default `https://acburgess25.github.io/NOBS/`.

## Alternative: standalone Vercel (only if you want it separate from nobsdash.com)
1. Push to a repo. 2. Vercel → import → Framework: Other → Output dir: `landing`.
Result: instant `vercel.app` URL; attach a custom domain free.

## Keep the standalone file
`landing/index.html` stays as a clean, dependency-free reference — you can copy its
HTML/CSS/copy straight into the `website/` app. It has zero builds and zero deps.

## Before you publish
- [ ] Swap the waitlist from `mailto:` to a real **Formspree** form (free tier) so
      emails are captured server-side. The form in `landing/index.html` has a `TODO` comment.
- [ ] Confirm the public URL + capture works (LAUNCH-CALENDAR Day 0).
- [ ] Decide: land it **under** nobsdash.com (recommended) vs. separate.