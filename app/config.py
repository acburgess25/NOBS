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
    version: str = "0.1.0"
    timezone: str = Field(
        default="America/Chicago",
        description="IANA timezone for briefing schedules and scheduler matching",
    )
    stale_approval_minutes: int = Field(default=15, ge=1, le=1440)
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
    pairing_code_ttl_seconds: int = Field(default=900, ge=60, le=3600)


@lru_cache
def get_settings() -> Settings:
    return Settings()
