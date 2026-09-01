from __future__ import annotations

import asyncio
import json
from typing import Any, Literal

import httpx
from pydantic import BaseModel, Field

from app.agent_store import AgentStore
from app.agent_tools import ToolRegistry, ToolRisk
from app.config import Settings


class AgentTaskRequest(BaseModel):
    objective: str = Field(min_length=1, max_length=10_000)
    context: Literal["personal", "business", "shared"] = "personal"
    mode: Literal["assistant", "developer"] = "assistant"


class ApprovalView(BaseModel):
    id: str
    run_id: str
    tool_name: str
    arguments: dict[str, Any]
    risk: str
    reason: str
    status: str
    result: dict[str, Any] | None
    created_at: str
    decided_at: str | None


class AgentTaskResponse(BaseModel):
    run_id: str
    status: Literal["completed", "awaiting_approval", "step_limit_reached"]
    message: str
    approvals: list[ApprovalView]
    tool_results: list[dict[str, Any]]


class ApprovalDecision(BaseModel):
    decision: Literal["approve", "deny"]


class OllamaToolFunction(BaseModel):
    name: str
    arguments: dict[str, Any] = Field(default_factory=dict)


class OllamaToolCall(BaseModel):
    type: str = "function"
    function: OllamaToolFunction


class OllamaAgentMessage(BaseModel):
    role: str = "assistant"
    content: str = ""
    tool_calls: list[OllamaToolCall] = Field(default_factory=list)


class OllamaAgentResponse(BaseModel):
    message: OllamaAgentMessage


class AgentModelError(RuntimeError):
    pass


