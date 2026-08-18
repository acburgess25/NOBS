"""Health, dashboard status, optimizer control, and device pairing.

`/health` and `/dashboard/status` are deliberately unauthenticated: the Tank's
own connected display has no token and must still be able to show whether the
Tank is alive. Neither route returns personal content or the device token --
`/dashboard/status` reports only whether a token is configured.

Pairing is the exception in this module. Opening a pairing window is what
grants a new device the token, so those routes are gated on the caller being
physically at the Tank.
"""

from __future__ import annotations

from datetime import UTC, datetime
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import RedirectResponse

from app.dashboard import build_dashboard_status
from app.dependencies import (
    OptimizerDep,
    PairingDep,
    ProcessStartedAtDep,
    SandboxFactoryDep,
    SettingsDep,
    StoreDep,
    ToolsDep,
    TransportDep,
    pairing_secret,
    require_device_token,
    require_local_or_paired_request,
    require_local_request,
    resolve_device_token,
)
from app.schemas import PairingSecretView, PairingStateView
from app.tank_optimizer import _ALL_JOB_TYPES, _HEAVY_JOB_TYPES

router = APIRouter()


@router.get("/health", tags=["operations"])
async def health(settings: SettingsDep) -> dict[str, str]:
    return {
        "status": "ok",
        "service": "nobs-tank-api",
        "environment": settings.environment,
        "version": settings.version,
        "timestamp": datetime.now(UTC).isoformat(),
    }


@router.get("/dashboard", include_in_schema=False)
async def dashboard_redirect() -> RedirectResponse:
    return RedirectResponse(url="/dashboard/assets/index.html")


@router.get("/dashboard/status", tags=["operations"])
async def dashboard_status(
    settings: SettingsDep,
    store: StoreDep,
    tools: ToolsDep,
    started_at: ProcessStartedAtDep,
    transport: TransportDep,
    optimizer: OptimizerDep,
    pairing: PairingDep,
) -> dict[str, object]:
    return await build_dashboard_status(
        settings,
        store,
        tools,
        started_at,
        transport,
        # Never the token itself: this route is deliberately unauthenticated
        # so the kiosk display works without pairing.
        token_configured=resolve_device_token(settings, store) is not None,
        optimizer=optimizer,
        pairing_state=pairing.state(),
    )


@router.get("/tank/optimizer", include_in_schema=False)
async def tank_optimizer_redirect() -> RedirectResponse:
    return RedirectResponse(url="/optimizer/status")


@router.get("/optimizer/status", tags=["operations"])
async def optimizer_status(optimizer: OptimizerDep) -> dict[str, Any]:
    return optimizer.status()


@router.get(
    "/dashboard/pairing",
    response_model=PairingSecretView,
    tags=["operations"],
    dependencies=[Depends(require_local_or_paired_request)],
    summary="Read the device token for display on the Tank",
)
async def dashboard_pairing(
    settings: SettingsDep,
    store: StoreDep,
    pairing: PairingDep,
) -> PairingSecretView:
    return pairing_secret(settings, store, pairing)


@router.post(
    "/dashboard/pairing/open",
    response_model=PairingSecretView,
    tags=["operations"],
    dependencies=[Depends(require_local_request)],
    summary="Open a time-boxed window allowing one new device to pair",
)
async def open_pairing_window(
    settings: SettingsDep,
    store: StoreDep,
    pairing: PairingDep,
) -> PairingSecretView:
    pairing.open()
    return pairing_secret(settings, store, pairing)


@router.post(
    "/dashboard/pairing/close",
    response_model=PairingStateView,
    tags=["operations"],
    dependencies=[Depends(require_local_request)],
)
async def close_pairing_window(pairing: PairingDep) -> PairingStateView:
    pairing.close()
    return PairingStateView.model_validate(pairing.state())


@router.post(
    "/optimizer/run-now", tags=["operations"], dependencies=[Depends(require_device_token)]
)
async def optimizer_run_now(
    settings: SettingsDep,
    store: StoreDep,
    tools: ToolsDep,
    transport: TransportDep,
    optimizer: OptimizerDep,
    sandbox_factory: SandboxFactoryDep,
    job_type: str | None = Query(default=None),
) -> dict[str, Any]:
    from app.tank_optimizer import OptimizerJobKind

    if not settings.optimizer_enabled:
        raise HTTPException(status_code=503, detail="Tank optimizer is disabled")
    if optimizer._current_job is not None:
        raise HTTPException(status_code=409, detail="Optimizer is already running a job")
    selected = job_type or _HEAVY_JOB_TYPES[optimizer._heavy_rotation % len(_HEAVY_JOB_TYPES)]
    if selected not in _ALL_JOB_TYPES:
        raise HTTPException(status_code=400, detail=f"Unknown job type: {selected}")
    kind = OptimizerJobKind.heavy if selected in _HEAVY_JOB_TYPES else OptimizerJobKind.light
    result = await optimizer._execute_job(
        selected,
        kind,
        settings,
        store,
        tools,
        transport,
        sandbox_factory,
    )
    return result.__dict__


@router.get(
    "/ready",
    tags=["operations"],
    dependencies=[Depends(require_device_token)],
)
async def ready() -> dict[str, str]:
    return {"status": "ready"}
