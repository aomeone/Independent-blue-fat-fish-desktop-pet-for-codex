[CmdletBinding()]
param(
    [switch]$SkipCompile
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$packageRoot = Join-Path $repoRoot "codex-dafeiyu-pet-v2.0.0-windows\codex-dafeiyu-pet-v2.0.0-windows"
$installerSource = Join-Path $repoRoot "installer"
$buildRoot = Join-Path $repoRoot "build\windows-installer"
$payloadZip = Join-Path $buildRoot "payload.zip"
$launcherExe = Join-Path $packageRoot "start-pet.exe"
$setupExe = Join-Path $packageRoot "CodexDaFeiYuSetup.exe"
$outputSetupExe = Join-Path $repoRoot "CodexDaFeiYuSetup.exe"

function Get-CscPath {
    foreach ($candidate in @(
        "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe",
        "$env:WINDIR\Microsoft.NET\Framework\v4.0.30319\csc.exe"
    )) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return $candidate
        }
    }
    throw "找不到系统 C# 编译器 csc.exe。"
}

function Invoke-Csc([string[]]$Arguments) {
    & (Get-CscPath) @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "C# 编译失败，退出码 $LASTEXITCODE。"
    }
}

function Update-Checksums {
    $lines = Get-ChildItem -LiteralPath $packageRoot -Recurse -File |
        Where-Object { $_.Name -notin @("checksums.sha256", "CodexDaFeiYuSetup.exe") } |
        Sort-Object FullName |
        ForEach-Object {
            $relative = $_.FullName.Substring($packageRoot.Length).TrimStart("\", "/")
            $relative = $relative -replace "\\", "/"
            $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
            "$hash  $relative"
        }
    [System.IO.File]::WriteAllLines(
        (Join-Path $packageRoot "checksums.sha256"),
        $lines,
        [System.Text.UTF8Encoding]::new($false))
}

New-Item -ItemType Directory -Path $buildRoot -Force | Out-Null

if (-not $SkipCompile) {
    Remove-Item -LiteralPath $launcherExe -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath (Join-Path $packageRoot "CodexDaFeiYuPet.exe") -Force -ErrorAction SilentlyContinue
    $framework64 = "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319"
    Invoke-Csc @(
        "/nologo",
        "/target:winexe",
        "/out:$launcherExe",
        "/r:$framework64\System.Windows.Forms.dll",
        (Join-Path $installerSource "StandaloneLauncher.cs")
    )
}

Update-Checksums

$staging = Join-Path $buildRoot "payload-staging"
Remove-Item -LiteralPath $payloadZip -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $staging -Force | Out-Null
Get-ChildItem -LiteralPath $packageRoot -Force |
    Where-Object { $_.Name -notin @("CodexDaFeiYuSetup.exe") } |
    Copy-Item -Destination $staging -Recurse -Force
Compress-Archive -Path (Join-Path $staging "*") `
    -DestinationPath $payloadZip -CompressionLevel Optimal

if (-not $SkipCompile) {
    Remove-Item -LiteralPath $setupExe -Force -ErrorAction SilentlyContinue
    $framework = "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319"
    Invoke-Csc @(
        "/nologo",
        "/target:winexe",
        "/out:$setupExe",
        "/resource:$payloadZip,PAYLOAD",
        "/r:$framework\System.Windows.Forms.dll",
        "/r:$framework\System.Drawing.dll",
        "/r:$framework\System.IO.Compression.dll",
        "/r:$framework\System.IO.Compression.FileSystem.dll",
        "/r:$framework\Microsoft.CSharp.dll",
        (Join-Path $installerSource "DafeiyuSetup.cs")
    )
    Copy-Item -LiteralPath $setupExe -Destination $outputSetupExe -Force
}

Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "构建完成：" -ForegroundColor Green
Write-Host "  独立桌宠：$launcherExe"
Write-Host "  一键安装器：$setupExe"
Write-Host "  根目录副本：$outputSetupExe"
