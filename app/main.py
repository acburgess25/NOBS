import asyncio
import secrets
import time
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import httpx
from fastapi import Depends, FastAPI, Header, HTTPException, Query, Request, status
from fastapi.responses import RedirectResponse, Response
from fastapi.staticfiles import StaticFiles

from app.agent import (
    AgentModelError,
    AgentTaskRequest,
    AgentTaskResponse,
    ApprovalDecision,
    ApprovalView,
    TankAgent,
)
from app.agent_store import AgentStore
from app.agent_tools import ToolRegistry
from app.bonjour import TankBonjourAdvertisement
from app.briefing import (
    BriefingError,
    BriefingModelUnavailable,
    BriefingRequest,
    BriefingResponse,
    OllamaResponse,
    PrivacyReceipt,
    generate_briefing,
)
from app.config import Settings, get_settings
from app.dashboard import build_dashboard_status
from app.dream_team import DreamTeamModelError, DreamTeamSandbox, LocalFirstPolicy
from app.home_assistant import HomeAssistantClient
from app.networking import tank_pairing_url
from app.pairing import PairingWindow, is_loopback_client
from app.scheduler import run_scheduler
from app.schemas import (
    AppleAuthRequest,
    AppleAuthResponse,
    ChatRequest,
    ChatResponse,
    CreateScheduleRequest,
    DreamTeamApproveResponse,
    DreamTeamProposalDecision,
    DreamTeamProposalView,
    DreamTeamSessionCreateRequest,
    DreamTeamSessionView,
    OvernightTaskCreateRequest,
    OvernightTaskView,
    PairingSecretView,
    PairingStateView,
    ProposalDecision,
    ProposalView,
    ScheduleView,
    SyncCalendarRequest,
    SyncRemindersRequest,
    UpdateScheduleRequest,
    WorkplaceBrowserSessionRequest,
)
from app.tank_optimizer import (
    _ALL_JOB_TYPES,
    _HEAVY_JOB_TYPES,
    TankOptimizer,
    run_optimizer_loop,
)
from app.workplace import (
    BrowserSandbox,
    BrowserSandboxError,
    build_workplace_status,
    parse_allowed_domains,
)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    settings = get_settings()
    optimizer: TankOptimizer = app.state.optimizer
    bonjour = TankBonjourAdvertisement(
        name=f"NOBS {settings.dashboard_name}",
        address=settings.advertised_address,
    )
    # zeroconf's synchronous registration waits on its own event loop; keep it
    # off FastAPI's lifespan loop so an mDNS fault can never prevent the API
    # from starting.
    await asyncio.to_thread(bonjour.start)

    def dream_team_factory() -> DreamTeamSandbox:
        return DreamTeamSandbox(
            settings=settings,
            store=app.state.agent_store,
            tools=app.state.agent_tools,
            transport=getattr(app.state, "ollama_transport", None),
            browser_sandbox=app.state.workplace_browser,
        )

    scheduler_task = asyncio.create_task(
        run_scheduler(
            settings,
            app.state.agent_store,
            app.state.agent_tools,
            getattr(app.state, "ollama_transport", None),
        )
    )
    optimizer_task = asyncio.create_task(
        run_optimizer_loop(
            optimizer,
            settings,
            app.state.agent_store,
            app.state.agent_tools,
            getattr(app.state, "ollama_transport", None),
            dream_team_factory,
        )
    )
    yield
    scheduler_task.cancel()
    optimizer_task.cancel()
    await asyncio.to_thread(bonjour.close)


