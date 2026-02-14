import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/translations.dart';
import '../models/subscription_config.dart';
import '../providers/locale_provider.dart';
import '../providers/subscription_provider.dart';
import '../theme/colors.dart';

/// Subscription management screen for MRVPN.
///
/// Displays saved subscriptions with traffic info and server counts.
/// Provides add, refresh, and delete actions.
class SubscriptionsScreen extends ConsumerStatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  ConsumerState<SubscriptionsScreen> createState() =>
      _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends ConsumerState<SubscriptionsScreen> {
  Future<void> _showAddSubscriptionDialog() async {
    final urlController = TextEditingController();
    final nameController = TextEditingController();
    final locale = ref.read(localeProvider);
    final t = (String key) => S.of(locale, key);
    bool isLoading = false;

    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(t('addSubscription')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: urlController,
                    decoration: InputDecoration(
                      hintText: t('subscriptionUrl'),
                      prefixIcon: const Icon(Icons.link),
                    ),
                    maxLines: 2,
                    minLines: 1,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final data =
                          await Clipboard.getData(Clipboard.kTextPlain);
                      if (data?.text != null) {
                        urlController.text = data!.text!;
                      }
                    },
                    icon: const Icon(Icons.content_paste, size: 18),
                    label: Text(t('importClipboard')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      hintText: t('subscriptionName'),
                      prefixIcon: const Icon(Icons.label_outline),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed:
                      isLoading ? null : () => Navigator.of(dialogContext).pop(),
                  child: Text(t('cancel')),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final url = urlController.text.trim();
                          if (url.isEmpty) return;

                          setDialogState(() => isLoading = true);
                          try {
                            await ref
                                .read(subscriptionProvider.notifier)
                                .addSubscription(
                                  url,
                                  name: nameController.text.trim(),
                                );
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text(t('subscriptionAdded')),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isLoading = false);
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${t('subscriptionError')}: $e',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(t('add')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(SubscriptionConfig sub) async {
    final locale = ref.read(localeProvider);
    final t = (String key) => S.of(locale, key);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(t('deleteServer')),
          content: Text(t('confirmDeleteSubscription')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(t('cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.disconnected,
              ),
              child: Text(t('delete')),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      ref.read(subscriptionProvider.notifier).removeSubscription(sub.id);
    }
  }

  String _formatTimeAgo(DateTime? dateTime, String Function(String) t) {
    if (dateTime == null) return t('never');
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return t('justNow');
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  String _formatTraffic(int bytes) {
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final subscriptions = ref.watch(subscriptionProvider);
    final locale = ref.watch(localeProvider);
    final theme = Theme.of(context);
    final t = (String key) => S.of(locale, key);

    return Scaffold(
      appBar: AppBar(
        title: Text(t('subscriptions')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: t('refreshAll'),
            onPressed: subscriptions.isEmpty
                ? null
                : () => ref.read(subscriptionProvider.notifier).refreshAll(),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: t('addSubscription'),
            onPressed: _showAddSubscriptionDialog,
          ),
        ],
      ),
      body: subscriptions.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.rss_feed,
                    size: 64,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    t('noSubscriptions'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _showAddSubscriptionDialog,
                    icon: const Icon(Icons.add),
                    label: Text(t('addSubscription')),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: subscriptions.length,
              itemBuilder: (context, index) {
                final sub = subscriptions[index];
                return _SubscriptionCard(
                  sub: sub,
                  timeAgo: _formatTimeAgo(sub.lastUpdated, t),
                  trafficText: sub.trafficUsed != null && sub.trafficLimit != null
                      ? '${_formatTraffic(sub.trafficUsed!)} / ${_formatTraffic(sub.trafficLimit!)}'
                      : null,
                  trafficProgress: sub.trafficUsed != null &&
                          sub.trafficLimit != null &&
                          sub.trafficLimit! > 0
                      ? sub.trafficUsed! / sub.trafficLimit!
                      : null,
                  onRefresh: () => ref
                      .read(subscriptionProvider.notifier)
                      .refreshSubscription(sub.id),
                  onDelete: () => _confirmDelete(sub),
                  t: t,
                );
              },
            ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  final SubscriptionConfig sub;
  final String timeAgo;
  final String? trafficText;
  final double? trafficProgress;
  final VoidCallback onRefresh;
  final VoidCallback onDelete;
  final String Function(String) t;

  const _SubscriptionCard({
    required this.sub,
    required this.timeAgo,
    this.trafficText,
    this.trafficProgress,
    required this.onRefresh,
    required this.onDelete,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final urlDisplay = sub.url.length > 40
        ? '${sub.url.substring(0, 40)}...'
        : sub.url;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: name + actions
            Row(
              children: [
                const Icon(Icons.rss_feed, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sub.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Server count badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${sub.serverIds.length} ${t('serversCount')}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: onRefresh,
                  tooltip: t('refresh'),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: theme.colorScheme.error,
                  ),
                  onPressed: onDelete,
                  tooltip: t('delete'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 4),
            // URL
            Text(
              urlDisplay,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 6),
            // Info row: last updated
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 4),
                Text(
                  '${t('lastUpdated')}: $timeAgo',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            // Traffic bar
            if (trafficText != null && trafficProgress != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '${t('trafficUsed')}: $trafficText',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: trafficProgress!.clamp(0.0, 1.0),
                  backgroundColor:
                      AppColors.primary.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    trafficProgress! > 0.9
                        ? AppColors.disconnected
                        : AppColors.primary,
                  ),
                  minHeight: 6,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
