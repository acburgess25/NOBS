from __future__ import annotations

from datetime import UTC, datetime, timedelta
import json
from pathlib import Path
import sqlite3
from threading import Lock
from typing import Any
from uuid import uuid4


def _now() -> str:
    return datetime.now(UTC).isoformat()


class AgentStore:
    """Small local audit store for agent runs and approval decisions."""

    def __init__(self, database_path: Path) -> None:
        self.database_path = database_path
        self._connection: sqlite3.Connection | None = None
        self._lock = Lock()

    def _connect(self) -> sqlite3.Connection:
        if self._connection is None:
            if str(self.database_path) != ":memory:":
                self.database_path.parent.mkdir(parents=True, exist_ok=True)
            self._connection = sqlite3.connect(
                self.database_path,
                check_same_thread=False,
            )
            self._connection.row_factory = sqlite3.Row
            self._connection.executescript(
                """
                PRAGMA journal_mode=WAL;
                CREATE TABLE IF NOT EXISTS agent_runs (
                    id TEXT PRIMARY KEY,
                    objective TEXT NOT NULL,
                    context TEXT NOT NULL,
                    status TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS approvals (
                    id TEXT PRIMARY KEY,
                    run_id TEXT NOT NULL REFERENCES agent_runs(id),
                    tool_name TEXT NOT NULL,
                    arguments_json TEXT NOT NULL,
                    risk TEXT NOT NULL,
                    reason TEXT NOT NULL,
                    status TEXT NOT NULL,
                    result_json TEXT,
                    created_at TEXT NOT NULL,
                    decided_at TEXT
                );
                CREATE TABLE IF NOT EXISTS audit_events (
                    id TEXT PRIMARY KEY,
                    run_id TEXT NOT NULL REFERENCES agent_runs(id),
                    event_type TEXT NOT NULL,
                    detail_json TEXT NOT NULL,
                    created_at TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS briefings (
                    date TEXT PRIMARY KEY,
                    content_json TEXT NOT NULL,
                    generated_at TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS proposals (
                    id TEXT PRIMARY KEY,
                    title TEXT NOT NULL,
                    description TEXT NOT NULL,
                    proposal_type TEXT NOT NULL,
                    status TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    decided_at TEXT
                );
                CREATE TABLE IF NOT EXISTS briefing_schedules (
                    id TEXT PRIMARY KEY,
                    time_of_day TEXT NOT NULL,
                    status TEXT NOT NULL,
                    created_at TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS calendar_events (
                    id TEXT PRIMARY KEY,
                    title TEXT NOT NULL,
                    start TEXT NOT NULL,
                    context TEXT NOT NULL,
                    created_at TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS reminders (
                    id TEXT PRIMARY KEY,
                    title TEXT NOT NULL,
                    context TEXT NOT NULL,
                    created_at TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS kv (
                    key TEXT PRIMARY KEY,
                    value TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS overnight_tasks (
                    id TEXT PRIMARY KEY,
                    objective TEXT NOT NULL,
                    context TEXT NOT NULL,
                    mode TEXT NOT NULL,
                    task_type TEXT NOT NULL,
                    priority INTEGER NOT NULL,
                    status TEXT NOT NULL,
                    result_json TEXT,
                    error TEXT,
                    created_at TEXT NOT NULL,
                    started_at TEXT,
                    completed_at TEXT
                );
                CREATE TABLE IF NOT EXISTS dream_team_sessions (
                    id TEXT PRIMARY KEY,
                    objective TEXT NOT NULL,
                    context TEXT NOT NULL,
                    status TEXT NOT NULL,
                    config_json TEXT NOT NULL,
                    result_summary TEXT,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS dream_team_drafts (
                    id TEXT PRIMARY KEY,
                    session_id TEXT NOT NULL,
                    name TEXT NOT NULL,
                    role TEXT NOT NULL,
                    persona_json TEXT NOT NULL,
                    score REAL,
                    iteration INTEGER NOT NULL DEFAULT 0,
                    status TEXT NOT NULL,
                    test_result_json TEXT,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS dream_team_iterations (
                    id TEXT PRIMARY KEY,
                    draft_id TEXT NOT NULL,
                    iteration INTEGER NOT NULL,
                    changes_json TEXT NOT NULL,
                    score REAL,
                    notes TEXT,
                    created_at TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS dream_team_proposals (
                    id TEXT PRIMARY KEY,
                    session_id TEXT NOT NULL,
                    title TEXT NOT NULL,
                    summary TEXT NOT NULL,
                    members_json TEXT NOT NULL,
                    metadata_json TEXT NOT NULL,
                    status TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    decided_at TEXT
                );
                """
            )
        return self._connection

    def create_run(self, objective: str, context: str) -> str:
        run_id = str(uuid4())
        now = _now()
        with self._lock:
            connection = self._connect()
            connection.execute(
                "INSERT INTO agent_runs VALUES (?, ?, ?, ?, ?, ?)",
                (run_id, objective, context, "running", now, now),
            )
            connection.commit()
        return run_id

    def update_run(self, run_id: str, status: str) -> None:
        with self._lock:
            connection = self._connect()
            connection.execute(
                "UPDATE agent_runs SET status = ?, updated_at = ? WHERE id = ?",
                (status, _now(), run_id),
            )
            connection.commit()

    def record_event(self, run_id: str, event_type: str, detail: dict[str, Any]) -> None:
        with self._lock:
            connection = self._connect()
            connection.execute(
                "INSERT INTO audit_events VALUES (?, ?, ?, ?, ?)",
                (str(uuid4()), run_id, event_type, json.dumps(detail), _now()),
            )
            connection.commit()

    def create_approval(
        self,
        run_id: str,
        tool_name: str,
        arguments: dict[str, Any],
        risk: str,
        reason: str,
    ) -> dict[str, Any]:
        approval_id = str(uuid4())
        created_at = _now()
        with self._lock:
            connection = self._connect()
            connection.execute(
                "INSERT INTO approvals VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                (
                    approval_id,
                    run_id,
                    tool_name,
                    json.dumps(arguments),
                    risk,
                    reason,
                    "pending",
                    None,
                    created_at,
                    None,
                ),
            )
            connection.commit()
        return self.get_approval(approval_id)

    def get_approval(self, approval_id: str) -> dict[str, Any]:
        with self._lock:
            row = (
                self._connect()
                .execute(
                    "SELECT * FROM approvals WHERE id = ?",
                    (approval_id,),
                )
                .fetchone()
            )
        if row is None:
            raise KeyError(approval_id)
        return self._approval_dict(row)

    def list_approvals(self, status: str | None = None) -> list[dict[str, Any]]:
        with self._lock:
            connection = self._connect()
            if status is None:
                rows = connection.execute(
                    "SELECT * FROM approvals ORDER BY created_at DESC"
                ).fetchall()
            else:
                rows = connection.execute(
                    "SELECT * FROM approvals WHERE status = ? ORDER BY created_at DESC",
                    (status,),
                ).fetchall()
        return [self._approval_dict(row) for row in rows]

    def decide_approval(
        self,
        approval_id: str,
        decision: str,
        result: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        with self._lock:
            connection = self._connect()
            cursor = connection.execute(
                """
                UPDATE approvals
                SET status = ?, result_json = ?, decided_at = ?
                WHERE id = ? AND status = 'pending'
                """,
                (decision, json.dumps(result) if result is not None else None, _now(), approval_id),
            )
            connection.commit()
        if cursor.rowcount != 1:
            raise ValueError("Approval is missing or already decided")
        return self.get_approval(approval_id)

    def claim_approval(self, approval_id: str) -> dict[str, Any]:
        """Atomically reserve one pending approval before executing its tool."""
        with self._lock:
            connection = self._connect()
            cursor = connection.execute(
                """
                UPDATE approvals SET status = 'executing', decided_at = ?
                WHERE id = ? AND status = 'pending'
                """,
                (_now(), approval_id),
            )
            connection.commit()
        if cursor.rowcount != 1:
            raise ValueError("Approval is missing or already decided")
        return self.get_approval(approval_id)

    def finish_approval(
        self,
        approval_id: str,
        status: str,
        result: dict[str, Any],
    ) -> dict[str, Any]:
        with self._lock:
            connection = self._connect()
            cursor = connection.execute(
                """
                UPDATE approvals SET status = ?, result_json = ?
                WHERE id = ? AND status = 'executing'
                """,
                (status, json.dumps(result), approval_id),
            )
            connection.commit()
        if cursor.rowcount != 1:
            raise ValueError("Approval is not being executed")
        return self.get_approval(approval_id)

    def last_proposal_at(self) -> str | None:
        """Return ISO timestamp of the most recently created proposal, or None."""
        with self._lock:
            row = (
                self._connect()
                .execute("SELECT created_at FROM proposals ORDER BY created_at DESC LIMIT 1")
                .fetchone()
            )
        return row["created_at"] if row else None

    def dashboard_metrics(self) -> dict[str, Any]:
        cutoff = (datetime.now(UTC) - timedelta(hours=24)).isoformat()
        with self._lock:
            connection = self._connect()
            pending_approvals = connection.execute(
                "SELECT COUNT(*) FROM approvals WHERE status = 'pending'"
            ).fetchone()[0]
            pending_proposals = connection.execute(
                "SELECT COUNT(*) FROM proposals WHERE status = 'pending'"
            ).fetchone()[0]
            runs_24h = connection.execute(
                "SELECT COUNT(*) FROM agent_runs WHERE created_at >= ?",
                (cutoff,),
            ).fetchone()[0]
            completed_24h = connection.execute(
                "SELECT COUNT(*) FROM agent_runs WHERE created_at >= ? AND status = 'completed'",
                (cutoff,),
            ).fetchone()[0]
            last_event = connection.execute(
                "SELECT created_at FROM audit_events ORDER BY created_at DESC LIMIT 1"
            ).fetchone()
        return {
            "pending_approvals": pending_approvals,
            "pending_proposals": pending_proposals,
            "runs_24h": runs_24h,
            "completed_24h": completed_24h,
            "last_activity_at": last_event[0] if last_event else None,
        }

    def save_briefing(self, date: str, content: dict[str, Any]) -> dict[str, Any]:
        generated_at = str(content["generated_at"])
        with self._lock:
            connection = self._connect()
            connection.execute(
                """
                INSERT INTO briefings (date, content_json, generated_at) VALUES (?, ?, ?)
                ON CONFLICT(date) DO UPDATE SET
                    content_json = excluded.content_json,
                    generated_at = excluded.generated_at
                """,
                (date, json.dumps(content), generated_at),
            )
            connection.commit()
        return content

    def latest_briefing(self) -> dict[str, Any] | None:
        with self._lock:
            row = (
                self._connect()
                .execute("SELECT content_json FROM briefings ORDER BY generated_at DESC LIMIT 1")
                .fetchone()
            )
        return json.loads(row["content_json"]) if row else None

    def create_proposal(self, title: str, description: str, proposal_type: str) -> dict[str, Any]:
        proposal_id = str(uuid4())
        created_at = _now()
        with self._lock:
            connection = self._connect()
            connection.execute(
                "INSERT INTO proposals VALUES (?, ?, ?, ?, ?, ?, ?)",
                (proposal_id, title, description, proposal_type, "pending", created_at, None),
            )
            connection.commit()
        return self.get_proposal(proposal_id)

    def get_proposal(self, proposal_id: str) -> dict[str, Any]:
        with self._lock:
            row = (
                self._connect()
                .execute(
                    "SELECT * FROM proposals WHERE id = ?",
                    (proposal_id,),
                )
                .fetchone()
            )
        if row is None:
            raise KeyError(proposal_id)
        return self._proposal_dict(row)

    def list_proposals(self, status: str | None = None) -> list[dict[str, Any]]:
        with self._lock:
            connection = self._connect()
            if status is None:
                rows = connection.execute(
                    "SELECT * FROM proposals ORDER BY created_at DESC"
                ).fetchall()
            else:
                rows = connection.execute(
                    "SELECT * FROM proposals WHERE status = ? ORDER BY created_at DESC",
                    (status,),
                ).fetchall()
        return [self._proposal_dict(row) for row in rows]

    def decide_proposal(self, proposal_id: str, decision: str) -> dict[str, Any]:
        if decision not in {"approved", "dismissed"}:
            raise ValueError("Decision must be approved or dismissed")
        with self._lock:
            connection = self._connect()
            cursor = connection.execute(
                """
                UPDATE proposals
                SET status = ?, decided_at = ?
                WHERE id = ? AND status = 'pending'
                """,
                (decision, _now(), proposal_id),
            )
            connection.commit()
        if cursor.rowcount != 1:
            raise ValueError("Proposal is missing or already decided")
        return self.get_proposal(proposal_id)

    def create_briefing_schedule(self, time_of_day: str) -> dict[str, Any]:
        schedule_id = str(uuid4())
        created_at = _now()
        with self._lock:
            connection = self._connect()
            connection.execute(
                "INSERT INTO briefing_schedules VALUES (?, ?, ?, ?)",
                (schedule_id, time_of_day, "active", created_at),
            )
            connection.commit()
        return self.get_briefing_schedule(schedule_id)

    def get_briefing_schedule(self, schedule_id: str) -> dict[str, Any]:
        with self._lock:
            row = (
                self._connect()
                .execute(
                    "SELECT * FROM briefing_schedules WHERE id = ?",
                    (schedule_id,),
                )
                .fetchone()
            )
        if row is None:
            raise KeyError(schedule_id)
        return dict(row)

    def list_briefing_schedules(self, status: str | None = None) -> list[dict[str, Any]]:
        with self._lock:
            connection = self._connect()
            if status is None:
                rows = connection.execute(
                    "SELECT * FROM briefing_schedules ORDER BY created_at DESC"
                ).fetchall()
            else:
                rows = connection.execute(
                    "SELECT * FROM briefing_schedules WHERE status = ? ORDER BY created_at DESC",
                    (status,),
                ).fetchall()
        return [dict(row) for row in rows]

    def update_briefing_schedule(self, schedule_id: str, status: str) -> dict[str, Any]:
        if status not in {"active", "paused", "revoked"}:
            raise ValueError("Status must be active, paused, or revoked")
        with self._lock:
            connection = self._connect()
            cursor = connection.execute(
                "UPDATE briefing_schedules SET status = ? WHERE id = ?",
                (status, schedule_id),
            )
            connection.commit()
        if cursor.rowcount != 1:
            raise ValueError("Schedule is missing")
        return self.get_briefing_schedule(schedule_id)

    def sync_calendar(self, events: list[dict[str, str]]) -> None:
        created_at = _now()
        with self._lock:
            connection = self._connect()
            connection.execute("DELETE FROM calendar_events")
            for event in events:
                connection.execute(
                    "INSERT INTO calendar_events VALUES (?, ?, ?, ?, ?)",
                    (str(uuid4()), event["title"], event["start"], event["context"], created_at),
                )
            connection.commit()

    def list_calendar_events(self) -> list[dict[str, Any]]:
        with self._lock:
            rows = self._connect().execute("SELECT * FROM calendar_events").fetchall()
        return [dict(row) for row in rows]

    def sync_reminders(self, reminders: list[dict[str, str]]) -> None:
        created_at = _now()
        with self._lock:
            connection = self._connect()
            connection.execute("DELETE FROM reminders")
            for reminder in reminders:
                connection.execute(
                    "INSERT INTO reminders VALUES (?, ?, ?, ?)",
                    (str(uuid4()), reminder["title"], reminder["context"], created_at),
                )
            connection.commit()

    def list_reminders(self) -> list[dict[str, Any]]:
        with self._lock:
            rows = self._connect().execute("SELECT * FROM reminders").fetchall()
        return [dict(row) for row in rows]

    @staticmethod
    def _proposal_dict(row: sqlite3.Row) -> dict[str, Any]:
        return {
            "id": row["id"],
            "title": row["title"],
            "description": row["description"],
            "proposal_type": row["proposal_type"],
            "status": row["status"],
            "created_at": row["created_at"],
            "decided_at": row["decided_at"],
        }

    @staticmethod
    def _approval_dict(row: sqlite3.Row) -> dict[str, Any]:
        return {
            "id": row["id"],
            "run_id": row["run_id"],
            "tool_name": row["tool_name"],
            "arguments": json.loads(row["arguments_json"]),
            "risk": row["risk"],
            "reason": row["reason"],
            "status": row["status"],
            "result": json.loads(row["result_json"]) if row["result_json"] else None,
            "created_at": row["created_at"],
            "decided_at": row["decided_at"],
        }

    # ------------------------------------------------------------------
    # Key-value store (generic settings, e.g. apple_user_identifier)
    # ------------------------------------------------------------------

    def get_kv(self, key: str) -> str | None:
        with self._lock:
            row = self._connect().execute("SELECT value FROM kv WHERE key = ?", (key,)).fetchone()
        return row["value"] if row else None

    def set_kv(self, key: str, value: str) -> None:
        with self._lock:
            connection = self._connect()
            connection.execute(
                "INSERT OR REPLACE INTO kv (key, value) VALUES (?, ?)",
                (key, value),
            )
            connection.commit()

    # ------------------------------------------------------------------
    # Overnight Tank queue (deferred/long-running work processed off-hours)
    # ------------------------------------------------------------------

    def enqueue_overnight_task(
        self,
        objective: str,
        context: str,
        task_type: str,
        mode: str = "assistant",
        priority: int = 0,
    ) -> dict[str, Any]:
        task_id = str(uuid4())
        created_at = _now()
        with self._lock:
            connection = self._connect()
            connection.execute(
                "INSERT INTO overnight_tasks VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                (
                    task_id,
                    objective,
                    context,
                    mode,
                    task_type,
                    priority,
                    "queued",
                    None,
                    None,
                    created_at,
                    None,
                    None,
                ),
            )
            connection.commit()
        return self.get_overnight_task(task_id)

    def get_overnight_task(self, task_id: str) -> dict[str, Any]:
        with self._lock:
            row = (
                self._connect()
                .execute("SELECT * FROM overnight_tasks WHERE id = ?", (task_id,))
                .fetchone()
            )
        if row is None:
            raise KeyError(task_id)
        return self._overnight_task_dict(row)

    def list_overnight_tasks(self, status: str | None = None) -> list[dict[str, Any]]:
        with self._lock:
            connection = self._connect()
            if status is None:
                rows = connection.execute(
                    "SELECT * FROM overnight_tasks ORDER BY priority DESC, created_at ASC"
                ).fetchall()
            else:
                rows = connection.execute(
                    "SELECT * FROM overnight_tasks WHERE status = ? "
                    "ORDER BY priority DESC, created_at ASC",
                    (status,),
                ).fetchall()
        return [self._overnight_task_dict(row) for row in rows]

    def claim_next_overnight_task(self) -> dict[str, Any] | None:
        """Atomically reserve the oldest, highest-priority queued task.

        Returns None if there is nothing queued. Once claimed, a task moves to
        `running` and cannot be claimed again, mirroring the approval claim
        pattern used for state-changing agent tools.
        """
        with self._lock:
            connection = self._connect()
            candidate = connection.execute(
                "SELECT id FROM overnight_tasks WHERE status = 'queued' "
                "ORDER BY priority DESC, created_at ASC LIMIT 1"
            ).fetchone()
            if candidate is None:
                return None
            task_id = candidate["id"]
            cursor = connection.execute(
                """
                UPDATE overnight_tasks SET status = 'running', started_at = ?
                WHERE id = ? AND status = 'queued'
                """,
                (_now(), task_id),
            )
            connection.commit()
            if cursor.rowcount != 1:
                return None
            row = connection.execute(
                "SELECT * FROM overnight_tasks WHERE id = ?", (task_id,)
            ).fetchone()
        return self._overnight_task_dict(row)

    def complete_overnight_task(self, task_id: str, result: dict[str, Any]) -> dict[str, Any]:
        with self._lock:
            connection = self._connect()
            cursor = connection.execute(
                """
                UPDATE overnight_tasks SET status = 'completed', result_json = ?, completed_at = ?
                WHERE id = ? AND status = 'running'
                """,
                (json.dumps(result), _now(), task_id),
            )
            connection.commit()
        if cursor.rowcount != 1:
            raise ValueError("Overnight task is not running")
        return self.get_overnight_task(task_id)

    def fail_overnight_task(self, task_id: str, error: str) -> dict[str, Any]:
        with self._lock:
            connection = self._connect()
            cursor = connection.execute(
                """
                UPDATE overnight_tasks SET status = 'failed', error = ?, completed_at = ?
                WHERE id = ? AND status = 'running'
                """,
                (error, _now(), task_id),
            )
            connection.commit()
        if cursor.rowcount != 1:
            raise ValueError("Overnight task is not running")
        return self.get_overnight_task(task_id)

    def cancel_overnight_task(self, task_id: str) -> dict[str, Any]:
        """Cancel a task that has not started yet. Running/finished tasks cannot be cancelled."""
        with self._lock:
            connection = self._connect()
            cursor = connection.execute(
                """
                UPDATE overnight_tasks SET status = 'cancelled', completed_at = ?
                WHERE id = ? AND status = 'queued'
                """,
                (_now(), task_id),
            )
            connection.commit()
        if cursor.rowcount != 1:
            raise ValueError("Overnight task is missing, already started, or already finished")
        return self.get_overnight_task(task_id)

    @staticmethod
    def _overnight_task_dict(row: sqlite3.Row) -> dict[str, Any]:
        return {
            "id": row["id"],
            "objective": row["objective"],
            "context": row["context"],
            "mode": row["mode"],
            "task_type": row["task_type"],
            "priority": row["priority"],
            "status": row["status"],
            "result": json.loads(row["result_json"]) if row["result_json"] else None,
            "error": row["error"],
            "created_at": row["created_at"],
            "started_at": row["started_at"],
            "completed_at": row["completed_at"],
        }

    # ------------------------------------------------------------------
    # Dream Team Sandbox (local-first agent persona refinement)
    # ------------------------------------------------------------------

    def create_dream_team_session(
        self,
        objective: str,
        context: str,
        config: dict[str, Any],
    ) -> dict[str, Any]:
        session_id = str(uuid4())
        now = _now()
        with self._lock:
            connection = self._connect()
            connection.execute(
                "INSERT INTO dream_team_sessions VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                (
                    session_id,
                    objective,
                    context,
                    "queued",
                    json.dumps(config),
                    None,
                    now,
                    now,
                ),
            )
            connection.commit()
        return self.get_dream_team_session(session_id)

    def get_dream_team_session(
        self, session_id: str, *, include_details: bool = False
    ) -> dict[str, Any]:
        with self._lock:
            row = (
                self._connect()
                .execute("SELECT * FROM dream_team_sessions WHERE id = ?", (session_id,))
                .fetchone()
            )
        if row is None:
            raise KeyError(session_id)
        session = self._dream_team_session_dict(row)
        if include_details:
            session["drafts"] = self.list_dream_team_drafts(session_id)
            session["proposals"] = self.list_dream_team_proposals(session_id=session_id)
        return session

    def list_dream_team_sessions(self, status: str | None = None) -> list[dict[str, Any]]:
        with self._lock:
            connection = self._connect()
            if status is None:
                rows = connection.execute(
                    "SELECT * FROM dream_team_sessions ORDER BY created_at DESC"
                ).fetchall()
            else:
                rows = connection.execute(
                    "SELECT * FROM dream_team_sessions WHERE status = ? ORDER BY created_at DESC",
                    (status,),
                ).fetchall()
        return [self._dream_team_session_dict(row) for row in rows]

    def update_dream_team_session(
        self,
        session_id: str,
        status: str,
        result_summary: str | None = None,
    ) -> dict[str, Any]:
        with self._lock:
            connection = self._connect()
            connection.execute(
                """
                UPDATE dream_team_sessions
                SET status = ?, result_summary = COALESCE(?, result_summary), updated_at = ?
                WHERE id = ?
                """,
                (status, result_summary, _now(), session_id),
            )
            connection.commit()
        return self.get_dream_team_session(session_id)

    def create_dream_team_draft(
        self,
        session_id: str,
        name: str,
        role: str,
        persona: dict[str, Any],
    ) -> dict[str, Any]:
        draft_id = str(uuid4())
        now = _now()
        with self._lock:
            connection = self._connect()
            connection.execute(
                "INSERT INTO dream_team_drafts VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                (
                    draft_id,
                    session_id,
                    name,
                    role,
                    json.dumps(persona),
                    None,
                    0,
                    "draft",
                    None,
                    now,
                    now,
                ),
            )
            connection.commit()
        return self.get_dream_team_draft(draft_id)

    def get_dream_team_draft(self, draft_id: str) -> dict[str, Any]:
        with self._lock:
            row = (
                self._connect()
                .execute("SELECT * FROM dream_team_drafts WHERE id = ?", (draft_id,))
                .fetchone()
            )
        if row is None:
            raise KeyError(draft_id)
        return self._dream_team_draft_dict(row)

    def list_dream_team_drafts(self, session_id: str) -> list[dict[str, Any]]:
        with self._lock:
            rows = (
                self._connect()
                .execute(
                    "SELECT * FROM dream_team_drafts WHERE session_id = ? ORDER BY created_at ASC",
                    (session_id,),
                )
                .fetchall()
            )
        return [self._dream_team_draft_dict(row) for row in rows]

    def update_dream_team_draft(
        self,
        draft_id: str,
        *,
        persona: dict[str, Any] | None = None,
        score: float | None = None,
        status: str | None = None,
        iteration: int | None = None,
        test_result: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        fields: list[str] = ["updated_at = ?"]
        values: list[Any] = [_now()]
        if persona is not None:
            fields.append("persona_json = ?")
            values.append(json.dumps(persona))
        if score is not None:
            fields.append("score = ?")
            values.append(score)
        if status is not None:
            fields.append("status = ?")
            values.append(status)
        if iteration is not None:
            fields.append("iteration = ?")
            values.append(iteration)
        if test_result is not None:
            fields.append("test_result_json = ?")
            values.append(json.dumps(test_result))
        values.append(draft_id)
        with self._lock:
            connection = self._connect()
            connection.execute(
                f"UPDATE dream_team_drafts SET {', '.join(fields)} WHERE id = ?",
                values,
            )
            connection.commit()
        return self.get_dream_team_draft(draft_id)

    def record_dream_team_iteration(
        self,
        draft_id: str,
        iteration: int,
        changes: dict[str, Any],
        score: float | None,
        notes: str,
    ) -> dict[str, Any]:
        iteration_id = str(uuid4())
        with self._lock:
            connection = self._connect()
            connection.execute(
                "INSERT INTO dream_team_iterations VALUES (?, ?, ?, ?, ?, ?, ?)",
                (
                    iteration_id,
                    draft_id,
                    iteration,
                    json.dumps(changes),
                    score,
                    notes,
                    _now(),
                ),
            )
            connection.commit()
        return {
            "id": iteration_id,
            "draft_id": draft_id,
            "iteration": iteration,
            "changes": changes,
            "score": score,
            "notes": notes,
        }

    def create_dream_team_proposal(
        self,
        session_id: str,
        title: str,
        summary: str,
        members: list[dict[str, Any]],
        metadata: dict[str, Any],
    ) -> dict[str, Any]:
        proposal_id = str(uuid4())
        created_at = _now()
        with self._lock:
            connection = self._connect()
            connection.execute(
                "INSERT INTO dream_team_proposals VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
                (
                    proposal_id,
                    session_id,
                    title,
                    summary,
                    json.dumps(members),
                    json.dumps(metadata),
                    "pending",
                    created_at,
                    None,
                ),
            )
            connection.commit()
        return self.get_dream_team_proposal(proposal_id)

    def get_dream_team_proposal(self, proposal_id: str) -> dict[str, Any]:
        with self._lock:
            row = (
                self._connect()
                .execute("SELECT * FROM dream_team_proposals WHERE id = ?", (proposal_id,))
                .fetchone()
            )
        if row is None:
            raise KeyError(proposal_id)
        return self._dream_team_proposal_dict(row)

    def list_dream_team_proposals(
        self, status: str | None = None, session_id: str | None = None
    ) -> list[dict[str, Any]]:
        query = "SELECT * FROM dream_team_proposals WHERE 1=1"
        params: list[Any] = []
        if status is not None:
            query += " AND status = ?"
            params.append(status)
        if session_id is not None:
            query += " AND session_id = ?"
            params.append(session_id)
        query += " ORDER BY created_at DESC"
        with self._lock:
            rows = self._connect().execute(query, params).fetchall()
        return [self._dream_team_proposal_dict(row) for row in rows]

    def decide_dream_team_proposal(self, proposal_id: str, decision: str) -> dict[str, Any]:
        if decision not in {"approved", "rejected"}:
            raise ValueError("Decision must be approved or rejected")
        with self._lock:
            connection = self._connect()
            cursor = connection.execute(
                """
                UPDATE dream_team_proposals
                SET status = ?, decided_at = ?
                WHERE id = ? AND status = 'pending'
                """,
                (decision, _now(), proposal_id),
            )
            connection.commit()
        if cursor.rowcount != 1:
            raise ValueError("Proposal is missing or already decided")
        return self.get_dream_team_proposal(proposal_id)

    @staticmethod
    def _dream_team_session_dict(row: sqlite3.Row) -> dict[str, Any]:
        return {
            "id": row["id"],
            "objective": row["objective"],
            "context": row["context"],
            "status": row["status"],
            "config": json.loads(row["config_json"]),
            "result_summary": row["result_summary"],
            "created_at": row["created_at"],
            "updated_at": row["updated_at"],
        }

    @staticmethod
    def _dream_team_draft_dict(row: sqlite3.Row) -> dict[str, Any]:
        return {
            "id": row["id"],
            "session_id": row["session_id"],
            "name": row["name"],
            "role": row["role"],
            "persona": json.loads(row["persona_json"]),
            "score": row["score"],
            "iteration": row["iteration"],
            "status": row["status"],
            "test_result": json.loads(row["test_result_json"])
            if row["test_result_json"]
            else None,
            "created_at": row["created_at"],
            "updated_at": row["updated_at"],
        }

    @staticmethod
    def _dream_team_proposal_dict(row: sqlite3.Row) -> dict[str, Any]:
        return {
            "id": row["id"],
            "session_id": row["session_id"],
            "title": row["title"],
            "summary": row["summary"],
            "members": json.loads(row["members_json"]),
            "metadata": json.loads(row["metadata_json"]),
            "status": row["status"],
            "created_at": row["created_at"],
            "decided_at": row["decided_at"],
        }
