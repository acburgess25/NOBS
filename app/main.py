from contextlib import asynccontextmanager
import asyncio
from datetime import UTC, date, datetime
from enum import Enum
import json
import secrets
from pathlib import Path
import time
from typing import AsyncIterator, Literal

import httpx
from fastapi import Depends, FastAPI, Header, HTTPException, status
from fastapi.responses import RedirectResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field

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
from app.config import Settings, get_settings
from app.dashboard import build_dashboard_status
from app.home_assistant import HomeAssistantClient
from app.scheduler import _BRIEFING_SYSTEM_PROMPT, run_scheduler


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
    context: BriefingContext


class BriefingReminderItem(BaseModel):
    title: str = Field(min_length=1, max_length=500)
    context: BriefingContext


class BriefingRequest(BaseModel):
    date: date
    calendar: list[BriefingCalendarItem] = Field(max_length=100)
    reminders: list[BriefingReminderItem] = Field(max_length=100)


class BriefingSections(BaseModel):
    personal: str
    business: str
    shared: str


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


class SyncCalendarRequest(BaseModel):
    events: list[BriefingCalendarItem]


class SyncRemindersRequest(BaseModel):
    reminders: list[BriefingReminderItem]


class AppleAuthRequest(BaseModel):
    user_identifier: str = Field(min_length=1, max_length=256)
    identity_token: str | None = None


class AppleAuthResponse(BaseModel):
    device_token: str


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    settings = get_settings()
    task = asyncio.create_task(run_scheduler(
        settings,
        app.state.agent_store,
        app.state.agent_tools,
        getattr(app.state, "ollama_transport", None),
    ))
    yield
    task.cancel()


def create_app(settings: Settings | None = None) -> FastAPI:
    settings = settings or get_settings()
    app = FastAPI(
        title="NOBS Tank API",
        version=settings.version,
        lifespan=lifespan,
    )
    app.state.agent_store = AgentStore(settings.agent_database_path)
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
    app.mount(
        "/dashboard/assets",
        StaticFiles(directory=dashboard_directory),
        name="dashboard-assets",
    )

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
        return await build_dashboard_status(
            settings,
            app.state.agent_store,
            app.state.agent_tools,
            app.state.process_started_at,
            getattr(app.state, "ollama_transport", None),
        )

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

    @app.get(
        "/ready",
        tags=["operations"],
        dependencies=[Depends(require_device_token)],
    )
    async def ready() -> dict[str, str]:
        return {"status": "ready"}

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

        result = BriefingResponse(
            date=request.date,
            personal=sections.personal,
            business=sections.business,
            shared=sections.shared,
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

    return app


app = create_app()
