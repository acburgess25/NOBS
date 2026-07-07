from pathlib import Path

import pytest

from app.agent_tools import ToolRegistry


def registry(tmp_path: Path) -> tuple[ToolRegistry, Path]:
    project = tmp_path / "project"
    project.mkdir()
    return ToolRegistry(tmp_path / "workspace", project), project


def test_developer_tools_are_hidden_from_assistant_mode(tmp_path: Path) -> None:
    tools, _ = registry(tmp_path)

    assistant_names = {item["function"]["name"] for item in tools.schemas_for_mode("assistant")}
    developer_names = {item["function"]["name"] for item in tools.schemas_for_mode("developer")}

    assert "read_project_file" not in assistant_names
    assert {
        "list_project_files",
        "read_project_file",
        "search_project_text",
    }.issubset(developer_names)


def test_project_listing_excludes_secrets_data_and_hidden_paths(tmp_path: Path) -> None:
    tools, project = registry(tmp_path)
    (project / "app").mkdir()
    (project / "app" / "main.py").write_text("print('safe')\n", encoding="utf-8")
    (project / ".env").write_text("SECRET=value\n", encoding="utf-8")
    (project / "data").mkdir()
    (project / "data" / "private.json").write_text("{}", encoding="utf-8")
    (project / ".hidden").mkdir()
    (project / ".hidden" / "notes.md").write_text("private", encoding="utf-8")

    result = tools.execute("list_project_files", {})

    assert result["files"] == ["app/main.py"]
    assert result["truncated"] is False


def test_project_read_is_bounded_and_rejects_unsafe_files(tmp_path: Path) -> None:
    tools, project = registry(tmp_path)
    (project / "README.md").write_text("A" * 50_100, encoding="utf-8")
    (project / ".env").write_text("SECRET=value\n", encoding="utf-8")
    (project / "image.txt").write_bytes(b"text\x00binary")

    result = tools.execute("read_project_file", {"path": "README.md"})

    assert len(result["content"]) == 50_000
    assert result["truncated"] is True
    with pytest.raises(ValueError, match="not available"):
        tools.execute("read_project_file", {"path": ".env"})
    with pytest.raises(ValueError, match="not UTF-8 text"):
        tools.execute("read_project_file", {"path": "image.txt"})


def test_project_tools_reject_path_escape_symlink_and_extra_arguments(tmp_path: Path) -> None:
    tools, project = registry(tmp_path)
    outside = tmp_path / "outside.md"
    outside.write_text("do not read", encoding="utf-8")
    try:
        (project / "outside-link.md").symlink_to(outside)
        has_symlinks = True
    except OSError:
        has_symlinks = False

    with pytest.raises(ValueError, match="escapes configured project"):
        tools.execute("read_project_file", {"path": "../outside.md"})
    if has_symlinks:
        with pytest.raises(ValueError, match="escapes configured project"):
            tools.execute("read_project_file", {"path": "outside-link.md"})
    with pytest.raises(ValueError, match="unsupported fields"):
        tools.execute("list_project_files", {"unexpected": True})


def test_project_search_returns_bounded_literal_matches(tmp_path: Path) -> None:
    tools, project = registry(tmp_path)
    (project / "app").mkdir()
    (project / "app" / "agent.py").write_text(
        "class TankAgent:\n    pass\n",
        encoding="utf-8",
    )
    (project / "README.md").write_text("TankAgent overview\n", encoding="utf-8")

    result = tools.execute(
        "search_project_text",
        {"query": "tankagent", "path": "app"},
    )

    assert result == {
        "query": "tankagent",
        "matches": [{"path": "app/agent.py", "line": 1, "snippet": "class TankAgent:"}],
        "truncated": False,
    }
