from contextlib import asynccontextmanager
import asyncio
from datetime import UTC, date, datetime
from enum import Enum
import json
import secrets
from pathlib import Path
import time
from typing import Any, AsyncIterator, Literal

import httpx
from fastapi import Depends, FastAPI, Header, HTTPException, Query, status
from fastapi.responses import RedirectResponse, Response
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field

from app.agent import (
    AgentModelError,
    AgentTaskRequest,
    AgentTaskResponse,
    ApprovalDecision,
    ApprovalView,
    BrainstormRequest,
    IdeaView,
    TankAgent,
)
from app.agent_store import AgentStore
from app.agent_tools import ToolRegistry
from app.bonjour import TankBonjourAdvertisement
from app.config import Settings, get_settings
from app.dashboard import build_dashboard_status
from app.dream_team import DreamTeamModelError, DreamTeamSandbox, LocalFirstPolicy
from app.workplace import (
    BrowserSandbox,
    BrowserSandboxError,
    build_workplace_status,
    parse_allowed_domains,
)
from app.home_assistant import HomeAssistantClient
from app.scheduler import _BRIEFING_SYSTEM_PROMPT, run_scheduler
from app.tank_optimizer import (
    TankOptimizer,
    _ALL_JOB_TYPES,
    _HEAVY_JOB_TYPES,
    run_optimizer_loop,
)


class ChatMessage(BaseModel):
    role: str = Field(pattern="^(user|assistant)$")
    content: str = Field(min_length=1, max_length=20_000)


class ChatRequest(BaseModel):
    messages: list[ChatMessage] = Field(min_length=1, max_length=40)


class PrivacyReceipt(BaseModel):
    used: list[str]
    processed: str
    shared: list[str]
    changed: list[str]


class ChatResponse(BaseModel):
    message: str
    route: str
    privacy_receipt: PrivacyReceipt


class OllamaMessage(BaseModel):
    content: str


class OllamaResponse(BaseModel):
    message: OllamaMessage


class BriefingContext(str, Enum):
    personal = "personal"
    business = "business"
    shared = "shared"


class BriefingCalendarItem(BaseModel):
    title: str = Field(min_length=1, max_length=500)
    start: str = Field(min_length=1, max_length=50)
    end: str | None = Field(default=None, max_length=50)
    location: str | None = Field(default=None, max_length=300)
    context: BriefingContext


class BriefingReminderItem(BaseModel):
    title: str = Field(min_length=1, max_length=500)
    due: str | None = Field(default=None, max_length=50)
    context: BriefingContext


class BriefingRequest(BaseModel):
    date: date
    calendar: list[BriefingCalendarItem] = Field(max_length=100)
    reminders: list[BriefingReminderItem] = Field(max_length=100)


class BriefingSections(BaseModel):
    topline: str = Field(min_length=1, max_length=600)
    priorities: list[str] = Field(default_factory=list, max_length=5)
    conflicts_or_risks: list[str] = Field(default_factory=list, max_length=8)
    recommended_plan: list[str] = Field(default_factory=list, max_length=10)
    one_useful_question: str | None = Field(default=None, max_length=300)
    suggested_next_actions: list[str] = Field(default_factory=list, max_length=6)


class BriefingResponse(BriefingSections):
    date: date
    generated_at: datetime
    route: str
    privacy_receipt: PrivacyReceipt


class ProposalView(BaseModel):
    id: str
    title: str
    description: str
    proposal_type: str
    status: str
    created_at: str
    decided_at: str | None


class ProposalDecision(BaseModel):
    decision: Literal["approve", "dismiss"]


class ScheduleView(BaseModel):
    id: str
    time_of_day: str
    status: str
    created_at: str


class CreateScheduleRequest(BaseModel):
    time_of_day: str = Field(pattern="^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$")


class UpdateScheduleRequest(BaseModel):
    status: Literal["active", "paused", "revoked"]


class OvernightTaskType(str, Enum):
    research = "research"
    memory_consolidation = "memory_consolidation"
    briefing_prep = "briefing_prep"
    custom = "custom"


class OvernightTaskCreateRequest(BaseModel):
    objective: str = Field(min_length=1, max_length=10_000)
    context: Literal["personal", "business", "shared"] = "personal"
    mode: Literal["assistant", "developer"] = "assistant"
    task_type: OvernightTaskType = OvernightTaskType.custom
    priority: int = Field(default=0, ge=0, le=10)


