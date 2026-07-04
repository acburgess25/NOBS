# NOBS Tank Agent Core

## Purpose

Tank is the private execution core for NOBS. It uses a local Ollama model to plan work and select narrowly defined tools. It does not receive arbitrary shell access and it does not treat model output as authorization.

The first implementation establishes the trust boundary needed for future personal and business integrations:

- Personal, Business, and Shared are explicit contexts.
- Read-only allowlisted tools may execute automatically.
- Every state-changing tool creates a pending approval.
- The stored tool name and exact arguments are shown before approval.
- Approval execution is atomic and cannot be replayed.
- Every tool execution and approval decision is written to a local SQLite audit trail.
- Agent data stays under the configured local workspace.

## Current tools

| Tool | Risk | Behavior |
|---|---|---|
| `get_tank_status` | Read only | Reports basic host load and free storage. |
| `list_workspace_files` | Read only | Lists files in one approved context directory. |
| `write_workspace_note` | Change | Proposes a Markdown note and waits for approval. |
| `list_project_files` | Read only | (Developer Mode) Lists bounded source and doc files under the configured NOBS project. |
| `read_project_file` | Read only | (Developer Mode) Reads a bounded UTF-8 source or doc file from the configured project. |
| `search_project_text` | Read only | (Developer Mode) Searches for literal text fragment in bounded source/doc files. |

There is deliberately no general-purpose shell, arbitrary URL fetcher, package installer, credential reader, message sender, deletion tool, or unrestricted filesystem tool.

## Developer Mode

Developer Mode can be activated by specifying `"mode": "developer"` in the agent task request. 

### Scope and Honest Boundaries

- **Model**: Uses `qwen2.5-coder:14b` instead of `qwen3:8b`.
- **Purpose**: Allows inspecting the codebase and documentation to help answer questions or plan work.
- **Strict Boundaries**: 
  - It is **read-only**: it cannot edit or create files in the project directory, run tests, execute terminal commands, or access the network/internet.
  - **No Symlink or Traversal Escape**: All paths are resolved and validated against the configured project root. If a file or symlink points outside the project, execution fails.
  - **Exclusions**: Hidden files/folders (starting with `.`), database files, secrets (such as `.env`), and data folders (such as `data/`) are blocked.
  - **No Codex Parity**: It is an exploratory/inspection tool only; it does not have the full self-editing, testing, or browsing capability of the parent Codex/Antigravity environments.

## Code map

| File | Responsibility |
|---|---|
| `app/agent.py` | Typed contracts, bounded Ollama loop, context prompt, and orchestration. |
| `app/agent_tools.py` | Tool registry, risks, schemas, path boundaries, and handlers. |
| `app/agent_store.py` | SQLite runs, approvals, audit events, atomic claims, and results. |
| `app/main.py` | Authenticated routes and approval execution boundary. |
| `app/config.py` | Database, workspace, model, timeout, and step-limit configuration. |
| `tests/test_agent.py` | Autonomy, approval, denial, authentication, and replay tests. |

The model-facing loop and execution boundary are deliberately separate. `TankAgent` may request a tool, but only the registry can execute it and only the approval route can release a state-changing proposal.

## API

All agent routes require the existing Tank device bearer token.

### Start a task

```http
POST /agent/tasks
Content-Type: application/json

{
  "objective": "Check Tank and save a note with today's maintenance priority",
  "context": "business"
}
```

The response is either `completed`, `awaiting_approval`, or `step_limit_reached`. Pending actions include an approval ID and the exact proposed arguments.

### List pending approvals

```http
GET /agent/approvals?approval_status=pending
```

### Approve or deny

```http
POST /agent/approvals/{approval_id}
Content-Type: application/json

{"decision": "approve"}
```

Use `deny` to reject the action. A decided approval cannot be executed again.

## Storage

Defaults:

- audit database: `data/nobs-agent.db`;
- bounded workspace: `data/agent-workspace/`;
- context directories: `personal/`, `business/`, and `shared/`.

Both paths are configurable through `.env`. The entire `data/` directory is ignored by Git.

## Autonomy policy

The long-term tool policy is:

| Risk | Examples | Default |
|---|---|---|
| Read only | status, calendar lookup, approved-file search | May run automatically |
| Change | create a note, draft a task, update a project file | Approval required |
| Sensitive | draft/send communication, access health or location | Contextual permission plus approval |
| Critical | purchases, deletion, security, secrets, admin access | Approval every time; some actions remain prohibited |

Scheduled tasks will use the same tool registry and approval store. A schedule may allow Tank to prepare work automatically, but it never bypasses the risk policy.

## Next integrations

Add integrations one at a time behind this boundary:

1. local daily briefing inputs from the iPhone;
2. calendar and reminder read tools;
3. business project and document search;
4. drafts for email and messages, without automatic sending;
5. persistent schedules and a visible activity/approval screen;
6. reviewed MCP adapters with least-privilege scopes.

Every integration must declare its data source, context, permissions, network destinations, retention, failure behavior, and tests before it can join the tool registry.

## How to add a tool

1. Write one bounded handler in `app/agent_tools.py`. Accept finite arguments rather than commands or arbitrary URLs.
2. Constrain filesystem roots, record limits, time windows, response sizes, and network destinations in code.
3. Assign the risk before adding the tool to the registry.
4. Add a JSON schema that rejects extra properties and caps user-controlled text.
5. Test success, invalid arguments, scope escape, denial, replay, and dependency failure as applicable.
6. Document permissions, data flow, retention, revocation, and offline behavior.
7. Run `python3 scripts/dev.py check` before a live Tank test.
8. Live-test with fake or low-risk data first.

Do not expose an SDK client wholesale. Wrap only the smallest operations NOBS needs as separately reviewable tools.

## Deployment handoff

The repository contains deployable source; the live Tank directory may not be a Git checkout. Before deployment:

1. verify the service working directory;
2. preserve `~/.config/nobs/nobs-api.env` and local `data/` content;
3. copy source without copying `.env`, databases, or credentials;
4. restart `nobs-api.service`;
5. verify `/health`, authenticated `/ready`, one read-only task, and one denied change proposal;
6. record the branch, commit, checks, and live-only gaps in the handoff.

Never use `rsync --delete` against the Tank project root because local agent data and environment state are not repository artifacts.
