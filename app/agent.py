from __future__ import annotations

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


class IdeaView(BaseModel):
    id: str
    title: str
    description: str
    status: str
    score: float
    rationale: str
    strategy: str
    tags: list[str]
    source: str
    run_id: str | None
    created_at: str


class BrainstormRequest(BaseModel):
    topic: str = Field(min_length=2, max_length=200)
    context: Literal["personal", "business", "shared"] = "personal"
    n_candidates: int = Field(default=5, ge=2, le=10)
    take_top: int = Field(default=3, ge=1, le=10)


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
    ) -> None:
        self.settings = settings
        self.store = store
        self.tools = tools
        self.transport = transport

    async def run(self, request: AgentTaskRequest) -> AgentTaskResponse:
        run_id = self.store.create_run(request.objective, request.context)
        messages: list[dict[str, Any]] = [
            {
                "role": "system",
                "content": self._system_prompt(request.context, request.mode, self.store),
            },
            {"role": "user", "content": request.objective},
        ]
        approvals: list[dict[str, Any]] = []
        tool_results: list[dict[str, Any]] = []

        for _ in range(self.settings.agent_max_steps):
            response = await self._chat(
                messages,
                tools=[] if approvals else self.tools.schemas_for_mode(request.mode),
                model=self._model_for(request.mode),
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
                if status != "awaiting_approval":
                    await self._maybe_auto_improve(
                        run_id, request, message.content or "", tool_results
                    )
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
                        result = self.tools.execute(tool.name, call.function.arguments)
                    except (OSError, ValueError) as error:
                        result = {"error": str(error)}
                    self.store.record_event(
                        run_id,
                        "tool_executed",
                        {"tool": tool.name, "risk": tool.risk, "result": result},
                    )
                    tool_results.append({"tool": tool.name, "result": result})
                else:
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
        if status == "step_limit_reached" and tool_results:
            await self._maybe_auto_improve(
                run_id, request, self._fallback_message(approvals), tool_results
            )
        return AgentTaskResponse(
            run_id=run_id,
            status=status,
            message=self._fallback_message(approvals),
            approvals=[ApprovalView.model_validate(item) for item in approvals],
            tool_results=tool_results,
        )

    def _model_for(self, mode: str) -> str:
        if self.settings.llm_backend == "openai":
            return self.settings.llm_model or self.settings.ollama_model
        return self.settings.coding_model if mode == "developer" else self.settings.ollama_model

    async def _chat(
        self,
        messages: list[dict[str, Any]],
        tools: list[dict[str, Any]],
        model: str,
    ) -> OllamaAgentResponse:
        if self.settings.llm_backend == "openai":
            return await self._chat_openai(messages, tools, model)
        payload = {
            "model": model,
            "stream": False,
            "think": False,
            "messages": messages,
            "tools": tools,
        }
        try:
            async with httpx.AsyncClient(
                timeout=self.settings.ollama_timeout_seconds,
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

    async def _chat_openai(
        self,
        messages: list[dict[str, Any]],
        tools: list[dict[str, Any]],
        model: str,
    ) -> OllamaAgentResponse:
        """Call any OpenAI-compatible /v1 endpoint (for example, a local mlx-lm
        server on the Tank host) and normalize the reply into the internal
        Ollama-style response shape used by the rest of the agent loop."""
        base_url = (self.settings.llm_base_url or "").rstrip("/")
        if not base_url:
            raise AgentModelError(
                "llm_base_url is not configured for the openai backend"
            )
        payload: dict[str, Any] = {
            "model": model,
            "messages": self._to_openai_messages(messages),
            "tools": tools,
            "tool_choice": "auto",
        }
        headers = {"Content-Type": "application/json"}
        api_key = self.settings.llm_api_key
        if api_key is not None and api_key.get_secret_value():
            headers["Authorization"] = f"Bearer {api_key.get_secret_value()}"
        try:
            async with httpx.AsyncClient(
                timeout=self.settings.ollama_timeout_seconds,
                transport=self.transport,
            ) as client:
                response = await client.post(
                    f"{base_url}/chat/completions",
                    json=payload,
                    headers=headers,
                )
                response.raise_for_status()
            data = response.json()
            message = data["choices"][0]["message"]
        except (httpx.HTTPError, ValueError, KeyError, IndexError) as error:
            raise AgentModelError("Tank model could not complete the agent step") from error

        tool_calls: list[OllamaToolCall] = []
        for call in message.get("tool_calls") or []:
            function = call.get("function") or {}
            raw_arguments = function.get("arguments") or "{}"
            if isinstance(raw_arguments, str):
                try:
                    parsed_arguments = json.loads(raw_arguments)
                except json.JSONDecodeError:
                    parsed_arguments = {}
            else:
                parsed_arguments = raw_arguments
            if not isinstance(parsed_arguments, dict):
                parsed_arguments = {}
            tool_calls.append(
                OllamaToolCall(
                    type="function",
                    function=OllamaToolFunction(
                        name=str(function.get("name") or ""),
                        arguments=parsed_arguments,
                    ),
                )
            )
        return OllamaAgentResponse(
            message=OllamaAgentMessage(
                role="assistant",
                content=message.get("content") or "",
                tool_calls=tool_calls,
            )
        )

    async def _plain_chat(
        self, messages: list[dict[str, Any]], model: str
    ) -> str:
        """One-off text completion without the tool loop, used for the
        lightweight auto-improve reflection pass. Never raises; returns "" if the
        model is unavailable so reflection can never break the main run."""
        if self.settings.llm_backend == "openai":
            base_url = (self.settings.llm_base_url or "").rstrip("/")
            if not base_url:
                return ""
            payload = {"model": model, "messages": messages}
            headers = {"Content-Type": "application/json"}
            api_key = self.settings.llm_api_key
            if api_key is not None and api_key.get_secret_value():
                headers["Authorization"] = f"Bearer {api_key.get_secret_value()}"
            try:
                async with httpx.AsyncClient(
                    timeout=self.settings.ollama_timeout_seconds, transport=self.transport
                ) as client:
                    response = await client.post(
                        f"{base_url}/chat/completions", json=payload, headers=headers
                    )
                    response.raise_for_status()
                return response.json()["choices"][0]["message"].get("content") or ""
            except (httpx.HTTPError, ValueError, KeyError, IndexError):
                return ""
        try:
            async with httpx.AsyncClient(
                timeout=self.settings.ollama_timeout_seconds, transport=self.transport
            ) as client:
                response = await client.post(
                    f"{self.settings.ollama_base_url}/api/chat",
                    json={
                        "model": model,
                        "stream": False,
                        "think": False,
                        "messages": messages,
                    },
                )
                response.raise_for_status()
            return response.json().get("message", {}).get("content") or ""
        except (httpx.HTTPError, ValueError):
            return ""

    async def _maybe_auto_improve(
        self,
        run_id: str,
        request: AgentTaskRequest,
        final_message: str,
        tool_results: list[dict[str, Any]],
    ) -> None:
        """End-of-run self-improvement. A lightweight local-model pass distills the
        run into a durable insight and, when there is a clear reusable lesson, a
        draft skill. The draft skill is stored (status=draft) and surfaced as a
        proposal so the user can activate it. NEVER raises: improvement is best-effort
        and must not perturb the user-facing run."""
        if not self.settings.auto_improve_enabled:
            return
        if not tool_results and len(final_message.strip()) < self.settings.auto_improve_min_message_chars:
            return
        try:
            model = self.settings.auto_improve_model or self._model_for("assistant")
        except Exception:
            return
        transcript = json.dumps(
            {
                "objective": request.objective,
                "context": request.context,
                "tools_used": [t.get("tool") for t in tool_results],
                "summary": (final_message or "")[:600],
            },
            ensure_ascii=False,
        )
        system = (
            "You are NOBS's self-improvement pass. From a completed agent run transcript, "
            "distill one durable, generalizable insight. If — and only if — the run reveals a "
            "clear reusable lesson that would help future runs, also propose a new 'skill': a "
            "named instruction set with name, description, step-by-step instructions, and tags. "
            "Output STRICT JSON only with exactly this shape, no prose around it: "
            '{"insight": "...", "skill": {"name": "...", "description": "...", '
            '"instructions": "...", "tags": ["..."]}} — set "skill" to null when '
            "nothing is reusable."
        )
        reflect_msgs = [
            {"role": "system", "content": system},
            {"role": "user", "content": transcript},
        ]
        content = await self._mlx_chat(reflect_msgs) or await self._plain_chat(
            reflect_msgs, model
        )
        if not content:
            return
        parsed = self._parse_json_object(content)
        if not parsed:
            return
        insight = str(parsed.get("insight") or "").strip()
        skill = parsed.get("skill")
        try:
            if insight:
                self.store.record_insight(
                    run_id,
                    insight,
                    kind="recommendation" if skill else "observation",
                    detail={"tools_used": [t.get("tool") for t in tool_results]},
                )
        except (OSError, ValueError):
            return
        if not isinstance(skill, dict):
            return
        name = str(skill.get("name") or "").strip()
        description = str(skill.get("description") or "").strip()
        instructions = str(skill.get("instructions") or "").strip()
        if not (name and description and instructions):
            return
        try:
            if self.store.get_skill_by_name(name):
                return  # already known
            tags = [str(t).strip() for t in (skill.get("tags") or []) if str(t).strip()]
            self.store.create_skill(
                name,
                description,
                instructions,
                tags=tags,
                status="draft",
                source="auto",
                run_id=run_id,
            )
            self.store.create_proposal(
                f"Suggested skill: {name}",
                f"NOBS auto-learned this skill from a recent run. Review and activate it to "
                f"apply it in future runs.\n\n{description}",
                "optimization",
            )
        except (OSError, ValueError, KeyError):
            return

    @staticmethod
    def _parse_json_object(content: str) -> dict[str, Any] | None:
        content = content.strip()
        if content.startswith("```"):
            lines = content.splitlines()
            if len(lines) >= 2 and lines[-1].startswith("```"):
                content = "\n".join(lines[1:-1]).strip()
        try:
            data = json.loads(content)
            return data if isinstance(data, dict) else None
        except json.JSONDecodeError:
            pass
        start = content.find("{")
        end = content.rfind("}")
        if start != -1 and end > start:
            try:
                data = json.loads(content[start : end + 1])
                return data if isinstance(data, dict) else None
            except json.JSONDecodeError:
                return None
        return None

    async def brainstorm(
        self,
        topic: str,
        context: str = "personal",
        n_candidates: int = 5,
        take_top: int = 3,
    ) -> list[IdeaView]:
        """Let NOBS work through ideas: a lightweight local-model "council"
        generates candidate money-making ideas, then a deliberation pass scores
        them and surfaces the best of the best. Costs nothing (local model),
        never raises (best-effort), and persists the top picks to the idea bank.
        """
        if n_candidates < 1 or take_top < 1 or take_top > n_candidates:
            raise ValueError("n_candidates >= take_top >= 1 required")
        take_top = min(take_top, n_candidates)
        run_id = self.store.create_run(f"Brainstorm: {topic}", context)
        model = self._model_for("assistant")

        generate = (
            "You are NOBS's venture council. The user wants to brainstorm ways to make "
            f"money (going public, gaining paying users) around: '{topic}'. "
            f"Produce exactly {n_candidates} distinct, concrete, differentiated ideas. "
            "For each: title, description (2-3 sentences), a concrete strategy for "
            "execution and monetization, and 2-4 tags. Output STRICT JSON only: "
            'a JSON array of objects: [{"title": "...", "description": "...", '
            '"strategy": "...", "tags": ["..."]}]. No prose around it.'
        )
        generate_msgs = [
            {"role": "system", "content": generate},
            {"role": "user", "content": f"Context: {context}"},
        ]
        content = await self._mlx_chat(generate_msgs) or await self._plain_chat(
            generate_msgs, model
        )
        candidates = self._parse_json_array(content)
        candidates = candidates[:n_candidates]
        if not candidates:
            self.store.record_insight(
                run_id,
                f"Brainstorm on '{topic}' produced no usable candidates.",
                kind="observation",
            )
            return []

        scored: list[dict[str, Any]] = []
        for idx, candidate in enumerate(candidates):
            try:
                title = str(candidate.get("title") or "").strip()
                description = str(candidate.get("description") or "").strip()
                strategy = str(candidate.get("strategy") or "").strip()
                tags = [
                    str(t).strip()
                    for t in (candidate.get("tags") or [])
                    if str(t).strip()
                ]
                if not (title and description):
                    continue
                # Ask the model to critically score each candidate 0-10 with a
                # one-line rationale for why it would or would not make money.
                score_prompt = (
                    "Critically score this money-making idea for feasibility, market "
                    f"demand, and realistic path to paying users. Return STRICT JSON only "
                    f"and fill in real numbers: {{\"score\": <a number from 0 to 10, "
                    "e.g. 8.5>, \"rationale\": <one sentence of critical reasoning>}}. "
                    f"no prose around it.\n\nTitle: {title}\nDescription: {description}"
                )
                score_msgs = [
                    {"role": "system", "content": score_prompt},
                    {"role": "user", "content": strategy},
                ]
                raw = await self._mlx_chat(score_msgs) or await self._plain_chat(
                    score_msgs, model
                )
                parsed = self._parse_json_object(raw) or {}
                score = float(parsed.get("score", 0.0) or 0.0)
                score = max(0.0, min(10.0, score)) if score == score else 0.0
                rationale = str(parsed.get("rationale") or "").strip()
            except (ValueError, AttributeError, TypeError):
                continue
            scored.append(
                {
                    "title": title,
                    "description": description,
                    "strategy": strategy,
                    "tags": tags,
                    "score": round(score, 1),
                    "rationale": rationale,
                }
            )

        scored.sort(key=lambda item: item["score"], reverse=True)
        top = scored[:take_top]
        views: list[IdeaView] = []
        for item in top:
            idea = self.store.create_idea(
                item["title"],
                item["description"],
                strategy=item["strategy"],
                score=item["score"],
                rationale=item["rationale"],
                tags=item["tags"],
                source="brainstorm",
                run_id=run_id,
            )
            # Best-of-the-best: promote strong ideas to validated and surface as a
            # proposal the user reviews (consistent with the auto-learn flow).
            if item["score"] >= self.settings.venture_validate_score:
                self.store.update_idea(idea["id"], status="validated")
                self.store.create_proposal(
                    f"Venture idea: {item['title']}",
                    (
                        f"Score {item['score']}/10. {item['rationale']}\n\n"
                        f"Strategy: {item['strategy']}"
                    ),
                    "venture",
                )
            else:
                self.store.update_idea(idea["id"], status="deliberating")
            views.append(IdeaView.model_validate(self.store.get_idea(idea["id"])))
        return views

    @staticmethod
    def _parse_json_array(content: str) -> list[dict[str, Any]]:
        content = (content or "").strip()
        if content.startswith("```"):
            lines = content.splitlines()
            if len(lines) >= 2 and lines[-1].startswith("```"):
                content = "\n".join(lines[1:-1]).strip()
        try:
            data = json.loads(content)
            return data if isinstance(data, list) else []
        except json.JSONDecodeError:
            pass
        start = content.find("[")
        end = content.rfind("]")
        if start != -1 and end > start:
            try:
                data = json.loads(content[start : end + 1])
                return data if isinstance(data, list) else []
            except json.JSONDecodeError:
                return []
        return []

    async def _mlx_chat(
        self,
        messages: list[dict[str, Any]],
    ) -> str:
        """Offload lightweight ideation/self-improvement to the local Apple
        Silicon MLX server (M-series GPU), OpenAI-compatible /v1. Keeps the
        heavy conversation model on Ollama while warming the GPU — still $0.
        Never raises; returns "" on any failure so callers can fall back.
        """
        base_url = (self.settings.mlx_base_url or "").rstrip("/")
        model = (self.settings.venture_model or "").strip()
        if not base_url or not model:
            return ""
        payload = {"model": model, "messages": messages}
        try:
            async with httpx.AsyncClient(
                timeout=self.settings.ollama_timeout_seconds,
                transport=self.transport,
            ) as client:
                response = await client.post(
                    f"{base_url}/chat/completions",
                    json=payload,
                    headers={"Content-Type": "application/json"},
                )
                response.raise_for_status()
            return response.json()["choices"][0]["message"].get("content") or ""
        except (httpx.HTTPError, ValueError, KeyError, IndexError):
            return ""

    @staticmethod
    def _to_openai_messages(
        messages: list[dict[str, Any]],
    ) -> list[dict[str, Any]]:
        """Convert the internal Ollama-style message history into the OpenAI
        wire format. The agent loop stores assistant tool calls without ids and
        tool results as ``role=tool`` plus ``tool_name``; OpenAI-compatible
        endpoints require ``id``/``tool_call_id`` pairs and JSON-string
        arguments."""
        normalized: list[dict[str, Any]] = []
        pending_ids: list[str] = []
        for message in messages:
            role = message.get("role")
            if role == "assistant" and message.get("tool_calls"):
                tool_calls = []
                for index, call in enumerate(message["tool_calls"]):
                    function = call.get("function") or {}
                    call_id = call.get("id") or f"call_{len(normalized)}_{index}"
                    pending_ids.append(call_id)
                    tool_calls.append(
                        {
                            "id": call_id,
                            "type": "function",
                            "function": {
                                "name": function.get("name") or "",
                                "arguments": json.dumps(
                                    function.get("arguments") or {}
                                ),
                            },
                        }
                    )
                normalized.append(
                    {
                        "role": "assistant",
                        "content": message.get("content") or "",
                        "tool_calls": tool_calls,
                    }
                )
            elif role == "tool":
                call_id = pending_ids.pop(0) if pending_ids else f"call_{len(normalized)}"
                normalized.append(
                    {
                        "role": "tool",
                        "tool_call_id": call_id,
                        "content": str(message.get("content") or ""),
                    }
                )
            else:
                normalized.append(
                    {"role": role, "content": message.get("content") or ""}
                )
        return normalized

    def _system_prompt(self, context: str, mode: str, store: AgentStore | None = None) -> str:
        prompt = (
            "You are the NOBS agent running privately on Tank. You are in a bounded tool loop. "
            f"The active context is {context}. Never mix personal and business context unless the "
            "active context is shared. Use only the supplied tools. Read-only tools may run now. "
            "Any tool that changes state will be queued for explicit user approval. Never claim a "
            "queued action happened. Briefly explain what you learned or what approval is needed."
            " Connected accounts (Google/school/mail/calendar) are strictly gated: you must NEVER "
            "send, post, email, or externalize anything to them without explicit user approval. "
            "There is no auto-send. If in doubt, queue it for approval."
        )
        if mode == "developer":
            prompt += (
                " Developer mode may inspect only the configured NOBS project through bounded "
                "read-only tools. Cite relevant project-relative file paths. It cannot edit files, "
                "run commands or tests, read secrets, or access the network. Never claim that it did."
            )
        store = store or self.store
        if store is not None:
            skills = self._active_skill_prompt(store)
            if skills:
                prompt += (
                    "\n\nActive skills you have learned — apply these when relevant:\n" + skills
                )
        return prompt

    @staticmethod
    def _active_skill_prompt(store: AgentStore) -> str:
        """Render active skills as instructions the agent actually follows on
        future runs. This is the mechanism that makes auto-learned skills stick."""
        try:
            skills = store._active_skills()
        except (OSError, ValueError):
            return ""
        if not skills:
            return ""
        blocks = []
        for skill in skills:
            blocks.append(
                f"- {skill['name']} — {skill['description']}\n{skill['instructions']}"
            )
        return "\n\n".join(blocks)

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
