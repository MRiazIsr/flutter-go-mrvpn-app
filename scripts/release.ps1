# MRVPN Release Script
# Creates a GitHub release with a ZIP archive of the built application.
#
# Usage:
#   .\scripts\release.ps1 -Version "1.0.0"
#   .\scripts\release.ps1 -Version "1.0.0" -SkipBuild    # Use existing dist/
#   .\scripts\release.ps1 -Version "1.0.0" -Draft         # Create as draft
#
# Prerequisites:
#   - GitHub CLI (gh) installed and authenticated: gh auth login
#   - Git repository with remote configured

param(
    [Parameter(Mandatory=$true)]
    [string]$Version,
    [switch]$SkipBuild,
    [switch]$Draft
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$DistDir = Join-Path $ProjectRoot "dist"
$ReleaseDir = Join-Path $ProjectRoot "build\release"
$ZipName = "MRVPN-$Version-windows-x64.zip"
$ZipPath = Join-Path $ReleaseDir $ZipName

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  MRVPN Release v$Version" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# ---- Verify tools ----
$gh = Get-Command gh -ErrorAction SilentlyContinue
if (-not $gh) {
    throw "GitHub CLI (gh) not found. Install from https://cli.github.com/"
}

# ---- Build ----
if (-not $SkipBuild) {
    Write-Host "[1/4] Building..." -ForegroundColor Yellow
    & "$ProjectRoot\scripts\build.ps1" -SkipInstaller
    Write-Host ""
} else {
    Write-Host "[1/4] Skipping build (using existing dist/)" -ForegroundColor DarkGray
}

# ---- Verify dist ----
Write-Host "[2/4] Verifying dist/..." -ForegroundColor Yellow

$requiredFiles = @("MRVPN.exe", "MRVPN-service.exe", "flutter_windows.dll", "app_icon.ico")
foreach ($file in $requiredFiles) {
    $path = Join-Path $DistDir $file
    if (-not (Test-Path $path)) {
        throw "Required file missing from dist/: $file"
    }
    $size = [math]::Round((Get-Item $path).Length / 1MB, 1)
    Write-Host "  $file ($size MB)" -ForegroundColor Green
}

# ---- Create ZIP ----
Write-Host "[3/4] Creating release archive..." -ForegroundColor Yellow

New-Item -ItemType Directory -Force -Path $ReleaseDir | Out-Null

# Remove old ZIP if exists
if (Test-Path $ZipPath) {
    Remove-Item $ZipPath -Force
}

# Create ZIP from dist contents
Compress-Archive -Path "$DistDir\*" -DestinationPath $ZipPath -CompressionLevel Optimal

$zipSize = [math]::Round((Get-Item $ZipPath).Length / 1MB, 1)
Write-Host "  -> $ZipName ($zipSize MB)" -ForegroundColor Green

# ---- Create GitHub Release ----
Write-Host "[4/4] Creating GitHub release..." -ForegroundColor Yellow

$tag = "v$Version"
$title = "MRVPN v$Version"
$notes = @"
## MRVPN v$Version

### Installation
1. Download ``$ZipName``
2. Extract to a folder
3. Run ``MRVPN.exe``
4. Accept the UAC prompt (required for VPN tunnel)

### What's included
- ``MRVPN.exe`` — Desktop UI
- ``MRVPN-service.exe`` — VPN backend service
- ``app_icon.ico`` — Application icon
- Flutter runtime and plugin DLLs
- ``wintun.dll`` — Network tunnel driver

### Requirements
- Windows 10/11 (x64)
- Administrator privileges (for TUN interface)
"@

$ghArgs = @(
    "release", "create", $tag,
    $ZipPath,
    "--title", $title,
    "--notes", $notes
)

if ($Draft) {
    $ghArgs += "--draft"
}

Push-Location $ProjectRoot
try {
    & gh @ghArgs
    if ($LASTEXITCODE -ne 0) { throw "gh release create failed" }
    Write-Host ""
    Write-Host "  Release $tag created!" -ForegroundColor Green
    & gh release view $tag --web
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Release v$Version complete!" -ForegroundColor Green
Write-Host "  Archive: $ZipPath" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
