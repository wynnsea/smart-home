import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/avatar_expression.dart';
import '../../domain/avatar_mood.dart';
import '../controllers/avatar_frame.dart';
import '../controllers/avatar_motion_controller.dart';

/// 3D soft-clay / matte toy procedural CustomPainter for "Wynn" v2 —
/// original chibi anime girl with messy brown side bun, swept curtain bangs,
/// oversized lavender hoodie, glossy anime eyes, bouncy ahoge, and glowing
/// star hair clip. Zero black outlines; all depth via soft gradients & rim light.
class ChibiBodyPainter extends CustomPainter {
  ChibiBodyPainter({
    this.motionController,
    this.staticExpression,
    this.staticFrame,
    required this.avatarSize,
    this.poseMode = AvatarPoseMode.standing,
  }) : super(repaint: motionController);

  final AvatarMotionController? motionController;
  final AvatarExpression? staticExpression;
  final AvatarFrame? staticFrame;
  final AvatarSize avatarSize;
  final AvatarPoseMode poseMode;

  AvatarExpression get expression =>
      motionController?.expression ??
      staticExpression ??
      kMoodExpressions[AvatarMood.idle]!;

  AvatarFrame get frame =>
      motionController?.frame ??
      staticFrame ??
      AvatarFrame.staticForPose(
        expression.armPose,
        headTilt: expression.headTilt,
      );

  // Reusable Paint instances (zero per-frame allocations in paint())
  final Paint _shadowPaint = Paint()
    ..style = PaintingStyle.fill
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
  final Paint _fillPaint = Paint()..style = PaintingStyle.fill;
  final Paint _shadePaint = Paint()..style = PaintingStyle.fill;
  final Paint _rimPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..color = Colors.white.withValues(alpha: 0.26);
  final Paint _strokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final Paint _blushPaint = Paint()..style = PaintingStyle.fill;
  final Paint _glowPaint = Paint()..style = PaintingStyle.fill;

  // Cached size-dependent shaders
  Size? _cachedSize;
  Shader? _hairBackShader;
  Shader? _bunShader;
  Shader? _bangsShader;
  Shader? _hoodieShader;
  Shader? _hoodieShadeShader;
  Shader? _faceShader;
  Shader? _irisShader;
  Shader? _skinHandShader;

