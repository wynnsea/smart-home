import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/avatar_expression.dart';
import '../../domain/avatar_mood.dart';
import '../controllers/avatar_frame.dart';
import '../controllers/avatar_motion_controller.dart';

/// Procedural 3D soft-clay painter for "Wynn" (anatomy layers 1–10).
/// Reads live values from [motionController] directly during [paint] so
/// frame ticks never trigger widget rebuilds, while also supporting static mode.
class AvatarBodyPainter extends CustomPainter {
  AvatarBodyPainter({
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
      AvatarFrame.staticForPose(expression.armPose);

  // Reusable paints (allocated once per painter instance)
  final Paint _shadowPaint = Paint()..style = PaintingStyle.fill;
  final Paint _stemPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..color = AppColors.avatarHoodDark;
  final Paint _glowPaint = Paint()..style = PaintingStyle.fill;
  final Paint _orbPaint = Paint()..style = PaintingStyle.fill;
  final Paint _bodyPaint = Paint()..style = PaintingStyle.fill;
  final Paint _bodyShadePaint = Paint()..style = PaintingStyle.fill;
  final Paint _highlightPaint = Paint()..style = PaintingStyle.fill;
  final Paint _facePaint = Paint()
    ..style = PaintingStyle.fill
    ..color = AppColors.avatarFace;
  final Paint _faceShadePaint = Paint()..style = PaintingStyle.fill;
  final Paint _blushPaint = Paint()..style = PaintingStyle.fill;
  final Paint _eyeFillPaint = Paint()
    ..style = PaintingStyle.fill
    ..color = AppColors.avatarInk;
  final Paint _eyeStrokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = AppColors.avatarInk;
  final Paint _browPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..color = AppColors.avatarInk.withValues(alpha: 0.78);
  final Paint _mouthFillPaint = Paint()
    ..style = PaintingStyle.fill
    ..color = AppColors.avatarMouth;
  final Paint _mouthStrokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..color = AppColors.avatarMouth;
  final Paint _tonguePaint = Paint()
    ..style = PaintingStyle.fill
    ..color = AppColors.avatarTongue;
  final Paint _handPaint = Paint()..style = PaintingStyle.fill;

  // Cached size-dependent geometry & shaders
  Size? _cachedSize;
  Shader? _hoodGradientShader;
  Shader? _hoodShadeShader;
  Shader? _faceInnerShadowShader;
  Color? _cachedAntennaColor;
  Shader? _antennaOrbShader;

  void _ensureShaders(Size size) {
    final s = size.shortestSide;
    if (_cachedSize != size) {
      _cachedSize = size;
      final bodyRect = Rect.fromCenter(
        center: Offset(s * 0.5, s * 0.56),
        width: s * 0.78,
        height: s * 0.74,
      );
      _hoodGradientShader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.avatarHoodLight, AppColors.avatarHood],
      ).createShader(bodyRect);

      _hoodShadeShader = RadialGradient(
        center: const Alignment(0.15, 0.95),
        radius: 0.85,
        colors: [
          AppColors.avatarHoodDark.withValues(alpha: 0.42),
          AppColors.avatarHoodDark.withValues(alpha: 0.0),
        ],
      ).createShader(bodyRect);

      final faceRect = Rect.fromCenter(
        center: Offset(s * 0.5, s * 0.60),
        width: s * 0.56,
        height: s * 0.46,
      );
      _faceInnerShadowShader = LinearGradient(
        begin: Alignment.topCenter,
        end: const Alignment(0, -0.15),
        colors: [
          AppColors.avatarHoodDark.withValues(alpha: 0.22),
          AppColors.avatarHoodDark.withValues(alpha: 0.0),
        ],
      ).createShader(faceRect);
    }

    if (_cachedAntennaColor != expression.antennaColor || _antennaOrbShader == null) {
      _cachedAntennaColor = expression.antennaColor;
      final orbRadius = s * 0.058;
      _antennaOrbShader = RadialGradient(
        center: const Alignment(-0.35, -0.35),
        radius: 0.95,
        colors: [
          Colors.white,
          expression.antennaColor,
          Color.lerp(expression.antennaColor, AppColors.avatarHoodDark, 0.35)!,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: orbRadius));
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (s <= 0) return;

    _ensureShaders(size);

    // 1. Contact shadow (hidden when peeking over a card edge)
    if (poseMode == AvatarPoseMode.standing) {
      final lift = (-frame.floatY).clamp(-0.04, 0.06);
      final shadowScale = (1.0 - lift * 3.0).clamp(0.75, 1.12);
      final shadowAlpha = (0.14 - lift * 0.7).clamp(0.08, 0.18);
      _shadowPaint.color = Colors.black.withValues(alpha: shadowAlpha);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(s * 0.5 + frame.shakeX * s * 0.5, s * 0.945),
          width: s * 0.56 * shadowScale,
          height: s * 0.08 * shadowScale,
        ),
        _shadowPaint,
      );
    }