def create_app(settings: Settings | None = None) -> FastAPI:
    settings = settings or get_settings()
    app = FastAPI(
        title="NOBS Tank API",
        version=settings.version,
        lifespan=lifespan,
    )
    app.state.agent_store = AgentStore(settings.agent_database_path)
    app.state.optimizer = TankOptimizer(settings)
    app.state.pairing_window = PairingWindow(settings.pairing_window_seconds)
    app.state.home_assistant = HomeAssistantClient(
        settings.homeassistant_url,
        settings.homeassistant_token,
    )
    app.state.agent_tools = ToolRegistry(
        settings.agent_workspace_path,
        settings.agent_project_path,
        app.state.home_assistant,
        app.state.agent_store,
        settings,
    )
    app.state.process_started_at = time.time()
    dashboard_directory = Path(__file__).resolve().parents[1] / "dashboard"
    workplace_directory = Path(__file__).resolve().parents[1] / "workplace"
    app.mount(
        "/dashboard/assets",
        StaticFiles(directory=dashboard_directory),
        name="dashboard-assets",
    )
    app.mount(
        "/workplace/assets",
        StaticFiles(directory=workplace_directory),
        name="workplace-assets",
    )
    app.state.workplace_browser = BrowserSandbox(
        allowed_domains=parse_allowed_domains(settings.workplace_browser_allowed_domains),
        transport=getattr(app.state, "ollama_transport", None),
        screenshot_dir=settings.browser_sandbox_screenshot_path,
        session_ttl_seconds=settings.browser_sandbox_session_ttl_seconds,
    )

    @app.middleware("http")
    async def optimizer_activity_middleware(request, call_next):
        optimizer: TankOptimizer | None = getattr(app.state, "optimizer", None)
        if optimizer is not None:
            optimizer.record_api_activity(request.url.path)
        return await call_next(request)

    @app.get("/health", tags=["operations"])
    async def health() -> dict[str, str]:
        return {
            "status": "ok",
            "service": "nobs-tank-api",
            "environment": settings.environment,
            "version": settings.version,
            "timestamp": datetime.now(UTC).isoformat(),
        }

    @app.get("/dashboard", include_in_schema=False)
    async def dashboard_redirect() -> RedirectResponse:
        return RedirectResponse(url="/dashboard/assets/index.html")

    @app.get("/dashboard/status", tags=["operations"])
    async def dashboard_status() -> dict[str, object]:
        store: AgentStore = app.state.agent_store
        pairing: PairingWindow = app.state.pairing_window
        return await build_dashboard_status(
            settings,
            store,
            app.state.agent_tools,
            app.state.process_started_at,
            getattr(app.state, "ollama_transport", None),
            # Never the token itself: this route is deliberately unauthenticated
            # so the kiosk display works without pairing.
            token_configured=resolve_device_token(store) is not None,
            optimizer=getattr(app.state, "optimizer", None),
            pairing_state=pairing.state(),
        )

    @app.get("/tank/optimizer", include_in_schema=False)
    async def tank_optimizer_redirect() -> RedirectResponse:
        return RedirectResponse(url="/optimizer/status")

    @app.get("/optimizer/status", tags=["operations"])
    async def optimizer_status() -> dict[str, Any]:
        optimizer: TankOptimizer = app.state.optimizer
        return optimizer.status()

    @app.get("/workplace", include_in_schema=False)
    async def workplace_redirect() -> RedirectResponse:
        return RedirectResponse(url="/workplace/assets/index.html")

    @app.get("/workplace/status", tags=["operations"])
    async def workplace_status() -> dict[str, Any]:
        if not settings.workplace_enabled:
            raise HTTPException(status_code=503, detail="Workplace dashboard is disabled")
        store: AgentStore = app.state.agent_store
        browser: BrowserSandbox = app.state.workplace_browser
        return build_workplace_status(settings, store, browser)

    @app.get(
        "/workplace/browser/sessions/{session_id}/screenshot",
        tags=["workplace"],
    )
    async def workplace_browser_screenshot(session_id: str) -> Response:
        if not settings.workplace_enabled:
            raise HTTPException(status_code=503, detail="Workplace dashboard is disabled")
        browser: BrowserSandbox = app.state.workplace_browser
        try:
            await browser.refresh_session(session_id)
            svg = browser.screenshot_svg(session_id)
        except KeyError as error:
            raise HTTPException(status_code=404, detail="Browser session not found") from error
        return Response(content=svg, media_type="image/svg+xml")

    def resolve_device_token(store: AgentStore) -> str | None:
        configured_token = settings.device_token
        if configured_token is not None:
            configured_value = configured_token.get_secret_value()
            if configured_value:
                return configured_value
        return store.get_kv("device_token")

    async def require_device_token(
        authorization: str | None = Header(default=None),
    ) -> None:
        store: AgentStore = app.state.agent_store
        resolved_token = resolve_device_token(store)
        if not resolved_token:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Tank device authentication is not configured",
            )

        scheme, _, supplied_token = (authorization or "").partition(" ")
        if scheme.lower() != "bearer" or not secrets.compare_digest(
            supplied_token,
            resolved_token,
        ):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid device token",
                headers={"WWW-Authenticate": "Bearer"},
            )

    def require_local_request(request: Request) -> None:
        """Allow only requests that originated on the Tank host itself.

        The peer address is read from the connection, never from a forwarded-for
        header, because those are supplied by the caller. This assumes the API
        port is not published through a reverse proxy — `deploy/tank/` only
        tunnels the marketing site — so a loopback peer really does mean someone
        is at the Tank. Putting a proxy in front of this port would turn every
        remote request into a local one and must not be done.
        """
        if not is_loopback_client(request.client.host if request.client else None):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=(
                    "Pairing can only be managed from the Tank itself. "
                    "Open the NOBS dashboard on the Tank display."
                ),
            )

    async def require_local_or_paired_request(
        request: Request,
        authorization: str | None = Header(default=None),
    ) -> None:
        """Permit the Tank's own display, or an already-paired device.

        A remote caller that offers no credential at all is a locality failure,
        not an authentication failure, so it gets 403 rather than a 401 that
        would invite a credential prompt for a route gated on being at the Tank.
        """
        if is_loopback_client(request.client.host if request.client else None):
            return
        if not authorization:
            require_local_request(request)
        await require_device_token(authorization)

    def pairing_secret() -> PairingSecretView:
        store: AgentStore = app.state.agent_store
        pairing: PairingWindow = app.state.pairing_window
        token = resolve_device_token(store)
        if not token:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Tank device authentication is not configured",
            )
        return PairingSecretView(
            url=tank_pairing_url(),
            token=token,
            **pairing.state(),
        )

    @app.get(
        "/dashboard/pairing",
        response_model=PairingSecretView,
        tags=["operations"],
        dependencies=[Depends(require_local_or_paired_request)],
        summary="Read the device token for display on the Tank",
    )
    async def dashboard_pairing() -> PairingSecretView:
        return pairing_secret()

    @app.post(
        "/dashboard/pairing/open",
        response_model=PairingSecretView,
        tags=["operations"],
        dependencies=[Depends(require_local_request)],
        summary="Open a time-boxed window allowing one new device to pair",
    )
    async def open_pairing_window() -> PairingSecretView:
        app.state.pairing_window.open()
        return pairing_secret()

    @app.post(
        "/dashboard/pairing/close",
        response_model=PairingStateView,
        tags=["operations"],
        dependencies=[Depends(require_local_request)],
    )
    async def close_pairing_window() -> PairingStateView:
        pairing: PairingWindow = app.state.pairing_window
        pairing.close()
        return PairingStateView.model_validate(pairing.state())

    @app.post(
        "/optimizer/run-now", tags=["operations"], dependencies=[Depends(require_device_token)]
    )
    async def optimizer_run_now(
        job_type: str | None = Query(default=None),
    ) -> dict[str, Any]:
        from app.tank_optimizer import OptimizerJobKind

        optimizer: TankOptimizer = app.state.optimizer
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
            app.state.agent_store,
            app.state.agent_tools,
            getattr(app.state, "ollama_transport", None),
            lambda: DreamTeamSandbox(
                settings=settings,
                store=app.state.agent_store,
                tools=app.state.agent_tools,
                transport=getattr(app.state, "ollama_transport", None),
                browser_sandbox=app.state.workplace_browser,
            ),
        )
        return result.__dict__

    @app.get(
        "/ready",
        tags=["operations"],
        dependencies=[Depends(require_device_token)],
    )
    async def ready() -> dict[str, str]:
        return {"status": "ready"}

    @app.post(
        "/workplace/browser/sessions",
        tags=["workplace"],
        dependencies=[Depends(require_device_token)],
    )
    async def create_workplace_browser_session(
        request: WorkplaceBrowserSessionRequest,
    ) -> dict[str, Any]:
        if not settings.workplace_enabled:
            raise HTTPException(status_code=503, detail="Workplace dashboard is disabled")
        browser: BrowserSandbox = app.state.workplace_browser
        try:
            session = browser.create_session(request.agent_id, request.url)
            session = await browser.refresh_session(session["id"])
        except BrowserSandboxError as error:
            raise HTTPException(status_code=400, detail=str(error)) from error
        return session

    @app.post(
        "/auth/apple",
        response_model=AppleAuthResponse,
        tags=["auth"],
        summary="Exchange an Apple user identifier for a Tank device token",
    )
    async def auth_apple(
        request: AppleAuthRequest,
    ) -> AppleAuthResponse:
        """
        Bootstrap endpoint — no device token required.

        Claiming an unpaired Tank additionally requires a pairing window opened
        on the Tank itself, because an Apple user identifier travels inside this
        request and so proves nothing on its own. Without that gate the first
        caller to reach the port would own the Tank.

        Once paired, the registered Apple user gets the same token back and any
        other user ID is rejected.
        """
        store: AgentStore = app.state.agent_store
        pairing: PairingWindow = app.state.pairing_window
        registered = store.get_kv("apple_user_identifier")

        if registered is None:
            if not pairing.is_open():
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail=(
                        "This Tank is not open for pairing. Open pairing on the "
                        "Tank display, then sign in again."
                    ),
                )
            # First pairing — register this Apple user and spend the window so a
            # single opening cannot be reused to claim the Tank twice.
            store.set_kv("apple_user_identifier", request.user_identifier)
            pairing.close()
        elif registered != request.user_identifier:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="This Tank is already paired to a different Apple ID.",
            )

        token = resolve_device_token(store)
        if not token:
            token = secrets.token_urlsafe(32)
            store.set_kv("device_token", token)
        return AppleAuthResponse(device_token=token)

    @app.post(
        "/chat",
        response_model=ChatResponse,
        tags=["assistant"],
        dependencies=[Depends(require_device_token)],
    )
    async def chat(request: ChatRequest) -> ChatResponse:
        system_message = {
            "role": "system",
            "content": (
                "You are NOBS, a warm, concise, privacy-first personal assistant. "
                "Reduce mental load, be honest about unavailable capabilities, and never claim "
                "you changed external data. Keep answers brief unless the user asks for detail."
            ),
        }
        payload = {
            "model": settings.ollama_model,
            "stream": False,
            "think": False,
            "messages": [
                system_message,
                *(message.model_dump() for message in request.messages),
            ],
        }

        try:
            async with httpx.AsyncClient(
                timeout=settings.ollama_timeout_seconds,
                transport=getattr(app.state, "ollama_transport", None),
            ) as client:
                response = await client.post(f"{settings.ollama_base_url}/api/chat", json=payload)
                response.raise_for_status()
        except (httpx.TimeoutException, httpx.ConnectError) as error:
            raise HTTPException(status_code=503, detail="Tank model is unavailable") from error
        except httpx.HTTPStatusError as error:
            raise HTTPException(status_code=502, detail="Tank model returned an error") from error

        try:
            message = OllamaResponse.model_validate_json(response.content).message.content.strip()
        except ValueError as error:
            raise HTTPException(
                status_code=502,
                detail="Tank model returned an invalid response",
            ) from error
        if not message:
            raise HTTPException(status_code=502, detail="Tank model returned an empty response")

        return ChatResponse(
            message=message,
            route="Tank",
            privacy_receipt=PrivacyReceipt(
                used=["conversation messages sent with this request"],
                processed="Tank on your private network",
                shared=[],
                changed=[],
            ),
        )

    @app.post(
        "/briefing",
        response_model=BriefingResponse,
        tags=["assistant"],
        dependencies=[Depends(require_device_token)],
    )
    async def create_briefing(request: BriefingRequest) -> BriefingResponse:
        try:
            result = await generate_briefing(
                settings,
                request,
                getattr(app.state, "ollama_transport", None),
            )
        except BriefingModelUnavailable as error:
            raise HTTPException(status_code=503, detail=str(error)) from error
        except BriefingError as error:
            raise HTTPException(status_code=502, detail=str(error)) from error

        app.state.agent_store.save_briefing(
            request.date.isoformat(), result.model_dump(mode="json")
        )
        return result

    @app.get(
        "/briefing/latest",
        response_model=BriefingResponse,
        tags=["assistant"],
        dependencies=[Depends(require_device_token)],
    )
    async def latest_briefing() -> BriefingResponse:
        briefing = app.state.agent_store.latest_briefing()
        if briefing is None:
            raise HTTPException(status_code=404, detail="No briefing is available")
        try:
            return BriefingResponse.model_validate(briefing)
        except ValueError as error:
            # A stored row written by an older build could fail today's schema.
            # Report it as absent rather than letting a ValidationError surface
            # as an opaque 500.
            raise HTTPException(
                status_code=404,
                detail="No readable briefing is available",
            ) from error

    @app.post(
        "/agent/tasks",
        response_model=AgentTaskResponse,
        tags=["agent"],
        dependencies=[Depends(require_device_token)],
    )
    async def run_agent_task(request: AgentTaskRequest) -> AgentTaskResponse:
        agent = TankAgent(
            settings=settings,
            store=app.state.agent_store,
            tools=app.state.agent_tools,
            transport=getattr(app.state, "ollama_transport", None),
        )
        try:
            return await agent.run(request)
        except AgentModelError as error:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Tank agent model is unavailable",
            ) from error

    @app.get(
        "/agent/approvals",
        response_model=list[ApprovalView],
        tags=["agent"],
        dependencies=[Depends(require_device_token)],
    )
    async def list_agent_approvals(approval_status: str = "pending") -> list[ApprovalView]:
        return [
            ApprovalView.model_validate(item)
            for item in app.state.agent_store.list_approvals(approval_status)
        ]

    @app.post(
        "/agent/approvals/{approval_id}",
        response_model=ApprovalView,
        tags=["agent"],
        dependencies=[Depends(require_device_token)],
    )
    async def decide_agent_approval(
        approval_id: str,
        decision: ApprovalDecision,
    ) -> ApprovalView:
        try:
            approval = app.state.agent_store.get_approval(approval_id)
        except KeyError as error:
            raise HTTPException(status_code=404, detail="Approval not found") from error

        if decision.decision == "deny":
            try:
                denied = app.state.agent_store.decide_approval(approval_id, "denied")
            except ValueError as error:
                raise HTTPException(status_code=409, detail=str(error)) from error
            app.state.agent_store.record_event(
                approval["run_id"],
                "approval_denied",
                {"approval_id": approval_id, "tool": approval["tool_name"]},
            )
            return ApprovalView.model_validate(denied)

        try:
            claimed = app.state.agent_store.claim_approval(approval_id)
        except ValueError as error:
            raise HTTPException(status_code=409, detail=str(error)) from error

        tool = app.state.agent_tools.get(claimed["tool_name"])
        if tool is None or tool.risk != claimed["risk"]:
            failed = app.state.agent_store.finish_approval(
                approval_id,
                "failed",
                {"error": "Approved tool is no longer available with the same risk"},
            )
            return ApprovalView.model_validate(failed)

        try:
            result = app.state.agent_tools.execute(tool.name, claimed["arguments"])
            final_status = "approved"
        except (OSError, ValueError) as error:
            result = {"error": str(error)}
            final_status = "failed"
        finished = app.state.agent_store.finish_approval(approval_id, final_status, result)
        app.state.agent_store.record_event(
            claimed["run_id"],
            "approval_executed",
            {
                "approval_id": approval_id,
                "tool": tool.name,
                "status": final_status,
                "result": result,
            },
        )
        return ApprovalView.model_validate(finished)

    @app.get(
        "/agent/proposals",
        response_model=list[ProposalView],
        tags=["agent"],
        dependencies=[Depends(require_device_token)],
    )
    async def list_agent_proposals(proposal_status: str | None = None) -> list[ProposalView]:
        return [
            ProposalView.model_validate(item)
            for item in app.state.agent_store.list_proposals(proposal_status)
        ]

    @app.post(
        "/agent/proposals/{proposal_id}/decide",
        response_model=ProposalView,
        tags=["agent"],
        dependencies=[Depends(require_device_token)],
    )
    async def decide_agent_proposal(
        proposal_id: str,
        decision: ProposalDecision,
    ) -> ProposalView:
        db_decision = "approved" if decision.decision == "approve" else "dismissed"
        try:
            finished = app.state.agent_store.decide_proposal(proposal_id, db_decision)
            return ProposalView.model_validate(finished)
        except KeyError as error:
            raise HTTPException(status_code=404, detail="Proposal not found") from error
        except ValueError as error:
            raise HTTPException(status_code=409, detail=str(error)) from error

    @app.post(
        "/schedules",
        response_model=ScheduleView,
        tags=["schedules"],
        dependencies=[Depends(require_device_token)],
    )
    async def create_schedule(request: CreateScheduleRequest) -> ScheduleView:
        schedule = app.state.agent_store.create_briefing_schedule(request.time_of_day)
        return ScheduleView.model_validate(schedule)

    @app.get(
        "/schedules",
        response_model=list[ScheduleView],
        tags=["schedules"],
        dependencies=[Depends(require_device_token)],
    )
    async def list_schedules() -> list[ScheduleView]:
        return [
            ScheduleView.model_validate(item)
            for item in app.state.agent_store.list_briefing_schedules()
        ]

    @app.patch(
        "/schedules/{schedule_id}",
        response_model=ScheduleView,
        tags=["schedules"],
        dependencies=[Depends(require_device_token)],
    )
    async def update_schedule(schedule_id: str, request: UpdateScheduleRequest) -> ScheduleView:
        try:
            schedule = app.state.agent_store.update_briefing_schedule(schedule_id, request.status)
            return ScheduleView.model_validate(schedule)
        except KeyError as error:
            raise HTTPException(status_code=404, detail="Schedule not found") from error
        except ValueError as error:
            raise HTTPException(status_code=409, detail=str(error)) from error

    @app.post(
        "/overnight/tasks",
        response_model=OvernightTaskView,
        tags=["overnight"],
        dependencies=[Depends(require_device_token)],
    )
    async def enqueue_overnight_task(request: OvernightTaskCreateRequest) -> OvernightTaskView:
        task = app.state.agent_store.enqueue_overnight_task(
            objective=request.objective,
            context=request.context,
            task_type=request.task_type.value,
            mode=request.mode,
            priority=request.priority,
        )
        return OvernightTaskView.model_validate(task)

    @app.get(
        "/overnight/tasks",
        response_model=list[OvernightTaskView],
        tags=["overnight"],
        dependencies=[Depends(require_device_token)],
    )
    async def list_overnight_tasks(task_status: str | None = None) -> list[OvernightTaskView]:
        return [
            OvernightTaskView.model_validate(item)
            for item in app.state.agent_store.list_overnight_tasks(task_status)
        ]

    @app.get(
        "/overnight/tasks/{task_id}",
        response_model=OvernightTaskView,
        tags=["overnight"],
        dependencies=[Depends(require_device_token)],
    )
    async def get_overnight_task(task_id: str) -> OvernightTaskView:
        try:
            task = app.state.agent_store.get_overnight_task(task_id)
        except KeyError as error:
            raise HTTPException(status_code=404, detail="Overnight task not found") from error
        return OvernightTaskView.model_validate(task)

    @app.post(
        "/overnight/tasks/{task_id}/cancel",
        response_model=OvernightTaskView,
        tags=["overnight"],
        dependencies=[Depends(require_device_token)],
    )
    async def cancel_overnight_task(task_id: str) -> OvernightTaskView:
        try:
            app.state.agent_store.get_overnight_task(task_id)
        except KeyError as error:
            raise HTTPException(status_code=404, detail="Overnight task not found") from error
        try:
            task = app.state.agent_store.cancel_overnight_task(task_id)
        except ValueError as error:
            raise HTTPException(status_code=409, detail=str(error)) from error
        return OvernightTaskView.model_validate(task)

    @app.post(
        "/sync/calendar",
        tags=["sync"],
        dependencies=[Depends(require_device_token)],
    )
    async def sync_calendar(request: SyncCalendarRequest) -> dict[str, str]:
        events = [item.model_dump(mode="json") for item in request.events]
        app.state.agent_store.sync_calendar(events)
        return {"status": "ok"}

    @app.post(
        "/sync/reminders",
        tags=["sync"],
        dependencies=[Depends(require_device_token)],
    )
    async def sync_reminders(request: SyncRemindersRequest) -> dict[str, str]:
        reminders = [item.model_dump(mode="json") for item in request.reminders]
        app.state.agent_store.sync_reminders(reminders)
        return {"status": "ok"}

    def _dream_team_sandbox() -> DreamTeamSandbox:
        return DreamTeamSandbox(
            settings=settings,
            store=app.state.agent_store,
            tools=app.state.agent_tools,
            transport=getattr(app.state, "ollama_transport", None),
            browser_sandbox=app.state.workplace_browser,
        )

    @app.post(
        "/dream-team/sessions",
        response_model=DreamTeamSessionView,
        tags=["dream-team"],
        dependencies=[Depends(require_device_token)],
    )
    async def create_dream_team_session(
        request: DreamTeamSessionCreateRequest,
    ) -> DreamTeamSessionView:
        if not settings.dream_team_enabled:
            raise HTTPException(status_code=503, detail="Dream Team Sandbox is disabled")
        policy = LocalFirstPolicy()
        session = app.state.agent_store.create_dream_team_session(
            objective=request.objective,
            context=request.context,
            config={
                "local_first_policy": policy.as_dict(),
                "model": settings.dream_team_model or settings.ollama_model,
                "max_agents": settings.dream_team_max_agents,
                "max_iterations": settings.dream_team_max_iterations,
            },
        )
        return DreamTeamSessionView.model_validate(session)

    @app.get(
        "/dream-team/sessions",
        response_model=list[DreamTeamSessionView],
        tags=["dream-team"],
        dependencies=[Depends(require_device_token)],
    )
    async def list_dream_team_sessions(
        session_status: str | None = None,
    ) -> list[DreamTeamSessionView]:
        return [
            DreamTeamSessionView.model_validate(item)
            for item in app.state.agent_store.list_dream_team_sessions(session_status)
        ]

    @app.get(
        "/dream-team/sessions/{session_id}",
        response_model=DreamTeamSessionView,
        tags=["dream-team"],
        dependencies=[Depends(require_device_token)],
    )
    async def get_dream_team_session(session_id: str) -> DreamTeamSessionView:
        try:
            session = app.state.agent_store.get_dream_team_session(session_id, include_details=True)
        except KeyError as error:
            raise HTTPException(status_code=404, detail="Session not found") from error
        return DreamTeamSessionView.model_validate(session)

    @app.post(
        "/dream-team/sessions/{session_id}/run",
        response_model=DreamTeamSessionView,
        tags=["dream-team"],
        dependencies=[Depends(require_device_token)],
    )
    async def run_dream_team_session(session_id: str) -> DreamTeamSessionView:
        if not settings.dream_team_enabled:
            raise HTTPException(status_code=503, detail="Dream Team Sandbox is disabled")
        sandbox = _dream_team_sandbox()
        try:
            session = await sandbox.run_session(session_id)
        except KeyError as error:
            raise HTTPException(status_code=404, detail="Session not found") from error
        except ValueError as error:
            raise HTTPException(status_code=409, detail=str(error)) from error
        except DreamTeamModelError as error:
            raise HTTPException(
                status_code=503,
                detail="Local Ollama could not complete dream team refinement",
            ) from error
        return DreamTeamSessionView.model_validate(session)

    @app.get(
        "/dream-team/proposals",
        response_model=list[DreamTeamProposalView],
        tags=["dream-team"],
        dependencies=[Depends(require_device_token)],
    )
    async def list_dream_team_proposals(
        proposal_status: str | None = "pending",
    ) -> list[DreamTeamProposalView]:
        return [
            DreamTeamProposalView.model_validate(item)
            for item in app.state.agent_store.list_dream_team_proposals(proposal_status)
        ]

    @app.get(
        "/dream-team/proposals/{proposal_id}",
        response_model=DreamTeamProposalView,
        tags=["dream-team"],
        dependencies=[Depends(require_device_token)],
    )
    async def get_dream_team_proposal(proposal_id: str) -> DreamTeamProposalView:
        try:
            proposal = app.state.agent_store.get_dream_team_proposal(proposal_id)
        except KeyError as error:
            raise HTTPException(status_code=404, detail="Proposal not found") from error
        return DreamTeamProposalView.model_validate(proposal)

    @app.post(
        "/dream-team/proposals/{proposal_id}/decide",
        tags=["dream-team"],
        dependencies=[Depends(require_device_token)],
    )
    async def decide_dream_team_proposal(
        proposal_id: str,
        decision: DreamTeamProposalDecision,
    ) -> DreamTeamProposalView | DreamTeamApproveResponse:
        sandbox = _dream_team_sandbox()
        try:
            if decision.decision == "approve":
                result = sandbox.approve_proposal(proposal_id)
                return DreamTeamApproveResponse(
                    proposal=DreamTeamProposalView.model_validate(result["proposal"]),
                    active_manifests=result["active_manifests"],
                    local_first_policy=LocalFirstPolicy().as_dict(),
                )
            result = sandbox.reject_proposal(proposal_id)
            return DreamTeamProposalView.model_validate(result)
        except KeyError as error:
            raise HTTPException(status_code=404, detail="Proposal not found") from error
        except ValueError as error:
            raise HTTPException(status_code=409, detail=str(error)) from error

    @app.get(
        "/dream-team/policy",
        tags=["dream-team"],
        dependencies=[Depends(require_device_token)],
    )
    async def dream_team_policy() -> dict[str, Any]:
        """Documents local-first processing for dream team refinement."""
        policy = LocalFirstPolicy()
        return {
            **policy.as_dict(),
            "model": settings.dream_team_model or settings.ollama_model,
            "max_agents": settings.dream_team_max_agents,
            "max_iterations": settings.dream_team_max_iterations,
            "sandbox_max_steps": settings.dream_team_sandbox_max_steps,
            "external_tools_excluded_from_sandbox": sorted(
                {
                    "web_search",
                    "read_url",
                    "lookup_wikipedia",
                    "read_news_feeds",
                    "get_weather",
                }
            ),
            "would_use_cloud_quota": False,
        }

    return app


app = create_app()
