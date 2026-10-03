#!/bin/bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
PET_ID="dafeiyu-whale-maid"
PETS_ROOT="$CODEX_HOME/pets"
DEST="$PETS_ROOT/$PET_ID"
BACKUP_ROOT="$PETS_ROOT/.backups/$PET_ID"

usage() {
  cat <<'EOF'
Usage: ./install.sh [--codex-home PATH] [--no-backup]
EOF
}

NO_BACKUP=0
while (($#)); do
  case "$1" in
    --codex-home) CODEX_HOME="${2:?missing path after --codex-home}"; shift 2 ;;
    --no-backup) NO_BACKUP=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

CODEX_HOME="$(cd -- "$CODEX_HOME" 2>/dev/null && pwd || printf '%s' "$CODEX_HOME")"
PETS_ROOT="$CODEX_HOME/pets"
DEST="$PETS_ROOT/$PET_ID"
BACKUP_ROOT="$PETS_ROOT/.backups/$PET_ID"

command -v shasum >/dev/null || { echo "shasum is required." >&2; exit 1; }
(
  cd -- "$ROOT"
  shasum -a 256 -c checksums.sha256
)

mkdir -p "$PETS_ROOT"
TMP="$PETS_ROOT/.${PET_ID}.install.$$"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP"
cp "$ROOT/pet.json" "$ROOT/spritesheet.webp" "$TMP/"

if [[ -e "$DEST" ]]; then
  if ((NO_BACKUP == 0)); then
    mkdir -p "$BACKUP_ROOT"
    BACKUP="$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)-$$"
    mkdir -p "$BACKUP"
    cp -R "$DEST" "$BACKUP/"
    echo "Previous version backed up at: $BACKUP"
  fi
  rm -rf "$DEST"
fi
mv "$TMP" "$DEST"
trap - EXIT

"$ROOT/macos/install-user-hooks.sh" --codex-home "$CODEX_HOME" --plugin-root "$ROOT"
echo
echo "Installed Codex custom pet: 鲸鱼娘 · 大肥鱼"
echo "Location: $DEST"
echo "Open Codex Settings > Pets, click Refresh, and select 鲸鱼娘 · 大肥鱼."
