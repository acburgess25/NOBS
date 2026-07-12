# Tank fresh start

Reset Tank to the state a **first-time client** would see: no paired devices, no dream-team history, no workplace browser sessions, no briefing cache, and no agent approvals.

## Production Tank (Ubuntu homelab)

The real Tank runs on the **Ubuntu homelab machine**, not your Mac. Deploy and reset there:

```bash
cd /Users/ab/Documents/NOBS/NOBS-old
bash scripts/deploy-tank.sh              # sync code + restart nobs-api on Ubuntu
bash scripts/reset-tank-fresh.sh --remote # wipe client state on Ubuntu (backs up first)
```

SSH host auto-detection: `tank-lan` (LAN `192.168.0.59`) then `tank` (Tailscale). Override with `TANK_HOST=tank-lan`.

| URL | What you see |
|-----|----------------|
| `http://192.168.0.59:8000/dashboard` | Main dashboard with **Dream team workplace** + **Dream Team sandbox** cards |
| `http://192.168.0.59:8000/workplace` | Animated live workplace floor |
| `http://192.168.0.59:8000/dream-team/policy` | Local-first policy JSON (requires device token) |
| `http://192.168.0.59:8000/health` | API health |

On Tailscale (when LAN is unreachable): use the Tank Tailscale IP from `ssh tank hostname -I`.

**Hard refresh** after deploy: `Cmd+Shift+R` (Safari/Chrome) so cached dashboard HTML/CSS reload.

Mac `install-tank-launchagent.sh` is **dev-only** for local API testing; production UI is always the Ubuntu host above.

## One command (local Mac dev only)

From the repo root:

```bash
bash scripts/reset-tank-fresh.sh
```

Preview without changes:

```bash
bash scripts/reset-tank-fresh.sh --dry-run
```

Homelab Tank over SSH (when `tank` is reachable):

```bash
bash scripts/reset-tank-fresh.sh --remote
```

Override the Tank working directory when auto-detection is wrong:

```bash
TANK_ROOT=/path/to/tank bash scripts/reset-tank-fresh.sh
```

## What gets wiped

| Item | Location |
|------|----------|
| Device token + Apple user pairing | `kv` table in `data/nobs-agent.db` (DB removed) |
| Agent runs, approvals, audit log | `data/nobs-agent.db` |
| Briefing cache + schedules | `data/nobs-agent.db` |
| Calendar/reminder sync copies | `data/nobs-agent.db` |
| Proposals + overnight queue | `data/nobs-agent.db` |
| Dream-team sessions, drafts, proposals | `data/nobs-agent.db` + `data/dream-team/active/` |
| Agent workspace files | `data/agent-workspace/` |
| Dream-team sandbox artifacts | `data/dream-team-sandbox/` |
| Workplace browser screenshots | `data/workplace/screenshots/` |
| Legacy DB stub | `nobs.db` |
| Env device token | `NOBS_DEVICE_TOKEN` cleared in `.env` and `~/.config/nobs/nobs-api.env` (if present) |

## What is preserved

- Application source (`app/`, `dashboard/`, `workplace/`)
- Python venv and Ollama models
- `.env` secrets other than `NOBS_DEVICE_TOKEN` (Home Assistant token, weather coords, etc.)
- Host tunnel config (`~/.config/nobs/` except token line in `nobs-api.env`)
- iPhone Keychain pairing (clear manually in the app after reset)

## Backup

Before wiping, the script copies state to:

```text
data/backups/pre-reset-<YYYYMMDD-HHMMSS>/
```

Includes `data/`, `nobs.db`, `.env` (as `dotenv.backup`), and `host-config/nobs-api.env` when present.

## First-time checklist after reset

1. **Pair iPhone** — `python3 scripts/pairing.py` (generates token + QR), then Privacy → Scan QR on the app.
2. **Dashboard** — `http://<tank-host>:8000/dashboard` (room-safe status + pairing QR).
3. **Workplace** — `http://<tank-host>:8000/workplace` (requires paired token for agent routes).
4. **Verify API** — `curl http://127.0.0.1:8000/health` and authenticated `GET /ready` with `Authorization: Bearer &lt;device token&gt;`.
5. **Clear stale iPhone pairing** if the app still shows the old token.
6. **Run checks** — `python3 scripts/dev.py check`.

Default URLs: Simulator `http://127.0.0.1:8000`; physical device use LAN IP (`tank.local` mDNS is unreliable).

## macOS LaunchAgent (local Tank)

On macOS, Tank should run from the authoritative checkout at
`/Users/ab/Documents/NOBS/NOBS-old` (this repo). An older iCloud-synced copy may
still exist at `/Users/ab/Documents/Documents - Unknown/NOBS`; use only one
checkout as `TANK_ROOT` so data, `.env`, and the LaunchAgent stay aligned.

Install or refresh the LaunchAgent after clone, venv changes, or a path move:

```bash
cd /Users/ab/Documents/NOBS/NOBS-old
bash scripts/install-tank-launchagent.sh
```

Preview without changes:

```bash
bash scripts/install-tank-launchagent.sh --dry-run
```

Point at a different checkout:

```bash
TANK_ROOT=/path/to/checkout bash scripts/install-tank-launchagent.sh
```

The script creates `$TANK_ROOT/.venv` when missing (via `python3 scripts/dev.py
setup`), ensures `uvicorn` is installed, writes
`~/Library/LaunchAgents/com.nobs.tank.plist` with the correct
`WorkingDirectory` and venv python, then loads and health-checks the service.

Manual foreground run (no LaunchAgent): `python3 scripts/dev.py run`.

## Service detection

The reset script stops and restarts Tank using the first match:

1. `systemctl --user nobs-api` (Linux homelab)
2. macOS LaunchAgent `com.nobs.tank`
3. uvicorn process listening on port 8000

Tank root auto-detection order: `TANK_ROOT` env → uvicorn process cwd → LaunchAgent `WorkingDirectory` → repo root.
