# NOBS Dogfood Setup

**Status:** Operating runbook (decision owner: Alexander Burgess)
**Captured:** August 31, 2026
**Purpose:** Stand NOBS up on the owner's own iPhone, Tank, and Mac, then run daily life, NOBS development, and company operations on it.

Related: [`CURRENT_STATE.md`](CURRENT_STATE.md) (what actually works), [`MONETIZATION_AND_GROWTH.md`](MONETIZATION_AND_GROWTH.md) (why this comes first), [`NOBS_TANK_BUILD.md`](NOBS_TANK_BUILD.md) (Tank architecture), [`IOS_SESSION_HANDOFF.md`](IOS_SESSION_HANDOFF.md) (iPhone build), [`REMOTE_ACCESS.md`](REMOTE_ACCESS.md) (Tailscale — **lands with PR #113**).

---

## Why this exists

NOBS has never run on a physical iPhone. Not the owner's, not anyone's. Everything verified so far is Simulator-only.

That is the single largest unknown in the product, and it is larger than any code-quality question. The backend is healthy — 252/252 tests pass cold on a clean machine — and the documentation is thorough. What is missing is **evidence that a person uses this and keeps using it**.

TestFlight is gated on the Xcode 27 release candidate, expected early-to-mid September 2026 (see "Toolchain" in [`CI_TROUBLESHOOTING.md`](CI_TROUBLESHOOTING.md)). That is a waiting period of roughly one to two weeks with nothing to do but wait.

**Spend it becoming user number one.** Every bug found here is a bug a TestFlight stranger would have found instead — except here it costs a fix rather than a review.

### The rule that makes this worth doing

Use NOBS for real work, not demo work. A briefing you skim and ignore proves nothing. A briefing that changes what you do that morning is the product working. When you reach for a different tool instead of NOBS, **that moment is the finding** — write it down.

---

## What you are standing up

| Machine | Role | Runs |
|---|---|---|
| **Tank** (Ubuntu + NVIDIA) | Always-on brain | `nobs-api` :8000, Ollama, dashboard :4173, overnight queue, Dream Team |
| **Mac** | Portable Tank + dev box | `NOBSTank` menu-bar app, `com.nobs.tank` LaunchAgent, Xcode |
| **iPhone** | The product | NOBS app, widget, Live Activity, Siri intents |

Tailscale joins all three so the phone reaches the Tank away from home.

---

## Order matters — read before starting

Two constraints fix the sequence. Neither is negotiable.

**1. Pair at the Tank, before you travel.** `require_local_request` gates `/dashboard/pairing` on a literal loopback peer address (`app/pairing.py`, `is_loopback_client`). Pairing is refused from anywhere else — **including over Tailscale**. That is deliberate. If you leave the house unpaired, there is no remote path in; someone has to be physically at the Tank.

**2. Never proxy port 8000.** cloudflared, nginx, Caddy, `tailscale serve`, and `tailscale funnel` all connect from localhost, which makes every request on earth look local — and the pairing route hands out the device token that unlocks everything. `X-Forwarded-For` cannot fix this; it is caller-supplied and forgeable. A VPN keeps the peer address honest; a proxy launders it. Full reasoning in [`REMOTE_ACCESS.md`](REMOTE_ACCESS.md).

So: **Tank first, Mac second, phone third, Tailscale fourth, pairing while still at home.**

---

## Phase A — Tank (Ubuntu homelab)

Target: the always-on brain, healthy and surviving reboot.

### A1. Deploy the backend

From a checkout on the Mac, on the home LAN:

```bash
bash scripts/deploy-tank.sh --dry-run   # read the plan first
bash scripts/deploy-tank.sh
```

It resolves the SSH host alias `tank-lan`, then `tank`; override with `TANK_HOST=…`. It syncs `app/`, `dashboard/`, `workplace/`, and `pyproject.toml`, installs dependencies, restarts `nobs-api`, and verifies `/health`, `/workplace`, and `/dream-team/policy`.

### A2. Confirm the services

On the Tank:

```bash
systemctl --user status nobs-api nobsdash
loginctl show-user "$USER" | grep Linger    # must be Linger=yes
curl -fsS localhost:8000/health
```

`Linger=yes` is what keeps user services alive across logout and reboot. Unit templates live in [`deploy/tank/`](../deploy/tank/); copy into `~/.config/systemd/user/`, edit paths and secrets locally, then `systemctl --user daemon-reload`.

### A3. Confirm the models

```bash
ollama list        # expect qwen3:8b and qwen2.5-coder:14b
nvidia-smi
```

`qwen3:8b` serves app chat; `qwen2.5-coder:14b` serves developer mode. If either is missing, `scripts/setup-local-ai.sh` pulls them.

### A4. Fix the overnight timeout before trusting the queue

`CURRENT_STATE.md` records 188 `AgentModelError`s from `httpx.ReadTimeout` on the reference Mac Tank. Ollama, the model, and the API were all healthy — this is timeout tuning for multi-step agent turns, not a defect.

The default is 45 seconds (`NOBS_OLLAMA_TIMEOUT_SECONDS`), which a multi-step turn on a loaded GPU will exceed. On the Tank's `.env`, raise it and restart:

```bash
NOBS_OLLAMA_TIMEOUT_SECONDS=180
systemctl --user restart nobs-api
```

Then re-measure over a few nights before calling scheduled idea generation working. **PR #115 (background agent timeout) addresses exactly this split** — merging it gives background turns their own budget instead of borrowing the interactive one. Prefer that over tuning one global number.

### A5. Dashboard on the HDMI display

Already configured to autostart into Firefox kiosk and survive reboot. Verify at `http://<tank>:8000/dashboard`. GUI session is tty2 (Ctrl+Alt+F2); text console is tty3.

**Gate:** `/health` answers, both models load, dashboard renders, survives a full reboot.

---

## Phase B — Mac (portable Tank + dev box)

### B1. Backend checkout

```bash
python3 scripts/dev.py setup
python3 scripts/dev.py check     # 252 tests, lint, format
```

### B2. LaunchAgent

```bash
bash scripts/install-tank-launchagent.sh --dry-run
bash scripts/install-tank-launchagent.sh
```

Writes `~/Library/LaunchAgents/com.nobs.tank.plist` pointing at this checkout (override with `TANK_ROOT`, port with `TANK_PORT`). This Mac Tank is **dev-only** — the Ubuntu box is the real one. Its value is having a Tank in your bag.

### B3. NOBSTank menu-bar app

Build the `NOBSTank` scheme from `NOBS.xcodeproj` (macOS 27, Xcode 27 beta). It shows Tank API / Ollama / model / network status, restarts the `com.nobs.tank` LaunchAgent, exposes a quick-ask box with honest Local-vs-Tank labeling, and displays the `nobs://pair` QR.

It reads the device token from `~/Documents/NOBS/.env`. If your checkout is elsewhere:

```bash
defaults write com.nobsdash.NOBSTank nobs.tank.rootPath -string "/path/to/checkout"
```

**Gate:** menu bar shows the Ubuntu Tank online; quick-ask answers and labels its route correctly.

---

## Phase C — iPhone (the one that has never happened)

This needs **no App Store Connect, no TestFlight, and no released toolchain**. It is a development build to your own device, and it is available today.

### C1. Provisioning

`DEVELOPMENT_TEAM = K853LKQLAS` with automatic signing. The known gap from [`IOS_SESSION_HANDOFF.md`](IOS_SESSION_HANDOFF.md):

> Widget extension (`NOBSWidgets`) must share the same team and App Group entitlements.

Both `com.nobsdash.nobs` and `com.nobsdash.nobs.widgets` need a development certificate, a provisioning profile, and App Group `group.com.nobsdash.nobs`. Fix the widget target first — a silently unsigned widget produces an app that installs but whose Today widget never appears, which reads as a product bug and is not one.

### C2. Build to the device

Plug the iPhone in, select it as destination in Xcode 27 beta, ⌘R. If signing fights you, confirm the code still compiles:

```bash
./scripts/build-ios-simulator.sh
```

That isolates signing problems from compile problems.

### C3. Verify on device, in this order

Cheapest first, so a failure stops you before you have wasted the later steps.

- [ ] App launches; conversational onboarding completes (name, mental-load sources, working hours, proactivity, one immediate problem)
- [ ] `UserProfile` persists to App Group `group.com.nobsdash.nobs` — kill and relaunch, greeting still personal
- [ ] EventKit calendar permission; today's real events appear
- [ ] Reminders permission; reminders join briefing context
- [ ] Briefing v2 generates on-device: topline, priorities, conflicts, sequencing, one clarifying question
- [ ] **Today's plan widget** on Home and Lock Screen reads `widget-snapshot.json` offline; tap opens `nobs://today`
- [ ] Widget timeline reloads after a new briefing
- [ ] Pair to Tank via Bonjour (`_nobs._tcp`) **while standing at the Tank**
- [ ] Tank chat authenticates; route badges show Local vs Tank; privacy receipt readable
- [ ] Approval queue: trigger a state-changing tool, approve from Activity, confirm audit event
- [ ] Live Activity shows pending approval on Lock Screen / Dynamic Island; Approve deep-links to `nobs://approvals?id=…&action=…`
- [ ] All four App Intents from Siri and Shortcuts: Prepare my day, Explain schedule, Ask NOBS, Show privacy receipt
- [ ] Focus-aware briefing changes with a real Focus mode active
- [ ] Evening wrap-up appears after 5pm

**Gate:** the whole list passes on real hardware. This gate is the point of the entire runbook.

---

## Phase D — Remote access

**Depends on PR #113.** Merge it first, then on the Tank, at home:

```bash
bash scripts/setup-tank-remote-access.sh
```

Installs Tailscale, joins the tailnet, verifies the API answers on the tailnet address, and refuses to continue if Serve or Funnel is publishing port 8000. Safe to re-run.

Then install Tailscale on the iPhone and the Mac, on the same tailnet.

### Verify the boundary holds

From off-network (cellular, Wi-Fi off):

- [ ] Tank chat works over Tailscale from the phone
- [ ] `tailscale serve status` shows nothing forwarding to 8000
- [ ] No router port-forward to 8000
- [ ] No `ingress` entry anywhere pointing at `127.0.0.1:8000`
- [ ] `GET /dashboard/pairing` over Tailscale is **refused** — if it succeeds, stop and fix it before going further

That last item is the security model working. A refusal is the pass condition.

---

## Phase E — Run the company on it

This is where dogfooding stops being QA and starts being the product thesis.

### Building NOBS with NOBS

Already built and worth exercising:

- **Developer mode** (`qwen2.5-coder:14b`) — bounded read-only project listing, file reading, and text search. Verified against traversal, symlink escape, hidden files, and secrets.
- **Overnight queue** — `POST /overnight/tasks`, runs one task at a time inside the `NOBS_TIMEZONE` window when CPU is idle, through the normal agent and approval path.
- **Aider loop** — `qwen2.5-coder:14b` over an SSH tunnel (`ssh -f -N -L 11434:127.0.0.1:11434 tank`), `--map-tokens 0` on macOS. Proven at commit `38b14bf`: spec → implement → test → failure report → fix. Use for well-scoped backend tasks.

Queue real NOBS work overnight — a small backend task with tests. In the morning you are reviewing a proposal instead of starting from nothing. **Do not merge unreviewed agent output**; the approval queue exists for exactly this and you are testing it.

### Running the company on it

Use the Personal / Business / Shared contexts as designed. Business context for company work, Shared for anything spanning both.

Honest boundary, from §21 and the security rules: passwords and financial accounts are off-limits, and this is a local assistant with an approval queue — not a bookkeeping system. Calendar, reminders, briefings, notes, research, and the overnight queue are the surface. Do not push it into money or credentials to prove a point.

---

## The daily loop

Every morning: open the briefing **before** anything else. Did it change what you did? Yes or no.

Keep one running file — `workplace/dogfood-log.md`, git-ignored:

```
## 2026-09-01
- Briefing changed my plan? yes/no — one line why
- Reached for another tool instead of NOBS: what, and why
- Bug / friction:
- Route badges honest? (Local / Tank / Apple Cloud)
- Overnight task queued / result:
```

The second line is the most valuable one you will write. Every instance is either a missing feature or a trust failure, and both are things a stranger would have hit silently before deleting the app.

**Do not fix bugs as you find them.** Log them, keep using it, and triage at the end of the week. Fixing mid-stream turns a usage test back into a development session, and you lose the retention signal you came for.

---

## Two-week exit criteria

At the Xcode 27 RC, you should be able to answer these from evidence rather than hope:

1. **Did you keep using it after week one?** If not, TestFlight will not save it — find out why first.
2. **Which feature earned its place?** The one you would miss. That is your marketing message.
3. **Which feature did you never touch?** Cut or defer it; it is carrying maintenance cost for nothing.
4. **Was Tank-less NOBS useful on its own?** Turn the Tank off for two days. This is the adoption-cliff question — almost no stranger has a GPU box, so if the free tier is thin without one, that is the business problem, not a feature gap.
5. **Would you pay $4.99/mo for what NOBScloud delivers today?** It currently routes to Apple PCC. Answer honestly; if no, the paid wedge is hosted Tank, not a PCC passthrough.
6. **What breaks the honesty promise?** Any place a route badge, privacy receipt, or "coming soon" label was wrong is a §-level bug, not a polish item.

Fold the answers into [`CURRENT_STATE.md`](CURRENT_STATE.md) and [`MONETIZATION_AND_GROWTH.md`](MONETIZATION_AND_GROWTH.md) before the TestFlight push.

---

## Known gaps you will hit

Documented already, listed here so they read as expected rather than as new failures:

| Gap | Behavior |
|---|---|
| No long-term memory workflow | Memory surfaces exist; no approved retention design |
| No hosted NOBScloud | Subscription delivers Apple PCC fallback on-device only |
| No backend entitlement sync | StoreKit entitlement is on-device; does not reach Tank |
| Home tab rendering pending | Home tools work on Tank; iOS Home tab and Activity rendering for those proposals are not built |
| `tank.local` may not resolve | Use the Tank's IP directly, e.g. `http://192.168.1.100:8000` |
| Overnight idea generation | Treat as not working until A4's timeout is re-measured |
| Xcode Cloud red | Redundant and permanently red — retire it in App Store Connect, do not debug |

## Optional after PR #114

LM Studio as a selectable local model server, if you prefer it to raw Ollama on the Mac. Not required for any gate above.
