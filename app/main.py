"""Application assembly for the Tank API.

This module builds the app and owns nothing else: state construction, static
mounts, the background tasks in `lifespan`, and the router includes. The routes
themselves live in app/routes/, grouped by area, and reach this state through
the typed dependencies in app/dependencies.py.

`create_app` takes an optional `Settings` so tests can build an app with custom
configuration. That object is stored on `app.state.settings`, which is where
every dependency reads it from -- reading a module-level `get_settings()` in a
dependency would silently ignore the injected one.
"""

import asyncio
import time
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

from app.agent_store import AgentStore
from app.agent_tools import ToolRegistry
from app.bonjour import TankBonjourAdvertisement
from app.config import Settings, get_settings
from app.dream_team import DreamTeamSandbox
from app.home_assistant import HomeAssistantClient
from app.pairing import PairingWindow
from app.routes import agent, assistant, auth, dream_team, operations, schedules, sync, workplace
from app.scheduler import run_scheduler
from app.tank_optimizer import TankOptimizer, run_optimizer_loop
from app.workplace import BrowserSandbox, parse_allowed_domains


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    settings = get_settings()
    optimizer: TankOptimizer = app.state.optimizer
    bonjour = TankBonjourAdvertisement(
        name=f"NOBS {settings.dashboard_name}",
        address=settings.advertised_address,
    )
    # zeroconf's synchronous registration waits on its own event loop; keep it
    # off FastAPI's lifespan loop so an mDNS fault can never prevent the API
    # from starting.
    await asyncio.to_thread(bonjour.start)

    def dream_team_factory() -> DreamTeamSandbox:
        return DreamTeamSandbox(
            settings=settings,
            store=app.state.agent_store,
            tools=app.state.agent_tools,
            transport=getattr(app.state, "ollama_transport", None),
            browser_sandbox=app.state.workplace_browser,
        )

    scheduler_task = asyncio.create_task(
        run_scheduler(
            settings,
            app.state.agent_store,
            app.state.agent_tools,
            getattr(app.state, "ollama_transport", None),
        )
    )
    optimizer_task = asyncio.create_task(
        run_optimizer_loop(
            optimizer,
            settings,
            app.state.agent_store,
            app.state.agent_tools,
            getattr(app.state, "ollama_transport", None),
            dream_team_factory,
        )
    )
    yield
    scheduler_task.cancel()
    optimizer_task.cancel()
    await asyncio.to_thread(bonjour.close)


def create_app(settings: Settings | None = None) -> FastAPI:
    settings = settings or get_settings()
    app = FastAPI(
        title="NOBS Tank API",
        version=settings.version,
        lifespan=lifespan,
    )
    app.state.settings = settings
    app.state.agent_store = AgentStore(settings.agent_database_path)
    app.state.optimizer = TankOptimizer(settings)
    app.state.pairing_window = PairingWindow(settings.pairing_window_seconds)
    app.state.home_assistant = HomeAssistantClient(
        settings.homeassistant_url,
        settings.homeassistant_token,
    )
    app.state.agent_tools = ToolRegistry(
        settings.agent_workspace_path,
        settings.agent_project_path,
        app.state.home_assistant,
        app.state.agent_store,
        settings,
    )
    app.state.process_started_at = time.time()
    dashboard_directory = Path(__file__).resolve().parents[1] / "dashboard"
    workplace_directory = Path(__file__).resolve().parents[1] / "workplace"
    app.mount(
        "/dashboard/assets",
        StaticFiles(directory=dashboard_directory),
        name="dashboard-assets",
    )
    app.mount(
        "/workplace/assets",
        StaticFiles(directory=workplace_directory),
        name="workplace-assets",
    )
    app.state.workplace_browser = BrowserSandbox(
        allowed_domains=parse_allowed_domains(settings.workplace_browser_allowed_domains),
        transport=getattr(app.state, "ollama_transport", None),
        screenshot_dir=settings.browser_sandbox_screenshot_path,
        session_ttl_seconds=settings.browser_sandbox_session_ttl_seconds,
    )

    @app.middleware("http")
    async def optimizer_activity_middleware(request, call_next):
        optimizer: TankOptimizer | None = getattr(app.state, "optimizer", None)
        if optimizer is not None:
            optimizer.record_api_activity(request.url.path)
        return await call_next(request)

    # Included in the order the routes were originally registered, so that where
    # two paths could match the same request the same one still wins.
    app.include_router(operations.router)
    app.include_router(workplace.router)
    app.include_router(auth.router)
    app.include_router(assistant.router)
    app.include_router(agent.router)
    app.include_router(schedules.router)
    app.include_router(sync.router)
    app.include_router(dream_team.router)

    return app


app = create_app()
