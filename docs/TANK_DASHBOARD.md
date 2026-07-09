# NOBS Tank Dashboard

## Purpose

The Tank dashboard is a room-safe, always-on status surface for a connected monitor or any browser on the private network. It reports operational facts without showing conversations, calendar details, filenames, note content, or approval arguments.

Open it at:

```text
http://tank.local:8000/dashboard
```

On Tank itself, use `http://127.0.0.1:8000/dashboard`.

## Information shown

- Tank host uptime, load, storage capacity, and API state;
- Ollama availability and configured local model;
- agent runs completed in the previous 24 hours;
- pending approval count without proposal details;
- item counts for Personal, Business, and Shared workspaces;
- the highest-priority room-safe alert;
- connection and refresh state.

The display refreshes every 15 seconds. Light, Dark, and Auto themes are stored in that browser. A one-pixel periodic layout shift reduces static-panel burn-in without creating distracting motion.

## Privacy boundary

`GET /dashboard/status` is intentionally safe for a shared room and therefore does not require the device bearer token. It includes a `pairing` object (`url` + `token`) so the on-screen QR can complete iPhone setup without conversations or calendar content. Detailed approvals remain on authenticated `/agent/approvals` routes and should be reviewed on the iPhone.

The LAN firewall must remain limited to the trusted home network. Do not expose the dashboard or API directly to the public internet.

## Connected-screen setup

The repository includes:

- `scripts/start-dashboard-kiosk.sh`, which launches Firefox or Chromium in kiosk mode;
- `deploy/tank/nobs-dashboard-kiosk.desktop`, which starts the launcher in a graphical desktop session.

Tank currently needs a graphical session and a supported browser before an HDMI-connected display can launch automatically. That installation requires sudo and should be completed interactively on Tank.

After installing Firefox or Chromium:

```bash
mkdir -p ~/.config/autostart
cp ~/nobs/deploy/tank/nobs-dashboard-kiosk.desktop ~/.config/autostart/
chmod +x ~/nobs/scripts/start-dashboard-kiosk.sh
```

Log into the graphical session once to verify display scaling, theme, screen blanking, and kiosk launch. Do not disable the lock screen on a display that can reveal anything beyond the room-safe dashboard.

## Validation

```bash
python3 scripts/dev.py check
curl -fsS http://127.0.0.1:8000/dashboard/status
```

Visual QA evidence is stored in the private repo under `outputs/dashboard-qa/` (see [`docs/internal/README.md`](internal/README.md)).
