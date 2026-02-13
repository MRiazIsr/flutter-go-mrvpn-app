import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/translations.dart';
import '../models/server_config.dart';
import '../providers/locale_provider.dart';
import '../providers/server_provider.dart';
import '../theme/colors.dart';
import '../widgets/server_card.dart';

/// Server management screen for MRVPN.
///
/// Displays a list of saved servers as [ServerCard] widgets. Provides an
/// "Add Server" action that shows a dialog for importing server links.
class ServersScreen extends ConsumerStatefulWidget {
  const ServersScreen({super.key});

  @override
  ConsumerState<ServersScreen> createState() => _ServersScreenState();
}

class _ServersScreenState extends ConsumerState<ServersScreen> {
  /// Show the add server dialog.
  Future<void> _showAddServerDialog() async {
    final controller = TextEditingController();
    final locale = ref.read(localeProvider);
    final t = (String key) => S.of(locale, key);

    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(t('addServer')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: t('serverLink'),
                  prefixIcon: const Icon(Icons.link),
                ),
                maxLines: 3,
                minLines: 1,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  if (data?.text != null) {
                    controller.text = data!.text!;
                    // Clear clipboard to avoid leaving VPN credentials accessible
                    await Clipboard.setData(const ClipboardData(text: ''));
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
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(t('cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                final link = controller.text.trim();
                if (link.isEmpty) return;

                try {
                  ref.read(serverProvider.notifier).addServer(link);
                  Navigator.of(dialogContext).pop();
                } on FormatException catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.message),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: Text(t('add')),
            ),
          ],
        );
      },
    );
  }

  /// Show a confirmation dialog before deleting a server.
  Future<void> _confirmDelete(ServerConfig server) async {
    final locale = ref.read(localeProvider);
    final t = (String key) => S.of(locale, key);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(t('deleteServer')),
          content: Text(
            t('deleteConfirm').replaceAll('\$name', server.name),
          ),
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
      ref.read(serverProvider.notifier).removeServer(server.id);
    }
  }

  /// Show a dialog to edit a server's display name.
  Future<void> _showEditDialog(ServerConfig server) async {
    final controller = TextEditingController(text: server.name);
    final locale = ref.read(localeProvider);
    final t = (String key) => S.of(locale, key);

    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(t('editName')),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: t('newName'),
              prefixIcon: const Icon(Icons.label_outline),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(t('cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                ref.read(serverProvider.notifier).updateServer(
                      server.copyWith(name: name),
                    );
                Navigator.of(dialogContext).pop();
              },
              child: Text(t('save')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final servers = ref.watch(serverProvider);
    final selectedId = ref.watch(selectedServerProvider);
    final locale = ref.watch(localeProvider);
    final theme = Theme.of(context);
    final t = (String key) => S.of(locale, key);

    return Scaffold(
      appBar: AppBar(
        title: Text(t('servers')),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: t('addServer'),
            onPressed: _showAddServerDialog,
          ),
        ],
      ),
      body: servers.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.dns_outlined,
                    size: 64,
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    t('noServersTitle'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _showAddServerDialog,
                    icon: const Icon(Icons.add),
                    label: Text(t('addFirstServer')),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: servers.length,
              itemBuilder: (context, index) {
                final server = servers[index];
                return ServerCard(
                  server: server,
                  isSelected: server.id == selectedId,
                  onTap: () {
                    ref
                        .read(selectedServerProvider.notifier)
                        .select(server.id);
                  },
                  onEdit: () => _showEditDialog(server),
                  onDelete: () => _confirmDelete(server),
                );
              },
            ),
    );
  }
}
