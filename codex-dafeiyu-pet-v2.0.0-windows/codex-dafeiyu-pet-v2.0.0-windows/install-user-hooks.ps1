[CmdletBinding()]
param(
    [string]$CodexHome = "",
    [string]$PluginRoot = "",
    [string]$NodePath = "",
    [switch]$NoBackup
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Get-FullPath([string]$Path) {
    return [System.IO.Path]::GetFullPath($Path)
}

function Resolve-NodePath([string]$RequestedPath) {
    if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
        $resolved = Get-FullPath $RequestedPath
        if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
            throw "The requested Node executable does not exist: $resolved"
        }
        return $resolved
    }

    $command = Get-Command node.exe -ErrorAction SilentlyContinue
    if ($command -and (Test-Path -LiteralPath $command.Source -PathType Leaf)) {
        return Get-FullPath $command.Source
    }

    foreach ($candidate in @(
        (Join-Path ${env:ProgramFiles} "nodejs\node.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "nodejs\node.exe"),
        (Join-Path ${env:LOCALAPPDATA} "Programs\nodejs\node.exe")
    )) {
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and
            (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return Get-FullPath $candidate
        }
    }

    throw "Node.js was not found. Install Node.js or rerun with -NodePath."
}

function Resolve-HookScript([string]$CodexHomePath, [string]$RequestedRoot) {
    $candidates = [System.Collections.Generic.List[string]]::new()

    if (-not [string]::IsNullOrWhiteSpace($RequestedRoot)) {
        $candidates.Add((Join-Path (Get-FullPath $RequestedRoot) "hooks\codex-pet.mjs"))
    }

    $environmentRoot = [Environment]::GetEnvironmentVariable("CODEX_DAFEIYU_PLUGIN_ROOT")
    if (-not [string]::IsNullOrWhiteSpace($environmentRoot)) {
        $candidates.Add((Join-Path (Get-FullPath $environmentRoot) "hooks\codex-pet.mjs"))
    }

    $cacheRoot = Join-Path $CodexHomePath "plugins\cache\codex-dafeiyu-local\codex-dafeiyu"
    if (Test-Path -LiteralPath $cacheRoot -PathType Container) {
        $cached = Get-ChildItem -LiteralPath $cacheRoot -Filter "codex-pet.mjs" -File -Recurse |
            Sort-Object LastWriteTimeUtc -Descending
        foreach ($item in $cached) {
            $candidates.Add($item.FullName)
        }
    }

    $sourceCandidate = Join-Path $PSScriptRoot "hooks\codex-pet.mjs"
    $candidates.Add($sourceCandidate)

    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return Get-FullPath $candidate
        }
    }

    throw @"
Could not find codex-pet.mjs.
Install or enable the Codex whale pet plugin first, then run this installer again.
You can also pass -PluginRoot with the plugin directory.
"@
}

function Get-HookCommands($HookGroup) {
    $values = [System.Collections.Generic.List[string]]::new()
    if ($null -eq $HookGroup) {
        return $values
    }
    foreach ($hook in @($HookGroup.hooks)) {
        foreach ($propertyName in @("command", "commandWindows")) {
            $property = $hook.PSObject.Properties[$propertyName]
            if ($property -and $property.Value) {
                $values.Add([string]$property.Value)
            }
        }
    }
    return $values
}

function Ensure-Property($Object, [string]$Name, $Value) {
    $property = $Object.PSObject.Properties[$Name]
    if ($property) {
        $Object.$Name = $Value
    }
    else {
        $Object | Add-Member -MemberType NoteProperty -Name $Name -Value $Value
    }
}

if ([string]::IsNullOrWhiteSpace($CodexHome)) {
    $CodexHome = Join-Path ([Environment]::GetFolderPath("UserProfile")) ".codex"
}
$CodexHome = Get-FullPath $CodexHome
$hooksPath = Join-Path $CodexHome "hooks.json"
$nodeExecutable = Resolve-NodePath $NodePath
$hookScript = Resolve-HookScript $CodexHome $PluginRoot

$command = 'node "' + $hookScript + '"'
$commandWindows = '"' + $nodeExecutable + '" "' + $hookScript + '"'
$events = @(
    "SessionStart",
    "UserPromptSubmit",
    "PreToolUse",
    "PostToolUse",
    "PermissionRequest",
    "SubagentStart",
    "SubagentStop",
    "Stop",
    "Interrupt",
    "SessionEnd"
)

if (Test-Path -LiteralPath $hooksPath -PathType Leaf) {
    try {
        $config = Get-Content -LiteralPath $hooksPath -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        throw "Cannot parse existing hooks.json. No changes were written. $($_.Exception.Message)"
    }
}
else {
    $config = [pscustomobject]@{}
}

if (-not $config.PSObject.Properties["hooks"] -or $null -eq $config.hooks) {
    $config | Add-Member -MemberType NoteProperty -Name "hooks" -Value ([pscustomobject]@{})
}

$hookDefinition = [pscustomobject]@{
    type = "command"
    command = $command
    commandWindows = $commandWindows
    async = $true
    timeout = 5
}
$newGroup = [pscustomobject]@{
    hooks = @($hookDefinition)
}

foreach ($event in $events) {
    $existingGroups = @()
    $eventProperty = $config.hooks.PSObject.Properties[$event]
    if ($eventProperty -and $null -ne $eventProperty.Value) {
        $existingGroups = @($eventProperty.Value)
    }

    $filteredGroups = @(
        $existingGroups | Where-Object {
            $commands = @(Get-HookCommands $_)
            ($commands -notcontains $command) -and
            ($commands -notcontains $commandWindows)
        }
    )
    Ensure-Property $config.hooks $event (@($filteredGroups) + @($newGroup))
}

New-Item -ItemType Directory -Path (Split-Path -Parent $hooksPath) -Force | Out-Null
$temporaryPath = "$hooksPath.$PID.tmp"
$backupPath = "$hooksPath.bak"
$json = $config | ConvertTo-Json -Depth 30
[System.IO.File]::WriteAllText(
    $temporaryPath,
    $json + [Environment]::NewLine,
    [System.Text.UTF8Encoding]::new($false)
)

try {
    if ((Test-Path -LiteralPath $hooksPath -PathType Leaf) -and -not $NoBackup) {
        Copy-Item -LiteralPath $hooksPath -Destination $backupPath -Force
    }
    Move-Item -LiteralPath $temporaryPath -Destination $hooksPath -Force
}
catch {
    if (Test-Path -LiteralPath $temporaryPath) {
        Remove-Item -LiteralPath $temporaryPath -Force
    }
    throw
}

Write-Host ""
Write-Host "Installed Codex whale pet user hooks." -ForegroundColor Green
Write-Host "Hook script: $hookScript"
Write-Host "Node: $nodeExecutable"
Write-Host "Configuration: $hooksPath"
if ((Test-Path -LiteralPath $backupPath -PathType Leaf) -and -not $NoBackup) {
    Write-Host "Previous configuration backed up at: $backupPath"
}
Write-Host ""
Write-Host "Restart Codex Desktop, then open /hooks and trust the new user hooks if prompted."
