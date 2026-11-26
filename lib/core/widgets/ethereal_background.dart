import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';

/// Soft pastel / midnight aurora backdrop engineered for zero-jank 60fps
/// scrolling on mid-range Android GPUs (single cached RepaintBoundary,
/// zero full-screen BackdropFilter blur pass, zero idle ticker repaints).
class EtherealBackground extends StatelessWidget {
  const EtherealBackground({
    super.key,
    required this.child,
    this.intenseCenter = false,
  });

  final Widget child;
  final bool intenseCenter;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF0D1021) : AppColors.meshBase;
    final blob1 = isDark
        ? const Color(0xFF3E2A78).withValues(alpha: 0.65)
        : AppColors.meshLavender.withValues(alpha: 0.82);
    final blob2 = isDark
        ? const Color(0xFF1A3A6E).withValues(alpha: 0.62)
        : AppColors.meshSky.withValues(alpha: 0.80);
    final blob3 = isDark
        ? const Color(0xFF4B245C).withValues(alpha: 0.48)
        : AppColors.meshPeach.withValues(alpha: 0.76);
    final blob4 = isDark
        ? const Color(0xFF28205F).withValues(alpha: 0.56)
        : AppColors.meshLilac.withValues(alpha: 0.70);
    final blob5 = isDark
        ? const Color(0xFF153757).withValues(alpha: 0.52)
        : AppColors.meshSky.withValues(alpha: 0.64);

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: baseColor),
        RepaintBoundary(
          child: IgnorePointer(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  top: -95,
                  left: -75,
                  child: _GlowBlob(size: 380, color: blob1),
                ),
                Positioned(
                  top: -30,
                  right: -95,
                  child: _GlowBlob(size: 360, color: blob2),
                ),
                Positioned(
                  top: intenseCenter ? 210 : 275,
                  left: -80,
                  child: _GlowBlob(size: 350, color: blob3),
                ),
                Positioned(
                  bottom: 80,
                  right: -80,
                  child: _GlowBlob(size: 330, color: blob4),
                ),
                Positioned(
                  bottom: -95,
                  left: 30,
                  child: _GlowBlob(size: 360, color: blob5),
                ),
              ],
            ),
          ),
        ),
        child,
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
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            color.withValues(alpha: 0.36),
            color.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.48, 1.0],
        ),
      ),
    );
  }
}
