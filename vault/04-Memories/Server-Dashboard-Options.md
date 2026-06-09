# Research: Home Server Control Dashboards (2026)

**Scope:** Evaluating interfaces for host OS administration, Docker container orchestration, system telemetry monitoring, and unified landing page link portals.

---

## 🗺️ The Home Server Dashboard Landscape

When selecting software to "control the whole server," self-hosted tools fall into three distinct categories based on their proximity to the metal (OS level) vs. container abstractions.

```
                  ┌──────────────────────┐
                  │      Category 1      │
                  │   System OS Admin    │  <-- Direct Host Control (e.g. Cockpit)
                  └──────────┬───────────┘
                             │
                             ▼
                  ┌──────────────────────┐
                  │      Category 2      │
                  │   Docker App Desktop │  <-- Container Store/Desktop (e.g. CasaOS)
                  └──────────┬───────────┘
                             │
                             ▼
                  ┌──────────────────────┐
                  │      Category 3      │
                  │   Unified Link Hub   │  <-- Browser Homepage (e.g. Homarr, Homepage)
                  └──────────────────────┘
```

---

## 🛠️ Category 1: System OS Administration (Deep Host Control)

These tools run natively as system daemons on the host OS. They do not run in Docker, giving them unrestricted access to systemd services, host configuration files, storage disks, and raw hardware sensors.

### Cockpit (The Industry Standard Linux Console)
Developed by Red Hat, Cockpit is a lightweight, secure, web-based administrator console for Linux servers.

*   **Primary Capabilities:**
    *   **Interactive Terminal:** Full web-based shell console directly in the browser.
    *   **systemd Controller:** Start, stop, restart, enable, or disable any host service (e.g., configure and restart your native `ollama` daemon).
    *   **Storage Management:** Format disks, configure partitions, set up RAID arrays, create LVM volumes, monitor SMART disk health, and manage NFS/Samba network mounts.
    *   **System Updates:** Trigger system package upgrades (`apt update && apt upgrade`) visually.
    *   **Log Inspector:** Stream and filter systemd journal logs (replaces command-line `journalctl`).
    *   **Hardware Telemetry:** View historical graphs of CPU, Memory, Disk I/O, and Network load.
    *   **Docker Integration:** Install the `cockpit-podman` plugin to manage container files.
*   **Security Model:** Uses your server's actual PAM authentication (log in using your standard Tank username and password). Extremely secure; if Cockpit is stopped, it consumes 0 resources.
*   **Installation Command (Ubuntu/Tank):**
    ```bash
    # Install cockpit and extensions
    sudo apt update
    sudo apt install -y cockpit cockpit-sensors cockpit-storaged
    
    # Enable and start service (Port 9090)
    sudo systemctl enable --now cockpit.socket
    ```
*   **Access Port:** `https://100.96.97.50:9090` (Note: Uses HTTPS with self-signed certificate by default).

---

## 🌐 Category 2: Docker App Engine (Web Desktop Wrapper)

These platforms sit on top of Docker. They abstract command line interactions behind a visual desktop workspace.

### CasaOS (The Beginner-Friendly App Hub)
CasaOS is a web-based operating system layer designed to turn a standard Linux VPS/server into a simplified personal cloud.

*   **Primary Capabilities:**
    *   **One-Click App Store:** Install databases, torrent clients, media players, or wikis from a community app catalog in a single click.
    *   **Sleek File Manager:** Browse, upload, download, and zip files on the host filesystem directly from the browser (replaces terminal `ls`, `mv`, `cp`).
    *   **Hardware Monitor:** Visual meters representing real-time CPU, RAM, and Disk storage distributions.
    *   **Docker Widget Controller:** View running containers, edit environments, map ports, inspect logs, and toggle power states.
*   **Trade-off:** CasaOS handles app installations via Docker templates. It does *not* manage host system configurations (e.g., systemd services, kernel sysctl tuning, or host-native installations like Ollama).
*   **Installation Command (Tank):**
    ```bash
    curl -fsSL https://get.casaos.io | sudo bash
    ```
*   **Access Port:** `http://100.96.97.50:80` (Binds to port 80 by default; if Nginx Proxy Manager is active on port 80, CasaOS will automatically prompt to bind to an alternate port like 8181).

---

## 📄 Category 3: Unified Service Portals (The Browser Landing Page)

These are bookmark and monitoring engines designed to aggregate all your running services (Open WebUI, NPM, LiteLLM, Cockpit) onto a single browser homepage.

### 1. Homepage (The YAML-Driven Powerhouse)
Homepage is a highly optimized, YAML-configured developer portal.

*   **Why Devs Choose It:** It supports widget integrations to stream data directly into the dashboard card:
    *   **Docker API Integration:** Automatically pings your docker socket to show container states, memory footprint, and labels.
    *   **OS Telemetry:** Connects to Netdata or Glances to show CPU temperature, disk writes, and RAM graphs.
    *   **Service States:** Verifies if endpoints (like `ai.nobsdash.com`) are online.
*   **Overhead:** Negligible (~20MB RAM).
*   **Compose Setup:**
    ```yaml
    services:
      homepage:
        image: ghcr.io/gethomepage/homepage:latest
        container_name: homepage
        ports:
          - 3000:3000
        volumes:
          - ./config:/app/config
          - /var/run/docker.sock:/var/run/docker.sock # Mount socket for container widgets
        restart: unless-stopped
    ```

### 2. Homarr (The Visual Drag-and-Drop Portal)
Homarr offers similar bookmarking features but uses a web interface with drag-and-drop customization instead of editing YAML files on disk.

---

## 🏁 Recommendations for Tank

To achieve the "simplistic life" while maintaining complete control over your hardware and services, the most optimized configuration is **Cockpit + Homepage**.

```
    🚀 User Browser ────> HTTPS (ai.nobsdash.com) ───> Open WebUI
         │
         ├───> Port 9090 ───> Cockpit Socket (Full host controls, Terminal, storage)
         │
         └───> Port 3000 ───> Homepage (Links to WebUI, NPM, LiteLLM, system stats)
```

1.  **Use Cockpit for Server Control:** Installing `cockpit` on Tank gives you a secure terminal shell, service manager (to monitor Ollama), disk space manager, and package updater in the browser.
2.  **Use Homepage for Daily Access:** Deploy a containerized `homepage` instance on Tank. Connect its docker socket so you can see all your homelab URLs (`ai.nobsdash.com`, `git.nobsdash.com`) and system temperatures in one minimal landing page.
