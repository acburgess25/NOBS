"""Live dream team workplace — animated floor, agent visuals, browser sandbox."""

from __future__ import annotations

import hashlib
import json
import logging
import re
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

import httpx

from app.agent_store import AgentStore
from app.config import Settings

logger = logging.getLogger(__name__)

_PRIVATE_HOST_RE = re.compile(
    r"^(localhost|127\.|10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.|::1|\[::1\])",
    re.IGNORECASE,
)

ROLE_APPEARANCE: dict[str, dict[str, str]] = {
    "planner": {"icon": "📋", "color": "#7ec8e3"},
    "scheduling": {"icon": "📅", "color": "#a8c58f"},
    "researcher": {"icon": "🔍", "color": "#c9a0ff"},
    "assistant": {"icon": "✨", "color": "#ffd166"},
    "writer": {"icon": "✍️", "color": "#f4a261"},
    "coder": {"icon": "💻", "color": "#8bd3dd"},
    "reviewer": {"icon": "🧐", "color": "#b8f2e6"},
    "analyst": {"icon": "📊", "color": "#cdb4db"},
}

WORKPLACE_STATIONS: list[dict[str, Any]] = [
    {"id": "lounge", "label": "Lounge", "x": 12, "y": 78, "has_screen": False},
    {"id": "desk-1", "label": "Desk 1", "x": 22, "y": 48, "has_screen": True},
    {"id": "desk-2", "label": "Desk 2", "x": 38, "y": 48, "has_screen": True},
    {"id": "desk-3", "label": "Desk 3", "x": 54, "y": 48, "has_screen": True},
    {"id": "desk-4", "label": "Desk 4", "x": 70, "y": 48, "has_screen": True},
    {"id": "meeting", "label": "Meeting nook", "x": 84, "y": 24, "has_screen": False},
    {"id": "kitchen", "label": "Kitchen", "x": 12, "y": 24, "has_screen": False},
]

MONITOR_STATIONS = [station["id"] for station in WORKPLACE_STATIONS if station["has_screen"]]


class BrowserSandboxError(ValueError):
    pass


@dataclass
class _BrowserSession:
    id: str
    agent_id: str
    url: str
    title: str = ""
    station: str | None = None
    created_at: float = field(default_factory=time.time)
    updated_at: float = field(default_factory=time.time)

    def as_dict(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "agent_id": self.agent_id,
            "url": self.url,
            "title": self.title,
            "station": self.station,
            "created_at": self.created_at,
            "updated_at": self.updated_at,
        }


class BrowserSandbox:
    """Filtered headless browser sessions for agent computer use (local Tank)."""

    def __init__(
        self,
        allowed_domains: list[str],
        transport: httpx.AsyncBaseTransport | None = None,
        screenshot_dir: Path | None = None,
        session_ttl_seconds: int = 1800,
    ) -> None:
        self.allowed_domains = {domain.lower().strip() for domain in allowed_domains if domain}
        self.transport = transport
        self.screenshot_dir = (screenshot_dir or Path("data/workplace/screenshots")).resolve()
        self.session_ttl_seconds = session_ttl_seconds
        self._sessions: dict[str, _BrowserSession] = {}
        self._agent_sessions: dict[str, str] = {}
        self._titles: dict[str, str] = {}
        self.screenshot_dir.mkdir(parents=True, exist_ok=True)

    def create_session(self, agent_id: str, url: str) -> dict[str, Any]:
        if not self._is_url_allowed(url):
            host = urlparse(url).hostname or url
            raise BrowserSandboxError(f"URL is not allowed by sandbox allowlist: {host}")
        self.close_agent_sessions(agent_id)
        session_id = f"{agent_id}-{int(time.time() * 1000)}"
        station = self._next_free_station()
        session = _BrowserSession(
            id=session_id,
            agent_id=agent_id,
            url=url.strip(),
            station=station,
        )
        self._sessions[session_id] = session
        self._agent_sessions[agent_id] = session_id
        return session.as_dict()

    def _next_free_station(self) -> str:
        used = {session.station for session in self._sessions.values() if session.station}
        for station_id in MONITOR_STATIONS:
            if station_id not in used:
                return station_id
        return MONITOR_STATIONS[0]

    async def refresh_session(self, session_id: str) -> dict[str, Any]:
        session = self._require_session(session_id)
        session.updated_at = time.time()
        session.title = await self._fetch_title(session.url)
        self._titles[session_id] = session.title
        return session.as_dict()

    def screenshot_svg(self, session_id: str) -> str:
        session = self._require_session(session_id)
        title = self._titles.get(session_id) or session.title or urlparse(session.url).hostname or "Sandbox"
        host = urlparse(session.url).hostname or session.url
        return _placeholder_svg(title=title, host=host, agent_id=session.agent_id)

    def get_agent_session(self, agent_id: str) -> dict[str, Any] | None:
        session_id = self._agent_sessions.get(agent_id)
        if not session_id:
            return None
        session = self._sessions.get(session_id)
        return session.as_dict() if session else None

    def assign_station(self, session_id: str, station: str) -> None:
        session = self._require_session(session_id)
        session.station = station

    def close_agent_sessions(self, agent_id: str) -> None:
        session_id = self._agent_sessions.pop(agent_id, None)
        if session_id:
            self._sessions.pop(session_id, None)
            self._titles.pop(session_id, None)

    def security_summary(self) -> str:
        domains = ", ".join(sorted(self.allowed_domains))
        return (
            "Monitored browser sandbox with allowlisted domains only "
            f"({domains}). Private networks and non-http schemes are blocked."
        )

    def _require_session(self, session_id: str) -> _BrowserSession:
        session = self._sessions.get(session_id)
        if session is None:
            raise KeyError(session_id)
        if time.time() - session.updated_at > self.session_ttl_seconds:
            self._sessions.pop(session_id, None)
            self._agent_sessions.pop(session.agent_id, None)
            raise KeyError(session_id)
        return session

    def _is_url_allowed(self, url: str) -> bool:
        parsed = urlparse(url.strip())
        if parsed.scheme not in {"http", "https"}:
            return False
        host = (parsed.hostname or "").lower()
        if not host or _PRIVATE_HOST_RE.match(host):
            return False
        if host in self.allowed_domains:
            return True
        return any(host == domain or host.endswith(f".{domain}") for domain in self.allowed_domains)

    async def _fetch_title(self, url: str) -> str:
        try:
            async with httpx.AsyncClient(
                timeout=8.0,
                follow_redirects=True,
                transport=self.transport,
            ) as client:
                response = await client.get(url, headers={"User-Agent": "NOBS-Workplace-Sandbox/1.0"})
                response.raise_for_status()
                match = re.search(r"<title[^>]*>([^<]+)</title>", response.text[:8000], re.I)
                if match:
                    return match.group(1).strip()[:120]
        except (httpx.HTTPError, ValueError):
            logger.debug("Could not fetch title for %s", url, exc_info=True)
        return urlparse(url).hostname or "Sandbox"


