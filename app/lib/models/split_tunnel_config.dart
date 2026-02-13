/// Split tunneling configuration model.
///
/// Controls which applications or domains are routed through or
/// bypassed from the VPN tunnel.
class SplitTunnelConfig {
  /// Tunneling mode: "off", "app", or "domain".
  final String mode;

  /// List of executable names to include/exclude when mode is "app".
  final List<String> apps;

  /// List of domain patterns to include/exclude when mode is "domain".
  final List<String> domains;

  /// When true, the selection is inverted (exclude instead of include).
  final bool invert;

  const SplitTunnelConfig({
    this.mode = 'off',
    this.apps = const [],
    this.domains = const [],
    this.invert = false,
  });

  /// Default configuration with split tunneling disabled.
  factory SplitTunnelConfig.off() {
    return const SplitTunnelConfig();
  }

  factory SplitTunnelConfig.fromJson(Map<String, dynamic> json) {
    return SplitTunnelConfig(
      mode: json['mode'] as String? ?? 'off',
      apps: (json['apps'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      domains: (json['domains'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      invert: json['invert'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mode': mode,
      'apps': apps,
      'domains': domains,
      'invert': invert,
    };
  }

  SplitTunnelConfig copyWith({
    String? mode,
    List<String>? apps,
    List<String>? domains,
    bool? invert,
  }) {
    return SplitTunnelConfig(
      mode: mode ?? this.mode,
      apps: apps ?? this.apps,
      domains: domains ?? this.domains,
      invert: invert ?? this.invert,
    );
  }

  /// Whether split tunneling is active.
  bool get isEnabled => mode != 'off';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SplitTunnelConfig) return false;
    if (other.mode != mode || other.invert != invert) return false;
    if (other.apps.length != apps.length) return false;
    if (other.domains.length != domains.length) return false;
    for (int i = 0; i < apps.length; i++) {
      if (other.apps[i] != apps[i]) return false;
    }
    for (int i = 0; i < domains.length; i++) {
      if (other.domains[i] != domains[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    return Object.hash(mode, Object.hashAll(apps), Object.hashAll(domains), invert);
  }

  @override
  String toString() {
    return 'SplitTunnelConfig(mode: $mode, apps: ${apps.length}, '
        'domains: ${domains.length}, invert: $invert)';
  }
}
