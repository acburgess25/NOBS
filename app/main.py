from contextlib import asynccontextmanager
from datetime import UTC, datetime
import secrets
from pathlib import Path
import time
from typing import AsyncIterator

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


@asynccontextmanager
async def lifespan(_: FastAPI) -> AsyncIterator[None]:
    get_settings()
    yield


def create_app(settings: Settings | None = None) -> FastAPI:
    settings = settings or get_settings()
    app = FastAPI(
        title="NOBS Tank API",
        version=settings.version,
        lifespan=lifespan,
    )
    app.state.agent_store = AgentStore(settings.agent_database_path)
    app.state.agent_tools = ToolRegistry(settings.agent_workspace_path)
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

    async def require_device_token(
        authorization: str | None = Header(default=None),
    ) -> None:
        configured_token = settings.device_token
        if configured_token is None or not configured_token.get_secret_value():
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Tank device authentication is not configured",
            )

        scheme, _, supplied_token = (authorization or "").partition(" ")
        if scheme.lower() != "bearer" or not secrets.compare_digest(
            supplied_token,
            configured_token.get_secret_value(),
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

    return app


app = create_app()
