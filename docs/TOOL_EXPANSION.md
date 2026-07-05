# NOBS Tool & Skill Expansion — Open-Source Research

**Researched:** 2026-07-05  
**Scope:** Open-source libraries and integrations suitable for Tank (FastAPI/Ollama backend) and the iPhone app (SwiftUI). All candidates evaluated against the NOBS Skill Policy: privacy-safe, local-first, no forced cloud, Apache/MIT/BSD licensed.

---

## Tank Backend Tools (new agent tools in `app/agent_tools.py`)

### 🌤️ 1. Weather — Open-Meteo
- **Library:** `open-meteo/python-requests` (pip: `openmeteo-requests`)
- **Stars:** 48★ | **License:** MIT | **No API key required**
- **What it adds:** Current conditions, hourly forecasts, daily high/low, precipitation probability for any lat/lon
- **Risk:** `READ_ONLY` — no auth, no data sent back, calls `api.open-meteo.com`
- **NOBS fit:** "What's the weather this week?" in briefings; Tank can pull forecast at briefing time and include it without iPhone sending anything
- **Privacy:** Open-Meteo is GDPR-compliant, no user tracking, no account
- **Install:** `uv add openmeteo-requests`

---

### 🔍 2. Web Search — DuckDuckGo Search (duckduckgo-search)
- **Library:** `deedy5/duckduckgo_search` ~13k★ | **License:** MIT | **No API key**
- **What it adds:** Text search, news search, image search — all locally routed through DDG's privacy proxy
- **Risk:** `READ_ONLY` — reads web results, no personal data shared
- **NOBS fit:** Enables Tank to actually research things — look up a business, find current news, answer factual questions the local model doesn't know
- **Replaces:** The missing "researching" capability the user asked about
- **Install:** `uv add duckduckgo-search`
- **Tool names to add:** `web_search`, `news_search`

---

### 📰 3. News/RSS Feeds — feedparser
- **Library:** `kurtmckee/feedparser` ~1.7k★ | **License:** BSD | **No API key**
- **What it adds:** Parse any RSS/Atom feed — news sites, blogs, podcasts, YouTube channels
- **Risk:** `READ_ONLY` — fetches public XML feeds
- **NOBS fit:** User configures a list of RSS feeds; Tank reads them at briefing time and includes headlines. "Tech news" / "weather alerts" / "local news" in daily briefing.
- **Install:** `uv add feedparser`
- **Tool name:** `read_news_feeds`

---

### 🧠 4. Web Page Reading — trafilatura
- **Library:** `adbar/trafilatura` ~3k★ | **License:** Apache 2.0 | **No API key**
- **What it adds:** Extracts clean article text from any URL — strips ads, nav, boilerplate
- **Risk:** `READ_ONLY` — fetches and reads a URL, no data sent
- **NOBS fit:** "Research this article/URL" — share a link from iPhone to Tank, Tank reads it with Ollama and returns a summary. Pairs perfectly with the ShareExtension idea for iOS.
- **Install:** `uv add trafilatura`
- **Tool name:** `read_url`

---

### 📊 5. System Monitoring — psutil
- **Library:** `giampaolo/psutil` ~10k★ | **License:** BSD | **No API key**
- **What it adds:** CPU %, memory usage, per-process stats, network I/O, disk I/O — cross-platform
- **Risk:** `READ_ONLY` — local system reads only
- **NOBS fit:** Enriches `get_tank_status` enormously. Dashboard and agent can see real load, whether Ollama is hogging RAM, whether a backup is running. Alerts when Tank is struggling.
- **Install:** `uv add psutil`
- **Upgrade:** Replace `os.getloadavg()` + `shutil.disk_usage()` with full psutil stats

---

### 🎮 6. GPU Monitoring — nvidia-ml-py (pynvml)
- **Library:** `gpuopenanalytics/pynvml` | **License:** BSD | **No API key**
- **What it adds:** RTX 3060 GPU utilization %, VRAM used/free, temperature, power draw — from Python
- **Risk:** `READ_ONLY` — reads NVIDIA Management Library, local only
- **NOBS fit:** Tank has an RTX 3060. The dashboard shows a "GPU card" already — right now it's basic. pynvml makes it real: VRAM used by Ollama, GPU temp, utilization while running a model.
- **Install:** `uv add nvidia-ml-py` (Linux only — Tank runs Ubuntu, perfect)

