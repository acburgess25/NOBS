"""Dream Team Sandbox — local-first agent persona drafting, testing, and refinement.

All inference runs on Tank's local Ollama. No cloud, PCC, or external APIs are used
in the refinement loop. Sandbox tests may only call read-only, on-host tools.
"""

from __future__ import annotations

import json
import logging
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import httpx

from app.agent_store import AgentStore
from app.agent_tools import ToolRegistry
from app.config import Settings

logger = logging.getLogger(__name__)

# Read-only tools safe for sandbox (no external network, no state changes).
SANDBOX_READ_ONLY_TOOLS = frozenset(
    {
        "get_tank_status",
        "list_workspace_files",
        "read_workspace_file",
        "list_project_files",
        "read_project_file",
        "search_project_text",
    }
)

# Monitored browser sandbox — allowlisted URLs only; lights up workplace monitors.
WORKPLACE_COMPUTER_TOOLS = frozenset({"use_computer"})

# Tools that hit external services — excluded from sandbox refinement.
EXTERNAL_API_TOOLS = frozenset(
    {
        "web_search",
        "read_url",
        "lookup_wikipedia",
        "read_news_feeds",
        "get_weather",
    }
)

LOCAL_PROCESSING_LABEL = "Tank local Ollama (no cloud quota)"

# Schemas handed to Ollama's `format` parameter so decoding is constrained to
# the shape each step already expects. `suggested_tools` is still filtered
# against SANDBOX_READ_ONLY_TOOLS after generation: a schema controls shape,
# never permission, and the model must not be able to widen its own sandbox
# by naming a tool here.
_PERSONA_PROPERTIES: dict[str, Any] = {
    "tone": {"type": "string"},
    "specialty": {"type": "string"},
    "suggested_tools": {"type": "array", "items": {"type": "string"}},
    "sample_objective": {"type": "string"},
}

AGENT_DRAFTS_SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {
        "agents": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "name": {"type": "string"},
                    "role": {"type": "string"},
                    **_PERSONA_PROPERTIES,
                },
                "required": ["name", "role", "tone", "specialty", "sample_objective"],
            },
        }
    },
    "required": ["agents"],
}

PERSONA_REFINEMENT_SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {
        "persona": {
            "type": "object",
            "properties": {
                **_PERSONA_PROPERTIES,
                "system_prompt": {"type": "string"},
            },
            "required": ["tone", "specialty", "sample_objective", "system_prompt"],
        }
    },
    "required": ["persona"],
}


class DreamTeamModelError(RuntimeError):
    pass


@dataclass(frozen=True)
class LocalFirstPolicy:
    """Documents what runs locally vs what would cost cloud quota."""

    inference: str = LOCAL_PROCESSING_LABEL
    storage: str = "SQLite + local filesystem under data/dream-team/"
    sandbox_tools: str = "Read-only on-host tools only; no external APIs"
    cloud_quota_used: bool = False
    external_apis_in_loop: bool = False

    def as_dict(self) -> dict[str, Any]:
        return {
            "inference": self.inference,
            "storage": self.storage,
            "sandbox_tools": self.sandbox_tools,
            "cloud_quota_used": self.cloud_quota_used,
            "external_apis_in_loop": self.external_apis_in_loop,
        }


