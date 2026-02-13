import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/server_config.dart';
import '../services/storage_service.dart';
import '../services/vpn_service.dart';
import 'theme_provider.dart';
import 'vpn_provider.dart';

// ---------------------------------------------------------------------------
// Server list notifier
// ---------------------------------------------------------------------------

/// Manages the list of saved VPN server configurations.
///
/// Servers are parsed from vless:// or hysteria2:// links, persisted through
/// [StorageService], and can be pinged via [VpnService].
class ServerNotifier extends StateNotifier<List<ServerConfig>> {
  final StorageService _storage;
  final VpnService _vpnService;

  ServerNotifier(this._storage, this._vpnService) : super([]) {
    _load();
  }

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  /// Load the saved server list from local storage.
  Future<void> _load() async {
    final servers = await _storage.loadServers();
    if (mounted) {
      state = servers;
    }
  }

  /// Persist the current server list to local storage.
  Future<void> _save() async {
    await _storage.saveServers(state);
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Parse a VPN link and add the resulting server to the list.
  ///
  /// Supported schemes: `vless://` and `hysteria2://` (also `hy2://`).
  /// The fragment (after `#`) is used as the server display name.
  ///
  /// Throws [FormatException] if the link cannot be parsed.
  Future<void> addServer(String link) async {
    final config = _parseLink(link);

    // Avoid duplicates by link.
    final exists = state.any((s) => s.link == link);
    if (exists) return;

    state = [...state, config];
    await _save();
  }

  /// Remove a server by its [id].
  Future<void> removeServer(String id) async {
    state = state.where((s) => s.id != id).toList();
    await _save();
  }

  /// Replace a server with an updated [config] (matched by id).
  Future<void> updateServer(ServerConfig config) async {
    state = [
      for (final s in state)
        if (s.id == config.id) config else s,
    ];
    await _save();
  }

  /// Ping a server by [id] and update its latency value.
  ///
  /// The latency is measured by [VpnService.pingServer] and stored in
  /// milliseconds. A value of -1 indicates the server is unreachable.
  Future<void> pingServer(String id) async {
    final index = state.indexWhere((s) => s.id == id);
    if (index == -1) return;

    final server = state[index];
    final latency = await _vpnService.pingServer(server.link);

    if (mounted) {
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == index)
            state[i].copyWith(latency: () => latency)
          else
            state[i],
      ];
      await _save();
    }
  }

  // ---------------------------------------------------------------------------
  // Link parsing
  // ---------------------------------------------------------------------------

  /// Parse a vless:// or hysteria2:// link into a [ServerConfig].
  static final _hostRegex = RegExp(
    r'^([a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?\.)*[a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?$',
  );
  static final _ipRegex = RegExp(
    r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$',
  );

  static ServerConfig _parseLink(String link) {
    // Length limit to prevent abuse
    if (link.length > 2048) {
      throw const FormatException('Server link is too long');
    }

    final uri = Uri.tryParse(link);
    if (uri == null) {
      throw const FormatException('Invalid server link');
    }

    final scheme = uri.scheme.toLowerCase();

    // Whitelist allowed schemes.
    final String protocol;
    switch (scheme) {
      case 'vless':
        protocol = 'VLESS';
        break;
      case 'hysteria2':
      case 'hy2':
        protocol = 'Hysteria2';
        break;
      default:
        throw FormatException('Unsupported protocol scheme: $scheme');
    }

    final address = uri.host;
    if (address.isEmpty) {
      throw const FormatException('Server address is empty');
    }

    // Validate host: must be a valid hostname or IPv4 address
    if (!_hostRegex.hasMatch(address) && !_ipRegex.hasMatch(address)) {
      throw const FormatException('Invalid server address');
    }

    final port = uri.hasPort ? uri.port : _defaultPort(scheme);
    if (port < 1 || port > 65535) {
      throw const FormatException('Invalid port number');
    }

    // Use the fragment as the display name, sanitize control characters.
    var name = uri.fragment.isNotEmpty
        ? Uri.decodeComponent(uri.fragment)
            .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        : '$address:$port';
    if (name.length > 100) name = name.substring(0, 100);

    // Generate a deterministic ID from the link so re-adding yields the same
    // identity. Using hashCode is sufficient for local-only identification.
    final id = link.hashCode.toRadixString(36);

    return ServerConfig(
      id: id,
      name: name,
      link: link,
      protocol: protocol,
      address: address,
      port: port,
    );
  }

  /// Return a sensible default port for the given scheme.
  static int _defaultPort(String scheme) {
    switch (scheme) {
      case 'vless':
        return 443;
      case 'hysteria2':
      case 'hy2':
        return 443;
      default:
        return 443;
    }
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Global provider for the list of saved [ServerConfig]s.
///
/// Usage:
/// ```dart
/// final servers = ref.watch(serverProvider);
/// ref.read(serverProvider.notifier).addServer(link);
/// ```
final serverProvider =
    StateNotifierProvider<ServerNotifier, List<ServerConfig>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final vpnService = ref.watch(vpnServiceProvider);
  return ServerNotifier(storage, vpnService);
});

// ---------------------------------------------------------------------------
// Selected server provider
// ---------------------------------------------------------------------------

/// Notifier that tracks which server is currently selected by its ID.
///
/// Persists the selection to [StorageService] as the "last server ID".
class SelectedServerNotifier extends StateNotifier<String?> {
  final StorageService _storage;

  SelectedServerNotifier(this._storage) : super(null) {
    _load();
  }

  Future<void> _load() async {
    final lastId = await _storage.loadLastServerId();
    if (mounted) {
      state = lastId;
    }
  }

  /// Select a server by [id]. Pass `null` to clear the selection.
  Future<void> select(String? id) async {
    state = id;
    await _storage.saveLastServerId(id);
  }
}

/// Provider for the currently selected server ID.
///
/// Usage:
/// ```dart
/// final selectedId = ref.watch(selectedServerProvider);
/// ref.read(selectedServerProvider.notifier).select(serverId);
/// ```
final selectedServerProvider =
    StateNotifierProvider<SelectedServerNotifier, String?>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return SelectedServerNotifier(storage);
});

/// Convenience provider that resolves the full [ServerConfig] of the
/// currently selected server, or `null` if nothing is selected.
final selectedServerConfigProvider = Provider<ServerConfig?>((ref) {
  final selectedId = ref.watch(selectedServerProvider);
  if (selectedId == null) return null;

  final servers = ref.watch(serverProvider);
  try {
    return servers.firstWhere((s) => s.id == selectedId);
  } catch (_) {
    return null;
  }
});