class OvernightTaskView(BaseModel):
    id: str
    objective: str
    context: str
    mode: str
    task_type: str
    priority: int
    status: str
    result: dict[str, Any] | None
    error: str | None
    created_at: str
    started_at: str | None
    completed_at: str | None


class SyncCalendarRequest(BaseModel):
    events: list[BriefingCalendarItem]


class SyncRemindersRequest(BaseModel):
    reminders: list[BriefingReminderItem]


class AppleAuthRequest(BaseModel):
    user_identifier: str = Field(min_length=1, max_length=256)
    identity_token: str | None = None


class AppleAuthResponse(BaseModel):
    device_token: str


class DreamTeamSessionCreateRequest(BaseModel):
    objective: str = Field(min_length=1, max_length=2000)
    context: Literal["personal", "business", "shared"] = "personal"


class DreamTeamDraftView(BaseModel):
    id: str
    session_id: str
    name: str
    role: str
    persona: dict[str, Any]
    score: float | None
    iteration: int
    status: str
    test_result: dict[str, Any] | None
    created_at: str
    updated_at: str


class DreamTeamProposalView(BaseModel):
    id: str
    session_id: str
    title: str
    summary: str
    members: list[dict[str, Any]]
    metadata: dict[str, Any]
    status: str
    created_at: str
    decided_at: str | None


class DreamTeamSessionView(BaseModel):
    id: str
    objective: str
    context: str
    status: str
    config: dict[str, Any]
    result_summary: str | None
    created_at: str
    updated_at: str
    drafts: list[DreamTeamDraftView] | None = None
    proposals: list[DreamTeamProposalView] | None = None


class DreamTeamProposalDecision(BaseModel):
    decision: Literal["approve", "reject"]


class DreamTeamApproveResponse(BaseModel):
    proposal: DreamTeamProposalView
    active_manifests: int
    local_first_policy: dict[str, Any]


