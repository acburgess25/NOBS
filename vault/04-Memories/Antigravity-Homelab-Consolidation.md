# Homelab Optimization: Transition to Local-First MCP Loop
**Brain Sync Date:** `2026-06-02`

---

## 🧭 Context & Transition Background

Initially, the AI and DevOps infrastructure on **Tank** was designed as an asynchronous, webhook-driven GitOps loop using Gitea (Source Control + Actions) and Dify (AI Orchestration + Worker Stack). While robust for background healing, it suffered from:
1. **High Overhead**: Running 10+ containers on Tank (Dify requires Postgres, Redis, Sandbox, Weaviate, Web, API, and Worker).
2. **Latency**: File modifications and compilations depended on Git commit cycles and remote synchronization.
3. **OS Separation Friction**: Xcode compiling must run on macOS, necessitating a Gitea Action Runner on the MacBook Pro communicating back and forth with Tank.

To resolve this, the architecture was restructured into a **Local-First MCP (Model Context Protocol) Loop**. 

---

## 🛠️ Architecture Decisions

### 1. Tank Clean Up & De-clutter
* **Ollama & NPM Only**: Decommissioned Gitea, Gitea Runners, and the entire Dify stack on Tank. Tank now runs containerized **Nginx Proxy Manager** for reverse proxy routing, and utilizes the existing **host-native Ollama service** (directly bound to the GPU RTX 3060).
* **Legacy Service Routing**: Configured Nginx Proxy Manager with `host.docker.internal:host-gateway` mapping to reverse-proxy legacy host-level services (Dashboard, Arize Phoenix, Agency, and Voice Chat) to the host system ports without requiring full Docker containerization.
* **Decommissioned Scripts**: Deleted the host-level `ops/tank-web-heal.py` script as reverse proxy and upstream management is fully centralized in Nginx Proxy Manager.

### 2. MacBook Pro Local-First Workspace (Cline + MCP)
* **IDE Agent (Cline/RooCode)**: Installed Cline in the editor. Cline executes terminal commands, reads local workspace files, and compiles iOS builds natively on the MacBook Pro.
* **Ollama over Tailscale**: Configured Cline's Ollama API endpoint to call Tank's GPU at `http://tank.tailscale:11434` or `http://tank.local:11434`, preserving local machine battery/resources.
* **Obsidian MCP Integration**: Mounted the Obsidian vault (`/Users/alexburgess/Library/Mobile Documents/com~apple~CloudDocs/NOBS`) as an active Cline MCP server. The agent can search, read, and write memories to the vault dynamically during coding sessions.

### 3. Cleanup Items Removed
- `.gitea/workflows/build.yml` (Removed from repo)
- `ops/tank/forward_failure.sh` (Removed from repo)

---

## ⚙️ Configuration Memory Reference

### Cline MCP Config Block (`mcpServers` settings):
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

### Trimmed docker-compose.yml Services:
- `nginx-proxy-manager` (ports 80, 81, 443; mapping `host.docker.internal:host-gateway`)
- `open-webui` (port 8082; connected to host-native Ollama and LiteLLM router)
- *(Note: Ollama runs as a host systemd daemon on Tank, utilizing port 11434 directly)*

