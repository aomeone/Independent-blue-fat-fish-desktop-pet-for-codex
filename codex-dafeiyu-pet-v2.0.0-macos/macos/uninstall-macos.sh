#!/bin/bash
set -euo pipefail

CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
RESTORE=0
while (($#)); do
  case "$1" in
    --codex-home) CODEX_HOME="${2:?missing path after --codex-home}"; shift 2 ;;
    --restore-backup) RESTORE=1; shift ;;
    -h|--help) echo "Usage: ./uninstall.sh [--codex-home PATH] [--restore-backup]"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

PET_ID="dafeiyu-whale-maid"
DEST="$CODEX_HOME/pets/$PET_ID"
BACKUP_ROOT="$CODEX_HOME/pets/.backups/$PET_ID"
[[ -d "$DEST" ]] || { echo "鲸鱼娘 · 大肥鱼 is not installed at $DEST."; exit 0; }
[[ -f "$DEST/pet.json" ]] || { echo "Refusing to remove an unrecognized directory: $DEST" >&2; exit 1; }
grep -q '"id"[[:space:]]*:[[:space:]]*"dafeiyu-whale-maid"' "$DEST/pet.json" || {
  echo "Installed pet id does not match this release." >&2; exit 1;
}

mkdir -p "$BACKUP_ROOT"
BACKUP="$BACKUP_ROOT/uninstall-$(date +%Y%m%d-%H%M%S)-$$"
mv "$DEST" "$BACKUP"
if ((RESTORE == 1)); then
previous="$(find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d ! -path "$BACKUP" -print | sort | tail -n 1 || true)"
  if [[ -n "$previous" && -f "$previous/pet.json" ]]; then
    mv "$previous" "$DEST"
    echo "Removed current version and restored: $DEST"
  elif [[ -n "$previous" && -f "$previous/$PET_ID/pet.json" ]]; then
    mv "$previous/$PET_ID" "$DEST"
    echo "Removed current version and restored: $DEST"
  fi
fi
echo "Uninstall backup: $BACKUP"
