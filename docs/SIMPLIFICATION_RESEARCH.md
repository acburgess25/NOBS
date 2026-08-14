# Simplification Research — Prior Art and Where to Stop Hand-Rolling

**Status:** Research note, August 14, 2026. Ecosystem claims come from third-party
reporting (sources at the end); code claims were checked against this repo the
same day.
**Question asked:** How can NOBS improve, what code already exists out there,
and what can we simplify?

## The one-paragraph answer

NOBS's backend is already unusually lean — 6,406 lines across `app/`, ten
runtime dependencies, no agent framework — and the parts that are hand-rolled
on purpose (the approval queue, context separation, privacy receipts) are the
product's moat and have no drop-in replacement. The real wins are: (1) adopt
**Ollama structured outputs** to delete manual JSON-fence parsing and harden
every model boundary; (2) adopt **MCP** as the integration standard instead of
writing one-off tool glue, keeping the NOBS approval gate in front of it —
1,200+ servers already exist; (3) lean on **Home Assistant's Assist pipeline**
as the voice/room endpoint instead of ever building our own speaker story; and
(4) turn the new landing page's contributor asks into repo infrastructure
(labels, good-first-issues, CONTRIBUTING.md), which is a process gap, not a
code gap.

## What we hand-rolled vs. what exists

| NOBS piece | Ecosystem equivalent | Verdict |
|---|---|---|
| Approval queue (atomic, non-replayable, audited) | MCP elicitation is the closest standard; no library ships this | **Keep custom.** It's the moat. Map it onto MCP's accept/decline/cancel semantics when MCP lands. |
| Personal/Business/Shared contexts | Nothing comparable in Khoj/LibreChat/AnythingLLM | **Keep custom.** |
| Privacy receipts + Local/Tank/cloud badges | Nothing comparable | **Keep custom.** |
| Agent loop (`app/agent.py`, 274 lines) | LangChain/CrewAI-style frameworks; Letta runtime | **Keep custom.** 274 lines is smaller than any framework's adapter layer, and framework lock-in (especially Letta's runtime model) works against local-first portability. |
| Tool registry (`app/agent_tools.py`, 1,139 lines) | MCP tool servers | **Hybrid.** Keep the registry + risk classes as the policy layer; let MCP servers become the supply of tools behind it. |
| JSON parsing from Ollama (`dream_team.py`, `briefing.py`, optimizer ping) | Ollama schema-constrained decoding (`format` = JSON Schema, XGrammar under the hood) | **Replace.** Done in #103. |
| Agent tool-call fence-stripping (`agent.py:261`) | — | **Keep.** That call passes `tools` and must still be able to return prose, so it cannot be constrained to a schema. |
| Memory approval flow (planned) | mem0 (bolt-on memory layer, minimal lock-in), Letta (runtime, heavy lock-in) | **Build the approval UX custom; consider mem0's extraction patterns as inspiration only.** Consent-first memory is a differentiator; no library ships it. |
| Home Assistant bridge (`app/home_assistant.py`) | HA's native Ollama/conversation-agent integrations | **Keep ours for control; add the reverse direction** (Tank as HA Assist conversation agent) for voice endpoints. |
| Custom skill pipeline (planned, PRODUCT_DECISIONS §14) | MCP server ecosystem + registries | **Reframe.** "Generate a custom integration" becomes "wrap or vet an existing MCP server" in most cases — cheaper to build, easier to scan. |

## Concrete simplification 1: Ollama structured outputs

**Status: implemented in #103.**

Ollama's `format` parameter accepts a full JSON Schema and constrains decoding
itself — no code fences, no explanatory prose, no manual cleanup. NOBS was
passing `"format": "json"` (unconstrained JSON mode) and compensating
afterwards. Three call sites changed:

- `app/briefing.py` now sends `BriefingSections.model_json_schema()` — the
  schema it was already validating against. A model that drifts off-shape used
  to mean a failed briefing for the user; that failure mode is gone rather
  than merely reported.
- `app/dream_team.py` sends schemas for its two JSON steps, so `_ollama_json`
  no longer strips fences by hand.
- The optimizer warm-up ping is constrained, so it measures model latency
  rather than the model's willingness to answer in JSON. That site previously
  called bare `json.loads` with no error handling.

**One correction to the original draft of this note:** `Agent._parse_json_tool_call`
cannot be replaced this way. That call passes `tools` and must still be able to
return ordinary prose, so constraining it to a tool-call schema would break
normal chat replies. Its fence-stripping stays.

`pydantic` already ships with FastAPI, so schemas come from models we define —
no new dependency (skip Instructor unless we later want its retry ergonomics).

The security-relevant lesson, now pinned by a test: **a schema constrains shape,
never permission.** `suggested_tools` is typed as an array of strings, so a
model can name a state-changing tool and stay schema-valid. The
`SANDBOX_READ_ONLY_TOOLS` allowlist is what rejects it, and it must keep
running after generation.

## Concrete simplification 2: MCP as the integration standard

