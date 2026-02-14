import 'dart:convert';

import 'package:http/http.dart' as http;

/// Result of fetching a subscription endpoint.
class SubscriptionResult {
  final List<String> links;
  final int updateInterval;
  final int? trafficUsed;
  final int? trafficLimit;
  final String? error;

  const SubscriptionResult({
    this.links = const [],
    this.updateInterval = 6,
    this.trafficUsed,
    this.trafficLimit,
    this.error,
  });
}

/// Service for fetching and parsing VPN subscription endpoints.
///
/// A subscription URL returns a base64-encoded list of server links
/// (one per line) along with metadata in HTTP headers.
class SubscriptionService {
  /// Fetch a subscription URL and return parsed links with metadata.
  Future<SubscriptionResult> fetchSubscription(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      return const SubscriptionResult(error: 'Invalid URL');
    }

    final http.Response response;
    try {
      response = await http
          .get(uri)
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      return SubscriptionResult(error: 'Connection failed: $e');
    }

    if (response.statusCode != 200) {
      return SubscriptionResult(
        error: 'HTTP ${response.statusCode}',
      );
    }

    // Parse Profile-Update-Interval header (default 6 hours)
    final intervalStr =
        response.headers['profile-update-interval'] ?? '6';
    final updateInterval = int.tryParse(intervalStr) ?? 6;

    // Parse Subscription-Userinfo header
    // Format: "upload=0; download=1073741824; total=32212254720"
    int? trafficUsed;
    int? trafficLimit;
    final userinfo = response.headers['subscription-userinfo'];
    if (userinfo != null) {
      trafficUsed = _parseUserinfoField(userinfo, 'download');
      trafficLimit = _parseUserinfoField(userinfo, 'total');
    }

    // Decode base64 body → newline-separated links
    final String decoded;
    try {
      decoded = utf8.decode(base64.decode(response.body.trim()));
    } catch (_) {
      return const SubscriptionResult(
        error: 'Failed to decode subscription data',
      );
    }

    final links = decoded
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.startsWith('vless://') ||
            l.startsWith('hysteria2://') ||
            l.startsWith('hy2://'))
        .toList();

    if (links.isEmpty) {
      return const SubscriptionResult(
        error: 'No supported servers found',
      );
    }

    return SubscriptionResult(
      links: links,
      updateInterval: updateInterval,
      trafficUsed: trafficUsed,
      trafficLimit: trafficLimit,
    );
  }

  /// Extract an integer field from a Subscription-Userinfo header value.
  static int? _parseUserinfoField(String userinfo, String field) {
    final regex = RegExp('$field=(\\d+)');
    final match = regex.firstMatch(userinfo);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }
}
