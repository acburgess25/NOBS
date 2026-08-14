# Mac M4 Pro — Local Inference Setup (keep costs at ~$0)

> Purpose: Run NOBS's "plan in 2 minutes" planner and agentic reasoning **fully on the MacBook** so the
> service costs ~$0 marginal per user (no per-token cloud spend) and keeps data on-device.
> Target hardware: **Apple M4 Pro** (this powers the personal Tank / local planner).
> Note: NOBS is a macOS/iOS **27** app; local model serving below works on any recent macOS on Apple Silicon.

## 1. Install Ollama on the Mac
```bash
brew install ollama
```
Or official installer: https://ollama.com/download (Apple Silicon build).

Start it and keep it alive across reboots (auto-background):
```bash
brew services start ollama        # auto-starts at login, stays in background
```

## 2. Pull the right model (pick by RAM)
M4 Pro unified memory decides the sweet spot:

| RAM | Recommended model | Why |
|---|---|---|
| 24 GB | `qwen3:30b-a3b` | MoE, ~3B active params → very fast, strong planning/tool-use. **Default pick.** |
| 48 GB | `qwen3:30b-a3b` **and** `qwen3:32b` | 30b for interactive; 32b for deeper reasoning / background tasks |
| any (lighter/faster chat) | `qwen3:8b` | quick asyncs, always-available cheap path |

```bash
ollama pull qwen3:30b-a3b     # ~18-20 GB, best quality/speed balance
ollama pull qwen3:8b           # ~5 GB, light/cheap path
```

## 3. Verify it actually runs (real proof)
```bash
ollama run qwen3:30b-a3b "Reply with exactly one word: ready"
```
Expect `ready` and, with `--verbose`, ~30–60+ tok/s on M4 Pro. If slow, use qwen3:8b.

## 4. Route the app through tiers (ModelRouter)
Order matters — cheapest/most-local first, cloud only as fallback:
1. **iPhone Apple Foundation / on-device** → micro/quick, zero network
2. **Mac M4 (this model)** → the real planner: `qwen3:30b-a3b`
3. **Always-on desktop (RTX 3060)** → `qwen3:8b` for background/overnight/cheap work
4. **Cloud** → strictly fallback when 1–3 can't answer (rare)

This maps to `ModelRouter.swift` + `RoutingPreferences`. Set the Mac route as preferred for
interactive planning; desktop route for background; iPhone route for on-device micro tasks.

## 5. (Optional) MLX — faster than llama.cpp/Ollama on Apple Silicon
Ollama is easiest and already integrated into NOBS. If you want the absolute best Apple-GPU speed,
serve the same models via **MLX** instead:
```bash
brew install python@3.11
pip install --user mlx-lm
mlx_lm.generate --model Qwen/Qwen3-30B-A3B-Instruct --prompt "Reply with exactly one word: ready"
```
MLX is best for the heavy 32b path; keep Ollama (already in NOBS's Tank wiring) for the everyday one.

## 6. Security & cost guardrails
- `OLLAMA_HOST=127.0.0.1` (default) → **bound to loopback only; never exposed to LAN/cloud**.
- No auth needed on loopback; never open port 11434 externally.
- Power: ~15–35 W only during inference; idle ~0 → **$0.00 marginal cost per user**.
- This is what makes a ~$4.24/mo NOBScloud subscription viable vs. cloud-cloud chains.

## 7. Quick health check
```bash
ollama list                     # models present
curl -s http://127.0.0.1:11434/api/tags | head
```

## Done = the 3-tier local stack is live
iPhone (micro) -> **Mac 30b (planner)** -> Desktop 8b (always-on) -> Cloud (fallback).
Cloud spend collapses toward ~$0; the business math holds.
