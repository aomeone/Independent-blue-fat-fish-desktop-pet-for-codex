[CmdletBinding()]
param(
    [string]$CodexHome = "",
    [switch]$NoBackup,
    [switch]$SkipHooks
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

$packageRoot = Get-FullPath $PSScriptRoot
$manifestPath = Join-Path $packageRoot "pet.json"
$checksumPath = Join-Path $packageRoot "checksums.sha256"

if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "pet.json is missing from the release package."
}
if (-not (Test-Path -LiteralPath $checksumPath -PathType Leaf)) {
    throw "checksums.sha256 is missing from the release package."
}

foreach ($line in Get-Content -LiteralPath $checksumPath) {
    if ([string]::IsNullOrWhiteSpace($line)) {
        continue
    }
    if ($line -notmatch "^(?<hash>[0-9A-Fa-f]{64})\s+\*?(?<name>.+)$") {
        throw "Invalid checksum line: $line"
    }
    $name = $Matches["name"].Trim()
    $filePath = Join-Path $packageRoot $name
    if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
        throw "Checksum file is missing: $name"
    }
    $actualHash = (Get-FileHash -LiteralPath $filePath -Algorithm SHA256).Hash
    if ($actualHash -ine $Matches["hash"]) {
        throw "Checksum mismatch for $name."
    }
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$petId = [string]$manifest.id
$displayName = [string]$manifest.displayName
$spriteVersion = [int]$manifest.spriteVersionNumber
$spritesheetName = [string]$manifest.spritesheetPath

if ($petId -notmatch "^[a-z0-9][a-z0-9-]{1,63}$") {
    throw "pet.json contains an invalid pet id: $petId"
}
if ([string]::IsNullOrWhiteSpace($displayName)) {
    throw "pet.json is missing displayName."
}
if ($spriteVersion -ne 2) {
    throw "This installer only accepts Codex spriteVersionNumber 2 pets."
}
if ([string]::IsNullOrWhiteSpace($spritesheetName) -or
    [System.IO.Path]::GetFileName($spritesheetName) -ne $spritesheetName) {
    throw "pet.json must point to a file in the release root."
}

$sourceSpritesheet = Join-Path $packageRoot $spritesheetName
if (-not (Test-Path -LiteralPath $sourceSpritesheet -PathType Leaf)) {
    throw "The spritesheet referenced by pet.json is missing."
}

if ([string]::IsNullOrWhiteSpace($CodexHome)) {
    $userProfile = [Environment]::GetFolderPath("UserProfile")
    $CodexHome = Join-Path $userProfile ".codex"
}
$CodexHome = Get-FullPath $CodexHome
$petsRoot = Get-FullPath (Join-Path $CodexHome "pets")
$destination = Assert-ChildPath (Join-Path $petsRoot $petId) $petsRoot "Pet destination"
$backupRoot = Assert-ChildPath (Join-Path $petsRoot ".backups\$petId") $petsRoot "Backup directory"

New-Item -ItemType Directory -Path $petsRoot -Force | Out-Null
$tempDirectory = Assert-ChildPath (Join-Path $petsRoot (".${petId}.install-$([guid]::NewGuid().ToString('N'))")) $petsRoot "Temporary install directory"

$existingBackup = $null
try {
    New-Item -ItemType Directory -Path $tempDirectory -Force | Out-Null
    Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $tempDirectory "pet.json")
    Copy-Item -LiteralPath $sourceSpritesheet -Destination (Join-Path $tempDirectory $spritesheetName)

    if (Test-Path -LiteralPath $destination -PathType Container) {
        if (-not $NoBackup) {
            New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
            $backupName = "$(Get-Date -Format 'yyyyMMdd-HHmmss-fff')-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
            $existingBackup = Assert-ChildPath (Join-Path $backupRoot $backupName) $backupRoot "Backup directory"
            New-Item -ItemType Directory -Path $existingBackup -Force | Out-Null
            Copy-Item -LiteralPath $destination -Destination $existingBackup -Recurse
        }
        Remove-Item -LiteralPath $destination -Recurse -Force
    }

    Move-Item -LiteralPath $tempDirectory -Destination $destination
}
catch {
    if (Test-Path -LiteralPath $tempDirectory) {
        Remove-Item -LiteralPath $tempDirectory -Recurse -Force
    }
    if ($existingBackup -and (Test-Path -LiteralPath $existingBackup)) {
        if (-not (Test-Path -LiteralPath $destination)) {
            Move-Item -LiteralPath (Join-Path $existingBackup $petId) -Destination $destination
        }
    }
    throw
}

Write-Host ""
Write-Host "Installed Codex custom pet: $displayName" -ForegroundColor Green
Write-Host "Pet id: $petId"
Write-Host "Location: $destination"
if ($existingBackup) {
    Write-Host "Previous version backed up at: $existingBackup"
}
Write-Host ""
Write-Host "Open Codex Settings > Pets, click Refresh, and select $displayName."

if (-not $SkipHooks) {
    $hookInstaller = Join-Path $packageRoot "install-user-hooks.ps1"
    if (Test-Path -LiteralPath $hookInstaller -PathType Leaf) {
        try {
            & $hookInstaller -CodexHome $CodexHome
        }
        catch {
            Write-Warning "The custom pet was installed, but the Codex state bridge was not registered: $($_.Exception.Message)"
            Write-Warning "Run install-user-hooks.ps1 after enabling the Codex 大肥鱼 plugin."
        }
    }
    else {
        Write-Warning "install-user-hooks.ps1 is missing; the standalone pet will not follow Codex state yet."
    }
}
