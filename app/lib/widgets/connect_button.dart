import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/vpn_state.dart';
import '../theme/colors.dart';

/// Large animated connect/disconnect button for the MRVPN dashboard.
///
/// Displays three visual states:
/// - **Disconnected**: Gray border with power icon and "Connect" label.
/// - **Connecting**: Pulsing purple ring animation.
/// - **Connected**: Solid purple gradient with glow and "Connected" label.
///
/// On hover: pointer cursor and an organic, irregular glow effect around the
/// button using the brand gradient colors. The glow is rendered via a
/// lightweight [CustomPainter] with GPU-accelerated blur filters.
class ConnectButton extends StatefulWidget {
  /// Current VPN connection status.
  final VpnStatus status;

  /// Called when the button is tapped.
  final VoidCallback? onTap;

  /// Label text displayed below the button.
  final String label;

  const ConnectButton({
    super.key,
    required this.status,
    required this.label,
    this.onTap,
  });

  @override
  State<ConnectButton> createState() => _ConnectButtonState();
}

class _ConnectButtonState extends State<ConnectButton>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  late final AnimationController _glowCtrl;

  bool get _isConnected => widget.status == VpnStatus.connected;
  bool get _isConnecting => widget.status == VpnStatus.connecting;
  bool get _isDisconnecting => widget.status == VpnStatus.disconnecting;
  bool get _isBusy => _isConnecting || _isDisconnecting;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  void _setHovered(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
    if (value) {
      _glowCtrl.repeat();
    } else {
      _glowCtrl.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MouseRegion(
          cursor: _isBusy ? SystemMouseCursors.basic : SystemMouseCursors.click,
          onEnter: (_) => _setHovered(true),
          onExit: (_) => _setHovered(false),
          child: GestureDetector(
            onTap: _isBusy ? null : widget.onTap,
            child: SizedBox(
              width: 200,
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Hover glow — organic, irregular edges.
                  if (_hovered && !_isBusy)
                    AnimatedBuilder(
                      animation: _glowCtrl,
                      builder: (context, _) {
                        return CustomPaint(
                          size: const Size(200, 200),
                          painter: _OrganicGlowPainter(
                            progress: _glowCtrl.value,
                            colors: _isConnected
                                ? [
                                    AppColors.connected
                                        .withValues(alpha: 0.18),
                                    AppColors.connected
                                        .withValues(alpha: 0.10),
                                  ]
                                : [
                                    AppColors.primary
                                        .withValues(alpha: 0.20),
                                    AppColors.primaryGradientEnd
                                        .withValues(alpha: 0.14),
                                  ],
                          ),
                        );
                      },
                    ),

                  // Outer glow for connected state.
                  if (_isConnected)
                    Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                    )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .fade(
                          begin: 0.6,
                          end: 1.0,
                          duration: 1500.ms,
                          curve: Curves.easeInOut,
                        ),

                  // Pulsing ring for connecting state.
                  if (_isConnecting)
                    Container(
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.5),
                          width: 3,
                        ),
                      ),
                    )
                        .animate(onPlay: (c) => c.repeat())
                        .scale(
                          begin: const Offset(0.85, 0.85),
                          end: const Offset(1.1, 1.1),
                          duration: 1200.ms,
                          curve: Curves.easeOut,
                        )
                        .fadeOut(
                          duration: 1200.ms,
                          curve: Curves.easeOut,
                        ),

                  // Main circular button.
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient:
                          _isConnected ? AppColors.primaryGradient : null,
                      color: _isConnected ? null : Colors.transparent,
                      border: _isConnected
                          ? null
                          : Border.all(
                              color: _isConnecting
                                  ? AppColors.primary
                                  : Colors.grey.shade600,
                              width: 3,
                            ),
                      boxShadow: _isConnected
                          ? [
                              BoxShadow(
                                color:
                                    AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      Icons.power_settings_new_rounded,
                      size: 56,
                      color: _isConnected
                          ? Colors.white
                          : _isConnecting
                              ? AppColors.primary
                              : Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 300),
          style: Theme.of(context).textTheme.titleMedium!.copyWith(
                color: _isConnected
                    ? AppColors.connected
                    : _isConnecting
                        ? AppColors.primary
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
              ),
          child: Text(widget.label),
        ),
      ],
    );
  }
}

/// Paints an organic, irregular glow around the connect button.
///
/// Draws 6 blurred circles whose positions oscillate via sine/cosine at
/// different frequencies, producing a living, plasma-like shimmer. Each circle
/// uses [MaskFilter.blur] which is GPU-composited, making the effect very
/// lightweight even at 60 fps.
class _OrganicGlowPainter extends CustomPainter {
  final double progress;
  final List<Color> colors;

  static const int _blobCount = 6;

  _OrganicGlowPainter({required this.progress, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width * 0.42;
    final phase = progress * 2 * pi;

    for (int i = 0; i < _blobCount; i++) {
      final angle = (i * 2 * pi / _blobCount) + phase * 0.3;

      // Each blob wobbles on a slightly different rhythm.
      final radiusJitter =
          sin(phase * 1.2 + i * 1.7) * 6 + cos(phase * 0.8 + i * 2.3) * 4;
      final dx = cos(angle) * (12 + sin(phase * 0.6 + i) * 5);
      final dy = sin(angle) * (12 + cos(phase * 0.7 + i * 1.4) * 5);

      final t = (i / (_blobCount - 1)).clamp(0.0, 1.0);
      final color = Color.lerp(colors[0], colors[1], t)!;

      final paint = Paint()
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);

      canvas.drawCircle(
        center + Offset(dx, dy),
        baseRadius + radiusJitter,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_OrganicGlowPainter old) => old.progress != progress;
}
