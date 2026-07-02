#!/usr/bin/env python3
"""Cross-platform development entrypoint for the NOBS backend."""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
VENV = ROOT / ".venv"


def require_supported_python() -> None:
    if sys.version_info < (3, 11):
        version = ".".join(map(str, sys.version_info[:3]))
        raise SystemExit(
            f"NOBS requires Python 3.11 or newer; current interpreter is {version}."
        )


def venv_python() -> Path:
    if os.name == "nt":
        return VENV / "Scripts" / "python.exe"
    return VENV / "bin" / "python"


def run(*args: str, executable: Path | None = None) -> None:
    command = [str(executable or venv_python()), *args]
    subprocess.run(command, cwd=ROOT, check=True)


def setup() -> None:
    require_supported_python()
    subprocess.run([sys.executable, "-m", "venv", str(VENV)], cwd=ROOT, check=True)
    run("-m", "pip", "install", "--upgrade", "pip")
    run("-m", "pip", "install", "-e", ".[dev]")


def ensure_environment() -> None:
    if not venv_python().exists():
        raise SystemExit(
            "Development environment is missing. Run: python scripts/dev.py setup"
        )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("setup", "test", "lint", "run", "check"))
    args = parser.parse_args()

    if args.command == "setup":
        setup()
        return

    ensure_environment()

    if args.command in {"test", "check"}:
        run("-m", "pytest")
    if args.command in {"lint", "check"}:
        run("-m", "ruff", "check", ".")
    if args.command == "run":
        run("-m", "uvicorn", "app.main:app", "--reload")


if __name__ == "__main__":
    main()

