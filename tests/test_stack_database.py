"""Keep the stack research database honest.

docs/research/stack.json is loaded by coding agents to decide what this project
already standardises on. A stale entry is worse than a missing one: an agent
that reads it will confidently use the wrong version or miss a dependency
entirely. These tests fail when the database drifts from what the project
actually declares.
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STACK_JSON = ROOT / "docs" / "research" / "stack.json"
PYPROJECT = ROOT / "pyproject.toml"

# Dependencies pulled in by another entry rather than chosen on their own.
# pydantic arrives with fastapi and pydantic-settings, and is documented as its
# own entry; nothing here needs a separate id.
NOT_SEPARATELY_TRACKED: set[str] = set()


def _load_stack() -> dict:
    return json.loads(STACK_JSON.read_text(encoding="utf-8"))


def _declared_dependencies() -> set[str]:
    data = tomllib.loads(PYPROJECT.read_text(encoding="utf-8"))
    project = data["project"]
    specs = list(project.get("dependencies", []))
    for extra in project.get("optional-dependencies", {}).values():
        specs.extend(extra)
    names = set()
    for spec in specs:
        name = re.split(r"[><=!\[;]", spec, maxsplit=1)[0].strip().lower()
        if name:
            names.add(name)
    return names


def test_entries_are_well_formed() -> None:
    stack = _load_stack()
    required = {"id", "name", "category", "layer", "role", "why_here", "docs"}
    ids = [entry["id"] for entry in stack["entries"]]
    assert len(ids) == len(set(ids)), "duplicate ids in stack.json"
    for entry in stack["entries"]:
        missing = required - set(entry)
        assert not missing, f"{entry.get('id')} is missing {sorted(missing)}"
        assert entry["docs"].startswith("http"), f"{entry['id']} has no documentation link"


def test_every_declared_python_dependency_is_documented() -> None:
    """A dependency in pyproject.toml with no entry here is an undocumented choice."""
    documented = {entry["id"] for entry in _load_stack()["entries"]}
    # Entry ids use the distribution name, lowercased.
    undocumented = sorted(_declared_dependencies() - documented - NOT_SEPARATELY_TRACKED)
    assert undocumented == [], (
        f"These dependencies are declared in pyproject.toml but absent from "
        f"docs/research/stack.json: {undocumented}. Add an entry describing what "
        f"each one is for, or the research database is lying to whoever reads it."
    )


def test_generated_markdown_is_current() -> None:
    """STACK.md is generated; a hand-edit or a stale build should fail here."""
    result = subprocess.run(
        [sys.executable, str(ROOT / "scripts" / "build_stack_docs.py"), "--check"],
        capture_output=True,
        text=True,
        cwd=ROOT,
    )
    assert result.returncode == 0, result.stderr or result.stdout
