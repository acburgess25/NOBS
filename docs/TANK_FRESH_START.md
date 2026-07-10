# Tank fresh start

Reset Tank to the state a **first-time client** would see: no paired devices, no dream-team history, no workplace browser sessions, no briefing cache, and no agent approvals.

## One command

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
4. **Verify API** — `curl http://127.0.0.1:8000/health` and authenticated `GET /ready` with `X-NOBS-Device-Token`.
5. **Clear stale iPhone pairing** if the app still shows the old token.
6. **Run checks** — `python3 scripts/dev.py check`.

Default URLs: Simulator `http://127.0.0.1:8000`; physical device use LAN IP (`tank.local` mDNS is unreliable).

## Service detection

The script stops and restarts Tank using the first match:

1. `systemctl --user nobs-api` (Linux homelab)
2. macOS LaunchAgent `com.nobs.tank`
3. uvicorn process listening on port 8000

Tank root auto-detection order: `TANK_ROOT` env → uvicorn process cwd → LaunchAgent `WorkingDirectory` → repo root.
