import 'dart:async';

import '../models/app_info.dart';
import '../models/split_tunnel_config.dart';
import '../models/vpn_state.dart';
import 'ipc_service.dart';

/// High-level VPN operations service that wraps IPC calls to the Go backend.
///
/// Provides a clean API for the UI layer to manage VPN connections,
/// split tunneling, and server pinging.
class VpnService {
  final IpcService _ipc;

  /// Stream controller for VPN state changes, broadcast to multiple listeners.
  final StreamController<VpnState> _stateController =
      StreamController<VpnState>.broadcast();

  /// Stream controller for traffic stats updates.
  final StreamController<StatsUpdate> _statsController =
      StreamController<StatsUpdate>.broadcast();

  StreamSubscription<Map<String, dynamic>>? _notificationSub;
  StreamSubscription<bool>? _connectionStatusSub;

  VpnState _currentState = VpnState.initial();

  final Completer<void> _ready = Completer<void>();

  /// A future that completes once [initialize] has been called and the IPC
  /// connection attempt has finished (whether it succeeded or not).
  Future<void> get ready => _ready.future;

  VpnService({IpcService? ipcService}) : _ipc = ipcService ?? IpcService() {
    _setupNotificationListener();
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Stream of VPN state changes (status transitions, errors, etc.).
  Stream<VpnState> get stateStream => _stateController.stream;

  /// Stream of periodic traffic statistics while connected.
  Stream<StatsUpdate> get statsStream => _statsController.stream;

  /// The most recently known VPN state.
  VpnState get currentState => _currentState;

  /// Whether the IPC connection to the Go backend is alive.
  bool get isBackendConnected => _ipc.isConnected;

  /// Initialize the service by connecting to the Go backend IPC pipe.
  Future<bool> initialize() async {
    final result = await _ipc.connect();
    if (!_ready.isCompleted) {
      _ready.complete();
    }
    return result;
  }

  /// Connect the VPN using the given server link (vless:// or hysteria2://).
  ///
  /// Optionally pass [splitTunnelConfig] to apply split tunneling rules.
  /// Throws [IpcException] if the backend reports an error.
  Future<void> connectVpn(
    String link, {
    SplitTunnelConfig? splitTunnelConfig,
  }) async {
    _updateState(_currentState.copyWith(
      status: VpnStatus.connecting,
      errorMessage: () => null,
    ));

    try {
      final params = <String, dynamic>{'link': link};
      if (splitTunnelConfig != null && splitTunnelConfig.isEnabled) {
        params['splitTunnelMode'] = splitTunnelConfig.mode;
        params['splitTunnelApps'] = splitTunnelConfig.apps;
        params['splitTunnelDomains'] = splitTunnelConfig.domains;
        params['splitTunnelInvert'] = splitTunnelConfig.invert;
      }
      final result = await _ipc.sendRequest('vpn.connect', params);

      _updateState(VpnState(
        status: VpnStatus.connected,
        serverName: result['serverName'] as String?,
        protocol: result['protocol'] as String?,
        connectedAt: DateTime.now(),
      ));
    } catch (e) {
      _updateState(_currentState.copyWith(
        status: VpnStatus.error,
        errorMessage: () => _sanitizeError(e),
      ));
      rethrow;
    }
  }

  /// Disconnect the currently active VPN connection.
  Future<void> disconnectVpn() async {
    _updateState(_currentState.copyWith(status: VpnStatus.disconnecting));

    try {
      await _ipc.sendRequest('vpn.disconnect');
      _updateState(VpnState.initial());
    } catch (e) {
      _updateState(_currentState.copyWith(
        status: VpnStatus.error,
        errorMessage: () => _sanitizeError(e),
      ));
      rethrow;
    }
  }

  /// Query the current VPN status from the Go backend.
  Future<VpnState> getStatus() async {
    final result = await _ipc.sendRequest('vpn.status');
    final state = VpnState.fromJson(result);
    _updateState(state);
    return state;
  }

  /// List installed applications available for split tunneling.
  ///
  /// Waits for the IPC connection to be ready before sending the request.
  /// If the backend is not connected, throws an [IpcException].
  Future<List<AppInfo>> listApps() async {
    // Wait for initialize() to finish, with a timeout.
    await _ready.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {},
    );

    if (!_ipc.isConnected) {
      throw const IpcException(
        'Backend service is not running. '
        'Please ensure MRVPN-service.exe is started.',
      );
    }

    final result = await _ipc.sendRequest('apps.list');
    // The backend returns the list as the 'value' key when it's not a map
    final value = result['value'];
    if (value is List) {
      return value
          .map((e) => AppInfo.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Apply a split tunnel configuration to the backend.
  Future<void> setSplitTunnelConfig(SplitTunnelConfig config) async {
    await _ipc.sendRequest('split.setConfig', config.toJson());
  }

  /// Retrieve the current split tunnel configuration from the backend.
  Future<SplitTunnelConfig> getSplitTunnelConfig() async {
    final result = await _ipc.sendRequest('split.getConfig');
    return SplitTunnelConfig.fromJson(result);
  }

  /// Ping a VPN server and return the latency in milliseconds.
  ///
  /// Returns -1 if the server is unreachable.
  Future<int> pingServer(String link) async {
    try {
      final result = await _ipc.sendRequest('servers.ping', {'link': link});
      return result['latency'] as int? ?? -1;
    } catch (_) {
      return -1;
    }
  }

  /// Tell the backend service to disconnect VPN and exit its process.
  Future<void> shutdownBackend() async {
    try {
      if (_ipc.isConnected) {
        await _ipc.sendRequest('service.shutdown').timeout(
          const Duration(seconds: 2),
          onTimeout: () => <String, dynamic>{},
        );
      }
    } catch (_) {
      // Best-effort — the service may already be gone.
    }
  }

  /// Dispose of the service and release all resources.
  Future<void> dispose() async {
    await _notificationSub?.cancel();
    await _connectionStatusSub?.cancel();
    await _stateController.close();
    await _statsController.close();
    await _ipc.dispose();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Set up listeners for backend notifications and connection status.
  void _setupNotificationListener() {
    _notificationSub = _ipc.notifications.listen(_handleNotification);

    _connectionStatusSub = _ipc.connectionStatus.listen((connected) {
      if (!connected && _currentState.isActive) {
        _updateState(_currentState.copyWith(
          status: VpnStatus.error,
          errorMessage: () => 'Lost connection to backend service',
        ));
      }
    });
  }

  /// Handle a notification message from the Go backend.
  void _handleNotification(Map<String, dynamic> message) {
    final method = message['method'] as String?;
    final params = message['params'] as Map<String, dynamic>? ?? {};

    switch (method) {
      case 'vpn.stateChanged':
        final state = VpnState.fromJson(params);
        _updateState(state);
        break;

      case 'vpn.statsUpdate':
        final stats = StatsUpdate.fromJson(params);
        _statsController.add(stats);

        // Also update the current state with latest traffic numbers.
        _updateState(_currentState.copyWith(
          upload: stats.upload,
          download: stats.download,
          upSpeed: stats.upSpeed,
          downSpeed: stats.downSpeed,
        ));
        break;

      case 'error':
        final errorMsg = params['message'] as String? ?? 'Unknown error';
        _updateState(_currentState.copyWith(
          status: VpnStatus.error,
          errorMessage: () => errorMsg,
        ));
        break;
    }
  }

  /// Sanitize backend error messages to avoid leaking internal details.
  static String _sanitizeError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('not connected') || msg.contains('connection lost')) {
      return 'Backend service is not connected';
    }
    if (msg.contains('timed out') || msg.contains('timeout')) {
      return 'Request timed out';
    }
    if (msg.contains('connection refused')) {
      return 'Unable to reach VPN server';
    }
    if (msg.contains('connection failed')) {
      return 'Connection failed';
    }
    if (msg.contains('parse')) {
      return 'Invalid server configuration';
    }
    return 'An error occurred';
  }

  /// Update the current state and notify listeners.
  void _updateState(VpnState newState) {
    _currentState = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }
}
