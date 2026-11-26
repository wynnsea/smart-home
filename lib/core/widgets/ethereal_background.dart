import 'dart:math' as math;
import 'dart:ui';

import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';

/// Luminous drifting pastel aurora backdrop engineered so iOS Liquid Glass
/// surfaces visibly refract color, highlights, and depth beneath them.
/// Pauses automatically when Reduce Motion is enabled or app is paused (T5.5, T6.2).
class EtherealBackground extends StatefulWidget {
  const EtherealBackground({
    super.key,
    required this.child,
    this.intenseCenter = false,
  });

  final Widget child;
  final bool intenseCenter;

  @override
  State<EtherealBackground> createState() => _EtherealBackgroundState();
}

class _EtherealBackgroundState extends State<EtherealBackground>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  bool _appPaused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    );
  }

  void _syncAnimation() {
    if (!mounted) return;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (disableAnimations || _appPaused) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appPaused =
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden;
    _syncAnimation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppColors.meshBase),
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value * 2 * math.pi;
              final dx1 = math.sin(t) * 28;
              final dy1 = math.cos(t) * 22;
              final dx2 = math.cos(t + 1.2) * 30;
              final dy2 = math.sin(t + 1.2) * 24;
              final dx3 = math.sin(t + 2.5) * 26;
              final dy3 = math.cos(t + 2.5) * 26;

              return Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    top: -95 + dy1,
                    left: -75 + dx1,
                    child: _GlowBlob(
                      size: 360,
                      color: AppColors.meshLavender.withValues(alpha: 0.92),
                    ),
                  ),
                  Positioned(
                    top: -30 + dy2,
                    right: -95 + dx2,
                    child: _GlowBlob(
                      size: 340,
                      color: AppColors.meshSky.withValues(alpha: 0.90),
                    ),
                  ),
                  Positioned(
                    top: (widget.intenseCenter ? 210 : 275) + dy3,
                    left: -80 + dx3,
                    child: _GlowBlob(
                      size: 330,
                      color: AppColors.meshPeach.withValues(alpha: 0.86),
                    ),
                  ),
                  Positioned(
                    bottom: 80 - dy2,
                    right: -80 + dx1,
                    child: _GlowBlob(
                      size: 310,
                      color: AppColors.meshLilac.withValues(alpha: 0.78),
                    ),
                  ),
                  Positioned(
                    bottom: -95 - dy1,
                    left: 30 - dx2,
                    child: _GlowBlob(
                      size: 340,
                      color: AppColors.meshSky.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        // Subtle silk diffusion so the aurora stays dreamy and smooth
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withValues(alpha: 0.42),
              color.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.54, 1.0],
          ),
        ),
      ),
    );
  }
}
