# LM Studio Setup (macOS and Windows/WSL2)

LM Studio is now a supported local model server for Tank, alongside Ollama. Nothing about
NOBS changes when you switch: the iPhone app, briefing, agent, dream team, dashboard, and
the background optimizer all keep talking to Tank, and Tank translates to whichever server
you point it at. Both are local; no request in this path reaches a cloud endpoint.

Pick one:

- **Ollama** — the existing default. Headless, `brew services`/systemd friendly, model names
  like `qwen3:8b`. Nothing to do; it is what runs today.
- **LM Studio** — a desktop app with a model browser, a chat UI, per-model context/GPU
  controls, and an OpenAI-compatible server. Easier to tune and inspect; it wants a
  logged-in desktop session to stay running.

You can keep both installed. Tank talks to exactly one at a time.

---

## 1. Install LM Studio

**macOS (Apple Silicon)**

```bash
brew install --cask lm-studio
```

Or download the Apple Silicon build from <https://lmstudio.ai/download>.

**Windows (the Tank box)**

Download the Windows installer from <https://lmstudio.ai/download> and run it. Install it on
**Windows**, not inside WSL2 — LM Studio needs the GPU driver, and the Windows build gets
CUDA/Vulkan acceleration that a WSL2 install does not. Tank reaches it over HTTP either way.

Open the app once and let it finish first-run setup.

## 2. Download the models

Use the **Discover** tab (magnifying glass), or the CLI that ships with the app:

```bash
lms get qwen/qwen3-8b                # everyday chat, briefing, agent
lms get qwen/qwen2.5-coder-14b       # developer mode (NOBS_CODING_MODEL)
```

Size the quantization to the memory you actually have — LM Studio marks each download as
"Full GPU offload possible" or not, and a model that spills to CPU turns a two-second
briefing into a thirty-second one. On a 24 GB Mac or a 12 GB GPU, a Q4_K_M 8B model is the
comfortable everyday pick.

Note the **model identifier** shown next to each downloaded model (for example
`qwen/qwen3-8b`). Tank needs the exact string; LM Studio names models differently from
Ollama (`qwen/qwen3-8b` versus `qwen3:8b`).

## 3. Start the server

In LM Studio, open the **Developer** tab (`⌘/Ctrl` + `2`) and turn the server **on**. Then:

- **Enable "Just-in-Time model loading"** so Tank's first request loads the model instead of
  failing. Without it you must load the model by hand in the UI after every restart.
- Leave **"Serve on Local Network" OFF** if Tank and LM Studio run on the same machine.
  Turn it on only for the split setup in step 6, and read the warning there first.
- Set **Context Length** on each model to at least 8192. The agent loop replays tool results
  into the conversation, and a 4096-token window truncates them mid-run.

Or start it headless:

```bash
lms server start                     # defaults to port 1234
lms server status
```

Verify it answers — this works the same on macOS, Linux, and Windows PowerShell:

```bash
curl http://127.0.0.1:1234/v1/models
```

You should see a JSON object with a `data` array containing your model ids.

## 4. Point Tank at LM Studio

Add to `.env` next to the Tank backend (see `.env.example`):

```bash
NOBS_INFERENCE_PROVIDER=lmstudio
NOBS_LMSTUDIO_BASE_URL=http://127.0.0.1:1234
NOBS_LMSTUDIO_MODEL=qwen/qwen3-8b
NOBS_LMSTUDIO_CODING_MODEL=qwen/qwen2.5-coder-14b
```

`NOBS_LMSTUDIO_MODEL` and `NOBS_LMSTUDIO_CODING_MODEL` map the names in `NOBS_OLLAMA_MODEL`
and `NOBS_CODING_MODEL` onto LM Studio's identifiers. Leave them blank only if your LM Studio
ids happen to match the Ollama ones. Every other setting — timeout, agent step limit,
overnight window, optimizer intensity — keeps working unchanged.

Restart Tank:

```bash
python scripts/dev.py run          # macOS: python3
```

## 5. Verify the connection

```bash
curl -s http://127.0.0.1:8000/dashboard/status | python -m json.tool
```

Look for:

```json
"ollama": { "status": "online", "model": "qwen/qwen3-8b", "provider": "LM Studio" }
```

`status` values mean:

