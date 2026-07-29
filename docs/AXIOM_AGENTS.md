# Axiom Agents for NOBS

NOBS uses [Axiom](https://charleswiltgen.github.io/Axiom/) for Apple-platform agent skills and autonomous auditors (Swift 6, SwiftUI, accessibility, concurrency, memory, IAP, health checks, and related domains).

Product decisions still come from [`PRODUCT_DECISIONS.md`](PRODUCT_DECISIONS.md). Axiom does not supersede NOBS privacy, approval, or cross-platform rules in [`AI_WORKFLOW.md`](AI_WORKFLOW.md).

## What is installed in this repo

| Path | Role |
|------|------|
| `.agents/skills/axiom-*` | 27 Axiom router skills (shared by Cursor, Codex, Antigravity, and other harnesses). Nested `skills/*-auditor.md` files are the auditor procedures for non–Claude Code agents. |
| `.claude/skills/axiom-*` | Symlinks into `.agents/skills` for Claude Code skill discovery. |
| `.claude/settings.json` | Project-scoped Claude Code marketplace + `axiom@axiom-marketplace` plugin enablement (full agents + `/axiom:*` commands after trust/install). |
| `.cursor/mcp.json` | Cursor MCP server `axiom` via `npx -y axiom-mcp`. |
| `.codex/config.toml` | Codex MCP server `axiom` via `npx -y axiom-mcp`. |
| `skills-lock.json` | Pin/hash lockfile for `npx skills experimental_install`. |

## Mac quickstart (full toolchain)

On a Mac with Node 18+, Xcode 27 (or current beta), and this branch checked out:

```bash
git fetch origin cursor/axiom-agents-system-95fc
git switch cursor/axiom-agents-system-95fc   # or merge/rebase into your working branch

# Optional: Axiom CLI helpers (simulator console, crash symbolication, UI drive, profiling)
git clone --depth 1 https://github.com/CharlesWiltgen/Axiom.git ~/Axiom
mkdir -p "$HOME/.local/bin"
ln -sf ~/Axiom/.claude-plugin/plugins/axiom/bin/* "$HOME/.local/bin/"
# ensure ~/.local/bin is on PATH

# Smoke-test MCP
npx -y axiom-mcp   # leave running briefly; Ctrl+C when it waits on stdin
```

Then pick a harness:

| Harness | Activate | First command / ask |
|---------|----------|---------------------|
| **Cursor** | Open the repo; confirm MCP shows `axiom` from `.cursor/mcp.json` | “Run a health check on my project” |
| **Claude Code** | Trust the folder; install plugin if prompted | `/axiom:health-check` |
| **Codex** | Restart so `.codex/config.toml` loads | “Audit NOBS for accessibility and Swift 6 concurrency” |
| **Xcode Claude/Codex** | See [Xcode MCP setup](https://charleswiltgen.github.io/Axiom/start/xcode-setup) — use absolute `npx` path | `/context` should list Axiom |

Claude Code plugin (once per machine/trust):

```bash
claude plugin marketplace add CharlesWiltgen/Axiom
claude plugin install axiom@axiom-marketplace --scope project
```

Good first Mac asks after MCP/plugin is live:

- “Run a health check on my project”
- “Check accessibility on the iPhone app”
- “Review for Swift 6 concurrency violations”
- “Take a screenshot to verify this fix” (needs booted simulator)

## How agents use Axiom

### Cursor

1. Ensure Node.js 18+ is available.
2. Reload MCP / open the project so `.cursor/mcp.json` is picked up.
3. Prefer MCP tools: `axiom_get_catalog` → `axiom_search_skills` → `axiom_read_skill` → `axiom_get_agent`.
4. For auditor work off Claude Code, follow the inlined auditor markdown under `.agents/skills/*/skills/*-auditor.md` (same procedures as the autonomous agents).

Natural-language examples that should pull Axiom guidance:

- "Check my code for accessibility issues"
- "Review for Swift 6 concurrency violations"
- "My SwiftUI scrolling is janky"
- "Run a health check on my project"
- "Review my in-app purchase implementation"

### Claude Code

On first trust of the repo, install the project marketplace plugin if prompted (commands in Mac quickstart above).

Then use `/axiom:health-check`, `/axiom:audit accessibility`, and related commands. Autonomous agents (for example `health-check`, `accessibility-auditor`, `concurrency-auditor`) are available through the plugin.

### Codex

MCP is configured in `.codex/config.toml`. Skills live under `.agents/skills/`. Update with:

```bash
npx skills update -p -y
```

## Refreshing skills

```bash
npx skills update -p -y
# or restore from the lockfile after a clean checkout:
npx skills experimental_install
```

Do not hand-edit Axiom skill bodies. Rename or wrap NOBS-specific guidance in `docs/` or thin adapters (`AGENTS.md`, `CLAUDE.md`), not inside vendored Axiom files.

## Scope boundaries

- Axiom is for **Apple OS / Swift / Xcode** work (`NOBS/`, `NOBSWidgets/`, `NOBSTankMac/`, `NOBSTests/`).
- Tank Python (`app/`), website (`website/`), and deploy scripts are outside Axiom's primary expertise; keep using NOBS docs and tests for those.
- macOS-only MCP tools (`xclog`, `xcsym`, `xcui`, `xcprof`) require a Mac with Xcode. Linux/Cloud agents can still use skill/agent instruction tools.
- Never let Axiom guidance override NOBS rules: local-first privacy, approval-gated automation, no passwords/financial accounts, and honest "coming soon" for unfinished capabilities.

## Useful agent names

See the [Axiom agents catalog](https://charleswiltgen.github.io/Axiom/agents/). Common ones for NOBS:

- `health-check` — project-wide parallel audit
- `accessibility-auditor`
- `concurrency-auditor`
- `swiftui-performance-analyzer`
- `swiftui-nav-auditor`
- `memory-auditor`
- `iap-auditor` / `iap-implementation`
- `security-privacy-scanner`
- `build-fixer` / `build-optimizer`
- `simulator-tester` (macOS + simulator)
