# Dockge Reference Manual

**Scope:** File-based Docker Compose orchestration, stack directories configuration, compose structure sync pipelines, and CLI integration on Linux hosts.

---

## 📂 1. Directory Structure Specifications

Dockge is a "compose-native" manager. Unlike Portainer, it does not hide configuration schemas in an internal database; instead, it targets directory structures.

*   **/opt/dockge**: Contains the application execution files (where Dockge's own `compose.yaml` and database metadata are stored).
*   **/opt/stacks**: The base directory containing separate folders for each service stack.
    - Example:
      ```text
      /opt/stacks/
      ├── nginx-proxy-manager/
      │   ├── compose.yaml
      │   └── data/
      ├── open-webui/
      │   └── compose.yaml
      └── litellm-gateway/
          ├── compose.yaml
          └── config.yaml
      ```

---

## 🛠️ 2. Installation & Bootstrap

Execute these commands on Tank to construct directory trees and start the Dockge container.

```bash
# 1. Generate directories
sudo mkdir -p /opt/dockge /opt/stacks

# 2. Set directory ownership (ensure docker-capable user can read/write)
sudo chown -R $USER:$USER /opt/dockge /opt/stacks

# 3. Enter application directory
cd /opt/dockge

# 4. Download composition blueprint
curl https://raw.githubusercontent.com/louislam/dockge/master/compose.yaml --output compose.yaml

# 5. Start Dockge in detached mode
docker compose up -d
```

### The Dockge `compose.yaml` Configurations
```yaml
version: "3.8"
services:
  dockge:
    image: louislam/dockge:1
    restart: unless-stopped
    ports:
      # Expose admin GUI on port 5001
      - 5001:5001
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./data:/app/data
      # Map the stacks directory. Crucial: Host and Container path MUST match.
      - /opt/stacks:/opt/stacks
    environment:
      # Instruct Dockge where to inspect stacks on filesystem
      - DOCKGE_STACKS_DIR=/opt/stacks
```

---

## 🔄 3. Synchronizing Stacks & CLI Commands

Because Dockge operates directly on disk files, you can manage files via standard text editors or git branches.

### A. Syncing Existing/External Stacks
If you create or modify stacks on your MacBook Pro and sync them to Tank (e.g., using Syncthing, Git, or SCP):
1.  Place the new stack folder inside `/opt/stacks/` on Tank.
    - Example path: `/opt/stacks/my-new-app/compose.yaml`
2.  Open the Dockge GUI (`http://100.96.97.50:5001`).
3.  Click the **"Scan Stacks Folder"** button (located in the left-hand navigation pane).
4.  Dockge will parse the new `.yaml` files and list them immediately.

### B. Command Line Control (Docker CLI is the Source of Truth)
Dockge does not intercept standard Docker commands. You can start, stop, or edit containers using raw shell commands, and Dockge will sync its state in real-time.
```bash
# Edit compose configuration natively
nano /opt/stacks/nginx-proxy-manager/compose.yaml

# Restart stack from terminal
cd /opt/stacks/nginx-proxy-manager && docker compose restart

# View logs from terminal
docker compose logs -f
```

---

## 🔌 4. Conversion API & Scripting

Dockge includes an integrated converter to translate legacy `docker run` commands into clean, multi-line `compose.yaml` files.

### A. Manual Conversion
1.  Open the Dockge UI.
2.  Click **"Compose"** > **"Convert"**.
3.  Paste any `docker run` string.
    - Example: `docker run -d -p 80:80 --name web nginx`
4.  The system output yields:
    ```yaml
    services:
      web:
        ports:
          - 80:80
        container_name: web
        image: nginx
    ```

### B. Scripting Stack Deployments via SSH
You can command Dockge-managed stacks remotely over Tailscale SSH:
```bash
# Trigger stack pull and upgrade from MacBook Pro
ssh alex@tank "cd /opt/stacks/litellm-gateway && git pull && docker compose up -d --build"
```
This bypasses UI interfaces completely, allowing developers to manage updates via git commits.
