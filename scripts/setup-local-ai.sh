#!/usr/bin/env sh
set -eu

MODELS="${NOBS_OLLAMA_MODELS:-qwen3:8b qwen2.5-coder:14b}"
OPEN_WEBUI_VENV="${NOBS_OPEN_WEBUI_VENV:-$HOME/.nobs/open-webui}"
AIDER_VENV="${NOBS_AIDER_VENV:-$HOME/.nobs/aider}"
OPEN_WEBUI_INSTALL_SKIPPED=0
AIDER_INSTALL_SKIPPED=0
OPEN_WEBUI_BIN=""

if command -v open-webui >/dev/null 2>&1; then
  OPEN_WEBUI_BIN="$(command -v open-webui)"
elif [ -x "$HOME/.openwebui/bin/open-webui" ]; then
  OPEN_WEBUI_BIN="$HOME/.openwebui/bin/open-webui"
fi

PYTHON_CMD=""
for candidate in python3.13 python3.12 python3.11 python3.14 python3; do
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
  mkdir -p "$(dirname "$AIDER_VENV")"
  if [ ! -x "$AIDER_VENV/bin/python" ]; then
    if ! "$PYTHON_CMD" -m venv "$AIDER_VENV"; then
      echo "Warning: unable to create aider venv. Install python3-venv (Linux) or use a Python with venv support." >&2
      AIDER_INSTALL_SKIPPED=1
    fi
  fi
  if [ "$AIDER_INSTALL_SKIPPED" -eq 0 ]; then
    if "$AIDER_VENV/bin/python" -m pip --version >/dev/null 2>&1; then
      "$AIDER_VENV/bin/python" -m pip install --upgrade pip
      "$AIDER_VENV/bin/python" -m pip install --upgrade aider-chat
      mkdir -p "$HOME/.local/bin"
      ln -sf "$AIDER_VENV/bin/aider" "$HOME/.local/bin/aider"
    else
      echo "Warning: pip is unavailable in aider venv; skipping aider install on this host." >&2
    fi
  fi
fi

if [ -z "$OPEN_WEBUI_BIN" ]; then
  PY_MINOR="$("$PYTHON_CMD" - <<'PY'
import sys
print(sys.version_info.minor)
PY
)"
  if [ "$PY_MINOR" -gt 12 ]; then
    echo "Warning: Open WebUI currently requires Python <= 3.12 for installation in this environment." >&2
    echo "Set NOBS_OPEN_WEBUI_VENV to a Python 3.11/3.12 environment or use the Tank-hosted Open WebUI service." >&2
    OPEN_WEBUI_INSTALL_SKIPPED=1
  fi
fi

if [ "$OPEN_WEBUI_INSTALL_SKIPPED" -eq 0 ] && [ -z "$OPEN_WEBUI_BIN" ]; then
  mkdir -p "$(dirname "$OPEN_WEBUI_VENV")"
  if [ ! -x "$OPEN_WEBUI_VENV/bin/python" ]; then
    "$PYTHON_CMD" -m venv "$OPEN_WEBUI_VENV"
  fi
  if ! "$OPEN_WEBUI_VENV/bin/python" -m pip install --upgrade pip; then
    rm -rf "$OPEN_WEBUI_VENV"
    "$PYTHON_CMD" -m venv "$OPEN_WEBUI_VENV"
    "$OPEN_WEBUI_VENV/bin/python" -m pip install --upgrade pip
  fi
  if ! "$OPEN_WEBUI_VENV/bin/python" -m pip install --upgrade open-webui; then
    rm -rf "$OPEN_WEBUI_VENV"
    "$PYTHON_CMD" -m venv "$OPEN_WEBUI_VENV"
    "$OPEN_WEBUI_VENV/bin/python" -m pip install --upgrade pip
    "$OPEN_WEBUI_VENV/bin/python" -m pip install --upgrade open-webui
  fi
  OPEN_WEBUI_BIN="$OPEN_WEBUI_VENV/bin/open-webui"
elif [ -n "$OPEN_WEBUI_BIN" ]; then
  OPEN_WEBUI_INSTALL_SKIPPED=1
fi

echo ""
echo "NOBS local AI stack is ready."
if [ "$OPEN_WEBUI_INSTALL_SKIPPED" -eq 1 ]; then
  if [ -n "$OPEN_WEBUI_BIN" ]; then
    echo "Open WebUI already available at: $OPEN_WEBUI_BIN"
  else
    echo "Open WebUI was not installed on this host. Use the Tank-hosted Open WebUI service."
  fi
else
  echo "Open WebUI start command:"
  echo "  $OPEN_WEBUI_VENV/bin/open-webui serve --host 127.0.0.1 --port 8080"
fi
