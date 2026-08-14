"""Background Tank optimizer — keeps Tank working on useful local jobs when idle.

Runs light maintenance between heavier optimization bursts. Yields immediately
when user-facing API traffic or elevated CPU load is detected.
"""

from __future__ import annotations

import asyncio
import json
import logging
import time
from collections.abc import Callable, Coroutine
from dataclasses import dataclass, field
from datetime import UTC, datetime
from enum import Enum
from pathlib import Path
from typing import Any

import httpx
import psutil

from app.agent_store import AgentStore
from app.agent_tools import ToolRegistry
from app.config import Settings
from app.dream_team import DreamTeamModelError, DreamTeamSandbox
from app.scheduler import trigger_briefing_generation

logger = logging.getLogger(__name__)

_USER_FACING_PREFIXES = (
    "/chat",
    "/agent",
    "/briefing",
    "/dream-team",
    "/workplace/browser",
    "/sync",
    "/overnight",
    "/schedules",
    "/ready",
    "/auth",
)

_LIGHT_JOB_TYPES = ("briefing_index_light", "model_ping", "dream_team_scoring")
_HEAVY_JOB_TYPES = ("dream_team_batch", "briefing_index_refresh", "model_warmup")
_ALL_JOB_TYPES = _LIGHT_JOB_TYPES + _HEAVY_JOB_TYPES

_INTENSITY_SCALE = {
    "light": 1.5,
    "normal": 1.0,
    "heavy": 0.75,
}


class OptimizerJobKind(str, Enum):
    light = "light"
    heavy = "heavy"


@dataclass
class OptimizerJobResult:
    job_type: str
    kind: OptimizerJobKind
    started_at: str
    completed_at: str
    success: bool
    summary: str
    details: dict[str, Any] = field(default_factory=dict)


