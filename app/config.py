from functools import lru_cache
from pathlib import Path

from pydantic import Field, SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Runtime configuration loaded from environment variables or `.env`."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_prefix="NOBS_",
        extra="ignore",
    )

    environment: str = "development"
    database_url: str = "sqlite:///./nobs.db"
    version: str = "0.1.0"
    ollama_base_url: str = "http://127.0.0.1:11434"
    ollama_model: str = "qwen3:8b"
    coding_model: str = "qwen2.5-coder:14b"
    ollama_timeout_seconds: float = Field(default=45.0, gt=0, le=300)
    device_token: SecretStr | None = None
    agent_database_path: Path = Path("data/nobs-agent.db")
    agent_workspace_path: Path = Path("data/agent-workspace")
    agent_project_path: Path = Path(".")
    agent_max_steps: int = Field(default=4, ge=1, le=8)
    dashboard_name: str = Field(default="Tank", min_length=1, max_length=40)
    homeassistant_url: str = Field(default="")
    homeassistant_token: SecretStr | None = Field(default=None)

    # Weather tool: set via NOBS_WEATHER_LATITUDE / NOBS_WEATHER_LONGITUDE
    weather_latitude: float | None = None
    weather_longitude: float | None = None

    # News feeds tool: comma-separated RSS/Atom feed URLs
    # e.g. NOBS_NEWS_FEED_URLS="https://feeds.bbci.co.uk/news/rss.xml,https://hnrss.org/frontpage"
    news_feed_urls: str = ""

    # Web search: max results returned per query (1–10)
    web_search_max_results: int = Field(default=5, ge=1, le=10)

    # Overnight Tank queue: IANA timezone used to evaluate the overnight window
    # (e.g. "America/Chicago"). Falls back to UTC if unset or unrecognized.
    timezone: str = Field(default="UTC")
    overnight_queue_enabled: bool = True
    # HH:MM (24h, local to `timezone`); the window may wrap past midnight.
    overnight_window_start: str = Field(default="23:00")
    overnight_window_end: str = Field(default="06:00")
    # Queue only advances when recent CPU load is at or below this percentage,
    # so overnight work yields to anything the user is actively doing.
    overnight_idle_cpu_percent: float = Field(default=40.0, ge=0, le=100)

    # Dream Team Sandbox — local Ollama only; no cloud/external APIs in refinement loop
    dream_team_enabled: bool = True
    dream_team_model: str | None = None  # defaults to ollama_model (e.g. qwen3:8b)
    dream_team_max_agents: int = Field(default=3, ge=1, le=5)
    dream_team_max_iterations: int = Field(default=2, ge=1, le=3)
    dream_team_sandbox_max_steps: int = Field(default=2, ge=1, le=4)
    dream_team_score_threshold: float = Field(default=0.65, ge=0.0, le=1.0)
    dream_team_sandbox_path: Path = Path("data/dream-team-sandbox")
    dream_team_active_path: Path = Path("data/dream-team/active")

    # Live workplace dashboard — animated floor + filtered browser sandbox
    workplace_enabled: bool = True
    workplace_browser_allowed_domains: str = (
        "wikipedia.org,www.wikipedia.org,en.wikipedia.org,docs.python.org,developer.mozilla.org"
    )
    browser_sandbox_screenshot_path: Path = Path("data/workplace/screenshots")
    browser_sandbox_session_ttl_seconds: int = Field(default=1800, ge=60, le=7200)

    # Background Tank optimizer — useful local work when not serving user requests
    optimizer_enabled: bool = True
    # light | normal | heavy — scales idle/heavy intervals (heavy = more frequent jobs)
    optimizer_intensity: str = Field(default="normal", pattern="^(light|normal|heavy)$")
    optimizer_min_idle_seconds: int = Field(default=90, ge=15, le=3600)
    optimizer_heavy_interval_minutes: int = Field(default=20, ge=5, le=240)
    optimizer_light_interval_seconds: int = Field(default=45, ge=10, le=600)
    optimizer_max_concurrent: int = Field(default=1, ge=1, le=3)
    optimizer_idle_cpu_percent: float = Field(default=50.0, ge=0, le=100)
    optimizer_dream_team_batch_size: int = Field(default=3, ge=1, le=5)


@lru_cache
def get_settings() -> Settings:
    return Settings()