---

### 📚 7. Wikipedia Lookup
- **Library:** `martin-majlis/Wikipedia-API` ~900★ | **License:** MIT | **No API key**
- **What it adds:** Search and fetch Wikipedia article summaries and sections in plain text
- **Risk:** `READ_ONLY` — public API, no auth
- **NOBS fit:** Quick factual lookups the local model doesn't know. "Who is X?" "What is Y?" — Tank looks it up, summarizes with Ollama, returns it privately.
- **Install:** `uv add wikipedia-api`
- **Tool name:** `lookup_wikipedia`

---

### ⏱️ 8. Better Scheduling — APScheduler
- **Library:** `agronholm/apscheduler` ~13k★ | **License:** MIT
- **What it adds:** Proper cron scheduling, misfire handling, persistent job store (SQLite), timezone-aware
- **Risk:** Internal infrastructure, no network
- **NOBS fit:** The current `asyncio.sleep(15)` scheduler loop is fragile — it can miss briefing times if the loop is slow. APScheduler replaces it with a real cron: `"every day at 07:00 America/Chicago"`. Surviving restarts via SQLite job store.
- **Install:** `uv add apscheduler`

---

### 🗃️ 9. Local Memory / RAG — ChromaDB
- **Library:** `chroma-core/chroma` ~22k★ | **License:** Apache 2.0
- **What it adds:** Local vector database — store embeddings of notes, briefings, conversations. Enables semantic search: "what did we talk about last Tuesday?" — Tank finds it.
- **Risk:** `READ_ONLY` for search, `CHANGE` for writes — all local, no cloud
- **NOBS fit:** The product decisions explicitly mention "no approved long-term memory workflow yet" — this IS the answer. Use Ollama's embedding endpoint to embed notes/briefings, store in ChromaDB, query at chat time.
- **Install:** `uv add chromadb`
- **Requires:** Ollama embedding model (e.g., `nomic-embed-text`)

---

## iPhone App Skills (SwiftUI)

### 🎙️ 10. Voice Input — SFSpeechRecognizer
- **Built into iOS** — no library, no API key, on-device
- **What it adds:** Push-to-talk or always-listening wake word to send a message to Tank without typing
- **Risk:** Local on-device — Apple processes speech on-device when available
- **NOBS fit:** "Hey NOBS" or push-button voice → text → sent to Tank → spoken response via AVSpeechSynthesizer. Huge UX upgrade.
- **Implementation:** `SFSpeechRecognizer` + `AVAudioEngine` + `AVSpeechSynthesizer`

---

### 📱 11. Siri & Shortcuts — AppIntents
- **Built into iOS 16+** — no library
- **What it adds:** "Hey Siri, ask NOBS what's on my calendar" — works from lock screen, AirPods, Apple Watch, CarPlay
- **Risk:** None — local request routing
- **NOBS fit:** The product decisions explicitly list "Siri integration" as a target. AppIntents is the modern replacement for SiriKit. Define 3-5 intents: GetBriefing, AskNOBS, AddReminder, GetProposals.
- **Effort:** Medium — define `AppIntent` structs, implement `perform()` to call Tank API

---

### 🏠 12. Home Screen & Lock Screen Widgets — WidgetKit
- **Built into iOS 14+** — no library
- **What it adds:** Glanceable briefing summary widget, next calendar event, pending approvals count
- **Risk:** None — reads cached data
- **NOBS fit:** User sees their briefing on the home screen without opening the app. Updates when Tank pushes new briefing.
- **Widget types:** Small (next event), Medium (briefing preview), Lock Screen (inline)

---

### ⌚ 13. Apple Watch — WatchKit / SwiftUI for watchOS
- **Built into watchOS** — no library
- **What it adds:** Briefing digest on wrist, quick voice reply to Tank, approve/dismiss proposals from Watch
- **Risk:** Communicates through iPhone via WatchConnectivity
- **NOBS fit:** "Complication" on watch face showing next calendar item or pending approval count