class TankOptimizer:
    """Tracks idle state, schedules background jobs, and exposes status."""

    def __init__(self, settings: Settings) -> None:
        self.settings = settings
        self._last_api_activity = time.perf_counter()
        self._current_job: str | None = None
        self._current_kind: OptimizerJobKind | None = None
        self._running_count = 0
        self._last_result: OptimizerJobResult | None = None
        self._history: list[OptimizerJobResult] = []
        self._last_heavy_finished_at: float | None = None
        self._next_heavy_at: float | None = None
        self._heavy_rotation = 0
        self._run_now_event = asyncio.Event()
        self._run_now_job: str | None = None
        self._started_at = time.monotonic()
        self._loop_task: asyncio.Task[None] | None = None

    def record_api_activity(self, path: str) -> None:
        if not _is_user_facing_path(path):
            return
        self._last_api_activity = time.perf_counter()

    def _intensity_scale(self) -> float:
        return _INTENSITY_SCALE.get(self.settings.optimizer_intensity.lower(), 1.0)

    def _scaled_light_interval(self) -> float:
        return self.settings.optimizer_light_interval_seconds * self._intensity_scale()

    def _scaled_heavy_interval(self) -> float:
        return self.settings.optimizer_heavy_interval_minutes * 60 * self._intensity_scale()

    def _scaled_min_idle(self) -> float:
        return self.settings.optimizer_min_idle_seconds * self._intensity_scale()

    def seconds_since_api_activity(self) -> float:
        return time.perf_counter() - self._last_api_activity

    def cpu_percent(self) -> float | None:
        try:
            return psutil.cpu_percent(interval=0.2)
        except OSError:
            return None

    def is_idle(self) -> bool:
        if self.seconds_since_api_activity() < self._scaled_min_idle():
            return False
        cpu = self.cpu_percent()
        if cpu is None:
            return True
        return cpu <= self.settings.optimizer_idle_cpu_percent

    def can_start_job(self) -> bool:
        return (
            self.settings.optimizer_enabled
            and self.is_idle()
            and self._running_count < self.settings.optimizer_max_concurrent
            and self._current_job is None
        )

    def _schedule_next_heavy(self) -> None:
        self._next_heavy_at = time.monotonic() + self._scaled_heavy_interval()

    def _next_heavy_job_type(self) -> str:
        job = _HEAVY_JOB_TYPES[self._heavy_rotation % len(_HEAVY_JOB_TYPES)]
        self._heavy_rotation += 1
        return job

    def _next_light_job_type(self) -> str:
        index = int(time.monotonic() // self._scaled_light_interval()) % len(_LIGHT_JOB_TYPES)
        return _LIGHT_JOB_TYPES[index]

    async def run_job_now(self, job_type: str | None = None) -> OptimizerJobResult | None:
        if job_type is not None and job_type not in _ALL_JOB_TYPES:
            raise ValueError(f"Unknown optimizer job type: {job_type}")
        if self._current_job is not None:
            raise RuntimeError("Optimizer is already running a job")
        self._run_now_job = job_type
        self._run_now_event.set()
        for _ in range(200):
            if (
                self._last_result
                and self._last_result.job_type == (job_type or self._last_result.job_type)
                and self._last_result.completed_at
            ):
                return self._last_result
            await asyncio.sleep(0.05)
        return self._last_result

    def status(self) -> dict[str, Any]:
        idle = self.is_idle()
        cpu = self.cpu_percent()
        next_heavy_in: float | None = None
        if self._next_heavy_at is not None:
            next_heavy_in = max(0.0, self._next_heavy_at - time.monotonic())

        return {
            "enabled": self.settings.optimizer_enabled,
            "idle": idle,
            "current_job": self._current_job,
            "current_kind": self._current_kind.value if self._current_kind else None,
            "running_count": self._running_count,
            "max_concurrent": self.settings.optimizer_max_concurrent,
            "intensity": self.settings.optimizer_intensity,
            "seconds_since_api_activity": round(self.seconds_since_api_activity(), 1),
            "min_idle_seconds": self.settings.optimizer_min_idle_seconds,
            "cpu_percent": cpu,
            "idle_cpu_threshold": self.settings.optimizer_idle_cpu_percent,
            "heavy_interval_minutes": self.settings.optimizer_heavy_interval_minutes,
            "light_interval_seconds": self.settings.optimizer_light_interval_seconds,
            "next_heavy_job_in_seconds": round(next_heavy_in, 1) if next_heavy_in is not None else None,
            "next_heavy_job_type": _HEAVY_JOB_TYPES[self._heavy_rotation % len(_HEAVY_JOB_TYPES)],
            "last_job": self._last_result.__dict__ if self._last_result else None,
            "recent_jobs": [item.__dict__ for item in self._history[-8:]],
            "job_types": {
                "light": list(_LIGHT_JOB_TYPES),
                "heavy": list(_HEAVY_JOB_TYPES),
            },
            "uptime_seconds": round(time.monotonic() - self._started_at),
        }

    async def _execute_job(
        self,
        job_type: str,
        kind: OptimizerJobKind,
        settings: Settings,
        store: AgentStore,
        tools: ToolRegistry,
        transport: Any,
        dream_team_factory: Callable[[], DreamTeamSandbox],
    ) -> OptimizerJobResult:
        started = datetime.now(UTC).isoformat()
        started_monotonic = time.monotonic()
        self._current_job = job_type
        self._current_kind = kind
        self._running_count += 1

        handlers: dict[str, Callable[[], Coroutine[Any, Any, dict[str, Any]]]] = {
            "briefing_index_light": lambda: job_briefing_index_light(store),
            "model_ping": lambda: job_model_ping(settings, transport),
            "dream_team_scoring": lambda: job_dream_team_scoring(settings, store, dream_team_factory()),
            "briefing_index_refresh": lambda: job_briefing_index_refresh(settings, store, transport),
            "dream_team_batch": lambda: job_dream_team_batch(settings, store, dream_team_factory()),
            "model_warmup": lambda: job_model_warmup(settings, transport),
        }

        success = False
        summary = "unknown job"
        details: dict[str, Any] = {}
        try:
            details = await handlers[job_type]()
            success = True
            summary = details.get("summary", f"Completed {job_type}")
        except Exception as error:
            logger.exception("Optimizer job %s failed", job_type)
            summary = str(error)
            details = {"error": str(error)}

        completed = datetime.now(UTC).isoformat()
        result = OptimizerJobResult(
            job_type=job_type,
            kind=kind,
            started_at=started,
            completed_at=completed,
            success=success,
            summary=summary,
            details=details,
        )
        self._last_result = result
        self._history.append(result)
        self._history = self._history[-32:]
        if kind == OptimizerJobKind.heavy:
            self._last_heavy_finished_at = started_monotonic
            self._schedule_next_heavy()
        self._current_job = None
        self._current_kind = None
        self._running_count = max(0, self._running_count - 1)
        return result

    async def optimizer_loop(
        self,
        settings: Settings,
        store: AgentStore,
        tools: ToolRegistry,
        transport: Any,
        dream_team_factory: Callable[[], DreamTeamSandbox],
    ) -> None:
        self._schedule_next_heavy()
        tick = 0.0
        while True:
            try:
                manual_job = self._run_now_job
                if self._run_now_event.is_set():
                    self._run_now_event.clear()
                    job_type = manual_job or self._next_heavy_job_type()
                    self._run_now_job = None
                    await self._execute_job(
                        job_type,
                        OptimizerJobKind.heavy if job_type in _HEAVY_JOB_TYPES else OptimizerJobKind.light,
                        settings,
                        store,
                        tools,
                        transport,
                        dream_team_factory,
                    )
                elif self.can_start_job():
                    now = time.monotonic()
                    due_heavy = (
                        self._next_heavy_at is not None
                        and now >= self._next_heavy_at
                    )
                    if due_heavy:
                        await self._execute_job(
                            self._next_heavy_job_type(),
                            OptimizerJobKind.heavy,
                            settings,
                            store,
                            tools,
                            transport,
                            dream_team_factory,
                        )
                    elif tick >= self._scaled_light_interval():
                        tick = 0.0
                        await self._execute_job(
                            self._next_light_job_type(),
                            OptimizerJobKind.light,
                            settings,
                            store,
                            tools,
                            transport,
                            dream_team_factory,
                        )
                tick += 5.0
            except asyncio.CancelledError:
                raise
            except Exception:
                logger.exception("Optimizer loop error")
            await asyncio.sleep(5)


def _is_user_facing_path(path: str) -> bool:
    return any(path.startswith(prefix) for prefix in _USER_FACING_PREFIXES)


async def job_briefing_index_light(store: AgentStore) -> dict[str, Any]:
    """Light pass: refresh in-memory index metadata from synced calendar/reminder rows."""
    calendar = store.list_calendar_events()
    reminders = store.list_reminders()
    latest = store.latest_briefing()
    index = {
        "calendar_count": len(calendar),
        "reminder_count": len(reminders),
        "latest_briefing_date": latest.get("date") if latest else None,
        "latest_briefing_generated_at": latest.get("generated_at") if latest else None,
        "refreshed_at": datetime.now(UTC).isoformat(),
    }
    store.set_kv("optimizer_briefing_index", json.dumps(index))
    return {
        "summary": (
            f"Indexed {len(calendar)} calendar and {len(reminders)} reminder items"
        ),
        "index": index,
    }


async def job_briefing_index_refresh(
    settings: Settings,
    store: AgentStore,
    transport: Any,
) -> dict[str, Any]:
    """Heavy pass: rebuild briefing from synced data when calendar exists."""
    calendar = store.list_calendar_events()
    reminders = store.list_reminders()
    if not calendar and not reminders:
        return await job_briefing_index_light(store)

    await trigger_briefing_generation(settings, store, transport)
    latest = store.latest_briefing()
    return {
        "summary": "Regenerated briefing from synced calendar and reminder data",
        "briefing_date": latest.get("date") if latest else None,
        "calendar_count": len(calendar),
        "reminder_count": len(reminders),
    }


async def job_model_ping(settings: Settings, transport: Any) -> dict[str, Any]:
    """Light pass: verify Ollama is reachable and the configured model is listed."""
    async with httpx.AsyncClient(timeout=5.0, transport=transport) as client:
        response = await client.get(f"{settings.ollama_base_url}/api/tags")
        response.raise_for_status()
        models = [item.get("name", "") for item in response.json().get("models", [])]
    wanted = settings.ollama_model
    available = wanted in models or any(model.startswith(f"{wanted}:") for model in models)
    store_note = {
        "checked_at": datetime.now(UTC).isoformat(),
        "model": wanted,
        "available": available,
        "model_count": len(models),
    }
    return {
        "summary": f"Model {'available' if available else 'missing'}: {wanted}",
        "ping": store_note,
    }


async def job_model_warmup(settings: Settings, transport: Any) -> dict[str, Any]:
    """Heavy pass: warm the chat model with a tiny self-test prompt."""
    payload = {
        "model": settings.ollama_model,
        "stream": False,
        "think": False,
        "messages": [
            {
                "role": "user",
                "content": (
                    "Reply with JSON only: {\"status\":\"ok\",\"service\":\"nobs-tank\"}"
                ),
            }
        ],
        "format": "json",
    }
    started = time.monotonic()
    async with httpx.AsyncClient(
        timeout=settings.ollama_timeout_seconds,
        transport=transport,
    ) as client:
        response = await client.post(f"{settings.ollama_base_url}/api/chat", json=payload)
        response.raise_for_status()
    elapsed_ms = round((time.monotonic() - started) * 1000)
    content = response.json().get("message", {}).get("content", "")
    parsed = json.loads(content)
    ok = parsed.get("status") == "ok"
    return {
        "summary": f"Model warm-up {'passed' if ok else 'failed'} in {elapsed_ms}ms",
        "latency_ms": elapsed_ms,
        "response": parsed,
    }


def _load_active_manifests(active_root: Path) -> list[dict[str, Any]]:
    if not active_root.exists():
        return []
    manifests: list[dict[str, Any]] = []
    for path in sorted(active_root.glob("*.json")):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
            if isinstance(data, dict):
                data["_path"] = str(path)
                manifests.append(data)
        except (OSError, json.JSONDecodeError):
            continue
    return manifests


async def job_dream_team_scoring(
    settings: Settings,
    store: AgentStore,
    sandbox: DreamTeamSandbox,
) -> dict[str, Any]:
    """Light pass: heuristic persona scores for approved active manifests."""
    manifests = _load_active_manifests(settings.dream_team_active_path)
    scores: list[dict[str, Any]] = []
    for manifest in manifests[: settings.optimizer_dream_team_batch_size]:
        draft = {
            "persona": manifest.get("persona") or {},
            "test_result": {"response": manifest.get("role", "")},
        }
        score = sandbox._heuristic_score(draft)
        scores.append(
            {
                "name": manifest.get("name"),
                "role": manifest.get("role"),
                "score": score,
                "path": manifest.get("_path"),
            }
        )
    payload = {
        "scored_at": datetime.now(UTC).isoformat(),
        "manifest_count": len(manifests),
        "scores": scores,
    }
    store.set_kv("optimizer_dream_team_scores", json.dumps(payload))
    avg = sum(item["score"] for item in scores) / len(scores) if scores else 0.0
    return {
        "summary": f"Scored {len(scores)} active dream-team manifest(s); avg {avg:.0%}",
        "scores": scores,
    }


async def job_dream_team_batch(
    settings: Settings,
    store: AgentStore,
    sandbox: DreamTeamSandbox,
) -> dict[str, Any]:
    """Heavy pass: run one local dream-team refinement session when enabled."""
    if not settings.dream_team_enabled:
        return await job_dream_team_scoring(settings, store, sandbox)

    queued = [
        session
        for session in store.list_dream_team_sessions(status="queued")
        if session.get("config", {}).get("optimizer_background")
    ]
    if queued:
        session_id = queued[0]["id"]
        action = "resumed queued background session"
    else:
        manifests = _load_active_manifests(settings.dream_team_active_path)
        objective = (
            f"Background refinement for {manifests[0]['name']}"
            if manifests
            else "Background persona refinement and sandbox scoring"
        )
        session = store.create_dream_team_session(
            objective=objective,
            context="personal",
            config={
                "optimizer_background": True,
                "local_first_policy": sandbox.policy.as_dict(),
                "model": sandbox.model,
                "max_agents": min(2, settings.dream_team_max_agents),
                "max_iterations": 1,
            },
        )
        session_id = session["id"]
        action = "created background refinement session"

    try:
        finished = await sandbox.run_session(session_id)
    except (DreamTeamModelError, ValueError, OSError) as error:
        return {
            "summary": f"Dream team batch stopped: {error}",
            "session_id": session_id,
            "action": action,
        }

    drafts = finished.get("drafts") or []
    return {
        "summary": (
            f"Dream team batch {action}; session {finished.get('status')} "
            f"with {len(drafts)} draft(s)"
        ),
        "session_id": session_id,
        "status": finished.get("status"),
        "draft_count": len(drafts),
    }


async def run_optimizer_loop(
    optimizer: TankOptimizer,
    settings: Settings,
    store: AgentStore,
    tools: ToolRegistry,
    transport: Any,
    dream_team_factory: Callable[[], DreamTeamSandbox],
) -> None:
    if not settings.optimizer_enabled:
        logger.info("Tank optimizer is disabled (NOBS_OPTIMIZER_ENABLED=false).")
        while True:
            await asyncio.sleep(60)
    else:
        logger.info(
            "Tank optimizer started (heavy every %s min when idle ≥ %s s).",
            settings.optimizer_heavy_interval_minutes,
            settings.optimizer_min_idle_seconds,
        )
        await optimizer.optimizer_loop(settings, store, tools, transport, dream_team_factory)
