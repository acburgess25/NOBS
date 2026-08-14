from __future__ import annotations

import datetime
import os
import sqlite3
import uuid
from pathlib import Path


def resolve_db_path() -> Path:
    env_path = os.environ.get("NOBS_AGENT_DB_PATH")
    if env_path:
        return Path(env_path)

    for candidate in (
        Path("data/nobs-agent.db"),
        Path.home() / "nobs" / "data" / "nobs-agent.db",
    ):
        if candidate.exists():
            return candidate
    return Path("data/nobs-agent.db")


def main() -> int:
    db_path = resolve_db_path()
    db_path.parent.mkdir(parents=True, exist_ok=True)

    now_utc = datetime.datetime.now(datetime.UTC)
    target_time = now_utc + datetime.timedelta(minutes=1)
    time_str = target_time.strftime("%H:%M")

    with sqlite3.connect(db_path) as conn:
        schedule_id = str(uuid.uuid4())
        conn.execute(
            "INSERT INTO briefing_schedules VALUES (?, ?, ?, ?)",
            (schedule_id, time_str, "active", now_utc.isoformat()),
        )

        conn.execute("DELETE FROM calendar_events")
        conn.execute(
            "INSERT INTO calendar_events VALUES (?, ?, ?, ?, ?)",
            (
                str(uuid.uuid4()),
                "Launch NOBS Dashboard",
                "10:00",
                "business",
                now_utc.isoformat(),
            ),
        )
        conn.execute(
            "INSERT INTO calendar_events VALUES (?, ?, ?, ?, ?)",
            (
                str(uuid.uuid4()),
                "Review Agent Approvals",
                "14:00",
                "personal",
                now_utc.isoformat(),
            ),
        )

        conn.execute("DELETE FROM reminders")
        conn.execute(
            "INSERT INTO reminders VALUES (?, ?, ?, ?)",
            (
                str(uuid.uuid4()),
                "Check Tank GPU temperatures",
                "business",
                now_utc.isoformat(),
            ),
        )

    print(f"Created active schedule for {time_str} UTC with 2 events and 1 reminder.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
