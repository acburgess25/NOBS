from pathlib import Path
import sys

import httpx


LOG_PATH = Path("/tmp/tank_api.log")
OLLAMA_URL = "http://127.0.0.1:11434/api/generate"
MODEL = "qwen2.5-coder:14b"


def build_prompt(recent_logs: str) -> str:
    return (
        "Analyze the following backend API logs for the NOBS Tank service.\n"
        "Identify any errors, warnings, or anomalies. If everything is running smoothly, "
        "summarize the general activity (for example, endpoints being hit).\n\n"
        f"Logs:\n{recent_logs}\n"
    )


def main() -> int:
    if not LOG_PATH.exists():
        print("Log file not found.", file=sys.stderr)
        return 1

    try:
        lines = LOG_PATH.read_text(encoding="utf-8").splitlines()
    except OSError as error:
        print(f"Failed to read log file: {error}", file=sys.stderr)
        return 1

    recent_logs = "\n".join(lines[-100:])
    payload = {"model": MODEL, "prompt": build_prompt(recent_logs), "stream": False}

    print(f"Analyzing logs using local Ollama ({MODEL})...")
    try:
        response = httpx.post(OLLAMA_URL, json=payload, timeout=60.0)
        response.raise_for_status()
        result = response.json()
    except httpx.HTTPError as error:
        print(f"Failed to query Ollama: {error}", file=sys.stderr)
        return 1
    except ValueError as error:
        print(f"Ollama returned invalid JSON: {error}", file=sys.stderr)
        return 1

    print("\n=== Analysis Result ===")
    print(result.get("response", "No response text found."))
    print("=======================\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
