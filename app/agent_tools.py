from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass
from enum import StrEnum
import json
import os
from pathlib import Path
import platform
import re
from typing import Any
from urllib.parse import urlparse

import feedparser
import httpx
import psutil
import trafilatura
import wikipediaapi
from duckduckgo_search import DDGS

from app.agent_store import AgentStore
from app.home_assistant import HomeAssistantClient

try:
    import pynvml  # type: ignore[import-untyped]
    pynvml.nvmlInit()
    _NVML_AVAILABLE = True
except Exception:
    _NVML_AVAILABLE = False


class ToolRisk(StrEnum):
    READ_ONLY = "read_only"
    CHANGE = "change"
    SENSITIVE = "sensitive"
    CRITICAL = "critical"


@dataclass(frozen=True)
class ToolDefinition:
    name: str
    description: str
    risk: ToolRisk
    parameters: dict[str, Any]
    handler: Callable[[dict[str, Any]], dict[str, Any]]

    def ollama_schema(self) -> dict[str, Any]:
        return {
            "type": "function",
            "function": {
                "name": self.name,
                "description": self.description,
                "parameters": self.parameters,
            },
        }


class ToolRegistry:
    """Allowlisted tools. There is intentionally no arbitrary shell tool."""

    _DEVELOPER_TOOLS = frozenset(
        {"list_project_files", "read_project_file", "search_project_text"}
    )
    _BLOCKED_PROJECT_PARTS = frozenset(
        {".git", ".venv", "__pycache__", "data", "node_modules", "xcuserdata"}
    )
    _TEXT_EXTENSIONS = frozenset(
        {
            ".css",
            ".html",
            ".js",
            ".json",
            ".jsx",
            ".md",
            ".py",
            ".sh",
            ".swift",
            ".toml",
            ".ts",
            ".tsx",
            ".txt",
            ".yaml",
            ".yml",
        }
    )
    _TEXT_FILENAMES = frozenset({"Dockerfile", "Gemfile", "Makefile"})

    def __init__(
        self,
        workspace: Path,
        project: Path | None = None,
        home_assistant: HomeAssistantClient | None = None,
        store: AgentStore | None = None,
        settings: Any | None = None,
    ) -> None:
        self.workspace = workspace.resolve()
        self.project = (project or Path.cwd()).resolve()
        self.home_assistant = home_assistant
        self.store = store
        self.settings = settings
        self._tools = {
            tool.name: tool
            for tool in (
                ToolDefinition(
                    name="get_tank_status",
                    description="Read basic Tank health and storage information.",
                    risk=ToolRisk.READ_ONLY,
                    parameters={"type": "object", "properties": {}, "additionalProperties": False},
                    handler=self._get_tank_status,
                ),
                ToolDefinition(
                    name="list_workspace_files",
                    description=(
                        "List files in the private NOBS agent workspace for one context. "
                        "This cannot read outside that workspace."
                    ),
                    risk=ToolRisk.READ_ONLY,
                    parameters=self._context_parameters(),
                    handler=self._list_workspace_files,
                ),
                ToolDefinition(
                    name="write_workspace_note",
                    description=(
                        "Write a Markdown note to the personal, business, or shared workspace. "
                        "This changes local state and always requires approval."
                    ),
                    risk=ToolRisk.CHANGE,
                    parameters={
                        "type": "object",
                        "required": ["context", "title", "content"],
                        "properties": {
                            "context": self._context_schema(),
                            "title": {"type": "string", "maxLength": 120},
                            "content": {"type": "string", "maxLength": 10000},
                        },
                        "additionalProperties": False,
                    },
                    handler=self._write_workspace_note,
                ),
                ToolDefinition(
                    name="list_project_files",
                    description=(
                        "List bounded source and documentation files under the configured NOBS "
                        "project. Secret, generated, hidden, and data paths are excluded."
                    ),
                    risk=ToolRisk.READ_ONLY,
                    parameters={
                        "type": "object",
                        "properties": {
                            "path": {"type": "string", "maxLength": 300},
                        },
                        "additionalProperties": False,
                    },
                    handler=self._list_project_files,
                ),
                ToolDefinition(
                    name="read_project_file",
                    description=(
                        "Read one bounded UTF-8 source or documentation file from the configured "
                        "NOBS project. Secret, generated, hidden, and data paths are excluded."
                    ),
                    risk=ToolRisk.READ_ONLY,
                    parameters={
                        "type": "object",
                        "required": ["path"],
                        "properties": {
                            "path": {"type": "string", "minLength": 1, "maxLength": 300},
                        },
                        "additionalProperties": False,
                    },
                    handler=self._read_project_file,
                ),
                ToolDefinition(
                    name="search_project_text",
                    description=(
                        "Search for a literal text fragment in bounded NOBS source and documentation "
                        "files. Returns project-relative paths, line numbers, and short snippets."
                    ),
                    risk=ToolRisk.READ_ONLY,
                    parameters={
                        "type": "object",
                        "required": ["query"],
                        "properties": {
                            "query": {"type": "string", "minLength": 1, "maxLength": 120},
                            "path": {"type": "string", "maxLength": 300},
                        },
                        "additionalProperties": False,
                    },
                    handler=self._search_project_text,
                ),
                ToolDefinition(
                    name="read_workspace_file",
                    description=(
                        "Read a Markdown note or file from the private NOBS agent workspace. "
                        "This cannot read outside that workspace."
                    ),
                    risk=ToolRisk.READ_ONLY,
                    parameters={
                        "type": "object",
                        "required": ["context", "path"],
                        "properties": {
                            "context": self._context_schema(),
                            "path": {"type": "string", "minLength": 1, "maxLength": 300},
                        },
                        "additionalProperties": False,
                    },
                    handler=self._read_workspace_file,
                ),
                ToolDefinition(
                    name="list_home_devices",
                    description=(
                        "List available smart home devices, their domains, names, and current states. "
                        "Optionally filters by domain (e.g. light, switch, climate, lock)."
                    ),
                    risk=ToolRisk.READ_ONLY,
                    parameters={
                        "type": "object",
                        "properties": {
                            "domain": {"type": "string", "maxLength": 50},
                        },
                        "additionalProperties": False,
                    },
                    handler=self._list_home_devices,
                ),
                ToolDefinition(
                    name="control_home_device",
                    description=(
                        "Control a non-secure smart home device (e.g., light, switch, climate, media_player). "
                        "This tool is prohibited from controlling secure domains like lock, alarm_control_panel, or cover. "
                        "This changes local home state and requires approval."
                    ),
                    risk=ToolRisk.CHANGE,
                    parameters={
                        "type": "object",
                        "required": ["entity_id", "service"],
                        "properties": {
                            "entity_id": {"type": "string", "minLength": 1, "maxLength": 100},
                            "service": {"type": "string", "minLength": 1, "maxLength": 50},
                            "service_data": {"type": "object"},
                        },
                        "additionalProperties": False,
                    },
                    handler=self._control_home_device,
                ),
                ToolDefinition(
                    name="control_secure_home_device",
                    description=(
                        "Control a secure smart home device (e.g., lock, alarm_control_panel, cover). "
                        "This tool is restricted only to secure domains and carries a higher risk. "
                        "This changes local home state and requires approval."
                    ),
                    risk=ToolRisk.SENSITIVE,
                    parameters={
                        "type": "object",
                        "required": ["entity_id", "service"],
                        "properties": {
                            "entity_id": {"type": "string", "minLength": 1, "maxLength": 100},
                            "service": {"type": "string", "minLength": 1, "maxLength": 50},
                            "service_data": {"type": "object"},
                        },
                        "additionalProperties": False,
                    },
                    handler=self._control_secure_home_device,
                ),
                ToolDefinition(
                    name="propose_idea",
                    description=(
                        "Propose a conceptual recommendation or optimization idea (like a new routine "
                        "or a device integration suggestion) to the user. This publishes the idea for "
                        "user review and does not execute any state change immediately."
                    ),
                    risk=ToolRisk.READ_ONLY,
                    parameters={
                        "type": "object",
                        "required": ["title", "description", "proposal_type"],
                        "properties": {
                            "title": {"type": "string", "minLength": 1, "maxLength": 120},
                            "description": {"type": "string", "minLength": 1, "maxLength": 2000},
                            "proposal_type": {
                                "type": "string",
                                "enum": ["routine", "integration", "optimization"],
                            },
                        },
                        "additionalProperties": False,
                    },
                    handler=self._propose_idea,
                ),
                ToolDefinition(
                    name="web_search",
                    description=(
                        "Search the web via DuckDuckGo. Returns titles, URLs, and snippets. "
                        "Use this to research current events, look up facts, find information "
                        "about people or businesses, or answer questions the local model may "
                        "not know. No personal data is shared with DuckDuckGo."
                    ),
                    risk=ToolRisk.READ_ONLY,
                    parameters={
                        "type": "object",
                        "required": ["query"],
                        "properties": {
                            "query": {
                                "type": "string",
                                "minLength": 1,
                                "maxLength": 200,
                                "description": "The search query.",
                            },
                            "max_results": {
                                "type": "integer",
                                "minimum": 1,
                                "maximum": 10,
                                "description": "Number of results to return (default 5).",
                            },
                        },
                        "additionalProperties": False,
                    },
                    handler=self._web_search,
                ),
                ToolDefinition(
                    name="get_weather",
                    description=(
                        "Get current weather conditions and a 7-day forecast using Open-Meteo "
                        "(free, no API key, GDPR-safe). Requires NOBS_WEATHER_LATITUDE and "
                        "NOBS_WEATHER_LONGITUDE to be configured. No personal data is transmitted."
                    ),
                    risk=ToolRisk.READ_ONLY,
                    parameters={
                        "type": "object",
                        "properties": {},
                        "additionalProperties": False,
                    },
                    handler=self._get_weather,
                ),
                ToolDefinition(
                    name="read_news_feeds",
                    description=(
                        "Fetch recent headlines from configured RSS/Atom news feeds. "
                        "Returns titles, links, and summaries from user-configured sources. "
                        "Configure feeds via NOBS_NEWS_FEED_URLS (comma-separated URLs)."
                    ),
                    risk=ToolRisk.READ_ONLY,
                    parameters={
                        "type": "object",
                        "properties": {
                            "max_per_feed": {
                                "type": "integer",
                                "minimum": 1,
                                "maximum": 20,
                                "description": "Max headlines to return per feed (default 5).",
                            },
                        },
                        "additionalProperties": False,
                    },
                    handler=self._read_news_feeds,
                ),
                ToolDefinition(
                    name="read_url",
                    description=(
                        "Fetch a public web URL and extract its main readable text content, "
                        "stripping ads, navigation, and boilerplate. Use this to read articles, "
                        "documentation, or any public page for summarization or research. "
                        "Only HTTP/HTTPS URLs are allowed."
                    ),
                    risk=ToolRisk.READ_ONLY,
                    parameters={
                        "type": "object",
                        "required": ["url"],
                        "properties": {
                            "url": {
                                "type": "string",
                                "minLength": 10,
                                "maxLength": 2000,
                                "description": "The full HTTP/HTTPS URL to fetch.",
                            },
                        },
                        "additionalProperties": False,
                    },
                    handler=self._read_url,
                ),
                ToolDefinition(
                    name="lookup_wikipedia",
                    description=(
                        "Search Wikipedia and return a plain-text summary of the best-matching "
                        "article. Use for factual lookups: people, places, events, concepts, "
                        "companies, or anything the local model may not know accurately."
                    ),
                    risk=ToolRisk.READ_ONLY,
                    parameters={
                        "type": "object",
                        "required": ["query"],
                        "properties": {
                            "query": {
                                "type": "string",
                                "minLength": 1,
                                "maxLength": 200,
                                "description": "The topic or entity to look up.",
                            },
                            "sentences": {
                                "type": "integer",
                                "minimum": 1,
                                "maximum": 20,
                                "description": "Approximate number of summary sentences (default 5).",
                            },
                        },
                        "additionalProperties": False,
                    },
                    handler=self._lookup_wikipedia,
                ),
            )
        }

    @staticmethod
    def _context_schema() -> dict[str, Any]:
        return {"type": "string", "enum": ["personal", "business", "shared"]}

    @classmethod
    def _context_parameters(cls) -> dict[str, Any]:
        return {
            "type": "object",
            "required": ["context"],
            "properties": {"context": cls._context_schema()},
            "additionalProperties": False,
        }

    @property
    def schemas(self) -> list[dict[str, Any]]:
        return self.schemas_for_mode("assistant")

    def schemas_for_mode(self, mode: str) -> list[dict[str, Any]]:
        return [
            tool.ollama_schema()
            for tool in self._tools.values()
            if self.is_available(tool.name, mode)
        ]

    def is_available(self, name: str, mode: str) -> bool:
        return name not in self._DEVELOPER_TOOLS or mode == "developer"

    def get(self, name: str) -> ToolDefinition | None:
        return self._tools.get(name)

    def execute(self, name: str, arguments: dict[str, Any]) -> dict[str, Any]:
        tool = self.get(name)
        if tool is None:
            raise KeyError(name)
        return tool.handler(arguments)

    def workspace_counts(self) -> dict[str, int]:
        counts: dict[str, int] = {}
        for context in ("personal", "business", "shared"):
            path = self._context_path(context)
            counts[context] = (
                sum(1 for item in path.rglob("*") if item.is_file()) if path.exists() else 0
            )
        return counts

    def _get_tank_status(self, _: dict[str, Any]) -> dict[str, Any]:
        cpu_percent = psutil.cpu_percent(interval=0.2)
        mem = psutil.virtual_memory()
        disk_root = Path("/") if Path("/").exists() else Path.cwd()
        disk = psutil.disk_usage(str(disk_root))
        load_avg = psutil.getloadavg() if hasattr(psutil, "getloadavg") else (None, None, None)

        result: dict[str, Any] = {
            "hostname": platform.node(),
            "platform": platform.system(),
            "cpu_percent": round(cpu_percent, 1),
            "load_1m": round(load_avg[0], 2) if load_avg[0] is not None else None,
            "load_5m": round(load_avg[1], 2) if load_avg[1] is not None else None,
            "memory_used_gb": round(mem.used / (1024**3), 2),
            "memory_total_gb": round(mem.total / (1024**3), 2),
            "memory_percent": round(mem.percent, 1),
            "disk_used_gb": round(disk.used / (1024**3), 1),
            "disk_total_gb": round(disk.total / (1024**3), 1),
            "disk_free_gb": round(disk.free / (1024**3), 1),
        }

        if _NVML_AVAILABLE:
            try:
                handle = pynvml.nvmlDeviceGetHandleByIndex(0)
                gpu_mem = pynvml.nvmlDeviceGetMemoryInfo(handle)
                gpu_util = pynvml.nvmlDeviceGetUtilizationRates(handle)
                gpu_temp = pynvml.nvmlDeviceGetTemperature(handle, pynvml.NVML_TEMPERATURE_GPU)
                result["gpu_name"] = pynvml.nvmlDeviceGetName(handle)
                result["gpu_util_percent"] = gpu_util.gpu
                result["gpu_vram_used_gb"] = round(gpu_mem.used / (1024**3), 2)
                result["gpu_vram_total_gb"] = round(gpu_mem.total / (1024**3), 2)
                result["gpu_temp_c"] = gpu_temp
            except Exception:
                result["gpu"] = "unavailable"

        return result

    def _context_path(self, context: str) -> Path:
        if context not in {"personal", "business", "shared"}:
            raise ValueError("Unknown context")
        path = (self.workspace / context).resolve()
        if self.workspace not in path.parents:
            raise ValueError("Context escapes workspace")
        return path

    def _list_workspace_files(self, arguments: dict[str, Any]) -> dict[str, Any]:
        path = self._context_path(str(arguments.get("context", "")))
        if not path.exists():
            return {"context": path.name, "files": []}
        files = [
            item.relative_to(path).as_posix()
            for item in sorted(path.rglob("*"))
            if item.is_file() and not any(part.startswith(".") for part in item.relative_to(path).parts)
        ]
        return {"context": path.name, "files": files[:100], "truncated": len(files) > 100}

    def _write_workspace_note(self, arguments: dict[str, Any]) -> dict[str, Any]:
        context = str(arguments.get("context", ""))
        title = str(arguments.get("title", "")).strip()
        content = str(arguments.get("content", "")).strip()
        if not title or not content:
            raise ValueError("Title and content are required")
        if len(title) > 120 or len(content) > 10_000:
            raise ValueError("Note exceeds the allowed size")
        path = self._context_path(context)
        path.mkdir(parents=True, exist_ok=True)
        slug = re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")[:80] or "note"
        destination = path / f"{slug}.md"
        if destination.exists():
            raise ValueError("A note with this title already exists")
        destination.write_text(f"# {title}\n\n{content}\n", encoding="utf-8")
        return {"context": context, "path": destination.relative_to(self.workspace).as_posix()}

    def _project_path(self, raw_path: object, *, require_directory: bool = False) -> Path:
        if not isinstance(raw_path, str):
            raise ValueError("Project path must be text")
        if len(raw_path) > 300:
            raise ValueError("Project path is too long")
        relative = Path(raw_path or ".")
        if relative.is_absolute():
            raise ValueError("Project path must be relative")
        destination = (self.project / relative).resolve()
        if destination != self.project and self.project not in destination.parents:
            raise ValueError("Project path escapes configured project")
        project_relative = destination.relative_to(self.project)
        if any(
            part.startswith(".") or part in self._BLOCKED_PROJECT_PARTS
            for part in project_relative.parts
        ):
            raise ValueError("Project path is not available")
        if require_directory and destination.exists() and not destination.is_dir():
            raise ValueError("Project path must be a directory")
        return destination

    def _is_project_text_file(self, path: Path) -> bool:
        try:
            resolved = path.resolve()
            relative = resolved.relative_to(self.project)
        except ValueError:
            return False
        return (
            resolved.is_file()
            and not any(
                part.startswith(".") or part in self._BLOCKED_PROJECT_PARTS
                for part in relative.parts
            )
            and (
                resolved.suffix.lower() in self._TEXT_EXTENSIONS
                or resolved.name in self._TEXT_FILENAMES
            )
        )

    def _project_files(self, root: Path) -> list[Path]:
        if not root.exists():
            return []
        files: list[Path] = []
        for dirpath, dirnames, filenames in os.walk(root):
            # Prune directories starting with "." or in blocked parts in-place
            dirnames[:] = [
                d for d in dirnames
                if not (d.startswith(".") or d in self._BLOCKED_PROJECT_PARTS)
            ]
            for filename in filenames:
                item = Path(dirpath) / filename
                if self._is_project_text_file(item):
                    files.append(item.resolve())
                    if len(files) >= 1_000:
                        break
            if len(files) >= 1_000:
                break
        files.sort()
        return files

    def _list_project_files(self, arguments: dict[str, Any]) -> dict[str, Any]:
        self._require_argument_keys(arguments, {"path"})
        root = self._project_path(arguments.get("path", "."), require_directory=True)
        files = self._project_files(root)
        return {
            "path": root.relative_to(self.project).as_posix(),
            "files": [item.relative_to(self.project).as_posix() for item in files[:200]],
            "truncated": len(files) > 200,
        }

    def _read_project_file(self, arguments: dict[str, Any]) -> dict[str, Any]:
        self._require_argument_keys(arguments, {"path"})
        path = self._project_path(arguments.get("path"))
        if not self._is_project_text_file(path):
            raise ValueError("Project file is not an available text file")
        with path.open("rb") as file:
            content = file.read(50_001)
        if b"\x00" in content:
            raise ValueError("Project file is not UTF-8 text")
        truncated = len(content) > 50_000
        try:
            text = content[:50_000].decode("utf-8", errors="ignore")
        except UnicodeDecodeError as error:
            raise ValueError("Project file is not UTF-8 text") from error
        return {
            "path": path.relative_to(self.project).as_posix(),
            "content": text,
            "truncated": truncated,
        }

    def _search_project_text(self, arguments: dict[str, Any]) -> dict[str, Any]:
        self._require_argument_keys(arguments, {"query", "path"})
        query = arguments.get("query")
        if not isinstance(query, str) or not query.strip():
            raise ValueError("Search query is required")
        if len(query) > 120:
            raise ValueError("Search query is too long")
        root = self._project_path(arguments.get("path", "."), require_directory=True)
        lowered_query = query.casefold()
        matches: list[dict[str, Any]] = []
        for path in self._project_files(root):
            try:
                if path.stat().st_size > 50_000:
                    continue
                content = path.read_bytes()
                if b"\x00" in content:
                    continue
                lines = content.decode("utf-8").splitlines()
            except (OSError, UnicodeDecodeError):
                continue
            for line_number, line in enumerate(lines, start=1):
                if lowered_query in line.casefold():
                    matches.append(
                        {
                            "path": path.relative_to(self.project).as_posix(),
                            "line": line_number,
                            "snippet": line.strip()[:300],
                        }
                    )
                    if len(matches) >= 100:
                        return {"query": query, "matches": matches, "truncated": True}
        return {"query": query, "matches": matches, "truncated": False}

    def _read_workspace_file(self, arguments: dict[str, Any]) -> dict[str, Any]:
        self._require_argument_keys(arguments, {"context", "path"})
        context = str(arguments.get("context", ""))
        path_str = str(arguments.get("path", ""))
        if not path_str:
            raise ValueError("Path is required")
        context_path = self._context_path(context)
        destination = (context_path / path_str).resolve()
        if context_path not in destination.parents and destination != context_path:
            raise ValueError("Path escapes context workspace")
        if not destination.exists() or not destination.is_file():
            raise FileNotFoundError("Workspace file does not exist")
        content = destination.read_text(encoding="utf-8", errors="ignore")
        truncated = len(content) > 50_000
        return {
            "context": context,
            "path": path_str,
            "content": content[:50_000],
            "truncated": truncated,
        }

    def _list_home_devices(self, arguments: dict[str, Any]) -> dict[str, Any]:
        self._require_argument_keys(arguments, {"domain"})
        if not self.home_assistant or not self.home_assistant.is_configured:
            return {
                "error": "Home Assistant integration is not configured. Ask the user to set NOBS_HOMEASSISTANT_URL and NOBS_HOMEASSISTANT_TOKEN in their environment."
            }
        domain = arguments.get("domain")
        try:
            devices = self.home_assistant.list_devices(domain)
            return {"devices": devices[:100], "truncated": len(devices) > 100}
        except Exception as e:
            return {"error": f"Failed to list devices from Home Assistant: {str(e)}"}

    def _control_home_device(self, arguments: dict[str, Any]) -> dict[str, Any]:
        self._require_argument_keys(arguments, {"entity_id", "service", "service_data"})
        entity_id = str(arguments.get("entity_id", ""))
        service = str(arguments.get("service", ""))
        service_data = arguments.get("service_data", {})
        if not entity_id or not service:
            raise ValueError("entity_id and service are required")
        domain = entity_id.split(".")[0] if "." in entity_id else ""
        if domain in {"lock", "alarm_control_panel", "cover"}:
            raise ValueError("This tool is not permitted to control secure devices. Use control_secure_home_device instead.")
        if not self.home_assistant or not self.home_assistant.is_configured:
            return {
                "error": "Home Assistant integration is not configured. Ask the user to set NOBS_HOMEASSISTANT_URL and NOBS_HOMEASSISTANT_TOKEN in their environment."
            }
        try:
            data = dict(service_data) if isinstance(service_data, dict) else {}
            data["entity_id"] = entity_id
            res = self.home_assistant.call_service(domain, service, data)
            return {"status": "success", "result": res}
        except Exception as e:
            return {"error": f"Failed to control device: {str(e)}"}

    def _control_secure_home_device(self, arguments: dict[str, Any]) -> dict[str, Any]:
        self._require_argument_keys(arguments, {"entity_id", "service", "service_data"})
        entity_id = str(arguments.get("entity_id", ""))
        service = str(arguments.get("service", ""))
        service_data = arguments.get("service_data", {})
        if not entity_id or not service:
            raise ValueError("entity_id and service are required")
        domain = entity_id.split(".")[0] if "." in entity_id else ""
        if domain not in {"lock", "alarm_control_panel", "cover"}:
            raise ValueError("This tool is only permitted to control secure devices (lock, alarm_control_panel, cover). Use control_home_device for other domains.")
        if not self.home_assistant or not self.home_assistant.is_configured:
            return {
                "error": "Home Assistant integration is not configured. Ask the user to set NOBS_HOMEASSISTANT_URL and NOBS_HOMEASSISTANT_TOKEN in their environment."
            }
        try:
            data = dict(service_data) if isinstance(service_data, dict) else {}
            data["entity_id"] = entity_id
            res = self.home_assistant.call_service(domain, service, data)
            return {"status": "success", "result": res}
        except Exception as e:
            return {"error": f"Failed to control secure device: {str(e)}"}

    def _propose_idea(self, arguments: dict[str, Any]) -> dict[str, Any]:
        self._require_argument_keys(arguments, {"title", "description", "proposal_type"})
        title = str(arguments.get("title", "")).strip()
        description = str(arguments.get("description", "")).strip()
        proposal_type = str(arguments.get("proposal_type", "")).strip()

        if not title or not description or not proposal_type:
            raise ValueError("title, description, and proposal_type are required")
        if proposal_type not in {"routine", "integration", "optimization"}:
            raise ValueError("proposal_type must be one of: routine, integration, optimization")

        if not self.store:
            return {"error": "Agent store is not available to save proposals."}

        try:
            prop = self.store.create_proposal(title, description, proposal_type)
            return {"status": "success", "proposal_id": prop["id"]}
        except Exception as e:
            return {"error": f"Failed to save proposal: {str(e)}"}

    @staticmethod
    def _require_argument_keys(arguments: dict[str, Any], allowed: set[str]) -> None:
        if not isinstance(arguments, dict) or not set(arguments).issubset(allowed):
            raise ValueError("Tool arguments contain unsupported fields")

    # ------------------------------------------------------------------ #
    # Research tools                                                       #
    # ------------------------------------------------------------------ #

    def _web_search(self, arguments: dict[str, Any]) -> dict[str, Any]:
        self._require_argument_keys(arguments, {"query", "max_results"})
        query = str(arguments.get("query", "")).strip()
        if not query:
            raise ValueError("Search query is required")
        max_results = int(arguments.get("max_results") or (
            self.settings.web_search_max_results if self.settings else 5
        ))
        max_results = max(1, min(max_results, 10))
        try:
            raw = list(DDGS().text(query, max_results=max_results))
        except Exception as exc:
            return {"error": f"Web search failed: {exc}"}
        results = [
            {"title": r.get("title", ""), "url": r.get("href", ""), "snippet": r.get("body", "")}
            for r in raw
        ]
        return {"query": query, "results": results, "count": len(results)}

    def _get_weather(self, _: dict[str, Any]) -> dict[str, Any]:
        if not self.settings or self.settings.weather_latitude is None:
            return {
                "error": (
                    "Weather is not configured. "
                    "Set NOBS_WEATHER_LATITUDE and NOBS_WEATHER_LONGITUDE in your environment."
                )
            }
        lat = self.settings.weather_latitude
        lon = self.settings.weather_longitude
        url = (
            "https://api.open-meteo.com/v1/forecast"
            f"?latitude={lat}&longitude={lon}"
            "&current=temperature_2m,relative_humidity_2m,apparent_temperature,"
            "precipitation,wind_speed_10m,weather_code"
            "&daily=temperature_2m_max,temperature_2m_min,precipitation_sum,"
            "weather_code,sunrise,sunset"
            "&temperature_unit=fahrenheit&wind_speed_unit=mph"
            "&precipitation_unit=inch&timezone=auto&forecast_days=7"
        )
        try:
            with httpx.Client(timeout=10.0) as client:
                response = client.get(url)
                response.raise_for_status()
            data = response.json()
        except Exception as exc:
            return {"error": f"Weather fetch failed: {exc}"}
        current = data.get("current", {})
        daily = data.get("daily", {})
        forecast = []
        dates = daily.get("time", [])
        for i, date in enumerate(dates):
            forecast.append({
                "date": date,
                "high_f": daily.get("temperature_2m_max", [None])[i],
                "low_f": daily.get("temperature_2m_min", [None])[i],
                "precipitation_in": daily.get("precipitation_sum", [None])[i],
                "weather_code": daily.get("weather_code", [None])[i],
                "sunrise": daily.get("sunrise", [None])[i],
                "sunset": daily.get("sunset", [None])[i],
            })
        return {
            "latitude": lat,
            "longitude": lon,
            "timezone": data.get("timezone"),
            "current": {
                "temperature_f": current.get("temperature_2m"),
                "feels_like_f": current.get("apparent_temperature"),
                "humidity_pct": current.get("relative_humidity_2m"),
                "wind_mph": current.get("wind_speed_10m"),
                "precipitation_in": current.get("precipitation"),
                "weather_code": current.get("weather_code"),
            },
            "forecast_7day": forecast,
        }

    def _read_news_feeds(self, arguments: dict[str, Any]) -> dict[str, Any]:
        self._require_argument_keys(arguments, {"max_per_feed"})
        max_per_feed = int(arguments.get("max_per_feed") or 5)
        max_per_feed = max(1, min(max_per_feed, 20))
        raw_urls = (self.settings.news_feed_urls if self.settings else "").strip()
        if not raw_urls:
            return {
                "error": (
                    "No news feeds configured. "
                    "Set NOBS_NEWS_FEED_URLS to a comma-separated list of RSS/Atom URLs."
                )
            }
        feed_urls = [u.strip() for u in raw_urls.split(",") if u.strip()]
        all_items: list[dict[str, Any]] = []
        errors: list[str] = []
        for url in feed_urls[:10]:
            try:
                parsed = feedparser.parse(url)
                feed_title = parsed.feed.get("title", url)
                for entry in parsed.entries[:max_per_feed]:
                    all_items.append({
                        "feed": feed_title,
                        "title": entry.get("title", ""),
                        "url": entry.get("link", ""),
                        "summary": entry.get("summary", "")[:500],
                        "published": entry.get("published", ""),
                    })
            except Exception as exc:
                errors.append(f"{url}: {exc}")
        result: dict[str, Any] = {"items": all_items, "count": len(all_items)}
        if errors:
            result["errors"] = errors
        return result

    def _read_url(self, arguments: dict[str, Any]) -> dict[str, Any]:
        self._require_argument_keys(arguments, {"url"})
        url = str(arguments.get("url", "")).strip()
        if not url:
            raise ValueError("URL is required")
        parsed = urlparse(url)
        if parsed.scheme not in {"http", "https"}:
            raise ValueError("Only HTTP and HTTPS URLs are allowed")
        try:
            downloaded = trafilatura.fetch_url(url)
            if downloaded is None:
                return {"error": "Could not fetch the URL"}
            text = trafilatura.extract(downloaded, include_comments=False, include_tables=True)
            if not text:
                return {"error": "Could not extract readable content from the URL"}
            truncated = len(text) > 20_000
            return {
                "url": url,
                "content": text[:20_000],
                "truncated": truncated,
                "char_count": len(text),
            }
        except Exception as exc:
            return {"error": f"Failed to read URL: {exc}"}

    def _lookup_wikipedia(self, arguments: dict[str, Any]) -> dict[str, Any]:
        self._require_argument_keys(arguments, {"query", "sentences"})
        query = str(arguments.get("query", "")).strip()
        if not query:
            raise ValueError("Search query is required")
        sentences = int(arguments.get("sentences") or 5)
        sentences = max(1, min(sentences, 20))
        try:
            wiki = wikipediaapi.Wikipedia(
                user_agent="NOBS-Tank/0.1 (private home assistant)",
                language="en",
            )
            page = wiki.page(query)
            if not page.exists():
                search_terms = query.replace(" ", "_")
                page = wiki.page(search_terms)
            if not page.exists():
                return {"query": query, "found": False, "error": "No Wikipedia article found"}
            full_summary = page.summary
            # Return approximately the requested number of sentences
            sent_list = full_summary.split(". ")
            summary = ". ".join(sent_list[:sentences])
            if not summary.endswith("."):
                summary += "."
            return {
                "query": query,
                "found": True,
                "title": page.title,
                "url": page.fullurl,
                "summary": summary,
                "full_summary_available": len(sent_list) > sentences,
            }
        except Exception as exc:
            return {"error": f"Wikipedia lookup failed: {exc}"}
