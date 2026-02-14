import 'package:flutter/material.dart';

import '../l10n/translations.dart';
import '../services/update_service.dart';
import '../theme/colors.dart';

/// Dialog shown when a new version of MRVPN is available.
///
/// Displays the current and new version, release notes, and provides
/// buttons to download, skip, or dismiss.
class UpdateDialog extends StatelessWidget {
  final UpdateInfo info;
  final String locale;
  final String currentVersion;

  const UpdateDialog({
    super.key,
    required this.info,
    required this.locale,
    required this.currentVersion,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = (String key) => S.of(locale, key);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.system_update_outlined,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Text(t('updateAvailable')),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('updateAvailableDesc'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            // Version info
            Row(
              children: [
                _VersionChip(
                  label: t('currentVersion'),
                  version: currentVersion,
                  isPrimary: false,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.arrow_forward, size: 18),
                ),
                _VersionChip(
                  label: t('newVersion'),
                  version: info.version,
                  isPrimary: true,
                ),
              ],
            ),
            // Release notes
            if (info.releaseNotes != null &&
                info.releaseNotes!.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    info.releaseNotes!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop('skip'),
          child: Text(
            t('skipVersion'),
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop('later'),
          child: Text(t('later')),
        ),
        FilledButton(
          onPressed: () {
            final url = info.downloadUrl ?? info.releaseUrl;
            UpdateService.openInBrowser(url);
            Navigator.of(context).pop('download');
          },
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.download, size: 18),
              const SizedBox(width: 6),
              Text(t('download')),
            ],
          ),
        ),
      ],
    );
  }
}

class _VersionChip extends StatelessWidget {
  final String label;
  final String version;
  final bool isPrimary;

  const _VersionChip({
    required this.label,
    required this.version,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isPrimary
                ? AppColors.primary.withValues(alpha: 0.15)
                : theme.colorScheme.onSurface.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'v$version',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: isPrimary ? AppColors.primary : null,
            ),
          ),
        ),
      ],
    );
  }
}
