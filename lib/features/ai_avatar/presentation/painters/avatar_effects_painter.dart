import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../controllers/avatar_frame.dart';
import '../controllers/avatar_motion_controller.dart';

/// Foreground particle layer (Layer 11) rendering sparkles ✦, hearts ♥,
/// sweat drops, "zZ" sleep glyphs, and thinking "…" dots (max 8 active).
class AvatarEffectsPainter extends CustomPainter {
  AvatarEffectsPainter({
    this.motionController,
    this.staticParticles = const [],
    this.staticVersion = 0,
  }) : super(repaint: motionController);

  final AvatarMotionController? motionController;
  final List<AvatarParticle> staticParticles;
  final int staticVersion;

  List<AvatarParticle> get particles =>
      motionController?.particles ?? staticParticles;

  int get version => motionController?.effectsVersion ?? staticVersion;

  final Paint _fillPaint = Paint()..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    if (particles.isEmpty) return;
    final s = size.shortestSide;
    if (s <= 0) return;

    for (final p in particles) {
      final opacity = p.opacity;
      if (opacity <= 0.01) continue;

      final pos = Offset(p.position.dx * s, p.position.dy * s);
      final r = s * 0.055 * p.scale;

      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      if (p.rotation != 0) canvas.rotate(p.rotation);

      switch (p.kind) {
        case AvatarParticleKind.sparkle:
          _drawSparkle(canvas, r, p.color.withValues(alpha: opacity));
        case AvatarParticleKind.heart:
          _drawHeart(canvas, r, p.color.withValues(alpha: opacity));
        case AvatarParticleKind.sweat:
          _drawSweatDrop(canvas, r, p.color.withValues(alpha: opacity));
        case AvatarParticleKind.sleepZ:
          _drawTextGlyph(
            canvas,
            p.label ?? 'zZ',
            (s * 0.105 * p.scale).clamp(8.0, 20.0),
            p.color.withValues(alpha: opacity),
          );
        case AvatarParticleKind.thinkingDot:
          _drawThinkingDots(canvas, r, p.color.withValues(alpha: opacity));
      }

      canvas.restore();
    }
  }

  void _drawSparkle(Canvas canvas, double r, Color color) {
    _fillPaint.color = color;
    final inner = r * 0.28;
    final path = Path()
      ..moveTo(0, -r)
      ..quadraticBezierTo(inner * 0.5, -inner * 0.5, r, 0)
      ..quadraticBezierTo(inner * 0.5, inner * 0.5, 0, r)
      ..quadraticBezierTo(-inner * 0.5, inner * 0.5, -r, 0)
      ..quadraticBezierTo(-inner * 0.5, -inner * 0.5, 0, -r)
      ..close();
    canvas.drawPath(path, _fillPaint);
  }

  void _drawHeart(Canvas canvas, double r, Color color) {
    _fillPaint.color = color;
    final path = Path()
      ..moveTo(0, r * 0.85)
      ..cubicTo(-r * 1.25, r * 0.1, -r * 1.15, -r * 0.95, 0, -r * 0.32)
      ..cubicTo(r * 1.15, -r * 0.95, r * 1.25, r * 0.1, 0, r * 0.85)
      ..close();
    canvas.drawPath(path, _fillPaint);
  }

  void _drawSweatDrop(Canvas canvas, double r, Color color) {
    _fillPaint.color = color;
    final path = Path()
      ..moveTo(0, -r * 1.1)
      ..quadraticBezierTo(r * 0.82, r * 0.15, 0, r * 0.92)
      ..quadraticBezierTo(-r * 0.82, r * 0.15, 0, -r * 1.1)
      ..close();
    canvas.drawPath(path, _fillPaint);

    // Glossy highlight dot
    _fillPaint.color = Colors.white.withValues(alpha: color.a * 0.78);
    canvas.drawCircle(Offset(-r * 0.2, r * 0.15), r * 0.2, _fillPaint);
  }

  void _drawThinkingDots(Canvas canvas, double r, Color color) {
    final dotR = math.max(1.4, r * 0.34);
    for (var i = 0; i < 3; i++) {
      final dx = (i - 1) * dotR * 2.7;
      final alphaScale = 0.55 + (i * 0.22);
      _fillPaint.color = color.withValues(
        alpha: (color.a * alphaScale).clamp(0.0, 1.0),
      );
      canvas.drawCircle(Offset(dx, 0), dotR, _fillPaint);
    }
  }

  void _drawTextGlyph(Canvas canvas, String text, double fontSize, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: color,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant AvatarEffectsPainter oldDelegate) {
    if (motionController != null || oldDelegate.motionController != null) {
      return oldDelegate.motionController != motionController;
    }
    return oldDelegate.version != version ||
        oldDelegate.particles.length != particles.length;
  }
}
