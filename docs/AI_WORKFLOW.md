# NOBS Agent Workflow

This is the canonical collaboration guide for every coding agent and every operating system. Tool-specific files must point here instead of copying these rules.

## Start Here

Before changing code:

1. Read [`docs/PRODUCT_DECISIONS.md`](PRODUCT_DECISIONS.md). It is the approved product source of truth.
2. Read [`docs/CURRENT_STATE.md`](CURRENT_STATE.md) for the implemented-versus-planned boundary.
3. For iPhone work, read [`docs/IOS_SESSION_HANDOFF.md`](IOS_SESSION_HANDOFF.md).
4. For smart-home / Google Home work, read [`docs/GOOGLE_HOME_INTEGRATION.md`](GOOGLE_HOME_INTEGRATION.md).
5. Read the relevant implementation document under `docs/`.
4. Run `git status --short --branch` and `git pull --ff-only`.
5. Inspect nearby code and tests before proposing a new pattern.
6. State the intended files, validation, and branch before making broad changes.

If a request conflicts with `PRODUCT_DECISIONS.md`, stop and ask whether the product decision should be superseded. Do not silently reinterpret it.

## Repository Shape

- `NOBS/`: iPhone SwiftUI application.
- `NOBS.xcodeproj/`: Xcode project metadata.
- `app/`: FastAPI backend and Tank-facing services.
- `tests/`: backend tests.
- `design/`: approved visual references.
- `docs/`: product decisions, architecture, roadmap, and build specifications.

### Work routing

- Tank agent, tools, approvals, or autonomy: read [`docs/TANK_AGENT_CORE.md`](TANK_AGENT_CORE.md), then inspect `app/agent.py`, `app/agent_tools.py`, `app/agent_store.py`, and `tests/test_agent.py`.
- Tank API, local model serving, authentication, or deployment: read [`docs/NOBS_TANK_BUILD.md`](NOBS_TANK_BUILD.md), then inspect `app/main.py`, `app/config.py`, and `deploy/tank/`. Every model request goes through `app/inference.py`; provider differences (Ollama, LM Studio) belong there, not at call sites. See [`docs/LM_STUDIO_SETUP.md`](LM_STUDIO_SETUP.md).
- Connected-screen dashboard or kiosk: read [`docs/TANK_DASHBOARD.md`](TANK_DASHBOARD.md), then inspect `dashboard/`, `app/dashboard.py`, and `scripts/start-dashboard-kiosk.sh`.
- iPhone experience: inspect `NOBS/AppModel.swift`, `NOBS/ConversationView.swift`, and the API contracts they call.
- Apple OS audits, SwiftUI/concurrency/accessibility/IAP/build diagnosis: follow [`docs/AXIOM_AGENTS.md`](AXIOM_AGENTS.md) (Axiom skills under `.agents/skills/`, MCP via `.cursor/mcp.json` / `.codex/config.toml`, Claude Code plugin via `.claude/settings.json`).
- Website: follow `website/AGENTS.md` and the approved reference under `design/`.
- Product direction: update `docs/PRODUCT_DECISIONS.md` only when the decision owner explicitly supersedes an approved decision.

The iPhone app is built on macOS with Xcode. Backend and Tank work must remain runnable from Windows/WSL2 and macOS where practical.

## Cross-Platform Is a Hard Requirement

Every feature must be designed for the complete NOBS system, not only the machine where it was written.

- Shared protocols, schemas, storage formats, APIs, and backend logic must work across macOS, Windows/WSL2, and Linux.
- The iPhone UI is intentionally Apple-native, but it must communicate through documented platform-neutral contracts.
- Tank services must run on Windows/WSL2 and must not assume macOS paths or Apple-only libraries.
- Developer setup, tests, linting, migrations, and operational commands need Windows and macOS paths.
- Use `pathlib`, environment configuration, URL-based service discovery, and portable process APIs instead of hard-coded separators, drive letters, shell syntax, or hostnames.
- A platform-specific implementation requires an explicit boundary, fallback behavior, and documentation. Do not let it leak into shared modules.
- A feature is not complete when it works on only one required platform. If counterpart support is intentionally deferred, label it honestly as coming soon and record the gap.
- New dependencies must support all platforms that execute the module. Platform-only dependencies belong behind an adapter.

Pull requests that affect shared code must pass the backend CI matrix on macOS, Windows, and Linux.

## Shared Git Protocol

GitHub is the synchronization layer between Codex, Claude Code, Antigravity, the Mac, and the Windows Tank.

### Before work

```bash
git status --short --branch
git fetch origin
git pull --ff-only
```

Never begin by force-resetting, deleting, or overwriting another agent's uncommitted work.

### Branch ownership

- Use one branch per task: `codex/<task>`, `claude/<task>`, `antigravity/<task>`, or `human/<task>`.
- Continue an existing branch only when the user explicitly wants the same body of work.
- Prefer a separate Git worktree when two agents may run concurrently.
- Never let two agents edit the same working tree at the same time.
- Never force-push shared branches unless the user explicitly approves it.

### Commits and handoff

- Keep commits small, coherent, and tool-neutral.
- Commit messages describe the outcome, not the agent that produced it.
- Push before switching machines or agents.
- Leave a concise PR comment or final message with branch, commit, checks, and remaining work.
- Do not commit generated local memory, credentials, caches, IDE state, or machine-specific paths.

### Safe integration

- Pull with `--ff-only`; do not hide divergence with an automatic merge.
- Rebase a private task branch only after checking that no other agent is using it.
- Resolve conflicts from product truth and tests, not by choosing “ours” or “theirs” wholesale.
- Merge through a pull request whenever practical.

