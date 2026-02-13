import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'ipc_service.dart';
import 'logger.dart';

// ShellExecuteW signature
typedef _ShellExecuteNative = IntPtr Function(
  IntPtr hwnd,
  Pointer<Utf16> lpOperation,
  Pointer<Utf16> lpFile,
  Pointer<Utf16> lpParameters,
  Pointer<Utf16> lpDirectory,
  Int32 nShowCmd,
);
typedef _ShellExecuteDart = int Function(
  int hwnd,
  Pointer<Utf16> lpOperation,
  Pointer<Utf16> lpFile,
  Pointer<Utf16> lpParameters,
  Pointer<Utf16> lpDirectory,
  int nShowCmd,
);

/// Manages the lifecycle of the Go backend process (MRVPN-service.exe).
///
/// Launches the backend elevated (as administrator) so that the TUN
/// interface can be created. Uses ShellExecuteW with "runas" verb to
/// trigger a UAC prompt.
class BackendLauncher {
  static const String _exeName = 'MRVPN-service.exe';
  static const int _swHide = 0;

  bool _started = false;

  bool get isRunning => _started;

  /// Start the Go backend elevated in interactive mode.
  ///
  /// Returns quickly — does NOT wait for the backend to be ready.
  /// The IPC reconnection logic handles the connection timing.
  Future<bool> start() async {
    if (_started) return true;

    final exePath = _resolveBackendPath();
    if (exePath == null) {
      AppLogger.log('LAUNCHER', 'Could not find $_exeName');
      return false;
    }

    if (!File(exePath).existsSync()) {
      AppLogger.log('LAUNCHER', '$_exeName not found at $exePath');
      return false;
    }

    // Kill any stale backend process (fire-and-forget, don't block).
    _killExisting();

    try {
      AppLogger.log('LAUNCHER', 'Starting elevated: $exePath -interactive');

      final shell32 = DynamicLibrary.open('shell32.dll');
      final shellExecute = shell32
          .lookupFunction<_ShellExecuteNative, _ShellExecuteDart>(
              'ShellExecuteW');

      final operation = 'runas'.toNativeUtf16();
      final file = exePath.toNativeUtf16();
      final params = '-interactive'.toNativeUtf16();
      final dir = File(exePath).parent.path.toNativeUtf16();

      try {
        final result = shellExecute(
          0, // no parent window
          operation,
          file,
          params,
          dir,
          _swHide, // hide the console window
        );

        // ShellExecuteW returns > 32 on success.
        if (result > 32) {
          AppLogger.log(
              'LAUNCHER', 'ShellExecuteW succeeded (result=$result)');
          _started = true;
          return true;
        } else {
          AppLogger.log('LAUNCHER', 'ShellExecuteW failed (result=$result)');
          return false;
        }
      } finally {
        calloc.free(operation);
        calloc.free(file);
        calloc.free(params);
        calloc.free(dir);
      }
    } catch (e) {
      AppLogger.log('LAUNCHER', 'Failed to start backend: $e');
      return false;
    }
  }

  /// Stop the backend process synchronously via IPC shutdown command.
  void stop() {
    if (!_started) return;
    AppLogger.log('LAUNCHER', 'Stopping backend (sync via IPC)...');
    try {
      IpcService.sendShutdownSync();
    } catch (e) {
      AppLogger.log('LAUNCHER', 'Failed to stop backend: $e');
    }
    _started = false;
  }

  /// Stop the backend process asynchronously via IPC shutdown command.
  void stopAsync() {
    if (!_started) return;
    _started = false;
    AppLogger.log('LAUNCHER', 'Stopping backend (async via IPC)...');
    try {
      IpcService.sendShutdownSync();
    } catch (_) {}
  }

  /// Kill any leftover MRVPN-service.exe processes.
  /// Fire-and-forget — runs in background, never blocks the caller.
  void _killExisting() {
    Process.run('taskkill', ['/F', '/IM', _exeName]).then((_) {
      AppLogger.log('LAUNCHER', 'Stale process cleanup done');
    }).catchError((_) {});
  }

  String? _resolveBackendPath() {
    try {
      final flutterExe = Platform.resolvedExecutable;
      final dir = File(flutterExe).parent.path;
      return '$dir${Platform.pathSeparator}$_exeName';
    } catch (_) {
      return null;
    }
  }
}
