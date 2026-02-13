import 'dart:io';

import 'package:flutter/foundation.dart';

/// Simple file logger for diagnosing startup freezes.
///
/// Only active in debug/profile builds. In release builds, logging is
/// completely disabled to prevent sensitive data leakage.
class AppLogger {
  static String? _logPath;

  /// Initialize the logger. Call once at app start.
  /// In release builds, this is a no-op.
  static void init() {
    if (kReleaseMode) return;

    try {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      _logPath = '$exeDir${Platform.pathSeparator}mrvpn_debug.log';
      File(_logPath!).writeAsStringSync(
        '=== MRVPN log started at ${DateTime.now()} ===\n',
      );
    } catch (_) {
      try {
        _logPath =
            '${Directory.systemTemp.path}${Platform.pathSeparator}mrvpn_debug.log';
        File(_logPath!).writeAsStringSync(
          '=== MRVPN log started at ${DateTime.now()} (temp) ===\n',
        );
      } catch (_) {}
    }
  }

  /// Write a log line with timestamp and tag. Fully synchronous.
  /// In release builds, this is a no-op.
  static void log(String tag, String message) {
    if (kReleaseMode) return;

    final now = DateTime.now();
    final ts = '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}.'
        '${now.millisecond.toString().padLeft(3, '0')}';
    final line = '[$ts] [$tag] $message';

    try {
      if (_logPath != null) {
        File(_logPath!).writeAsStringSync(
          '$line\n',
          mode: FileMode.append,
          flush: true,
        );
      }
    } catch (_) {}

    // Print to console only in debug mode.
    // ignore: avoid_print
    print(line);
  }

  /// The path to the log file (null in release builds).
  static String? get logPath => _logPath;
}
