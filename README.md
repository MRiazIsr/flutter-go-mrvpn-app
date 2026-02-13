# MRVPN

Windows VPN client with a Flutter desktop UI and a Go backend powered by [sing-box](https://github.com/SagerNet/sing-box).

![Windows](https://img.shields.io/badge/platform-Windows-blue)
![Flutter](https://img.shields.io/badge/Flutter-3.8-02569B)
![Go](https://img.shields.io/badge/Go-1.25-00ADD8)

## Architecture

```
MRVPN.exe (Flutter)          MRVPN-service.exe (Go, elevated)
┌──────────────────┐         ┌──────────────────────┐
│  UI / Riverpod   │◄──IPC──►│  sing-box VPN engine  │
│  window_manager  │  named  │  TUN interface        │
│  system_tray     │  pipe   │  split tunneling      │
└──────────────────┘         └──────────────────────┘
```

- **Flutter app** — frameless desktop window with custom header, system tray, dark/light themes, EN/RU localization
- **Go service** — runs elevated (admin) to create the TUN adapter; communicates with the UI via `\\.\pipe\MRVPN` using JSON-RPC over named pipes

## Features

- Connect/disconnect VPN (VLESS, Hysteria2)
- Server list with latency ping
- Split tunneling (per-app routing)
- System tray with minimize-to-tray
- Auto-start with Windows
- Dark / Light / System theme
- English / Russian localization
- Inno Setup installer

## Prerequisites

| Tool | Version | Notes |
|------|---------|-------|
| Flutter SDK | >= 3.8 | `flutter doctor` to verify |
| Go | >= 1.25 | With CGO disabled (pure Go) |
| Visual Studio | 2022+ | "Desktop development with C++" workload |
| Python 3 | any | Only for `scripts/generate_icon.py` (Pillow) |
| Inno Setup 6 | optional | Only for building the installer |

## Project Structure

```
├── app/                    # Flutter desktop application
│   ├── lib/
│   │   ├── main.dart       # Entry point, window & tray setup
│   │   ├── app.dart        # MaterialApp, router, shell
│   │   ├── models/         # Data models (VPN state, server, etc.)
│   │   ├── providers/      # Riverpod state providers
│   │   ├── screens/        # Home, Servers, Split Tunnel, Settings
│   │   ├── services/       # IPC, backend launcher, VPN service
│   │   ├── theme/          # Dark/light themes, colors
│   │   ├── widgets/        # Header, sidebar, connect button
│   │   └── l10n/           # Translations (EN/RU)
│   ├── windows/            # Windows runner, CMake, RC resources
│   └── pubspec.yaml        # Dart dependencies
├── core/                   # Go backend service
│   ├── cmd/mriaz-service/  # Service entry point
│   ├── internal/
│   │   ├── ipc/            # Named pipe server & JSON-RPC handler
│   │   ├── vpn/            # sing-box engine wrapper
│   │   ├── parser/         # VLESS / Hysteria2 link parser
│   │   ├── splittunnel/    # Per-app routing
│   │   └── service/        # Windows service integration
│   ├── go.mod
│   └── go.sum
├── installer/              # Inno Setup installer config
├── scripts/                # Build, deploy, icon generation
└── dist/                   # Build output (not in git)
```

## Building

### Quick build (Flutter only)

```powershell
.\scripts\deploy.ps1
```

### Full build (Go + Flutter + Installer)

```powershell
.\scripts\build.ps1
```

### Build flags

```powershell
# Skip specific steps
.\scripts\build.ps1 -SkipGo          # Skip Go backend
.\scripts\build.ps1 -SkipFlutter     # Skip Flutter app
.\scripts\build.ps1 -SkipInstaller   # Skip Inno Setup

# Deploy and launch
.\scripts\deploy.ps1 -Launch
.\scripts\deploy.ps1 -SkipBuild      # Copy existing build to dist
```

Output goes to `dist/` with:
- `MRVPN.exe` — Flutter UI
- `MRVPN-service.exe` — Go backend
- `app_icon.ico` — tray icon
- `data/` — Flutter assets
- DLLs (Flutter engine, plugins, wintun)

### Regenerate app icon

```powershell
pip install Pillow
python scripts\generate_icon.py
```

## Running

Launch from `dist/`:

```powershell
.\dist\MRVPN.exe
```

The app will request UAC elevation to start `MRVPN-service.exe` (required for TUN interface creation).

## Creating a Release

```powershell
.\scripts\release.ps1 -Version "1.0.0"
```

This builds everything, creates a ZIP archive, and (with `gh` CLI) publishes a GitHub release.

## License

Private repository. All rights reserved.
