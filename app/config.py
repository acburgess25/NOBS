from functools import lru_cache

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
    ollama_base_url: str = "http://host.docker.internal:11434"


@lru_cache
def get_settings() -> Settings:
    return Settings()