def parse_allowed_domains(raw: str) -> list[str]:
    return [part.strip() for part in raw.split(",") if part.strip()]


def agent_visual_for(name: str, role: str = "") -> dict[str, str]:
    role_key = role.lower()
    for key, appearance in ROLE_APPEARANCE.items():
        if key in role_key or key in name.lower():
            return dict(appearance)
    digest = hashlib.sha256(name.encode("utf-8")).hexdigest()
    palette = ["#7ec8e3", "#c9a0ff", "#ffd166", "#f4a261", "#8bd3dd", "#b8f2e6", "#a8c58f"]
    icons = ["🤖", "🦊", "🐱", "🐶", "🐼", "🐸", "🦄"]
    return {
        "icon": icons[int(digest[:2], 16) % len(icons)],
        "color": palette[int(digest[2:4], 16) % len(palette)],
    }


def build_workplace_status(
    settings: Settings,
    store: AgentStore,
    browser: BrowserSandbox,
) -> dict[str, Any]:
    screens = _build_screens(browser)
    agents = _collect_agents(settings, store, browser)
    dream_team = _active_dream_team_session(store)
    return {
        "generated_at": time.time(),
        "display_name": settings.dashboard_name,
        "privacy": "Room-safe workplace view. No conversation text or private file contents.",
        "stations": WORKPLACE_STATIONS,
        "agents": agents,
        "screens": screens,
        "dream_team": dream_team,
        "browser_sandbox": {
            "allowed_domains": sorted(browser.allowed_domains),
            "security": browser.security_summary(),
        },
    }


def _collect_agents(
    settings: Settings,
    store: AgentStore,
    browser: BrowserSandbox,
) -> list[dict[str, Any]]:
    agents: dict[str, dict[str, Any]] = {}

    for manifest in _load_active_manifests(settings.dream_team_active_path):
        name = str(manifest.get("name", "Agent"))
        role = str(manifest.get("role", "assistant"))
        agent_id = _slugify(name)
        visual = agent_visual_for(name, role)
        session = browser.get_agent_session(agent_id)
        agents[agent_id] = {
            "id": agent_id,
            "name": name,
            "role": role,
            "icon": visual["icon"],
            "color": visual["color"],
            "source": "approved",
            "station": session["station"] if session and session.get("station") else "lounge",
            "activity": "browsing" if session else "idle",
            "session_id": session["id"] if session else None,
        }

    running = _running_dream_team_drafts(store)
    for index, draft in enumerate(running):
        name = draft["name"]
        role = draft.get("role", "assistant")
        agent_id = f"draft-{draft['id']}"
        if agent_id in agents:
            continue
        visual = agent_visual_for(name, role)
        activity = _activity_for_draft(draft)
        station = _station_for_draft(draft, index, list(agents.values()))
        session = browser.get_agent_session(agent_id)
        if activity == "sandboxing" and session is None:
            try:
                created = browser.create_session(agent_id, "https://en.wikipedia.org/wiki/Main_Page")
                browser.assign_station(created["id"], station)
                session = created
            except BrowserSandboxError:
                logger.debug("Could not auto-start sandbox browser for %s", agent_id, exc_info=True)
        agents[agent_id] = {
            "id": agent_id,
            "name": name,
            "role": role,
            "icon": visual["icon"],
            "color": visual["color"],
            "source": "dream_team",
            "station": session["station"] if session and session.get("station") else station,
            "activity": "browsing" if session else activity,
            "session_id": session["id"] if session else None,
        }

    return list(agents.values())


