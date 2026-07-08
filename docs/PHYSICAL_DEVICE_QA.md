# Physical Device QA — Pass/Fail Template

**Status:** Active validation template  
**Updated:** July 8, 2026  
**Companion:** [`DEVICE_HUB_QA.md`](DEVICE_HUB_QA.md) (simulator matrix + automation boundaries)  
**Product context:** [`CURRENT_STATE.md`](CURRENT_STATE.md)

Use this document for each physical iPhone validation run. Copy the session block below or duplicate this file per test cycle (e.g. `PHYSICAL_DEVICE_QA_2026-07-08.md`).

Physical device testing **cannot** be fully automated in CI today — it requires contributor hardware, a signed build, and a live Tank on the LAN. Simulator and backend tests cover compilation and API contracts only.

---

## Session metadata

| Field | Value |
|---|---|
| **Tester** | |
| **Date** | |
| **Device** | e.g. iPhone 15 Pro, iOS 26.x |
| **Build** | Debug / TestFlight build #, git SHA |
| **Tank host** | IP or hostname, port |
| **Tank API** | `python3 scripts/dev.py check` pass? ☐ Yes ☐ No |
| **Network** | Same LAN as Tank? ☐ Yes ☐ No |

**Overall result:** ☐ Pass ☐ Fail (blockers: _______________)

---

## 1. Pairing

### 1.1 Tank dashboard QR

| Step | Action | Expected | Pass/Fail | Notes |
|---|---|---|---|---|
| 1.1.1 | Open `http://<tank-host>:8000/dashboard` on a browser | Pairing QR visible; no conversation/calendar PII on screen | ☐ | |
| 1.1.2 | On iPhone: Privacy → **Scan QR** | Camera opens; scan dashboard QR | ☐ | |
| 1.1.3 | After scan | Tank URL and connection status show connected; no token paste required | ☐ | |
| 1.1.4 | Pull to refresh or open Chat | `/ready` or chat succeeds (not persistent 401) | ☐ | |

### 1.2 `scripts/pairing.py`

| Step | Action | Expected | Pass/Fail | Notes |
|---|---|---|---|---|
| 1.2.1 | On Tank or dev machine in repo root: `python3 scripts/pairing.py` | ASCII QR prints; URL matches LAN IP :8000 | ☐ | |
| 1.2.2 | Scan terminal QR from Privacy → Scan QR | Same pairing outcome as dashboard QR | ☐ | |
| 1.2.3 | Force-quit NOBS; relaunch | Still connected; no re-pair prompt | ☐ | |

### 1.3 Manual pairing (fallback)

| Step | Action | Expected | Pass/Fail | Notes |
|---|---|---|---|---|
| 1.3.1 | Privacy → enter Tank base URL manually | Saves and probes connection | ☐ | |
| 1.3.2 | Enter device token from `.env` `NOBS_DEVICE_TOKEN` | Authenticated routes work | ☐ | |

---

## 2. Chat

| Step | Action | Expected | Pass/Fail | Notes |
|---|---|---|---|---|
| 2.1 | Open Chat; send "What can you help with today?" | Response within reasonable time | ☐ | |
| 2.2 | Inspect message chrome | **Tank** route badge visible when connected | ☐ | |
| 2.3 | Open privacy receipt on response | Lists processing route and data handling honestly | ☐ | |
| 2.4 | Stop Tank API; send another message | **Local** route; honest offline copy (no fake Tank reply) | ☐ | |
| 2.5 | Restart Tank; send message | Returns to Tank route without re-pairing | ☐ | |

---

## 3. Briefing refinement

| Step | Action | Expected | Pass/Fail | Notes |
|---|---|---|---|---|
| 3.1 | Grant calendar access if prompted | Today shows same-day events | ☐ | |
| 3.2 | Today → generate / refresh briefing | Topline, priorities, risks render | ☐ | |
| 3.3 | With Tank online | Briefing shows Tank refinement (route badge or receipt) | ☐ | |
| 3.4 | With Tank offline | On-device briefing still generates; route shows Local | ☐ | |
| 3.5 | Overlapping events (if available) | Conflict/overload called out; clarifying question on Today or notification | ☐ | |

