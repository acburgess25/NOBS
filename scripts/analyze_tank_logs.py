import httpx
import json
import sys
from pathlib import Path

def main():
    log_path = Path("/tmp/tank_api.log")
    if not log_path.exists():
        print("Log file not found.")
        return

    # Read last 100 lines for brevity to the LLM
    lines = log_path.read_text(encoding="utf-8").splitlines()
    recent_logs = "\n".join(lines[-100:])

    prompt = f"""
Analyze the following backend API logs for the NOBS Tank service.
Identify any errors, warnings, or anomalies. If everything is running smoothly, summarize the general activity (e.g., endpoints being hit).

Logs:
{recent_logs}
"""

    payload = {
        "model": "qwen2.5-coder:14b",
        "prompt": prompt,
        "stream": False
    }

    print("Analyzing logs using local Mac Ollama (qwen2.5-coder:14b)...")
    try:
        response = httpx.post("http://127.0.0.1:11434/api/generate", json=payload, timeout=60.0)
        response.raise_for_status()
        result = response.json()
        print("\n=== Analysis Result ===")
        print(result.get("response", "No response text found."))
        print("=======================\n")
    except Exception as e:
        print(f"Error querying local Ollama: {e}")

if __name__ == "__main__":
    main()
