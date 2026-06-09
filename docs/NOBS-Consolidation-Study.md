# Research Report: Unified Architecture for NOBS & Personal AI

This study evaluates whether your current multi-tiered system (Gitea, Gitea Actions, Dify, Ollama, Obsidian, Syncthing, Jan, Tailscale, Nginx Proxy Manager) can be consolidated into **one single solution** or a significantly simplified stack.

---

## 1. The Core Architecture Challenge

Your workflow bridges two distinct domains:
1. **Personal AI & Knowledge Base**: Obsidian (Notes) $\leftrightarrow$ Syncthing $\leftrightarrow$ Jan (Chat Interface).
2. **DevOps & Autonomous Agent Loop**: Gitea (Git/CI) $\leftrightarrow$ Mac Runner (Xcode) $\leftrightarrow$ Dify (Orchestrator) $\leftrightarrow$ Ollama (LLM).

The main friction points are:
* **Operating System Isolation**: Apple restricts iOS compilation (`xcodebuild`) to macOS. Tank (Ubuntu) cannot build your iOS app natively. Therefore, a **true single-machine containerized setup** for building is impossible.
* **Context Fragmentation**: Dify (on Tank) does not natively read your Obsidian vaults unless synced, vectorized, and parsed.
* **Maintenance Overhead**: You are running a minimum of 10 containers on Tank (Dify requires 7 by itself) plus host configurations.

---

## 2. Consolidation Pathways

We evaluated three potential pathways to reduce your stack to a simpler, more unified footprint.

### Option A: The IDE-Centric MCP Stack (Recommended)
This approach shifts the agentic execution to your MacBook Pro (IDE-level) while keeping LLM inference on Tank.

```
┌────────────────────────────────────────────────────────┐
│                   MacBook Pro (M4 Pro)                 │
│                                                        │
│  Xcode / VS Code  ───>  Cline Agent  <──>  Obsidian    │
│       │                      │            (Local Vault)│
│  (Native Build)              │ (Via Obsidian MCP)     │
└───────┼──────────────────────┼────────────────────────┘
        │                      │
        ▼                      ▼ (Tailscale / NPM)
   [Local Git]            [Tank: Ollama GPU]
```

* **How it works**:
  You use a modern agentic IDE extension like **Cline** or **RooCode** on your MacBook. You equip it with the **Model Context Protocol (MCP)**.
  - **Obsidian MCP Server**: Gives the agent direct semantic access to search and read your Obsidian notes.
  - **Local Compiler Access**: Cline runs directly on your Mac, so it can execute `xcodebuild`, observe failures, modify the local files, and compile again—without Git commits or webhook logs.
  - **Tank's Role**: Tank is simplified to run only **Ollama** and **Tailscale/NPM**.
* **Consolidated Components**:
  - **Eliminated**: Dify stack (7 containers), Weaviate, Gitea, Gitea Runner, Gitea Actions, Syncthing, and custom webhook python scripts.
  - **Retained**: Ollama (Tank), Obsidian (Mac), Tailscale, and your IDE.
* **Why it works better**: The agent loops *locally* inside your workspace. If a build fails, it fixes the file instantly on disk and recompiles.

---

### Option B: The Open WebUI Unified Portal
This approach consolidates the chat interface (Jan), RAG database (Weaviate), and orchestration (Dify) into a single container.

```
┌──────────────────────────────────────────────────────────────────┐
│                         Tank (Server)                            │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │                        Open WebUI                          │  │
│  │                                                            │  │
│  │  - Chat (Jan replacement)       - Pipelines (Dify replacement)│  │
│  │  - RAG / Obsidian Uploads       - Internal Vector Store    │  │
│  └──────────────────────────────┬─────────────────────────────┘  │
│                                 │                                │
│                                 ▼                                │
│                            Ollama GPU                            │
└──────────────────────────────────────────────────────────────────┘
```

* **How it works**:
  **Open WebUI** is no longer just a frontend; it has evolved into a full-featured workspace platform.
  - **Pipelines**: Open WebUI can run python scripts and workflows (similar to Dify) to handle Gitea webhooks, run agents, and return code repairs.
  - **RAG & Docs**: It has a built-in vector database. You can sync your Obsidian folders directly into Open WebUI's documents page to make your personal knowledge base available to all models.
  - **Unified Client**: You access Open WebUI via the browser (on Mac/iPhone), removing the need for Jan.
* **Consolidated Components**:
  - **Eliminated**: Dify API, Dify Worker, Dify Sandbox, Dify Web, Weaviate, Redis, and Jan.
  - **Retained**: Open WebUI (1 container), Ollama (1 container), PostgreSQL (1 container), Gitea/NPM.
* **Why it works better**: It reduces the server footprint on Tank by 70% while maintaining the server-side webhook automation.

---

### Option C: Cloud-Hosted Alternative (GitHub Copilot Workspace)
* **How it works**: Replace Gitea, runners, and Dify with GitHub's commercial cloud platform.
* **Consolidated Components**: No local server required at all.
* **Why it is rejected**: It violates your design decisions to use local models (Qwen 2.5), local hosting (Tank), and data privacy (Tailscale VPN).

---

## 3. Comparison Matrix

| Metric | Current Stack (Gitea + Dify) | Option A (MCP + Cline) | Option B (Open WebUI Stack) |
| :--- | :--- | :--- | :--- |
| **Complexity (Containers)** | High (12+ containers) | **Low (2-3 containers)** | Medium (5-6 containers) |
| **Auto-Heal Trigger** | Commits / Webhooks (Passive) | **Interactive Run / CLI (Active)** | Commits / Webhooks (Passive) |
| **Obsidian Access** | Manual Copy / Sync | **Native Real-time (MCP)** | Unified Sync Directory |
| **iOS Build Support** | Indirect (Via Gitea Runner) | **Direct (Native on Mac)** | Indirect (Via Gitea Runner) |
| **Chat Interface** | Jan (Mac) | IDE Sidebar / Cline | Web Interface (Self-hosted) |

---

## 4. Conclusion & Recommendation

If your primary goal is **reducing system maintenance, file-syncing latency, and system resource usage**, **Option A (The IDE + MCP Stack)** is the cleanest single solution.

By using an MCP-capable agent (like Cline) on your MacBook Pro:
1. The agent reads your local **Obsidian** notes natively via an MCP bridge.
2. The agent compiles your **Xcode** project natively on your M4 Pro.
3. The agent calls **Ollama** on Tank over Tailscale to leverage the RTX 3060 for fast local inference.
4. You completely decommission the Dify stack, Gitea runners, and Syncthing.
