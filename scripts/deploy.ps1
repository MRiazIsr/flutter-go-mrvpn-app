# MRVPN Quick Deploy
# Rebuilds Flutter app and replaces files in dist/
# Usage: .\scripts\deploy.ps1 [-SkipBuild] [-Launch]

param(
    [switch]$SkipBuild,
    [switch]$Launch
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$AppDir = Join-Path $ProjectRoot "app"
$DistDir = Join-Path $ProjectRoot "dist"
$FlutterBuild = Join-Path $AppDir "build\windows\x64\runner\Release"

# Resolve flutter — check PATH first, then known install location
$Flutter = Get-Command flutter -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
if (-not $Flutter) {
    $Flutter = "C:\Dev\flutter\bin\flutter.bat"
    if (-not (Test-Path $Flutter)) {
        throw "Flutter SDK not found. Install Flutter or set FLUTTER_ROOT."
    }
}

Write-Host ""
Write-Host "  MRVPN Deploy" -ForegroundColor Cyan
Write-Host "  ===============" -ForegroundColor Cyan
Write-Host ""

# ---- Stop running app if needed ----
$uiProcess = Get-Process -Name "MRVPN" -ErrorAction SilentlyContinue
$svcProcess = Get-Process -Name "MRVPN-service" -ErrorAction SilentlyContinue

if ($uiProcess -or $svcProcess) {
    Write-Host "[*] Stopping running MRVPN..." -ForegroundColor Yellow
    & taskkill /F /IM MRVPN-service.exe 2>$null
    & taskkill /F /IM MRVPN.exe 2>$null
    Stop-Process -Name "MRVPN" -Force -ErrorAction SilentlyContinue
    Stop-Process -Name "MRVPN-service" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    $still = Get-Process -Name "MRVPN-service" -ErrorAction SilentlyContinue
    if ($still) {
        Write-Host "  -> WARNING: MRVPN-service still running (elevated). Run as Admin." -ForegroundColor Red
        throw "Cannot stop elevated MRVPN-service.exe. Please run PowerShell as Administrator."
    }
    Write-Host "  -> Stopped" -ForegroundColor Green
}

# ---- Build Flutter ----
if (-not $SkipBuild) {
    Write-Host "[1/2] Building Flutter app (release)..." -ForegroundColor Yellow

    # Wipe the entire Windows build cache so icon/RC changes are always picked up.
    $winBuildCache = Join-Path $AppDir "build\windows"
    if (Test-Path $winBuildCache) {
        Write-Host "  Clearing Windows build cache..." -ForegroundColor DarkGray
        Remove-Item -Recurse -Force $winBuildCache
    }

    Push-Location $AppDir
    try {
        & $Flutter build windows --release
        if ($LASTEXITCODE -ne 0) { throw "Flutter build failed with exit code $LASTEXITCODE" }
        Write-Host "  -> Build successful" -ForegroundColor Green
    }
    finally {
        Pop-Location
    }
} else {
    Write-Host "[1/2] Skipping build (using existing output)" -ForegroundColor DarkGray
}

# ---- Verify build output exists ----
if (-not (Test-Path $FlutterBuild)) {
    # Try alternate path (non-x64)
    $FlutterBuild = Join-Path $AppDir "build\windows\runner\Release"
    if (-not (Test-Path $FlutterBuild)) {
        throw "Flutter build output not found. Run without -SkipBuild first."
    }
}

# ---- Deploy to dist ----
Write-Host "[2/2] Deploying to dist/..." -ForegroundColor Yellow

# Ensure dist exists
New-Item -ItemType Directory -Force -Path $DistDir | Out-Null

# Copy all Flutter build output (exe + dlls + data/)
Copy-Item -Path "$FlutterBuild\*" -Destination $DistDir -Recurse -Force
Write-Host "  -> Copied Flutter build output to dist/" -ForegroundColor Green

# Copy tray icon next to exe (system_tray needs it at runtime)
$trayIcoSrc = Join-Path $ProjectRoot "app\windows\runner\resources\app_icon.ico"
if (Test-Path $trayIcoSrc) {
    Copy-Item -Path $trayIcoSrc -Destination $DistDir -Force
    Write-Host "  -> Copied app_icon.ico (tray icon)" -ForegroundColor Green
}

# Verify key files
$exePath = Join-Path $DistDir "MRVPN.exe"
if (Test-Path $exePath) {
    $size = (Get-Item $exePath).Length / 1MB
    Write-Host "  -> MRVPN.exe: $([math]::Round($size, 1)) MB" -ForegroundColor Green
} else {
    Write-Host "  -> WARNING: MRVPN.exe not found in dist/" -ForegroundColor Red
}

$svcPath = Join-Path $DistDir "MRVPN-service.exe"
if (-not (Test-Path $svcPath)) {
    Write-Host "  -> NOTE: MRVPN-service.exe missing. Run .\scripts\build.ps1 to build Go backend." -ForegroundColor Yellow
}

# ---- Optionally launch ----
if ($Launch) {
    Write-Host ""
    Write-Host "[*] Launching MRVPN..." -ForegroundColor Cyan
    $launchBat = Join-Path $DistDir "launch.bat"
    if (Test-Path $launchBat) {
        Start-Process -FilePath $launchBat -WorkingDirectory $DistDir
    } else {
        Start-Process -FilePath $exePath -WorkingDirectory $DistDir
    }
}

Write-Host ""
Write-Host "  Deploy complete!" -ForegroundColor Green
Write-Host "  Output: $DistDir" -ForegroundColor Cyan
Write-Host ""
