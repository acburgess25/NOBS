#!/usr/bin/env python3
"""Run one shift of the local NOBS research team.

Each shift hands a single researcher role to the Tank agent, which works with
its normal allowlisted tools and its normal approval policy: it may read and
search freely, and it records what it learns as a proposal. Nothing it finds is
acted on without an explicit approval, exactly like any other agent run.

Findings accumulate in the agent database that already backs the Tank
(`agent_runs`, `audit_events`, `proposals`), so the library grows over time and
stays queryable from the app, the dashboard, and the API.

Roles rotate so no single topic starves. State is one small file, so the
rotation survives restarts without needing a scheduler that remembers anything.

Usage:
    python scripts/research_team.py                 # next role in rotation
    python scripts/research_team.py --role codebase # force one role
    python scripts/research_team.py --list          # show roles and next up

Environment:
    NOBS_API_URL              default http://127.0.0.1:8000
    NOBS_DEVICE_TOKEN         falls back to .env, then ~/.config/nobs/nobs-api.env
    NOBS_RESEARCH_STATE       rotation state file (default under the user state dir)
    NOBS_RESEARCH_TIMEOUT     seconds to wait for a shift (default 900)
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

import httpx

REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_API_URL = "http://127.0.0.1:8000"
DEFAULT_TIMEOUT = 900.0

# Each role is one researcher. Objectives are written so the local model has a
# concrete first move, a bounded scope, and an explicit instruction to record
# what it learned rather than to act on it.
ROLES: dict[str, dict[str, str]] = {
    "codebase": {
        "summary": "Reviews the NOBS codebase itself and proposes concrete engineering work",
        "context": "business",
        "objective": (
            "You are the engineering researcher for the NOBS project. Use list_workspace_files "
            "to see the current repository, and read the files that look most central. "
            "Study how the code is actually organized right now. Identify ONE specific, "
            "concrete improvement that would make the product more reliable, simpler, or "
            "easier to finish — a missing test, an unclear boundary, a fragile assumption, "
            "duplicated logic, or a gap between documentation and code. "
            "Be specific about the file and the change. Do not propose vague refactors. "
            "Record it with propose_idea using proposal_type 'optimization'."
        ),
    },
    "psychology": {
        "summary": "Studies UX and behavioral-science research, applies it to the NOBS interface",
        "context": "business",
        "objective": (
            "You are the UX and behavioral-science researcher for NOBS, a private local-first "
            "personal assistant for overwhelmed working adults. Use web_search and read_url to "
            "study published research on one topic this shift: cognitive load, habit formation, "
            "trust and transparency in software, attention and interruption, motivation, or "
            "accessibility for neurodivergent users. Prefer primary sources and established "
            "findings over listicles. Then propose ONE specific change to how NOBS behaves or "
            "presents information that follows from what you read, and name the finding it "
            "rests on. NOBS never uses dark patterns, manufactured urgency, guilt, or "
            "engagement bait — reject any technique that works by pressuring the user. "
            "Record it with propose_idea using proposal_type 'optimization'."
        ),
    },
    "market": {
        "summary": "Tracks the competitive and privacy-tech landscape",
        "context": "business",
        "objective": (
            "You are the market researcher for NOBS. Use web_search and read_url to study the "
            "current landscape for private, local-first, and on-device AI assistants: what "
            "shipped recently, what people complain about, what they pay for, and where the "
            "honest gaps are. Focus on evidence, not hype. Propose ONE positioning or product "
            "insight that NOBS could act on, and cite what it is based on. Be direct about "
            "anything that suggests NOBS's current plan is wrong. "
            "Record it with propose_idea using proposal_type 'optimization'."
        ),
    },
    "home": {
        "summary": "Learns the connected home and proposes safe automations",
        "context": "shared",
        "objective": (
            "You are the household researcher for NOBS. Use list_home_devices to see what is "
            "actually connected right now. Study the real devices, their rooms, and their "
            "current states. Propose ONE automation or routine that would genuinely help this "
            "specific household, using only devices that actually exist in the list. "
            "Say plainly which devices it would use and what would trigger it. "
            "Never propose anything touching locks, cameras, or alarms. "
            "Record it with propose_idea using proposal_type 'routine'."
        ),
    },
}

ROTATION = ["codebase", "psychology", "market", "home"]


def _state_path() -> Path:
    override = os.environ.get("NOBS_RESEARCH_STATE")
    if override:
        return Path(override).expanduser()
    base = os.environ.get("XDG_STATE_HOME")
    root = Path(base).expanduser() if base else Path.home() / ".local" / "state"
    return root / "nobs" / "research-rotation"


def _read_token_file(path: Path) -> str | None:
    if not path.is_file():
        return None
    try:
        for line in path.read_text(encoding="utf-8").splitlines():
            if line.startswith("NOBS_DEVICE_TOKEN="):
                return line.partition("=")[2].strip().strip("\"'")
    except OSError:
        return None
    return None


def resolve_token() -> str | None:
    token = os.environ.get("NOBS_DEVICE_TOKEN")
    if token:
        return token
    for candidate in (REPO_ROOT / ".env", Path.home() / ".config" / "nobs" / "nobs-api.env"):
        token = _read_token_file(candidate)
        if token:
            return token
    return None


def next_role() -> str:
    state = _state_path()
    previous = ""
    if state.is_file():
        try:
            previous = state.read_text(encoding="utf-8").strip()
        except OSError:
            previous = ""
    if previous in ROTATION:
        return ROTATION[(ROTATION.index(previous) + 1) % len(ROTATION)]
    return ROTATION[0]


def remember_role(role: str) -> None:
    state = _state_path()
    try:
        state.parent.mkdir(parents=True, exist_ok=True)
        state.write_text(role, encoding="utf-8")
    except OSError as error:
        # A shift that cannot persist rotation is still a useful shift.
        print(f"warning: could not record rotation state: {error}", file=sys.stderr)


def run_shift(role: str, api_url: str, token: str, timeout: float) -> int:
    spec = ROLES[role]
    print(f"NOBS research team — {role} shift")
    print(f"  {spec['summary']}")
    print(f"  Tank: {api_url}")

    try:
        with httpx.Client(timeout=timeout) as client:
            response = client.post(
                f"{api_url}/agent/tasks",
                headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
                json={
                    "objective": spec["objective"],
                    "context": spec["context"],
                    "mode": "assistant",
                },
            )
            response.raise_for_status()
            data = response.json()
    except httpx.HTTPError as error:
        print(f"Shift failed to reach the Tank: {error}", file=sys.stderr)
        return 1
    except ValueError as error:
        print(f"Tank returned invalid JSON: {error}", file=sys.stderr)
        return 1

    remember_role(role)

    print("\n--- Result ---")
    print(data.get("message", "(no message)"))
    for result in data.get("tool_results", []) or []:
        name = result.get("tool") or result.get("name") or "tool"
        payload = {k: v for k, v in result.items() if k not in {"tool", "name"}}
        print(f"  {name}: {json.dumps(payload)[:220]}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Run one shift of the local NOBS research team.")
    parser.add_argument("--role", choices=sorted(ROLES), help="Force a specific researcher role")
    parser.add_argument("--list", action="store_true", help="List roles and exit")
    args = parser.parse_args()

    if args.list:
        upcoming = next_role()
        for name in ROTATION:
            marker = "→" if name == upcoming else " "
            print(f"{marker} {name:<11} {ROLES[name]['summary']}")
        return 0

    token = resolve_token()
    if not token:
        print(
            "No device token found. Set NOBS_DEVICE_TOKEN, or add it to .env or "
            "~/.config/nobs/nobs-api.env",
            file=sys.stderr,
        )
        return 2

    api_url = os.environ.get("NOBS_API_URL", DEFAULT_API_URL).rstrip("/")
    try:
        timeout = float(os.environ.get("NOBS_RESEARCH_TIMEOUT", DEFAULT_TIMEOUT))
    except ValueError:
        timeout = DEFAULT_TIMEOUT

    return run_shift(args.role or next_role(), api_url, token, timeout)


if __name__ == "__main__":
    raise SystemExit(main())