  void _ensureShaders(Size size) {
    if (_cachedSize == size) return;
    _cachedSize = size;
    final s = size.shortestSide;

    _hairBackShader = const RadialGradient(
      center: Alignment(-0.35, -0.45),
      radius: 1.05,
      colors: [
        AppColors.avatarHairHighlight,
        AppColors.avatarHair,
        AppColors.avatarHairShade,
      ],
      stops: [0.0, 0.52, 1.0],
    ).createShader(Rect.fromLTWH(s * 0.14, s * 0.12, s * 0.72, s * 0.72));

    _bunShader = const RadialGradient(
      center: Alignment(-0.4, -0.45),
      radius: 0.95,
      colors: [
        AppColors.avatarHairHighlight,
        AppColors.avatarHair,
        AppColors.avatarHairShade,
      ],
      stops: [0.0, 0.55, 1.0],
    ).createShader(
      Rect.fromCircle(center: Offset(s * 0.34, s * 0.15), radius: s * 0.16),
    );

    _bangsShader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        AppColors.avatarHairHighlight,
        AppColors.avatarHair,
        AppColors.avatarHairShade,
      ],
      stops: [0.0, 0.55, 1.0],
    ).createShader(Rect.fromLTWH(s * 0.16, s * 0.10, s * 0.68, s * 0.56));

    _hoodieShader = const RadialGradient(
      center: Alignment(-0.45, -0.55),
      radius: 1.15,
      colors: [
        AppColors.avatarHoodLight,
        AppColors.avatarHood,
        AppColors.avatarHoodDark,
      ],
      stops: [0.0, 0.62, 1.0],
    ).createShader(Rect.fromLTWH(s * 0.12, s * 0.58, s * 0.76, s * 0.42));

    _hoodieShadeShader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        AppColors.avatarHoodDark.withValues(alpha: 0.28),
        AppColors.avatarHoodDark.withValues(alpha: 0.0),
      ],
    ).createShader(Rect.fromLTWH(s * 0.25, s * 0.60, s * 0.50, s * 0.16));

    _faceShader = const RadialGradient(
      center: Alignment(-0.32, -0.38),
      radius: 0.96,
      colors: [
        Color(0xFFFFF0E6),
        AppColors.avatarSkin,
        AppColors.avatarSkinShade,
      ],
      stops: [0.0, 0.56, 1.0],
    ).createShader(
      Rect.fromCenter(
        center: Offset(s * 0.50, s * 0.41),
        width: s * 0.56,
        height: s * 0.52,
      ),
    );

    _irisShader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        AppColors.avatarHairShade,
        AppColors.avatarIris,
        AppColors.avatarIrisLight,
      ],
      stops: [0.0, 0.45, 1.0],
    ).createShader(Rect.fromLTWH(0, -s * 0.06, s * 0.10, s * 0.12));

    _skinHandShader = const RadialGradient(
      center: Alignment(-0.35, -0.4),
      radius: 0.95,
      colors: [
        Color(0xFFFFEFE5),
        AppColors.avatarSkin,
        AppColors.avatarSkinShade,
      ],
      stops: [0.0, 0.62, 1.0],
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: s * 0.095));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (s <= 0) return;

    _ensureShaders(size);
    final sway = avatarSize.swayHair ? frame.hairSwayOffset : Offset.zero;

    canvas.save();
    if (poseMode == AvatarPoseMode.peek || avatarSize == AvatarSize.xs) {
      canvas.clipRect(Rect.fromLTWH(-s * 0.12, -s * 0.12, s * 1.24, s * 1.12));
    }
    _applyFraming(canvas, s);

    // 1. Contact shadow (standing only, omitted in xs bust close-up & peek)
    if (poseMode == AvatarPoseMode.standing && avatarSize != AvatarSize.xs) {
      _drawContactShadow(canvas, s);
    }

    // Body root transform: float, shake, squash/stretch, breathing
    final bodyPivot = Offset(s * 0.50, s * 0.78);
    canvas.save();
    canvas.translate(frame.shakeX * s, frame.floatY * s);
    canvas.translate(bodyPivot.dx, bodyPivot.dy);
    canvas.scale(
      frame.squashX * frame.bodyScale,
      frame.squashY * frame.breatheScaleY * frame.bodyScale,
    );
    canvas.translate(-bodyPivot.dx, -bodyPivot.dy);

    // 2. Back hair & 3. High messy side bun (drawn behind body/shoulders)
    final headPivot = Offset(s * 0.50, s * 0.58);
    canvas.save();
    canvas.translate(headPivot.dx, headPivot.dy);
    canvas.rotate(frame.headTiltZ);
    canvas.translate(-headPivot.dx, -headPivot.dy);
    _drawHairBack(canvas, s, sway);
    _drawBun(canvas, s, sway);
    canvas.restore();

    // 4. Hoodie body (clipped softly at bottom edge when peeking over a card)
    _drawBody(canvas, s);

    // 5..14. Head & facial stack rotated around neck pivot
    canvas.save();
    canvas.translate(headPivot.dx, headPivot.dy);
    canvas.rotate(frame.headTiltZ);
    canvas.translate(-headPivot.dx, -headPivot.dy);

    _drawNeckAndEars(canvas, s);
    _drawFace(canvas, s);
    _drawBlush(canvas, s);
    _drawEyes(canvas, s);
    _drawBrows(canvas, s);
    _drawNose(canvas, s);
    _drawMouth(canvas, s);
    _drawBangs(canvas, s, sway);
    _drawAhogeAndClip(canvas, s, sway);

    canvas.restore();

    // 15. Arms & chunky lavender hoodie cuffs
    _drawArms(canvas, s);

    canvas.restore();
    canvas.restore();
  }

  /// Framing per size (§2.8): `xs` bust close-up (~90% head), `sm` head+shoulders,
  /// `md`/`lg` full half-body.
  void _applyFraming(Canvas canvas, double s) {
    switch (avatarSize) {
      case AvatarSize.xs:
        const scale = 1.48;
        canvas.translate(s * 0.50, s * 0.52);
        canvas.scale(scale, scale);
        canvas.translate(-s * 0.50, -s * 0.41);
      case AvatarSize.sm:
        final scale = poseMode == AvatarPoseMode.peek ? 1.08 : 1.18;
        final focusY = poseMode == AvatarPoseMode.peek ? 0.50 : 0.46;
        canvas.translate(s * 0.50, s * 0.51);
        canvas.scale(scale, scale);
        canvas.translate(-s * 0.50, -s * focusY);
      case AvatarSize.md:
      case AvatarSize.lg:
        break;
    }
  }

  void _drawContactShadow(Canvas canvas, double s) {
    final lift = (-frame.floatY).clamp(-0.04, 0.06);
    final shadowScale = (1.0 - lift * 3.0).clamp(0.76, 1.12);
    final shadowAlpha = (0.14 - lift * 0.7).clamp(0.07, 0.18);
    _shadowPaint.color = AppColors.avatarInk.withValues(alpha: shadowAlpha);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(s * 0.50 + frame.shakeX * s * 0.4, s * 0.955),
        width: s * 0.62 * shadowScale,
        height: s * 0.075 * shadowScale,
      ),
      _shadowPaint,
    );
  }

  void _drawHairBack(Canvas canvas, double s, Offset sway) {
    final pivot = Offset(s * 0.50, s * 0.28);
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(-sway.dx * 1.0);
    canvas.translate(-pivot.dx, -pivot.dy + sway.dy * s * 0.35);

    final path = Path()
      ..moveTo(s * 0.21, s * 0.36)
      ..cubicTo(s * 0.17, s * 0.20, s * 0.32, s * 0.11, s * 0.50, s * 0.12)
      ..cubicTo(s * 0.69, s * 0.11, s * 0.83, s * 0.21, s * 0.79, s * 0.38)
      ..cubicTo(s * 0.82, s * 0.52, s * 0.81, s * 0.67, s * 0.73, s * 0.73)
      ..quadraticBezierTo(s * 0.64, s * 0.78, s * 0.55, s * 0.72)
      ..quadraticBezierTo(s * 0.48, s * 0.77, s * 0.40, s * 0.72)
      ..quadraticBezierTo(s * 0.28, s * 0.77, s * 0.22, s * 0.67)
      ..cubicTo(s * 0.17, s * 0.57, s * 0.19, s * 0.46, s * 0.21, s * 0.36)
      ..close();

    _fillPaint
      ..shader = _hairBackShader
      ..color = AppColors.avatarHair;
    canvas.drawPath(path, _fillPaint);
    _fillPaint.shader = null;

    // Subtle soft white top-left rim light on crown
    _rimPaint.strokeWidth = (s * 0.014).clamp(0.8, 2.6);
    final rimPath = Path()
      ..moveTo(s * 0.24, s * 0.31)
      ..quadraticBezierTo(s * 0.29, s * 0.16, s * 0.47, s * 0.14);
    canvas.drawPath(rimPath, _rimPaint);

    canvas.restore();
  }

  void _drawBun(Canvas canvas, double s, Offset sway) {
    final basePivot = Offset(s * 0.38, s * 0.21);
    canvas.save();
    canvas.translate(basePivot.dx, basePivot.dy);
    canvas.rotate(-sway.dx * 0.7);
    canvas.translate(-basePivot.dx, -basePivot.dy + sway.dy * s * 0.28);

    // Messy loose wisps flicking playfully off the bun
    _strokePaint
      ..color = AppColors.avatarHair
      ..strokeWidth = (s * 0.022).clamp(1.2, 4.0);
    final wispLeft = Path()
      ..moveTo(s * 0.25, s * 0.18)
      ..quadraticBezierTo(s * 0.15, s * 0.17, s * 0.15, s * 0.09);
    canvas.drawPath(wispLeft, _strokePaint);

    _strokePaint.strokeWidth = (s * 0.016).clamp(0.9, 3.0);
    final wispTop = Path()
      ..moveTo(s * 0.33, s * 0.07)
      ..quadraticBezierTo(s * 0.38, s * 0.02, s * 0.44, s * 0.05);
    canvas.drawPath(wispTop, _strokePaint);

    // Main sculpted clay bun silhouette (oval tilted slightly left)
    canvas.save();
    canvas.translate(s * 0.33, s * 0.145);
    canvas.rotate(-0.34);
    final bunRect = Rect.fromCenter(
      center: Offset.zero,
      width: s * 0.27,
      height: s * 0.21,
    );
    _fillPaint
      ..shader = _bunShader
      ..color = AppColors.avatarHair;
    canvas.drawOval(bunRect, _fillPaint);
    _fillPaint.shader = null;

    // Sculpted clay hair coil grooves (soft darker brown + light sheen bands)
    _strokePaint
      ..color = AppColors.avatarHairShade.withValues(alpha: 0.45)
      ..strokeWidth = (s * 0.015).clamp(0.8, 2.8);
    canvas.drawArc(
      bunRect.deflate(s * 0.028),
      -math.pi * 0.85,
      math.pi * 0.95,
      false,
      _strokePaint,
    );
    canvas.drawArc(
      bunRect.deflate(s * 0.055),
      math.pi * 0.12,
      math.pi * 0.72,
      false,
      _strokePaint,
    );

    _strokePaint
      ..color = AppColors.avatarHairHighlight.withValues(alpha: 0.55)
      ..strokeWidth = (s * 0.016).clamp(0.8, 3.0);
    canvas.drawArc(
      bunRect.deflate(s * 0.036),
      -math.pi * 0.78,
      math.pi * 0.52,
      false,
      _strokePaint,
    );
    canvas.restore();

    canvas.restore();
  }

  void _drawBody(Canvas canvas, double s) {
    final isPeek = poseMode == AvatarPoseMode.peek;
    final bottomY = isPeek ? s * 0.87 : s * 0.94;
    if (isPeek) {
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(0, 0, s, s * 0.865));
    }
    // Back hood collar rim hugging shoulders
    final hoodRim = Path()
      ..moveTo(s * 0.22, s * 0.68)
      ..quadraticBezierTo(s * 0.30, s * 0.56, s * 0.50, s * 0.58)
      ..quadraticBezierTo(s * 0.70, s * 0.56, s * 0.78, s * 0.68)
      ..quadraticBezierTo(s * 0.64, s * 0.75, s * 0.50, s * 0.74)
      ..quadraticBezierTo(s * 0.36, s * 0.75, s * 0.22, s * 0.68)
      ..close();
    _fillPaint
      ..shader = _hoodieShader
      ..color = AppColors.avatarHood;
    canvas.drawPath(hoodRim, _fillPaint);

    // Main oversized lavender hoodie torso (shoulder width ~0.62s)
    final torso = Path()
      ..moveTo(s * 0.19, bottomY)
      ..cubicTo(s * 0.18, s * 0.76, s * 0.23, s * 0.63, s * 0.36, s * 0.61)
      ..lineTo(s * 0.64, s * 0.61)
      ..cubicTo(s * 0.77, s * 0.63, s * 0.82, s * 0.76, s * 0.81, bottomY)
      ..quadraticBezierTo(s * 0.50, bottomY + s * 0.03, s * 0.19, bottomY)
      ..close();
    canvas.drawPath(torso, _fillPaint);
    _fillPaint.shader = null;

    // Soft cast shadow under chin onto hoodie collar
    _shadePaint.shader = _hoodieShadeShader;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(s * 0.50, s * 0.65),
        width: s * 0.34,
        height: s * 0.12,
      ),
      _shadePaint,
    );
    _shadePaint.shader = null;

    // Rounded sculpted hoodie collar folds (V-overlap like reference photo)
    _strokePaint
      ..color = AppColors.avatarHoodDark.withValues(alpha: 0.42)
      ..strokeWidth = (s * 0.016).clamp(1.0, 3.0);
    final collarFold = Path()
      ..moveTo(s * 0.37, s * 0.62)
      ..quadraticBezierTo(s * 0.47, s * 0.72, s * 0.53, s * 0.72)
      ..quadraticBezierTo(s * 0.58, s * 0.69, s * 0.63, s * 0.62);
    canvas.drawPath(collarFold, _strokePaint);

    // Two white hoodie drawstrings with cute rounded bead ends
    if (avatarSize != AvatarSize.xs) {
      _strokePaint
        ..color = Colors.white.withValues(alpha: 0.92)
        ..strokeWidth = (s * 0.014).clamp(1.0, 2.8);
      final leftString = Path()
        ..moveTo(s * 0.455, s * 0.695)
        ..quadraticBezierTo(s * 0.435, s * 0.76, s * 0.445, s * 0.815);
      final rightString = Path()
        ..moveTo(s * 0.545, s * 0.695)
        ..quadraticBezierTo(s * 0.565, s * 0.76, s * 0.555, s * 0.815);
      canvas.drawPath(leftString, _strokePaint);
      canvas.drawPath(rightString, _strokePaint);

      _fillPaint.color = Colors.white.withValues(alpha: 0.96);
      canvas.drawCircle(Offset(s * 0.445, s * 0.822), s * 0.014, _fillPaint);
      canvas.drawCircle(Offset(s * 0.555, s * 0.822), s * 0.014, _fillPaint);
    }

    // Left shoulder white rim light
    _rimPaint.strokeWidth = (s * 0.014).clamp(0.8, 2.4);
    final leftRim = Path()
      ..moveTo(s * 0.21, s * 0.86)
      ..quadraticBezierTo(s * 0.20, s * 0.70, s * 0.30, s * 0.63);
    canvas.drawPath(leftRim, _rimPaint);

    if (isPeek) {
      canvas.restore();
    }
  }

  void _drawNeckAndEars(Canvas canvas, double s) {
    // Short shaded clay neck
    _fillPaint.color = AppColors.avatarSkinShade;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(s * 0.50, s * 0.635),
          width: s * 0.13,
          height: s * 0.10,
        ),
        Radius.circular(s * 0.05),
      ),
      _fillPaint,
    );

    // Cute rounded small ears peeking below side hair
    for (final side in [-1.0, 1.0]) {
      final earCenter = Offset(s * (0.50 + side * 0.272), s * 0.475);
      _fillPaint.color = AppColors.avatarSkin;
      canvas.drawOval(
        Rect.fromCenter(
          center: earCenter,
          width: s * 0.088,
          height: s * 0.105,
        ),
        _fillPaint,
      );
      _fillPaint.color = AppColors.avatarSkinShade.withValues(alpha: 0.85);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(earCenter.dx - side * s * 0.006, earCenter.dy + s * 0.004),
          width: s * 0.044,
          height: s * 0.058,
        ),
        _fillPaint,
      );
    }
  }

  void _drawFace(Canvas canvas, double s) {
    // Plump soft-chin chibi face oval: width 0.54s (rx=0.27s), height 0.50s (ry=0.25s)
    // centered around (0.50s, 0.40s) with fuller soft cheeks
    final facePath = Path()
      ..moveTo(s * 0.50, s * 0.15)
      ..cubicTo(s * 0.68, s * 0.15, s * 0.775, s * 0.27, s * 0.772, s * 0.43)
      ..cubicTo(s * 0.770, s * 0.56, s * 0.665, s * 0.652, s * 0.50, s * 0.652)
      ..cubicTo(s * 0.335, s * 0.652, s * 0.230, s * 0.56, s * 0.228, s * 0.43)
      ..cubicTo(s * 0.225, s * 0.27, s * 0.32, s * 0.15, s * 0.50, s * 0.15)
      ..close();

    _fillPaint
      ..shader = _faceShader
      ..color = AppColors.avatarSkin;
    canvas.drawPath(facePath, _fillPaint);
    _fillPaint.shader = null;

    // Soft ambient occlusion cast shadow beneath swept bangs
    canvas.save();
    canvas.clipPath(facePath);
    _fillPaint.color = AppColors.avatarSkinShade.withValues(alpha: 0.45);
    final bangsShadow = Path()
      ..moveTo(s * 0.20, s * 0.16)
      ..lineTo(s * 0.80, s * 0.16)
      ..lineTo(s * 0.80, s * 0.35)
      ..quadraticBezierTo(s * 0.66, s * 0.31, s * 0.50, s * 0.26)
      ..quadraticBezierTo(s * 0.34, s * 0.31, s * 0.20, s * 0.35)
      ..close();
    canvas.drawPath(bangsShadow, _fillPaint);

    // Subtle soft clay forehead sheen
    _fillPaint.color = Colors.white.withValues(alpha: 0.22);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(s * 0.45, s * 0.30),
        width: s * 0.16,
        height: s * 0.08,
      ),
      _fillPaint,
    );
    canvas.restore();

    // Soft left cheek rim light
    _rimPaint.strokeWidth = (s * 0.012).clamp(0.7, 2.2);
    final cheekRim = Path()
      ..moveTo(s * 0.245, s * 0.47)
      ..quadraticBezierTo(s * 0.255, s * 0.57, s * 0.35, s * 0.625);
    canvas.drawPath(cheekRim, _rimPaint);
  }

  void _drawBlush(Canvas canvas, double s) {
    final intensity = expression.blush.clamp(0.0, 1.0);
    if (intensity <= 0.02) return;

    final sigma = (s * 0.032).clamp(1.2, 5.5);
    _blushPaint
      ..color = AppColors.avatarBlush.withValues(alpha: 0.62 * intensity)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma);

    final leftCenter = Offset(s * 0.335, s * 0.52);
    final rightCenter = Offset(s * 0.665, s * 0.52);
    canvas.drawOval(
      Rect.fromCenter(center: leftCenter, width: s * 0.135, height: s * 0.072),
      _blushPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: rightCenter, width: s * 0.135, height: s * 0.072),
      _blushPaint,
    );
    _blushPaint.maskFilter = null;

    // Anime diagonal blush hatch lines when blush > 0.6 (§2.2)
    if (intensity > 0.6 && avatarSize != AvatarSize.xs) {
      final lineAlpha = ((intensity - 0.6) / 0.4).clamp(0.0, 1.0) * 0.65;
      _strokePaint
        ..color = AppColors.avatarTongue.withValues(alpha: lineAlpha)
        ..strokeWidth = (s * 0.0085).clamp(0.7, 1.6);
      for (final cx in [s * 0.335, s * 0.665]) {
        for (var i = -1; i <= 1; i++) {
          final dx = cx + i * s * 0.024;
          canvas.drawLine(
            Offset(dx - s * 0.008, s * 0.532),
            Offset(dx + s * 0.008, s * 0.506),
            _strokePaint,
          );
        }
      }
    }
  }

  void _drawEyes(Canvas canvas, double s) {
    final effectiveOpen = (expression.eyeOpen * (1.0 - frame.blinkAmount))
        .clamp(0.0, 1.0);
    final leftCenter = Offset(s * 0.40, s * 0.44);
    final rightCenter = Offset(s * 0.60, s * 0.44);

    _drawSingleEye(
      canvas,
      s,
      center: leftCenter,
      isViewerLeft: true,
      effectiveOpen: effectiveOpen,
    );
    _drawSingleEye(
      canvas,
      s,
      center: rightCenter,
      isViewerLeft: false,
      effectiveOpen: effectiveOpen,
    );
  }

  void _drawSingleEye(
    Canvas canvas,
    double s, {
    required Offset center,
    required bool isViewerLeft,
    required double effectiveOpen,
  }) {
    final strokeW = (s * 0.022).clamp(1.4, 4.2);
    final outerDir = isViewerLeft ? -1.0 : 1.0;

    // 1. Happy ^ ^ arch
    if (expression.eyeShape == EyeShape.happy) {
      _drawCurvedClosedEye(canvas, s, center, strokeW, outerDir, happyUp: true);
      return;
    }

    // 2. Wink right (anatomical right eye = viewer's left eye, matching reference!)
    if (expression.winkRight && isViewerLeft) {
      _drawCurvedClosedEye(canvas, s, center, strokeW, outerDir, happyUp: true);
      return;
    }

    // 3. Squeeze > <
    if (expression.eyeShape == EyeShape.squeeze) {
      _strokePaint
        ..color = AppColors.avatarHairShade
        ..strokeWidth = strokeW;
      final rx = s * 0.046;
      final ry = s * 0.036;
      final path = Path();
      if (isViewerLeft) {
        path
          ..moveTo(center.dx - rx, center.dy - ry)
          ..lineTo(center.dx + rx * 0.65, center.dy)
          ..lineTo(center.dx - rx, center.dy + ry);
      } else {
        path
          ..moveTo(center.dx + rx, center.dy - ry)
          ..lineTo(center.dx - rx * 0.65, center.dy)
          ..lineTo(center.dx + rx, center.dy + ry);
      }
      canvas.drawPath(path, _strokePaint);
      return;
    }

    // 4. Fully closed / blink bottom curve
    if (effectiveOpen < 0.09) {
      _drawCurvedClosedEye(canvas, s, center, strokeW, outerDir, happyUp: false);
      return;
    }

    // 5. Open anime eye (§2.3): sclera + clipped vertical-gradient iris + pupil +
    //    30%-lag wet specular highlights + thick upper lash line + 2 outer lashes
    final isWide = expression.eyeShape == EyeShape.wide;
    final eyeW = s * 0.104 * (isWide ? 1.15 : 1.0);
    final eyeH = s * 0.132 * (isWide ? 1.15 : 1.0);
    final scleraRect = Rect.fromCenter(center: center, width: eyeW, height: eyeH);
    final scleraPath = Path()..addOval(scleraRect);

    // Upper eyelid vertical clip for half-closed / sleepy / blinking eyes
    final lidTopY = lerpDouble(
      scleraRect.bottom - eyeH * 0.12,
      scleraRect.top - s * 0.015,
      effectiveOpen,
    )!;

    canvas.save();
    canvas.clipRect(
      Rect.fromLTRB(
        scleraRect.left - s * 0.04,
        lidTopY,
        scleraRect.right + s * 0.04,
        scleraRect.bottom + s * 0.04,
      ),
    );

    // White sclera with subtle cool-grey top inner shadow
    _fillPaint.color = const Color(0xFFFFFCFA);
    canvas.drawPath(scleraPath, _fillPaint);

    // Clip iris & highlights inside sclera
    canvas.save();
    canvas.clipPath(scleraPath);

    final gazeShift = Offset(
      (frame.pupilOffset.dx * s * 0.92).clamp(-eyeW * 0.24, eyeW * 0.24),
      (frame.pupilOffset.dy * s * 0.92).clamp(-eyeH * 0.22, eyeH * 0.22),
    );
    final irisScale = isWide ? 0.85 : 1.0;
    final irisW = eyeW * 0.78 * irisScale;
    final irisH = eyeH * 0.76 * irisScale;
    final irisCenter = center + gazeShift + Offset(0, eyeH * 0.03);

    // Glossy brown iris gradient
    canvas.save();
    canvas.translate(irisCenter.dx, irisCenter.dy);
    _fillPaint
      ..shader = _irisShader
      ..color = AppColors.avatarIris;
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: irisW, height: irisH),
      _fillPaint,
    );
    _fillPaint.shader = null;

    // Warm golden-amber lower iris inner glow
    _fillPaint.color = AppColors.avatarIrisLight.withValues(alpha: 0.45);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, irisH * 0.24),
        width: irisW * 0.64,
        height: irisH * 0.30,
      ),
      _fillPaint,
    );

    // Dark pupil
    _fillPaint.color = AppColors.avatarInk;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, irisH * 0.02),
        width: irisW * 0.46,
        height: irisH * 0.48,
      ),
      _fillPaint,
    );
    canvas.restore();

    // Wet specular highlights (shift only 30% of gazeShift per §2.3!)
    final specShift = gazeShift * 0.30;
    final specBoost = isWide ? 1.18 : 1.0;
    _fillPaint.color = Colors.white.withValues(alpha: 0.95);
    canvas.drawOval(
      Rect.fromCenter(
        center:
            center +
            specShift +
            Offset(-irisW * 0.24, -irisH * 0.22),
        width: irisW * 0.34 * specBoost,
        height: irisH * 0.28 * specBoost,
      ),
      _fillPaint,
    );
    canvas.drawCircle(
      center + specShift + Offset(irisW * 0.22, irisH * 0.24),
      irisW * 0.12 * specBoost,
      _fillPaint,
    );

    canvas.restore(); // sclera clip
    canvas.restore(); // eyelid clip

    // Thick sculpted upper lash line hugging eyelid curve + 2 cute outer lashes
    final lashY = math.max(scleraRect.top + eyeH * 0.04, lidTopY + s * 0.004);
    final archLift = eyeH * 0.16 * effectiveOpen;
    _strokePaint
      ..color = AppColors.avatarHairShade
      ..strokeWidth = (s * 0.023).clamp(1.4, 4.4);
    final lashPath = Path()
      ..moveTo(scleraRect.left - s * 0.005, lashY + archLift)
      ..quadraticBezierTo(center.dx, lashY - archLift * 0.45, scleraRect.right + s * 0.005, lashY + archLift);
    canvas.drawPath(lashPath, _strokePaint);

    // 2 tiny upturned outer lashes
    _strokePaint.strokeWidth = (s * 0.015).clamp(1.0, 2.8);
    final outerX = isViewerLeft ? scleraRect.left : scleraRect.right;
    final outerY = lashY + archLift * 0.85;
    canvas.drawLine(
      Offset(outerX, outerY),
      Offset(outerX + outerDir * s * 0.022, outerY - s * 0.016),
      _strokePaint,
    );
    canvas.drawLine(
      Offset(outerX + outerDir * s * 0.004, outerY + s * 0.014),
      Offset(outerX + outerDir * s * 0.020, outerY + s * 0.004),
      _strokePaint,
    );
  }

  void _drawCurvedClosedEye(
    Canvas canvas,
    double s,
    Offset center,
    double strokeW,
    double outerDir, {
    required bool happyUp,
  }) {
    _strokePaint
      ..color = AppColors.avatarHairShade
      ..strokeWidth = strokeW;
    final rx = s * 0.052;
    final curveDelta = happyUp ? -s * 0.042 : s * 0.032;
    final yBase = center.dy + (happyUp ? s * 0.014 : 0.0);
    final path = Path()
      ..moveTo(center.dx - rx, yBase)
      ..quadraticBezierTo(center.dx, yBase + curveDelta, center.dx + rx, yBase);
    canvas.drawPath(path, _strokePaint);

    // 2 cute lashes at outer corner (matches reference wink!)
    _strokePaint.strokeWidth = (strokeW * 0.68).clamp(1.0, 2.8);
    final outerX = center.dx + outerDir * rx;
    canvas.drawLine(
      Offset(outerX, yBase),
      Offset(outerX + outerDir * s * 0.018, yBase - s * 0.016),
      _strokePaint,
    );
    canvas.drawLine(
      Offset(outerX - outerDir * s * 0.006, yBase + s * 0.006),
      Offset(outerX + outerDir * s * 0.014, yBase + s * 0.004),
      _strokePaint,
    );
  }

  void _drawBrows(Canvas canvas, double s) {
    final raiseOffset = -expression.browRaise * s * 0.024;
    final tiltDelta = expression.browTilt * s * 0.020;
    final y = s * 0.345 + raiseOffset;

    _strokePaint
      ..color = AppColors.avatarHairShade
      ..strokeWidth = (s * 0.022).clamp(1.2, 4.2);

    // Viewer left eyebrow
    final leftPath = Path()
      ..moveTo(s * 0.345, y - tiltDelta * 0.5)
      ..quadraticBezierTo(s * 0.398, y - s * 0.020, s * 0.448, y + tiltDelta);
    canvas.drawPath(leftPath, _strokePaint);

    // Viewer right eyebrow
    final rightPath = Path()
      ..moveTo(s * 0.552, y + tiltDelta)
      ..quadraticBezierTo(s * 0.602, y - s * 0.020, s * 0.655, y - tiltDelta * 0.5);
    canvas.drawPath(rightPath, _strokePaint);
  }

  void _drawNose(Canvas canvas, double s) {
    // Adorable tiny sculpted soft clay button nose
    final center = Offset(s * 0.50, s * 0.498);
    _fillPaint.color = AppColors.avatarSkinShade.withValues(alpha: 0.72);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + s * 0.005),
        width: s * 0.032,
        height: s * 0.018,
      ),
      _fillPaint,
    );
    _fillPaint.color = Colors.white.withValues(alpha: 0.45);
    canvas.drawCircle(
      Offset(center.dx - s * 0.005, center.dy - s * 0.002),
      s * 0.007,
      _fillPaint,
    );
  }

  void _drawMouth(Canvas canvas, double s) {
    final center = Offset(s * 0.50, s * 0.556);
    final openAmt = (expression.mouthOpen + frame.mouthTalkBoost).clamp(0.0, 1.0);
    final curve = expression.mouthCurve;

    // 1. Sleepy / fidget yawn: big vertical oval (§2.4)
    if (frame.isYawning) {
      final yawnRect = Rect.fromCenter(
        center: Offset(center.dx, center.dy + s * 0.008),
        width: s * 0.072,
        height: s * 0.095,
      );
      _fillPaint.color = AppColors.avatarMouth;
      canvas.drawOval(yawnRect, _fillPaint);
      _fillPaint.color = AppColors.avatarTongue;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(center.dx, yawnRect.bottom - s * 0.022),
          width: s * 0.048,
          height: s * 0.032,
        ),
        _fillPaint,
      );
      return;
    }

    // 2. Wide cheerful "D" smile (reference pose!) or open talk/o mouth
    if (openAmt > 0.24 && curve > 0.45) {
      final talkNarrow = frame.talkShape * 0.22;
      final mouthW = s * (0.108 + openAmt * 0.036) * (1.0 - talkNarrow * 0.4);
      final mouthH = s * (0.048 + openAmt * 0.056) * (1.0 - talkNarrow);
      final topY = center.dy - mouthH * 0.34;
      final dPath = Path()
        ..moveTo(center.dx - mouthW * 0.5, topY)
        ..quadraticBezierTo(center.dx, topY + s * 0.008, center.dx + mouthW * 0.5, topY)
        ..cubicTo(
          center.dx + mouthW * 0.46,
          topY + mouthH * 1.15,
          center.dx - mouthW * 0.46,
          topY + mouthH * 1.15,
          center.dx - mouthW * 0.5,
          topY,
        )
        ..close();

      _fillPaint.color = AppColors.avatarMouth;
      canvas.drawPath(dPath, _fillPaint);

      // Clip white upper teeth + coral-pink tongue inside "D" mouth
      canvas.save();
      canvas.clipPath(dPath);
      _fillPaint.color = const Color(0xFFFFFCFA);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(center.dx, topY + mouthH * 0.14),
            width: mouthW * 0.84,
            height: mouthH * 0.28,
          ),
          Radius.circular(s * 0.012),
        ),
        _fillPaint,
      );
      _fillPaint.color = AppColors.avatarTongue;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(center.dx, topY + mouthH * 0.86),
          width: mouthW * 0.66,
          height: mouthH * 0.54,
        ),
        _fillPaint,
      );
      canvas.restore();
      return;
    }

    // 3. Open neutral / surprised "o" or streaming vowel alternation
    if (openAmt > 0.22) {
      final w = lerpDouble(s * 0.055, s * 0.082, frame.talkShape)!;
      final h = lerpDouble(s * (0.042 + openAmt * 0.046), s * 0.036, frame.talkShape)!;
      final rect = Rect.fromCenter(center: center, width: w, height: h);
      _fillPaint.color = AppColors.avatarMouth;
      canvas.drawOval(rect, _fillPaint);
      _fillPaint.color = AppColors.avatarTongue;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(center.dx, rect.bottom - h * 0.24),
          width: w * 0.58,
          height: h * 0.36,
        ),
        _fillPaint,
      );
      return;
    }

    // 4. Closed mouths: wavy frown, cute "ω" cat smile when blush > 0.7, or sweet smile
    _strokePaint
      ..color = AppColors.avatarMouth
      ..strokeWidth = (s * 0.018).clamp(1.2, 3.4);

    if (curve < -0.15) {
      // Worried wavy frown
      final halfW = s * 0.048;
      final amp = s * 0.014 * (-curve).clamp(0.3, 1.0);
      final wavy = Path()
        ..moveTo(center.dx - halfW, center.dy + amp * 0.5)
        ..quadraticBezierTo(center.dx - halfW * 0.5, center.dy - amp, center.dx, center.dy)
        ..quadraticBezierTo(center.dx + halfW * 0.5, center.dy + amp, center.dx + halfW, center.dy - amp * 0.4);
      canvas.drawPath(wavy, _strokePaint);
    } else if (curve > 0.4 && expression.blush > 0.7) {
      // Cute "ω" cat smile when super rosy/blushing
      final halfW = s * 0.052;
      final dip = s * 0.022;
      final cat = Path()
        ..moveTo(center.dx - halfW, center.dy - dip * 0.3)
        ..quadraticBezierTo(center.dx - halfW * 0.5, center.dy + dip, center.dx, center.dy - dip * 0.15)
        ..quadraticBezierTo(center.dx + halfW * 0.5, center.dy + dip, center.dx + halfW, center.dy - dip * 0.3);
      canvas.drawPath(cat, _strokePaint);
    } else {
      final halfW = s * 0.046;
      final depth = curve * s * 0.032;
      final smile = Path()
        ..moveTo(center.dx - halfW, center.dy - depth * 0.25)
        ..quadraticBezierTo(center.dx, center.dy + depth, center.dx + halfW, center.dy - depth * 0.25);
      canvas.drawPath(smile, _strokePaint);
    }
  }

  void _drawBangs(Canvas canvas, double s, Offset sway) {
    // Two curly side hair strands framing cheeks in front of ears (sway x 0.8)
    _drawSideStrand(canvas, s, isLeft: true, sway: sway);
    _drawSideStrand(canvas, s, isLeft: false, sway: sway);

    // Sculpted curtain / swept bangs: 5 soft-pointed leaf strands rotated
    // around upper crown pivots by hairSwayOffset x 0.6 (§3 Fase B)
    final partPivot = Offset(s * 0.48, s * 0.16);
    canvas.save();
    canvas.translate(partPivot.dx, partPivot.dy);
    canvas.rotate(-sway.dx * 0.6);
    canvas.translate(-partPivot.dx, -partPivot.dy + sway.dy * s * 0.18);

    _fillPaint
      ..shader = _bangsShader
      ..color = AppColors.avatarHair;

    // Left voluminous curtain sweep
    final leftCurtain = Path()
      ..moveTo(s * 0.485, s * 0.14)
      ..cubicTo(s * 0.32, s * 0.12, s * 0.20, s * 0.24, s * 0.19, s * 0.42)
      ..quadraticBezierTo(s * 0.24, s * 0.43, s * 0.28, s * 0.35)
      ..cubicTo(s * 0.34, s * 0.28, s * 0.44, s * 0.24, s * 0.485, s * 0.18)
      ..close();
    canvas.drawPath(leftCurtain, _fillPaint);

    // Right voluminous curtain sweep
    final rightCurtain = Path()
      ..moveTo(s * 0.475, s * 0.14)
      ..cubicTo(s * 0.65, s * 0.12, s * 0.79, s * 0.23, s * 0.80, s * 0.41)
      ..quadraticBezierTo(s * 0.75, s * 0.42, s * 0.71, s * 0.34)
      ..cubicTo(s * 0.65, s * 0.27, s * 0.54, s * 0.24, s * 0.475, s * 0.18)
      ..close();
    canvas.drawPath(rightCurtain, _fillPaint);

    // 3 soft-pointed inner leaf strands sweeping softly over forehead
    final leafStrands = [
      (Offset(s * 0.47, s * 0.16), Offset(s * 0.34, s * 0.25), Offset(s * 0.29, s * 0.34), Offset(s * 0.40, s * 0.28)),
      (Offset(s * 0.48, s * 0.17), Offset(s * 0.44, s * 0.24), Offset(s * 0.42, s * 0.30), Offset(s * 0.49, s * 0.24)),
      (Offset(s * 0.49, s * 0.16), Offset(s * 0.62, s * 0.24), Offset(s * 0.69, s * 0.33), Offset(s * 0.58, s * 0.27)),
    ];
    for (final (p0, c1, tip, c2) in leafStrands) {
      final leaf = Path()
        ..moveTo(p0.dx, p0.dy)
        ..quadraticBezierTo(c1.dx, c1.dy, tip.dx, tip.dy)
        ..quadraticBezierTo(c2.dx, c2.dy, p0.dx, p0.dy)
        ..close();
      canvas.drawPath(leaf, _fillPaint);
    }
    _fillPaint.shader = null;

    // Soft sculpted clay ridge highlights & part groove
    _strokePaint
      ..color = AppColors.avatarHairHighlight.withValues(alpha: 0.50)
      ..strokeWidth = (s * 0.018).clamp(1.0, 3.2);
    canvas.drawPath(
      Path()
        ..moveTo(s * 0.26, s * 0.29)
        ..quadraticBezierTo(s * 0.34, s * 0.18, s * 0.46, s * 0.17),
      _strokePaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(s * 0.51, s * 0.17)
        ..quadraticBezierTo(s * 0.64, s * 0.18, s * 0.72, s * 0.28),
      _strokePaint,
    );

    _strokePaint
      ..color = AppColors.avatarHairShade.withValues(alpha: 0.55)
      ..strokeWidth = (s * 0.011).clamp(0.7, 2.0);
    canvas.drawPath(
      Path()
        ..moveTo(s * 0.48, s * 0.145)
        ..quadraticBezierTo(s * 0.475, s * 0.185, s * 0.49, s * 0.215),
      _strokePaint,
    );

    canvas.restore();
  }

  void _drawSideStrand(
    Canvas canvas,
    double s, {
    required bool isLeft,
    required Offset sway,
  }) {
    final sign = isLeft ? -1.0 : 1.0;
    final pivot = Offset(s * (0.50 + sign * 0.25), s * 0.33);
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(-sway.dx * 0.8);
    canvas.translate(-pivot.dx, -pivot.dy + sway.dy * s * 0.22);

    _fillPaint
      ..shader = _bangsShader
      ..color = AppColors.avatarHair;
    final strand = Path()
      ..moveTo(s * (0.50 + sign * 0.23), s * 0.32)
      ..cubicTo(
        s * (0.50 + sign * 0.31),
        s * 0.40,
        s * (0.50 + sign * 0.33),
        s * 0.50,
        s * (0.50 + sign * 0.29),
        s * 0.57,
      )
      ..quadraticBezierTo(
        s * (0.50 + sign * 0.24),
        s * 0.51,
        s * (0.50 + sign * 0.22),
        s * 0.39,
      )
      ..close();
    canvas.drawPath(strand, _fillPaint);
    _fillPaint.shader = null;
    canvas.restore();
  }

  void _drawAhogeAndClip(Canvas canvas, double s, Offset sway) {
    // 1. Bouncy signature ahoge (sway x 1.4, perk from ahogePerk, "?" in error mood)
    final ahogeBase = Offset(s * 0.51, s * 0.145);
    canvas.save();
    canvas.translate(ahogeBase.dx, ahogeBase.dy);
    canvas.rotate(sway.dx * 1.4 + (1.0 - expression.ahogePerk) * 0.42);
    canvas.translate(-ahogeBase.dx, -ahogeBase.dy);

    final lift = lerpDouble(s * 0.045, s * 0.115, expression.ahogePerk)!;
    _strokePaint
      ..color = AppColors.avatarHair
      ..strokeWidth = (s * 0.024).clamp(1.4, 4.4);

    if (frame.isQuestionAhoge) {
      // Playful "?" curl during error mood (§2.7)
      final qPath = Path()
        ..moveTo(ahogeBase.dx, ahogeBase.dy)
        ..cubicTo(
          ahogeBase.dx - s * 0.02,
          ahogeBase.dy - lift * 0.55,
          ahogeBase.dx + s * 0.06,
          ahogeBase.dy - lift * 0.55,
          ahogeBase.dx + s * 0.045,
          ahogeBase.dy - lift * 0.95,
        )
        ..cubicTo(
          ahogeBase.dx + s * 0.03,
          ahogeBase.dy - lift * 1.25,
          ahogeBase.dx - s * 0.04,
          ahogeBase.dy - lift * 1.12,
          ahogeBase.dx - s * 0.035,
          ahogeBase.dy - lift * 0.78,
        );
      canvas.drawPath(qPath, _strokePaint);
    } else {
      final ahogePath = Path()
        ..moveTo(ahogeBase.dx, ahogeBase.dy)
        ..cubicTo(
          ahogeBase.dx + s * 0.02 + sway.dx * s * 0.25,
          ahogeBase.dy - lift * 0.75,
          ahogeBase.dx + s * 0.09 + sway.dx * s * 0.4,
          ahogeBase.dy - lift,
          ahogeBase.dx + s * 0.115 + sway.dx * s * 0.5,
          ahogeBase.dy - lift * 0.48 + sway.dy * s * 0.35,
        );
      canvas.drawPath(ahogePath, _strokePaint);

      // Subtle glossy highlight along ahoge curve
      _strokePaint
        ..color = AppColors.avatarHairHighlight.withValues(alpha: 0.6)
        ..strokeWidth = (s * 0.009).clamp(0.7, 1.8);
      canvas.drawPath(ahogePath, _strokePaint);
    }
    canvas.restore();

    // 2. Glowing 5-point star hair clip (Wynn's mood beacon!)
    final clipCenter = Offset(
      s * 0.665 - sway.dx * s * 0.06,
      s * 0.245 + sway.dy * s * 0.12,
    );
    final starR = s * 0.048;
    final glowStrength = (expression.accentGlow * frame.accentPulse).clamp(
      0.0,
      1.2,
    );

    if (glowStrength > 0.05) {
      final blurSigma = (s * 0.034).clamp(1.4, 6.0);
      _glowPaint
        ..color = expression.accentColor.withValues(
          alpha: (0.55 * glowStrength).clamp(0.0, 0.85),
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma);
      canvas.drawCircle(
        clipCenter,
        starR * (1.25 + glowStrength * 0.35),
        _glowPaint,
      );
      _glowPaint.maskFilter = null;
    }

    canvas.save();
    canvas.translate(clipCenter.dx, clipCenter.dy);
    canvas.rotate(0.22 - sway.dx * 0.5);
    final starPath = _buildStarPath(starR, starR * 0.48);
    _fillPaint.color = Color.lerp(
      AppColors.avatarStarClip,
      expression.accentColor,
      (0.35 + expression.accentGlow * 0.45).clamp(0.0, 0.85),
    )!;
    canvas.drawPath(starPath, _fillPaint);

    // Tiny glossy clay highlight dot on star clip
    _fillPaint.color = Colors.white.withValues(alpha: 0.82);
    canvas.drawCircle(Offset(-starR * 0.22, -starR * 0.20), starR * 0.22, _fillPaint);
    canvas.restore();
  }

  Path _buildStarPath(double outerR, double innerR) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? outerR : innerR;
      final angle = -math.pi / 2 + (i * math.pi / 5);
      final pt = Offset(math.cos(angle) * r, math.sin(angle) * r);
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    return path..close();
  }

  void _drawArms(Canvas canvas, double s) {
    // §2.8 framing visibility: xs omits arms; sm draws arms only for peek/cheer
    if (avatarSize == AvatarSize.xs) return;
    final effectivePose =
        (poseMode == AvatarPoseMode.peek && expression.armPose == ArmPose.rest)
        ? ArmPose.peek
        : expression.armPose;
    if (avatarSize == AvatarSize.sm &&
        effectivePose != ArmPose.peek &&
        effectivePose != ArmPose.cheer &&
        effectivePose != ArmPose.chin) {
      return;
    }

    // Viewer left arm (shoulder at 0.26, 0.72 -> frame.leftHandPos)
    final leftShoulder = Offset(s * 0.24, s * 0.74);
    final rightShoulder = Offset(s * 0.76, s * 0.74);
    final leftHand = Offset(frame.leftHandPos.dx * s, frame.leftHandPos.dy * s);
    final rightHand = Offset(
      frame.rightHandPos.dx * s,
      frame.rightHandPos.dy * s,
    );

    _drawHoodieArm(
      canvas,
      s,
      shoulder: leftShoulder,
      hand: leftHand,
      isLeft: true,
      pose: effectivePose,
    );
    _drawHoodieArm(
      canvas,
      s,
      shoulder: rightShoulder,
      hand: rightHand,
      isLeft: false,
      pose: effectivePose,
    );
  }

  void _drawHoodieArm(
    Canvas canvas,
    double s, {
    required Offset shoulder,
    required Offset hand,
    required bool isLeft,
    required ArmPose pose,
  }) {
    final dir = hand - shoulder;
    final dist = dir.distance.clamp(s * 0.08, s * 0.45);
    final angle = math.atan2(dir.dy, dir.dx);
    final sleeveW = s * 0.145;
    final cuffOffset = (dist - s * 0.068).clamp(s * 0.04, dist);

    // 1. Chunky lavender hoodie sleeve & ribbed cuff
    // In peek mode, clip sleeves along the card rim so ONLY hands drape over the card!
    final clipSleeveAtRim = poseMode == AvatarPoseMode.peek;
    if (clipSleeveAtRim) {
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(-s * 0.1, 0, s * 1.1, s * 0.875));
    }
    canvas.save();
    canvas.translate(shoulder.dx, shoulder.dy);
    canvas.rotate(angle);

    final sleeveRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(-s * 0.05, -sleeveW * 0.5, cuffOffset + s * 0.05, sleeveW),
      Radius.circular(sleeveW * 0.48),
    );
    _fillPaint
      ..shader = _hoodieShader
      ..color = AppColors.avatarHood;
    canvas.drawRRect(sleeveRect, _fillPaint);
    _fillPaint.shader = null;

    // Chunky ribbed lavender cuff band (matches reference hoodie cuffs!)
    final cuffRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        cuffOffset - s * 0.058,
        -sleeveW * 0.47,
        s * 0.072,
        sleeveW * 0.94,
      ),
      Radius.circular(sleeveW * 0.30),
    );
    _fillPaint.color = AppColors.avatarHoodLight;
    canvas.drawRRect(cuffRect, _fillPaint);

    _strokePaint
      ..color = AppColors.avatarHoodDark.withValues(alpha: 0.35)
      ..strokeWidth = (s * 0.011).clamp(0.7, 2.0);
    canvas.drawLine(
      Offset(cuffOffset - s * 0.056, -sleeveW * 0.40),
      Offset(cuffOffset - s * 0.056, sleeveW * 0.40),
      _strokePaint,
    );
    canvas.restore();
    if (clipSleeveAtRim) {
      canvas.restore();
    }

    // 2. Plump soft-clay mitten hand (no outlines, soft gradient)
    final handRx = pose == ArmPose.peek ? s * 0.074 : s * 0.062;
    final handRy = pose == ArmPose.peek ? s * 0.056 : s * 0.064;

    canvas.save();
    canvas.translate(hand.dx, hand.dy);
    if (pose == ArmPose.chin && !isLeft) {
      canvas.rotate(-0.35);
    } else if (pose == ArmPose.peek) {
      canvas.rotate(isLeft ? 0.16 : -0.16);
    }

    // Soft drop shadow beneath peeking hand over card rim
    if (pose == ArmPose.peek || (pose == ArmPose.chin && isLeft)) {
      _fillPaint.color = AppColors.avatarInk.withValues(alpha: 0.11);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, s * 0.014),
          width: handRx * 1.95,
          height: handRy * 1.75,
        ),
        _fillPaint,
      );
    }

    _fillPaint
      ..shader = _skinHandShader
      ..color = AppColors.avatarSkin;
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: handRx * 2, height: handRy * 2),
      _fillPaint,
    );
    _fillPaint.shader = null;

    // Subtle soft-clay finger crease hints on md/lg sizes
    if (avatarSize == AvatarSize.md || avatarSize == AvatarSize.lg) {
      _strokePaint
        ..color = AppColors.avatarSkinShade.withValues(alpha: 0.65)
        ..strokeWidth = (s * 0.008).clamp(0.6, 1.5);
      canvas.drawLine(
        Offset(-handRx * 0.25, handRy * 0.18),
        Offset(-handRx * 0.20, handRy * 0.72),
        _strokePaint,
      );
      canvas.drawLine(
        Offset(handRx * 0.18, handRy * 0.18),
        Offset(handRx * 0.22, handRy * 0.72),
        _strokePaint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ChibiBodyPainter oldDelegate) {
    if (motionController != null || oldDelegate.motionController != null) {
      return oldDelegate.motionController != motionController ||
          oldDelegate.avatarSize != avatarSize ||
          oldDelegate.poseMode != poseMode;
    }
    return oldDelegate.expression != expression ||
        oldDelegate.frame != frame ||
        oldDelegate.avatarSize != avatarSize ||
        oldDelegate.poseMode != poseMode;
  }
}
