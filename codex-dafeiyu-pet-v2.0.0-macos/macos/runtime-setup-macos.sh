#!/bin/bash
set -euo pipefail

CODEX_DAFEIYU_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CODEX_DAFEIYU_RUNTIME_ROOT="${HOME}/Library/Application Support/Codex/codex-dafeiyu-runtime"
CODEX_DAFEIYU_VENV="${CODEX_DAFEIYU_RUNTIME_ROOT}/venv"
export CODEX_DAFEIYU_ROOT

codex_dafeiyu_find_brew() {
  if command -v brew >/dev/null 2>&1; then
    command -v brew
  elif [[ -x /opt/homebrew/bin/brew ]]; then
    printf '%s\n' /opt/homebrew/bin/brew
  elif [[ -x /usr/local/bin/brew ]]; then
    printf '%s\n' /usr/local/bin/brew
  else
    return 1
  fi
}

codex_dafeiyu_find_node() {
  local candidate
  candidate="${CODEX_DAFEIYU_NODE:-}"
  if [[ -n "$candidate" && -x "$candidate" ]]; then
    printf '%s\n' "$candidate"
  elif command -v node >/dev/null 2>&1; then
    command -v node
    return 0
  fi
  for candidate in "$HOME"/.nvm/versions/node/*/bin/node "$HOME"/.volta/bin/node "$HOME"/.asdf/installs/nodejs/*/bin/node; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

codex_dafeiyu_try_python() {
  local candidate="$1"
  if [[ -n "$candidate" ]] && codex_dafeiyu_python_usable "$candidate"; then
    printf '%s\n' "$candidate"
    return 0
  fi
  return 1
}

codex_dafeiyu_python_usable() {
  local candidate="$1"
  [[ -x "$candidate" ]] &&
    "$candidate" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)' >/dev/null 2>&1
}

