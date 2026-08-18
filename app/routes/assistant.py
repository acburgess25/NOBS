"""Chat and the daily briefing -- the two user-facing model routes.

Both talk to Ollama on the Tank and both return a privacy receipt naming where
the work happened, because PRODUCT_DECISIONS.md requires every response to
identify its processing location. Model failures are mapped to 503 (Tank model
unavailable) or 502 (Tank model misbehaved) rather than surfacing as a 500, so
the app can tell "try later" apart from "something is broken".
"""

from __future__ import annotations

import httpx
from fastapi import APIRouter, Depends, HTTPException

from app.briefing import (
    BriefingError,
    BriefingModelUnavailable,
    BriefingRequest,
    BriefingResponse,
    OllamaResponse,
    PrivacyReceipt,
    generate_briefing,
)
from app.dependencies import SettingsDep, StoreDep, TransportDep, require_device_token
from app.schemas import ChatRequest, ChatResponse

router = APIRouter()


@router.post(
    "/chat",
    response_model=ChatResponse,
    tags=["assistant"],
    dependencies=[Depends(require_device_token)],
)
async def chat(
    request: ChatRequest,
    settings: SettingsDep,
    transport: TransportDep,
) -> ChatResponse:
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
            transport=transport,
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


@router.post(
    "/briefing",
    response_model=BriefingResponse,
    tags=["assistant"],
    dependencies=[Depends(require_device_token)],
)
async def create_briefing(
    request: BriefingRequest,
    settings: SettingsDep,
    store: StoreDep,
    transport: TransportDep,
) -> BriefingResponse:
    try:
        result = await generate_briefing(settings, request, transport)
    except BriefingModelUnavailable as error:
        raise HTTPException(status_code=503, detail=str(error)) from error
    except BriefingError as error:
        raise HTTPException(status_code=502, detail=str(error)) from error

    store.save_briefing(request.date.isoformat(), result.model_dump(mode="json"))
    return result


@router.get(
    "/briefing/latest",
    response_model=BriefingResponse,
    tags=["assistant"],
    dependencies=[Depends(require_device_token)],
)
async def latest_briefing(store: StoreDep) -> BriefingResponse:
    briefing = store.latest_briefing()
    if briefing is None:
        raise HTTPException(status_code=404, detail="No briefing is available")
    try:
        return BriefingResponse.model_validate(briefing)
    except ValueError as error:
        # A stored row written by an older build could fail today's schema.
        # Report it as absent rather than letting a ValidationError surface
        # as an opaque 500.
        raise HTTPException(
            status_code=404,
            detail="No readable briefing is available",
        ) from error
