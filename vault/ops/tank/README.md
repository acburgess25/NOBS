# DevOps & AI Lab Setup Guide: Local-First MCP Stack

This guide details the deployment of the simplified, high-performance homelab stack. This architecture leverages **Tank** for heavy GPU LLM inference (Ollama) and reverse proxy routing, and your **MacBook Pro** for local-first agentic coding (Cline + Obsidian MCP integration + Xcode compiling).

```
┌────────────────────────────────────────────────────────┐
│                   MacBook Pro (M4 Pro)                 │
│                                                        │
│  Xcode / VS Code  ───>  Cline Agent  <──>  Obsidian    │
│  (Native Builds)             │            (Local Vault)│
│                              │ (Via Obsidian MCP)     │
└──────────────────────────────┼────────────────────────┘
                               │
                               ▼ (Tailscale / NPM)
                          [Tank: Ollama]
                         [Tank: Legacy Proxy]
```

---

## Part 1: Setting up "Tank" (Server)

### 1. Run Optimizations & Install NVIDIA Drivers
Transfer `setup_tank.sh` to Tank and execute it:
```bash
# Transfer script to Tank
scp ops/tank/setup_tank.sh user@tank.local:/tmp/
# SSH into Tank and execute script
ssh -t user@tank.local "sudo chmod +x /tmp/setup_tank.sh && sudo /tmp/setup_tank.sh"
# Reboot Tank to apply proprietary drivers and system-wide sysctl optimizations
ssh user@tank.local "sudo reboot"
```

Verify GPU container integration:
```bash
# SSH back into Tank and test nvidia-smi in Docker
docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu22.04 nvidia-smi
```

### 2. Deploy Services via Docker Compose
Create `/opt/homelab` directory and place `docker-compose.yml` there:
```bash
ssh user@tank.local "sudo mkdir -p /opt/homelab && sudo chown -R 1000:1000 /opt/homelab"
scp ops/tank/docker-compose.yml user@tank.local:/opt/homelab/docker-compose.yml
ssh user@tank.local "cd /opt/homelab && docker compose up -d"
```

Verify Nginx Proxy Manager is up and healthy:
```bash
ssh user@tank.local "docker compose -f /opt/homelab/docker-compose.yml ps"
```

### 3. Nginx Proxy Manager Setup & Legacy Migration
Disable the old host-level Nginx server on Tank to free up ports 80/443:
```bash
ssh user@tank.local "sudo systemctl disable --now nginx"
```

Access the Admin Web Console at `http://<TANK_IP>:81` (Default login: `admin@example.com` / `changeme`).

#### Proxy Hosts Configuration
Add Proxy Hosts for your `*.nobsdash.com` subdomains:
- **Ollama**: Route `ollama.nobsdash.com` $\rightarrow$ Forward Port `11434` to `host.docker.internal` (using `http` - since Ollama runs natively on the host, restrict access to Tailscale / local network).
- **AI Web Portal (Open WebUI)**: Route `ai.nobsdash.com` $\rightarrow$ Forward Port `8082` to container `open-webui` (using `http`). This acts as your single app to call all different AIs.
- Request Let's Encrypt Wildcard SSL Certificates for `*.nobsdash.com` in NPM.

#### Migrating Legacy Host Services
For the main domain `nobsdash.com` (or specific subdomain proxy host), configure the following **Custom Locations** in NPM to proxy back to the legacy host machine services using the container gateway bridge:
- **Dashboard**: `/dashboard` $\rightarrow$ Forward to `http://host.docker.internal:8787/dashboard`
- **Research (Phoenix)**: `/research` $\rightarrow$ Forward to `http://host.docker.internal:6006/research`
- **Agency**: `/agency` $\rightarrow$ Forward to `http://host.docker.internal:8070/agency`
- **Voice Chat**: `/chat` $\rightarrow$ Forward to `http://host.docker.internal:8090/chat`

---

## Part 2: Local MacBook Pro Configuration (Cline + MCP)

Under this local-first architecture, your MacBook Pro compiles code and runs the agent workspace inside VS Code or Cursor using the **Cline** extension. Cline connects to Tank's GPU for LLM calls and accesses your local Obsidian knowledge base via the Model Context Protocol (MCP).

### 1. Configure Cline to use Ollama on Tank
1. Open VS Code and install the **Cline** extension.
2. Open Cline Settings (gear icon in the top right).
3. Set **API Provider** to `Ollama`.
4. Set **Base URL** to your Tank address:
   - For Tailscale: `http://tank.tailscale:11434` (Recommended)
   - For Local network: `http://tank.local:11434`
5. Under **Model**, choose:
   - `qwen2.5-coder:14b` (Highly recommended for coding)
   - `llama3.1:8b` (For general agent tasks)

Ensure the model is pulled on Tank:
```bash
ssh tank "ollama pull qwen2.5-coder:14b"
```

### 2. Configure Obsidian MCP Server (Memory Connection)
To allow Cline to read, search, and synchronize code patterns with your Obsidian vault:
1. In your MacBook's Cline settings, find the **MCP Servers** section.
2. Add a new MCP server configuration using the standard node-based Obsidian MCP client:
   ```json
   {
     "mcpServers": {
       "obsidian": {
         "command": "npx",
         "args": [
           "-y",
           "@modelcontextprotocol/server-obsidian",
           "--vault-path",
           "/Users/alexburgess/Library/Mobile Documents/com~apple~CloudDocs/NOBS"
         ]
       }
     }
   }
   ```
3. Cline now has custom tool capabilities to query your vault notes, insert memories, and pull documentation templates automatically while writing code.

### 3. Running Builds Locally
Because the agent runs inside your MacBook's terminal context, you can command it to build and fix Xcode projects interactively:
- **Prompt**: `"Compile the app and fix any errors"`
- Cline will run `xcodebuild -project NOBS.xcodeproj ...`, capture compile failures, search your local files/Obsidian logs, make edits, and compile again until it builds clean.
- This replaces the slow commit-push-webhook circle with a 5-second local auto-heal loops.
