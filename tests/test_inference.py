"""Provider layer tests: LM Studio must behave exactly like Ollama upstream.

Every route, the agent loop, the dream team, and the optimizer speak Ollama's
dialect, so what matters is that selecting LM Studio changes the wire traffic
and nothing else. These tests assert both halves: the request that leaves Tank
and the Ollama-shaped result handed back to the caller.
"""

from __future__ import annotations

import asyncio
import json
import tempfile
from pathlib import Path
from typing import Any

import httpx
import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.inference import chat, list_models, model_available, provider_label, resolve_model
from app.main import create_app

TOKEN = "test-device-token"


def lmstudio_settings(**overrides: Any) -> Settings:
    defaults: dict[str, Any] = {
        "inference_provider": "lmstudio",
        "lmstudio_base_url": "http://127.0.0.1:1234",
        "agent_database_path": Path(":memory:"),
        "agent_workspace_path": Path(tempfile.mkdtemp()),
    }
    return Settings(**{**defaults, **overrides})


def recorder(response: httpx.Response) -> tuple[httpx.MockTransport, list[httpx.Request]]:
    seen: list[httpx.Request] = []

    def handler(request: httpx.Request) -> httpx.Response:
        seen.append(request)
        return response

    return httpx.MockTransport(handler), seen


def completion(content: str = "ready", **message: Any) -> httpx.Response:
    return httpx.Response(
        200,
        json={
            "model": "qwen/qwen3-8b",
            "choices": [
                {"index": 0, "message": {"role": "assistant", "content": content, **message}}
            ],
        },
    )


def test_ollama_provider_is_unchanged() -> None:
    settings = Settings()
    transport, seen = recorder(httpx.Response(200, json={"message": {"content": "hi"}}))

    result = asyncio.run(
        chat(settings, {"model": "qwen3:8b", "messages": [], "think": False}, transport)
    )

    assert str(seen[0].url) == "http://127.0.0.1:11434/api/chat"
    assert json.loads(seen[0].content) == {"model": "qwen3:8b", "messages": [], "think": False}
    assert result == {"message": {"content": "hi"}}


def test_lmstudio_chat_translates_request_and_response() -> None:
    settings = lmstudio_settings(lmstudio_model="qwen/qwen3-8b")
    transport, seen = recorder(completion("hello"))

    result = asyncio.run(
        chat(
            settings,
            {
                "model": "qwen3:8b",
                "stream": False,
                "think": False,
                "messages": [{"role": "user", "content": "hi"}],
            },
            transport,
        )
    )

    assert str(seen[0].url) == "http://127.0.0.1:1234/v1/chat/completions"
    body = json.loads(seen[0].content)
    assert body["model"] == "qwen/qwen3-8b"
    assert body["messages"] == [{"role": "user", "content": "hi"}]
    # `think` has no OpenAI equivalent and must not be forwarded verbatim.
    assert "think" not in body
    assert result["message"] == {"role": "assistant", "content": "hello"}
    assert result["done"] is True


def test_lmstudio_base_url_may_already_include_v1() -> None:
    settings = lmstudio_settings(lmstudio_base_url="http://tank.local:1234/v1/")
    transport, seen = recorder(completion())

    asyncio.run(chat(settings, {"model": "qwen3:8b", "messages": []}, transport))

    assert str(seen[0].url) == "http://tank.local:1234/v1/chat/completions"


def test_lmstudio_json_format_becomes_a_json_schema_response_format() -> None:
    settings = lmstudio_settings()
    schema = {"title": "Briefing", "type": "object", "properties": {"topline": {"type": "string"}}}
    transport, seen = recorder(completion('{"topline": "ok"}'))

    asyncio.run(chat(settings, {"model": "qwen3:8b", "messages": [], "format": schema}, transport))

    body = json.loads(seen[0].content)
    assert body["response_format"] == {
        "type": "json_schema",
        "json_schema": {"name": "Briefing", "strict": True, "schema": schema},
    }
    assert "format" not in body