---

### 📍 14. Location-Aware Context — CoreLocation
- **Built into iOS** — no library
- **What it adds:** When-in-use location → Tank knows you're at home vs work → adjusts briefing context automatically
- **Risk:** `SENSITIVE` — requires explicit user permission, processed on-device, never sent to cloud
- **NOBS fit:** "You're at home, switching to personal context." Morning commute detected → add travel time to briefing.

---

### 🔗 15. Share Extension — UIKit/SwiftUI
- **Built into iOS** — no library
- **What it adds:** "Share to NOBS" from Safari/News/Mail → sends URL to Tank → Tank reads page with trafilatura + Ollama → returns summary to iPhone
- **Risk:** None — user-initiated, local pipeline
- **NOBS fit:** Pairs with tool #4 (trafilatura). The full flow: Safari → Share → NOBS → Tank reads it → summary in chat.

---

### 🎯 16. Focus Filter Integration — AppIntents FocusFilterIntent
- **Built into iOS 16+** — no library
- **What it adds:** When user activates Work Focus → NOBS automatically switches to `business` context. Personal Focus → `personal` context.
- **Risk:** None — reads Focus state only
- **NOBS fit:** Context switching is currently manual. Focus integration makes it automatic.

---

### 🏷️ 17. NFC Automations — Core NFC
- **Built into iOS 14+** — no library
- **What it adds:** Tap phone on NFC tag to trigger Tank automations: tap desk tag = start work mode, tap nightstand = wind-down routine
- **Risk:** `CHANGE` — triggers Tank actions, requires user to physically tap
- **NOBS fit:** Physical interaction that triggers Tank → Home Assistant → smart home chain without cloud

---

## Priority Ranking for Implementation

| Priority | Tool | Impact | Effort | Risk Level |
|----------|------|--------|--------|-----------|
| 🔴 1 | **DuckDuckGo Search** | Fixes "nothing is researching" immediately | Low | READ_ONLY |
| 🔴 2 | **Open-Meteo weather** | Enriches every briefing | Low | READ_ONLY |
| 🔴 3 | **psutil system monitor** | Fixes shallow Tank stats | Low | READ_ONLY |
| 🔴 4 | **feedparser RSS** | User-curated news in briefings | Low | READ_ONLY |
| 🟡 5 | **Voice input (SFSpeechRecognizer)** | Major UX upgrade on iPhone | Medium | READ_ONLY |
| 🟡 6 | **trafilatura URL reader** | Enables research on any URL | Low | READ_ONLY |
| 🟡 7 | **nvidia-ml-py GPU stats** | Real GPU monitoring on Tank | Low | READ_ONLY |
| 🟡 8 | **APScheduler** | Reliable briefing scheduling | Medium | Internal |
| 🟡 9 | **Wikipedia lookup** | Factual research tool | Low | READ_ONLY |
| 🟢 10 | **AppIntents / Siri** | Siri integration (product goal) | High | READ_ONLY |
| 🟢 11 | **WidgetKit** | Home screen briefing widget | Medium | READ_ONLY |
| 🟢 12 | **ChromaDB memory** | Long-term agent memory | High | Mixed |
| 🟢 13 | **Focus Filter** | Automatic context switching | Medium | READ_ONLY |
| ⚪ 14 | **Apple Watch** | Wrist briefings | High | READ_ONLY |
| ⚪ 15 | **CoreLocation** | Location-aware context | Medium | SENSITIVE |
| ⚪ 16 | **Share Extension** | "Research this" from Safari | Medium | READ_ONLY |
| ⚪ 17 | **NFC automations** | Physical trigger for Tank | Medium | CHANGE |

---

## First Sprint Recommendation

Land the top 4 Tank tools in one PR — they're all `pip install` + one `ToolDefinition` each, all `READ_ONLY`, no approval needed:

1. `web_search` via duckduckgo-search  
2. `get_weather` via open-meteo  
3. Upgraded `get_tank_status` via psutil + pynvml  
4. `read_news_feeds` via feedparser  

Together these make Tank actually useful for research and produce genuinely informative briefings. Estimated 2-3 hours of work.
