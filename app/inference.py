"""Local inference providers for Tank — Ollama and LM Studio.

Tank speaks one internal dialect: Ollama's ``/api/chat`` request and response
shape. Every call site already builds and parses it, so that stays the shared
language and the translation to another server's dialect happens here, at the
boundary, instead of spreading provider branches through chat, briefing, agent,
dream team, and optimizer code.

LM Studio serves the OpenAI-compatible dialect (``/v1/chat/completions``,
``/v1/models``), so this module rewrites requests and responses when that
provider is selected. Selection is configuration only: with
``NOBS_INFERENCE_PROVIDER`` unset the Ollama path is byte-for-byte what it was.

Both providers stay local-first. Neither base URL should point off the private
network, and no request made here reaches a cloud endpoint.
"""

from __future__ import annotations

import json
from typing import Any

import httpx

from app.config import Settings

OLLAMA = "ollama"
LM_STUDIO = "lmstudio"


def provider_label(settings: Settings) -> str:
    """Human-readable provider name for status surfaces."""
    return "LM Studio" if settings.inference_provider == LM_STUDIO else "Ollama"


def base_url(settings: Settings) -> str:
    """Root URL of the selected provider, without a trailing slash."""
    if settings.inference_provider == LM_STUDIO:
        return settings.lmstudio_base_url.rstrip("/")
    return settings.ollama_base_url.rstrip("/")


def resolve_model(settings: Settings, model: str) -> str:
    """Map a configured Ollama model name onto the selected provider's name.

    Ollama and LM Studio identify the same weights differently (``qwen3:8b``
    versus ``qwen/qwen3-8b``), and callers name models from the Ollama settings.
    Only the two configured names are remapped; anything else is passed through
    so an explicit model choice is never silently replaced.
    """
    if settings.inference_provider != LM_STUDIO:
        return model
    if model == settings.ollama_model and settings.lmstudio_model:
        return settings.lmstudio_model
    if model == settings.coding_model and settings.lmstudio_coding_model:
        return settings.lmstudio_coding_model
    return model


def model_available(model: str, available: list[str]) -> bool:
    """True when `model` is served, allowing for an implicit Ollama tag."""
    return model in available or any(item.startswith(f"{model}:") for item in available)


async def chat(
    settings: Settings,
    payload: dict[str, Any],
    transport: httpx.AsyncBaseTransport | None = None,
    timeout: float | None = None,
) -> dict[str, Any]:
    """Run one non-streaming chat turn and return an Ollama-shaped response.

    `payload` is an Ollama ``/api/chat`` body. HTTP failures propagate as httpx
    errors so callers keep their existing 503/502 mapping. A body that is not
    JSON becomes an empty dict, which the callers' own validation then reports
    as an invalid model response rather than a server error.
    """
    request_timeout = settings.ollama_timeout_seconds if timeout is None else timeout
    if settings.inference_provider == LM_STUDIO:
        url = f"{_openai_root(settings)}/chat/completions"
        body = _to_openai_request(settings, payload)
    else:
        url = f"{base_url(settings)}/api/chat"
        body = payload

    async with httpx.AsyncClient(timeout=request_timeout, transport=transport) as client:
        response = await client.post(url, json=body)
        response.raise_for_status()

    try:
        data = response.json()
    except ValueError:
        return {}
    if not isinstance(data, dict):
        return {}
    if settings.inference_provider == LM_STUDIO:
        return _from_openai_response(data)
    return data


async def list_models(
    settings: Settings,
    transport: httpx.AsyncBaseTransport | None = None,
    timeout: float = 5.0,
) -> list[str]:
    """Names of the models the selected provider is currently serving."""
    if settings.inference_provider == LM_STUDIO:
        url = f"{_openai_root(settings)}/models"
    else:
        url = f"{base_url(settings)}/api/tags"

    async with httpx.AsyncClient(timeout=timeout, transport=transport) as client:
        response = await client.get(url)
        response.raise_for_status()
        data = response.json()

    if not isinstance(data, dict):
        return []
    if settings.inference_provider == LM_STUDIO:
        entries = data.get("data") or []
        return [str(item.get("id", "")) for item in entries if isinstance(item, dict)]
    entries = data.get("models") or []
    return [str(item.get("name", "")) for item in entries if isinstance(item, dict)]


