import httpx
from fastapi.testclient import TestClient
import subprocess  # Import subprocess module

from app.config import Settings
from app.main import create_app


def test_health_returns_service_metadata() -> None:
    response = TestClient(create_app()).get("/health")

    assert response.status_code == 200
    payload = response.json()
    assert payload["status"] == "ok"
    assert payload["service"] == "nobs-tank-api"
    assert payload["version"]
    assert payload["timestamp"].endswith("+00:00")


def test_dashboard_is_served_and_redirected() -> None:
    app = create_app(Settings(agent_database_path=":memory:"))
    test_client = TestClient(app)

    redirect = test_client.get("/dashboard", follow_redirects=False)
    page = test_client.get("/dashboard/assets/index.html")

    assert redirect.status_code == 307
    assert redirect.headers["location"] == "/dashboard/assets/index.html"
    assert page.status_code == 200
    assert "NOBS Tank Dashboard" in page.text
    assert 'data-theme-choice="dark"' in page.text


def test_dashboard_status_is_room_safe(tmp_path) -> None:
    settings = Settings(
        agent_database_path=":memory:",
        agent_workspace_path=tmp_path,
        dashboard_name="Workshop Tank",
    )
    app = create_app(settings)
    app.state.ollama_transport = httpx.MockTransport(
        lambda _: httpx.Response(200, json={"models": [{"name": "qwen3:8b"}]})
    )

    response = TestClient(app).get("/dashboard/status")

    assert response.status_code == 200
    payload = response.json()
    assert payload["display_name"] == "Workshop Tank"
    assert payload["services"]["ollama"] == {"status": "online", "model": "qwen3:8b"}
    assert payload["agent"]["pending_approvals"] == 0
    assert payload["workspaces"] == {"personal": 0, "business": 0, "shared": 0}
    assert "conversations" in payload["privacy"].lower()
    assert "messages" not in payload


def test_dashboard_status_includes_gpu_when_available(monkeypatch) -> None:
    def mock_subprocess_run(*args, **kwargs):
        return subprocess.CompletedProcess(args=args, returncode=0, stdout="37, 4096, 12288, 51\n")

    monkeypatch.setattr(subprocess, "run", mock_subprocess_run)

    app = create_app(Settings())
    response = TestClient(app).get("/dashboard/status")

    assert response.status_code == 200
    payload = response.json()
    gpu_status = payload.get("gpu")
    assert gpu_status is not None
    assert gpu_status["utilization_percent"] == 37
    assert gpu_status["memory_used_mb"] == 4096
    assert gpu_status["memory_total_mb"] == 12288
    assert gpu_status["temperature_c"] == 51


def test_dashboard_status_gpu_none_when_unavailable(monkeypatch) -> None:
    def mock_subprocess_run(*args, **kwargs):
        raise FileNotFoundError

    monkeypatch.setattr(subprocess, "run", mock_subprocess_run)

    app = create_app(Settings())
    response = TestClient(app).get("/dashboard/status")

    assert response.status_code == 200
    payload = response.json()
    gpu_status = payload.get("gpu")
    assert gpu_status is None
