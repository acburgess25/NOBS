# r/LocalLLaMA post — 20B as a daily driver on a 12GB card

**Status:** Draft. Every number below was measured on the actual machine — do not add figures that have not been verified. This audience checks.
**Measured July 29, 2026:** `ollama show` → 20.9B params, MXFP4, 131072 max context. `ollama ps` → 14 GB model, 4096 context, 24%/76% CPU/GPU split. `nvidia-smi` → 10768 MiB / 12288 MiB VRAM in use.

## Title

gpt-oss:20b as a daily-driver assistant on a 12GB 3060 — it doesn't fully fit, and that's mostly fine

## Body

Running `gpt-oss:20b` (MXFP4, 20.9B params) as the actual backend for a personal assistant rather than as a benchmark toy. Some notes on what a 12GB card really does with a model this size.

**Hardware:** Ryzen 5 5600X3D, RTX 3060 12GB, 24GB system RAM. A gaming PC that was otherwise idle.

**The memory reality.** The model is 14GB on disk. At 4096 context, `ollama ps` reports a **24% CPU / 76% GPU** split — it does not fit entirely in VRAM, and `nvidia-smi` shows 10768 MiB of 12288 MiB in use. So this is a partial offload, not a clean GPU-resident setup. It still answers fast enough to be genuinely usable for chat and planning, which honestly surprised me. The card advertises 131072 max context; I run 4096 because pushing context is what actually hurts on this hardware, more than parameter count does.

**What it drives:**
- WSL2 Ubuntu running a FastAPI service under systemd
- A SwiftUI iPhone client over a token-authenticated boundary, reachable outside the house via Tailscale with no port forwarding
- Home Assistant in Docker, 45 entities — the model *proposes* actions and a human approves before anything executes. It has no ability to change device state on its own.
- A research agent on a systemd timer at idle priority, writing findings to SQLite

Fully functional on the LAN with the internet disconnected.

**Where it holds up:** summarizing, daily planning, drafting, and picking the right tool call from a bounded set. For an assistant that mostly needs to route, summarize, and propose, 20B is comfortably past the threshold.

**Where it doesn't:** multi-step reasoning that needs to stay consistent over a long chain. It is not frontier-level and I would not pretend otherwise. It also occasionally emits a malformed tool argument, which is why the approval gate is a hard requirement and not a UX nicety.

Open source: https://github.com/acburgess25/NOBS

What are you all running on 12GB? I'm curious whether people are pushing bigger models with heavier quantization and eating the offload penalty, or staying smaller to keep everything resident — and where you've found the honest ceiling for daily use rather than benchmarks.

## Notes before posting

- Cold-load time was NOT measured; do not quote one.
- Do not mention the paid setup service. If asked directly, answer once with the site link.
- The 24%/76% split is the most interesting honest detail here — lead with it, don't hide it.