MCP became the de facto tool-integration standard in 2025–2026 — supported by
every major lab, 1,200+ public servers, three primitives (tools, resources,
prompts), stdio transport for local processes. Two moves, both preserving the
NOBS safety model:

1. **Consume:** add one MCP client adapter to the Tank tool registry. Every
   MCP server's tools arrive as registry entries that still get a NOBS risk
   class and still go through the approval queue. One adapter replaces N
   future one-off integrations — this is most of what PRODUCT_DECISIONS §14's
   skill pipeline was going to hand-build, and the Skill Policy scanner gets a
   standard surface (declared tools + transports) to scan instead of arbitrary
   generated code.
2. **Expose:** serve Tank's own tools as an MCP server. Any MCP-speaking
   client on the LAN (including coding agents working on NOBS itself) can then
   use Tank capabilities without custom API glue.

The 2026-07-28 MCP spec's **elicitation** flow (accept/decline/cancel with
structured content) is the standard shape of NOBS's approval concept —
mapping our queue onto it means MCP tools that request confirmation get the
NOBS approval UI for free. Cautions: the spec is newly stateless and still
moving (breaking changes in the 07-28 revision), and the approval gate must
stay on our side of the boundary — an MCP server's own confirmation prompts
are never a substitute for the Tank queue.

## Concrete simplification 3: Home Assistant as the room story

HA ships a native Ollama conversation-agent integration, and its Assist
pipeline treats any conversation agent as pluggable alongside wake word, STT,
and TTS. NOBS already bridges *into* HA for device control; the reverse
direction — registering Tank as the conversation agent HA's voice hardware
talks to — gives "the same NOBS in every room" using hardware and pipeline
code we never have to write. That converts a chunk of PRODUCT_DECISIONS §11
(cross-device endpoints) from build-it to configure-it. Google/Alexa
unification stays honestly "coming soon" either way.

## What the competition confirms

The 2026 self-hosted assistant field (Open WebUI, LibreChat, AnythingLLM,
Khoj, Jan, Leon) has converged on chat + RAG + MCP + some memory. None of
them have: a native phone app as the primary surface, approval-gated
automation, context separation, or processing-location receipts. Two
implications: our differentiators are correctly custom-built, and the
undifferentiated parts (model serving, tool transport, structured output)
should be standards, not our code. LibreChat shipping MCP + persistent memory
as defaults shows where table stakes are moving.

## Process simplifications (no code)

- **Contributor on-ramp:** the landing page now asks for five kinds of help,
  but the repo has no `CONTRIBUTING.md`, no issue templates, no
  `good first issue` labels. That gap converts recruited interest into
  bounce. This is the highest-leverage process fix this month.
- **Stale doc line:** `docs/CURRENT_STATE.md` §Website says content was
  "updated for TestFlight public beta," which reads as TestFlight being live;
  §Known gaps says the upload is pending. Reword the former.
- **Two sites, one domain:** nobsdash.com currently serves a Next.js waitlist
  app (via `web.polsia.app`/CloudFront) while this repo deploys the approved
  Vite site to GitHub Pages. Until DNS points at one of them on purpose,
  every "put it on the site" change silently ships to a page nobody sees.
  Owner decision needed; document the outcome in CURRENT_STATE.
- **Xcode Cloud red** is still unread noise on every PR and needs a human in
  App Store Connect (unchanged from the Aug 14 handoff).
- **Unmerged branch:** `cursor/axiom-agents-system-95fc` (~3,000 lines,
  includes the waitlist app now apparently live) increasingly needs a
  merge-or-close decision before it drifts further from `main`.

## What NOT to do

- No agent frameworks (LangChain, CrewAI) — they'd replace 274 readable lines
  with a dependency we'd fight.
- No Letta/MemGPT runtime — architectural lock-in contradicts §17 portability.
- No Open WebUI/LibreChat embedding — the phone app is the product surface;
  shipping a second web chat UI dilutes it.
- No new Python dependencies for structured output — the `format` parameter
  plus existing pydantic covers it.

## Sources

- MCP standardization and ecosystem: sitepoint.com/model-context-protocol-mcp/; mcp.so registry count via devstarsj.github.io MCP guide (July 2026)
- MCP 2026-07-28 spec and elicitation: blog.modelcontextprotocol.io/posts/2026-07-28/; stacktr.ee/blog/mcp-2026-spec-changes; gofastmcp.com/servers/elicitation
- Ollama structured outputs: ollama.com/blog/structured-outputs; docs.ollama.com/capabilities/structured-outputs
- Home Assistant Ollama/Assist: home-assistant.io/integrations/ollama/; home-assistant.io/voice_control/assist_create_open_ai_personality/
- Assistant landscape: vellum.ai/blog/best-open-source-personal-ai-assistants; vellum.ai/blog/best-local-ai-assistants
- Memory layers: vectorize.io/articles/mem0-vs-letta; braintrust.dev/articles/best-ai-agent-memory-tools-2026
