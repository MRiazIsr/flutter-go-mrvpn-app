import 'package:flutter/material.dart';

import '../models/server_config.dart';
import '../theme/colors.dart';

/// Card widget displaying a single VPN server configuration.
///
/// Shows the server name, protocol badge, address:port, and latency.
/// Provides edit and delete actions, and highlights when selected.
class ServerCard extends StatelessWidget {
  /// The server configuration to display.
  final ServerConfig server;

  /// Whether this server is currently selected.
  final bool isSelected;

  /// Called when the card is tapped (to select this server).
  final VoidCallback? onTap;

  /// Called when the edit button is tapped.
  final VoidCallback? onEdit;

  /// Called when the delete button is tapped.
  final VoidCallback? onDelete;

  const ServerCard({
    super.key,
    required this.server,
    this.isSelected = false,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  /// Returns a color based on latency value.
  Color _latencyColor(int? latency) {
    if (latency == null || latency < 0) return Colors.grey;
    if (latency < 100) return AppColors.connected;
    if (latency < 200) return Colors.orange;
    return AppColors.disconnected;
  }

  /// Returns a human-readable latency string.
  String _latencyText(int? latency) {
    if (latency == null) return '-- ms';
    if (latency < 0) return 'Timeout';
    return '$latency ms';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isSelected
            ? const BorderSide(color: AppColors.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Server info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Server name + protocol badge
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            server.name,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
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
                            server.protocol,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Address:port
                    Text(
                      '${server.address}:${server.port}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),

              // Latency indicator
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      _latencyColor(server.latency).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _latencyColor(server.latency),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _latencyText(server.latency),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _latencyColor(server.latency),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Action buttons
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: onEdit,
                tooltip: 'Edit',
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: theme.colorScheme.error,
                ),
                onPressed: onDelete,
                tooltip: 'Delete',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