| Value | Meaning |
|---|---|
| `online` | Server answered and is serving the configured model. |
| `model_missing` | Server answered, but no id matched `NOBS_LMSTUDIO_MODEL`. Check the exact string in the Developer tab. |
| `offline` | Nothing answered on `NOBS_LMSTUDIO_BASE_URL`. |

Then exercise the real path (replace the token with your `NOBS_DEVICE_TOKEN`):

```bash
curl -s http://127.0.0.1:8000/chat \
  -H "Authorization: Bearer $NOBS_DEVICE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","content":"Reply with exactly one word: ready"}]}'
```

The Tank dashboard (`/dashboard/`) shows the same state on the connected screen, with the
service row labelled **LM Studio** instead of **Ollama**.

## 6. Serving Tank from a different machine

If LM Studio runs on the Mac and Tank runs on the Windows box (or the reverse):

1. In LM Studio, turn on **Serve on Local Network**.
2. Point Tank at the host: `NOBS_LMSTUDIO_BASE_URL=http://192.168.1.50:1234`.

**LM Studio's server has no authentication.** With local-network serving on, anyone on your
LAN can send prompts and read replies — including guests on the same Wi-Fi. Only do this on
a network you control, never forward port 1234 through your router, and keep it off when you
do not need it. Loopback-only is the default for a reason.

## 7. What connects automatically, and what does not

Everything downstream of Tank comes along, because Tank is the only thing that talks to a
model server:

| Surface | Status |
|---|---|
| iPhone app (chat, briefing) | Works — talks to Tank, nothing to change |
| Tank agent and approvals | Works — tool calls translate both directions |
| Dream Team sandbox | Works |
| Connected-screen dashboard / kiosk | Works — shows the provider name |
| Background optimizer (model ping, warm-up) | Works |
| Scheduled briefings and the overnight queue | Works |

Two things are **not** wired up yet, and NOBS should not claim otherwise:

- **The Mac menu-bar app (`NOBSTankMac`)** still health-checks Ollama directly on port 11434,
  so its status row reads "Ollama: Stopped" when you run LM Studio. Tank itself is fine; only
  that indicator is wrong. Making it provider-aware is coming soon.
- **`scripts/setup-local-ai.sh`** installs and pulls Ollama models only. Use the LM Studio
  steps above instead; do not run the script expecting it to configure LM Studio.

## 8. Connecting other tools to the same LM Studio

The server is OpenAI-compatible, so anything that accepts a custom base URL can share it —
no second copy of the model in memory, no extra configuration in NOBS:

- **Base URL:** `http://127.0.0.1:1234/v1`
- **API key:** any non-empty string (`lm-studio` is conventional); it is not checked.
- **Model:** the identifier from step 2.

That covers editors (Continue, Zed, Cline), Open WebUI, Obsidian plugins, and most CLI
clients. Keep the same privacy rule in mind that the rest of NOBS follows: a tool pointed at
this server sends whatever you paste into it to your own machine, but a tool that *also*
talks to a cloud provider is still a cloud tool. Check what else it is configured with.

## 9. Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `offline` in the dashboard | Server not running (`lms server status`), or the port/host in `NOBS_LMSTUDIO_BASE_URL` is wrong. |
| `model_missing` | The id in `NOBS_LMSTUDIO_MODEL` does not match LM Studio's. Copy it exactly from the Developer tab. |
| Chat returns 503 | Tank could not reach the server at all — same causes as `offline`. |
| Chat returns 502 | The server answered with an error or an unusable body. Check LM Studio's server log; usually no model is loaded and JIT loading is off. |
| First request times out, later ones are fast | JIT loading is loading the model from disk. Raise `NOBS_OLLAMA_TIMEOUT_SECONDS`, or load the model in the UI before you start. |
| Briefing fails with an invalid-briefing error | The model is too small or too quantized to hold the JSON schema. Try a larger quant or a stronger model. |
| Agent never calls tools | The model has no tool-use training. Use a tool-capable model (Qwen 3, Llama 3.1+, Mistral Nemo). |

## 10. Switching back to Ollama

Set `NOBS_INFERENCE_PROVIDER=ollama` (or delete the line) and restart Tank. The LM Studio
settings are ignored while it is unset, so you can leave them in `.env`.
