from __future__ import annotations

from typing import Any

import httpx

from app.agent_store import AgentStore
from app.config import Settings


async def dependency_status(
    settings: Settings,
    store: AgentStore,
    transport: httpx.AsyncBaseTransport | None = None,
) -> dict[str, Any]:
    """Probe SQLite and Ollama for the authenticated /ready endpoint."""
    checks: dict[str, Any] = {"database": "unknown", "ollama": "unknown", "model": settings.ollama_model}

    try:
        store.dashboard_metrics()
        checks["database"] = "ok"
    except Exception as error:  # noqa: BLE001 — surface dependency failure to caller
        checks["database"] = f"error: {error}"

    try:
        async with httpx.AsyncClient(timeout=3.0, transport=transport) as client:
            response = await client.get(f"{settings.ollama_base_url}/api/tags")
            response.raise_for_status()
            models = [item.get("name", "") for item in response.json().get("models", [])]
        wanted = settings.ollama_model
        available = wanted in models or any(model.startswith(f"{wanted}:") for model in models)
        checks["ollama"] = "ok" if available else "model_missing"
    except httpx.HTTPError as error:
        checks["ollama"] = f"offline: {error}"

    return checks


def ready_from_checks(checks: dict[str, Any]) -> tuple[bool, str]:
    if checks.get("database") != "ok":
        return False, "database unavailable"
    ollama = str(checks.get("ollama", ""))
    if ollama != "ok":
        return False, ollama or "ollama unavailable"
    return True, "ready"
