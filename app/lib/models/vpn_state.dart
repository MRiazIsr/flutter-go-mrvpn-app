/// VPN connection status enumeration.
enum VpnStatus {
  disconnected,
  connecting,
  connected,
  disconnecting,
  error;

  static VpnStatus fromString(String value) {
    return VpnStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => VpnStatus.disconnected,
    );
  }
}

/// VPN connection state model.
///
/// Holds the current status, traffic statistics, and connection metadata.
class VpnState {
  final VpnStatus status;
  final String? serverName;
  final String? protocol;
  final DateTime? connectedAt;
  final int upload;
  final int download;
  final int upSpeed;
  final int downSpeed;
  final String? errorMessage;

  const VpnState({
    this.status = VpnStatus.disconnected,
    this.serverName,
    this.protocol,
    this.connectedAt,
    this.upload = 0,
    this.download = 0,
    this.upSpeed = 0,
    this.downSpeed = 0,
    this.errorMessage,
  });

  /// Initial disconnected state.
  factory VpnState.initial() {
    return const VpnState();
  }

  factory VpnState.fromJson(Map<String, dynamic> json) {
    return VpnState(
      status: VpnStatus.fromString(json['status'] as String? ?? 'disconnected'),
      serverName: json['serverName'] as String?,
      protocol: json['protocol'] as String?,
      connectedAt: json['connectedAt'] != null
          ? DateTime.tryParse(json['connectedAt'] as String)
          : null,
      upload: json['upload'] as int? ?? 0,
      download: json['download'] as int? ?? 0,
      upSpeed: json['upSpeed'] as int? ?? 0,
      downSpeed: json['downSpeed'] as int? ?? 0,
      errorMessage: json['errorMessage'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status.name,
      'serverName': serverName,
      'protocol': protocol,
      'connectedAt': connectedAt?.toIso8601String(),
      'upload': upload,
      'download': download,
      'upSpeed': upSpeed,
      'downSpeed': downSpeed,
      'errorMessage': errorMessage,
    };
  }

  VpnState copyWith({
    VpnStatus? status,
    String? Function()? serverName,
    String? Function()? protocol,
    DateTime? Function()? connectedAt,
    int? upload,
    int? download,
    int? upSpeed,
    int? downSpeed,
    String? Function()? errorMessage,
  }) {
    return VpnState(
      status: status ?? this.status,
      serverName: serverName != null ? serverName() : this.serverName,
      protocol: protocol != null ? protocol() : this.protocol,
      connectedAt: connectedAt != null ? connectedAt() : this.connectedAt,
      upload: upload ?? this.upload,
      download: download ?? this.download,
      upSpeed: upSpeed ?? this.upSpeed,
      downSpeed: downSpeed ?? this.downSpeed,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }

  /// Whether the VPN is currently active (connecting or connected).
  bool get isActive =>
      status == VpnStatus.connecting || status == VpnStatus.connected;

  /// Duration of the current connection, or null if not connected.
  Duration? get connectionDuration {
    if (connectedAt == null) return null;
    return DateTime.now().difference(connectedAt!);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VpnState &&
        other.status == status &&
        other.serverName == serverName &&
        other.protocol == protocol &&
        other.connectedAt == connectedAt &&
        other.upload == upload &&
        other.download == download &&
        other.upSpeed == upSpeed &&
        other.downSpeed == downSpeed &&
        other.errorMessage == errorMessage;
  }

  @override
  int get hashCode {
    return Object.hash(
      status,
      serverName,
      protocol,
      connectedAt,
      upload,
      download,
      upSpeed,
      downSpeed,
      errorMessage,
    );
  }

  @override
  String toString() {
    return 'VpnState(status: ${status.name}, server: $serverName, '
        'protocol: $protocol, upload: $upload, download: $download)';
  }
}

/// Stats update from the Go backend, emitted periodically while connected.
class StatsUpdate {
  final int upload;
  final int download;
  final int upSpeed;
  final int downSpeed;

  const StatsUpdate({
    required this.upload,
    required this.download,
    required this.upSpeed,
    required this.downSpeed,
  });

  factory StatsUpdate.fromJson(Map<String, dynamic> json) {
    return StatsUpdate(
      upload: json['upload'] as int? ?? 0,
      download: json['download'] as int? ?? 0,
      upSpeed: json['upSpeed'] as int? ?? 0,
      downSpeed: json['downSpeed'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'upload': upload,
      'download': download,
      'upSpeed': upSpeed,
      'downSpeed': downSpeed,
    };
  }

  @override
  String toString() {
    return 'StatsUpdate(upload: $upload, download: $download, '
        'upSpeed: $upSpeed, downSpeed: $downSpeed)';
  }
}
