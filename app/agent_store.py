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
                    triggered_by TEXT NOT NULL DEFAULT 'user',
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
                CREATE TABLE IF NOT EXISTS memories (
                    id TEXT PRIMARY KEY,
                    content TEXT NOT NULL,
                    category TEXT NOT NULL,
                    source TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS research_jobs (
                    id TEXT PRIMARY KEY,
                    topic TEXT NOT NULL,
                    context TEXT NOT NULL,
                    status TEXT NOT NULL,
                    summary TEXT,
                    sources_json TEXT NOT NULL,
                    run_id TEXT,
                    created_at TEXT NOT NULL,
                    completed_at TEXT
                );
                """
            )
            self._migrate(self._connection)
        return self._connection

    def _migrate(self, connection: sqlite3.Connection) -> None:
        try:
            connection.execute(
                "ALTER TABLE agent_runs ADD COLUMN triggered_by TEXT NOT NULL DEFAULT 'user'"
            )
            connection.commit()
        except sqlite3.OperationalError:
            pass
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS research_jobs (
                id TEXT PRIMARY KEY,
                topic TEXT NOT NULL,
                context TEXT NOT NULL,
                status TEXT NOT NULL,
                summary TEXT,
                sources_json TEXT NOT NULL,
                run_id TEXT,
                created_at TEXT NOT NULL,
                completed_at TEXT
            )
            """
        )
        connection.commit()

    def create_run(
        self,
        objective: str,
        context: str,
        triggered_by: str = "user",
    ) -> str:
        run_id = str(uuid4())
        now = _now()
        with self._lock:
            connection = self._connect()
            connection.execute(
                "INSERT INTO agent_runs VALUES (?, ?, ?, ?, ?, ?, ?)",
                (run_id, objective, context, triggered_by, "running", now, now),
            )
            connection.commit()
        return run_id

    def get_run(self, run_id: str) -> dict[str, Any] | None:
        with self._lock:
            row = (
                self._connect()
                .execute("SELECT * FROM agent_runs WHERE id = ?", (run_id,))
                .fetchone()
            )
        if row is None:
            return None
        return self._run_dict(row)

    def list_audit_events(self, run_id: str, limit: int = 5) -> list[dict[str, Any]]:
        with self._lock:
            rows = (
                self._connect()
                .execute(
                    """
                    SELECT event_type, detail_json, created_at
                    FROM audit_events
                    WHERE run_id = ?
                    ORDER BY created_at ASC
                    LIMIT ?
                    """,
                    (run_id, limit),
                )
                .fetchall()
            )
        return [
            {
                "event_type": row["event_type"],
                "detail": json.loads(row["detail_json"]),
                "created_at": row["created_at"],
            }
            for row in rows
        ]

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
        return self._enrich_approval(row)

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
        return [self._enrich_approval(row) for row in rows]

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

    def _enrich_approval(self, row: sqlite3.Row) -> dict[str, Any]:
        approval = self._approval_dict(row)
        run = self.get_run(approval["run_id"])
        if run is None:
            approval["triggered_by"] = "user"
            approval["run_objective"] = ""
            approval["run_context"] = "personal"
        else:
            approval["triggered_by"] = run.get("triggered_by", "user")
            approval["run_objective"] = run["objective"]
            approval["run_context"] = run["context"]
        approval["audit_events"] = self.list_audit_events(approval["run_id"])
        return approval

    @staticmethod
    def _run_dict(row: sqlite3.Row) -> dict[str, Any]:
        return {
            "id": row["id"],
            "objective": row["objective"],
            "context": row["context"],
            "triggered_by": row["triggered_by"] if "triggered_by" in row.keys() else "user",
            "status": row["status"],
            "created_at": row["created_at"],
            "updated_at": row["updated_at"],
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

    def create_memory(self, content: str, category: str, source: str) -> dict[str, Any]:
        memory_id = str(uuid4())
        now = _now()
        with self._lock:
            connection = self._connect()
            connection.execute(
                "INSERT INTO memories VALUES (?, ?, ?, ?, ?, ?)",
                (memory_id, content, category, source, now, now),
            )
            connection.commit()
        return self.get_memory(memory_id)

    def get_memory(self, memory_id: str) -> dict[str, Any]:
        with self._lock:
            row = (
                self._connect()
                .execute("SELECT * FROM memories WHERE id = ?", (memory_id,))
                .fetchone()
            )
        if row is None:
            raise KeyError(memory_id)
        return self._memory_dict(row)

    def list_memories(self) -> list[dict[str, Any]]:
        with self._lock:
            rows = (
                self._connect()
                .execute("SELECT * FROM memories ORDER BY updated_at DESC")
                .fetchall()
            )
        return [self._memory_dict(row) for row in rows]

    def update_memory(
        self,
        memory_id: str,
        *,
        content: str | None = None,
        category: str | None = None,
    ) -> dict[str, Any]:
        if content is None and category is None:
            raise ValueError("At least one field must be updated")
        with self._lock:
            connection = self._connect()
            row = connection.execute(
                "SELECT * FROM memories WHERE id = ?",
                (memory_id,),
            ).fetchone()
            if row is None:
                raise KeyError(memory_id)
            updated_content = content if content is not None else row["content"]
            updated_category = category if category is not None else row["category"]
            connection.execute(
                """
                UPDATE memories
                SET content = ?, category = ?, updated_at = ?
                WHERE id = ?
                """,
                (updated_content, updated_category, _now(), memory_id),
            )
            connection.commit()
        return self.get_memory(memory_id)

    def delete_memory(self, memory_id: str) -> None:
        with self._lock:
            connection = self._connect()
            cursor = connection.execute("DELETE FROM memories WHERE id = ?", (memory_id,))
            connection.commit()
        if cursor.rowcount != 1:
            raise KeyError(memory_id)

    @staticmethod
    def _memory_dict(row: sqlite3.Row) -> dict[str, Any]:
        return {
            "id": row["id"],
            "content": row["content"],
            "category": row["category"],
            "source": row["source"],
            "created_at": row["created_at"],
            "updated_at": row["updated_at"],
        }

    def create_research_job(self, topic: str, context: str) -> dict[str, Any]:
        job_id = str(uuid4())
        now = _now()
        with self._lock:
            connection = self._connect()
            connection.execute(
                """
                INSERT INTO research_jobs
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (job_id, topic, context, "running", None, "[]", None, now, None),
            )
            connection.commit()
        return self.get_research_job(job_id)

    def get_research_job(self, job_id: str) -> dict[str, Any]:
        with self._lock:
            row = (
                self._connect()
                .execute("SELECT * FROM research_jobs WHERE id = ?", (job_id,))
                .fetchone()
            )
        if row is None:
            raise KeyError(job_id)
        return self._research_job_dict(row)

    def list_research_jobs(self) -> list[dict[str, Any]]:
        with self._lock:
            rows = (
                self._connect()
                .execute("SELECT * FROM research_jobs ORDER BY created_at DESC")
                .fetchall()
            )
        return [self._research_job_dict(row) for row in rows]

    def update_research_job(
        self,
        job_id: str,
        *,
        status: str | None = None,
        summary: str | None = None,
        sources: list[dict[str, Any]] | None = None,
        run_id: str | None = None,
    ) -> dict[str, Any]:
        with self._lock:
            connection = self._connect()
            row = connection.execute(
                "SELECT * FROM research_jobs WHERE id = ?",
                (job_id,),
            ).fetchone()
            if row is None:
                raise KeyError(job_id)
            updated_status = status if status is not None else row["status"]
            updated_summary = summary if summary is not None else row["summary"]
            updated_sources = (
                json.dumps(sources)
                if sources is not None
                else row["sources_json"]
            )
            updated_run_id = run_id if run_id is not None else row["run_id"]
            completed_at = row["completed_at"]
            if status is not None and status != "running":
                completed_at = _now()
            connection.execute(
                """
                UPDATE research_jobs
                SET status = ?, summary = ?, sources_json = ?, run_id = ?, completed_at = ?
                WHERE id = ?
                """,
                (
                    updated_status,
                    updated_summary,
                    updated_sources,
                    updated_run_id,
                    completed_at,
                    job_id,
                ),
            )
            connection.commit()
        return self.get_research_job(job_id)

    @staticmethod
    def _research_job_dict(row: sqlite3.Row) -> dict[str, Any]:
        return {
            "id": row["id"],
            "topic": row["topic"],
            "context": row["context"],
            "status": row["status"],
            "summary": row["summary"],
            "sources": json.loads(row["sources_json"]),
            "run_id": row["run_id"],
            "created_at": row["created_at"],
            "completed_at": row["completed_at"],
        }
