# Deep Research: Next-Gen Local AI Workspaces (MCP, Cline, Aider & LiteLLM)
**Date:** `2026-06-02`

---

## 🧭 The State of Local AI Coding Agents (2026)

The developer community has shifted decisively away from cloud-only code generation toward **local-first agentic loops** governed by the **Model Context Protocol (MCP)**. Instead of chat portals, AI models are integrated directly as system executors with permission-gated tools.

### 1. IDE Agent Suite: Cline vs. Aider

#### **Cline (VS Code / Cursor Integration)**
*   **Status**: Active & Leading. Following the community discontinuation of Roo Code, Cline has become the gold standard for GUI-based developer agents.
*   **Why devs use it**: High visual safety (approval prompt per action), robust built-in diff editor, and out-of-the-box MCP server management.
*   **Best fit for you**: Interactive code refactoring and multi-file code editing inside your Xcode/VS Code environment.

#### **Aider (Terminal CLI Agent)**
*   **Status**: Active & Highly Trending.
*   **Why devs use it**: Git-native code edits. Aider maps the repository, makes edits, runs tests in the terminal, and auto-commits changes with detailed commit messages. If a change fails, you can `git reset` instantly.
*   **Best fit for you**: High-speed command-line tasks, running scripts, and automating repetitive codebase updates.

---

## 🔌 Trending MCP Servers for System Integrations

Developers are using the following open-source MCP servers to expand their agent workspaces:

| MCP Server | GitHub Repository / Origin | Capability for Your Lab |
| :--- | :--- | :--- |
| **Sequential Thinking** | `modelcontextprotocol/servers` | Enables the agent to structure reasoning step-by-step, evaluating assumptions before editing code (minimizes logic bugs). |
| **Docker Manager** | `mcp-servers/docker` | Allows Cline to query status, boot containers, inspect logs, and manage stacks on Tank directly from your Mac. |
| **Playwright Browser** | `modelcontextprotocol/servers/playwright` | Allows the agent to open a chromium browser, take screenshots, click buttons, and scrape web pages (great for debugging web views). |
| **Git Integration** | `modelcontextprotocol/servers/git` | Direct tool commands to review git history, log diffs, and generate pull requests. |
| **PostgreSQL / SQLite** | `modelcontextprotocol/servers/postgres` | Connects directly to databases to query schemas, inspect values, or mock datasets. |

---

## 🚀 Optimizing Your Current Stack

Since you already have **LiteLLM** (port 4000) and **Ollama** running natively on Tank, you have the exact building blocks to build an elite, enterprise-grade AI router.

```
                  ┌──────────────────────┐
                  │ MacBook Pro IDE/CLI  │
                  └──────────┬───────────┘
                             │
                             ▼ (Single API Point)
                  ┌──────────────────────┐
                  │ Tank: LiteLLM (:4000)│
                  └────┬────────────┬────┘
                       │            │
         (Local VRAM)  ▼            ▼  (Cloud Fallback)
         Tank Ollama (14B)       DeepSeek / Claude 3.7
```

### 1. Configure LiteLLM as Your Unified Gateway
Instead of pointing Cline directly to Ollama, point it to **LiteLLM on Tank** (`http://100.96.97.50:4000/v1`).
Configure LiteLLM (`config.yaml`) to manage:
- **Primary**: Local `qwen2.5-coder:14b` running on Tank's native Ollama.
- **Secondary (Mac Local)**: MacBook's local Ollama (useful when traveling offline).
- **Fallback (Cloud)**: Fall back to high-tier APIs (like Claude 3.7 or DeepSeek-Coder-V2) when the agent hits complex, structural bugs that local 14B models struggle to resolve.
This keeps your billing at $0 for 90% of development, with seamless API fallbacks.

### 2. Tailscale SSH Integration
To allow your Mac agent to execute commands safely on Tank (such as restarting custom backend services like `nobs-memories-api`):
*   Enable **Tailscale SSH** on Tank and your MacBook Pro.
*   Cline can execute commands natively on Tank over Tailscale SSH without managing passwords or manual SSH keys:
    ```bash
    ssh alex@tank "docker restart nobs-memories-api"
    ```

---

## 📂 Vault Integration & RAG Best Practices

To maximize the value of the **Obsidian MCP Server** inside Cline:
1.  **Structure a `.prompting/` or `.instructions/` folder** in your vault. Put templates there representing:
    - Code styling standards for the NOBS iOS app.
    - API documentation for `nobs-memories-api` and `nobs-llm-router`.
2.  **Add a `.clinerules` file** to the root of your code repositories.
    *   Instruct Cline to always call the `obsidian` MCP tool to look up directories inside your vault before implementing complex structural changes.
    *   This forces the AI agent to reference your personal notes and design decisions dynamically.
