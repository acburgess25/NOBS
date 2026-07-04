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


@lru_cache
def get_settings() -> Settings:
    return Settings()
