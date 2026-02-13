import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/app_info.dart';
import '../theme/colors.dart';

/// List tile for an installed application in the split tunnel configuration.
///
/// Displays the app icon (extracted from the exe, or a generic fallback),
/// app name, executable name, an optional UWP badge, and a checkbox to
/// include/exclude the app from the VPN tunnel.
class AppTile extends StatelessWidget {
  /// Information about the installed application.
  final AppInfo app;

  /// Called when the checkbox value changes.
  final ValueChanged<bool?>? onChanged;

  const AppTile({
    super.key,
    required this.app,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CheckboxListTile(
      value: app.isSelected,
      onChanged: onChanged,
      activeColor: AppColors.primary,
      secondary: _AppIcon(icon: app.icon),
      title: Row(
        children: [
          Flexible(
            child: Text(
              app.name,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (app.isUwp) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'UWP',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        app.exeName,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
      controlAffinity: ListTileControlAffinity.trailing,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}

/// Displays a decoded base64 PNG icon, or a generic fallback.
class _AppIcon extends StatelessWidget {
  final String? icon;

  const _AppIcon({this.icon});

  @override
  Widget build(BuildContext context) {
    if (icon == null || icon!.isEmpty) {
      return const Icon(Icons.apps, size: 28);
    }

    try {
      final bytes = base64Decode(icon!);
      return Image.memory(
        bytes,
        width: 28,
        height: 28,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => const Icon(Icons.apps, size: 28),
      );
    } catch (_) {
      return const Icon(Icons.apps, size: 28);
    }
  }
}