class DreamTeamSandbox:
    """Draft, sandbox-test, score, refine, and propose a team of agent personas."""

    def __init__(
        self,
        settings: Settings,
        store: AgentStore,
        tools: ToolRegistry,
        transport: httpx.AsyncBaseTransport | None = None,
        browser_sandbox: Any | None = None,
    ) -> None:
        self.settings = settings
        self.store = store
        self.tools = tools
        self.transport = transport
        self.browser_sandbox = browser_sandbox
        self.policy = LocalFirstPolicy()
        self.sandbox_root = settings.dream_team_sandbox_path
        self.active_root = settings.dream_team_active_path

    @property
    def model(self) -> str:
        return self.settings.dream_team_model or self.settings.ollama_model

    async def run_session(self, session_id: str) -> dict[str, Any]:
        session = self.store.get_dream_team_session(session_id)
        if session["status"] not in {"queued", "failed"}:
            raise ValueError("Session is already running or finished")

        self.store.update_dream_team_session(session_id, "running")
        llm_calls = 0

        try:
            sandbox_dir = self._ensure_sandbox_dir(session_id)
            drafts, llm_calls = await self._draft_team(session, llm_calls)
            refined: list[dict[str, Any]] = []

            for draft in drafts[: self.settings.dream_team_max_agents]:
                tested, llm_calls = await self._sandbox_test(draft, session, sandbox_dir, llm_calls)
                score = self._heuristic_score(tested)
                tested = self.store.update_dream_team_draft(
                    tested["id"],
                    score=score,
                    status="tested",
                    test_result=tested.get("test_result"),
                )

                current = tested
                iteration = 0
                while (
                    score < self.settings.dream_team_score_threshold
                    and iteration < self.settings.dream_team_max_iterations
                ):
                    current, llm_calls = await self._refine_draft(
                        current, session, score, iteration + 1, llm_calls
                    )
                    current, llm_calls = await self._sandbox_test(
                        current, session, sandbox_dir, llm_calls
                    )
                    score = self._heuristic_score(current)
                    current = self.store.update_dream_team_draft(
                        current["id"],
                        score=score,
                        status="refined",
                        persona=current.get("persona"),
                        test_result=current.get("test_result"),
                    )
                    self.store.record_dream_team_iteration(
                        draft_id=current["id"],
                        iteration=iteration + 1,
                        changes={"refined_persona": current.get("persona")},
                        score=score,
                        notes="Local heuristic re-score after refinement",
                    )
                    iteration += 1

                refined.append(self.store.update_dream_team_draft(current["id"], status="selected"))

            proposal = self._build_proposal(session, refined, llm_calls)
            self.store.update_dream_team_session(
                session_id,
                "proposed",
                result_summary=proposal["summary"],
            )
            return self.store.get_dream_team_session(session_id, include_details=True)

        except (DreamTeamModelError, OSError, ValueError) as error:
            logger.exception("Dream team session %s failed", session_id)
            self.store.update_dream_team_session(session_id, "failed", result_summary=str(error))
            raise

    def approve_proposal(self, proposal_id: str) -> dict[str, Any]:
        proposal = self.store.decide_dream_team_proposal(proposal_id, "approved")
        session = self.store.get_dream_team_session(proposal["session_id"], include_details=True)
        self.active_root.mkdir(parents=True, exist_ok=True)
        for member in proposal["members"]:
            manifest = {
                "name": member["name"],
                "role": member["role"],
                "persona": member["persona"],
                "score": member.get("score"),
                "approved_at": proposal["decided_at"],
                "processing": self.policy.as_dict(),
            }
            slug = _slugify(member["name"])
            path = self.active_root / f"{slug}.json"
            path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
        self.store.update_dream_team_session(proposal["session_id"], "approved")
        return {"proposal": proposal, "session": session, "active_manifests": len(proposal["members"])}

    def reject_proposal(self, proposal_id: str) -> dict[str, Any]:
        proposal = self.store.decide_dream_team_proposal(proposal_id, "rejected")
        self.store.update_dream_team_session(proposal["session_id"], "rejected")
        return proposal

    async def _draft_team(
        self, session: dict[str, Any], llm_calls: int
    ) -> tuple[list[dict[str, Any]], int]:
        prompt = (
            "You are designing a small 'dream team' of NOBS agent personas for a private home Tank. "
            f"User objective: {session['objective']}\n"
            f"Context: {session['context']}\n"
            f"Create {self.settings.dream_team_max_agents} complementary agent personas. "
            "Return ONLY JSON: {\"agents\": [{\"name\": str, \"role\": str, \"tone\": str, "
            "\"specialty\": str, \"suggested_tools\": [str], \"sample_objective\": str}]}. "
            "suggested_tools must be from: get_tank_status, list_workspace_files, read_workspace_file. "
            "Keep personas concise and practical."
        )
        raw = await self._ollama_json(prompt, AGENT_DRAFTS_SCHEMA)
        llm_calls += 1
        agents = raw.get("agents", [])
        if not isinstance(agents, list) or not agents:
            raise DreamTeamModelError("Local model did not return agent drafts")

        drafts: list[dict[str, Any]] = []
        for agent in agents[: self.settings.dream_team_max_agents]:
            if not isinstance(agent, dict):
                continue
            persona = {
                "tone": str(agent.get("tone", "warm, concise")),
                "specialty": str(agent.get("specialty", "")),
                "suggested_tools": [
                    t
                    for t in agent.get("suggested_tools", [])
                    if t in SANDBOX_READ_ONLY_TOOLS
                ],
                "sample_objective": str(agent.get("sample_objective", session["objective"])),
                "system_prompt": (
                    f"You are {agent.get('name', 'Agent')}, a NOBS specialist. "
                    f"Tone: {agent.get('tone', 'warm')}. "
                    f"Focus: {agent.get('specialty', '')}."
                ),
            }
            drafts.append(
                self.store.create_dream_team_draft(
                    session_id=session["id"],
                    name=str(agent.get("name", "Specialist"))[:80],
                    role=str(agent.get("role", "assistant"))[:120],
                    persona=persona,
                )
            )
        if not drafts:
            raise DreamTeamModelError("No valid agent drafts parsed")
        return drafts, llm_calls

    async def _sandbox_test(
        self,
        draft: dict[str, Any],
        session: dict[str, Any],
        sandbox_dir: Path,
        llm_calls: int,
    ) -> tuple[dict[str, Any], int]:
        """Run a short local sandbox loop with read-only tools only."""
        test_objective = draft["persona"].get("sample_objective") or session["objective"]
        tool_results: list[dict[str, Any]] = []
        messages: list[dict[str, Any]] = [
            {
                "role": "system",
                "content": (
                    f"{draft['persona'].get('system_prompt', '')} "
                    "SANDBOX MODE: read-only tools only. No state changes. "
                    f"Active context: {session['context']}."
                ),
            },
            {"role": "user", "content": test_objective},
        ]
        schemas = self._sandbox_tool_schemas(draft)
        final_message = ""

        for _ in range(self.settings.dream_team_sandbox_max_steps):
            response = await self._ollama_chat(messages, tools=schemas)
            llm_calls += 1
            message = response.get("message", {})
            content = (message.get("content") or "").strip()
            tool_calls = message.get("tool_calls") or []

            if not tool_calls:
                final_message = content
                break

            messages.append(message)
            for call in tool_calls[:2]:
                fn = call.get("function", {})
                name = fn.get("name", "")
                args = fn.get("arguments", {})
                if isinstance(args, str):
                    try:
                        args = json.loads(args)
                    except json.JSONDecodeError:
                        args = {}
                if name not in SANDBOX_READ_ONLY_TOOLS and name not in WORKPLACE_COMPUTER_TOOLS:
                    result: dict[str, Any] = {
                        "error": f"Tool {name} is not available in sandbox",
                    }
                elif name == "use_computer":
                    result = self._use_computer_tool(draft, args if isinstance(args, dict) else {})
                else:
                    try:
                        result = self.tools.execute(name, args if isinstance(args, dict) else {})
                    except (OSError, ValueError) as error:
                        result = {"error": str(error)}
                tool_results.append({"tool": name, "result": result})
                messages.append(
                    {
                        "role": "tool",
                        "tool_name": name,
                        "content": json.dumps(result),
                    }
                )
        else:
            final_message = final_message or "Sandbox step limit reached without completion."

        test_result = {
            "objective": test_objective,
            "response": final_message,
            "tool_results": tool_results,
            "sandbox_path": str(sandbox_dir),
            "processing": self.policy.as_dict(),
        }
        draft = dict(draft)
        draft["test_result"] = test_result
        return draft, llm_calls

    async def _refine_draft(
        self,
        draft: dict[str, Any],
        session: dict[str, Any],
        score: float,
        iteration: int,
        llm_calls: int,
    ) -> tuple[dict[str, Any], int]:
        test_result = draft.get("test_result") or {}
        prompt = (
            "Improve this NOBS agent persona based on sandbox feedback. "
            "Return ONLY JSON: {\"persona\": {\"tone\": str, \"specialty\": str, "
            "\"suggested_tools\": [str], \"sample_objective\": str, \"system_prompt\": str}}.\n"
            f"Objective: {session['objective']}\n"
            f"Current name: {draft['name']}\n"
            f"Current role: {draft['role']}\n"
            f"Score: {score:.2f}\n"
            f"Sandbox response: {test_result.get('response', '')}\n"
            f"Iteration: {iteration}"
        )
        raw = await self._ollama_json(prompt, PERSONA_REFINEMENT_SCHEMA)
        llm_calls += 1
        persona = raw.get("persona", {})
        if not isinstance(persona, dict):
            persona = draft["persona"]
        else:
            persona["suggested_tools"] = [
                t for t in persona.get("suggested_tools", []) if t in SANDBOX_READ_ONLY_TOOLS
            ]
        updated = self.store.update_dream_team_draft(
            draft["id"],
            persona=persona,
            iteration=iteration,
            status="refining",
        )
        return updated, llm_calls

    def _build_proposal(
        self,
        session: dict[str, Any],
        drafts: list[dict[str, Any]],
        llm_calls: int,
    ) -> dict[str, Any]:
        members = [
            {
                "draft_id": d["id"],
                "name": d["name"],
                "role": d["role"],
                "persona": d["persona"],
                "score": d.get("score"),
                "test_summary": (d.get("test_result") or {}).get("response", "")[:300],
            }
            for d in drafts
        ]
        avg_score = sum(m.get("score") or 0 for m in members) / max(len(members), 1)
        summary = (
            f"Dream team of {len(members)} agents for: {session['objective'][:200]}. "
            f"Average sandbox score: {avg_score:.0%}. "
            f"All refinement used {llm_calls} local Ollama call(s); no cloud quota."
        )
        title = f"Dream team: {session['objective'][:60]}"
        return self.store.create_dream_team_proposal(
            session_id=session["id"],
            title=title,
            summary=summary,
            members=members,
            metadata={
                "local_first_policy": self.policy.as_dict(),
                "llm_calls": llm_calls,
                "external_tools_excluded": sorted(EXTERNAL_API_TOOLS),
            },
        )

    def _heuristic_score(self, draft: dict[str, Any]) -> float:
        """Score without extra LLM calls — keeps refinement loop resource-light."""
        persona = draft.get("persona") or {}
        test = draft.get("test_result") or {}
        score = 0.0
        required = ("tone", "specialty", "system_prompt", "sample_objective")
        score += 0.25 * sum(1 for key in required if persona.get(key)) / len(required)
        tools = persona.get("suggested_tools") or []
        if tools and all(t in SANDBOX_READ_ONLY_TOOLS for t in tools):
            score += 0.15
        response = (test.get("response") or "").strip()
        if response:
            score += 0.2
            if 40 <= len(response) <= 800:
                score += 0.1
        if test.get("tool_results"):
            successes = sum(
                1 for tr in test["tool_results"] if "error" not in (tr.get("result") or {})
            )
            score += 0.2 * (successes / len(test["tool_results"]))
        elif response:
            score += 0.1
        if "error" in response.lower()[:100]:
            score -= 0.1
        return round(min(max(score, 0.0), 1.0), 3)

    def _use_computer_tool(self, draft: dict[str, Any], args: dict[str, Any]) -> dict[str, Any]:
        if self.browser_sandbox is None:
            return {"error": "Workplace browser sandbox is not available"}
        url = str(args.get("url", "")).strip()
        if not url:
            return {"error": "url is required"}
        from app.workplace import BrowserSandboxError

        agent_id = _slugify(draft["name"])
        try:
            session = self.browser_sandbox.create_session(agent_id, url)
        except BrowserSandboxError as error:
            return {"error": str(error)}
        return {
            "session_id": session["id"],
            "url": session["url"],
            "screenshot_url": f"/workplace/browser/sessions/{session['id']}/screenshot",
            "message": "Computer session started on workplace monitor",
        }

    def _sandbox_tool_schemas(self, draft: dict[str, Any]) -> list[dict[str, Any]]:
        suggested = set(draft.get("persona", {}).get("suggested_tools") or [])
        allowed = suggested & SANDBOX_READ_ONLY_TOOLS or SANDBOX_READ_ONLY_TOOLS
        schemas = [
            self.tools.get(name).ollama_schema()
            for name in sorted(allowed)
            if self.tools.get(name) is not None
        ]
        if self.browser_sandbox is not None:
            schemas.append(
                {
                    "type": "function",
                    "function": {
                        "name": "use_computer",
                        "description": (
                            "Open an allowlisted URL in the monitored workplace browser. "
                            "Shown live on the Tank workplace dashboard."
                        ),
                        "parameters": {
                            "type": "object",
                            "required": ["url"],
                            "properties": {
                                "url": {"type": "string", "maxLength": 2000},
                            },
                            "additionalProperties": False,
                        },
                    },
                }
            )
        return schemas

    def _ensure_sandbox_dir(self, session_id: str) -> Path:
        # Resolve the root before comparing. The configured sandbox path is
        # relative by default, and a relative root is never a parent of a
        # resolved absolute child, so comparing the two rejected every valid
        # session id. Creating the root first also keeps symlink resolution
        # consistent between the root and the child (macOS /tmp, for example).
        root = self.sandbox_root.resolve()
        root.mkdir(parents=True, exist_ok=True)
        root = root.resolve()
        path = (root / session_id).resolve()
        if root not in path.parents and path != root:
            raise ValueError("Sandbox path escapes root")
        path.mkdir(parents=True, exist_ok=True)
        return path

    async def _ollama_json(self, prompt: str, schema: dict[str, Any]) -> dict[str, Any]:
        """Ask the local model for one JSON object shaped by `schema`.

        The schema is handed to Ollama as the `format` parameter, so decoding
        itself is constrained (Ollama 0.5+). The model cannot emit markdown
        fences or commentary around the object, which is why nothing here
        strips them. A malformed body now means the request genuinely failed
        rather than the model having wandered off-format.
        """
        messages = [
            {"role": "system", "content": "Return valid JSON only."},
            {"role": "user", "content": prompt},
        ]
        response = await self._ollama_chat(messages, tools=[], json_format=schema)
        content = (response.get("message", {}).get("content") or "").strip()
        try:
            data = json.loads(content)
            return data if isinstance(data, dict) else {}
        except json.JSONDecodeError as error:
            raise DreamTeamModelError("Local model returned invalid JSON") from error

    async def _ollama_chat(
        self,
        messages: list[dict[str, Any]],
        tools: list[dict[str, Any]],
        json_format: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        payload: dict[str, Any] = {
            "model": self.model,
            "stream": False,
            "think": False,
            "messages": messages,
            "tools": tools,
        }
        if json_format is not None:
            payload["format"] = json_format
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
            return response.json()
        except (httpx.HTTPError, ValueError) as error:
            raise DreamTeamModelError("Local Ollama could not complete dream team step") from error


def _slugify(value: str) -> str:
    import re

    slug = re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")
    return slug[:60] or "agent"
