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
    # LLM backend: "ollama" (default) or "openai". The openai backend targets any
    # OpenAI-compatible /v1 endpoint, including a local mlx-lm server on the same
    # host, which keeps model inference free and on-device.
    llm_backend: str = "ollama"
    llm_base_url: str = ""  # e.g. http://127.0.0.1:8081/v1 for a local mlx-lm server
    llm_model: str | None = None  # overrides ollama_model when backend is "openai"
    llm_api_key: SecretStr | None = None
    # Path to the NOBS docs knowledge brain (SQLite FTS5 index built by
    # `nobs-brain build`). Defaults to ~/.local/share/nobs-brain/brain.db.
    brain_db_path: Path | None = None
    ollama_timeout_seconds: float = Field(default=45.0, gt=0, le=300)
    device_token: SecretStr | None = None
    agent_database_path: Path = Path("data/nobs-agent.db")
    agent_workspace_path: Path = Path("data/agent-workspace")
    agent_project_path: Path = Path(".")
    agent_max_steps: int = Field(default=4, ge=1, le=8)
    # Self-improvement: at the end of each completed run, a lightweight local pass
    # distills the run into a durable insight and, when reusable, a draft skill
    # surfaced as a proposal. Purely best-effort.
    auto_improve_enabled: bool = True
    auto_improve_model: str | None = None  # defaults to the assistant model
    # Only reflect on runs that produced at least this many chars of output or
    # used tools, so trivial exchanges don't spawn self-improvement work.
    auto_improve_min_message_chars: int = Field(default=40, ge=0, le=4000)

    # Hard safety rule: any action that SENDS or EXTERNALIZES to a connected
    # account (Google, school, mail, calendar...) MUST wait for explicit user
    # approval. There is no auto-send path while this is true. Keeping this on
    # is non-negotiable for the "never send anything without permission" promise.
    send_requires_approval: bool = True
    # Venture / idea engine: a brainstorm'd idea scoring at or above this
    # threshold is 'validated' and surfaced as a reviewable proposal.
    venture_validate_score: float = Field(default=7.0, ge=0.0, le=10.0)
    # Offload lightweight ideation + self-improvement onto a local Apple-Silicon
    # MLX server (OpenAI-compatible /v1). This keeps heavy chat on Ollama and
    # warms the M-series GPU for the high-volume background passes — still $0.
    mlx_base_url: str = "http://127.0.0.1:8081/v1"
    venture_model: str = "mlx-community/Qwen2.5-1.5B-Instruct-4bit"

    # OpenRouter-powered brainstorm: when a key + models are set, NOBS runs the
    # idea council through your OpenRouter key on frontier/"expert" models for
    # the topic, instead of the local small model. Everything else stays local.
    openrouter_api_key: SecretStr | None = None
    openrouter_base_url: str = "https://openrouter.ai/api/v1"
    # comma-separated OpenRouter model ids used for the brainstorm council
    brainstorm_models: str = (
        "anthropic/claude-sonnet-4.5,openai/gpt-4.1-mini,deepseek/deepseek-chat-v3.1"
    )
    brainstorm_openrouter: bool = True
    dashboard_name: str = Field(default="Tank", min_length=1, max_length=40)
    advertised_address: str | None = None
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
    overnight_max_retries: int = Field(default=3, ge=0, le=10)

    # Compatibility controls for the persistent background queue used by older
    # Tank deployments. Keep these explicit so a client deployment cannot
    # silently disable scheduler work.
    background_max_concurrent: int = Field(default=1, ge=1, le=3)
    background_queue_schedule: str = Field(default="idle")
    background_max_cpu_percent: float = Field(default=70.0, ge=0, le=100)
    background_min_cpu_percent: float = Field(default=0.0, ge=0, le=100)

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
