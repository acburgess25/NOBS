# LiteLLM Reference Manual

**Scope:** Deployment routing configurations, API model aliasing, database schema variables, fallback execution, and key-management endpoint routing.

---

## 🛠️ 1. `config.yaml` Settings Configuration

The central yaml file controls how LiteLLM interfaces with downstream engines (Ollama, HuggingFace, APIs) and how requests are balanced.

```yaml
model_list:
  # Local primary deployment
  - model_name: qwen2.5-coder:14b
    litellm_params:
      model: ollama/qwen2.5-coder:14b
      api_base: http://localhost:11434
      tpm: 100000          # Tokens Per Minute limit (for throttling)
      rpm: 1000            # Requests Per Minute limit
      max_tokens: 8192     # Hard constraint on context limit
      
  # Local secondary/backup deployment
  - model_name: local-llama
    litellm_params:
      model: ollama/llama3:8b
      api_base: http://localhost:11434
      
  # Remote high-tier fallback deployment
  - model_name: deepseek-coder
    litellm_params:
      model: deepseek/deepseek-coder
      api_key: "os.environ/DEEPSEEK_API_KEY"
      
  # Remote reasoning fallback deployment
  - model_name: claude-sonnet
    litellm_params:
      model: anthropic/claude-3-7-sonnet-20250219
      api_key: "os.environ/ANTHROPIC_API_KEY"

router_settings:
  # Options: latency-based-routing, least-busy, usage-based-routing
  routing_strategy: latency-based-routing
  # Allow model to fail twice before cool down trigger
  allowed_fails: 2
  # Put failing endpoints in a cooldown timeout for 10 seconds
  cooldown_time: 10
  # Retry requests globally if failure occurs
  num_retries: 3
  # Global client request timeout (in seconds)
  timeout: 45

# Fallback Routing chains
fallbacks:
  # Map primary user-facing model to a backup list if failure is triggered
  - qwen2.5-coder:14b: ["local-llama", "deepseek-coder", "claude-sonnet"]

general_settings:
  # Protect the server with a master token
  master_key: "os.environ/LITELLM_MASTER_KEY"
  # Route database metadata using SQL
  database_url: "postgresql://postgres:postgres@localhost:5432/litellm"
```

---

## 💻 2. Command Line Interface (CLI)

Run the LiteLLM proxy server on the host machine or within a container wrapper.

```bash
# Start proxy with custom config.yaml
litellm --config ./config.yaml

# Start proxy on specific host interface and port
litellm --config ./config.yaml --host 0.0.0.0 --port 4000

# Start lightweight routing proxy without config.yaml (exposing Ollama directly)
litellm --model ollama/qwen2.5-coder:14b --api_base http://localhost:11434 --port 4000

# Start proxy in background via docker run
docker run -d \
  -v $(pwd)/config.yaml:/app/config.yaml \
  -e DEEPSEEK_API_KEY="your-key" \
  -e ANTHROPIC_API_KEY="your-key" \
  -p 4000:4000 \
  ghcr.io/berriai/litellm:main-latest \
  --config /app/config.yaml --port 4000
```

---

## 🔌 3. Admin & User REST API Reference

Expose OpenAI-compatible endpoints at `/v1/chat/completions` and admin utilities. Include authentication header `Authorization: Bearer <LITELLM_MASTER_KEY>` for all administrative calls.

### A. Generate Completions (`POST /v1/chat/completions`)
*   **Request:**
    ```bash
    curl http://localhost:4000/v1/chat/completions \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer sk-your-key-here" \
      -d '{
        "model": "qwen2.5-coder:14b",
        "messages": [
          {"role": "user", "content": "Generate a binary search in Swift."}
        ]
      }'
    ```

### B. Generate a temporary API Token (`POST /key/generate`)
Create access tokens for development scripts or IDE extensions.
*   **Request:**
    ```bash
    curl -X POST http://localhost:4000/key/generate \
      -H "Authorization: Bearer sk-master-key" \
      -H "Content-Type: application/json" \
      -d '{
        "key_alias": "alex-macbook-cline",
        "duration": "30d",
        "models": ["qwen2.5-coder:14b", "claude-sonnet"]
      }'
    ```
*   **Response:** Returns a token structure starting with `sk-` along with model permissions.

### C. Revoke/Delete API Token (`POST /key/delete`)
*   **Request:**
    ```bash
    curl -X POST http://localhost:4000/key/delete \
      -H "Authorization: Bearer sk-master-key" \
      -H "Content-Type: application/json" \
      -d '{"key": "sk-token-to-revoke"}'
    ```

### D. Dynamically Register a New Model (`POST /model/new`)
Add models to the router without editing `config.yaml` or restarting the proxy.
*   **Request:**
    ```bash
    curl -X POST http://localhost:4000/model/new \
      -H "Authorization: Bearer sk-master-key" \
      -H "Content-Type: application/json" \
      -d '{
        "model_name": "qwen-temp",
        "litellm_params": {
          "model": "ollama/qwen2.5-coder:7b",
          "api_base": "http://localhost:11434"
        }
      }'
    ```

---

## ⚠️ 4. Error Mapping & Troubleshooting

LiteLLM translates raw error types from downstream providers into standard HTTP status codes:

*   **`400 Bad Request`**: Downstream parser configuration failed (invalid context size parameters or mismatched prompt templates).
*   **`429 Rate Limit Exceeded`**: Target provider throttled request. LiteLLM will automatically trigger any fallback sequences defined under `fallbacks:`.
*   **`500 Internal Server Error`**: Connection to Ollama failed (e.g. Ollama daemon stopped, port blocked). Ensure local service is running and pingable: `curl http://localhost:11434`.
*   **`401 Unauthorized`**: Key verification failure. Check authorization headers or ensure the token is correctly stored in LiteLLM's Postgres/SQLite meta-store database.