## Source-of-Truth Order

When instructions disagree, use this order:

1. The user's current explicit request.
2. [`docs/PRODUCT_DECISIONS.md`](PRODUCT_DECISIONS.md).
3. Relevant architecture or build document under `docs/`.
4. Existing tests and established implementation patterns.
5. This workflow.
6. Tool-specific adapter files.

Tool-specific memory and chat history are hints, not shared project truth.

## Product Rules That Must Survive Every Implementation

- NOBS is local-first, privacy-first, and useful without a paid cloud plan.
- Chat is the home of the product; settings and adaptation happen conversationally.
- Do not claim an unfinished capability works. Explain that it is coming soon and offer the closest available action.
- Passwords and financial accounts are off-limits.
- Sensitive data use must be contextual, visible, and approved.
- Processing must be identifiable as Local, Tank, or NOBScloud.
- Automation must be visible, revocable, auditable, and reversible where possible.
- Do not create lock-in, artificial hardware limits, surveillance, or data monetization.
- Accessibility is adaptive product behavior, not a separate diminished mode.

## Security and Privacy

- Never commit `.env`, keys, tokens, certificates, personal data, production logs, or database files.
- Before making the repository public, follow [`docs/PUBLIC_RELEASE.md`](PUBLIC_RELEASE.md).
- Use `.env.example` only for blank or clearly fake values.
- Treat calendar, messages, contacts, health, location, home, research, and memory as sensitive.
- Minimize collection and retention.
- Do not transmit user data to a third party unless the feature and permission explicitly require it.
- New integrations require declared permissions, network destinations, failure behavior, and tests.
- High-risk home controls, purchases, external messages, deletion, admin access, and secret access require explicit safeguards.

## Implementation Standards

### Swift and SwiftUI

- Use current Apple frameworks and Swift concurrency.
- Prefer native SwiftUI components and SF Symbols.
- Keep views small and extract stateful behavior into testable models or services.
- Support Dynamic Type, VoiceOver, reduced motion, sufficient contrast, and non-color state indicators.
- Keep preview/sample data free of real personal information.
- Do not add a dependency when an Apple framework cleanly solves the problem.

### Python and FastAPI

- Require Python 3.11 or newer.
- Keep configuration centralized in `app/config.py`.
- Validate external input with typed models.
- Keep routes thin; place business logic in testable modules.
- Use explicit timeouts and bounded retries for network or model calls.
- Log failures clearly without logging secrets or personal content.
- Preserve deterministic health, auth, and entitlement behavior.

### Tank agent and tool extensions

- The local model may propose an action; it never authorizes the action.
- Register concrete tools in `app/agent_tools.py`. Do not give the model an arbitrary shell, unrestricted filesystem access, credential access, or an open-ended URL fetcher.
- Classify every tool as read-only, change, sensitive, or critical before exposing it to the model.
- Read-only tools may run automatically only when their output and scope are bounded.
- State changes require a stored approval containing the exact tool name and arguments. Do not regenerate arguments after approval.
- Approval execution must be atomic, non-replayable, auditable, and restricted to the same tool risk that was approved.
- Keep Personal, Business, and Shared context explicit in schemas, storage, prompts, and tests. Never infer that cross-context sharing is allowed.
- Every integration must document data source, requested permissions, network destinations, retention, failure behavior, and revocation.
- Scheduled work uses the same tool registry and approval policy; a scheduler must never become a bypass around consent.
- Add denial, replay, path-boundary, malformed-model-output, and unavailable-dependency tests for every new tool family.

### Cross-platform behavior

- Use repository-relative paths in code and documentation.
- Use UTF-8 and LF line endings; Git handles platform checkout behavior through `.gitattributes`.
- Do not commit macOS-only user data, Xcode user schemes, Windows drive paths, or WSL-specific addresses as universal defaults.
- Put environment differences behind configuration and document both macOS and Windows/WSL2 commands.

## Validation

Run the narrowest relevant checks before handing off.

### Backend

```bash
python scripts/dev.py setup
python scripts/dev.py check
```

On macOS, `python3` may be used instead of `python`. Python must be 3.11 or newer. The task runner resolves `.venv/bin` and `.venv/Scripts` automatically.

For Tank agent changes, required cases include automatic read-only execution, queued state changes, denial without side effects, and non-replayable approval. Live Ollama testing is additional evidence; it does not replace deterministic tests.

### iOS

Use Xcode 27 or newer on macOS. A command-line simulator build should use the installed Xcode path and an available iPhone simulator. Never claim the app builds based only on source inspection.

Example:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcodebuild -project NOBS.xcodeproj -scheme NOBS \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

### Documentation-only changes

```bash
git diff --check
```

## Definition of Done

A task is done only when:

- requested behavior is implemented;
- relevant checks pass or the exact blocker is recorded;
- privacy, accessibility, offline, and failure states were considered;
- documentation reflects durable architectural or product changes;
- `docs/CURRENT_STATE.md` reflects meaningful capability or next-step changes;
- the branch is pushed when the user asks for cross-device handoff;
- the handoff names the branch, commit, validation, and remaining risks.

## Local Agent Files

Personal or machine-local agent notes must not be committed. Use ignored files such as:

- `CLAUDE.local.md`;
- `.agents/local/`;
- `.codex/local/`;
- editor-specific workspace state.

If a discovery should survive switching tools or computers, put it in `docs/`, a test, an issue, or a pull request—not in private agent memory.
