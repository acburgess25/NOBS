from __future__ import annotations

import os
import shutil
import subprocess
import time
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import httpx

from app.agent_store import AgentStore
from app.agent_tools import ToolRegistry
from app.config import Settings
from app.networking import tank_pairing_url
from app.tank_optimizer import TankOptimizer


async def build_dashboard_status(
    settings: Settings,
    store: AgentStore,
    tools: ToolRegistry,
    process_started_at: float,
    transport: httpx.AsyncBaseTransport | None = None,
    token_configured: bool = False,
    optimizer: TankOptimizer | None = None,
    pairing_state: dict[str, Any] | None = None,
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
    if agent.get("pending_proposals"):
        count = agent["pending_proposals"]
        attention.append(
            {
                "level": "action",
                "title": f"{count} new idea{'s' if count != 1 else ''} proposed",
                "detail": "Tank has autonomously generated suggestions for your review.",
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

    # Combine approvals and proposals for the frontend metric which expects 'pending_approvals'
    frontend_pending = agent["pending_approvals"] + agent.get("pending_proposals", 0)
    agent_for_frontend = dict(agent)
    agent_for_frontend["pending_approvals"] = frontend_pending

    gpu_status = _gpu_status()
    pairing = _pairing_payload(token_configured, pairing_state)
    optimizer_status = optimizer.status() if optimizer is not None else None
    if optimizer_status and optimizer_status.get("current_job"):
        attention.insert(
            0,
            {
                "level": "clear",
                "title": "Tank optimizer is working",
                "detail": (
                    f"Background {optimizer_status.get('current_kind', 'job')}: "
                    f"{optimizer_status['current_job']}"
                ),
            },
        )
    return {
        "generated_at": datetime.now(UTC).isoformat(),
        "display_name": settings.dashboard_name,
        "system": system,
        "services": {
            "api": {"status": "online", "version": settings.version},
            "ollama": ollama,
        },
        "agent": agent_for_frontend,
        "workspaces": workspaces,
        "attention": attention,
        "privacy": (
            "Room-safe summary only. No conversations, private event details, "
            "or credentials are shown."
        ),
        "gpu": gpu_status,
        "pairing": pairing,
        "optimizer": optimizer_status,
    }


def _pairing_payload(
    token_configured: bool,
    pairing_state: dict[str, Any] | None,
) -> dict[str, Any]:
    """Describe pairing without disclosing the device token.

    This status route is intentionally reachable without a token so the kiosk
    display works, which means everything it returns is readable by anything on
    the LAN. The token therefore lives behind `GET /dashboard/pairing`; only the
    Tank address is published here, and Bonjour already advertises that.
    """
    state = pairing_state or {"open": False, "expires_in_seconds": None}
    return {
        "url": tank_pairing_url(),
        "token_configured": token_configured,
        "pairing_open": bool(state.get("open")),
        "pairing_expires_in_seconds": state.get("expires_in_seconds"),
    }


def _load_average_1m() -> float | None:
    try:
        if hasattr(os, "getloadavg"):
            return round(os.getloadavg()[0], 2)
    except OSError:
        pass
    return None


def _system_status(workspace: Path, process_started_at: float) -> dict[str, Any]:
    disk_path = workspace.parent if workspace.parent.exists() else Path.cwd()
    usage = shutil.disk_usage(disk_path)
    uptime = _host_uptime() or max(0.0, time.time() - process_started_at)
    return {
        "status": "online",
        "uptime_seconds": round(uptime),
        "load_1m": _load_average_1m(),
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


def _gpu_status() -> dict[str, int] | None:
    try:
        result = subprocess.run(
            [
                "nvidia-smi",
                "--query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu",
                "--format=csv,noheader,nounits",
            ],
            timeout=2,
            capture_output=True,
            text=True,
            check=False,  # returncode is inspected below; a missing GPU is not an error
        )
        if result.returncode != 0:
            return None

        values = result.stdout.strip().split(", ")
        if len(values) != 4:
            return None

        utilization_percent, memory_used_mb, memory_total_mb, temperature_c = map(int, values)
        return {
            "utilization_percent": utilization_percent,
            "memory_used_mb": memory_used_mb,
            "memory_total_mb": memory_total_mb,
            "temperature_c": temperature_c,
        }
    except (OSError, subprocess.SubprocessError, ValueError):
        return None
