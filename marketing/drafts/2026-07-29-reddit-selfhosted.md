# r/selfhosted post — private AI server on owned hardware

**Status:** Draft. Do not post the paid service in the body; r/selfhosted allows self-promotion only in context.
**Generated:** July 29, 2026

## Title

Turned my old gaming PC into a private AI assistant for my iPhone — RTX 3060, 20B model, works with the router unplugged

## Body

I've been building a local-first personal assistant and finally got the whole loop running on hardware I already owned. Writing it up because the "you need a datacenter for this" assumption is doing a lot of work in these conversations, and it isn't true at household scale.

**Hardware:** Ryzen 5 5600X3D, RTX 3060 12GB, 24GB RAM — a gaming PC that was mostly collecting dust.

**Stack:**
- Windows host running Ollama (`gpt-oss:20b`) on the GPU
- WSL2 Ubuntu running a FastAPI service under systemd
- Tailscale for access from outside the house — no ports forwarded, no dynamic DNS
- Home Assistant + Matter server in Docker, 45 entities
- A SwiftUI iPhone client that talks to it over a token-authenticated boundary

**What actually works:**
- Chat and daily planning answered locally, with a visible badge showing whether a response came from the phone or the server
- The assistant can see and control the smart home through Home Assistant, but every state change requires explicit approval — the model proposes, it never executes on its own
- A rotating research agent runs on a systemd timer at idle priority and files proposals to a local SQLite DB
- Airplane mode on the phone, LAN only: still works. Nothing leaves the network.

**What doesn't:**
- A 20B local model is not GPT-5. For planning, summarizing, and home control it's genuinely fine. For hard reasoning it isn't close, and pretending otherwise would be silly.
- The iOS app isn't on TestFlight yet, so you can't install that half today. The server side is open source and self-hostable now.
- Cold-loading the model takes a while; keeping it resident costs RAM.

Repo: https://github.com/acburgess25/NOBS

The thing that surprised me most was how much of "AI needs the cloud" turns out to be about *their* scale — millions of concurrent users — not mine. One household is a much smaller problem.

Curious what others are running locally and where you've found the ceiling.

## Comment rules

- Post a first comment with the systemd unit, Tailscale setup, and approval flow.
- Do NOT mention the paid setup service unprompted. If asked "would you set this up for me?", answer once, plainly, with the site link.
- Answer technical questions for the first few hours; that decides whether the post survives.
