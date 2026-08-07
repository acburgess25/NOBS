"""Tests for the OpenAI-compatible (mlx-lm) LLM backend and the NOBS docs
brain search tool."""

import json
import sqlite3
from pathlib import Path

import httpx
from fastapi.testclient import TestClient

from app.config import Settings
from app.main import create_app

from tests.test_chat import TOKEN, auth


def mlx_client(
    transport: httpx.BaseTransport | None = None,
    brain_db: Path | None = None,
) -> TestClient:
    settings = Settings(
        device_token=TOKEN,
        agent_database_path=Path(":memory:"),
        llm_backend="openai",
        llm_base_url="http://127.0.0.1:8081/v1",
        llm_model="mlx-community/Qwen2.5-1.5B-Instruct-4bit",
        brain_db_path=brain_db,
        auto_improve_enabled=False,
    )
    app = create_app(settings)
    if transport is not None:
        app.state.ollama_transport = transport
    return TestClient(app)


def _openai_message(content: str = "", tool_calls: list[dict] | None = None) -> dict:
    message: dict = {"role": "assistant", "content": content}
    if tool_calls:
        message["tool_calls"] = tool_calls
    return {"choices": [{"message": message}], "model": "mlx-community/Qwen2.5-1.5B-Instruct-4bit"}


def _tool_call(name: str, arguments: str | dict) -> dict:
    return {
        "id": "call_1",
        "type": "function",
        "function": {"name": name, "arguments": arguments},
    }


def test_openai_backend_completes_read_only_tool_loop() -> None:
    calls = 0

    def handler(request: httpx.Request) -> httpx.Response:
        nonlocal calls
        calls += 1
        payload = json.loads(request.content)
        assert request.url.path.endswith("/chat/completions")
        assert payload["model"] == "mlx-community/Qwen2.5-1.5B-Instruct-4bit"
        assert payload["tool_choice"] == "auto"
        if calls == 1:
            return httpx.Response(
                200,
                json=_openai_message(tool_calls=[_tool_call("get_tank_status", "{}")]),
            )
        # Second request must be OpenAI wire format: assistant tool_calls carry
        # an id and string arguments; the tool result references that id.
        assistant = payload["messages"][-2]
        assert assistant["role"] == "assistant"
        assert assistant["tool_calls"][0]["function"]["arguments"] == "{}"
        call_id = assistant["tool_calls"][0]["id"]
        assert payload["messages"][-1]["role"] == "tool"
        assert payload["messages"][-1]["tool_call_id"] == call_id
        return httpx.Response(200, json=_openai_message("Tank is healthy via MLX."))

    response = mlx_client(httpx.MockTransport(handler)).post(
        "/agent/tasks",
        json={"objective": "Check Tank", "context": "personal"},
        headers=auth(),
    )

    assert response.status_code == 200
    payload = response.json()
    assert payload["status"] == "completed"
    assert payload["message"] == "Tank is healthy via MLX."
    assert payload["tool_results"][0]["tool"] == "get_tank_status"


def test_openai_backend_parses_string_arguments_and_final_reply() -> None:
    calls = 0

    def handler(request: httpx.Request) -> httpx.Response:
        nonlocal calls
        calls += 1
        payload = json.loads(request.content)
        if calls == 1:
            return httpx.Response(
                200,
                json=_openai_message(
                    tool_calls=[
                        _tool_call("search_nobs_docs", json.dumps({"query": "Tank approval", "limit": 2}))
                    ]
                ),
            )
        assert payload["messages"][-1]["role"] == "tool"
        return httpx.Response(200, json=_openai_message("No brain yet."))

    brain = Path(__file__).parent / "missing-brain.db"
    response = mlx_client(httpx.MockTransport(handler), brain_db=brain).post(
        "/agent/tasks",
        json={"objective": "Search the docs", "context": "shared"},
        headers=auth(),
    )

    assert response.status_code == 200
    result = response.json()["tool_results"][0]["result"]
    assert "not available" in result["error"]


def test_search_nobs_docs_tool_returns_ranked_matches(tmp_path: Path) -> None:
    brain = tmp_path / "brain.db"
    connection = sqlite3.connect(brain)
    connection.execute("CREATE VIRTUAL TABLE docs USING fts5(path UNINDEXED, title, body)")
    connection.execute(
        "INSERT INTO docs(path,title,body) VALUES(?,?,?)",
        (
            "/docs/TANK_AGENT_CORE.md",
            "TANK_AGENT_CORE.md",
            "The Tank approval queue is atomic, audited, and non-replayable.",
        ),
    )
    connection.execute(
        "INSERT INTO docs(path,title,body) VALUES(?,?,?)",
        ("/docs/PRD.md", "PRD.md", "NOBS is a privacy-first local assistant."),
    )
    connection.commit()
    connection.close()

    calls = 0

    def handler(request: httpx.Request) -> httpx.Response:
        nonlocal calls
        calls += 1
        if calls == 1:
            return httpx.Response(
                200,
                json=_openai_message(
                    tool_calls=[_tool_call("search_nobs_docs", json.dumps({"query": "Tank approval"}))]
                ),
            )
        return httpx.Response(200, json=_openai_message("Found the docs."))

    response = mlx_client(httpx.MockTransport(handler), brain_db=brain).post(
        "/agent/tasks",
        json={"objective": "Search the docs", "context": "personal"},
        headers=auth(),
    )

    assert response.status_code == 200
    payload = response.json()
    assert payload["status"] == "completed"
    result = payload["tool_results"][0]["result"]
    assert result["count"] == 1
    assert result["matches"][0]["path"].endswith("TANK_AGENT_CORE.md")
