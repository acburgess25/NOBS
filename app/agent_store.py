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
