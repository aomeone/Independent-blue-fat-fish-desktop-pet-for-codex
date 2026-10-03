[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$env:CODEX_DAFEIYU_LAYOUT_PATH = Join-Path $env:LOCALAPPDATA "Codex\codex-dafeiyu-standalone\layout.json"
$env:CODEX_DAFEIYU_STATUS_PATH = Join-Path $env:LOCALAPPDATA "Codex\codex-dafeiyu\status.json"

& py -3 (Join-Path $root "standalone\runtime\helper.py") --standalone @args
exit $LASTEXITCODE
