import 'dart:ui';

import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';

/// Authentic iOS 26 Liquid Glass surface with:
/// - Real [BackdropFilter] frosted refraction
/// - Multi-stop translucent glass body (clear center + edge bounce)
/// - Specular gradient rim stroke (bright top-left & bottom-right edge catch)
/// - Delicate inner top sheen highlight
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 26,
    this.blurSigma = 22,
    this.blur = true,
    this.color,
    this.onTap,
    this.borderColor,
    this.tintStrength = 1.0,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double blurSigma;
  final bool blur;
  final Color? color;
  final VoidCallback? onTap;
  final Color? borderColor;
  final double tintStrength;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(borderRadius);
    final topAlpha = (0.64 * tintStrength).clamp(0.18, 0.90);
    final midAlpha = (0.34 * tintStrength).clamp(0.12, 0.80);
    final botAlpha = (0.50 * tintStrength).clamp(0.16, 0.85);

    final innerContent = CustomPaint(
      foregroundPainter: _LiquidGlassRimPainter(
        borderRadius: borderRadius,
        accentBorder: borderColor,
        isDark: isDark,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: color != null
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color!.withValues(alpha: blur ? 0.78 : 0.92),
                    color!.withValues(alpha: blur ? 0.56 : 0.86),
                  ],
                )
              : isDark
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: blur
                      ? [
                          const Color(0xFF232845).withValues(alpha: 0.72),
                          const Color(0xFF171B32).withValues(alpha: 0.58),
                          const Color(0xFF1E223D).withValues(alpha: 0.68),
                        ]
                      : [
                          const Color(0xFF212642).withValues(alpha: 0.92),
                          const Color(0xFF181C33).withValues(alpha: 0.94),
                        ],
                )
              : blur
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: topAlpha),
                    Colors.white.withValues(alpha: midAlpha),
                    Colors.white.withValues(alpha: botAlpha),
                  ],
                  stops: const [0.0, 0.52, 1.0],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.92),
                    AppColors.surfaceCardStrong,
                    Colors.white.withValues(alpha: 0.86),
                  ],
                ),
        ),
        child: Stack(
          children: [
            // Subtle top inner glass specular reflection
            Positioned(
              top: 0,
              left: borderRadius * 0.65,
              right: borderRadius * 0.65,
              height: 1.5,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.0),
                      Colors.white.withValues(alpha: isDark ? 0.28 : 0.92),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: padding,
              child: child,
            ),
          ],
        ),
      ),
    );

    final glassBody = ClipRRect(
      borderRadius: radius,
      child: blur
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: innerContent,
            )
          : innerContent,
    );

    final framed = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5D46B8).withValues(alpha: 0.09),
            blurRadius: 26,
            spreadRadius: -2,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: glassBody,
    );

    if (onTap == null) return framed;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: framed,
    );
  }
}

/// Unified iOS 26 Liquid Glass Pill Container (ideal for grouped top bar controls
/// and floating dock shells).
class LiquidGlassPill extends StatelessWidget {
  const LiquidGlassPill({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    this.height,
    this.blurSigma = 26,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? height;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : const Color(0xFF5A45B5))
                .withValues(alpha: isDark ? 0.35 : 0.13),
            blurRadius: 24,
            spreadRadius: -2,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: CustomPaint(
            foregroundPainter: _LiquidGlassRimPainter(
              borderRadius: 999,
              strokeWidth: 1.5,
              isDark: isDark,
            ),
            child: Container(
              height: height,
              padding: padding,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          const Color(0xFF232846).withValues(alpha: 0.78),
                          const Color(0xFF171B32).withValues(alpha: 0.66),
                          const Color(0xFF1E233E).withValues(alpha: 0.74),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.66),
                          Colors.white.withValues(alpha: 0.36),
                          Colors.white.withValues(alpha: 0.56),
                        ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular iPhone Liquid Glass action button with specular rim, required tooltip,
/// Semantics label, and >= 48px accessible hit target.
class GlassCircleButton extends StatelessWidget {
  const GlassCircleButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.size = 42,
    this.badgeText,
    this.iconColor,
    this.blur = true,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final double size;
  final String? badgeText;
  final Color? iconColor;
  final bool blur;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final semanticLabel = badgeText != null && badgeText!.isNotEmpty
        ? '$tooltip, $badgeText'
        : tooltip;

    final circleBody = CustomPaint(
      foregroundPainter: _LiquidGlassRimPainter(
        borderRadius: size / 2,
        strokeWidth: 1.4,
        isDark: isDark,
      ),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF252B49).withValues(alpha: blur ? 0.78 : 0.94),
                    const Color(0xFF191D34).withValues(alpha: blur ? 0.64 : 0.90),
                  ]
                : blur
                ? [
                    Colors.white.withValues(alpha: 0.72),
                    Colors.white.withValues(alpha: 0.36),
                    Colors.white.withValues(alpha: 0.58),
                  ]
                : [
                    Colors.white.withValues(alpha: 0.92),
                    AppColors.surfaceCardStrong,
                  ],
          ),
        ),
        child: Icon(
          icon,
          size: 19,
          color:
              iconColor ??
              (isDark ? const Color(0xFFF2F3FF) : AppColors.textPrimary),
        ),
      ),
    );

    final button = Semantics(
      button: true,
      label: semanticLabel,
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF5D46B8).withValues(
                            alpha: 0.11,
                          ),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: blur
                          ? BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                              child: circleBody,
                            )
                          : circleBody,
                    ),
                  ),
                  if (badgeText != null && badgeText!.isNotEmpty)
                    Positioned(
                      top: -3,
                      right: -3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5.5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: Colors.white, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          badgeText!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return button;
  }
}

/// Paints the directional specular glass rim highlight (bright top-left &
/// bottom-right light catch, translucent cool tint on opposing sides).
class _LiquidGlassRimPainter extends CustomPainter {
  const _LiquidGlassRimPainter({
    required this.borderRadius,
    this.strokeWidth = 1.35,
    this.accentBorder,
    this.isDark = false,
  });

  final double borderRadius;
  final double strokeWidth;
  final Color? accentBorder;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final clampedRadius = borderRadius.clamp(0.0, size.shortestSide / 2);
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      Radius.circular(clampedRadius),
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: accentBorder != null
            ? [
                Colors.white.withValues(alpha: isDark ? 0.45 : 0.95),
                accentBorder!.withValues(alpha: isDark ? 0.72 : 0.55),
                Colors.white.withValues(alpha: isDark ? 0.35 : 0.85),
              ]
            : isDark
            ? [
                Colors.white.withValues(alpha: 0.28),
                const Color(0xFF9E7BFF).withValues(alpha: 0.14),
                Colors.white.withValues(alpha: 0.06),
                Colors.white.withValues(alpha: 0.22),
              ]
            : [
                Colors.white.withValues(alpha: 0.95),
                const Color(0xFFB5CCFF).withValues(alpha: 0.25),
                Colors.white.withValues(alpha: 0.22),
                Colors.white.withValues(alpha: 0.85),
              ],
        stops: accentBorder != null
            ? const [0.0, 0.5, 1.0]
            : const [0.0, 0.35, 0.68, 1.0],
      ).createShader(rect);

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _LiquidGlassRimPainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.accentBorder != accentBorder ||
        oldDelegate.isDark != isDark;
  }
}
