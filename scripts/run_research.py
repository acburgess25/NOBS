#!/usr/bin/env python3
"""Trigger the Tank agent to run a system-wide research and proposal cycle."""

from __future__ import annotations

import os
import sys
from pathlib import Path

import httpx

# Load token from .env or config if available
ROOT = Path(__file__).resolve().parents[1]
ENV_FILE = ROOT / ".env"
DEVICE_TOKEN = os.environ.get("NOBS_DEVICE_TOKEN")
API_URL = os.environ.get("NOBS_API_URL", "http://127.0.0.1:8000")


def _load_token_from_file(path: Path) -> str | None:
    if not path.exists():
        return None
    try:
        for line in path.read_text(encoding="utf-8").splitlines():
            if line.startswith("NOBS_DEVICE_TOKEN="):
                return line.partition("=")[2].strip('"\'')
    except OSError:
        return None
    return None


if not DEVICE_TOKEN:
    DEVICE_TOKEN = _load_token_from_file(ENV_FILE)

# Also check typical Tank path config
TANK_ENV_FILE = Path.home() / ".config" / "nobs" / "nobs-api.env"
if not DEVICE_TOKEN:
    DEVICE_TOKEN = _load_token_from_file(TANK_ENV_FILE)

if not DEVICE_TOKEN:
    print(
        "Error: NOBS_DEVICE_TOKEN must be set in env or ~/.config/nobs/nobs-api.env",
        file=sys.stderr,
    )
    sys.exit(1)


def main() -> None:
    print(f"Triggering Tank research cycle at {API_URL}...")
    headers = {
        "Authorization": f"Bearer {DEVICE_TOKEN}",
        "Content-Type": "application/json",
    }
    payload = {
        "objective": (
            "Scan the home devices using list_home_devices and review workspace notes using "
            "list_workspace_files. Brainstorm potential automations, routines, or optimizations "
            "to make the home better, and propose 1-2 new ideas to the user using the propose_idea tool."
        ),
        "context": "shared",
        "mode": "assistant",
    }

    try:
        with httpx.Client(timeout=120.0) as client:
            response = client.post(
                f"{API_URL}/agent/tasks",
                headers=headers,
                json=payload,
            )
            response.raise_for_status()
            data = response.json()
    except httpx.HTTPError as error:
        print(f"Failed to connect to Tank API: {error}", file=sys.stderr)
        sys.exit(1)
    except ValueError as error:
        print(f"Tank API returned invalid JSON: {error}", file=sys.stderr)
        sys.exit(1)

    print("\n=== Agent Response ===")
    print(data.get("message"))
    print("\n=== Tool Results ===")
    for item in data.get("tool_results", []):
        print(f"- Tool: {item.get('tool')}")
        result = item.get("result", {})
        if "error" in result:
            print(f"  Error: {result['error']}")
        elif "proposal_id" in result:
            print(f"  Proposal ID: {result['proposal_id']}")
        elif "devices" in result:
            print(f"  Devices Found: {len(result['devices'])}")

    print("\nResearch cycle complete!")


if __name__ == "__main__":
    main()
