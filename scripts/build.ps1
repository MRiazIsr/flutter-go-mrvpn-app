# MRVPN Build Script
# Usage: .\scripts\build.ps1 [-SkipFlutter] [-SkipGo] [-SkipInstaller]

param(
    [switch]$SkipFlutter,
    [switch]$SkipGo,
    [switch]$SkipInstaller,
    [string]$GoTags = "with_quic,with_grpc,with_utls,with_gvisor,with_clash_api"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$DistDir = Join-Path $ProjectRoot "dist"

# Resolve flutter — check PATH first, then known install location
$Flutter = Get-Command flutter -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
if (-not $Flutter) {
    $Flutter = "C:\Dev\flutter\bin\flutter.bat"
    if (-not (Test-Path $Flutter)) {
        throw "Flutter SDK not found. Install Flutter or set FLUTTER_ROOT."
    }
}

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  MRVPN Build Script" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Project root: $ProjectRoot"
Write-Host ""

# ---- Stop running app if needed (prevents locked file errors) ----
# The service runs elevated, so we use taskkill which can kill elevated processes
# when the build script is run from an elevated prompt, or via the /F flag.
$uiProcess = Get-Process -Name "MRVPN" -ErrorAction SilentlyContinue
$svcProcess = Get-Process -Name "MRVPN-service" -ErrorAction SilentlyContinue

if ($uiProcess -or $svcProcess) {
    Write-Host "[*] Stopping running MRVPN processes..." -ForegroundColor Yellow
    # Use taskkill /F for elevated processes; also try Stop-Process as fallback
    & taskkill /F /IM MRVPN-service.exe 2>$null
    & taskkill /F /IM MRVPN.exe 2>$null
    Stop-Process -Name "MRVPN" -Force -ErrorAction SilentlyContinue
    Stop-Process -Name "MRVPN-service" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    # Verify they're actually stopped
    $still = Get-Process -Name "MRVPN-service" -ErrorAction SilentlyContinue
    if ($still) {
        Write-Host "  -> WARNING: MRVPN-service still running (elevated). Run this script as Admin." -ForegroundColor Red
        throw "Cannot stop elevated MRVPN-service.exe. Please run PowerShell as Administrator."
    }
    Write-Host "  -> Stopped" -ForegroundColor Green
}

# Create dist directory
New-Item -ItemType Directory -Force -Path $DistDir | Out-Null

# ----- Build Go Backend -----
if (-not $SkipGo) {
    Write-Host "[1/3] Building Go backend..." -ForegroundColor Yellow
    $coreDir = Join-Path $ProjectRoot "core"
    $goOutput = Join-Path $DistDir "MRVPN-service.exe"

    Push-Location $coreDir
    try {
        & go build -tags $GoTags -ldflags "-s -w" -o $goOutput ./cmd/mriaz-service/
        if ($LASTEXITCODE -ne 0) { throw "Go build failed" }
        Write-Host "  -> Go backend built: $goOutput" -ForegroundColor Green
    }
    finally {
        Pop-Location
    }
} else {
    Write-Host "[1/3] Skipping Go backend build" -ForegroundColor DarkGray
}

# ----- Build Flutter App -----
if (-not $SkipFlutter) {
    Write-Host "[2/3] Building Flutter app..." -ForegroundColor Yellow
    $appDir = Join-Path $ProjectRoot "app"

    # Wipe the entire Windows build cache so icon/RC changes are always picked up.
    # CMakeLists.txt has OBJECT_DEPENDS for the icon, but a full clean avoids
    # any stale CMake generator cache issues.
    $winBuildCache = Join-Path $appDir "build\windows"
    if (Test-Path $winBuildCache) {
        Write-Host "  Clearing Windows build cache..." -ForegroundColor DarkGray
        Remove-Item -Recurse -Force $winBuildCache
    }

    Push-Location $appDir
    try {
        & $Flutter build windows --release
        if ($LASTEXITCODE -ne 0) { throw "Flutter build failed" }

        # Copy Flutter build output to dist
        $flutterBuild = Join-Path $appDir "build\windows\x64\runner\Release"
        if (Test-Path $flutterBuild) {
            Copy-Item -Path "$flutterBuild\*" -Destination $DistDir -Recurse -Force
            Write-Host "  -> Flutter app built and copied to: $DistDir" -ForegroundColor Green
        } else {
            # Try alternate path
            $flutterBuild = Join-Path $appDir "build\windows\runner\Release"
            Copy-Item -Path "$flutterBuild\*" -Destination $DistDir -Recurse -Force
            Write-Host "  -> Flutter app built and copied to: $DistDir" -ForegroundColor Green
        }
    }
    finally {
        Pop-Location
    }
} else {
    Write-Host "[2/3] Skipping Flutter build" -ForegroundColor DarkGray
}

# ----- Copy required DLLs and assets -----
Write-Host "  Copying additional assets..." -ForegroundColor Yellow

# Copy tray icon next to exe (system_tray needs it at runtime)
$trayIcoSrc = Join-Path $ProjectRoot "app\windows\runner\resources\app_icon.ico"
if (Test-Path $trayIcoSrc) {
    Copy-Item -Path $trayIcoSrc -Destination $DistDir -Force
    Write-Host "  -> Copied app_icon.ico (tray icon)" -ForegroundColor Green
}

# Copy wintun.dll if available
$wintunSrc = Join-Path $ProjectRoot "installer\assets\wintun.dll"
if (Test-Path $wintunSrc) {
    Copy-Item -Path $wintunSrc -Destination $DistDir -Force
    Write-Host "  -> Copied wintun.dll" -ForegroundColor Green
} else {
    Write-Host "  -> WARNING: wintun.dll not found at $wintunSrc" -ForegroundColor Yellow
    Write-Host "     Download from https://www.wintun.net/ and place in installer\assets\" -ForegroundColor Yellow
}

# ----- Build Installer -----
if (-not $SkipInstaller) {
    Write-Host "[3/3] Building installer..." -ForegroundColor Yellow
    $issFile = Join-Path $ProjectRoot "installer\inno_setup.iss"

    $iscc = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
    if (-not (Test-Path $iscc)) {
        $iscc = "C:\Program Files\Inno Setup 6\ISCC.exe"
    }

    if (Test-Path $iscc) {
        & $iscc $issFile
        if ($LASTEXITCODE -ne 0) { throw "Installer build failed" }
        Write-Host "  -> Installer built successfully" -ForegroundColor Green
    } else {
        Write-Host "  -> WARNING: Inno Setup not found. Skipping installer." -ForegroundColor Yellow
        Write-Host "     Install from https://jrsoftware.org/isinfo.php" -ForegroundColor Yellow
    }
} else {
    Write-Host "[3/3] Skipping installer build" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Build complete!" -ForegroundColor Green
Write-Host "  Output: $DistDir" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
