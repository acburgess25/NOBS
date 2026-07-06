#!/usr/bin/env sh
set -eu

MODELS="${NOBS_OLLAMA_MODELS:-qwen3:8b qwen2.5-coder:14b}"
OPEN_WEBUI_VENV="${NOBS_OPEN_WEBUI_VENV:-$HOME/.nobs/open-webui}"

PYTHON_CMD=""
for candidate in python3.14 python3.13 python3.12 python3.11 python3; do
  if command -v "$candidate" >/dev/null 2>&1; then
    PYTHON_CMD="$candidate"
    break
  fi
done

if [ -z "$PYTHON_CMD" ]; then
  echo "Python 3.11+ is required." >&2
  exit 1
fi

"$PYTHON_CMD" - <<'PY'
import sys
if sys.version_info < (3, 11):
    version = ".".join(map(str, sys.version_info[:3]))
    raise SystemExit(f"Python 3.11+ required, found {version}")
PY

if ! command -v ollama >/dev/null 2>&1; then
  echo "Ollama is required. Install it first: https://ollama.com/download" >&2
  exit 1
fi

for model in $MODELS; do
  echo "Pulling model: $model"
  ollama pull "$model"
done

if ! command -v aider >/dev/null 2>&1; then
  echo "Installing aider-chat"
  "$PYTHON_CMD" -m ensurepip --upgrade >/dev/null 2>&1 || true
  "$PYTHON_CMD" -m pip install --user --upgrade aider-chat
fi

mkdir -p "$(dirname "$OPEN_WEBUI_VENV")"
if [ ! -x "$OPEN_WEBUI_VENV/bin/python" ]; then
  "$PYTHON_CMD" -m venv "$OPEN_WEBUI_VENV"
fi
"$OPEN_WEBUI_VENV/bin/python" -m pip install --upgrade pip
"$OPEN_WEBUI_VENV/bin/python" -m pip install --upgrade open-webui

echo ""
echo "NOBS local AI stack is ready."
echo "Open WebUI start command:"
echo "  $OPEN_WEBUI_VENV/bin/open-webui serve --host 127.0.0.1 --port 8080"
