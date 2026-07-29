# NOBS Instructions for Codex and Other Agents

Read [`docs/CODEBASE_REFERENCE.md`](docs/CODEBASE_REFERENCE.md) first for the current repo map, architecture, build/test commands, CI, and signing state.

Then read and follow [`docs/AI_WORKFLOW.md`](docs/AI_WORKFLOW.md) before making changes.

The approved product source of truth is [`docs/PRODUCT_DECISIONS.md`](docs/PRODUCT_DECISIONS.md).

Do not duplicate durable project instructions in this adapter. Update `docs/AI_WORKFLOW.md` so Codex, Claude Code, Antigravity, and human contributors receive the same guidance.

## Cursor Cloud specific instructions

The Cursor Cloud VM is Linux, so only the Python backend (`app/`, `tests/`) and the `website/` prototype are buildable/runnable here. The iOS/macOS/Android targets (`NOBS/`, `NOBSWidgets/`, `NOBSTankMac/`, `NOBSAndroid/`) require macOS + Xcode and cannot be built in this environment.

Startup deps are refreshed automatically by the update script (`python3 scripts/dev.py setup` + `pnpm --dir website install`); the venv lives at `.venv/`. Standard commands are already documented in `README.md` and `docs/CODEBASE_REFERENCE.md`:

- Backend checks: `python3 scripts/dev.py check` (pytest + ruff). Run + serve: `python3 scripts/dev.py run` (uvicorn on `127.0.0.1:8000`).
- Website: `pnpm --dir website dev` (Vite on `127.0.0.1:5173`); `pnpm --dir website build`.

Non-obvious caveats:

- Copy `.env.example` to `.env` before running the backend (`.env` is gitignored). A device token is not required to boot: `POST /auth/apple` bootstraps and persists one in the agent SQLite DB, then use it as `Authorization: Bearer <token>` for protected routes (`/ready`, `/chat`, `/sync/*`, `/schedules`, `/agent/*`, ...).
- Ollama is NOT installed here and is optional. The test suite mocks it, and public routes / dashboard work without it — the dashboard correctly shows "Ollama offline". Only the live-model routes (`/chat`, `/briefing`, dream-team `run`) and `POST /optimizer/run-now` model jobs need a local Ollama with `qwen3:8b`; expect 503 from those without it.
- The `python3-venv` system package is required to create the venv (already present in the VM snapshot).

