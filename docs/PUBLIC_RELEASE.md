# Public GitHub release checklist

Use this before switching the repository from private to public.

Making the repo public also unlocks the career track in [`CAREER_AND_VISIBILITY.md`](CAREER_AND_VISIBILITY.md)—recruiters cannot evaluate private work.

## Repository split (done)

- [x] Internal fundraising, discovery, ops docs, and QA captures moved to **NOBS-private** (`https://github.com/acburgess25/NOBS-private`).
- [x] Public tree keeps redirect stubs under `docs/internal/` and `docs/app-store/review-notes.md`.
- [x] `outputs/` gitignored in the public repo.

## Repository hygiene

- [ ] Scan for secrets: `git grep -iE 'password|api[_-]?key|BEGIN PRIVATE|mobileprovision|\.p8'` and review `deploy/`, `docs/`, and `scripts/`.
- [ ] Confirm `.env`, logs, tunnel credentials, and `website/dist/` are not tracked.
- [ ] Replace home-specific hostnames, LAN IPs, usernames, and tunnel UUIDs with examples (see `deploy/tank/*.example`).
- [ ] If a Cloudflare tunnel UUID was ever committed, **rotate the tunnel** and update the host-local config only.

## GitHub settings

- [ ] Set repository description and topics (privacy, local-first, SwiftUI, FastAPI, homelab).
- [ ] Enable **Private vulnerability reporting** (Settings → Code security).
- [ ] Protect `main`: require PR reviews, required status checks (`backend-ci`), block force-push.
- [ ] Fix Actions billing so `TestFlight` can run when you cut iOS builds.
- [ ] Delete `PROVISIONING_PROFILE` secret if still present (workflow no longer uses it).
- [ ] Review open PRs and close or merge stale drafts before going public.

## Branch cleanup (optional)

List merged remote branches:

```bash
git fetch --prune
git branch -r --merged origin/main
```

Delete only branches you no longer need:

```bash
git push origin --delete <branch>
```

## Legal and product

- [ ] `LICENSE` (AGPL-3.0-or-later) and `CONTRIBUTING.md` DCO requirements are visible.
- [ ] `SECURITY.md` contact path is valid.
- [ ] Privacy policy URL is ready before external TestFlight or App Store beta.
- [ ] README and `docs/CURRENT_STATE.md` describe prototype boundaries honestly.

## After flipping to public

- [ ] Watch the Security tab for Dependabot alerts.
- [ ] Re-run `python3 scripts/dev.py check` on `main`.
- [ ] Trigger TestFlight manually once billing and signing are healthy.