---

## 4. Approve / deny

| Step | Action | Expected | Pass/Fail | Notes |
|---|---|---|---|---|
| 4.1 | Trigger a state-changing agent action on Tank (e.g. approval-gated note) | Pending item appears in Activity → Approvals | ☐ | |
| 4.2 | Tap **Approve** | Item clears or moves to executed; success receipt in Activity | ☐ | |
| 4.3 | Trigger another pending item; tap **Deny** | Item rejected; no silent execution | ☐ | |
| 4.4 | Dashboard (room display) | Approval *count* updates; no proposal details on shared screen | ☐ | |

---

## 5. Calendar and reminders sync

| Step | Action | Expected | Pass/Fail | Notes |
|---|---|---|---|---|
| 5.1 | Calendar permission granted | Today lists today's events | ☐ | |
| 5.2 | After briefing or sync | Tank receives calendar payload (verify via logs or agent context) | ☐ | |
| 5.3 | Reminders permission granted | Briefing or Today references reminders when relevant | ☐ | |
| 5.4 | Reminders sync | `/sync/reminders` succeeds (no 401; check Tank logs if needed) | ☐ | |
| 5.5 | Deny calendar | App does not crash; briefing explains limited context | ☐ | |

---

## 6. Widget snapshot

| Step | Action | Expected | Pass/Fail | Notes |
|---|---|---|---|---|
| 6.1 | After successful briefing | `widget-snapshot.json` updated in App Group `group.com.nobsdash.nobs` (optional: Xcode container inspect) | ☐ | |
| 6.2 | Add **Today's plan** widget to Home Screen | Shows topline from last briefing | ☐ | |
| 6.3 | Force-quit app; wait for widget refresh | Widget still shows cached snapshot (offline OK) | ☐ | |
| 6.4 | Tap widget | Opens app to Today (`nobs://today`) | ☐ | |
| 6.5 | Lock Screen widget (if configured) | Redacted details per privacy setting | ☐ | |

---

## 7. App restart and reconnect

| Step | Action | Expected | Pass/Fail | Notes |
|---|---|---|---|---|
| 7.1 | Note Tank URL in Privacy | Matches paired host | ☐ | |
| 7.2 | Force-quit NOBS; relaunch on same Wi‑Fi | Auto-reconnect; chat/briefing use Tank without QR | ☐ | |
| 7.3 | Toggle airplane mode on → off | Connection recovers (may need Privacy refresh until Tier 1.2 reconnect UX ships) | ☐ | |
| 7.4 | Reboot iPhone; open NOBS | Keychain token and URL persist; pairing intact | ☐ | |

---

## 8. Optional — Siri and notifications

Not required for Tier 1.1 minimum bar; record when testing Tier 1 Apple slice on device.

| Step | Action | Expected | Pass/Fail | Notes |
|---|---|---|---|---|
| 8.1 | "Prepare my day in NOBS" to Siri | Speaks topline or honest calendar-denied message | ☐ | |
| 8.2 | Briefing with clarifying question; notifications allowed | At most one proactive question notification per day | ☐ | |
| 8.3 | Tap notification action | Opens chat with prefilled prompt; no silent calendar edit | ☐ | |

---

## Sign-off

| Role | Name | Date | Result |
|---|---|---|---|
| Tester | | | ☐ Pass ☐ Fail |
| Reviewer (optional) | | | |

**Blockers filed as issues:** (links)

**Updates required:** ☐ [`CURRENT_STATE.md`](CURRENT_STATE.md) ☐ [`DEVICE_HUB_QA.md`](DEVICE_HUB_QA.md) release blockers

---

## Quick commands

```bash
# Tank health (on dev machine or Tank)
python3 scripts/dev.py check

# Pairing QR in terminal
python3 scripts/pairing.py

# Simulator build (does not replace physical QA)
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcodebuild -project NOBS.xcodeproj -scheme NOBS \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' \
  CODE_SIGNING_ALLOWED=NO build
```
