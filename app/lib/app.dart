import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers/locale_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/update_provider.dart';
import 'services/update_service.dart';
import 'screens/home_screen.dart';
import 'screens/servers_screen.dart';
import 'screens/split_tunnel_screen.dart';
import 'screens/subscriptions_screen.dart';
import 'screens/settings_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/app_header.dart';
import 'widgets/sidebar_nav.dart';
import 'widgets/update_dialog.dart';

// Shell route key for the scaffold with sidebar
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return _AppShell(child: child);
      },
      routes: [
        GoRoute(
          path: '/',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: HomeScreen(),
          ),
        ),
        GoRoute(
          path: '/servers',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: ServersScreen(),
          ),
        ),
        GoRoute(
          path: '/subscriptions',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: SubscriptionsScreen(),
          ),
        ),
        GoRoute(
          path: '/split-tunnel',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: SplitTunnelScreen(),
          ),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: SettingsScreen(),
          ),
        ),
      ],
    ),
  ],
);

class MRVPNApp extends ConsumerWidget {
  const MRVPNApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'MRVPN',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      locale: Locale(locale),
      routerConfig: _router,
    );
  }
}

class _AppShell extends ConsumerStatefulWidget {
  final Widget child;

  const _AppShell({required this.child});

  @override
  ConsumerState<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<_AppShell> {
  bool _updateChecked = false;

  @override
  Widget build(BuildContext context) {
    // Listen for update check results and show dialog once.
    ref.listen<AsyncValue<UpdateInfo?>>(updateCheckProvider, (prev, next) {
      if (_updateChecked) return;
      next.whenData((info) {
        if (info != null && mounted) {
          _updateChecked = true;
          final locale = ref.read(localeProvider);
          final version =
              ref.read(appVersionProvider).valueOrNull ?? '?';
          showDialog(
            context: context,
            builder: (_) => UpdateDialog(
              info: info,
              locale: locale,
              currentVersion: version,
            ),
          ).then((result) {
            if (result == 'skip') {
              skipVersion(info.version);
            }
          });
        }
      });
    });

    return Scaffold(
      body: Column(
        children: [
          const AppHeader(),
          Expanded(
            child: Row(
              children: [
                const SidebarNav(),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(child: widget.child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
