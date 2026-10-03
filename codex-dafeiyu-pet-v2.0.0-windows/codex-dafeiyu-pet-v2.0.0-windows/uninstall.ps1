[CmdletBinding()]
param(
    [string]$CodexHome = "",
    [switch]$RestoreBackup
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Get-FullPath([string]$Path) {
    return [System.IO.Path]::GetFullPath($Path)
}

function Assert-ChildPath([string]$Path, [string]$Parent, [string]$Label) {
    $fullPath = (Get-FullPath $Path).TrimEnd("\")
    $fullParent = (Get-FullPath $Parent).TrimEnd("\") + "\"
    if (-not $fullPath.StartsWith($fullParent, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "$Label is outside the expected directory: $fullPath"
    }
    return $fullPath
}

$manifestPath = Join-Path (Get-FullPath $PSScriptRoot) "pet.json"
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "pet.json is missing from the release package."
}
$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$petId = [string]$manifest.id
$displayName = [string]$manifest.displayName
if ($petId -notmatch "^[a-z0-9][a-z0-9-]{1,63}$") {
    throw "pet.json contains an invalid pet id: $petId"
}

if ([string]::IsNullOrWhiteSpace($CodexHome)) {
    $userProfile = [Environment]::GetFolderPath("UserProfile")
    $CodexHome = Join-Path $userProfile ".codex"
}
$CodexHome = Get-FullPath $CodexHome
$petsRoot = Get-FullPath (Join-Path $CodexHome "pets")
$destination = Assert-ChildPath (Join-Path $petsRoot $petId) $petsRoot "Pet destination"
$backupRoot = Assert-ChildPath (Join-Path $petsRoot ".backups\$petId") $petsRoot "Backup directory"

if (-not (Test-Path -LiteralPath $destination -PathType Container)) {
    Write-Host "$displayName is not installed at $destination."
    exit 0
}

$installedManifestPath = Join-Path $destination "pet.json"
if (-not (Test-Path -LiteralPath $installedManifestPath -PathType Leaf)) {
    throw "Refusing to remove a directory without a matching pet.json: $destination"
}
$installedManifest = Get-Content -LiteralPath $installedManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ([string]$installedManifest.id -ne $petId) {
    throw "The installed pet id does not match this release. Refusing to remove it."
}

$previousBackups = @()
if (Test-Path -LiteralPath $backupRoot -PathType Container) {
    $previousBackups = @(Get-ChildItem -LiteralPath $backupRoot -Directory | Sort-Object LastWriteTime -Descending)
}

New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
$uninstallBackup = Assert-ChildPath (Join-Path $backupRoot ("uninstall-" + (Get-Date -Format "yyyyMMdd-HHmmss-fff") + "-" + [guid]::NewGuid().ToString("N").Substring(0, 8))) $backupRoot "Uninstall backup"
Move-Item -LiteralPath $destination -Destination $uninstallBackup

if ($RestoreBackup -and $previousBackups.Count -gt 0) {
    $restoreSource = Assert-ChildPath (Join-Path $previousBackups[0].FullName $petId) $previousBackups[0].FullName "Restore source"
    Move-Item -LiteralPath $restoreSource -Destination $destination
    Write-Host "Removed $displayName and restored the previous backup."
}
else {
    Write-Host "Removed $displayName from $destination."
}
Write-Host "Uninstall backup: $uninstallBackup"
