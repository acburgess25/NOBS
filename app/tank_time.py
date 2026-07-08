from __future__ import annotations

from datetime import UTC, datetime
from zoneinfo import ZoneInfo


def local_now(timezone: str) -> datetime:
    """Current wall-clock time in the configured Tank timezone."""
    return datetime.now(ZoneInfo(timezone))


def local_time_label(timezone: str) -> str:
    """HH:MM in local Tank time for schedule matching."""
    return local_now(timezone).strftime("%H:%M")


def utc_now() -> datetime:
    return datetime.now(UTC)
