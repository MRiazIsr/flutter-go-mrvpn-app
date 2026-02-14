import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/update_service.dart';

/// Provides the current app version from pubspec.yaml at runtime.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.version;
});

const String _keySkippedVersion = 'skipped_update_version';

final updateServiceProvider = Provider<UpdateService>((ref) => UpdateService());

/// Checks for updates and returns [UpdateInfo] if a newer version is available.
///
/// Respects the user's "skip this version" preference.
/// Returns `null` if up-to-date, skipped, or on error.
final updateCheckProvider = FutureProvider<UpdateInfo?>((ref) async {
  final service = ref.read(updateServiceProvider);
  final info = await service.checkForUpdate();

  if (info != null) {
    final prefs = await SharedPreferences.getInstance();
    final skipped = prefs.getString(_keySkippedVersion);
    if (skipped == info.version) return null;
  }

  return info;
});

/// Mark a version as skipped so the user won't be prompted again.
Future<void> skipVersion(String version) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_keySkippedVersion, version);
}

/// Clear the skipped version (e.g. when manually checking for updates).
Future<void> clearSkippedVersion() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_keySkippedVersion);
}
