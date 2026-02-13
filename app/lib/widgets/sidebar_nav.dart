import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/translations.dart';
import '../models/vpn_state.dart';
import '../providers/locale_provider.dart';
import '../providers/vpn_provider.dart';
import '../theme/colors.dart';

/// Desktop sidebar navigation for MRVPN.
///
/// Uses [NavigationRail] with collapsible labels and a connection status
/// indicator at the bottom. Determines selected index from the current route.
class SidebarNav extends ConsumerStatefulWidget {
  const SidebarNav({super.key});

  @override
  ConsumerState<SidebarNav> createState() => _SidebarNavState();
}

class _SidebarNavState extends ConsumerState<SidebarNav> {
  bool _extended = true;

  static const _routes = ['/', '/servers', '/split-tunnel', '/settings'];

  List<NavigationRailDestination> _destinations(String locale) {
    final t = (String key) => S.of(locale, key);
    return [
      NavigationRailDestination(
        icon: const Icon(Icons.dashboard_outlined),
        selectedIcon: const Icon(Icons.dashboard),
        label: Text(t('home')),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.dns_outlined),
        selectedIcon: const Icon(Icons.dns),
        label: Text(t('servers')),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.call_split_outlined),
        selectedIcon: const Icon(Icons.call_split),
        label: Text(t('splitTunnel')),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.settings_outlined),
        selectedIcon: const Icon(Icons.settings),
        label: Text(t('settings')),
      ),
    ];
  }

  int _selectedIndexFromRoute(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final index = _routes.indexOf(location);
    return index >= 0 ? index : 0;
  }

  void _onDestinationSelected(int index) {
    context.go(_routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    final vpnState = ref.watch(vpnProvider);
    final locale = ref.watch(localeProvider);
    final isConnected = vpnState.status == VpnStatus.connected;
    final selectedIndex = _selectedIndexFromRoute(context);
    final t = (String key) => S.of(locale, key);

    return NavigationRail(
      extended: _extended,
      selectedIndex: selectedIndex,
      onDestinationSelected: _onDestinationSelected,
      minWidth: 72,
      minExtendedWidth: 180,
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: IconButton(
          icon: Icon(_extended ? Icons.menu_open : Icons.menu),
          onPressed: () {
            setState(() {
              _extended = !_extended;
            });
          },
          tooltip: _extended ? t('collapse') : t('expand'),
        ),
      ),
      trailing: Expanded(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isConnected
                        ? AppColors.connected
                        : AppColors.disconnected,
                    boxShadow: [
                      BoxShadow(
                        color: (isConnected
                                ? AppColors.connected
                                : AppColors.disconnected)
                            .withValues(alpha: 0.5),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                if (_extended) ...[
                  const SizedBox(width: 8),
                  Text(
                    isConnected ? t('connected') : t('disconnected'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isConnected
                              ? AppColors.connected
                              : AppColors.disconnected,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      destinations: _destinations(locale),
    );
  }
}