def _build_screens(browser: BrowserSandbox) -> list[dict[str, Any]]:
    screens: list[dict[str, Any]] = []
    for station_id in MONITOR_STATIONS:
        active_session = next(
            (session for session in browser._sessions.values() if session.station == station_id),
            None,
        )
        screens.append(
            {
                "station": station_id,
                "active": active_session is not None,
                "screenshot_url": (
                    f"/workplace/browser/sessions/{active_session.id}/screenshot"
                    if active_session
                    else None
                ),
                "url": active_session.url if active_session else None,
                "title": active_session.title if active_session else None,
            }
        )
    return screens


def _active_dream_team_session(store: AgentStore) -> dict[str, Any] | None:
    for status in ("running", "proposed"):
        sessions = store.list_dream_team_sessions(status)
        if sessions:
            session = sessions[0]
            return {
                "id": session["id"],
                "status": session["status"],
                "objective": session["objective"],
                "context": session["context"],
            }
    return None


def _dream_team_drafts(store: AgentStore) -> list[dict[str, Any]]:
    for status in ("running", "proposed"):
        sessions = store.list_dream_team_sessions(status)
        if sessions:
            return store.list_dream_team_drafts(sessions[0]["id"])
    return []


def _activity_for_draft(draft: dict[str, Any]) -> str:
    status = str(draft.get("status", ""))
    if status in {"tested", "refining"}:
        return "sandboxing"
    if status in {"selected", "refined"}:
        return "presenting"
    return "walking"


def _station_for_draft(
    draft: dict[str, Any],
    index: int,
    existing: list[dict[str, Any]],
) -> str:
    status = str(draft.get("status", ""))
    if status in {"tested", "refining"} or _draft_uses_computer(draft):
        return MONITOR_STATIONS[index % len(MONITOR_STATIONS)]
    if status in {"selected", "refined"}:
        return MONITOR_STATIONS[index % len(MONITOR_STATIONS)]
    used = {agent["station"] for agent in existing if agent.get("station")}
    non_monitor = [station["id"] for station in WORKPLACE_STATIONS if not station["has_screen"]]
    digest = int(hashlib.sha256(draft["name"].encode("utf-8")).hexdigest()[:2], 16)
    candidates = [station for station in non_monitor if station not in used] or non_monitor
    return candidates[digest % len(candidates)]


def _draft_uses_computer(draft: dict[str, Any]) -> bool:
    test = draft.get("test_result") or {}
    if test.get("tool_results"):
        return True
    tools = (draft.get("persona") or {}).get("suggested_tools") or []
    return any(tool in {"read_url", "web_search"} for tool in tools)


def _running_dream_team_drafts(store: AgentStore) -> list[dict[str, Any]]:
    return _dream_team_drafts(store)


def _load_active_manifests(path: Path) -> list[dict[str, Any]]:
    if not path.exists():
        return []
    manifests: list[dict[str, Any]] = []
    for manifest_path in sorted(path.glob("*.json")):
        try:
            data = json.loads(manifest_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            logger.warning("Skipping invalid dream team manifest: %s", manifest_path)
            continue
        if isinstance(data, dict):
            manifests.append(data)
    return manifests


def _slugify(value: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")
    return slug[:60] or "agent"


def _placeholder_svg(title: str, host: str, agent_id: str) -> str:
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="960" height="540" viewBox="0 0 960 540">
  <rect width="960" height="540" fill="#101510"/>
  <rect x="24" y="24" width="912" height="56" rx="12" fill="#1a241a"/>
  <text x="48" y="60" fill="#a8c58f" font-family="sans-serif" font-size="22">{_xml_escape(title)}</text>
  <text x="48" y="140" fill="#edf0e8" font-family="sans-serif" font-size="34">Monitored browser sandbox</text>
  <text x="48" y="190" fill="#aab4a8" font-family="sans-serif" font-size="22">{_xml_escape(host)}</text>
  <text x="48" y="250" fill="#aab4a8" font-family="sans-serif" font-size="18">Allowlisted fetch only — no script execution in Tank</text>
  <text x="48" y="500" fill="#6d776c" font-family="sans-serif" font-size="16">Agent: {_xml_escape(agent_id)}</text>
</svg>"""


def _xml_escape(value: str) -> str:
    return (
        value.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
    )
