import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/avatar_expression.dart';
import '../../domain/avatar_mood.dart';
import '../controllers/avatar_frame.dart';
import '../controllers/avatar_motion_controller.dart';

/// Pixar-style 3D soft-shaded CustomPainter for "Wynn" matching the user's
/// reference character: glossy jet-black wavy chin-length bob with deep
/// side-swept bangs, matte-black round-wayfarer glasses with lens sheen,
/// big winged-eyeliner espresso eyes, rosy button nose, coral lips, and
/// cream-white ribbed crewneck sweater with navy-blue horizontal stripes.
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

  // Reusable Paint instances (zero per-frame allocations)
  final Paint _shadowPaint = Paint()
    ..style = PaintingStyle.fill
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
  final Paint _fillPaint = Paint()..style = PaintingStyle.fill;
  final Paint _shadePaint = Paint()..style = PaintingStyle.fill;
  final Paint _strokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final Paint _blushPaint = Paint()..style = PaintingStyle.fill;
  final Paint _glowPaint = Paint()..style = PaintingStyle.fill;

  // Cached size-dependent shaders
  Size? _cachedSize;
  Shader? _hairBackShader;
  Shader? _hairFrontShader;
  Shader? _sweaterShader;
  Shader? _faceShader;
  Shader? _neckShader;
  Shader? _irisShader;
  Shader? _skinHandShader;
  Shader? _noseShader;

  void _ensureShaders(Size size) {
    if (_cachedSize == size) return;
    _cachedSize = size;
    final s = size.shortestSide;

    _hairBackShader = const RadialGradient(
      center: Alignment(-0.28, -0.48),
      radius: 1.08,
      colors: [
        Color(0xFF3E4357),
        AppColors.avatarHair,
        AppColors.avatarHairShade,
      ],
      stops: [0.0, 0.42, 1.0],
    ).createShader(Rect.fromLTWH(s * 0.12, s * 0.06, s * 0.76, s * 0.72));

    _hairFrontShader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF454B63),
        AppColors.avatarHair,
        AppColors.avatarHairShade,
      ],
      stops: [0.0, 0.48, 1.0],
    ).createShader(Rect.fromLTWH(s * 0.16, s * 0.08, s * 0.68, s * 0.56));

    _sweaterShader = const RadialGradient(
      center: Alignment(0.0, -0.45),
      radius: 1.10,
      colors: [
        AppColors.avatarHoodLight,
        AppColors.avatarHood,
        AppColors.avatarHoodDark,
      ],
      stops: [0.0, 0.68, 1.0],
    ).createShader(Rect.fromLTWH(s * 0.16, s * 0.66, s * 0.68, s * 0.34));

    _faceShader = const RadialGradient(
      center: Alignment(-0.12, -0.22),
      radius: 0.92,
      colors: [
        Color(0xFFFFEFE3),
        AppColors.avatarSkin,
        AppColors.avatarSkinShade,
      ],
      stops: [0.0, 0.58, 1.0],
    ).createShader(
      Rect.fromCenter(
        center: Offset(s * 0.50, s * 0.41),
        width: s * 0.48,
        height: s * 0.48,
      ),
    );

    _neckShader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFFD4927B),
        AppColors.avatarSkin,
        Color(0xFFF3C2A8),
      ],
      stops: [0.0, 0.52, 1.0],
    ).createShader(Rect.fromLTWH(s * 0.41, s * 0.59, s * 0.18, s * 0.16));

    _irisShader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF1A100D),
        AppColors.avatarIris,
        AppColors.avatarIrisLight,
      ],
      stops: [0.0, 0.52, 1.0],
    ).createShader(Rect.fromLTWH(0, -s * 0.055, s * 0.10, s * 0.11));

    _skinHandShader = const RadialGradient(
      center: Alignment(-0.3, -0.35),
      radius: 0.95,
      colors: [
        Color(0xFFFFEFE3),
        AppColors.avatarSkin,
        AppColors.avatarSkinShade,
      ],
      stops: [0.0, 0.60, 1.0],
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: s * 0.085));

    _noseShader = const RadialGradient(
      center: Alignment(-0.25, -0.35),
      radius: 0.95,
      colors: [
        Color(0xFFFFC1B2),
        Color(0xFFF19582),
        Color(0xFFD87968),
      ],
      stops: [0.0, 0.58, 1.0],
    ).createShader(
      Rect.fromCenter(
        center: Offset(s * 0.50, s * 0.478),
        width: s * 0.072,
        height: s * 0.048,
      ),
    );
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

    // 1. Contact shadow
    if (poseMode == AvatarPoseMode.standing && avatarSize != AvatarSize.xs) {
      _drawContactShadow(canvas, s);
    }

    // Body root transform
    final bodyPivot = Offset(s * 0.50, s * 0.80);
    canvas.save();
    canvas.translate(frame.shakeX * s, frame.floatY * s);
    canvas.translate(bodyPivot.dx, bodyPivot.dy);
    canvas.scale(
      frame.squashX * frame.bodyScale,
      frame.squashY * frame.breatheScaleY * frame.bodyScale,
    );
    canvas.translate(-bodyPivot.dx, -bodyPivot.dy);

    // 2. Back glossy black wavy bob silhouette (behind shoulders & neck)
    final headPivot = Offset(s * 0.50, s * 0.62);
    canvas.save();
    canvas.translate(headPivot.dx, headPivot.dy);
    canvas.rotate(frame.headTiltZ);
    canvas.translate(-headPivot.dx, -headPivot.dy);
    _drawHairBack(canvas, s, sway);
    canvas.restore();

    // 3. Cream knit crewneck sweater with navy horizontal stripe
    _drawBody(canvas, s);

    // 4..13. Head, face, eyes, glasses, glossy bob bangs & mood accent
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
    _drawGlasses(canvas, s);
    _drawBangsAndBobSides(canvas, s, sway);
    _drawMoodAccent(canvas, s, sway);

    canvas.restore();

    // 14. Arms & cream/navy-striped sleeves
    _drawArms(canvas, s);

    canvas.restore();
    canvas.restore();
  }

  void _applyFraming(Canvas canvas, double s) {
    switch (avatarSize) {
      case AvatarSize.xs:
        const scale = 1.46;
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
    final shadowAlpha = (0.12 - lift * 0.6).clamp(0.06, 0.16);
    _shadowPaint.color = AppColors.avatarInk.withValues(alpha: shadowAlpha);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(s * 0.50 + frame.shakeX * s * 0.4, s * 0.96),
        width: s * 0.56 * shadowScale,
        height: s * 0.065 * shadowScale,
      ),
      _shadowPaint,
    );
  }

  /// Glossy jet-black wavy chin-length bob silhouette curving smoothly outward
  /// around cheeks and tucking softly inward beneath jaw level.
  void _drawHairBack(Canvas canvas, double s, Offset sway) {
    final pivot = Offset(s * 0.50, s * 0.24);
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(-sway.dx * 0.9);
    canvas.translate(-pivot.dx, -pivot.dy + sway.dy * s * 0.30);

    final bob = Path()
      ..moveTo(s * 0.56, s * 0.115)
      // Right side dome & wavy bob flare
      ..cubicTo(s * 0.72, s * 0.085, s * 0.78, s * 0.27, s * 0.80, s * 0.44)
      ..cubicTo(s * 0.84, s * 0.54, s * 0.85, s * 0.66, s * 0.76, s * 0.72)
      ..cubicTo(s * 0.68, s * 0.76, s * 0.60, s * 0.73, s * 0.56, s * 0.69)
      // Across behind neck
      ..lineTo(s * 0.44, s * 0.69)
      // Left side wavy bob tuck & flare
      ..cubicTo(s * 0.40, s * 0.74, s * 0.31, s * 0.76, s * 0.23, s * 0.71)
      ..cubicTo(s * 0.15, s * 0.65, s * 0.16, s * 0.54, s * 0.21, s * 0.44)
      ..cubicTo(s * 0.23, s * 0.26, s * 0.30, s * 0.075, s * 0.56, s * 0.115)
      ..close();

    _fillPaint
      ..shader = _hairBackShader
      ..color = AppColors.avatarHair;
    canvas.drawPath(bob, _fillPaint);
    _fillPaint.shader = null;

    // Silky curved Pixar sheen arcs on upper crown & lower bob waves
    _strokePaint
      ..color = AppColors.avatarHairHighlight.withValues(alpha: 0.48)
      ..strokeWidth = (s * 0.022).clamp(1.2, 4.2);
    canvas.drawPath(
      Path()
        ..moveTo(s * 0.28, s * 0.27)
        ..quadraticBezierTo(s * 0.36, s * 0.13, s * 0.54, s * 0.13),
      _strokePaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(s * 0.61, s * 0.14)
        ..quadraticBezierTo(s * 0.72, s * 0.22, s * 0.76, s * 0.40),
      _strokePaint,
    );

    _strokePaint
      ..color = AppColors.avatarHairHighlight.withValues(alpha: 0.34)
      ..strokeWidth = (s * 0.018).clamp(1.0, 3.2);
    canvas.drawPath(
      Path()
        ..moveTo(s * 0.21, s * 0.56)
        ..quadraticBezierTo(s * 0.22, s * 0.67, s * 0.31, s * 0.71),
      _strokePaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(s * 0.79, s * 0.56)
        ..quadraticBezierTo(s * 0.79, s * 0.67, s * 0.70, s * 0.71),
      _strokePaint,
    );

    canvas.restore();
  }

  /// Cream-white ribbed crewneck knit sweater with crisp navy horizontal chest stripe.
  void _drawBody(Canvas canvas, double s) {
    final isPeek = poseMode == AvatarPoseMode.peek;
    final bottomY = isPeek ? s * 0.87 : s * 0.96;

    if (isPeek) {
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(0, 0, s, s * 0.865));
    }

    final torso = Path()
      ..moveTo(s * 0.21, bottomY)
      ..cubicTo(s * 0.22, s * 0.80, s * 0.26, s * 0.72, s * 0.39, s * 0.705)
      ..lineTo(s * 0.61, s * 0.705)
      ..cubicTo(s * 0.74, s * 0.72, s * 0.78, s * 0.80, s * 0.79, bottomY)
      ..close();

    _fillPaint
      ..shader = _sweaterShader
      ..color = AppColors.avatarHood;
    canvas.drawPath(torso, _fillPaint);
    _fillPaint.shader = null;

    // Clip navy horizontal chest stripe & subtle knit shoulder shading inside torso
    canvas.save();
    canvas.clipPath(torso);

    // Signature deep navy-blue chest stripe
    _fillPaint.color = AppColors.avatarSweaterStripe;
    final stripePath = Path()
      ..moveTo(s * 0.26, s * 0.835)
      ..quadraticBezierTo(s * 0.50, s * 0.822, s * 0.74, s * 0.835)
      ..lineTo(s * 0.75, s * 0.885)
      ..quadraticBezierTo(s * 0.50, s * 0.872, s * 0.25, s * 0.885)
      ..close();
    canvas.drawPath(stripePath, _fillPaint);

    // Matching lower sleeve stripes on left & right shoulders
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s * 0.19, s * 0.915, s * 0.13, s * 0.032),
        Radius.circular(s * 0.01),
      ),
      _fillPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s * 0.68, s * 0.915, s * 0.13, s * 0.032),
        Radius.circular(s * 0.01),
      ),
      _fillPaint,
    );

    // Soft ambient shadow cast by bob hair onto upper sweater shoulders
    _shadePaint.color = AppColors.avatarHoodDark.withValues(alpha: 0.42);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(s * 0.31, s * 0.73),
        width: s * 0.18,
        height: s * 0.08,
      ),
      _shadePaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(s * 0.69, s * 0.73),
        width: s * 0.18,
        height: s * 0.08,
      ),
      _shadePaint,
    );
    canvas.restore();

    // Ribbed cream crewneck collar band
    final collarPath = Path()
      ..moveTo(s * 0.395, s * 0.702)
      ..quadraticBezierTo(s * 0.50, s * 0.785, s * 0.605, s * 0.702);
    _strokePaint
      ..color = AppColors.avatarHoodLight
      ..strokeWidth = (s * 0.036).clamp(2.0, 6.4);
    canvas.drawPath(collarPath, _strokePaint);

    _strokePaint
      ..color = AppColors.avatarHoodDark.withValues(alpha: 0.55)
      ..strokeWidth = (s * 0.009).clamp(0.6, 1.6);
    canvas.drawPath(
      Path()
        ..moveTo(s * 0.388, s * 0.716)
        ..quadraticBezierTo(s * 0.50, s * 0.802, s * 0.612, s * 0.716),
      _strokePaint,
    );

    // Subtle knit rib ticks along crewneck collar on md/lg
    if (avatarSize == AvatarSize.md || avatarSize == AvatarSize.lg) {
      _strokePaint
        ..color = AppColors.avatarHoodDark.withValues(alpha: 0.45)
        ..strokeWidth = (s * 0.006).clamp(0.5, 1.2);
      for (var i = -4; i <= 4; i++) {
        final t = (i + 4) / 8.0;
        final x = lerpDouble(s * 0.415, s * 0.585, t)!;
        final curveDip = math.sin(t * math.pi) * s * 0.042;
        canvas.drawLine(
          Offset(x, s * 0.706 + curveDip),
          Offset(x, s * 0.734 + curveDip),
          _strokePaint,
        );
      }
    }

    if (isPeek) {
      canvas.restore();
    }
  }

  void _drawNeckAndEars(Canvas canvas, double s) {
    // Graceful slender Pixar neck tapering smoothly into crewneck collar
    final neckPath = Path()
      ..moveTo(s * 0.44, s * 0.595)
      ..quadraticBezierTo(s * 0.445, s * 0.675, s * 0.405, s * 0.712)
      ..quadraticBezierTo(s * 0.50, s * 0.775, s * 0.595, s * 0.712)
      ..quadraticBezierTo(s * 0.555, s * 0.675, s * 0.56, s * 0.595)
      ..close();
    _fillPaint
      ..shader = _neckShader
      ..color = AppColors.avatarSkin;
    canvas.drawPath(neckPath, _fillPaint);
    _fillPaint.shader = null;

    // Small ears subtly peeking behind the glasses temples & bob sides
    for (final side in [-1.0, 1.0]) {
      final earCenter = Offset(s * (0.50 + side * 0.218), s * 0.475);
      _fillPaint.color = AppColors.avatarSkinShade;
      canvas.drawOval(
        Rect.fromCenter(
          center: earCenter,
          width: s * 0.068,
          height: s * 0.090,
        ),
        _fillPaint,
      );
    }
  }

  void _drawFace(Canvas canvas, double s) {
    // Smooth heart-oval Pixar face: full soft cheeks tapering gently to cute rounded chin
    final facePath = Path()
      ..moveTo(s * 0.50, s * 0.175)
      ..cubicTo(s * 0.66, s * 0.175, s * 0.725, s * 0.295, s * 0.720, s * 0.445)
      ..cubicTo(s * 0.715, s * 0.565, s * 0.618, s * 0.638, s * 0.50, s * 0.638)
      ..cubicTo(s * 0.382, s * 0.638, s * 0.285, s * 0.565, s * 0.280, s * 0.445)
      ..cubicTo(s * 0.275, s * 0.295, s * 0.34, s * 0.175, s * 0.50, s * 0.175)
      ..close();

    _fillPaint
      ..shader = _faceShader
      ..color = AppColors.avatarSkin;
    canvas.drawPath(facePath, _fillPaint);
    _fillPaint.shader = null;

    // Soft cast shadow from side-swept bangs onto upper-left forehead
    canvas.save();
    canvas.clipPath(facePath);
    _fillPaint.color = AppColors.avatarSkinShade.withValues(alpha: 0.35);
    final bangsShadow = Path()
      ..moveTo(s * 0.24, s * 0.16)
      ..lineTo(s * 0.62, s * 0.16)
      ..quadraticBezierTo(s * 0.52, s * 0.32, s * 0.24, s * 0.39)
      ..close();
    canvas.drawPath(bangsShadow, _fillPaint);
    canvas.restore();
  }

  void _drawBlush(Canvas canvas, double s) {
    final intensity = (expression.blush * 0.85 + 0.25).clamp(0.0, 1.0);
    final sigma = (s * 0.036).clamp(1.4, 6.0);
    _blushPaint
      ..color = AppColors.avatarBlush.withValues(alpha: 0.52 * intensity)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(s * 0.365, s * 0.495),
        width: s * 0.145,
        height: s * 0.085,
      ),
      _blushPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(s * 0.635, s * 0.495),
        width: s * 0.145,
        height: s * 0.085,
      ),
      _blushPaint,
    );
    _blushPaint.maskFilter = null;

    if (expression.blush > 0.65 && avatarSize != AvatarSize.xs) {
      final lineAlpha = ((expression.blush - 0.65) / 0.35).clamp(0.0, 1.0) * 0.55;
      _strokePaint
        ..color = AppColors.avatarMouth.withValues(alpha: lineAlpha)
        ..strokeWidth = (s * 0.008).clamp(0.6, 1.5);
      for (final cx in [s * 0.365, s * 0.635]) {
        for (var i = -1; i <= 1; i++) {
          final dx = cx + i * s * 0.022;
          canvas.drawLine(
            Offset(dx - s * 0.007, s * 0.512),
            Offset(dx + s * 0.007, s * 0.490),
            _strokePaint,
          );
        }
      }
    }
  }

  void _drawEyes(Canvas canvas, double s) {
    final effectiveOpen = (expression.eyeOpen * (1.0 - frame.blinkAmount))
        .clamp(0.0, 1.0);
    _drawSingleEye(
      canvas,
      s,
      center: Offset(s * 0.398, s * 0.412),
      isViewerLeft: true,
      effectiveOpen: effectiveOpen,
    );
    _drawSingleEye(
      canvas,
      s,
      center: Offset(s * 0.602, s * 0.412),
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
    final strokeW = (s * 0.021).clamp(1.4, 4.0);
    final outerDir = isViewerLeft ? -1.0 : 1.0;

    if (expression.eyeShape == EyeShape.happy ||
        (expression.winkRight && isViewerLeft)) {
      _drawCurvedClosedEye(canvas, s, center, strokeW, outerDir, happyUp: true);
      return;
    }

    if (expression.eyeShape == EyeShape.squeeze) {
      _strokePaint
        ..color = AppColors.avatarInk
        ..strokeWidth = strokeW;
      final rx = s * 0.044;
      final ry = s * 0.032;
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

    if (effectiveOpen < 0.09) {
      _drawCurvedClosedEye(canvas, s, center, strokeW, outerDir, happyUp: false);
      return;
    }

    final isWide = expression.eyeShape == EyeShape.wide;
    final eyeW = s * 0.118 * (isWide ? 1.12 : 1.0);
    final eyeH = s * 0.096 * (isWide ? 1.15 : 1.0);
    final scleraRect = Rect.fromCenter(center: center, width: eyeW, height: eyeH);
    final scleraPath = Path()..addOval(scleraRect);

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

    // Pure studio white sclera
    _fillPaint.color = const Color(0xFFFFFDFB);
    canvas.drawPath(scleraPath, _fillPaint);

    // Clip glossy espresso iris + studio catchlights inside sclera
    canvas.save();
    canvas.clipPath(scleraPath);

    final gazeShift = Offset(
      (frame.pupilOffset.dx * s * 0.90).clamp(-eyeW * 0.22, eyeW * 0.22),
      (frame.pupilOffset.dy * s * 0.90).clamp(-eyeH * 0.20, eyeH * 0.20),
    );
    final irisScale = isWide ? 0.86 : 1.0;
    final irisR = eyeH * 0.44 * irisScale;
    final irisCenter = center + gazeShift + Offset(isViewerLeft ? s * 0.008 : -s * 0.008, s * 0.004);

    canvas.save();
    canvas.translate(irisCenter.dx, irisCenter.dy);
    _fillPaint
      ..shader = _irisShader
      ..color = AppColors.avatarIris;
    canvas.drawCircle(Offset.zero, irisR, _fillPaint);
    _fillPaint.shader = null;

    _fillPaint.color = AppColors.avatarInk;
    canvas.drawCircle(Offset.zero, irisR * 0.56, _fillPaint);
    canvas.restore();

    // Soft upper sclera shadow under lashes
    _fillPaint.color = const Color(0xFF8C7B76).withValues(alpha: 0.22);
    canvas.drawRect(
      Rect.fromLTRB(scleraRect.left, scleraRect.top, scleraRect.right, scleraRect.top + eyeH * 0.22),
      _fillPaint,
    );

    // Crisp Pixar studio catchlights (30% gaze lag)
    final specShift = gazeShift * 0.30;
    final specBoost = isWide ? 1.15 : 1.0;
    _fillPaint.color = Colors.white.withValues(alpha: 0.96);
    canvas.drawOval(
      Rect.fromCenter(
        center: irisCenter - gazeShift + specShift + Offset(-irisR * 0.36, -irisR * 0.34),
        width: irisR * 0.52 * specBoost,
        height: irisR * 0.44 * specBoost,
      ),
      _fillPaint,
    );
    canvas.drawCircle(
      irisCenter - gazeShift + specShift + Offset(irisR * 0.32, irisR * 0.32),
      irisR * 0.16 * specBoost,
      _fillPaint,
    );

    canvas.restore();
    canvas.restore();

    // Signature thick winged black eyeliner flicking upward at outer corners
    final lashY = math.max(scleraRect.top + eyeH * 0.02, lidTopY + s * 0.003);
    final archLift = eyeH * 0.24 * effectiveOpen;
    final outerX = isViewerLeft ? scleraRect.left : scleraRect.right;
    final innerX = isViewerLeft ? scleraRect.right : scleraRect.left;

    _strokePaint
      ..color = AppColors.avatarInk
      ..strokeWidth = (s * 0.022).clamp(1.4, 4.2);
    final linerPath = Path()
      ..moveTo(innerX, lashY + archLift * 0.85)
      ..quadraticBezierTo(center.dx, lashY - archLift * 0.45, outerX, lashY + archLift * 0.65)
      ..quadraticBezierTo(
        outerX + outerDir * s * 0.014,
        lashY + archLift * 0.55,
        outerX + outerDir * s * 0.024,
        lashY + archLift * 0.10,
      );
    canvas.drawPath(linerPath, _strokePaint);

    // Soft delicate eyelid crease line right above open eye
    if (effectiveOpen > 0.55 && avatarSize != AvatarSize.xs) {
      _strokePaint
        ..color = AppColors.avatarSkinShade.withValues(alpha: 0.72)
        ..strokeWidth = (s * 0.007).clamp(0.5, 1.3);
      canvas.drawPath(
        Path()
          ..moveTo(scleraRect.left + s * 0.01, lashY - s * 0.012)
          ..quadraticBezierTo(center.dx, lashY - s * 0.032, scleraRect.right - s * 0.01, lashY - s * 0.012),
        _strokePaint,
      );
    }
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
      ..color = AppColors.avatarInk
      ..strokeWidth = strokeW;
    final rx = s * 0.052;
    final curveDelta = happyUp ? -s * 0.038 : s * 0.028;
    final yBase = center.dy + (happyUp ? s * 0.012 : 0.0);
    canvas.drawPath(
      Path()
        ..moveTo(center.dx - rx, yBase)
        ..quadraticBezierTo(center.dx, yBase + curveDelta, center.dx + rx, yBase),
      _strokePaint,
    );

    // Cute winged flick at outer corner
    final outerX = center.dx + outerDir * rx;
    canvas.drawLine(
      Offset(outerX, yBase),
      Offset(outerX + outerDir * s * 0.018, yBase - s * 0.014),
      _strokePaint,
    );
  }

  /// Sleek sculpted dark-charcoal arched Pixar eyebrows (right brow prominent
  /// above glasses; left brow sits naturally beneath the sweeping bangs).
  void _drawBrows(Canvas canvas, double s) {
    final raiseOffset = -expression.browRaise * s * 0.020;
    final tiltDelta = expression.browTilt * s * 0.018;
    final y = s * 0.312 + raiseOffset;

    _strokePaint
      ..color = AppColors.avatarHair
      ..strokeWidth = (s * 0.024).clamp(1.4, 4.5);

    // Viewer left eyebrow (partially tucked under side-swept bangs)
    canvas.drawPath(
      Path()
        ..moveTo(s * 0.33, y - tiltDelta * 0.4 + s * 0.010)
        ..quadraticBezierTo(s * 0.40, y - s * 0.018, s * 0.455, y + tiltDelta),
      _strokePaint,
    );

    // Viewer right eyebrow (prominently arched like reference!)
    canvas.drawPath(
      Path()
        ..moveTo(s * 0.545, y + tiltDelta)
        ..quadraticBezierTo(s * 0.615, y - s * 0.022, s * 0.672, y - tiltDelta * 0.4 + s * 0.016),
      _strokePaint,
    );
  }

  /// Adorable rosy-peach rounded Pixar button nose.
  void _drawNose(Canvas canvas, double s) {
    final center = Offset(s * 0.50, s * 0.478);

    // Soft cast shadow right underneath nose
    _fillPaint.color = AppColors.avatarSkinShade.withValues(alpha: 0.65);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + s * 0.014),
        width: s * 0.056,
        height: s * 0.020,
      ),
      _fillPaint,
    );

    // Rosy plump button nose bulb
    _fillPaint
      ..shader = _noseShader
      ..color = const Color(0xFFF19582);
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: s * 0.068,
        height: s * 0.044,
      ),
      _fillPaint,
    );
    _fillPaint.shader = null;

    // Soft specular sheen on top of nose
    _fillPaint.color = Colors.white.withValues(alpha: 0.35);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx - s * 0.008, center.dy - s * 0.008),
        width: s * 0.026,
        height: s * 0.014,
      ),
      _fillPaint,
    );
  }

  /// Full soft coral-peach Pixar lips for resting smile, seamlessly morphing
  /// into open "D" grin, talking vowels, yawn, or worried frown for expressions.
  void _drawMouth(Canvas canvas, double s) {
    final center = Offset(s * 0.50, s * 0.548);
    final openAmt = (expression.mouthOpen + frame.mouthTalkBoost).clamp(0.0, 1.0);
    final curve = expression.mouthCurve;

    if (frame.isYawning) {
      final rect = Rect.fromCenter(
        center: Offset(center.dx, center.dy + s * 0.008),
        width: s * 0.068,
        height: s * 0.088,
      );
      _fillPaint.color = const Color(0xFF7D3438);
      canvas.drawOval(rect, _fillPaint);
      _fillPaint.color = AppColors.avatarTongue;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(center.dx, rect.bottom - s * 0.020),
          width: s * 0.044,
          height: s * 0.028,
        ),
        _fillPaint,
      );
      return;
    }

    if (openAmt > 0.24 && curve > 0.45) {
      final talkNarrow = frame.talkShape * 0.22;
      final mouthW = s * (0.106 + openAmt * 0.032) * (1.0 - talkNarrow * 0.4);
      final mouthH = s * (0.044 + openAmt * 0.050) * (1.0 - talkNarrow);
      final topY = center.dy - mouthH * 0.34;
      final dPath = Path()
        ..moveTo(center.dx - mouthW * 0.5, topY)
        ..quadraticBezierTo(center.dx, topY + s * 0.007, center.dx + mouthW * 0.5, topY)
        ..cubicTo(
          center.dx + mouthW * 0.44,
          topY + mouthH * 1.12,
          center.dx - mouthW * 0.44,
          topY + mouthH * 1.12,
          center.dx - mouthW * 0.5,
          topY,
        )
        ..close();

      _fillPaint.color = const Color(0xFF7D3438);
      canvas.drawPath(dPath, _fillPaint);

      canvas.save();
      canvas.clipPath(dPath);
      _fillPaint.color = const Color(0xFFFFFCFA);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(center.dx, topY + mouthH * 0.14),
            width: mouthW * 0.84,
            height: mouthH * 0.26,
          ),
          Radius.circular(s * 0.012),
        ),
        _fillPaint,
      );
      _fillPaint.color = AppColors.avatarTongue;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(center.dx, topY + mouthH * 0.85),
          width: mouthW * 0.64,
          height: mouthH * 0.52,
        ),
        _fillPaint,
      );
      canvas.restore();
      return;
    }

    if (openAmt > 0.22) {
      final w = lerpDouble(s * 0.052, s * 0.078, frame.talkShape)!;
      final h = lerpDouble(s * (0.040 + openAmt * 0.042), s * 0.034, frame.talkShape)!;
      final rect = Rect.fromCenter(center: center, width: w, height: h);
      _fillPaint.color = const Color(0xFF7D3438);
      canvas.drawOval(rect, _fillPaint);
      _fillPaint.color = AppColors.avatarTongue;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(center.dx, rect.bottom - h * 0.24),
          width: w * 0.55,
          height: h * 0.34,
        ),
        _fillPaint,
      );
      return;
    }

    if (curve < -0.15) {
      _strokePaint
        ..color = AppColors.avatarMouth
        ..strokeWidth = (s * 0.017).clamp(1.2, 3.2);
      final halfW = s * 0.048;
      final amp = s * 0.013 * (-curve).clamp(0.3, 1.0);
      canvas.drawPath(
        Path()
          ..moveTo(center.dx - halfW, center.dy + amp * 0.5)
          ..quadraticBezierTo(center.dx - halfW * 0.5, center.dy - amp, center.dx, center.dy)
          ..quadraticBezierTo(center.dx + halfW * 0.5, center.dy + amp, center.dx + halfW, center.dy - amp * 0.4),
        _strokePaint,
      );
      return;
    }

    // Signature soft full coral-peach Pixar lips with gentle warm smile!
    final halfW = s * 0.068;
    final lift = curve.clamp(0.0, 1.0) * s * 0.016;
    final lowerLip = Path()
      ..moveTo(center.dx - halfW * 0.92, center.dy - lift * 0.5)
      ..quadraticBezierTo(center.dx, center.dy + s * 0.042, center.dx + halfW * 0.92, center.dy - lift * 0.5)
      ..quadraticBezierTo(center.dx, center.dy + s * 0.008, center.dx - halfW * 0.92, center.dy - lift * 0.5)
      ..close();
    _fillPaint.color = const Color(0xFFF08B73);
    canvas.drawPath(lowerLip, _fillPaint);

    final upperLip = Path()
      ..moveTo(center.dx - halfW * 0.88, center.dy - lift * 0.5)
      ..quadraticBezierTo(center.dx, center.dy - s * 0.018, center.dx + halfW * 0.88, center.dy - lift * 0.5)
      ..quadraticBezierTo(center.dx, center.dy + s * 0.008, center.dx - halfW * 0.88, center.dy - lift * 0.5)
      ..close();
    _fillPaint.color = const Color(0xFFE0735D);
    canvas.drawPath(upperLip, _fillPaint);

    // Subtle lip crease + glossy lower-lip highlight
    _strokePaint
      ..color = const Color(0xFFB55444).withValues(alpha: 0.65)
      ..strokeWidth = (s * 0.008).clamp(0.6, 1.5);
    canvas.drawPath(
      Path()
        ..moveTo(center.dx - halfW, center.dy - lift * 0.65)
        ..quadraticBezierTo(center.dx, center.dy + s * 0.014, center.dx + halfW, center.dy - lift * 0.65),
      _strokePaint,
    );

    _fillPaint.color = Colors.white.withValues(alpha: 0.28);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + s * 0.019),
        width: s * 0.046,
        height: s * 0.011,
      ),
      _fillPaint,
    );
  }

  /// Iconic thick matte-black round-wayfarer eyeglasses with curved nose bridge,
  /// outer wing lugs, and soft semi-transparent glass lens sheen.
  void _drawGlasses(Canvas canvas, double s) {
    final lensW = s * 0.172;
    final lensH = s * 0.144;
    final leftCenter = Offset(s * 0.390, s * 0.422);
    final rightCenter = Offset(s * 0.610, s * 0.422);

    RRect buildLens(Offset c) => RRect.fromRectAndCorners(
      Rect.fromCenter(center: c, width: lensW, height: lensH),
      topLeft: Radius.circular(s * 0.056),
      topRight: Radius.circular(s * 0.056),
      bottomLeft: Radius.circular(s * 0.072),
      bottomRight: Radius.circular(s * 0.072),
    );

    final leftLens = buildLens(leftCenter);
    final rightLens = buildLens(rightCenter);

    // Subtle lens gloss reflection
    _fillPaint.color = Colors.white.withValues(alpha: 0.10);
    canvas.drawRRect(leftLens, _fillPaint);
    canvas.drawRRect(rightLens, _fillPaint);

    // Diagonal glass sheen streak inside right & left lenses
    if (avatarSize != AvatarSize.xs) {
      _strokePaint
        ..color = Colors.white.withValues(alpha: 0.22)
        ..strokeWidth = (s * 0.010).clamp(0.7, 1.8);
      for (final c in [leftCenter, rightCenter]) {
        canvas.drawLine(
          Offset(c.dx - lensW * 0.26, c.dy - lensH * 0.28),
          Offset(c.dx - lensW * 0.06, c.dy - lensH * 0.34),
          _strokePaint,
        );
      }
    }

    // Thick matte-black frame rims
    final frameW = (s * 0.019).clamp(1.4, 3.6);
    _strokePaint
      ..color = AppColors.avatarGlasses
      ..strokeWidth = frameW;
    canvas.drawRRect(leftLens, _strokePaint);
    canvas.drawRRect(rightLens, _strokePaint);

    // Curved keyhole nose bridge
    final bridgePath = Path()
      ..moveTo(leftCenter.dx + lensW * 0.48, leftCenter.dy - s * 0.018)
      ..quadraticBezierTo(s * 0.50, leftCenter.dy - s * 0.044, rightCenter.dx - lensW * 0.48, rightCenter.dy - s * 0.018);
    canvas.drawPath(bridgePath, _strokePaint);

    // Outer frame wing endpieces
    _strokePaint.strokeWidth = frameW * 1.15;
    canvas.drawLine(
      Offset(leftCenter.dx - lensW * 0.48, leftCenter.dy - s * 0.040),
      Offset(leftCenter.dx - lensW * 0.58, leftCenter.dy - s * 0.044),
      _strokePaint,
    );
    canvas.drawLine(
      Offset(rightCenter.dx + lensW * 0.48, rightCenter.dy - s * 0.040),
      Offset(rightCenter.dx + lensW * 0.58, rightCenter.dy - s * 0.044),
      _strokePaint,
    );

    // Subtle top-frame specular sheen so frames look 3D matte-plastic
    _strokePaint
      ..color = Colors.white.withValues(alpha: 0.16)
      ..strokeWidth = (s * 0.006).clamp(0.5, 1.1);
    canvas.drawLine(
      Offset(leftCenter.dx - lensW * 0.25, leftCenter.dy - lensH * 0.49),
      Offset(leftCenter.dx + lensW * 0.22, leftCenter.dy - lensH * 0.49),
      _strokePaint,
    );
    canvas.drawLine(
      Offset(rightCenter.dx - lensW * 0.22, rightCenter.dy - lensH * 0.49),
      Offset(rightCenter.dx + lensW * 0.25, rightCenter.dy - lensH * 0.49),
      _strokePaint,
    );
  }

  /// Deep side-swept glossy black bangs sweeping diagonally from upper-right
  /// part down over the viewer's left forehead & glasses rim, plus sleek
  /// framing bob sides.
  void _drawBangsAndBobSides(Canvas canvas, double s, Offset sway) {
    final partPivot = Offset(s * 0.58, s * 0.13);
    canvas.save();
    canvas.translate(partPivot.dx, partPivot.dy);
    canvas.rotate(-sway.dx * 0.55);
    canvas.translate(-partPivot.dx, -partPivot.dy + sway.dy * s * 0.16);

    _fillPaint
      ..shader = _hairFrontShader
      ..color = AppColors.avatarHair;

    // Main sweeping diagonal left-side bangs (signature look of reference!)
    final mainBang = Path()
      ..moveTo(s * 0.575, s * 0.125)
      ..cubicTo(s * 0.37, s * 0.085, s * 0.23, s * 0.21, s * 0.235, s * 0.385)
      ..quadraticBezierTo(s * 0.35, s * 0.38, s * 0.455, s * 0.34)
      ..cubicTo(s * 0.535, s * 0.30, s * 0.585, s * 0.22, s * 0.575, s * 0.125)
      ..close();
    canvas.drawPath(mainBang, _fillPaint);

    // Right side hair sweep curving neatly along right temple & glasses edge
    final rightSweep = Path()
      ..moveTo(s * 0.575, s * 0.125)
      ..cubicTo(s * 0.69, s * 0.13, s * 0.77, s * 0.25, s * 0.77, s * 0.44)
      ..quadraticBezierTo(s * 0.72, s * 0.43, s * 0.71, s * 0.35)
      ..cubicTo(s * 0.69, s * 0.26, s * 0.63, s * 0.20, s * 0.575, s * 0.165)
      ..close();
    canvas.drawPath(rightSweep, _fillPaint);
    _fillPaint.shader = null;

    // Delicate wispy strands grazing forehead above the bridge of the glasses
    _strokePaint
      ..color = AppColors.avatarHair
      ..strokeWidth = (s * 0.011).clamp(0.7, 2.0);
    canvas.drawPath(
      Path()
        ..moveTo(s * 0.555, s * 0.24)
        ..quadraticBezierTo(s * 0.535, s * 0.325, s * 0.455, s * 0.365),
      _strokePaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(s * 0.582, s * 0.19)
        ..quadraticBezierTo(s * 0.585, s * 0.27, s * 0.530, s * 0.335),
      _strokePaint,
    );

    // Luminous silky specular highlight band curving across the bangs
    _strokePaint
      ..color = AppColors.avatarHairHighlight.withValues(alpha: 0.55)
      ..strokeWidth = (s * 0.020).clamp(1.0, 3.6);
    canvas.drawPath(
      Path()
        ..moveTo(s * 0.30, s * 0.255)
        ..quadraticBezierTo(s * 0.41, s * 0.165, s * 0.545, s * 0.165),
      _strokePaint,
    );

    // Subtle dark parting line at the crown
    _strokePaint
      ..color = AppColors.avatarHairShade
      ..strokeWidth = (s * 0.010).clamp(0.6, 1.8);
    canvas.drawPath(
      Path()
        ..moveTo(s * 0.575, s * 0.115)
        ..quadraticBezierTo(s * 0.580, s * 0.155, s * 0.570, s * 0.195),
      _strokePaint,
    );

    canvas.restore();
  }

  /// Subtle glowing mood star pin tucked neatly near the right hair part so
  /// all 9 mood colors stay readable while preserving the clean bob silhouette.
  void _drawMoodAccent(Canvas canvas, double s, Offset sway) {
    final glowStrength = (expression.accentGlow * frame.accentPulse).clamp(
      0.0,
      1.1,
    );
    if (glowStrength < 0.08 && !frame.isQuestionAhoge) return;

    final pinCenter = Offset(
      s * 0.655 - sway.dx * s * 0.05,
      s * 0.235 + sway.dy * s * 0.10,
    );
    final starR = s * 0.032;

    if (glowStrength > 0.08) {
      final blurSigma = (s * 0.026).clamp(1.2, 4.8);
      _glowPaint
        ..color = expression.accentColor.withValues(
          alpha: (0.50 * glowStrength).clamp(0.0, 0.80),
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma);
      canvas.drawCircle(pinCenter, starR * (1.2 + glowStrength * 0.3), _glowPaint);
      _glowPaint.maskFilter = null;
    }

    canvas.save();
    canvas.translate(pinCenter.dx, pinCenter.dy);
    canvas.rotate(0.18 - sway.dx * 0.4);
    final starPath = _buildStarPath(starR, starR * 0.46);
    _fillPaint.color = Color.lerp(
      AppColors.avatarStarClip,
      expression.accentColor,
      (0.35 + expression.accentGlow * 0.5).clamp(0.0, 0.85),
    )!;
    canvas.drawPath(starPath, _fillPaint);
    _fillPaint.color = Colors.white.withValues(alpha: 0.85);
    canvas.drawCircle(Offset(-starR * 0.2, -starR * 0.2), starR * 0.2, _fillPaint);
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

    final leftShoulder = Offset(s * 0.26, s * 0.78);
    final rightShoulder = Offset(s * 0.74, s * 0.78);
    final leftHand = Offset(frame.leftHandPos.dx * s, frame.leftHandPos.dy * s);
    final rightHand = Offset(
      frame.rightHandPos.dx * s,
      frame.rightHandPos.dy * s,
    );

    _drawSweaterArm(
      canvas,
      s,
      shoulder: leftShoulder,
      hand: leftHand,
      isLeft: true,
      pose: effectivePose,
    );
    _drawSweaterArm(
      canvas,
      s,
      shoulder: rightShoulder,
      hand: rightHand,
      isLeft: false,
      pose: effectivePose,
    );
  }

  void _drawSweaterArm(
    Canvas canvas,
    double s, {
    required Offset shoulder,
    required Offset hand,
    required bool isLeft,
    required ArmPose pose,
  }) {
    final dir = hand - shoulder;
    final dist = dir.distance.clamp(s * 0.08, s * 0.44);
    final angle = math.atan2(dir.dy, dir.dx);
    final sleeveW = s * 0.128;
    final cuffOffset = (dist - s * 0.060).clamp(s * 0.04, dist);

    final clipSleeveAtRim = poseMode == AvatarPoseMode.peek;
    if (clipSleeveAtRim) {
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(-s * 0.1, 0, s * 1.1, s * 0.875));
    }

    canvas.save();
    canvas.translate(shoulder.dx, shoulder.dy);
    canvas.rotate(angle);

    final sleeveRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(-s * 0.04, -sleeveW * 0.5, cuffOffset + s * 0.04, sleeveW),
      Radius.circular(sleeveW * 0.48),
    );
    _fillPaint
      ..shader = _sweaterShader
      ..color = AppColors.avatarHood;
    canvas.drawRRect(sleeveRect, _fillPaint);
    _fillPaint.shader = null;

    // Matching navy-blue sleeve stripe near cuff
    _fillPaint.color = AppColors.avatarSweaterStripe;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          cuffOffset - s * 0.068,
          -sleeveW * 0.46,
          s * 0.032,
          sleeveW * 0.92,
        ),
        Radius.circular(s * 0.012),
      ),
      _fillPaint,
    );

    canvas.restore();
    if (clipSleeveAtRim) {
      canvas.restore();
    }

    // Soft Pixar hand
    final handRx = pose == ArmPose.peek ? s * 0.066 : s * 0.056;
    final handRy = pose == ArmPose.peek ? s * 0.050 : s * 0.058;

    canvas.save();
    canvas.translate(hand.dx, hand.dy);
    if (pose == ArmPose.chin && !isLeft) {
      canvas.rotate(-0.32);
    } else if (pose == ArmPose.peek) {
      canvas.rotate(isLeft ? 0.15 : -0.15);
    }

    if (pose == ArmPose.peek || (pose == ArmPose.chin && isLeft)) {
      _fillPaint.color = AppColors.avatarInk.withValues(alpha: 0.10);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, s * 0.012),
          width: handRx * 1.9,
          height: handRy * 1.7,
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

    if (avatarSize == AvatarSize.md || avatarSize == AvatarSize.lg) {
      _strokePaint
        ..color = AppColors.avatarSkinShade.withValues(alpha: 0.60)
        ..strokeWidth = (s * 0.0075).clamp(0.6, 1.4);
      canvas.drawLine(
        Offset(-handRx * 0.24, handRy * 0.18),
        Offset(-handRx * 0.20, handRy * 0.70),
        _strokePaint,
      );
      canvas.drawLine(
        Offset(handRx * 0.18, handRy * 0.18),
        Offset(handRx * 0.22, handRy * 0.70),
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