    // Apply body float, shake, squash/stretch, breathing, and head Z-tilt
    final pivot = Offset(s * 0.5, s * 0.62);
    canvas.save();
    canvas.translate(
      frame.shakeX * s,
      frame.floatY * s,
    );
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(frame.headTiltZ);
    canvas.scale(
      frame.squashX * frame.bodyScale,
      frame.squashY * frame.breatheScaleY * frame.bodyScale,
    );
    canvas.translate(-pivot.dx, -pivot.dy);

    // 2. Antenna (stem + glowing AI orb bead)
    _paintAntenna(canvas, s);

    // 4. Hoodie ears (behind hood rim so seam feels seamless soft-clay)
    _paintHoodEars(canvas, s);

    // 3. Body / hoodie mochi superellipse (no outline, soft clay shading)
    _paintBody(canvas, s);

    // 5. Face oval + cozy hoodie inner top shadow
    _paintFace(canvas, s);

    // 6. Cheek blush
    _paintBlush(canvas, s);

    // 7. Eyes (with pupil tracking, blink, happy ^ ^, squeeze > <, wink)
    _paintEyes(canvas, s);

    // 8. Eyebrows
    _paintBrows(canvas, s);

    // 9. Mouth (smile/frown curve or open "o" with tongue)
    _paintMouth(canvas, s);

    canvas.restore();