class WorkplaceBrowserSessionRequest(BaseModel):
    agent_id: str = Field(min_length=1, max_length=120)
    url: str = Field(min_length=1, max_length=2000)


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
        return await build_dashboard_status(
            settings,
            store,
            app.state.agent_tools,
            app.state.process_started_at,
            getattr(app.state, "ollama_transport", None),
            resolve_device_token(store),
            getattr(app.state, "optimizer", None),
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

    @app.post("/optimizer/run-now", tags=["operations"], dependencies=[Depends(require_device_token)])
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
        kind = (
            OptimizerJobKind.heavy
            if selected in _HEAVY_JOB_TYPES
            else OptimizerJobKind.light
        )
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

        First call registers the Apple user ID and returns the device token.
        Subsequent calls from the same user ID also return the token.
        Any other user ID is rejected (personal-use protection).
        """
        store: AgentStore = app.state.agent_store
        registered = store.get_kv("apple_user_identifier")

        if registered is None:
            # First pairing — register this Apple user.
            store.set_kv("apple_user_identifier", request.user_identifier)
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
        source = request.model_dump(mode="json")
        payload = {
            "model": settings.ollama_model,
            "stream": False,
            "think": False,
            "format": "json",
            "messages": [
                {"role": "system", "content": _BRIEFING_SYSTEM_PROMPT},
                {"role": "user", "content": json.dumps(source)},
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
            model_content = OllamaResponse.model_validate_json(response.content).message.content
            sections = BriefingSections.model_validate_json(model_content)
        except ValueError as error:
            raise HTTPException(
                status_code=502,
                detail="Tank model returned an invalid briefing",
            ) from error

        sections = _merge_briefing_with_heuristics(request, sections)
        result = BriefingResponse(
            date=request.date,
            topline=sections.topline,
            priorities=sections.priorities,
            conflicts_or_risks=sections.conflicts_or_risks,
            recommended_plan=sections.recommended_plan,
            one_useful_question=sections.one_useful_question,
            suggested_next_actions=sections.suggested_next_actions,
            generated_at=datetime.now(UTC),
            route="Tank",
            privacy_receipt=PrivacyReceipt(
                used=[
                    f"{len(request.calendar)} calendar items",
                    f"{len(request.reminders)} reminder items",
                ],
                processed="Tank on your private network",
                shared=[],
                changed=[],
            ),
        )
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
        return BriefingResponse.model_validate(briefing)

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

    @app.get(
        "/agent/ideas",
        response_model=list[IdeaView],
        tags=["agent"],
        dependencies=[Depends(require_device_token)],
    )
    async def list_agent_ideas(
        idea_status: str | None = Query(default=None),
    ) -> list[IdeaView]:
        return [
            IdeaView.model_validate(item)
            for item in app.state.agent_store.list_ideas(idea_status)
        ]

    @app.post(
        "/agent/brainstorm",
        response_model=list[IdeaView],
        tags=["agent"],
        dependencies=[Depends(require_device_token)],
    )
    async def brainstorm_ideas(request: BrainstormRequest) -> list[IdeaView]:
        agent = TankAgent(
            settings=settings,
            store=app.state.agent_store,
            tools=app.state.agent_tools,
            transport=getattr(app.state, "ollama_transport", None),
        )
        try:
            return await agent.brainstorm(
                request.topic,
                context=request.context,
                n_candidates=request.n_candidates,
                take_top=request.take_top,
            )
        except AgentModelError as error:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Tank model is unavailable",
            ) from error

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
            session = app.state.agent_store.get_dream_team_session(
                session_id, include_details=True
            )
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


def _time_to_minutes(value: str | None) -> int | None:
    if not value:
        return None
    try:
        hour, minute = value.strip().split(":", 1)
        parsed_hour = int(hour)
        parsed_minute = int(minute)
    except (ValueError, AttributeError):
        return None
    if parsed_hour < 0 or parsed_hour > 23 or parsed_minute < 0 or parsed_minute > 59:
        return None
    return parsed_hour * 60 + parsed_minute


def _is_important_title(title: str) -> bool:
    normalized = title.lower()
    important_keywords = (
        "deadline",
        "interview",
        "presentation",
        "board",
        "review",
        "flight",
        "doctor",
        "exam",
        "launch",
    )
    return any(keyword in normalized for keyword in important_keywords)


def _context_prefix(context: BriefingContext) -> str:
    if context == BriefingContext.business:
        return "Business"
    if context == BriefingContext.shared:
        return "Shared"
    return "Personal"


def _dedupe(values: list[str]) -> list[str]:
    seen: set[str] = set()
    result: list[str] = []
    for value in values:
        trimmed = value.strip()
        if not trimmed:
            continue
        key = trimmed.casefold()
        if key in seen:
            continue
        seen.add(key)
        result.append(trimmed)
    return result


def _detect_briefing_risks(request: BriefingRequest) -> tuple[list[str], bool]:
    risks: list[str] = []
    overload = False
    events = sorted(
        request.calendar,
        key=lambda item: (_time_to_minutes(item.start) is None, _time_to_minutes(item.start) or 0),
    )
    if len(events) >= 7:
        overload = True
        risks.append(f"Your day has {len(events)} events, which is likely overload without active pruning.")

    back_to_back = 0
    overlaps = 0
    important_tight = 0
    morning_count = 0
    for index, event in enumerate(events):
        start_minutes = _time_to_minutes(event.start)
        if start_minutes is not None and start_minutes < (12 * 60):
            morning_count += 1
        if index >= len(events) - 1:
            continue
        current_end = _time_to_minutes(event.end) or start_minutes
        next_start = _time_to_minutes(events[index + 1].start)
        if current_end is None or next_start is None:
            continue
        gap = next_start - current_end
        if gap < 0:
            overlaps += 1
        elif gap <= 10:
            back_to_back += 1
        if (
            _is_important_title(event.title)
            and _is_important_title(events[index + 1].title)
            and gap <= 60
        ):
            important_tight += 1

    if overlaps > 0:
        overload = True
        risks.append(f"{overlaps} schedule overlap(s) need a clear attendance choice.")
    if back_to_back >= 2:
        overload = True
        risks.append(
            f"{back_to_back} tight transition(s) under 10 minutes increase prep or travel risk."
        )
    if important_tight > 0:
        overload = True
        risks.append(
            "Important events are clustered too tightly; prep quality is at risk."
        )
    if morning_count >= 4:
        overload = True
        risks.append(
            "Morning load is heavy with four or more events before noon."
        )
    if request.reminders and sum(1 for reminder in request.reminders if reminder.context == BriefingContext.business) >= 3:
        risks.append("Several business reminders are pending; prep work may be under-scoped.")

    return _dedupe(risks), overload


def _fallback_topline(
    request: BriefingRequest, overload: bool, risk_count: int
) -> str:
    if not request.calendar and not request.reminders:
        return "This is a light day with room to protect deep work and recovery."
    if overload:
        return "This is a high-load day; trimming and sequencing early will keep it realistic."
    if risk_count > 0:
        return "This day is manageable, but a few timing risks need attention."
    return "This is a steady day with enough space to execute your top priorities."


def _fallback_priorities(request: BriefingRequest) -> list[str]:
    ranked_events = sorted(
        request.calendar,
        key=lambda item: (
            not _is_important_title(item.title),
            _time_to_minutes(item.start) or 24 * 60,
        ),
    )
    priorities = [
        f"{_context_prefix(event.context)} · {event.title} ({event.start})"
        for event in ranked_events[:4]
    ]
    if len(priorities) < 3:
        priorities.extend(
            f"{_context_prefix(reminder.context)} · {reminder.title}"
            for reminder in request.reminders[: 5 - len(priorities)]
        )
    if not priorities:
        priorities.append("Protect one focused block for your highest-impact work.")
    return _dedupe(priorities)[:5]


def _fallback_recommended_plan(request: BriefingRequest) -> list[str]:
    events = sorted(
        request.calendar,
        key=lambda item: (_time_to_minutes(item.start) is None, _time_to_minutes(item.start) or 0),
    )
    plan: list[str] = []
    if events:
        first = events[0]
        plan.append(
            f"Start with prep for {first.title} before {first.start} to avoid reactive context switching."
        )
    for event in events[:3]:
        plan.append(f"Anchor {_context_prefix(event.context).lower()} focus around {event.title} at {event.start}.")
    if request.reminders:
        plan.append("Bundle reminder follow-ups into one admin block between meetings.")
    plan.append("Reassess afternoon priorities after lunch and drop low-impact work.")
    return _dedupe(plan)[:6]


def _fallback_question(request: BriefingRequest, risks: list[str]) -> str | None:
    events = sorted(
        request.calendar,
        key=lambda item: (_time_to_minutes(item.start) is None, _time_to_minutes(item.start) or 0),
    )
    for index, event in enumerate(events[:-1]):
        current_end = _time_to_minutes(event.end)
        next_start = _time_to_minutes(events[index + 1].start)
        if current_end is None or next_start is None:
            continue
        if next_start < current_end:
            return (
                "You have overlapping events. Which one is the must-attend so I can adjust the rest?"
            )
    if risks and request.reminders:
        return "Which reminder is truly critical today so lower-value tasks can be deferred?"
    return None


def _fallback_next_actions(request: BriefingRequest, risks: list[str]) -> list[str]:
    actions: list[str] = []
    if request.calendar:
        first = sorted(
            request.calendar,
            key=lambda item: (_time_to_minutes(item.start) is None, _time_to_minutes(item.start) or 0),
        )[0]
        actions.append(f"Review prep notes for {first.title} before {first.start}.")
    if risks:
        actions.append("Draft a conflict message for any meeting that can be moved or shortened.")
    if request.reminders:
        actions.append("Create a single prep reminder block to clear your highest-value tasks.")
    actions.append("Re-check afternoon priorities after your second major commitment.")
    return _dedupe(actions)[:4]


def _merge_briefing_with_heuristics(
    request: BriefingRequest, sections: BriefingSections
) -> BriefingSections:
    heuristic_risks, overload = _detect_briefing_risks(request)
    merged_risks = _dedupe([*sections.conflicts_or_risks, *heuristic_risks])[:8]
    question = sections.one_useful_question.strip() if sections.one_useful_question else None
    if not question:
        question = _fallback_question(request, merged_risks)
    return BriefingSections(
        topline=sections.topline.strip()
        or _fallback_topline(request, overload=overload, risk_count=len(merged_risks)),
        priorities=(
            _dedupe(sections.priorities)[:5]
            or _fallback_priorities(request)
        ),
        conflicts_or_risks=merged_risks or ["No major schedule risks detected right now."],
        recommended_plan=(
            _dedupe(sections.recommended_plan)[:10]
            or _fallback_recommended_plan(request)
        ),
        one_useful_question=question,
        suggested_next_actions=(
            _dedupe(sections.suggested_next_actions)[:6]
            or _fallback_next_actions(request, merged_risks)
        ),
    )


app = create_app()
