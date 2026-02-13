/// Server configuration model for MRVPN.
///
/// Represents a VPN server parsed from a vless:// or hysteria2:// link.
class ServerConfig {
  final String id;
  final String name;
  final String link;
  final String protocol;
  final String address;
  final int port;
  final int? latency;

  const ServerConfig({
    required this.id,
    required this.name,
    required this.link,
    required this.protocol,
    required this.address,
    required this.port,
    this.latency,
  });

  factory ServerConfig.fromJson(Map<String, dynamic> json) {
    return ServerConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      link: json['link'] as String,
      protocol: json['protocol'] as String,
      address: json['address'] as String,
      port: json['port'] as int,
      latency: json['latency'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'link': link,
      'protocol': protocol,
      'address': address,
      'port': port,
      'latency': latency,
    };
  }

  ServerConfig copyWith({
    String? id,
    String? name,
    String? link,
    String? protocol,
    String? address,
    int? port,
    int? Function()? latency,
  }) {
    return ServerConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      link: link ?? this.link,
      protocol: protocol ?? this.protocol,
      address: address ?? this.address,
      port: port ?? this.port,
      latency: latency != null ? latency() : this.latency,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ServerConfig &&
        other.id == id &&
        other.name == name &&
        other.link == link &&
        other.protocol == protocol &&
        other.address == address &&
        other.port == port &&
        other.latency == latency;
  }

  @override
  int get hashCode {
    return Object.hash(id, name, link, protocol, address, port, latency);
  }

  @override
  String toString() {
    return 'ServerConfig(id: $id, name: $name, protocol: $protocol, '
        'address: $address, port: $port, latency: ${latency}ms)';
  }
}
