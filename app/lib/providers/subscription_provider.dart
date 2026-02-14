import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/subscription_config.dart';
import '../services/storage_service.dart';
import '../services/subscription_service.dart';
import 'server_provider.dart';
import 'theme_provider.dart';

// ---------------------------------------------------------------------------
// Subscription list notifier
// ---------------------------------------------------------------------------

/// Manages the list of VPN subscriptions.
///
/// Each subscription holds a URL that returns base64-encoded server links.
/// Servers from subscriptions are stored in [ServerNotifier] alongside
/// manually added servers. The difference is tracked via
/// [SubscriptionConfig.serverIds].
class SubscriptionNotifier extends StateNotifier<List<SubscriptionConfig>> {
  final StorageService _storage;
  final SubscriptionService _subscriptionService;
  final ServerNotifier _serverNotifier;
  Timer? _autoRefreshTimer;

  SubscriptionNotifier(
    this._storage,
    this._subscriptionService,
    this._serverNotifier,
  ) : super([]) {
    _load();
  }

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  Future<void> _load() async {
    final subs = await _storage.loadSubscriptions();
    if (mounted) {
      state = subs;
      _startAutoRefresh();
    }
  }

  Future<void> _save() async {
    await _storage.saveSubscriptions(state);
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Add a new subscription by URL.
  ///
  /// Fetches the subscription, parses server links, adds them to
  /// [ServerNotifier], and stores the subscription config.
  ///
  /// Throws [Exception] if the fetch fails.
  Future<void> addSubscription(String url, {String? name}) async {
    final result = await _subscriptionService.fetchSubscription(url);
    if (result.error != null) {
      throw Exception(result.error);
    }

    // Add each server link and collect their IDs
    final serverIds = <String>[];
    for (final link in result.links) {
      try {
        await _serverNotifier.addServer(link);
        final id = link.hashCode.toRadixString(36);
        serverIds.add(id);
      } catch (_) {
        // Skip unparseable links
      }
    }

    final displayName =
        name?.isNotEmpty == true ? name! : 'Subscription ${state.length + 1}';
    final id = url.hashCode.toRadixString(36);

    final config = SubscriptionConfig(
      id: id,
      name: displayName,
      url: url,
      updateInterval: result.updateInterval,
      lastUpdated: DateTime.now(),
      trafficUsed: result.trafficUsed,
      trafficLimit: result.trafficLimit,
      serverIds: serverIds,
    );

    state = [...state, config];
    await _save();
  }

  /// Refresh a subscription by re-fetching its URL.
  ///
  /// Removes old servers and adds the new ones.
  Future<void> refreshSubscription(String subscriptionId) async {
    final index = state.indexWhere((s) => s.id == subscriptionId);
    if (index == -1) return;

    final sub = state[index];

    // Remove old servers
    for (final serverId in sub.serverIds) {
      await _serverNotifier.removeServer(serverId);
    }

    // Fetch fresh data
    final result = await _subscriptionService.fetchSubscription(sub.url);
    if (result.error != null) {
      print('Failed to refresh subscription "${sub.name}": ${result.error}');
      return;
    }

    // Add new servers
    final serverIds = <String>[];
    for (final link in result.links) {
      try {
        await _serverNotifier.addServer(link);
        final id = link.hashCode.toRadixString(36);
        serverIds.add(id);
      } catch (_) {
        // Skip unparseable links
      }
    }

    if (mounted) {
      final updated = sub.copyWith(
        lastUpdated: () => DateTime.now(),
        trafficUsed: () => result.trafficUsed,
        trafficLimit: () => result.trafficLimit,
        updateInterval: result.updateInterval,
        serverIds: serverIds,
      );

      state = [
        for (int i = 0; i < state.length; i++)
          if (i == index) updated else state[i],
      ];
      await _save();
    }
  }

  /// Refresh all subscriptions.
  Future<void> refreshAll() async {
    for (final sub in state) {
      await refreshSubscription(sub.id);
    }
  }

  /// Remove a subscription and all its servers.
  Future<void> removeSubscription(String subscriptionId) async {
    final index = state.indexWhere((s) => s.id == subscriptionId);
    if (index == -1) return;

    final sub = state[index];

    // Remove all servers belonging to this subscription
    for (final serverId in sub.serverIds) {
      await _serverNotifier.removeServer(serverId);
    }

    state = state.where((s) => s.id != subscriptionId).toList();
    await _save();
  }

  // ---------------------------------------------------------------------------
  // Auto-refresh
  // ---------------------------------------------------------------------------

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    // Check every 15 minutes if any subscription needs refreshing
    _autoRefreshTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => _checkAndRefresh(),
    );
  }

  void _checkAndRefresh() {
    final now = DateTime.now();
    for (final sub in state) {
      if (sub.lastUpdated == null) continue;
      final elapsed = now.difference(sub.lastUpdated!);
      if (elapsed.inHours >= sub.updateInterval) {
        print('Auto-refreshing subscription "${sub.name}" '
            '(${elapsed.inHours}h since last update)');
        refreshSubscription(sub.id);
      }
    }
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  return SubscriptionService();
});

final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, List<SubscriptionConfig>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final subService = ref.watch(subscriptionServiceProvider);
  final serverNotifier = ref.read(serverProvider.notifier);
  return SubscriptionNotifier(storage, subService, serverNotifier);
});
