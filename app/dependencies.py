"""Shared FastAPI dependencies for the Tank API.

Two things live here: the typed accessors that hand a route the objects the
app was built with, and the three authentication gates.

Routes reach shared state through these accessors rather than through
`request.app.state` directly, so a handler's signature says what it touches.
Everything resolves from `app.state`, which is what lets `create_app` keep
accepting an injected `Settings` -- the tests build apps with custom settings,
so reading a module-level `get_settings()` here would quietly ignore them.

The gates are deliberately three distinct things:

- `require_device_token` -- a paired device proved it holds the token.
- `require_local_request` -- the caller is physically at the Tank.
- `require_local_or_paired_request` -- either of the above.

They are separate because they fail differently on purpose; see
`require_local_or_paired_request` for why a missing credential is a 403 and
not a 401.
"""

from __future__ import annotations

import secrets
from collections.abc import Callable
from typing import Annotated

import httpx
from fastapi import Depends, Header, HTTPException, Request, status

from app.agent_store import AgentStore
from app.agent_tools import ToolRegistry
from app.config import Settings
from app.dream_team import DreamTeamSandbox
from app.networking import tank_pairing_url
from app.pairing import PairingWindow, is_loopback_client
from app.schemas import PairingSecretView
from app.tank_optimizer import TankOptimizer
from app.workplace import BrowserSandbox


def get_app_settings(request: Request) -> Settings:
    return request.app.state.settings


def get_store(request: Request) -> AgentStore:
    return request.app.state.agent_store


def get_tools(request: Request) -> ToolRegistry:
    return request.app.state.agent_tools


def get_pairing_window(request: Request) -> PairingWindow:
    return request.app.state.pairing_window


def get_optimizer(request: Request) -> TankOptimizer:
    return request.app.state.optimizer


def get_browser(request: Request) -> BrowserSandbox:
    return request.app.state.workplace_browser


def get_transport(request: Request) -> httpx.AsyncBaseTransport | None:
    # Optional and set after construction: the tests attach a MockTransport to
    # an app they already built, so this is read per request, never cached.
    return getattr(request.app.state, "ollama_transport", None)


def get_process_started_at(request: Request) -> float:
    return request.app.state.process_started_at


SettingsDep = Annotated[Settings, Depends(get_app_settings)]
StoreDep = Annotated[AgentStore, Depends(get_store)]
ToolsDep = Annotated[ToolRegistry, Depends(get_tools)]
PairingDep = Annotated[PairingWindow, Depends(get_pairing_window)]
OptimizerDep = Annotated[TankOptimizer, Depends(get_optimizer)]
BrowserDep = Annotated[BrowserSandbox, Depends(get_browser)]
TransportDep = Annotated["httpx.AsyncBaseTransport | None", Depends(get_transport)]
ProcessStartedAtDep = Annotated[float, Depends(get_process_started_at)]


def get_dream_team_sandbox(
    settings: SettingsDep,
    store: StoreDep,
    tools: ToolsDep,
    transport: TransportDep,
    browser: BrowserDep,
) -> DreamTeamSandbox:
    return DreamTeamSandbox(
        settings=settings,
        store=store,
        tools=tools,
        transport=transport,
        browser_sandbox=browser,
    )


SandboxDep = Annotated[DreamTeamSandbox, Depends(get_dream_team_sandbox)]


def get_dream_team_sandbox_factory(
    settings: SettingsDep,
    store: StoreDep,
    tools: ToolsDep,
    transport: TransportDep,
    browser: BrowserDep,
) -> Callable[[], DreamTeamSandbox]:
    """A zero-argument factory, for callers that build a sandbox per job.

    The optimizer runs jobs after the request that triggered them has been
    answered, so it needs to construct a sandbox on demand rather than hold
    one built at request time.
    """

    def factory() -> DreamTeamSandbox:
        return DreamTeamSandbox(
            settings=settings,
            store=store,
            tools=tools,
            transport=transport,
            browser_sandbox=browser,
        )

    return factory


SandboxFactoryDep = Annotated[
    Callable[[], DreamTeamSandbox], Depends(get_dream_team_sandbox_factory)
]


def resolve_device_token(settings: Settings, store: AgentStore) -> str | None:
    configured_token = settings.device_token
    if configured_token is not None:
        configured_value = configured_token.get_secret_value()
        if configured_value:
            return configured_value
    return store.get_kv("device_token")


async def require_device_token(
    settings: SettingsDep,
    store: StoreDep,
    authorization: str | None = Header(default=None),
) -> None:
    resolved_token = resolve_device_token(settings, store)
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


def require_local_request(request: Request) -> None:
    """Allow only requests that originated on the Tank host itself.

    The peer address is read from the connection, never from a forwarded-for
    header, because those are supplied by the caller. This assumes the API
    port is not published through a reverse proxy — `deploy/tank/` only
    tunnels the marketing site — so a loopback peer really does mean someone
    is at the Tank. Putting a proxy in front of this port would turn every
    remote request into a local one and must not be done.
    """
    if not is_loopback_client(request.client.host if request.client else None):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                "Pairing can only be managed from the Tank itself. "
                "Open the NOBS dashboard on the Tank display."
            ),
        )


async def require_local_or_paired_request(
    request: Request,
    settings: SettingsDep,
    store: StoreDep,
    authorization: str | None = Header(default=None),
) -> None:
    """Permit the Tank's own display, or an already-paired device.

    A remote caller that offers no credential at all is a locality failure,
    not an authentication failure, so it gets 403 rather than a 401 that
    would invite a credential prompt for a route gated on being at the Tank.
    """
    if is_loopback_client(request.client.host if request.client else None):
        return
    if not authorization:
        require_local_request(request)
    await require_device_token(settings, store, authorization)


def pairing_secret(
    settings: Settings,
    store: AgentStore,
    pairing: PairingWindow,
) -> PairingSecretView:
    token = resolve_device_token(settings, store)
    if not token:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Tank device authentication is not configured",
        )
    return PairingSecretView(
        url=tank_pairing_url(),
        token=token,
        **pairing.state(),
    )