def _openai_root(settings: Settings) -> str:
    root = settings.lmstudio_base_url.rstrip("/")
    return root if root.endswith("/v1") else f"{root}/v1"


def _to_openai_request(settings: Settings, payload: dict[str, Any]) -> dict[str, Any]:
    body: dict[str, Any] = {
        "model": resolve_model(settings, str(payload.get("model", ""))),
        "stream": False,
        "messages": _to_openai_messages(payload.get("messages") or []),
    }
    # Ollama's tool schema is already the OpenAI function schema, so tools pass
    # through untouched. `think` has no OpenAI equivalent and is dropped.
    tools = payload.get("tools")
    if tools:
        body["tools"] = tools

    schema = payload.get("format")
    if isinstance(schema, dict):
        body["response_format"] = {
            "type": "json_schema",
            "json_schema": {
                "name": str(schema.get("title") or "response"),
                "strict": True,
                "schema": schema,
            },
        }
    elif schema == "json":
        body["response_format"] = {"type": "json_object"}

    options = payload.get("options")
    if isinstance(options, dict):
        for key in ("temperature", "top_p", "seed"):
            if key in options:
                body[key] = options[key]
        if "num_predict" in options:
            body["max_tokens"] = options["num_predict"]
    return body


def _to_openai_messages(messages: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Translate Ollama messages, synthesizing the tool call ids OpenAI requires.

    Ollama pairs a tool result with its call by position and a `tool_name`;
    OpenAI pairs them by `tool_call_id`. Ids are generated in call order and
    handed to the results that follow, which is the same pairing the agent loop
    already relies on when it appends a result directly after its call.
    """
    translated: list[dict[str, Any]] = []
    pending: list[str] = []
    next_id = 0

    for message in messages:
        role = str(message.get("role", "user"))
        if role == "tool":
            item: dict[str, Any] = {"role": "tool", "content": message.get("content") or ""}
            if pending:
                item["tool_call_id"] = pending.pop(0)
            name = message.get("tool_name") or message.get("name")
            if name:
                item["name"] = name
            translated.append(item)
            continue

        item = {"role": role, "content": message.get("content") or ""}
        calls = message.get("tool_calls") or []
        openai_calls = []
        for call in calls:
            function = call.get("function") or {}
            call_id = str(call.get("id") or f"call_{next_id}")
            next_id += 1
            pending.append(call_id)
            arguments = function.get("arguments", {})
            openai_calls.append(
                {
                    "id": call_id,
                    "type": "function",
                    "function": {
                        "name": str(function.get("name", "")),
                        "arguments": (
                            arguments if isinstance(arguments, str) else json.dumps(arguments)
                        ),
                    },
                }
            )
        if openai_calls:
            item["tool_calls"] = openai_calls
        translated.append(item)

    return translated


def _from_openai_response(body: dict[str, Any]) -> dict[str, Any]:
    """Translate one OpenAI chat completion back into Ollama's response shape.

    An unexpected body yields an empty assistant message rather than an
    exception, so callers report it through their existing "invalid model
    response" path instead of raising a 500.
    """
    choices = body.get("choices") or []
    raw = choices[0].get("message") or {} if choices and isinstance(choices[0], dict) else {}

    message: dict[str, Any] = {
        "role": str(raw.get("role") or "assistant"),
        "content": raw.get("content") or "",
    }

    tool_calls = []
    for call in raw.get("tool_calls") or []:
        function = call.get("function") or {}
        arguments = function.get("arguments", {})
        if isinstance(arguments, str):
            try:
                arguments = json.loads(arguments or "{}")
            except json.JSONDecodeError:
                arguments = {}
        if not isinstance(arguments, dict):
            arguments = {}
        tool_calls.append(
            {
                "type": "function",
                "function": {"name": str(function.get("name", "")), "arguments": arguments},
            }
        )
    if tool_calls:
        message["tool_calls"] = tool_calls

    return {"model": str(body.get("model", "")), "done": True, "message": message}
