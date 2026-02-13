import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../providers/locale_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/colors.dart';

/// Custom frameless window header bar for MRVPN.
///
/// Renders a 40px-tall bar with the app logo, a draggable center area,
/// language toggle, theme toggle, and window control buttons.
class AppHeader extends ConsumerStatefulWidget {
  const AppHeader({super.key});

  @override
  ConsumerState<AppHeader> createState() => _AppHeaderState();
}

class _AppHeaderState extends ConsumerState<AppHeader> {
  bool _isMaximized = false;
  bool _closeHovered = false;

  @override
  void initState() {
    super.initState();
    _checkMaximized();
  }

  Future<void> _checkMaximized() async {
    final maximized = await windowManager.isMaximized();
    if (mounted) setState(() => _isMaximized = maximized);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeProvider);

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // -- App logo + name --
          const SizedBox(width: 12),
          Icon(
            Icons.shield_outlined,
            color: AppColors.primary,
            size: 18,
          ),
          const SizedBox(width: 6),
          Text(
            'MRVPN',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 8),

          // -- Draggable center area --
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (_) => windowManager.startDragging(),
              onDoubleTap: _toggleMaximize,
              child: const SizedBox.expand(),
            ),
          ),

          // -- Language toggle --
          _HeaderTextButton(
            label: locale == 'en' ? 'EN' : 'RU',
            onTap: () {
              final next = locale == 'en' ? 'ru' : 'en';
              ref.read(localeProvider.notifier).setLocale(next);
            },
          ),
          const SizedBox(width: 2),

          // -- Theme toggle --
          _HeaderIconButton(
            icon: _themeIcon(themeMode),
            tooltip: _themeTooltip(themeMode),
            onTap: () => _cycleTheme(themeMode),
          ),
          const SizedBox(width: 4),

          // -- Divider before window controls --
          Container(
            width: 1,
            height: 16,
            color: theme.dividerColor,
          ),
          const SizedBox(width: 2),

          // -- Minimize to tray --
          _HeaderIconButton(
            icon: Icons.remove,
            tooltip: 'Minimize to tray',
            onTap: () => windowManager.hide(),
          ),

          // -- Maximize / Restore --
          _HeaderIconButton(
            icon: _isMaximized
                ? Icons.filter_none
                : Icons.crop_square,
            iconSize: _isMaximized ? 14 : 16,
            tooltip: _isMaximized ? 'Restore' : 'Maximize',
            onTap: _toggleMaximize,
          ),

          // -- Close --
          MouseRegion(
            onEnter: (_) => setState(() => _closeHovered = true),
            onExit: (_) => setState(() => _closeHovered = false),
            child: SizedBox(
              width: 36,
              height: 40,
              child: Material(
                color: _closeHovered ? Colors.red : Colors.transparent,
                child: InkWell(
                  onTap: () => windowManager.close(),
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: _closeHovered
                        ? Colors.white
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleMaximize() async {
    if (_isMaximized) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
    if (mounted) setState(() => _isMaximized = !_isMaximized);
  }

  IconData _themeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return Icons.dark_mode;
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.system:
        return Icons.settings_brightness;
    }
  }

  String _themeTooltip(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.system:
        return 'System';
    }
  }

  void _cycleTheme(ThemeMode current) {
    final next = switch (current) {
      ThemeMode.dark => ThemeMode.light,
      ThemeMode.light => ThemeMode.system,
      ThemeMode.system => ThemeMode.dark,
    };
    ref.read(themeProvider.notifier).setTheme(next);
  }
}

/// Small text button used in the header (e.g. language toggle).
class _HeaderTextButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _HeaderTextButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        child: Text(label),
      ),
    );
  }
}

/// Small icon button used in the header (minimize, maximize, theme, etc.).
class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final double iconSize;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.iconSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 40,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: iconSize),
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        splashRadius: 14,
      ),
    );
  }
}
