from __future__ import annotations

from datetime import UTC, datetime
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
            row = self._connect().execute(
                "SELECT * FROM approvals WHERE id = ?",
                (approval_id,),
            ).fetchone()
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
