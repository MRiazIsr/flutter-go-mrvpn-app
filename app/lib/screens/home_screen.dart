import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/translations.dart';
import '../models/vpn_state.dart';
import '../providers/locale_provider.dart';
import '../providers/server_provider.dart';
import '../providers/split_tunnel_provider.dart';
import '../providers/vpn_provider.dart';
import '../theme/colors.dart';
import '../widgets/connect_button.dart';
import '../widgets/speed_indicator.dart';

/// Main dashboard screen for MRVPN.
///
/// Displays the connect button, current server info, live speed indicators,
/// connection duration timer, and a summary info card.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _durationTimer;

  @override
  void dispose() {
    _durationTimer?.cancel();
    super.dispose();
  }

  /// Start or stop the duration timer based on connection status.
  void _manageDurationTimer(VpnStatus status) {
    if (status == VpnStatus.connected) {
      _durationTimer ??= Timer.periodic(
        const Duration(seconds: 1),
        (_) {
          if (mounted) setState(() {});
        },
      );
    } else {
      _durationTimer?.cancel();
      _durationTimer = null;
    }
  }

  /// Format a [Duration] as HH:MM:SS.
  String _formatDuration(Duration? duration) {
    if (duration == null) return '00:00:00';
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  String _connectButtonLabel(String locale, VpnStatus status) {
    switch (status) {
      case VpnStatus.connected:
        return S.of(locale, 'connected');
      case VpnStatus.connecting:
        return S.of(locale, 'connecting');
      case VpnStatus.disconnecting:
        return S.of(locale, 'disconnecting');
      case VpnStatus.error:
        return S.of(locale, 'error');
      case VpnStatus.disconnected:
        return S.of(locale, 'connect');
    }
  }

  void _onConnectTap() {
    final vpnState = ref.read(vpnProvider);
    final selectedServer = ref.read(selectedServerConfigProvider);
    final locale = ref.read(localeProvider);

    if (vpnState.status == VpnStatus.connected ||
        vpnState.status == VpnStatus.connecting) {
      ref.read(vpnProvider.notifier).disconnect();
    } else {
      if (selectedServer == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.of(locale, 'selectServerFirst')),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      final splitConfig = ref.read(splitTunnelProvider);
      ref.read(vpnProvider.notifier).connect(
            selectedServer.link,
            splitTunnelConfig: splitConfig,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vpnState = ref.watch(vpnProvider);
    final selectedServer = ref.watch(selectedServerConfigProvider);
    final servers = ref.watch(serverProvider);
    final locale = ref.watch(localeProvider);
    final theme = Theme.of(context);
    final t = (String key) => S.of(locale, key);

    // Manage the duration timer based on current status.
    _manageDurationTimer(vpnState.status);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Connect button
              ConnectButton(
                status: vpnState.status,
                label: _connectButtonLabel(locale, vpnState.status),
                onTap: _onConnectTap,
              ),
              const SizedBox(height: 24),

              // Server selector
              _ServerSelector(
                selectedServer: selectedServer,
                servers: servers,
                locale: locale,
                onSelected: (server) {
                  ref
                      .read(selectedServerProvider.notifier)
                      .select(server.id);
                },
                onNoServers: () => context.go('/servers'),
              ),
              const SizedBox(height: 32),

              // Speed indicators
              SpeedIndicator(
                uploadSpeed: vpnState.upSpeed,
                downloadSpeed: vpnState.downSpeed,
                totalUpload: vpnState.upload,
                totalDownload: vpnState.download,
              ),
              const SizedBox(height: 24),

              // Connection duration — always occupies space to prevent layout jump.
              AnimatedOpacity(
                opacity: vpnState.status == VpnStatus.connected ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _formatDuration(vpnState.connectionDuration),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w300,
                    letterSpacing: 2,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Connection info card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _InfoRow(
                        label: t('status'),
                        value: vpnState.status.name.toUpperCase(),
                        valueColor: vpnState.status == VpnStatus.connected
                            ? AppColors.connected
                            : vpnState.status == VpnStatus.error
                                ? AppColors.disconnected
                                : null,
                      ),
                      const Divider(height: 20),
                      _InfoRow(
                        label: t('server'),
                        value: vpnState.serverName ??
                            selectedServer?.name ??
                            '-',
                      ),
                      const Divider(height: 20),
                      _InfoRow(
                        label: t('protocol'),
                        value: vpnState.protocol ??
                            selectedServer?.protocol ??
                            '-',
                      ),
                      if (vpnState.errorMessage != null) ...[
                        const Divider(height: 20),
                        _InfoRow(
                          label: t('error'),
                          value: vpnState.errorMessage!,
                          valueColor: AppColors.disconnected,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Interactive server selector card with dropdown.
class _ServerSelector extends StatelessWidget {
  final dynamic selectedServer;
  final List servers;
  final String locale;
  final void Function(dynamic server) onSelected;
  final VoidCallback onNoServers;

  const _ServerSelector({
    required this.selectedServer,
    required this.servers,
    required this.locale,
    required this.onSelected,
    required this.onNoServers,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = (String key) => S.of(locale, key);

    if (selectedServer == null && servers.isEmpty) {
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onNoServers,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_circle_outline,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                t('noServerSelected'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return PopupMenuButton<String>(
      onSelected: (id) {
        final server = servers.firstWhere((s) => s.id == id);
        onSelected(server);
      },
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) {
        return servers.map<PopupMenuEntry<String>>((server) {
          final isSelected =
              selectedServer != null && server.id == selectedServer.id;
          return PopupMenuItem<String>(
            value: server.id,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    server.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    server.protocol,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.check, size: 16, color: AppColors.primary),
                ],
              ],
            ),
          );
        }).toList();
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selectedServer != null) ...[
            Text(
              selectedServer.name,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                selectedServer.protocol,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ] else
            Text(
              t('selectServer'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color:
                    theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          const SizedBox(width: 4),
          Icon(
            Icons.arrow_drop_down,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }
}

/// A label-value row used in the connection info card.
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