def test_lmstudio_tool_calls_round_trip_through_ollama_shape() -> None:
    settings = lmstudio_settings()
    transport, seen = recorder(
        completion(
            "",
            tool_calls=[
                {
                    "id": "call_abc",
                    "type": "function",
                    "function": {
                        "name": "get_tank_status",
                        "arguments": '{"context": "personal"}',
                    },
                }
            ],
        )
    )

    messages = [
        {"role": "user", "content": "status?"},
        {
            "role": "assistant",
            "content": "",
            "tool_calls": [
                {"type": "function", "function": {"name": "get_tank_status", "arguments": {}}}
            ],
        },
        {"role": "tool", "tool_name": "get_tank_status", "content": '{"ok": true}'},
    ]
    payload = {
        "model": "qwen3:8b",
        "messages": messages,
        "tools": [{"type": "function", "function": {"name": "get_tank_status"}}],
    }

    result = asyncio.run(chat(settings, payload, transport))

    body = json.loads(seen[0].content)
    # The assistant call is given an id and the following result is paired to it,
    # which is the pairing the agent loop relies on when it appends results in order.
    call_id = body["messages"][1]["tool_calls"][0]["id"]
    assert body["messages"][1]["tool_calls"][0]["function"]["arguments"] == "{}"
    assert body["messages"][2] == {
        "role": "tool",
        "content": '{"ok": true}',
        "tool_call_id": call_id,
        "name": "get_tank_status",
    }
    assert body["tools"] == [{"type": "function", "function": {"name": "get_tank_status"}}]
    # Arguments come back as a dict, so the agent's tool registry can call it.
    assert result["message"]["tool_calls"] == [
        {
            "type": "function",
            "function": {"name": "get_tank_status", "arguments": {"context": "personal"}},
        }
    ]


def test_lmstudio_unusable_body_yields_an_empty_message_not_a_crash() -> None:
    settings = lmstudio_settings()
    transport, _ = recorder(httpx.Response(200, json={"error": "no model loaded"}))

    result = asyncio.run(chat(settings, {"model": "qwen3:8b", "messages": []}, transport))

    assert result["message"]["content"] == ""


def test_lmstudio_http_errors_still_surface_as_httpx_errors() -> None:
    settings = lmstudio_settings()
    transport, _ = recorder(httpx.Response(503, json={"error": "unavailable"}))

    with pytest.raises(httpx.HTTPStatusError):
        asyncio.run(chat(settings, {"model": "qwen3:8b", "messages": []}, transport))


def test_list_models_reads_each_provider_catalog() -> None:
    ollama_transport, ollama_seen = recorder(
        httpx.Response(200, json={"models": [{"name": "qwen3:8b"}]})
    )
    assert asyncio.run(list_models(Settings(), ollama_transport)) == ["qwen3:8b"]
    assert str(ollama_seen[0].url) == "http://127.0.0.1:11434/api/tags"

    lm_transport, lm_seen = recorder(
        httpx.Response(200, json={"data": [{"id": "qwen/qwen3-8b"}, {"id": "nomic-embed-text"}]})
    )
    models = asyncio.run(list_models(lmstudio_settings(), lm_transport))
    assert models == ["qwen/qwen3-8b", "nomic-embed-text"]
    assert str(lm_seen[0].url) == "http://127.0.0.1:1234/v1/models"


def test_resolve_model_only_remaps_the_configured_names() -> None:
    settings = lmstudio_settings(
        lmstudio_model="qwen/qwen3-8b",
        lmstudio_coding_model="qwen/qwen2.5-coder-14b",
    )

    assert resolve_model(settings, "qwen3:8b") == "qwen/qwen3-8b"
    assert resolve_model(settings, "qwen2.5-coder:14b") == "qwen/qwen2.5-coder-14b"
    assert resolve_model(settings, "some-other-model") == "some-other-model"
    # Without a mapping the Ollama name is sent through untouched.
    assert resolve_model(lmstudio_settings(), "qwen3:8b") == "qwen3:8b"
    # The Ollama provider never remaps.
    assert resolve_model(Settings(), "qwen3:8b") == "qwen3:8b"


