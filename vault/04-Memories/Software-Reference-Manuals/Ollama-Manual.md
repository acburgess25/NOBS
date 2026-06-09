# Ollama Reference Manual

**Scope:** Host-native LLM engine configuration, model orchestration, custom weights compiling, REST API integrations, and systemd service optimization on Linux hosts.

---

## 💻 1. CLI Command Reference

Manage the Ollama daemon and running models from the host command line.

```bash
# Start a model interactively (downloads if not present)
ollama run <model-name>

# Pull a model from the registry without launching it
ollama pull <model-name>

# List all models currently loaded into VRAM/RAM
ollama ps

# List all models stored on local disk
ollama list

# Create a custom model from a Modelfile
ollama create <new-model-name> -f ./Modelfile

# Remove a model from local disk storage
ollama rm <model-name>

# Copy an existing model to a new name
ollama cp <source-model> <target-model>

# Push a custom model to a registry (requires registry authentication)
ollama push <namespace/model-name>

# View metadata, parameters, and system templates of a model
ollama show <model-name> --system
ollama show <model-name> --parameters
ollama show <model-name> --license
```

---

## 🛠️ 2. Modelfile Syntax & Parameters

Modelfiles define the base weights, system prompts, inference parameters, and context templates for custom LLM configurations.

### Modelfile Directives
*   `FROM` (Required): Reference a base model weight or local GGUF path.
    - Example: `FROM qwen2.5-coder:14b` or `FROM ./custom-weights.gguf`
*   `SYSTEM`: Injects a persistent system prompt defining the agent's persona.
*   `TEMPLATE`: Defines the chat sequence wrapper (e.g., system/user/assistant token framing).
*   `PARAMETER`: Sets runtime options (see table below).
*   `LICENSE`: Standard software license.
*   `MESSAGE`: Adds historical context messages to pre-condition the model.

### Available Parameters (`PARAMETER`)

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `num_ctx` | int | `2048` | Size of the context window (token limit). For coding agent workflows, set to `8192` or `16384`. |
| `temperature` | float | `0.8` | Creativity scale. Higher = random; for programming tasks, set to `0.0` or `0.1` for deterministic code. |
| `num_thread` | int | Auto | Number of CPU threads to allocate. Set to match physical CPU cores (e.g., `6` for Ryzen 5600X3D). |
| `num_predict` | int | `-1` | Maximum number of tokens to generate per response (`-1` = infinite predict loop). |
| `top_k` | int | `40` | Reduces probability of generating nonsense. Lower values = more focused generation. |
| `top_p` | float | `0.9` | Works with top_k. Lower value = more focused/deterministic. |
| `repeat_penalty` | float | `1.1` | Penalty for word repetition. Adjust if model loops output. |
| `stop` | string | - | Sets a stop token sequence (e.g., `stop <\|im_end\|>`). |

### Custom Modelfile Template for Coding Agent:
```dockerfile
FROM qwen2.5-coder:14b
# Set low temperature for deterministic code execution
PARAMETER temperature 0.0
# Enlarge context window for multi-file codebase analysis
PARAMETER num_ctx 8192
# Limit CPU threads to physical cores to avoid SMT cache pollution
PARAMETER num_thread 6
# Set stop tokens
PARAMETER stop <|im_end|>
PARAMETER stop <|im_start|>

SYSTEM """
You are Tank-Coder, an elite autonomous software engineering agent.
- Output clean, modular, and optimized code.
- Avoid descriptive introductory filler text.
- Do not repeat known bad code paths.
"""
```

---

## 🔌 3. REST API Endpoint Reference

Ollama runs an HTTP server (default port `11434`). All requests accept and return JSON.

### A. Generate a Response (`POST /api/generate`)
Sends a single text prompt and streams/returns the model response.
*   **Request:**
    ```bash
    curl http://localhost:11434/api/generate -d '{
      "model": "qwen2.5-coder:14b",
      "prompt": "Write a python script to count to 10.",
      "stream": false,
      "options": {
        "temperature": 0.0,
        "num_ctx": 4096
      }
    }'
    ```
*   **Response (JSON):**
    ```json
    {
      "model": "qwen2.5-coder:14b",
      "created_at": "2026-06-02T01:10:00.123Z",
      "response": "```python\nfor i in range(1, 11):\n    print(i)\n```",
      "done": true,
      "context": [123, 456, 789],
      "total_duration": 450000000
    }
    ```

### B. Chat Conversations (`POST /api/chat`)
Maintains conversation formatting using message roles.
*   **Request:**
    ```bash
    curl http://localhost:11434/api/chat -d '{
      "model": "qwen2.5-coder:14b",
      "messages": [
        { "role": "system", "content": "You are a helpful compiler helper." },
        { "role": "user", "content": "Explain Swift compiler error code 0003." }
      ],
      "stream": false
    }'
    ```

### C. Check Model Status (`POST /api/show`)
*   **Request:**
    ```bash
    curl http://localhost:11434/api/show -d '{"name": "qwen2.5-coder:14b"}'
    ```

---

## ⚙️ 4. Systemd Override Settings (Linux Service)

Ollama is managed as a systemd service on Ubuntu. To tune environment variables, create systemd configuration overrides rather than editing the base service configuration directly.

1.  **Open Override Editor:**
    ```bash
    sudo systemctl edit ollama.service
    ```
2.  **Add Configuration Directives:**
    Paste the following block exactly, saving parameters within the comment boundaries:
    ```ini
    [Service]
    # Bind to all interfaces (allows Tailscale clients to call port 11434)
    Environment="OLLAMA_HOST=0.0.0.0"
    # Route model download directories to optimized storage array
    Environment="OLLAMA_MODELS=/var/lib/ollama/models"
    # Enable Flash Attention to optimize VRAM utilization
    Environment="OLLAMA_FLASH_ATTENTION=1"
    # Allow 2 concurrent contexts to share model weights (prevent OOM)
    Environment="OLLAMA_NUM_PARALLEL=2"
    # Do not allow multiple models in VRAM simultaneously
    Environment="OLLAMA_MAX_LOADED_MODELS=1"
    # Keep models loaded in GPU for 15 minutes before idling out
    Environment="OLLAMA_KEEP_ALIVE=15m"
    ```
3.  **Reload configuration and restart the service:**
    ```bash
    sudo systemctl daemon-reload
    sudo systemctl restart ollama
    ```
4.  **Confirm variables are applied:**
    ```bash
    sudo systemctl show ollama --property=Environment
    ```
