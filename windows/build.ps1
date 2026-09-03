<#
.SYNOPSIS
    Builds TextPolisher for Windows: publishes a self-contained app and compiles
    the one-click installer (TextPolisher-Setup.exe).

.DESCRIPTION
    1. dotnet publish (self-contained win-x64) -> windows\publish
    2. Inno Setup (iscc) compiles installer\TextPolisher.iss -> windows\dist

.PARAMETER Version
    Version string embedded in the installer. Default 1.0.0.

.EXAMPLE
    .\build.ps1
    .\build.ps1 -Version 1.1.0
#>
param(
    [string]$Version = "1.0.0"
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$project = Join-Path $root "src\TextPolisher\TextPolisher.csproj"
$publishDir = Join-Path $root "publish"
$issScript = Join-Path $root "installer\TextPolisher.iss"

Write-Host "==> Publishing TextPolisher (self-contained win-x64)..." -ForegroundColor Cyan

if (Test-Path $publishDir) {
    Remove-Item $publishDir -Recurse -Force
}

dotnet publish $project `
    -c Release `
    -r win-x64 `
    --self-contained true `
    -p:Version=$Version `
    -p:PublishSingleFile=false `
    -o $publishDir

if ($LASTEXITCODE -ne 0) {
    throw "dotnet publish failed with exit code $LASTEXITCODE"
}

Write-Host "==> Locating Inno Setup compiler (iscc)..." -ForegroundColor Cyan

$iscc = Get-Command iscc.exe -ErrorAction SilentlyContinue
if (-not $iscc) {
    $candidates = @(
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { $iscc = $c; break }
    }
} else {
    $iscc = $iscc.Source
}

if (-not $iscc) {
    Write-Warning "Inno Setup (iscc.exe) not found. The self-contained app is in '$publishDir'."
    Write-Warning "Install Inno Setup 6 from https://jrsoftware.org/isdl.php and re-run to build the installer."
    exit 0
}

Write-Host "==> Compiling installer with $iscc ..." -ForegroundColor Cyan

& $iscc "/DAppVersion=$Version" $issScript
if ($LASTEXITCODE -ne 0) {
    throw "Inno Setup compilation failed with exit code $LASTEXITCODE"
}

Write-Host "==> Done. Installer is in windows\dist\TextPolisher-Setup.exe" -ForegroundColor Green
