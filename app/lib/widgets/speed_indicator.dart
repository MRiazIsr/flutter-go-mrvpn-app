import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Displays upload and download speed with total transferred data.
///
/// Automatically formats bytes into human-readable units (B/s, KB/s, MB/s, GB/s).
class SpeedIndicator extends StatelessWidget {
  /// Current upload speed in bytes per second.
  final int uploadSpeed;

  /// Current download speed in bytes per second.
  final int downloadSpeed;

  /// Total bytes uploaded.
  final int totalUpload;

  /// Total bytes downloaded.
  final int totalDownload;

  const SpeedIndicator({
    super.key,
    required this.uploadSpeed,
    required this.downloadSpeed,
    required this.totalUpload,
    required this.totalDownload,
  });

  /// Formats a byte count into a human-readable speed string.
  static String formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond < 1024) {
      return '$bytesPerSecond B/s';
    } else if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    } else if (bytesPerSecond < 1024 * 1024 * 1024) {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(2)} MB/s';
    } else {
      return '${(bytesPerSecond / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB/s';
    }
  }

  /// Formats a byte count into a human-readable data size string.
  static String formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Upload column
        _SpeedColumn(
          icon: Icons.arrow_upward_rounded,
          iconColor: AppColors.primary,
          speed: formatSpeed(uploadSpeed),
          total: formatBytes(totalUpload),
          label: 'Upload',
          theme: theme,
        ),
        const SizedBox(width: 48),
        // Download column
        _SpeedColumn(
          icon: Icons.arrow_downward_rounded,
          iconColor: AppColors.primaryGradientEnd,
          speed: formatSpeed(downloadSpeed),
          total: formatBytes(totalDownload),
          label: 'Download',
          theme: theme,
        ),
      ],
    );
  }
}

class _SpeedColumn extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String speed;
  final String total;
  final String label;
  final ThemeData theme;

  const _SpeedColumn({
    required this.icon,
    required this.iconColor,
    required this.speed,
    required this.total,
    required this.label,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          speed,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          total,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}
