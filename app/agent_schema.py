"""SQLite schema for the Tank agent store.

The 14 tables the Tank keeps on disk, plus the column additions needed by a
database that was created before a table grew a field. `CREATE TABLE IF NOT
EXISTS` is a no-op against an existing table, so a Tank that has been running
since before a column shipped needs `ADDED_COLUMNS` to reach the current
shape -- that is the whole migration story, and it belongs next to the DDL
rather than buried in the middle of the store's query methods.
"""

from __future__ import annotations

import sqlite3

SCHEMA_SQL = """
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
        created_at TEXT NOT NULL,
        end_time TEXT,
        location TEXT
    );
    CREATE TABLE IF NOT EXISTS reminders (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        context TEXT NOT NULL,
        created_at TEXT NOT NULL,
        due_at TEXT
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

# Columns added after a table first shipped. `CREATE TABLE IF NOT EXISTS`
# does nothing to a table that already exists, so an existing Tank database
# would keep the old shape and fail at query time. Every entry here must be
# nullable or carry a default, because SQLite cannot add a NOT NULL column
# without one to a populated table.
ADDED_COLUMNS: tuple[tuple[str, str, str], ...] = (
    ("calendar_events", "end_time", "TEXT"),
    ("calendar_events", "location", "TEXT"),
    ("reminders", "due_at", "TEXT"),
)


def apply_migrations(connection: sqlite3.Connection) -> None:
    """Add any columns missing from a database created by an older build."""
    tables = {table for table, _, _ in ADDED_COLUMNS}
    existing = {
        table: {row["name"] for row in connection.execute(f"PRAGMA table_info({table})")}
        for table in tables
    }
    for table, column, declaration in ADDED_COLUMNS:
        if column not in existing[table]:
            connection.execute(f"ALTER TABLE {table} ADD COLUMN {column} {declaration}")
    connection.commit()
