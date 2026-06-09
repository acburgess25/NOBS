# 🧠 Developer Homelab & Self-Improving AI Database

**Last Updated:** `2026-06-02`  
**Target Server:** `Tank` (Ubuntu 26.04 LTS, AMD Ryzen 5 5600X3D, NVIDIA RTX 3060 12GB, NVMe SSD)  
**Security Model:** Local-First, air-gapped preference, Tailscale Encrypted Overlay Network.

---

## 🧭 Table of Contents
- [🧠 Developer Homelab & Self-Improving AI Database](#-developer-homelab--self-improving-ai-database)
  - [🧭 Table of Contents](#-table-of-contents)
  - [📦 Part 1: The Dev Home Server Stack Landscape (2026)](#-part-1-the-dev-home-server-stack-landscape-2026)
    - [1. Self-Hosted PaaS Platforms](#1-self-hosted-paas-platforms)
      - [A. Coolify (The Feature-Rich Giant)](#a-coolify-the-feature-rich-giant)
      - [B. Dokploy (The Lightweight Swarm-Based Challenger)](#b-dokploy-the-lightweight-swarm-based-challenger)
      - [C. CapRover (The Stable Veteran)](#c-caprover-the-stable-veteran)
      - [D. Cosmos Cloud (The Security-First Gateway)](#d-cosmos-cloud-the-security-first-gateway)
      - [E. Comparison Matrix](#e-comparison-matrix)
    - [2. File-Based & Container Orchestrators](#2-file-based--container-orchestrators)
      - [A. Dockge (Compose-First UI)](#a-dockge-compose-first-ui)
      - [B. Portainer (Full Infrastructure Manager)](#b-portainer-full-infrastructure-manager)
    - [3. Modern Reverse Proxies & SSL Pipelines](#3-modern-reverse-proxies--ssl-pipelines)
      - [A. Nginx Proxy Manager (NPM)](#a-nginx-proxy-manager-npm)
      - [B. Caddy (The Modern Automatic-SSL Proxy)](#b-caddy-the-modern-automatic-ssl-proxy)
    - [4. Homelab Metrics \& Log Aggregators](#4-homelab-metrics--log-aggregators)
  - [🤖 Part 2: Self-Improving AI (SIA) Agent Loops](#-part-2-self-improving-ai-sia-agent-loops)
    - [1. The Agent Loop Architecture](#1-the-agent-loop-architecture)
    - [2. Model Context Protocol (MCP) Integration](#2-model-context-protocol-mcp-integration)
    - [3. Code Execution & Validation (Local Xcode Bridge)](#3-code-execution--validation-local-xcode-bridge)
    - [4. Python Script Template: `sia_loop.py`](#python-script-template-sia_looppy)
    - [5. Preventing Digital Amnesia (Permanent Memory Store)](#5-preventing-digital-amnesia-permanent-memory-store)
    - [6. LiteLLM Unified Gateway Router Configuration](#6-litellm-unified-gateway-router-configuration)
  - [⚙️ Part 3: Tank Hardware Optimization & OS Tuning](#️-part-3-tank-hardware-optimization--os-tuning)
    - [1. AMD Ryzen 5 5600X3D CPU (3D V-Cache Tuning)](#1-amd-ryzen-5-5600x3d-cpu-3d-v-cache-tuning)
      - [A. Thread Pinning & SMT Avoidance for Ollama](#a-thread-pinning--smt-avoidance-for-ollama)
      - [B. Linux Scheduler Tweaks & Performance Governor](#b-linux-scheduler-tweaks--performance-governor)
      - [C. BIOS/UEFI Tweaks](#c-biosuefi-tweaks)
    - [2. NVIDIA RTX 3060 12GB GPU Tuning](#2-nvidia-rtx-3060-12gb-gpu-tuning)
      - [A. CUDA & Docker Container Toolkit Installation](#a-cuda--docker-container-toolkit-installation)
      - [B. Ollama VRAM Optimization & Math](#b-ollama-vram-optimization--math)
    - [3. PCIe Gen 4 NVMe SSD & Swappiness Tuning](#3-pcie-gen-4-nvme-ssd--swappiness-tuning)
      - [A. Disk I/O Schedulers](#a-disk-io-schedulers)
      - [B. Mount Optimizations (`/etc/fstab`)](#b-mount-optimizations-etcfstab)
      - [C. Swap File & Dirty Ratio Control](#c-swap-file--dirty-ratio-control)
    - [4. Optimizing the Docker Engine on Tank](#4-optimizing-the-docker-engine-on-tank)
      - [A. `/etc/docker/daemon.json`](#a-etcdockerdaemonjson)
    - [5. Tailscale & Linux TCP Stack Tuning](#5-tailscale--linux-tcp-stack-tuning)
      - [A. Network sysctl Optimization (`/etc/sysctl.d/99-homelab-network.conf`)](#a-network-sysctl-optimization-etcsysctld99-homelab-networkconf)
      - [B. Tailscale SSH Configuration](#b-tailscale-ssh-configuration)

---

## 📦 Part 1: The Dev Home Server Stack Landscape (2026)

### 1. Self-Hosted PaaS Platforms
Self-hosted Platform-as-a-Service (PaaS) engines automate DNS creation, reverse proxy config, SSL provisioning, database lifecycle, and Git-to-deploy workflows. They turn a single Linux machine into a private Heroku or Vercel.

#### A. Coolify (The Feature-Rich Giant)
*   **Architecture:** Written in Laravel, manages standalone Docker engines or remote servers over SSH. Uses Traefik or Caddy for routing.
*   **Best For:** All-in-one dashboards, team management, multi-environment setups, and one-click deployment from 280+ templates (databases, key-value stores, monitoring).
*   **Resource Overhead:** High (requires ~1.5–2GB RAM and 2 cores to run smoothly).
*   **Install Command:**
    ```bash
    curl -fsSL https://cdn.coollabs.io/coolify/install.sh | bash
    ```
*   **Docker Compose Snippet:** Coolify operates by spinning up its own control database and managing docker sockets.

#### B. Dokploy (The Lightweight Swarm-Based Challenger)
*   **Architecture:** Built on Node.js/TypeScript. Leverages Docker Swarm (even on a single-node host) and Traefik.
*   **Best For:** Lightweight server footprints, high deployment speed, and pure Docker Compose support without additional database bloat.
*   **Resource Overhead:** Very Low (~200MB idle RAM).
*   **Install Command:**
    ```bash
    curl -sSL https://dokploy.com/install.sh | sh
    ```

#### C. CapRover (The Stable Veteran)
*   **Architecture:** Node.js daemon managing a Docker Swarm. Uses Nginx for SSL and reverse routing.
*   **Best For:** Fire-and-forget stability, minimal state failures during server upgrades, and multi-node container routing.
*   **Resource Overhead:** Low-to-Medium (~300MB RAM).
*   **Install Command:**
    ```bash
    docker run -p 80:80 -p 443:443 -p 3000:3000 -v /var/run/docker.sock:/var/run/docker.sock -v /captain:/captain caprover/caprover
    ```

#### D. Cosmos Cloud (The Security-First Gateway)
*   **Architecture:** Go-based single binary that functions as a security gateway, reverse proxy (using Caddy/custom routing), and container orchestrator.
*   **Best For:** Homelabs exposed to the web. It includes built-in MFA/SSO, a secure WireGuard VPN, container sandbox isolation, automatic SSL, and protection against malicious IP addresses.
*   **Resource Overhead:** Low (~150MB RAM).
*   **Install Command:**
    ```bash
    docker run -d --name cosmos-server -p 80:80 -p 443:443 -p 443:443/udp -v /var/run/docker.sock:/var/run/docker.sock -v /var/lib/cosmos:/var/lib/cosmos --privileged cosmos-cloud/cosmos
    ```

#### E. Comparison Matrix

| Criteria | Coolify | Dokploy | CapRover | Cosmos Cloud |
| :--- | :--- | :--- | :--- | :--- |
| **Primary Focus** | Heroku/Vercel Clone | Lightweight Deployer | Cluster Orchestration | Homelab Security/VPN |
| **Proxy Engine** | Traefik | Traefik | Nginx | Custom Go/Caddy |
| **Overhead** | High (1.5GB+ RAM) | Low (~200MB RAM) | Low (~300MB RAM) | Very Low (~150MB) |
| **Database Support** | GUI-integrated | Compose/Docker | CLI/One-click apps | Docker native |
| **Multi-Server** | Native (SSH agents) | Coming soon | Native (Swarm) | No |
| **SSO / VPN** | No (Third-party) | No | No | Built-in (WireGuard) |

---

### 2. File-Based & Container Orchestrators

For developers who prefer writing raw `docker-compose.yml` configurations rather than abstracting them behind a PaaS web panel, these managers allow you to organize, inspect, and monitor stacks.

#### A. Dockge (Compose-First UI)
*   **Philosophy:** Dockge is a frontend for directory-based Docker Compose setups. It does *not* store configurations in a proprietary database. Your local directories of `docker-compose.yml` files remain the absolute source of truth.
*   **Why Devs Use It:** You can edit files natively in VS Code, execute `git commit`, and Dockge will pick up the changes instantly. If you delete Dockge, your applications remain running and fully manageable via command line.
*   **Compose Setup:**
    ```yaml
    services:
      dockge:
        image: louislam/dockge:1
        restart: unless-stopped
        ports:
          - 5001:5001
        volumes:
          - /var/run/docker.sock:/var/run/docker.sock
          - /opt/stacks:/opt/stacks
        environment:
          - DOCKGE_STACKS_DIR=/opt/stacks
    ```

#### B. Portainer (Full Infrastructure Manager)
*   **Philosophy:** A complete visualizer for Docker sockets, Swarm clusters, and Kubernetes nodes.
*   **Why Devs Use It:** For granular management of networks, volumes, image layers, system logs, and container stats.
*   **Trade-off:** "Portainer database lock." Configurations created inside the Portainer GUI are stored in its internal database. Editing files outside Portainer can cause database desynchronization.

---

### 3. Modern Reverse Proxies & SSL Pipelines

#### A. Nginx Proxy Manager (NPM)
*   **Features:** Web GUI interface to configure Nginx proxies, auto-generate Let's Encrypt certificates, enforce SSL, and configure access lists.
*   **Tuning for local-only domains:** Point subdomains (e.g., `git.nobsdash.com`) to Tank's local Tailscale IP (`100.96.97.50`) and request DNS-01 Let's Encrypt verification (using Cloudflare or GoDaddy API keys) so your certificates are valid without exposing Tank to HTTP/HTTPS inbound internet traffic.

#### B. Caddy (The Modern Automatic-SSL Proxy)
*   **Features:** Single configuration file (`Caddyfile`), standard HTTP/3 support, automatic certificate generation (HTTP-01 or DNS-01 verification), and a lightweight footprint.
*   **Caddyfile Example for Tailscale:**
    ```caddy
    git.nobsdash.com {
        reverse_proxy host.docker.internal:3000
    }
    dify.nobsdash.com {
        reverse_proxy host.docker.internal:8080
    }
    ```

---

### 4. Homelab Metrics & Log Aggregators
*   **Netdata:** Real-time host telemetry (1s updates). Tracks CPU core temperatures, L3 cache thrashing, GPU power draws, and NVMe wear levels out of the box with zero configuration.
*   **Dozzle:** A single, lightweight page that streams logs from all running Docker containers simultaneously. Excellent for debugging microservices without SSH tailing.

---

## 🤖 Part 2: Self-Improving AI (SIA) Agent Loops

Self-improving AI loops move LLM output out of chat widgets and integrate them directly into local terminal filesystems, build runners, and execution compilers.

### 1. The Agent Loop Architecture
```
                  ┌──────────────────────┐
                  │ Perceive Workspace   │
                  │   - Read files       │
                  │   - Read git status  │
                  └──────────┬───────────┘
                             │
                             ▼
                  ┌──────────────────────┐
                  │ Plan Strategy        │
                  │   - Sequential Think │
                  └──────────┬───────────┘
                             │
                             ▼
                  ┌──────────────────────┐
                  │ Act (Run Tool/Code)  │
                  │   - Write code       │
                  │   - Run compiler/test│
                  └──────────┬───────────┘
                             │
                             ▼
                  ┌──────────────────────┐
                  │ Observe Outcome      │
                  │   - Check exit codes │
                  │   - Parse compilation│
                  └─────┬──────────┬─────┘
                        │          │
           (Test Fails) │          │ (Test Passes)
                        ▼          ▼
            ┌──────────────┐    ┌──────────────┐
            │ Diagnose Bug │    │ Git Commit   │
            │ Apply patch  │    │ Log Learnings│
            └──────────────┘    └──────────────┘
```

### 2. Model Context Protocol (MCP) Integration
MCP is an open standard that decouples models from system tools. By running an MCP host (like Claude Desktop or Cline) on your MacBook Pro:
1.  **System Bridge:** The agent can query Tank’s Docker containers using the `docker-mcp` server.
2.  **Vault Integration:** The agent reads memories, patterns, and architectural rules from Obsidian via the `obsidian-mcp` server.
3.  **Local Execution:** The agent interacts directly with local tools (`xcodebuild`, file system editors, shell scripts) on the MacBook Pro.

### 3. Code Execution & Validation (Local Xcode Bridge)
Because compilation of iOS applications (Swift/Objective-C) requires the macOS SDK and compiler binaries, the agent loops must follow a split-environment design:
*   **Inference Host:** Tank (handles processing LLM queries on RTX 3060 to preserve Mac battery and performance).
*   **Execution & Compiler Host:** MacBook Pro (native environment for running compilers and test simulations).
*   **Bridge:** Tailscale SSH and shared folders (via Syncthing or local Git repositories).

---

### 4. Python Script Template: `sia_loop.py`
This script runs on the MacBook Pro, coordinating local builds (`xcodebuild`), extracting compiler failures, and using Tank’s LiteLLM gateway to generate fixes, apply patches, and commit modifications.

```python
#!/usr/bin/env python3
import os
import subprocess
import sys
import json
import urllib.request

# Configuration
LITELLM_ENDPOINT = "http://100.96.97.50:4000/v1/chat/completions" # Tank's LiteLLM Router
MODEL_NAME = "qwen2.5-coder:14b"
WORKSPACE_DIR = os.getcwd()
TEST_COMMAND = "xcodebuild -workspace nobs-app.xcworkspace -scheme nobs-app -sdk iphonesimulator clean build"
LEARNINGS_FILE = os.path.join(WORKSPACE_DIR, "04-Memories", "learnings.json")
MAX_RETRIES = 5

def run_tests():
    print("🚀 Running compilation test suite...")
    process = subprocess.Popen(
        TEST_COMMAND,
        shell=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        cwd=WORKSPACE_DIR
    )
    stdout, stderr = process.communicate()
    return process.returncode, stdout.decode('utf-8'), stderr.decode('utf-8')

def read_learnings():
    if os.path.exists(LEARNINGS_FILE):
        try:
            with open(LEARNINGS_FILE, 'r') as f:
                return json.load(f)
        except Exception:
            return []
    return []

def save_learning(error_pattern, fix_strategy):
    learnings = read_learnings()
    learnings.append({"error": error_pattern, "fix": fix_strategy})
    os.makedirs(os.path.dirname(LEARNINGS_FILE), exist_ok=True)
    with open(LEARNINGS_FILE, 'w') as f:
        json.dump(learnings[-50:], f, indent=2) # Keep last 50 learnings

def generate_patch(error_log, code_files_content, past_learnings):
    print("🧠 Querying Tank LLM for code correction...")
    prompt = f"""
You are an autonomous self-improving engineering loop.
A test/compilation build failed. Your task is to output a code patch to resolve the issue.

---
PAST LEARNINGS (Avoid repeating these failures):
{json.dumps(past_learnings, indent=2)}

---
COMPILER ERROR LOG:
{error_log}

---
CURRENT FILE CONTENTS:
{code_files_content}

---
Format your response as a valid unified diff block. Do not write explanations, write ONLY the raw git patch.
"""
    data = json.dumps({
        "model": MODEL_NAME,
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.1
    }).encode('utf-8')
    
    req = urllib.request.Request(
        LITELLM_ENDPOINT, 
        data=data, 
        headers={'Content-Type': 'application/json'}
    )
    
    try:
        with urllib.request.urlopen(req) as response:
            result = json.loads(response.read().decode('utf-8'))
            return result['choices'][0]['message']['content']
    except Exception as e:
        print(f"❌ Failed to reach LLM gateway: {e}")
        return None

def apply_patch(patch_content):
    patch_path = os.path.join(WORKSPACE_DIR, "patch.diff")
    with open(patch_path, "w") as f:
        f.write(patch_content)
    
    res = subprocess.run(f"git apply {patch_path}", shell=True, cwd=WORKSPACE_DIR)
    os.remove(patch_path)
    return res.returncode == 0

def git_commit(task_description):
    print("✅ Build passed! Committing changes...")
    subprocess.run("git add .", shell=True, cwd=WORKSPACE_DIR)
    commit_msg = f"SIA Loop Fix: Auto-repaired compiler warning/error for: {task_description}"
    subprocess.run(f'git commit -m "{commit_msg}"', shell=True, cwd=WORKSPACE_DIR)

def git_rollback():
    print("⚠️ Build failed after patch. Rolling back modifications...")
    subprocess.run("git reset --hard HEAD", shell=True, cwd=WORKSPACE_DIR)

def main():
    task_desc = sys.argv[1] if len(sys.argv) > 1 else "Unknown Task"
    print(f"🔧 Starting healing loop for task: {task_desc}")
    
    for attempt in range(1, MAX_RETRIES + 1):
        print(f"\n--- Loop Iteration {attempt}/{MAX_RETRIES} ---")
        code, out, err = run_tests()
        
        if code == 0:
            print("🚀 Build compiles successfully!")
            git_commit(task_desc)
            sys.exit(0)
            
        print("❌ Build failure detected. Extracting log details...")
        # Gather relevant files
        files_to_send = {}
        for root, _, files in os.walk(WORKSPACE_DIR):
            for file in files:
                if file.endswith(('.swift', '.m', '.h')) and ".git" not in root:
                    path = os.path.join(root, file)
                    with open(path, 'r') as f:
                        files_to_send[file] = f.read()
                        
        past_learnings = read_learnings()
        error_context = err if len(err) > 10 else out[-4000:]
        
        patch = generate_patch(error_context, json.dumps(files_to_send), past_learnings)
        if not patch:
            print("❌ No patch generated. Exiting.")
            sys.exit(1)
            
        print("🩹 Applying patch...")
        if apply_patch(patch):
            # Test again
            test_code, _, _ = run_tests()
            if test_code == 0:
                print("🎉 Patch corrected the compilation error!")
                save_learning(error_context[:200], f"Applied patch: {patch[:200]}")
                git_commit(task_desc)
                sys.exit(0)
            else:
                print("❌ Patch applied but compilation still fails.")
                git_rollback()
        else:
            print("❌ Failed to apply generated patch.")
            git_rollback()
            
    print("💔 Execution loop reached maximum retries without healing the build.")
    sys.exit(1)

if __name__ == "__main__":
    main()
```

---

### 5. Preventing Digital Amnesia (Permanent Memory Store)
To ensure your agent does not repeat failures or lose system context during terminal resets:
1.  **Save Failures Contextually:** Store the patterns of syntax differences or compile flags (e.g., Swift concurrency modifications needed for iOS 17+) in `04-Memories/learnings.json`.
2.  **MCP Integration:** In `.clinerules`, direct the agent to read `/04-Memories/learnings.json` prior to any code generation task:
    ```text
    CRITICAL: Always query learnings.json before generating code to see what compiler errors occurred previously and avoid rewriting known bad syntax.
    ```

---

### 6. LiteLLM Unified Gateway Router Configuration
Deploying LiteLLM on Tank exposes a single OpenAI-compatible endpoint. It handles routing and failover between local Ollama (RTX 3060 GPU) and fallback APIs (Claude / DeepSeek) if the local model gets stuck in an infinite fix-fail loop.

**Sample `config.yaml` for LiteLLM on Tank:**
```yaml
model_list:
  - model_name: qwen2.5-coder:14b
    litellm_params:
      model: ollama/qwen2.5-coder:14b
      api_base: http://localhost:11434
      tpm: 100000
      rpm: 1000
  - model_name: fallback-llm
    litellm_params:
      model: deepseek/deepseek-coder
      api_key: "os.environ/DEEPSEEK_API_KEY"
  - model_name: claude-3-7-sonnet
    litellm_params:
      model: anthropic/claude-3-7-sonnet-20250219
      api_key: "os.environ/ANTHROPIC_API_KEY"

router_settings:
  routing_strategy: latency-based-routing
  allowed_fails: 2
  cooldown_time: 10
```

---

## ⚙️ Part 3: Tank Hardware Optimization & OS Tuning

To extract maximum performance from the CPU, GPU, storage interfaces, and network on Tank, implement the following low-level configurations.

### 1. AMD Ryzen 5 5600X3D CPU (3D V-Cache Tuning)
The Ryzen 5 5600X3D features a massive 96MB L3 cache stack on top of a single 6-core CCD. 

#### A. Thread Pinning & SMT Avoidance for Ollama
Running LLM inference on CPU is highly memory-bandwidth constrained. spawner threads across SMT (hyperthread) boundaries degrades performance because threads share cache access, creating memory contention.
*   **Optimization:** When running CPU-bound models or configuring llama.cpp, limit the execution threads to the physical cores (`6` threads) and pin them to cores `0-5` to avoid using hyperthreads `6-11`.
*   **Command Template (Pinning Ollama/Llama.cpp process):**
    ```bash
    taskset -c 0,1,2,3,4,5 numactl --localalloc ollama run qwen2.5-coder:14b
    ```

#### B. Linux Scheduler Tweaks & Performance Governor
*   Set the active CPU frequency governor to `performance` to keep cores from downclocking during short compilation bursts.
*   **Configure via systemd startup script:**
    ```bash
    # Create optimizer script /usr/local/bin/optimize-cpu.sh
    #!/usr/bin/env bash
    # Set performance scaling governor
    echo "performance" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
    # Adjust kernel task scheduler for latency
    sysctl -w kernel.sched_latency_ns=4000000
    sysctl -w kernel.sched_wakeup_granularity_ns=1000000
    sysctl -w kernel.sched_migration_cost_ns=500000
    ```

#### C. BIOS/UEFI Tweaks
1.  **Precision Boost Overdrive (PBO):** Enable in BIOS and apply a negative curve optimizer offset (e.g., `-20` or `-30` All Core) to lower voltages, reduce thermals, and maximize sustain boost clocks.
2.  **AMD SVM Virtualization:** Ensure SVM is enabled to run hardware-accelerated Docker containers and test runners without virtualization overhead.
3.  **Global C-States:** If running latency-critical voice AI pipelines or high-frequency loops, disable global C-states in BIOS or add `processor.max_cstate=1` to the Grub boot loader to prevent CPU latency spikes when recovering from idle states.

---

### 2. NVIDIA RTX 3060 12GB GPU Tuning

#### A. CUDA & Docker Container Toolkit Installation
To route containerized AI agents (like Weaviate, LiteLLM, or Dify sandbox steps) to the GPU, register the container runtime wrapper.
```bash
# Add NVIDIA GPG Keys
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
# Add Repo
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
# Install
sudo apt update && sudo apt install -y nvidia-container-toolkit
# Configure Docker config
sudo nvidia-container-toolkit runtime configure --runtime=docker
# Restart Docker
sudo systemctl restart docker
```

#### B. Ollama VRAM Optimization & Math
*   **Enabling Flash Attention:** Flash Attention significantly reduces memory requirements for KV caching, allowing larger model contexts to fit in VRAM.
    *   Set `OLLAMA_FLASH_ATTENTION=1` in your environmental variables.
*   **VRAM Calculations (12GB Limit):**
    *   An RTX 3060 offers `12,288 MB` of VRAM.
    *   A 14B Q4_K_M model requires roughly `9,200 MB` for raw weights.
    *   Remaining space: `3,088 MB`.
    *   A single context slot with 8192 context size requires roughly `1,200 MB` of KV Cache.
    *   Therefore, with a 14B model, `OLLAMA_NUM_PARALLEL` can be set to maximum `2` (`2400 MB` KV Cache).
    *   Setting `OLLAMA_NUM_PARALLEL=4` with a 14B model will exceed 12GB VRAM, forcing weights to spill into system memory (RAM), dropping speed from ~40 tokens/sec to ~1-2 tokens/sec.
    *   If you need `OLLAMA_NUM_PARALLEL=4`, you must drop model size to a 7B or 8B model (e.g. `llama3:8b` or `qwen2.5-coder:7b`).

**Configuring Service Environment on Tank (`/etc/systemd/system/ollama.service.d/override.conf`):**
```ini
[Service]
Environment="OLLAMA_HOST=0.0.0.0"
Environment="OLLAMA_FLASH_ATTENTION=1"
Environment="OLLAMA_NUM_PARALLEL=2"
Environment="OLLAMA_MAX_LOADED_MODELS=1"
Environment="OLLAMA_KEEP_ALIVE=10m"
```

---

### 3. PCIe Gen 4 NVMe SSD & Swappiness Tuning

#### A. Disk I/O Schedulers
Modern NVMe SSDs have internal hardware queue management and do not benefit from CPU-bound I/O scheduling algorithms (like BFQ or CFQ) used on traditional rotational disks.
*   **Optimization:** Set NVMe scheduler to `none` or `kyber`.
*   Verify scheduler status: `cat /sys/block/nvme0n1/queue/scheduler`
*   Set to `none` at boot via sysfs or dynamic rule in `/etc/udev/rules.d/60-scheduler.rules`:
    ```udev
    ACTION=="add|change", KERNEL=="nvme*", ATTR{queue/scheduler}="none"
    ```

#### B. Mount Optimizations (`/etc/fstab`)
To prevent the operating system from constantly writing metadata timestamp updates for every file access (which degrades compilation performance and shortens SSD life):
*   Add `noatime,lazytime,nodiratime` to your `/etc/fstab` volume entries:
    ```text
    UUID=YOUR-NVME-UUID / ext4 defaults,noatime,lazytime,nodiratime 0 1
    ```

#### C. Swap File & Dirty Ratio Control
Prevent Linux from aggressively swapping out container memory blocks to NVMe:
```bash
# Add to /etc/sysctl.d/99-homelab-storage.conf
# Force kernel to wait until memory is at 90% utilization before swapping
vm.swappiness=10
# Drop cache pressure to keep directory indexes in memory
vm.vfs_cache_pressure=50
# Optimize write cache flushing limits (increases burst write tolerance)
vm.dirty_background_ratio=5
vm.dirty_ratio=15
```

---

### 4. Optimizing the Docker Engine on Tank

Configure `/etc/docker/daemon.json` to configure storage drivers, size-capped log output (prevents system disk exhaustion), and register the Nvidia toolkit.

#### A. `/etc/docker/daemon.json`
```json
{
  "storage-driver": "overlay2",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "20m",
    "max-file": "3"
  },
  "default-runtime": "nvidia",
  "runtimes": {
    "nvidia": {
      "path": "nvidia-container-runtime",
      "runtimeArgs": []
    }
  },
  "bip": "172.18.0.1/16",
  "default-address-pools": [
    {"base": "172.19.0.0/16", "size": 24}
  ],
  "features": {
    "buildkit": true
  }
}
```

---

### 5. Tailscale & Linux TCP Stack Tuning

#### A. Network sysctl Optimization (`/etc/sysctl.d/99-homelab-network.conf`)
Optimize networking buffers, increase socket queue bounds, and enable BBR (Bottleneck Bandwidth and RTT) congestion control to maximize data transfer rates over Tailscale connections.
```ini
# Enable BBR congestion control
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr

# Increase maximum network buffer sizes (for high-speed transfers)
net.core.rmem_max=67108864
net.core.wmem_max=67108864
net.ipv4.tcp_rmem=4096 87380 67108864
net.ipv4.tcp_wmem=4096 65536 67108864

# Increase file descriptor constraints
fs.file-max=2097152

# Increase system socket connections queue limit
net.core.somaxconn=1024
```

#### B. Tailscale SSH Configuration
Tailscale SSH allows passwordless, certificate-validated terminal command routing directly over your encrypted Tailnet.
1.  Enable on Tank:
    ```bash
    sudo tailscale up --ssh
    ```
2.  Now, the MacBook agent can run remote tasks on Tank without SSH key files or manual password entry:
    ```bash
    ssh alex@tank "systemctl restart ollama"
    ```

---

## 📄 Part 4: Software Reference Manuals

For deep developer references, configuration guides, command catalogs, and API endpoints, refer to the individual manuals in the vault:
- 📄 **[Ollama Reference Manual](file:///Users/alexburgess/Library/Mobile%20Documents/com~apple~CloudDocs/NOBS/04-Memories/Software-Reference-Manuals/Ollama-Manual.md)**
- 📄 **[LiteLLM Reference Manual](file:///Users/alexburgess/Library/Mobile%20Documents/com~apple~CloudDocs/NOBS/04-Memories/Software-Reference-Manuals/LiteLLM-Manual.md)**
- 📄 **[Dockge Reference Manual](file:///Users/alexburgess/Library/Mobile%20Documents/com~apple~CloudDocs/NOBS/04-Memories/Software-Reference-Manuals/Dockge-Manual.md)**
- 📄 **[Cosmos Cloud Reference Manual](file:///Users/alexburgess/Library/Mobile%20Documents/com~apple~CloudDocs/NOBS/04-Memories/Software-Reference-Manuals/Cosmos-Cloud-Manual.md)**
- 📄 **[Dokploy Reference Manual](file:///Users/alexburgess/Library/Mobile%20Documents/com~apple~CloudDocs/NOBS/04-Memories/Software-Reference-Manuals/Dokploy-Manual.md)**
- 📄 **[Coolify Reference Manual](file:///Users/alexburgess/Library/Mobile%20Documents/com~apple~CloudDocs/NOBS/04-Memories/Software-Reference-Manuals/Coolify-Manual.md)**

