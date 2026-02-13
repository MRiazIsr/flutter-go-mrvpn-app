import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'services/backend_launcher.dart';
import 'services/ipc_service.dart';
import 'services/logger.dart';

final _backendLauncher = BackendLauncher();
final _systemTray = SystemTray();

void main() async {
  AppLogger.init();
  AppLogger.log('MAIN', 'main() start');

  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  // Solid background so the window is never transparent while Flutter renders.
  const windowOptions = WindowOptions(
    size: Size(1100, 720),
    minimumSize: Size(900, 600),
    center: true,
    backgroundColor: Color(0xFF0D0D1A),
    titleBarStyle: TitleBarStyle.hidden,
  );

  // Set up close handler before showing.
  await windowManager.setPreventClose(true);
  windowManager.addListener(_AppWindowListener());

  // Show window.
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // System tray (non-fatal — app works without it).
  try {
    await _initSystemTray();
  } catch (e) {
    AppLogger.log('MAIN', 'System tray init failed: $e');
  }

  // Launch backend in background — never block the UI.
  _backendLauncher.start();

  // Handle Ctrl+C.
  ProcessSignal.sigint.watch().listen((_) => _exitApp());

  AppLogger.log('MAIN', 'runApp');
  runApp(
    const ProviderScope(
      child: MRVPNApp(),
    ),
  );
}

String _trayIconPath() {
  final exeDir = File(Platform.resolvedExecutable).parent.path;
  return '$exeDir${Platform.pathSeparator}app_icon.ico';
}

Future<void> _initSystemTray() async {
  final iconPath = _trayIconPath();
  AppLogger.log('MAIN', 'Tray icon path: $iconPath (exists: ${File(iconPath).existsSync()})');
  await _systemTray.initSystemTray(
    iconPath: iconPath,
    toolTip: 'MRVPN',
  );

  final menu = Menu();
  await menu.buildFrom([
    MenuItemLabel(
      label: 'Show',
      onClicked: (_) => _showWindow(),
    ),
    MenuSeparator(),
    MenuItemLabel(
      label: 'Exit',
      onClicked: (_) => _exitApp(),
    ),
  ]);
  await _systemTray.setContextMenu(menu);

  _systemTray.registerSystemTrayEventHandler((eventName) {
    if (eventName == kSystemTrayEventClick) {
      _showWindow();
    } else if (eventName == kSystemTrayEventRightClick) {
      _systemTray.popUpContextMenu();
    } else if (eventName == kSystemTrayEventDoubleClick) {
      _showWindow();
    }
  });
}

Future<void> _showWindow() async {
  await windowManager.show();
  await windowManager.focus();
}

Future<void> _exitApp() async {
  AppLogger.log('MAIN', 'Exit requested — shutting down');

  // Send shutdown command directly to the backend via a fresh pipe connection.
  // This works regardless of the Riverpod-managed IpcService connection state.
  // The Go backend receives it, disconnects VPN, and exits gracefully.
  try {
    IpcService.sendShutdownSync();
    AppLogger.log('MAIN', 'Shutdown command sent via IPC');
  } catch (_) {}

  // Remove tray icon before exiting.
  await _systemTray.destroy();

  exit(0);
}

class _AppWindowListener extends WindowListener {
  @override
  void onWindowClose() async {
    // Hide to tray instead of closing.
    AppLogger.log('MAIN', 'Window close requested — hiding to tray');
    await windowManager.hide();
  }
}
