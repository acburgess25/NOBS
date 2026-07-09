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


@lru_cache
def get_settings() -> Settings:
    return Settings()