def test_model_available_allows_an_implicit_ollama_tag() -> None:
    assert model_available("qwen3", ["qwen3:8b"])
    assert model_available("qwen/qwen3-8b", ["qwen/qwen3-8b"])
    assert not model_available("qwen3:8b", ["llama3:8b"])


def test_provider_label_names_the_selected_server() -> None:
    assert provider_label(Settings()) == "Ollama"
    assert provider_label(lmstudio_settings()) == "LM Studio"


def test_chat_route_serves_lm_studio_end_to_end() -> None:
    """The iPhone contract is unchanged when Tank is pointed at LM Studio."""
    settings = lmstudio_settings(device_token=TOKEN, agent_project_path=Path.cwd())
    app = create_app(settings)
    transport, seen = recorder(completion("Here is your plan."))
    app.state.ollama_transport = transport

    response = TestClient(app).post(
        "/chat",
        json={"messages": [{"role": "user", "content": "plan my day"}]},
        headers={"Authorization": f"Bearer {TOKEN}"},
    )

    assert response.status_code == 200
    assert response.json()["message"] == "Here is your plan."
    assert response.json()["route"] == "Tank"
    assert str(seen[0].url) == "http://127.0.0.1:1234/v1/chat/completions"


def test_dashboard_reports_the_lm_studio_provider() -> None:
    settings = lmstudio_settings(
        device_token=TOKEN,
        lmstudio_model="qwen/qwen3-8b",
        agent_project_path=Path.cwd(),
    )
    app = create_app(settings)
    app.state.ollama_transport = httpx.MockTransport(
        lambda _: httpx.Response(200, json={"data": [{"id": "qwen/qwen3-8b"}]})
    )

    payload = TestClient(app).get("/dashboard/status").json()

    assert payload["services"]["ollama"] == {
        "status": "online",
        "model": "qwen/qwen3-8b",
        "provider": "LM Studio",
    }


def test_agent_tool_loop_completes_through_lm_studio(tmp_path: Path) -> None:
    """The full agent loop, not just one translated request.

    The second turn is the risky one: Tank replays its own assistant message and
    the tool result back to the server, and LM Studio rejects a tool result that
    is not paired to a call id. This asserts the pairing survives the round trip.
    """
    calls = 0

    def handler(request: httpx.Request) -> httpx.Response:
        nonlocal calls
        calls += 1
        body = json.loads(request.content)
        assert str(request.url).endswith("/v1/chat/completions")
        assert body["model"] == "qwen/qwen3-8b"
        if calls == 1:
            return completion(
                "",
                tool_calls=[
                    {
                        "id": "call_1",
                        "type": "function",
                        "function": {"name": "get_tank_status", "arguments": "{}"},
                    }
                ],
            )
        # Turn two: the replayed call and its result must reference the same id.
        assistant, result = body["messages"][-2], body["messages"][-1]
        assert result["role"] == "tool"
        assert result["tool_call_id"] == assistant["tool_calls"][0]["id"]
        return completion("Tank is healthy.")

    settings = lmstudio_settings(
        device_token=TOKEN,
        lmstudio_model="qwen/qwen3-8b",
        agent_workspace_path=tmp_path,
        agent_project_path=Path.cwd(),
    )
    app = create_app(settings)
    app.state.ollama_transport = httpx.MockTransport(handler)

    response = TestClient(app).post(
        "/agent/tasks",
        json={"objective": "Check Tank", "context": "business"},
        headers={"Authorization": f"Bearer {TOKEN}"},
    )

    assert response.status_code == 200
    payload = response.json()
    assert payload["status"] == "completed"
    assert payload["message"] == "Tank is healthy."
    assert payload["tool_results"][0]["tool"] == "get_tank_status"
