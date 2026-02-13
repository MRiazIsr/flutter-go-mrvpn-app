import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/split_tunnel_config.dart';
import '../models/vpn_state.dart';
import '../services/logger.dart';
import '../services/vpn_service.dart';

// ---------------------------------------------------------------------------
// Service provider
// ---------------------------------------------------------------------------

/// Provides a singleton [VpnService] instance to the provider graph.
final vpnServiceProvider = Provider<VpnService>((ref) {
  final service = VpnService();
  ref.onDispose(() => service.dispose());
  return service;
});

// ---------------------------------------------------------------------------
// VPN notifier
// ---------------------------------------------------------------------------

/// Manages VPN connection state by bridging [VpnService] streams into
/// Riverpod state.
///
/// Listens to [VpnService.stateStream] for status transitions and
/// [VpnService.statsStream] for periodic traffic statistics, keeping the
/// exposed [VpnState] always up to date.
class VpnNotifier extends StateNotifier<VpnState> {
  final VpnService _vpnService;

  StreamSubscription<VpnState>? _stateSub;
  StreamSubscription<StatsUpdate>? _statsSub;

  VpnNotifier(this._vpnService) : super(VpnState.initial()) {
    _init();
  }

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  Future<void> _init() async {
    AppLogger.log('VPN', '_init() start');

    // Attempt to connect to the Go backend.
    AppLogger.log('VPN', 'vpnService.initialize()...');
    await _vpnService.initialize();
    AppLogger.log('VPN', 'vpnService.initialize() done');

    // Listen for state changes pushed by the backend.
    _stateSub = _vpnService.stateStream.listen((vpnState) {
      if (mounted) {
        state = vpnState;
      }
    });

    // Listen for traffic statistics updates.
    _statsSub = _vpnService.statsStream.listen((stats) {
      if (mounted) {
        state = state.copyWith(
          upload: stats.upload,
          download: stats.download,
          upSpeed: stats.upSpeed,
          downSpeed: stats.downSpeed,
        );
      }
    });

    // Fetch the initial status in case the backend is already connected.
    AppLogger.log('VPN', 'refreshStatus()...');
    await refreshStatus();
    AppLogger.log('VPN', 'refreshStatus() done, _init complete');
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Connect to a VPN server using the given [link] (vless:// or hysteria2://).
  ///
  /// Pass [splitTunnelConfig] to apply split tunneling rules for this session.
  Future<void> connect(
    String link, {
    SplitTunnelConfig? splitTunnelConfig,
  }) async {
    try {
      await _vpnService.connectVpn(link, splitTunnelConfig: splitTunnelConfig);
    } catch (_) {
      // State is already updated to error inside VpnService; nothing extra
      // needed here.
    }
  }

  /// Disconnect the active VPN connection.
  Future<void> disconnect() async {
    try {
      await _vpnService.disconnectVpn();
    } catch (_) {
      // Error state handled by VpnService.
    }
  }

  /// Re-query the backend for the latest VPN status.
  Future<void> refreshStatus() async {
    try {
      final freshState = await _vpnService.getStatus();
      if (mounted) {
        state = freshState;
      }
    } catch (_) {
      // If the backend isn't reachable yet, keep the current state.
    }
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    _stateSub?.cancel();
    _statsSub?.cancel();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// Global provider for [VpnState].
///
/// Usage in widgets:
/// ```dart
/// final vpnState = ref.watch(vpnProvider);
/// ref.read(vpnProvider.notifier).connect(serverLink);
/// ref.read(vpnProvider.notifier).disconnect();
/// ```
final vpnProvider = StateNotifierProvider<VpnNotifier, VpnState>((ref) {
  final vpnService = ref.watch(vpnServiceProvider);
  return VpnNotifier(vpnService);
});