    // 10. Hands / mittens (drawn outside head tilt for steady peek/type poses)
    if (avatarSize.showHands) {
      _paintHands(canvas, s);
    }
  }

  void _paintAntenna(Canvas canvas, double s) {
    final sway = avatarSize.swayAntenna ? frame.antennaOffset : Offset.zero;
    final base = Offset(s * 0.5, s * 0.22);
    final tip = Offset(
      s * 0.5 + sway.dx * s,
      s * 0.065 + sway.dy * s,
    );
    final control = Offset(
      s * 0.5 + sway.dx * s * 0.42,
      s * 0.135,
    );

    _stemPaint.strokeWidth = (s * 0.026).clamp(1.2, 6.0);
    final stemPath = Path()
      ..moveTo(base.dx, base.dy)
      ..quadraticBezierTo(control.dx, control.dy, tip.dx, tip.dy);
    canvas.drawPath(stemPath, _stemPaint);

    final orbRadius = s * 0.056;
    final glowStrength = (expression.antennaGlow * frame.antennaPulse).clamp(
      0.0,
      1.0,
    );
    if (glowStrength > 0.02) {
      final blurSigma = (s * 0.038).clamp(1.5, 6.5);
      _glowPaint
        ..color = expression.antennaColor.withValues(alpha: 0.58 * glowStrength)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma);
      canvas.drawCircle(tip, orbRadius * (1.35 + glowStrength * 0.35), _glowPaint);
      _glowPaint.maskFilter = null;
    }

    canvas.save();
    canvas.translate(tip.dx, tip.dy);
    _orbPaint.shader = _antennaOrbShader;
    canvas.drawCircle(Offset.zero, orbRadius, _orbPaint);
    // Tiny specular pin-light on orb
    _highlightPaint.color = Colors.white.withValues(alpha: 0.85);
    canvas.drawCircle(
      Offset(-orbRadius * 0.32, -orbRadius * 0.32),
      orbRadius * 0.24,
      _highlightPaint,
    );
    canvas.restore();
  }

  void _paintHoodEars(Canvas canvas, double s) {
    final perkLift = expression.earPerk * s * 0.042;
    final perkSpread = expression.earPerk * 0.14;
    _bodyPaint.shader = _hoodGradientShader;

    for (final side in [-1.0, 1.0]) {
      final earCenter = Offset(
        s * (0.5 + side * 0.27),
        s * 0.265 - perkLift,
      );
      canvas.save();
      canvas.translate(earCenter.dx, earCenter.dy);
      canvas.rotate(side * (0.42 - perkSpread));
      final earRect = Rect.fromCenter(
        center: Offset.zero,
        width: s * 0.16,
        height: s * 0.19,
      );
      canvas.drawOval(earRect, _bodyPaint);

      // Soft inner ear highlight
      _highlightPaint.color = Colors.white.withValues(alpha: 0.26);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(-side * s * 0.015, -s * 0.028),
          width: s * 0.065,
          height: s * 0.08,
        ),
        _highlightPaint,
      );
      canvas.restore();
    }
  }

  void _paintBody(Canvas canvas, double s) {
    final bodyRect = Rect.fromCenter(
      center: Offset(s * 0.5, s * 0.56),
      width: s * 0.78,
      height: s * 0.74,
    );
    // Soft mochi bean superellipse (rounder top, cozy plump bottom)
    final bodyRRect = RRect.fromRectAndCorners(
      bodyRect,
      topLeft: Radius.circular(s * 0.37),
      topRight: Radius.circular(s * 0.37),
      bottomLeft: Radius.circular(s * 0.33),
      bottomRight: Radius.circular(s * 0.33),
    );

    _bodyPaint.shader = _hoodGradientShader;
    canvas.drawRRect(bodyRRect, _bodyPaint);

    // Clip clay shading & specular highlight inside the body silhouette
    canvas.save();
    canvas.clipRRect(bodyRRect);

    _bodyShadePaint.shader = _hoodShadeShader;
    canvas.drawRect(bodyRect, _bodyShadePaint);

    // Soft clay specular highlight oval top-left
    canvas.save();
    canvas.translate(s * 0.31, s * 0.31);
    canvas.rotate(-0.48);
    _highlightPaint.color = Colors.white.withValues(alpha: 0.34);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: s * 0.22, height: s * 0.10),
      _highlightPaint,
    );
    canvas.restore();

    // Subtle hoodie cuff/drawstring rim beneath face
    final seamPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = (s * 0.014).clamp(0.8, 2.5)
      ..strokeCap = StrokeCap.round
      ..color = AppColors.avatarHoodDark.withValues(alpha: 0.22);
    final seamPath = Path()
      ..moveTo(s * 0.36, s * 0.845)
      ..quadraticBezierTo(s * 0.5, s * 0.88, s * 0.64, s * 0.845);
    canvas.drawPath(seamPath, seamPaint);

    canvas.restore();
  }

  void _paintFace(Canvas canvas, double s) {
    final faceRect = Rect.fromCenter(
      center: Offset(s * 0.5, s * 0.60),
      width: s * 0.56,
      height: s * 0.46,
    );
    final faceRRect = RRect.fromRectAndCorners(
      faceRect,
      topLeft: Radius.circular(s * 0.25),
      topRight: Radius.circular(s * 0.25),
      bottomLeft: Radius.circular(s * 0.22),
      bottomRight: Radius.circular(s * 0.22),
    );

    canvas.drawRRect(faceRRect, _facePaint);

    // Soft inner shadow along top edge (from overhanging hoodie rim)
    canvas.save();
    canvas.clipRRect(faceRRect);
    _faceShadePaint.shader = _faceInnerShadowShader;
    canvas.drawRect(faceRect, _faceShadePaint);
    canvas.restore();
  }

  void _paintBlush(Canvas canvas, double s) {
    final alpha = (expression.blush * 0.68).clamp(0.0, 0.7);
    if (alpha <= 0.01) return;

    final blurSigma = (s * 0.026).clamp(1.0, 5.0);
    _blushPaint
      ..color = AppColors.avatarBlush.withValues(alpha: alpha)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma);

    final y = s * 0.655;
    for (final side in [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(s * (0.5 + side * 0.165), y),
          width: s * 0.115,
          height: s * 0.068,
        ),
        _blushPaint,
      );
    }
    _blushPaint.maskFilter = null;
  }

  void _paintEyes(Canvas canvas, double s) {
    final eyeY = s * 0.575;
    final eyeSpacing = s * 0.125;
    final gazeShift = Offset(
      frame.pupilOffset.dx.clamp(-0.035, 0.035) * s,
      frame.pupilOffset.dy.clamp(-0.035, 0.035) * s,
    );
    final effectiveOpen = (expression.eyeOpen * (1.0 - frame.blinkAmount)).clamp(
      0.0,
      1.0,
    );

    _eyeStrokePaint.strokeWidth = (s * 0.032).clamp(1.6, 5.5);

    for (var i = 0; i < 2; i++) {
      final isRight = i == 1;
      final side = isRight ? 1.0 : -1.0;
      final center = Offset(
        s * 0.5 + side * eyeSpacing + gazeShift.dx,
        eyeY + gazeShift.dy,
      );

      // Wink on right eye
      if (isRight && expression.winkRight) {
        final w = s * 0.068;
        final winkPath = Path()
          ..moveTo(center.dx - w * 0.7, center.dy + s * 0.005)
          ..quadraticBezierTo(
            center.dx,
            center.dy - s * 0.042,
            center.dx + w * 0.7,
            center.dy + s * 0.008,
          );
        canvas.drawPath(winkPath, _eyeStrokePaint);
        continue;
      }

      if (expression.eyeShape == EyeShape.happy) {
        final w = s * 0.068;
        final arcPath = Path()
          ..moveTo(center.dx - w * 0.72, center.dy + s * 0.015)
          ..quadraticBezierTo(
            center.dx,
            center.dy - s * 0.052,
            center.dx + w * 0.72,
            center.dy + s * 0.015,
          );
        canvas.drawPath(arcPath, _eyeStrokePaint);
        continue;
      }

      if (expression.eyeShape == EyeShape.squeeze) {
        final r = s * 0.046;
        final chevron = Path();
        if (!isRight) {
          // ">"
          chevron
            ..moveTo(center.dx - r, center.dy - r * 0.75)
            ..lineTo(center.dx + r * 0.7, center.dy)
            ..lineTo(center.dx - r, center.dy + r * 0.75);
        } else {
          // "<"
          chevron
            ..moveTo(center.dx + r, center.dy - r * 0.75)
            ..lineTo(center.dx - r * 0.7, center.dy)
            ..lineTo(center.dx + r, center.dy + r * 0.75);
        }
        canvas.drawPath(chevron, _eyeStrokePaint);
        continue;
      }

      // Normal or wide eye (collapses to soft sleepy/blink line at low open)
      if (effectiveOpen < 0.14) {
        final w = s * 0.062;
        final closedPath = Path()
          ..moveTo(center.dx - w * 0.75, center.dy)
          ..quadraticBezierTo(
            center.dx,
            center.dy + s * 0.022,
            center.dx + w * 0.75,
            center.dy,
          );
        canvas.drawPath(closedPath, _eyeStrokePaint);
        continue;
      }

      final wideBoost = expression.eyeShape == EyeShape.wide ? 1.16 : 1.0;
      final eyeW = s * 0.078 * wideBoost;
      final eyeH = s * 0.098 * wideBoost * effectiveOpen;
      final eyeRect = Rect.fromCenter(center: center, width: eyeW, height: eyeH);
      canvas.drawOval(eyeRect, _eyeFillPaint);

      // 2 crisp specular white highlights (large top-left, small bottom-right)
      if (effectiveOpen > 0.35) {
        _highlightPaint.color = Colors.white.withValues(alpha: 0.95);
        canvas.drawCircle(
          Offset(center.dx - eyeW * 0.19, center.dy - eyeH * 0.22),
          (eyeW * 0.22).clamp(1.0, 7.0),
          _highlightPaint,
        );
        if (s >= 42) {
          _highlightPaint.color = Colors.white.withValues(alpha: 0.80);
          canvas.drawCircle(
            Offset(center.dx + eyeW * 0.20, center.dy + eyeH * 0.22),
            (eyeW * 0.11).clamp(0.7, 3.5),
            _highlightPaint,
          );
        }
      }
    }
  }

  void _paintBrows(Canvas canvas, double s) {
    final browY = s * 0.492 - expression.browRaise * s * 0.028;
    final browSpacing = s * 0.125;
    final halfW = s * 0.042;
    _browPaint.strokeWidth = (s * 0.022).clamp(1.2, 4.0);

    for (final side in [-1.0, 1.0]) {
      final center = Offset(s * 0.5 + side * browSpacing, browY);
      // browTilt: -1 worried (outer down), +1 focused (inner down)
      final angle = -side * expression.browTilt * 0.34;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);
      canvas.drawLine(Offset(-halfW, 0), Offset(halfW, 0), _browPaint);
      canvas.restore();
    }
  }

  void _paintMouth(Canvas canvas, double s) {
    final center = Offset(s * 0.5, s * 0.692);
    final open = (expression.mouthOpen + frame.mouthTalkBoost).clamp(0.0, 1.0);
    final curve = expression.mouthCurve.clamp(-1.0, 1.0);
    final halfW = s * (0.062 + open * 0.018);

    if (open < 0.08) {
      _mouthStrokePaint.strokeWidth = (s * 0.024).clamp(1.3, 4.2);
      final controlY = center.dy + curve * s * 0.052;
      final path = Path()
        ..moveTo(center.dx - halfW, center.dy - curve * s * 0.012)
        ..quadraticBezierTo(
          center.dx,
          controlY,
          center.dx + halfW,
          center.dy - curve * s * 0.012,
        );
      canvas.drawPath(path, _mouthStrokePaint);
      return;
    }

    // Open mouth (cute rounded "D" or "o" depending on smile curve)
    final mouthH = s * (0.042 + open * 0.068);
    final topY = center.dy - mouthH * 0.38;
    final botY = center.dy + mouthH * 0.62;

    final mouthPath = Path();
    if (curve >= 0.15) {
      // Happy D-shaped open smile
      mouthPath
        ..moveTo(center.dx - halfW, topY)
        ..quadraticBezierTo(center.dx, topY - curve * s * 0.012, center.dx + halfW, topY)
        ..quadraticBezierTo(center.dx + halfW * 0.9, botY, center.dx, botY)
        ..quadraticBezierTo(center.dx - halfW * 0.9, botY, center.dx - halfW, topY)
        ..close();
    } else {
      // Rounded "o" or worried open oval
      final rect = Rect.fromCenter(
        center: Offset(center.dx, center.dy + (curve < -0.2 ? s * 0.01 : 0)),
        width: halfW * 1.45,
        height: mouthH,
      );
      mouthPath.addOval(rect);
    }

    canvas.drawPath(mouthPath, _mouthFillPaint);

    // Cute little tongue peek inside open mouth
    if (open > 0.18) {
      canvas.save();
      canvas.clipPath(mouthPath);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(center.dx, botY),
          width: halfW * 1.25,
          height: mouthH * 0.72,
        ),
        _tonguePaint,
      );
      canvas.restore();
    }
  }

  void _paintHands(Canvas canvas, double s) {
    final handRadius = s * 0.082;
    final hands = [frame.leftHandPos, frame.rightHandPos];

    for (var i = 0; i < 2; i++) {
      final pos = Offset(
        hands[i].dx * s + frame.shakeX * s * 0.5,
        hands[i].dy * s +
            (poseMode == AvatarPoseMode.peek ? 0.0 : frame.floatY * s * 0.65),
      );

      // Soft drop shadow beneath peeking mittens
      if (poseMode == AvatarPoseMode.peek || expression.armPose == ArmPose.peek) {
        _shadowPaint.color = AppColors.avatarHoodDark.withValues(alpha: 0.22);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(pos.dx, pos.dy + handRadius * 0.72),
            width: handRadius * 1.8,
            height: handRadius * 0.55,
          ),
          _shadowPaint,
        );
      }

      _handPaint.shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        radius: 1.0,
        colors: const [
          AppColors.avatarHoodLight,
          AppColors.avatarHood,
          AppColors.avatarHoodDark,
        ],
        stops: const [0.0, 0.68, 1.0],
      ).createShader(Rect.fromCircle(center: pos, radius: handRadius));

      canvas.drawOval(
        Rect.fromCenter(
          center: pos,
          width: handRadius * 2.05,
          height: handRadius * 1.78,
        ),
        _handPaint,
      );

      // Soft clay highlight dot on mitten
      _highlightPaint.color = Colors.white.withValues(alpha: 0.36);
      canvas.drawCircle(
        Offset(pos.dx - handRadius * 0.28, pos.dy - handRadius * 0.28),
        handRadius * 0.28,
        _highlightPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant AvatarBodyPainter oldDelegate) {
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

/// Generates subtle static mood indicator particles for Reduce Motion or static preview.
List<AvatarParticle> staticParticlesForMood(AvatarMood mood) {
  return switch (mood) {
    AvatarMood.success => const [
      AvatarParticle(
        kind: AvatarParticleKind.sparkle,
        position: Offset(0.14, 0.22),
        velocity: Offset.zero,
        age: 0.3,
        lifetime: 1.0,
        scale: 1.0,
        color: AppColors.tintGreenFg,
      ),
      AvatarParticle(
        kind: AvatarParticleKind.sparkle,
        position: Offset(0.86, 0.18),
        velocity: Offset.zero,
        age: 0.3,
        lifetime: 1.0,
        scale: 0.85,
        color: AppColors.primary,
      ),
    ],
    AvatarMood.error => const [
      AvatarParticle(
        kind: AvatarParticleKind.sweat,
        position: Offset(0.80, 0.36),
        velocity: Offset.zero,
        age: 0.3,
        lifetime: 1.0,
        scale: 1.0,
        color: AppColors.tintBlueFg,
      ),
    ],
    AvatarMood.thinking => const [
      AvatarParticle(
        kind: AvatarParticleKind.thinkingDot,
        position: Offset(0.88, 0.24),
        velocity: Offset.zero,
        age: 0.3,
        lifetime: 1.0,
        scale: 1.0,
        color: AppColors.tintBlueFg,
      ),
    ],
    AvatarMood.offline || AvatarMood.sleepy => const [
      AvatarParticle(
        kind: AvatarParticleKind.sleepZ,
        position: Offset(0.84, 0.22),
        velocity: Offset.zero,
        age: 0.3,
        lifetime: 1.0,
        scale: 1.0,
        color: AppColors.textSecondary,
        label: 'zZ',
      ),
    ],
    _ => const [],
  };
}
