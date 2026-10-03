#!/bin/bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
PLUGIN_ROOT="$ROOT"
NODE_PATH="${CODEX_DAFEIYU_NODE:-${NODE_PATH:-$(command -v node || true)}}"
NO_BACKUP=0

usage() {
  cat <<'EOF'
Usage: install-user-hooks.sh [--codex-home PATH] [--plugin-root PATH] [--node PATH] [--no-backup]
EOF
}

while (($#)); do
  case "$1" in
    --codex-home) CODEX_HOME="${2:?missing path after --codex-home}"; shift 2 ;;
    --plugin-root) PLUGIN_ROOT="${2:?missing path after --plugin-root}"; shift 2 ;;
    --node) NODE_PATH="${2:?missing path after --node}"; shift 2 ;;
    --no-backup) NO_BACKUP=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ "$NODE_PATH" != */* ]]; then
  NODE_PATH="$(command -v "$NODE_PATH" || true)"
fi
[[ -n "$NODE_PATH" && -x "$NODE_PATH" ]] || {
  echo "Node.js was not found. Install Node.js or pass --node /path/to/node." >&2
  exit 1
}
HOOK_SCRIPT="$PLUGIN_ROOT/hooks/codex-pet.mjs"
[[ -f "$HOOK_SCRIPT" ]] || { echo "Missing hook script: $HOOK_SCRIPT" >&2; exit 1; }

EXTRA_ARGS=()
if ((NO_BACKUP == 1)); then EXTRA_ARGS+=(--no-backup); fi
exec "$NODE_PATH" "$ROOT/macos/install-user-hooks.mjs" \
  --codex-home "$CODEX_HOME" \
  --plugin-root "$PLUGIN_ROOT" \
  --node "$NODE_PATH" \
  "${EXTRA_ARGS[@]}"
