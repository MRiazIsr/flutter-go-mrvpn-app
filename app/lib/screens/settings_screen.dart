import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/translations.dart';
import '../providers/locale_provider.dart';
import '../theme/colors.dart';

// ---------------------------------------------------------------------------
// Settings-specific providers
// ---------------------------------------------------------------------------

/// Provides the persisted settings state.
///
/// In a full implementation these would be backed by [StorageService]. For now
/// they are simple [StateProvider]s so the UI is fully functional.
final autoConnectProvider = StateProvider<bool>((ref) => false);
final startMinimizedProvider = StateProvider<bool>((ref) => false);
final killSwitchProvider = StateProvider<bool>((ref) => false);
final dnsOptionProvider = StateProvider<String>((ref) => 'System');
final mtuProvider = StateProvider<int>((ref) => 1500);

/// Settings screen for MRVPN.
///
/// Allows the user to configure auto-connect, tray behavior, kill switch,
/// DNS, MTU, and view app version information.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _mtuController;

  static const _dnsOptions = ['System', 'Cloudflare', 'Google', 'Custom'];

  @override
  void initState() {
    super.initState();
    _mtuController =
        TextEditingController(text: ref.read(mtuProvider).toString());
  }

  @override
  void dispose() {
    _mtuController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final autoConnect = ref.watch(autoConnectProvider);
    final startMinimized = ref.watch(startMinimizedProvider);
    final killSwitch = ref.watch(killSwitchProvider);
    final dnsOption = ref.watch(dnsOptionProvider);
    final locale = ref.watch(localeProvider);
    final theme = Theme.of(context);
    final t = (String key) => S.of(locale, key);

    return Scaffold(
      appBar: AppBar(
        title: Text(t('settings')),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // ---------------------------------------------------------------
          // General
          // ---------------------------------------------------------------
          _SectionHeader(title: t('general')),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(t('autoConnect')),
                  subtitle: Text(t('autoConnectDesc')),
                  value: autoConnect,
                  onChanged: (value) {
                    ref.read(autoConnectProvider.notifier).state = value;
                  },
                  activeColor: AppColors.primary,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                SwitchListTile(
                  title: Text(t('startMinimized')),
                  subtitle: Text(t('startMinimizedDesc')),
                  value: startMinimized,
                  onChanged: (value) {
                    ref.read(startMinimizedProvider.notifier).state = value;
                  },
                  activeColor: AppColors.primary,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                SwitchListTile(
                  title: Text(t('killSwitch')),
                  subtitle: Text(t('killSwitchDesc')),
                  value: killSwitch,
                  onChanged: (value) {
                    ref.read(killSwitchProvider.notifier).state = value;
                  },
                  activeColor: AppColors.primary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ---------------------------------------------------------------
          // Network
          // ---------------------------------------------------------------
          _SectionHeader(title: t('network')),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // DNS dropdown
                  Text(
                    t('dns'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: dnsOption,
                    items: _dnsOptions.map((option) {
                      return DropdownMenuItem(
                        value: option,
                        child: Text(option),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        ref.read(dnsOptionProvider.notifier).state = value;
                      }
                    },
                    decoration: const InputDecoration(
                      isDense: true,
                      prefixIcon: Icon(Icons.dns_outlined),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // MTU text field
                  Text(
                    t('mtu'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _mtuController,
                    decoration: const InputDecoration(
                      hintText: '1500',
                      isDense: true,
                      prefixIcon: Icon(Icons.straighten_outlined),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(5),
                    ],
                    onChanged: (value) {
                      final mtu = int.tryParse(value);
                      if (mtu != null && mtu > 0) {
                        ref.read(mtuProvider.notifier).state = mtu;
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ---------------------------------------------------------------
          // About
          // ---------------------------------------------------------------
          _SectionHeader(title: t('about')),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.shield_outlined,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MRVPN',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            t('version'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    t('aboutDesc'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Section header used to separate groups of settings.
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}
