import os

import pytest

from app.config import get_settings


@pytest.fixture(autouse=True)
def hermetic_environment(tmp_path, monkeypatch) -> None:
    """Isolate every test from live state in the checkout it runs from.

    `Settings` resolves its data paths (`data/nobs-agent.db`,
    `data/agent-workspace`, ...) and its optional `.env` file relative to the
    current working directory, so a checkout with real Tank state — for
    example a populated `data/nobs-agent.db` holding device pairings — leaks
    into any test that does not override every path. Running each test from
    an empty temporary directory keeps the suite deterministic and keeps
    tests from ever reading or writing production data.

    Ambient `NOBS_*` environment variables are removed for the same reason:
    a deployed Tank exports real configuration that would silently override
    the defaults tests assert against. The cached `get_settings()` result is
    cleared so no test observes settings captured under another test's
    environment.
    """
    for name in list(os.environ):
        if name.startswith("NOBS_"):
            monkeypatch.delenv(name)
    monkeypatch.chdir(tmp_path)
    get_settings.cache_clear()
