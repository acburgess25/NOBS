from contextlib import asynccontextmanager
import asyncio
from datetime import UTC, date, datetime
import logging
import secrets
from pathlib import Path
import sqlite3
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
from app.briefing import (
    BriefingCalendarItem,
    BriefingContext,
    BriefingInvalidResponseError,
    BriefingReminderItem,
    BriefingRequest,
    BriefingSections,
    BriefingUnavailableError,
    OllamaResponse,
    generate_briefing_sections,
    privacy_receipt_used_fields,
)
from app.tank_health import dependency_status, ready_from_checks
from app.scheduler import run_scheduler


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


class PairRequest(BaseModel):
    code: str = Field(min_length=8, max_length=128)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    settings = get_settings()
    store: AgentStore = app.state.agent_store
    try:
        store.recover_stale_state(
            approval_minutes=settings.stale_approval_minutes,
            run_timeout_seconds=settings.ollama_timeout_seconds * settings.agent_max_steps,
        )
    except sqlite3.Error as error:
        logging.getLogger(__name__).warning(
            "Could not recover stale Tank state on startup: %s", error
        )
    task = asyncio.create_task(
        run_scheduler(
            settings,
            store,
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
    async def ready() -> dict[str, Any]:
        checks = await dependency_status(
            settings,
            app.state.agent_store,
            getattr(app.state, "ollama_transport", None),
        )
        ok, message = ready_from_checks(checks)
        if not ok:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail={
                    "status": "not_ready",
                    "message": message,
                    "checks": checks,
                },
            )
        return {"status": "ready", "checks": checks}

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
        "/auth/pair",
        response_model=AppleAuthResponse,
        tags=["auth"],
        summary="Exchange a dashboard pairing code for the device token",
    )
    async def auth_pair(request: PairRequest) -> AppleAuthResponse:
        store: AgentStore = app.state.agent_store
        if not store.consume_pairing_code(request.code):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid or expired pairing code",
            )
        token = resolve_device_token(store)
        if not token:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Tank device authentication is not configured",
            )
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
        try:
            sections = await generate_briefing_sections(
                settings,
                request,
                transport=getattr(app.state, "ollama_transport", None),
            )
        except BriefingUnavailableError as error:
            raise HTTPException(status_code=503, detail=str(error)) from error
        except BriefingInvalidResponseError as error:
            raise HTTPException(status_code=502, detail=str(error)) from error

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
                used=privacy_receipt_used_fields(request),
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
        except (httpx.HTTPError, ValueError, TypeError, OSError) as error:
            store.update_research_job(
                job["id"],
                status="failed",
                summary="Research job failed before completion.",
            )
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Research job failed",
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


app = create_app()
