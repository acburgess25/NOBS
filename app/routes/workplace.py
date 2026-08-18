"""The dream-team workplace view and its browser sandbox.

The status and screenshot routes are unauthenticated so the Tank's display can
render the floor without pairing; they expose agent activity, never personal
content. Creating a browser session does require a device token, because it
makes the Tank fetch a URL -- and the sandbox confines that to an allowlist.
"""

from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import RedirectResponse, Response

from app.dependencies import BrowserDep, SettingsDep, StoreDep, require_device_token
from app.schemas import WorkplaceBrowserSessionRequest
from app.workplace import BrowserSandboxError, build_workplace_status

router = APIRouter()


@router.get("/workplace", include_in_schema=False)
async def workplace_redirect() -> RedirectResponse:
    return RedirectResponse(url="/workplace/assets/index.html")


@router.get("/workplace/status", tags=["operations"])
async def workplace_status(
    settings: SettingsDep,
    store: StoreDep,
    browser: BrowserDep,
) -> dict[str, Any]:
    if not settings.workplace_enabled:
        raise HTTPException(status_code=503, detail="Workplace dashboard is disabled")
    return build_workplace_status(settings, store, browser)


@router.get(
    "/workplace/browser/sessions/{session_id}/screenshot",
    tags=["workplace"],
)
async def workplace_browser_screenshot(
    session_id: str,
    settings: SettingsDep,
    browser: BrowserDep,
) -> Response:
    if not settings.workplace_enabled:
        raise HTTPException(status_code=503, detail="Workplace dashboard is disabled")
    try:
        await browser.refresh_session(session_id)
        svg = browser.screenshot_svg(session_id)
    except KeyError as error:
        raise HTTPException(status_code=404, detail="Browser session not found") from error
    return Response(content=svg, media_type="image/svg+xml")


@router.post(
    "/workplace/browser/sessions",
    tags=["workplace"],
    dependencies=[Depends(require_device_token)],
)
async def create_workplace_browser_session(
    request: WorkplaceBrowserSessionRequest,
    settings: SettingsDep,
    browser: BrowserDep,
) -> dict[str, Any]:
    if not settings.workplace_enabled:
        raise HTTPException(status_code=503, detail="Workplace dashboard is disabled")
    try:
        session = browser.create_session(request.agent_id, request.url)
        session = await browser.refresh_session(session["id"])
    except BrowserSandboxError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
    return session
