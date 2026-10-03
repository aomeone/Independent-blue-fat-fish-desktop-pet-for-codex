#!/bin/bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_FILE="$(mktemp -t codex-dafeiyu-install.XXXXXX)"
trap 'rm -f "$LOG_FILE"' EXIT
PATH="/opt/homebrew/bin:/usr/local/bin:/opt/local/bin:$HOME/.volta/bin:$HOME/.local/bin:$HOME/bin:$PATH"
export PATH

show_error() {
  /usr/bin/osascript - "$1" <<'APPLESCRIPT'
on run argv
  display dialog (item 1 of argv) with title "Codex 大肥鱼" buttons {"好"} default button "好" with icon stop
end run
APPLESCRIPT
}

show_log_error() {
  local title="$1"
  local details
  details="$(tail -n 18 "$LOG_FILE")"
  show_error "$title

$details"
}

CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
DEST="$CODEX_HOME/pets/dafeiyu-whale-maid"

if ! (
  cd -- "$ROOT"
  shasum -a 256 -c checksums.sha256
) >"$LOG_FILE" 2>&1; then
  show_log_error "Codex 大肥鱼校验失败："
  exit 1
fi

export CODEX_DAFEIYU_ROOT="$ROOT"
source "$ROOT/macos/runtime-setup-macos.sh"

if ! codex_dafeiyu_ensure_runtime >"$LOG_FILE" 2>&1; then
  show_log_error "运行环境准备失败："
  exit 1
fi

if [[ ! -f "$DEST/pet.json" || ! -f "$DEST/spritesheet.webp" ]] ||
   ! cmp -s "$ROOT/pet.json" "$DEST/pet.json" ||
   ! cmp -s "$ROOT/spritesheet.webp" "$DEST/spritesheet.webp"; then
  install_command=("$ROOT/macos/install-macos.sh")
else
  install_command=("$ROOT/macos/install-user-hooks.sh" --codex-home "$CODEX_HOME" --plugin-root "$ROOT")
fi

if ! "${install_command[@]}" >"$LOG_FILE" 2>&1; then
  show_log_error "Codex 大肥鱼安装失败："
  exit 1
fi

if ! "$ROOT/macos/start-pet-macos.sh" "$@" >"$LOG_FILE" 2>&1; then
  show_log_error "Mini 已安装，但独立桌宠启动失败："
  exit 1
fi
