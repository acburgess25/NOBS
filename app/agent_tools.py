from __future__ import annotations

from dataclasses import dataclass
from enum import StrEnum
import os
from pathlib import Path
import platform
import re
import shutil
from typing import Any, Callable


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

    def __init__(self, workspace: Path, project: Path | None = None) -> None:
        self.workspace = workspace.resolve()
        self.project = (project or Path.cwd()).resolve()
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
        usage = shutil.disk_usage(self.workspace.parent if self.workspace.parent.exists() else Path.cwd())
        load = os.getloadavg()[0] if hasattr(os, "getloadavg") else None
        return {
            "hostname": platform.node(),
            "platform": platform.system(),
            "load_1m": load,
            "disk_free_gb": round(usage.free / (1024**3), 1),
        }

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

    @staticmethod
    def _require_argument_keys(arguments: dict[str, Any], allowed: set[str]) -> None:
        if not isinstance(arguments, dict) or not set(arguments).issubset(allowed):
            raise ValueError("Tool arguments contain unsupported fields")
