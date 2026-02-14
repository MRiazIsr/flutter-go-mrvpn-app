import 'dart:convert';
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

import 'logger.dart';

/// Returns the current app version from pubspec.yaml at runtime.
Future<String> getAppVersion() async {
  final info = await PackageInfo.fromPlatform();
  return info.version;
}

/// Information about an available update.
class UpdateInfo {
  final String version;
  final String tagName;
  final String? releaseNotes;
  final String releaseUrl;
  final String? downloadUrl;

  UpdateInfo({
    required this.version,
    required this.tagName,
    this.releaseNotes,
    required this.releaseUrl,
    this.downloadUrl,
  });
}

/// Checks GitHub Releases API for newer versions of MRVPN.
class UpdateService {
  static const String _repoOwner = 'MRiazIsr';
  static const String _repoName = 'flutter-go-mrvpn-app';

  /// Check for a newer release on GitHub.
  ///
  /// Returns [UpdateInfo] if a newer version exists, `null` if up-to-date.
  /// Silently returns `null` on any error (no internet, private repo, etc.).
  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final currentVersion = await getAppVersion();

      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);

      final uri = Uri.https(
        'api.github.com',
        '/repos/$_repoOwner/$_repoName/releases/latest',
      );

      final request = await client.getUrl(uri);
      request.headers.set('Accept', 'application/vnd.github.v3+json');
      request.headers.set('User-Agent', 'MRVPN/$currentVersion');

      final response = await request.close().timeout(
            const Duration(seconds: 15),
          );

      if (response.statusCode != 200) {
        AppLogger.log('UPDATE', 'GitHub API returned ${response.statusCode}');
        await response.drain<void>();
        client.close();
        return null;
      }

      final body = await response.transform(utf8.decoder).join();
      client.close();

      final json = jsonDecode(body) as Map<String, dynamic>;
      final tagName = json['tag_name'] as String? ?? '';
      final remoteVersion = tagName.replaceFirst(RegExp(r'^v'), '');

      if (!isNewer(remoteVersion, currentVersion)) {
        AppLogger.log(
          'UPDATE',
          'Up to date (current=$currentVersion, latest=$remoteVersion)',
        );
        return null;
      }

      // Find installer (.exe) or fallback to .zip in release assets.
      String? downloadUrl;
      final assets = json['assets'] as List<dynamic>? ?? [];

      for (final asset in assets) {
        final name = (asset['name'] as String? ?? '').toLowerCase();
        if (name.contains('setup') && name.endsWith('.exe')) {
          downloadUrl = asset['browser_download_url'] as String?;
          break;
        }
      }
      if (downloadUrl == null) {
        for (final asset in assets) {
          final name = (asset['name'] as String? ?? '').toLowerCase();
          if (name.endsWith('.zip')) {
            downloadUrl = asset['browser_download_url'] as String?;
            break;
          }
        }
      }

      AppLogger.log('UPDATE', 'New version available: $remoteVersion');

      return UpdateInfo(
        version: remoteVersion,
        tagName: tagName,
        releaseNotes: json['body'] as String?,
        releaseUrl: json['html_url'] as String? ??
            'https://github.com/$_repoOwner/$_repoName/releases/latest',
        downloadUrl: downloadUrl,
      );
    } catch (e) {
      AppLogger.log('UPDATE', 'Update check failed: $e');
      return null;
    }
  }

  /// Compare two semver strings. Returns `true` if [remote] > [current].
  static bool isNewer(String remote, String current) {
    final remoteParts = _parseSemver(remote);
    final currentParts = _parseSemver(current);
    if (remoteParts == null || currentParts == null) return false;

    for (int i = 0; i < 3; i++) {
      if (remoteParts[i] > currentParts[i]) return true;
      if (remoteParts[i] < currentParts[i]) return false;
    }
    return false;
  }

  static List<int>? _parseSemver(String version) {
    final parts = version.split('.');
    if (parts.length < 2) return null;
    try {
      return [
        int.parse(parts[0]),
        int.parse(parts[1]),
        parts.length > 2 ? int.parse(parts[2]) : 0,
      ];
    } catch (_) {
      return null;
    }
  }

  /// Open a URL in the default Windows browser.
  static void openInBrowser(String url) {
    Process.run('cmd', ['/c', 'start', '', url]);
  }
}