class TankAgent:
    def __init__(
        self,
        settings: Settings,
        store: AgentStore,
        tools: ToolRegistry,
        transport: httpx.AsyncBaseTransport | None = None,
        timeout_override: float | None = None,
    ) -> None:
        self.settings = settings
        self.store = store
        self.tools = tools
        self.transport = transport
        self._timeout_seconds = (
            timeout_override if timeout_override is not None else settings.ollama_timeout_seconds
        )

    async def run(self, request: AgentTaskRequest) -> AgentTaskResponse:
        run_id = self.store.create_run(request.objective, request.context)
        messages: list[dict[str, Any]] = [
            {
                "role": "system",
                "content": self._system_prompt(request.context, request.mode),
            },
            {"role": "user", "content": request.objective},
        ]
        approvals: list[dict[str, Any]] = []
        tool_results: list[dict[str, Any]] = []

        for _ in range(self.settings.agent_max_steps):
            response = await self._chat(
                messages,
                tools=[] if approvals else self.tools.schemas_for_mode(request.mode),
                model=(
                    self.settings.coding_model
                    if request.mode == "developer"
                    else self.settings.ollama_model
                ),
            )
            message = response.message
            if not message.tool_calls and message.content:
                parsed = self._parse_json_tool_call(message.content)
                if parsed:
                    message.tool_calls = [
                        OllamaToolCall(
                            type="function",
                            function=OllamaToolFunction(
                                name=parsed["name"],
                                arguments=parsed["arguments"],
                            ),
                        )
                    ]
            messages.append(message.model_dump(exclude_none=True))
            if not message.tool_calls:
                status = "awaiting_approval" if approvals else "completed"
                self.store.update_run(run_id, status)
                return AgentTaskResponse(
                    run_id=run_id,
                    status=status,
                    message=message.content.strip() or self._fallback_message(approvals),
                    approvals=[ApprovalView.model_validate(item) for item in approvals],
                    tool_results=tool_results,
                )

            for call in message.tool_calls:
                tool = self.tools.get(call.function.name)
                if tool is None or not self.tools.is_available(call.function.name, request.mode):
                    result = {"error": "Unknown or unavailable tool"}
                elif tool.risk is ToolRisk.READ_ONLY:
                    try:
                        # Tool handlers are synchronous and several perform network
                        # I/O, so running them inline would block the event loop
                        # for the whole Tank.
                        result = await asyncio.to_thread(
                            self.tools.execute, tool.name, call.function.arguments
                        )
                    except (OSError, ValueError) as error:
                        result = {"error": str(error)}
                    self.store.record_event(
                        run_id,
                        "tool_executed",
                        {"tool": tool.name, "risk": tool.risk, "result": result},
                    )
                    tool_results.append({"tool": tool.name, "result": result})
                else:
                    try:
                        # Check the arguments before queueing anything. Otherwise a
                        # call the tool would refuse still becomes a pending
                        # approval, and the user is asked to authorize something
                        # that cannot run. Reporting the error here also lets the
                        # model correct itself within the same run.
                        self.tools.validate(tool.name, call.function.arguments)
                    except ValueError as error:
                        result = {"error": str(error)}
                        self.store.record_event(
                            run_id,
                            "tool_refused",
                            {
                                "tool": tool.name,
                                "risk": tool.risk,
                                "arguments": call.function.arguments,
                                "error": str(error),
                            },
                        )
                        messages.append(
                            {
                                "role": "tool",
                                "tool_name": call.function.name,
                                "content": json.dumps(result),
                            }
                        )
                        continue
                    approval = self.store.create_approval(
                        run_id=run_id,
                        tool_name=tool.name,
                        arguments=call.function.arguments,
                        risk=tool.risk,
                        reason=f"{tool.name} changes {request.context} state",
                    )
                    approvals.append(approval)
                    result = {
                        "status": "approval_required",
                        "approval_id": approval["id"],
                    }
                messages.append(
                    {
                        "role": "tool",
                        "tool_name": call.function.name,
                        "content": json.dumps(result),
                    }
                )

        status = "awaiting_approval" if approvals else "step_limit_reached"
        self.store.update_run(run_id, status)
        return AgentTaskResponse(
            run_id=run_id,
            status=status,
            message=self._fallback_message(approvals),
            approvals=[ApprovalView.model_validate(item) for item in approvals],
            tool_results=tool_results,
        )

    async def _chat(
        self,
        messages: list[dict[str, Any]],
        tools: list[dict[str, Any]],
        model: str,
    ) -> OllamaAgentResponse:
        payload = {
            "model": model,
            "stream": False,
            "think": False,
            "messages": messages,
            "tools": tools,
        }
        try:
            async with httpx.AsyncClient(
                timeout=self._timeout_seconds,
                transport=self.transport,
            ) as client:
                response = await client.post(
                    f"{self.settings.ollama_base_url}/api/chat",
                    json=payload,
                )
                response.raise_for_status()
            return OllamaAgentResponse.model_validate_json(response.content)
        except (httpx.HTTPError, ValueError) as error:
            raise AgentModelError("Tank model could not complete the agent step") from error

    @staticmethod
    def _system_prompt(context: str, mode: str) -> str:
        prompt = (
            "You are the NOBS agent running privately on Tank. You are in a bounded tool loop. "
            f"The active context is {context}. Never mix personal and business context unless the "
            "active context is shared. Use only the supplied tools. Read-only tools may run now. "
            "Any tool that changes state will be queued for explicit user approval. Never claim a "
            "queued action happened. Briefly explain what you learned or what approval is needed."
        )
        if mode == "developer":
            prompt += (
                " Developer mode may inspect only the configured NOBS project through bounded "
                "read-only tools. Cite relevant project-relative file paths. It cannot edit files, "
                "run commands or tests, read secrets, or access the network. Never claim that it did."
            )
        return prompt

    @staticmethod
    def _fallback_message(approvals: list[dict[str, Any]]) -> str:
        if approvals:
            return "I prepared an action and am waiting for your approval before changing anything."
        return "I stopped after reaching the safe step limit without changing anything."

    @staticmethod
    def _parse_json_tool_call(content: str) -> dict[str, Any] | None:
        content = content.strip()
        if content.startswith("```"):
            lines = content.splitlines()
            if len(lines) >= 2 and lines[-1].startswith("```"):
                content = "\n".join(lines[1:-1]).strip()
        try:
            data = json.loads(content)
            if isinstance(data, dict) and "name" in data:
                args = data.get("arguments", {})
                if not isinstance(args, dict):
                    args = {}
                return {"name": str(data["name"]), "arguments": args}
        except json.JSONDecodeError:
            pass
        return None
