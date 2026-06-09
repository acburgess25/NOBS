# Walkthrough: Developer Homelab & Local Workspace Simplification

We have successfully deployed the homelab stack, configured the server dashboards on **Tank**, simplified your local **MacBook Pro** workspace, and cleaned up unnecessary or failing host-level systemd services.

---

## 🚀 1. Server Dashboard & Control Portal on Tank (Complete)

We have deployed **Cockpit** for deep host OS management and **Homepage** as a unified service landing page dashboard:

### Cockpit Host OS Administrator (Port 9090)
*   **What was done:** Installed native Ubuntu packages `cockpit` and `cockpit-storaged` on Tank. Enabled the socket daemon.
*   **Verification:** Verified port `9090` is listening and responding to secure HTTP connections.
*   **How to access:** Open `https://100.96.97.50:9090` in your browser. Log in using your standard Tank SSH account credentials (`alexburgess` / password). You now have access to a web-based terminal, system updates panel, systemd service controls, disk partition mappings, and system logs.

### Homepage Service Portal (Port 3000)
*   **What was done:** Added `homepage` container service to `docker-compose.yml` mapping host port `3000`. Configured custom layouts mapping the Docker socket for system utilization graphs and docker status signals.
*   **Configuration Files Deployed:**
    *   📄 [settings.yaml](file:///Users/alexburgess/Library/Mobile%20Documents/com~apple~CloudDocs/NOBS/ops/tank/homepage/settings.yaml) — Set title ("NOBS Homelab Portal"), dark slate theme, and header hardware stats indicators.
    *   📄 [services.yaml](file:///Users/alexburgess/Library/Mobile%20Documents/com~apple~CloudDocs/NOBS/ops/tank/homepage/services.yaml) — Visual cards linking your services (Open WebUI, NPM, LiteLLM, and Cockpit) along with real-time docker container health check mappings.
    *   📄 [docker.yaml](file:///Users/alexburgess/Library/Mobile%20Documents/com~apple~CloudDocs/NOBS/ops/tank/homepage/docker.yaml) — Bound connection to `/var/run/docker.sock`.
    *   📄 [bookmarks.yaml](file:///Users/alexburgess/Library/Mobile%20Documents/com~apple~CloudDocs/NOBS/ops/tank/homepage/bookmarks.yaml) — Links to git repositories and your Obsidian vault index page.
*   **Verification:** Checked HTTP endpoint on `http://100.96.97.50:3000` responding with layout data.

---

## 🛠️ 2. Core Homelab Stack on Tank (Complete)

- **GPU Driver & Passthrough:** Installed proprietary NVIDIA driver version `580.159.03`. Tested container GPU offloading using the official CUDA base image.
- **Ollama Engine:** Native daemon initialized on port `11434` with overridden service parameters (Flash Attention enabled, 2 context slots parallel offloading, 15m keep-alive limit) and model weights `qwen2.5-coder:14b` pulled.
- **Docker Compose Stack:**
  - **LiteLLM Gateway (`litellm-gateway`):** Running on port `4000`, verified end-to-end local inference loop routing to Qwen.
  - **Open WebUI (`open-webui`):** Healthy on port `8082`, connected to local model engines.
  - **Nginx Proxy Manager (`nginx-proxy-manager`):** Responsive on port `80/81/443` with persistent volume mappings.

---

## 💻 3. Local MacBook Pro Workspace Simplification (Complete)

Consolidated all custom scripts, templates, backups, and projects from your home directory and downloads into your Obsidian iCloud vault:
*   **Mac Utility Scripts (`/ops/mac/`):**
    *   📄 [nobs-ai.sh](file:///Users/alexburgess/Library/Mobile%20Documents/com~apple~CloudDocs/NOBS/ops/mac/nobs-ai.sh) — Aider vault integration loop.
    *   📄 [nobs-memory-sync.py](file:///Users/alexburgess/Library/Mobile%20Documents/com~apple~CloudDocs/NOBS/ops/mac/nobs-memory-sync.py) — Brain and session parsing sync.
    *   📄 [nobs-visual-test.sh](file:///Users/alexburgess/Library/Mobile%20Documents/com~apple~CloudDocs/NOBS/ops/mac/nobs-visual-test.sh) — iPhone simulator installer test.
    *   📄 [setup_nobs_vault.sh](file:///Users/alexburgess/Library/Mobile%20Documents/com~apple~CloudDocs/NOBS/ops/mac/setup_nobs_vault.sh) — Initial vault sync connector.
*   **Tank Automation Templates (`/ops/tank/`):**
    *   📄 [nobs-obsidian-export.sh](file:///Users/alexburgess/Library/Mobile%20Documents/com~apple~CloudDocs/NOBS/ops/tank/nobs-obsidian-export.sh) — SQLite campaign exporter.
*   **Design Assets (`/BrandKIt/`):**
    *   📄 [NOBS Brand Kit.html](file:///Users/alexburgess/Library/Mobile%20Documents/com~apple~CloudDocs/NOBS/BrandKIt/NOBS%20Brand%20Kit.html) — Brand assets page.
*   **Archived items (`/ops/archived/`):**
    *   📦 [NOBS_AI_Backup.zip](file:///Users/alexburgess/Library/Mobile%20Documents/com~apple~CloudDocs/NOBS/ops/archived/NOBS_AI_Backup.zip) — Legacy ZIP backup.
    *   📁 [NOBS-Server](file:///Users/alexburgess/Library/Mobile%20Documents/com~apple~CloudDocs/NOBS/ops/archived/NOBS-Server/) — Obsolete local Go-installer project.
    *   📁 [templates](file:///Users/alexburgess/Library/Mobile%20Documents/com~apple~CloudDocs/NOBS/ops/archived/templates/) — Web mockups (`login.html`, `memories_api_app.py`, `privacy.html`, `redesigned_index.html`).

### Cleaned Local Applications
*   ❌ **OpenClaw.app** (Deleted + caches removed)
*   ❌ **chatbox.app** (Deleted)
*   ❌ **LM Studio.app** (Deleted)
*   *Kept `Ollama.app` on your MacBook Pro for traveling / offline backup purposes.*

---

## 🧹 4. Systemd Services Clean Up (Complete)

We have cleaned up unnecessary, redundant, or failing host-level systemd services on **Tank** to optimize resource consumption, speed up system boot times, and prevent configuration conflicts:
- **Stopped & Disabled Services**:
  - `nginx.service` (Host Nginx) — Stopped & disabled to prevent port conflicts with Nginx Proxy Manager (Docker container) on ports `80` and `443`.
  - `vgauth.service` & `open-vm-tools.service` (VMware Tools) — Stopped & disabled since Tank is a bare-metal physical machine (Ryzen 5 5600X3D).
  - `ModemManager.service` (Cellular Broadband) — Stopped & disabled.
  - `multipathd.service` (SAN multipathing) — Stopped & disabled.
  - `snap.cups.cupsd.service` & `snap.cups.cups-browsed.service` (CUPS Printers) — Stopped & disabled.
  - `open-iscsi.service` — Stopped & disabled.
  - `NetworkManager-wait-online.service` & `systemd-networkd-wait-online.service` — Disabled to eliminate boot delays.
- **Stopped & Masked Services**:
  - `wpa_supplicant.service` (Wi-Fi Authenticator) — Stopped and masked to prevent it from being automatically spawned via D-Bus by NetworkManager (since Tank is connected via wired Ethernet).
- **Deleted Legacy Scripts & Files**:
  - Deleted `/usr/local/bin/tank-web-heal`
  - Deleted systemd unit files `/etc/systemd/system/tank-web-heal.service` and `/etc/systemd/system/tank-web-heal.timer`
  - Reset all failed states (`systemctl --failed` shows `0` failed units).

---

## 📱 5. Autonomous Agent & iPhone Approval Loop (Complete)

We have built and deployed a fully autonomous homelab agent and interactive notification pipeline with human-in-the-loop approval:

### Deployed Components
*   **ntfy Push Notification Server (`ntfy`):** Running on port `5050`, securely delivering real-time interactive push notifications to the ntfy client on your iPhone over Tailscale.
*   **Proposal Approval API (`approval-api`):** Deployed a FastAPI backend on port `5051` using SQLite (`/data/tasks.db`) to hold pending proposals and receive webhook actions from your iPhone.
*   **Autonomous Agent Container (`nobs-agent`):** Orchestrated on Tank, running Playwright (headless Chromium) and Ollama pipelines, polling the approval API, and executing tasks (e.g. docker upgrades, local updates) upon approval.

### Career & LinkedIn Integration
1.  **Session Extractor (`ops/mac/linkedin_login.py`):** Runs a headed Chromium window locally on your Mac, logs in securely to LinkedIn, captures the session state (cookies & localStorage), and automatically transfers it to Tank via SCP.
2.  **State-Carrying Scraper:** The agent mounts the session directory `/sessions/linkedin/state.json` inside the Docker sandbox, allowing it to scrape targeted job searches ("Apple internship", "IT Infrastructure intern", etc.) without triggering bot checks.
3.  **LLM-Driven Relevance Filters:** Scraped jobs are analyzed by your local Ollama instance (`qwen2.5-coder:14b`). The agent generates structured summaries (assessing relevance to your UArk IS major and career path) and pushes interactive cards to your iPhone.

### Interactive Web Console & AI Conflict Resolver
*   **Dynamic Glassmorphic Dashboard:** The root URL `http://100.96.97.50:5051` hosts a premium dark-theme console rendering statistics tiles (pending/approved/skipped) and list cards for all proposal items.
*   **XHR Status Resolution:** Direct `Approve` and `Skip` actions trigger background fetch requests, resolving the states instantly and animating UI cards without forcing page reloads.
*   **Ollama Conflict Auditor:** Includes an integrated terminal block that lets you trigger a full audit. The API feeds active pending proposals to your local `qwen2.5-coder:14b` model to check for duplicate outreach efforts, overlapping docker ports, or heavy model pulls that might overload VRAM.

---

## 🏁 6. Access Matrix

| Application | Access Path | Description |
| :--- | :--- | :--- |
| **Homepage** | `http://100.96.97.50:3000` | Unified central bookmark dashboard & container telemetry |
| **Open WebUI** | `http://100.96.97.50:8082` | Consolidated AI Portal interface (linked in Homepage) |
| **Nginx Proxy Manager** | `http://100.96.97.50:81` | Subdomain & SSL Routing dashboard (Default: `admin@example.com`/`changeme`) |
| **Cockpit OS Console** | `https://100.96.97.50:9090` | Natively managed host admin web-terminal (HTTPS) |
| **LiteLLM Gateway** | `http://100.96.97.50:4000` | Stateless unified LLM routing API (`Authorization: Bearer nobs_litellm_master_secret_8829401`) |
| **Ollama Daemon** | `http://100.96.97.50:11434` | GPU LLM Inference Engine (Offloaded to host RTX 3060) |
| **ntfy Push Server** | `http://100.96.97.50:5050` | Interactive iOS Push Server (Alex topic: `proposals`) |
| **Approval Queue API** | `http://100.96.97.50:5051` | Task queue database backend & iPhone webhook router |