codex_dafeiyu_find_python() {
  local candidate
  local -a candidates=()
  if [[ -n "${CODEX_DAFEIYU_PYTHON:-}" ]] && codex_dafeiyu_python_usable "$CODEX_DAFEIYU_PYTHON"; then
    printf '%s\n' "$CODEX_DAFEIYU_PYTHON"
    return 0
  fi
  candidates+=("$(command -v python3 2>/dev/null || true)")
  candidates+=("$(command -v python 2>/dev/null || true)")
  candidates+=("$HOME/.local/bin/python3")
  for candidate in "$HOME"/.pyenv/versions/*/bin/python3; do
    candidates+=("$candidate")
  done
  for candidate in "${candidates[@]}"; do
    if codex_dafeiyu_try_python "$candidate"; then
      return 0
    fi
  done
  return 1
}

codex_dafeiyu_pyside_available() {
  local candidate="$1"
  "$candidate" -c 'import PySide6' >/dev/null 2>&1
}

codex_dafeiyu_confirm_install() {
  local missing="$1"
  /usr/bin/osascript - "$missing" <<'APPLESCRIPT'
on run argv
  set promptText to "Codex 大肥鱼还缺少运行依赖：" & return & return & (item 1 of argv) & return & return & "将下载并安装这些组件。PySide6 会安装在 Codex 专用环境中；安装 Homebrew 时会打开 Terminal，可能需要按提示完成系统认证。是否继续？"
  set resultButton to button returned of (display dialog promptText with title "设置 Codex 大肥鱼运行环境" buttons {"取消", "继续安装"} default button "继续安装" cancel button "取消" with icon caution)
  return resultButton
end run
APPLESCRIPT
}

codex_dafeiyu_open_brew_installer() {
  local status_file script_file quoted_status quoted_script terminal_command result attempt brew
  status_file="$(mktemp -t codex-dafeiyu-brew.XXXXXX)"
  script_file="$(mktemp -t codex-dafeiyu-homebrew.XXXXXX)"
  rm -f "$status_file"
  rm -f "$script_file"
  printf -v quoted_status '%q' "$status_file"
  printf -v quoted_script '%q' "$script_file"
  terminal_command="/usr/bin/curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o $quoted_script && /bin/bash $quoted_script; result=\$?; printf \"%s\" \"\$result\" > $quoted_status; rm -f $quoted_script"

  if ! /usr/bin/osascript - "$terminal_command" <<'APPLESCRIPT'
on run argv
  tell application "Terminal"
    activate
    do script (item 1 of argv)
  end tell
end run
APPLESCRIPT
  then
    rm -f "$status_file" "$script_file"
    echo "Could not open Terminal to install Homebrew."
    return 1
  fi

  for ((attempt = 0; attempt < 900; attempt += 1)); do
    if [[ -f "$status_file" ]]; then
      result="$(<"$status_file")"
      rm -f "$status_file"
      if [[ "$result" != "0" ]]; then
        echo "Homebrew installation did not complete successfully. Check the Terminal window and try again."
        return 1
      fi
      brew="$(codex_dafeiyu_find_brew || true)"
      if [[ -n "$brew" ]]; then
        printf '%s\n' "$brew"
        return 0
      fi
      echo "Homebrew finished, but its brew command was not found."
      return 1
    fi
    sleep 2
  done
  rm -f "$status_file"
  echo "Timed out waiting for Homebrew. Finish or close the Terminal installer, then reopen the app."
  return 1
}

codex_dafeiyu_ensure_runtime() {
  local node_bin python_bin brew_bin brew_prefix missing_text choice
  local -a missing=()
  local -a formulae=()

  node_bin="$(codex_dafeiyu_find_node || true)"
  python_bin="$(codex_dafeiyu_find_python || true)"
  if [[ -n "$python_bin" && -x "$CODEX_DAFEIYU_VENV/bin/python" ]] &&
     codex_dafeiyu_pyside_available "$CODEX_DAFEIYU_VENV/bin/python"; then
    python_bin="$CODEX_DAFEIYU_VENV/bin/python"
  fi
  if [[ -z "$node_bin" ]]; then missing+=("Node.js (for Codex hooks)"); fi
  if [[ -z "$python_bin" ]]; then missing+=("Python 3.10 or newer"); fi
  if [[ -n "$python_bin" ]] && ! codex_dafeiyu_pyside_available "$python_bin"; then
    missing+=("PySide6 (desktop pet interface)")
  fi

  if ((${#missing[@]} == 0)); then
    export CODEX_DAFEIYU_NODE="$node_bin"
    export CODEX_DAFEIYU_PYTHON="$python_bin"
    return 0
  fi

  brew_bin="$(codex_dafeiyu_find_brew || true)"
  if [[ -z "$brew_bin" && ( -z "$node_bin" || -z "$python_bin" ) ]]; then
    missing+=("Homebrew (package manager for the missing runtimes)")
  fi
  missing_text="$(printf '• %s\n' "${missing[@]}")"
  choice="$(codex_dafeiyu_confirm_install "$missing_text")" || {
    echo "Dependency installation was cancelled."
    return 1
  }
  if [[ "$choice" != "继续安装" ]]; then
    echo "Dependency installation was cancelled."
    return 1
  fi

  /usr/bin/osascript -e 'display notification "正在检测并安装所需组件，请稍候。" with title "Codex 大肥鱼"'

  if [[ -z "$brew_bin" && ( -z "$node_bin" || -z "$python_bin" ) ]]; then
    brew_bin="$(codex_dafeiyu_open_brew_installer)" || return 1
  fi

  if [[ -n "$brew_bin" ]]; then
    brew_prefix="$("$brew_bin" --prefix)"
    PATH="$brew_prefix/bin:$brew_prefix/sbin:/opt/homebrew/bin:/usr/local/bin:/opt/local/bin:$HOME/.volta/bin:$PATH"
    export PATH
    node_bin="$(codex_dafeiyu_find_node || true)"
    python_bin="$(codex_dafeiyu_find_python || true)"
  fi

  if [[ -z "$node_bin" ]]; then formulae+=(node); fi
  if [[ -z "$python_bin" ]]; then formulae+=(python); fi
  if ((${#formulae[@]} > 0)); then
    [[ -n "$brew_bin" ]] || {
      echo "Homebrew is required to install the missing runtimes."
      return 1
    }
    "$brew_bin" install "${formulae[@]}"
    brew_prefix="$("$brew_bin" --prefix)"
    PATH="$brew_prefix/bin:$brew_prefix/sbin:$PATH"
    export PATH
    node_bin="$(codex_dafeiyu_find_node || true)"
    python_bin="$(codex_dafeiyu_find_python || true)"
  fi

  if [[ -z "$node_bin" ]]; then
    echo "Node.js installation finished, but the node executable was not found."
    return 1
  fi
  if [[ -z "$python_bin" ]]; then
    echo "Python 3.10 or newer could not be found after installation."
    return 1
  fi

  if ! codex_dafeiyu_pyside_available "$python_bin"; then
    mkdir -p "$CODEX_DAFEIYU_RUNTIME_ROOT"
    if ! "$CODEX_DAFEIYU_VENV/bin/python" -c 'import PySide6' >/dev/null 2>&1; then
      "$python_bin" -m venv --clear "$CODEX_DAFEIYU_VENV"
      "$CODEX_DAFEIYU_VENV/bin/python" -m pip install --disable-pip-version-check \
        -r "$CODEX_DAFEIYU_ROOT/standalone/requirements.txt"
    fi
    python_bin="$CODEX_DAFEIYU_VENV/bin/python"
  fi

  if ! "$python_bin" -c 'import PySide6' >/dev/null 2>&1; then
    echo "PySide6 installation completed, but its import check failed."
    return 1
  fi

  export CODEX_DAFEIYU_NODE="$node_bin"
  export CODEX_DAFEIYU_PYTHON="$python_bin"
  return 0
}
