import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/translations.dart';
import '../providers/locale_provider.dart';
import '../providers/split_tunnel_provider.dart';
import '../theme/colors.dart';
import '../widgets/app_tile.dart';
import '../widgets/domain_list.dart';

/// Split tunnel configuration screen for MRVPN.
///
/// Allows the user to choose between Off, App, or Domain tunneling modes,
/// configure which apps or domains are included/excluded, and toggle the
/// invert option.
class SplitTunnelScreen extends ConsumerStatefulWidget {
  const SplitTunnelScreen({super.key});

  @override
  ConsumerState<SplitTunnelScreen> createState() => _SplitTunnelScreenState();
}

class _SplitTunnelScreenState extends ConsumerState<SplitTunnelScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(splitTunnelProvider);
    final notifier = ref.read(splitTunnelProvider.notifier);
    final locale = ref.watch(localeProvider);
    final theme = Theme.of(context);
    final t = (String key) => S.of(locale, key);

    return Scaffold(
      appBar: AppBar(
        title: Text(t('splitTunnel')),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mode selector
            Center(
              child: SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'off',
                    label: Text(t('off')),
                    icon: const Icon(Icons.block, size: 18),
                  ),
                  ButtonSegment(
                    value: 'app',
                    label: Text(t('app')),
                    icon: const Icon(Icons.apps, size: 18),
                  ),
                  ButtonSegment(
                    value: 'domain',
                    label: Text(t('domain')),
                    icon: const Icon(Icons.language, size: 18),
                  ),
                ],
                selected: {config.mode},
                onSelectionChanged: (selected) {
                  notifier.setMode(selected.first);
                },
                style: SegmentedButton.styleFrom(
                  selectedForegroundColor: Colors.white,
                  selectedBackgroundColor: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Content based on mode
            Expanded(
              child: _buildModeContent(
                  config.mode, config, notifier, theme, locale),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeContent(
    String mode,
    dynamic config,
    SplitTunnelNotifier notifier,
    ThemeData theme,
    String locale,
  ) {
    switch (mode) {
      case 'app':
        return _buildAppMode(config, notifier, theme, locale);
      case 'domain':
        return _buildDomainMode(config, notifier, theme, locale);
      default:
        final t = (String key) => S.of(locale, key);
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.call_split_outlined,
                size: 64,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                t('splitDisabled'),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                t('splitDisabledDesc'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildAppMode(
    dynamic config,
    SplitTunnelNotifier notifier,
    ThemeData theme,
    String locale,
  ) {
    final installedApps = ref.watch(installedAppsProvider);
    final t = (String key) => S.of(locale, key);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Invert toggle
        SwitchListTile(
          title: Text(t('invertSelection')),
          subtitle: Text(
            config.invert ? t('appsBypassVpn') : t('appsUseVpn'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          value: config.invert,
          onChanged: (value) => notifier.setInvert(value),
          activeColor: AppColors.primary,
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 8),

        // Search bar
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: t('searchApps'),
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
          ),
          onChanged: (value) {
            setState(() => _searchQuery = value.toLowerCase());
          },
        ),
        const SizedBox(height: 8),

        // App list
        Expanded(
          child: installedApps.when(
            data: (apps) {
              // Mark apps as selected based on config.
              final appList = apps.map((app) {
                return app.copyWith(
                  isSelected: config.apps.contains(app.exeName),
                );
              }).toList();

              // Filter by search query.
              final filtered = _searchQuery.isEmpty
                  ? appList
                  : appList
                      .where((app) =>
                          app.name.toLowerCase().contains(_searchQuery) ||
                          app.exeName.toLowerCase().contains(_searchQuery))
                      .toList();

              // Selected apps first, then alphabetical.
              filtered.sort((a, b) {
                if (a.isSelected != b.isSelected) {
                  return a.isSelected ? -1 : 1;
                }
                return a.name.toLowerCase().compareTo(b.name.toLowerCase());
              });

              if (filtered.isEmpty) {
                return Center(
                  child: Text(
                    _searchQuery.isEmpty ? t('noApps') : t('noMatchingApps'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.4),
                    ),
                  ),
                );
              }

              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final app = filtered[index];
                  return AppTile(
                    app: app,
                    onChanged: (selected) {
                      if (selected == true) {
                        notifier.addApp(app.exeName);
                      } else {
                        notifier.removeApp(app.exeName);
                      }
                    },
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t('failedLoadApps'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      error.toString(),
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      ref.invalidate(installedAppsProvider);
                    },
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(t('retry')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDomainMode(
    dynamic config,
    SplitTunnelNotifier notifier,
    ThemeData theme,
    String locale,
  ) {
    final t = (String key) => S.of(locale, key);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Invert toggle
        SwitchListTile(
          title: Text(t('invertSelection')),
          subtitle: Text(
            config.invert ? t('domainsBypassVpn') : t('domainsUseVpn'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          value: config.invert,
          onChanged: (value) => notifier.setInvert(value),
          activeColor: AppColors.primary,
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 8),

        // Domain list
        Expanded(
          child: DomainList(
            domains: config.domains.cast<String>(),
            onAdd: (domain) => notifier.addDomain(domain),
            onRemove: (domain) => notifier.removeDomain(domain),
            onImport: () {
              // TODO: Implement domain import from file.
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Import not yet implemented'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            onExport: () {
              // TODO: Implement domain export to file.
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Export not yet implemented'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
