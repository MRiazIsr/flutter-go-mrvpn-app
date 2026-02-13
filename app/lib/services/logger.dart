import 'dart:io';

/// Simple file logger for diagnosing startup freezes.
///
/// Uses synchronous file writes so that every line is guaranteed to be
/// on disk immediately — even if the main thread blocks right after.
class AppLogger {
  static String? _logPath;

  /// Initialize the logger. Call once at app start.
  static void init() {
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
  static void log(String tag, String message) {
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

    // Also print to console (visible in debug mode).
    // ignore: avoid_print
    print(line);
  }

  /// The path to the log file.
  static String? get logPath => _logPath;
}
