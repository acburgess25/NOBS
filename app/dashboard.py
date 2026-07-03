from __future__ import annotations

from datetime import UTC, datetime
import os
from pathlib import Path
import shutil
import time
from typing import Any

import httpx

from app.agent_store import AgentStore
from app.agent_tools import ToolRegistry
from app.config import Settings


async def build_dashboard_status(
    settings: Settings,
    store: AgentStore,
    tools: ToolRegistry,
    process_started_at: float,
    transport: httpx.AsyncBaseTransport | None = None,
) -> dict[str, Any]:
    system = _system_status(settings.agent_workspace_path, process_started_at)
    ollama = await _ollama_status(settings, transport)
    agent = store.dashboard_metrics()
    workspaces = tools.workspace_counts()
    attention: list[dict[str, str]] = []

    if ollama["status"] != "online":
        attention.append(
            {
                "level": "urgent",
                "title": "Local model is offline",
                "detail": "Ollama did not answer the dashboard health check.",
            }
        )
    if agent["pending_approvals"]:
        count = agent["pending_approvals"]
        attention.append(
            {
                "level": "action",
                "title": f"{count} approval{'s' if count != 1 else ''} waiting",
                "detail": "Review these privately on your authenticated NOBS device.",
            }
        )
    if system["disk_used_percent"] >= 85:
        attention.append(
            {
                "level": "urgent",
                "title": "Storage needs attention",
                "detail": f"Tank storage is {system['disk_used_percent']:.0f}% full.",
            }
        )
    if not attention:
        attention.append(
            {
                "level": "clear",
                "title": "Nothing needs your attention",
                "detail": "Tank, Ollama, and the approval queue look healthy.",
            }
        )

    return {
        "generated_at": datetime.now(UTC).isoformat(),
        "display_name": settings.dashboard_name,
        "system": system,
        "services": {
            "api": {"status": "online", "version": settings.version},
            "ollama": ollama,
        },
        "agent": agent,
        "workspaces": workspaces,
        "attention": attention,
        "privacy": "Room-safe summary only. No conversations or private event details are shown.",
    }


def _system_status(workspace: Path, process_started_at: float) -> dict[str, Any]:
    disk_path = workspace.parent if workspace.parent.exists() else Path.cwd()
    usage = shutil.disk_usage(disk_path)
    uptime = _host_uptime() or max(0.0, time.time() - process_started_at)
    return {
        "status": "online",
        "uptime_seconds": round(uptime),
        "load_1m": round(os.getloadavg()[0], 2) if hasattr(os, "getloadavg") else None,
        "disk_free_gb": round(usage.free / (1024**3), 1),
        "disk_used_percent": round((usage.used / usage.total) * 100, 1),
    }


def _host_uptime() -> float | None:
    try:
        return float(Path("/proc/uptime").read_text(encoding="utf-8").split()[0])
    except (OSError, ValueError, IndexError):
        return None


async def _ollama_status(
    settings: Settings,
    transport: httpx.AsyncBaseTransport | None = None,
) -> dict[str, str]:
    try:
        async with httpx.AsyncClient(timeout=2.5, transport=transport) as client:
            response = await client.get(f"{settings.ollama_base_url}/api/tags")
            response.raise_for_status()
            models = [item.get("name", "") for item in response.json().get("models", [])]
        wanted = settings.ollama_model
        available = wanted in models or any(model.startswith(f"{wanted}:") for model in models)
        return {"status": "online" if available else "model_missing", "model": wanted}
    except (httpx.HTTPError, ValueError):
        return {"status": "offline", "model": settings.ollama_model}
