# Contributing to NOBS

Thanks for helping build NOBS. This is a solo-maintained project, so a small
amount of your time goes a long way — and "this was confusing" is a real
contribution, not a lesser one.

## Start here

1. Read [`docs/CURRENT_STATE.md`](docs/CURRENT_STATE.md). It is the honest
   implemented-versus-planned boundary, written for someone arriving with no
   prior context. Most "is this broken or just unbuilt?" questions are answered
   there.
2. Skim [`docs/PRODUCT_DECISIONS.md`](docs/PRODUCT_DECISIONS.md) for why NOBS
   behaves the way it does.
3. Read [`docs/AI_WORKFLOW.md`](docs/AI_WORKFLOW.md) — the collaboration guide
   for every contributor, human or agent. It covers branch naming, validation,
   and the definition of done.

## Where help is most useful

| If you know | What needs doing |
|---|---|
| **Swift / SwiftUI** | The iPhone app is the front door: widgets, Live Activities, App Intents, and especially accessibility — Dynamic Type, VoiceOver, reduced motion, non-color state indicators. Accessibility here is adaptive product behavior, not a compliance pass. |
| **Python / FastAPI** | Tank's agent, tool registry, and approval queue in `app/`. New tools need denial, replay, path-boundary, and malformed-model-output tests. |
| **Home Assistant / smart home** | The bridge works and every state change creates an approval. It needs real, messy, multi-vendor houses reporting where the model breaks. |
| **Spare hardware** | Tank must run well on Windows/WSL2 and Linux, not only the Mac it is developed on. CI covers all three; lived experience covers none. |
| **Writing / design** | Docs, onboarding words, and the visual system. Making privacy-first feel warm rather than paranoid is unsolved. |

Smaller and still genuinely useful: open a
[friction report](https://github.com/acburgess25/NOBS/issues/new?template=friction_report.yml)
when setup hurts, or file an idea. You do not need to write code to help.

## Set up the backend

Requires Python 3.11 or newer. The task runner resolves the virtualenv on both
`.venv/bin` and `.venv/Scripts`, so the same two commands work everywhere.

macOS / Linux:

```bash
python3 scripts/dev.py setup && python3 scripts/dev.py check
```

Windows (PowerShell):

```powershell
python scripts\dev.py setup; python scripts\dev.py check
```

`check` runs lint and the full backend suite. It should be green before you
start, so a failure is a signal about your environment rather than your change.

The iPhone app builds on macOS with Xcode 27 or newer and is not required for
backend work. Never claim the app builds from source inspection alone — see
`docs/AI_WORKFLOW.md` for the simulator build command.

## What will be sent back

These are product rules, not style preferences:

- **No feature that pretends to work.** If something is unfinished, NOBS says
  so and offers the closest real alternative. A fake spinner or an invented
  result is worse than an honest "coming soon".
- **No action without approval.** The model may propose a state change; it
  never authorizes one. Approvals are stored, atomic, non-replayable, and
  audited, and the exact approved arguments are what execute.
- **No password or financial account access.** Categorically off-limits.
- **No macOS-only assumptions in shared code.** Use `pathlib`, environment
  configuration, and URL-based discovery rather than hard-coded separators,
  drive letters, or hostnames.
- **No secrets, personal data, or `data/` contents in commits, tests, or
  issues.**

## Ground rules (free protection baseline)

1. **Only submit work you have the right to submit.** Contribute code and
   content you are allowed to share publicly, and that you either wrote or can
   redistribute under this repository's license.
2. **Respect repository boundaries.** Keep private/proprietary integrations out of public contributions.
3. **No secrets or personal data.** Never commit keys, tokens, private logs, or personal user data.

## Pull request checklist

1. Use a clear title and explain the user impact.
2. Use the public codename **Project Lantern** when discussing sensitive roadmap items in public threads.
3. Include tests or explain why tests are not needed.
4. Ensure local checks pass (`python3 scripts/dev.py check` for backend changes).
5. Confirm the contributor attestation in the PR template, including the
   [contribution grant](#the-grant).

## License and contribution rights

NOBS is published under **AGPL-3.0-or-later**, and it stays that way. Inbound
contributions match outbound: your work is licensed under AGPL like everything
else here.

There is one addition. It is stated plainly in the open rather than buried in a
signature flow, because a term you only discover after doing the work is a bad
way to treat someone who showed up to help.

### The grant

By opening a pull request, you confirm that:

1. **You have the right to submit the work.** You wrote it, or you can
   redistribute it under this repository's license. It carries no employer
   claim, NDA, or third-party copyright you are not free to license.

2. **Your contribution is licensed under AGPL-3.0-or-later**, like the rest of
   the project.

3. **You additionally grant the maintainer** (Alexander Burgess) a perpetual,
   worldwide, non-exclusive, royalty-free, irrevocable license to reproduce,
   modify, adapt, publish, sublicense, and distribute your contribution —
   including under license terms other than AGPL, and including as part of a
   proprietary or commercially distributed build. The grant covers any patent
   claims you hold that your contribution would otherwise infringe.

**You keep your copyright.** This is a license, not an assignment. You may still
use, publish, and relicense your own work anywhere you like, and your name stays
in the history.

### Why this exists

The AGPL and Apple's App Store terms do not sit comfortably together. Store
distribution imposes usage restrictions that the GPL family is written to
forbid, which is why AGPL-licensed apps have been pulled from the App Store
before.

While one person holds copyright on all of NOBS, this is not a problem — a sole
copyright holder can publish AGPL source and also ship a store build. But the
first contribution that arrives under AGPL alone makes the iPhone app
undistributable without going back to its author for separate permission. With
enough contributors, that becomes impossible to unwind.

Without this grant, the project has to choose between accepting help and
shipping the app it exists to ship. The grant is what lets both be true.

**What it is not.** It does not make NOBS closed — the source stays public and
AGPL, and this file will say so for as long as that is true. It does not let
anyone other than the maintainer relicense your work. And it does not loosen the
product rules in [`docs/PRODUCT_DECISIONS.md`](docs/PRODUCT_DECISIONS.md):
no selling personal data, no paywalling the free local core, no manufactured
hardware limits. Those bind the maintainer regardless of who wrote which line.

If you would rather not grant it, a friction report, bug report, or idea is
still a real contribution and carries none of these terms.

### Sign-off

Per-commit `Signed-off-by` is not required. It was previously listed as
mandatory while nothing in the project actually used it, which asked newcomers
to follow a rule the repository itself did not follow. The confirmation above is
what carries that intent now. Sign-off is still welcome if you prefer it —
`git commit -s` — it is simply not a condition of merging.
