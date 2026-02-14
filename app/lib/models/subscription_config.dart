/// Subscription configuration model for MRVPN.
///
/// Represents a subscription endpoint that provides a list of VPN servers.
/// The subscription URL returns a base64-encoded list of server links.
class SubscriptionConfig {
  final String id;
  final String name;
  final String url;
  final int updateInterval;
  final DateTime? lastUpdated;
  final int? trafficUsed;
  final int? trafficLimit;
  final List<String> serverIds;

  const SubscriptionConfig({
    required this.id,
    required this.name,
    required this.url,
    required this.updateInterval,
    this.lastUpdated,
    this.trafficUsed,
    this.trafficLimit,
    this.serverIds = const [],
  });

  factory SubscriptionConfig.fromJson(Map<String, dynamic> json) {
    return SubscriptionConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      url: json['url'] as String,
      updateInterval: json['updateInterval'] as int? ?? 6,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['lastUpdated'] as int)
          : null,
      trafficUsed: json['trafficUsed'] as int?,
      trafficLimit: json['trafficLimit'] as int?,
      serverIds: (json['serverIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'updateInterval': updateInterval,
      'lastUpdated': lastUpdated?.millisecondsSinceEpoch,
      'trafficUsed': trafficUsed,
      'trafficLimit': trafficLimit,
      'serverIds': serverIds,
    };
  }

  SubscriptionConfig copyWith({
    String? id,
    String? name,
    String? url,
    int? updateInterval,
    DateTime? Function()? lastUpdated,
    int? Function()? trafficUsed,
    int? Function()? trafficLimit,
    List<String>? serverIds,
  }) {
    return SubscriptionConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      updateInterval: updateInterval ?? this.updateInterval,
      lastUpdated: lastUpdated != null ? lastUpdated() : this.lastUpdated,
      trafficUsed: trafficUsed != null ? trafficUsed() : this.trafficUsed,
      trafficLimit: trafficLimit != null ? trafficLimit() : this.trafficLimit,
      serverIds: serverIds ?? this.serverIds,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SubscriptionConfig) return false;
    if (other.id != id ||
        other.name != name ||
        other.url != url ||
        other.updateInterval != updateInterval ||
        other.lastUpdated != lastUpdated ||
        other.trafficUsed != trafficUsed ||
        other.trafficLimit != trafficLimit ||
        other.serverIds.length != serverIds.length) {
      return false;
    }
    for (int i = 0; i < serverIds.length; i++) {
      if (other.serverIds[i] != serverIds[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      url,
      updateInterval,
      lastUpdated,
      trafficUsed,
      trafficLimit,
      Object.hashAll(serverIds),
    );
  }

  @override
  String toString() {
    return 'SubscriptionConfig(id: $id, name: $name, '
        'servers: ${serverIds.length}, interval: ${updateInterval}h)';
  }
}
