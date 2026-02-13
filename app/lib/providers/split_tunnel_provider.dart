import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_info.dart';
import '../models/split_tunnel_config.dart';
import '../services/storage_service.dart';
import '../services/vpn_service.dart';
import 'theme_provider.dart';
import 'vpn_provider.dart';

// ---------------------------------------------------------------------------
// Split tunnel notifier
// ---------------------------------------------------------------------------

/// Manages the split tunneling configuration, controlling which apps or
/// domains are routed through (or bypassed from) the VPN tunnel.
///
/// All mutations are automatically persisted to [StorageService].
class SplitTunnelNotifier extends StateNotifier<SplitTunnelConfig> {
  final StorageService _storage;

  SplitTunnelNotifier(this._storage) : super(SplitTunnelConfig.off()) {
    _load();
  }

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  /// Load the saved split tunnel configuration from local storage.
  Future<void> _load() async {
    final config = await _storage.loadSplitTunnelConfig();
    if (mounted) {
      state = config;
    }
  }

  /// Persist the current configuration to local storage.
  Future<void> _save() async {
    await _storage.saveSplitTunnelConfig(state);
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Set the tunneling mode.
  ///
  /// Valid values: `"off"`, `"app"`, `"domain"`.
  Future<void> setMode(String mode) async {
    state = state.copyWith(mode: mode);
    await _save();
  }

  /// Add an application (by executable name) to the split tunnel list.
  ///
  /// No-op if [exeName] is already in the list.
  Future<void> addApp(String exeName) async {
    if (state.apps.contains(exeName)) return;
    state = state.copyWith(apps: [...state.apps, exeName]);
    await _save();
  }

  /// Remove an application (by executable name) from the split tunnel list.
  Future<void> removeApp(String exeName) async {
    state = state.copyWith(
      apps: state.apps.where((a) => a != exeName).toList(),
    );
    await _save();
  }

  /// Add a domain pattern to the split tunnel list.
  ///
  /// No-op if [domain] is already in the list.
  Future<void> addDomain(String domain) async {
    if (state.domains.contains(domain)) return;
    state = state.copyWith(domains: [...state.domains, domain]);
    await _save();
  }

  /// Remove a domain pattern from the split tunnel list.
  Future<void> removeDomain(String domain) async {
    state = state.copyWith(
      domains: state.domains.where((d) => d != domain).toList(),
    );
    await _save();
  }

  /// Set whether the selection is inverted.
  ///
  /// When [invert] is `true`, selected apps/domains are *excluded* from
  /// the tunnel instead of included.
  Future<void> setInvert(bool invert) async {
    state = state.copyWith(invert: invert);
    await _save();
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Global provider for the [SplitTunnelConfig].
///
/// Usage:
/// ```dart
/// final config = ref.watch(splitTunnelProvider);
/// ref.read(splitTunnelProvider.notifier).setMode('app');
/// ref.read(splitTunnelProvider.notifier).addApp('chrome.exe');
/// ```
final splitTunnelProvider =
    StateNotifierProvider<SplitTunnelNotifier, SplitTunnelConfig>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return SplitTunnelNotifier(storage);
});

/// Provider that asynchronously fetches the list of installed applications
/// available for split tunneling.
///
/// Calls [VpnService.listApps] which queries the Go backend for all
/// installed applications on the system.
///
/// Usage:
/// ```dart
/// final appsAsync = ref.watch(installedAppsProvider);
/// appsAsync.when(
///   data: (apps) => ...,
///   loading: () => ...,
///   error: (e, st) => ...,
/// );
/// ```
final installedAppsProvider = FutureProvider<List<AppInfo>>((ref) async {
  final vpnService = ref.watch(vpnServiceProvider);
  // Wait for the VPN service to finish its initialization (IPC connect)
  // before attempting to list apps.
  await vpnService.ready.timeout(
    const Duration(seconds: 10),
    onTimeout: () {},
  );
  return vpnService.listApps();
});
