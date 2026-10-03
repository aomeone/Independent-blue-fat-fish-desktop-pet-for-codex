#!/bin/bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON_BIN="${CODEX_DAFEIYU_PYTHON:-}"
if [[ -z "$PYTHON_BIN" ]]; then
  if command -v python3 >/dev/null 2>&1; then PYTHON_BIN="$(command -v python3)"
  elif command -v python >/dev/null 2>&1; then PYTHON_BIN="$(command -v python)"
  else
    echo "Python 3 was not found. Install Python 3 and PySide6 first." >&2
    exit 1
  fi
fi

if ! "$PYTHON_BIN" -c 'import PySide6' >/dev/null 2>&1; then
  echo "PySide6 is missing. Install it with:" >&2
  echo "  \"$PYTHON_BIN\" -m pip install -r \"$ROOT/standalone/requirements.txt\"" >&2
  exit 1
fi

APP_SUPPORT="${HOME}/Library/Application Support/Codex"
export CODEX_DAFEIYU_LAYOUT_PATH="${CODEX_DAFEIYU_LAYOUT_PATH:-$APP_SUPPORT/codex-dafeiyu-standalone/layout.json}"
export CODEX_DAFEIYU_STATUS_PATH="${CODEX_DAFEIYU_STATUS_PATH:-$APP_SUPPORT/codex-dafeiyu/status.json}"
export CODEX_DAFEIYU_AUTO_DISCOVER="${CODEX_DAFEIYU_AUTO_DISCOVER:-1}"
exec "$PYTHON_BIN" "$ROOT/standalone/runtime/helper.py" --standalone "$@"
