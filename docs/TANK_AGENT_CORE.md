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

There is deliberately no general-purpose shell, arbitrary URL fetcher, package installer, credential reader, message sender, deletion tool, or unrestricted filesystem tool.

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
