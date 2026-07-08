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
from app.memory import (
    MEMORY_CATEGORIES,
    extract_correction,
    extract_forget_request,
    extract_remember_request,
    find_matching_memories,
    format_memory_used_receipt,
    infer_category,
    infer_memory_from_message,
    memory_categories_used,
)
from app.research import (
    build_research_objective,
    entitlement_denied_detail,
    extract_sources_from_tool_results,
    research_entitled,
)
from app.scheduler import (
    _BRIEFING_SYSTEM_PROMPT,
    _EVENING_BRIEFING_SYSTEM_PROMPT,
    run_scheduler,
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
    kind: Literal["morning", "evening"] = "morning"
    calendar: list[BriefingCalendarItem] = Field(max_length=100)
    reminders: list[BriefingReminderItem] = Field(max_length=100)
    tomorrow_calendar: list[BriefingCalendarItem] = Field(default_factory=list, max_length=100)
    tomorrow_reminders: list[BriefingReminderItem] = Field(default_factory=list, max_length=100)


class BriefingSections(BaseModel):
    topline: str = Field(min_length=1, max_length=600)
    priorities: list[str] = Field(default_factory=list, max_length=5)
    conflicts_or_risks: list[str] = Field(default_factory=list, max_length=8)
    recommended_plan: list[str] = Field(default_factory=list, max_length=10)
    one_useful_question: str | None = Field(default=None, max_length=300)
    suggested_next_actions: list[str] = Field(default_factory=list, max_length=6)


class BriefingResponse(BriefingSections):
    date: date
    kind: Literal["morning", "evening"] = "morning"
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


class MemoryView(BaseModel):
    id: str
    content: str
    category: str
    source: str
    created_at: str
    updated_at: str


class UpdateMemoryRequest(BaseModel):
    content: str | None = Field(default=None, min_length=1, max_length=2_000)
    category: str | None = None


class HomeDeviceView(BaseModel):
    entity_id: str
    name: str
    state: str
    domain: str


class HomeDevicesResponse(BaseModel):
    configured: bool
    devices: list[HomeDeviceView] = Field(default_factory=list)
    truncated: bool = False
    message: str | None = None


class ResearchSourceView(BaseModel):
    title: str
    url: str
    kind: str


class ResearchRequest(BaseModel):
    topic: str = Field(min_length=1, max_length=500)
    context: BriefingContext = BriefingContext.personal


class ResearchJobView(BaseModel):
    id: str
    topic: str
    context: str
    status: str
    summary: str | None = None
    sources: list[ResearchSourceView] = Field(default_factory=list)
    run_id: str | None = None
    created_at: str
    completed_at: str | None = None


class AppleAuthRequest(BaseModel):
    user_identifier: str = Field(min_length=1, max_length=256)
    identity_token: str | None = None


class AppleAuthResponse(BaseModel):
    device_token: str


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    settings = get_settings()
    task = asyncio.create_task(
        run_scheduler(
            settings,
            app.state.agent_store,
            app.state.agent_tools,
            getattr(app.state, "ollama_transport", None),
        )
    )
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
        store: AgentStore = app.state.agent_store
        return await build_dashboard_status(
            settings,
            store,
            app.state.agent_tools,
            app.state.process_started_at,
            getattr(app.state, "ollama_transport", None),
            resolve_device_token(store),
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
        store: AgentStore = app.state.agent_store
        last_user_message = next(
            (message.content for message in reversed(request.messages) if message.role == "user"),
            "",
        )
        memory_changes: list[str] = []
        used_memories: list[dict[str, Any]] = []

        remember_content = extract_remember_request(last_user_message)
        if remember_content:
            category = infer_category(remember_content)
            store.create_memory(remember_content, category, "user_explicit")
            memory_changes.append(f"Saved memory ({category})")
        else:
            forget_query = extract_forget_request(last_user_message)
            if forget_query:
                matches = find_matching_memories(store.list_memories(), forget_query)
                if matches:
                    store.delete_memory(matches[0]["id"])
                    memory_changes.append("Deleted 1 memory")
            else:
                correction = extract_correction(last_user_message)
                if correction:
                    matches = find_matching_memories(store.list_memories(), correction)
                    if not matches and request.messages:
                        matches = store.list_memories()[:1]
                    if matches:
                        updated = store.update_memory(
                            matches[0]["id"],
                            content=correction,
                            category=infer_category(correction),
                        )
                        memory_changes.append(f"Updated memory ({updated['category']})")
                else:
                    inferred = infer_memory_from_message(last_user_message)
                    if inferred:
                        content, category = inferred
                        existing = find_matching_memories(store.list_memories(), content)
                        if not existing:
                            store.create_memory(content, category, "chat")
                            memory_changes.append(f"Inferred memory ({category})")

        all_memories = store.list_memories()
        used_memories = find_matching_memories(all_memories, last_user_message)
        if not used_memories and all_memories and not memory_changes:
            used_memories = all_memories[:3]

        memory_context = ""
        if used_memories:
            lines = [f"- [{item['category']}] {item['content']}" for item in used_memories]
            memory_context = (
                "\n\nApproved memories you may use when relevant:\n" + "\n".join(lines)
            )

        system_message = {
            "role": "system",
            "content": (
                "You are NOBS, a warm, concise, privacy-first personal assistant. "
                "Reduce mental load, be honest about unavailable capabilities, and never claim "
                "you changed external data. Keep answers brief unless the user asks for detail."
                f"{memory_context}"
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

        if remember_content:
            message = "Got it — I'll remember that. You can review or change it anytime in Memory."
        elif extract_forget_request(last_user_message) and memory_changes:
            message = "Done — I removed that memory."
        elif extract_correction(last_user_message) and memory_changes:
            message = "Updated. The corrected memory is saved on Tank."

        used_fields = ["conversation messages sent with this request"]
        used_fields.extend(format_memory_used_receipt(memory_categories_used(used_memories)))

        return ChatResponse(
            message=message,
            route="Tank",
            privacy_receipt=PrivacyReceipt(
                used=used_fields,
                processed="Tank on your private network",
                shared=[],
                changed=memory_changes,
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
        system_prompt = (
            _EVENING_BRIEFING_SYSTEM_PROMPT
            if request.kind == "evening"
            else _BRIEFING_SYSTEM_PROMPT
        )
        payload = {
            "model": settings.ollama_model,
            "stream": False,
            "think": False,
            "format": "json",
            "messages": [
                {"role": "system", "content": system_prompt},
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

        sections = (
            _merge_evening_briefing_with_heuristics(request, sections)
            if request.kind == "evening"
            else _merge_briefing_with_heuristics(request, sections)
        )
        used_fields = [
            f"{len(request.calendar)} calendar items",
            f"{len(request.reminders)} reminder items",
        ]
        if request.kind == "evening":
            used_fields.extend(
                [
                    f"{len(request.tomorrow_calendar)} tomorrow calendar items",
                    f"{len(request.tomorrow_reminders)} tomorrow reminder items",
                ]
            )
        result = BriefingResponse(
            date=request.date,
            kind=request.kind,
            topline=sections.topline,
            priorities=sections.priorities,
            conflicts_or_risks=sections.conflicts_or_risks,
            recommended_plan=sections.recommended_plan,
            one_useful_question=sections.one_useful_question,
            suggested_next_actions=sections.suggested_next_actions,
            generated_at=datetime.now(UTC),
            route="Tank",
            privacy_receipt=PrivacyReceipt(
                used=used_fields,
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

    @app.get(
        "/memories",
        response_model=list[MemoryView],
        tags=["memories"],
        dependencies=[Depends(require_device_token)],
    )
    async def list_memories() -> list[MemoryView]:
        return [
            MemoryView.model_validate(item)
            for item in app.state.agent_store.list_memories()
        ]

    @app.patch(
        "/memories/{memory_id}",
        response_model=MemoryView,
        tags=["memories"],
        dependencies=[Depends(require_device_token)],
    )
    async def update_memory(memory_id: str, request: UpdateMemoryRequest) -> MemoryView:
        if request.category is not None and request.category not in MEMORY_CATEGORIES:
            raise HTTPException(status_code=422, detail="Invalid memory category")
        try:
            updated = app.state.agent_store.update_memory(
                memory_id,
                content=request.content,
                category=request.category,
            )
            return MemoryView.model_validate(updated)
        except KeyError as error:
            raise HTTPException(status_code=404, detail="Memory not found") from error
        except ValueError as error:
            raise HTTPException(status_code=422, detail=str(error)) from error

    @app.delete(
        "/memories/{memory_id}",
        tags=["memories"],
        dependencies=[Depends(require_device_token)],
    )
    async def delete_memory(memory_id: str) -> dict[str, str]:
        try:
            app.state.agent_store.delete_memory(memory_id)
            return {"status": "deleted"}
        except KeyError as error:
            raise HTTPException(status_code=404, detail="Memory not found") from error

    @app.get(
        "/home/devices",
        response_model=HomeDevicesResponse,
        tags=["home"],
        dependencies=[Depends(require_device_token)],
    )
    async def list_home_devices(domain: str | None = None) -> HomeDevicesResponse:
        ha: HomeAssistantClient = app.state.home_assistant
        if not ha.is_configured:
            return HomeDevicesResponse(
                configured=False,
                message=(
                    "Home Assistant is not configured on Tank. "
                    "Set NOBS_HOMEASSISTANT_URL and NOBS_HOMEASSISTANT_TOKEN."
                ),
            )
        try:
            devices = ha.list_devices(domain_filter=domain or None)
        except (httpx.HTTPError, ValueError) as error:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"Could not reach Home Assistant: {error}",
            ) from error
        truncated = len(devices) > 100
        return HomeDevicesResponse(
            configured=True,
            devices=[HomeDeviceView.model_validate(item) for item in devices[:100]],
            truncated=truncated,
        )

    @app.get(
        "/research",
        response_model=list[ResearchJobView],
        tags=["research"],
        dependencies=[Depends(require_device_token)],
    )
    async def list_research_jobs() -> list[ResearchJobView]:
        return [
            ResearchJobView.model_validate(item)
            for item in app.state.agent_store.list_research_jobs()
        ]

    @app.get(
        "/research/{job_id}",
        response_model=ResearchJobView,
        tags=["research"],
        dependencies=[Depends(require_device_token)],
    )
    async def get_research_job(job_id: str) -> ResearchJobView:
        try:
            job = app.state.agent_store.get_research_job(job_id)
        except KeyError as error:
            raise HTTPException(status_code=404, detail="Research job not found") from error
        return ResearchJobView.model_validate(job)

    @app.post(
        "/research",
        response_model=ResearchJobView,
        tags=["research"],
        dependencies=[Depends(require_device_token)],
    )
    async def create_research(request: ResearchRequest) -> ResearchJobView:
        store: AgentStore = app.state.agent_store
        if not research_entitled(store, settings):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=entitlement_denied_detail(),
            )

        job = store.create_research_job(
            topic=request.topic.strip(),
            context=request.context.value,
        )
        agent = TankAgent(
            settings=settings,
            store=store,
            tools=app.state.agent_tools,
            transport=getattr(app.state, "ollama_transport", None),
        )
        try:
            response = await agent.run(
                AgentTaskRequest(
                    objective=build_research_objective(request.topic.strip()),
                    context=request.context.value,
                    mode="assistant",
                    triggered_by="user",
                )
            )
        except AgentModelError as error:
            store.update_research_job(
                job["id"],
                status="failed",
                summary="Tank model is unavailable for research right now.",
            )
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Tank agent model is unavailable",
            ) from error

        sources = extract_sources_from_tool_results(response.tool_results)
        job_status = (
            "awaiting_approval"
            if response.status == "awaiting_approval"
            else "completed"
        )
        updated = store.update_research_job(
            job["id"],
            status=job_status,
            summary=response.message,
            sources=sources,
            run_id=response.run_id,
        )
        return ResearchJobView.model_validate(updated)

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


def _detect_evening_unfinished(request: BriefingRequest) -> list[str]:
    unfinished: list[str] = []
    for reminder in request.reminders:
        unfinished.append(
            f"{_context_prefix(reminder.context)} · {reminder.title} (still open)"
        )
    if request.tomorrow_calendar:
        first = sorted(
            request.tomorrow_calendar,
            key=lambda item: (_time_to_minutes(item.start) is None, _time_to_minutes(item.start) or 0),
        )[0]
        unfinished.append(
            f"Tomorrow starts with {_context_prefix(first.context).lower()} · {first.title} at {first.start}."
        )
    return _dedupe(unfinished)[:8]


def _evening_accomplishments(request: BriefingRequest) -> list[str]:
    accomplishments: list[str] = []
    for event in request.calendar:
        accomplishments.append(
            f"{_context_prefix(event.context)} · {event.title} ({event.start})"
        )
    if not accomplishments and not request.reminders:
        accomplishments.append("You protected space for rest and recovery today.")
    elif not accomplishments:
        accomplishments.append("You kept commitments moving even without fixed calendar blocks.")
    return _dedupe(accomplishments)[:5]


def _evening_topline(request: BriefingRequest, unfinished_count: int) -> str:
    event_count = len(request.calendar)
    if event_count == 0 and unfinished_count == 0:
        return "A calm day wraps up — tomorrow can stay light unless you choose otherwise."
    if unfinished_count == 0:
        return f"You moved through {event_count} commitment{'s' if event_count != 1 else ''} today. Nothing critical is left hanging."
    if unfinished_count == 1:
        return "Solid progress today — one item can roll forward without guilt."
    return (
        f"You made it through a full day. {unfinished_count} items can carry to tomorrow "
        "without needing to finish tonight."
    )


def _evening_tomorrow_plan(request: BriefingRequest) -> list[str]:
    plan: list[str] = []
    tomorrow_events = sorted(
        request.tomorrow_calendar,
        key=lambda item: (_time_to_minutes(item.start) is None, _time_to_minutes(item.start) or 0),
    )
    if tomorrow_events:
        first = tomorrow_events[0]
        plan.append(f"First up tomorrow: {first.title} at {first.start}.")
    for event in tomorrow_events[:3]:
        plan.append(
            f"Block prep for {_context_prefix(event.context).lower()} · {event.title}."
        )
    if request.tomorrow_reminders:
        plan.append(
            f"{len(request.tomorrow_reminders)} reminder"
            f"{'s' if len(request.tomorrow_reminders) != 1 else ''} queued for tomorrow."
        )
    if not plan:
        plan.append("Tomorrow looks open — protect one block for what matters most.")
    plan.append("Wind down without reopening today's unfinished list unless it helps.")
    return _dedupe(plan)[:6]


def _evening_question(request: BriefingRequest, unfinished: list[str]) -> str | None:
    if len(unfinished) >= 2:
        return "Which carry-over item matters most tomorrow so the rest can wait?"
    if request.tomorrow_calendar and len(request.tomorrow_calendar) >= 4:
        return "Tomorrow looks packed — want to defer one lower-priority block now?"
    return None


def _evening_next_actions(request: BriefingRequest, unfinished: list[str]) -> list[str]:
    actions: list[str] = []
    if unfinished:
        actions.append("Pick one carry-over item to tackle first tomorrow — the rest can wait.")
    if request.tomorrow_calendar:
        first = sorted(
            request.tomorrow_calendar,
            key=lambda item: (_time_to_minutes(item.start) is None, _time_to_minutes(item.start) or 0),
        )[0]
        actions.append(f"Set a gentle prep reminder for {first.title} before bed.")
    actions.append("Close the day — unfinished work does not need guilt tonight.")
    return _dedupe(actions)[:4]


def _merge_evening_briefing_with_heuristics(
    request: BriefingRequest, sections: BriefingSections
) -> BriefingSections:
    accomplishments = _evening_accomplishments(request)
    unfinished = _detect_evening_unfinished(request)
    merged_priorities = _dedupe([*sections.priorities, *accomplishments])[:5]
    if not merged_priorities:
        merged_priorities = accomplishments
    merged_unfinished = _dedupe([*sections.conflicts_or_risks, *unfinished])[:8]
    question = sections.one_useful_question.strip() if sections.one_useful_question else None
    if not question:
        question = _evening_question(request, merged_unfinished)
    return BriefingSections(
        topline=sections.topline.strip()
        or _evening_topline(request, unfinished_count=len(merged_unfinished)),
        priorities=merged_priorities or accomplishments,
        conflicts_or_risks=merged_unfinished or ["Nothing critical needs to carry into tomorrow."],
        recommended_plan=(
            _dedupe(sections.recommended_plan)[:10]
            or _evening_tomorrow_plan(request)
        ),
        one_useful_question=question,
        suggested_next_actions=(
            _dedupe(sections.suggested_next_actions)[:6]
            or _evening_next_actions(request, merged_unfinished)
        ),
    )


app = create_app()
