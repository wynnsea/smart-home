import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../domain/avatar_expression.dart';
import '../../domain/avatar_mood.dart';
import '../controllers/avatar_frame.dart';
import '../controllers/avatar_motion_controller.dart';
import '../renderers/layered_sprite_renderer.dart';

/// CustomPainter for [LayeredSpriteRenderer] that composites pre-decoded
/// 1024×1024 PNG layers with live motion from [AvatarMotionController]:
/// hair/ahoge spring rotation around layer pivots, clipped iris gaze tracking,
/// head tilt, breathing, tinted star clip, and animated arm micro-motion.
class SpriteAvatarPainter extends CustomPainter {
  SpriteAvatarPainter({
    required this.manifest,
    required this.images,
    this.motionController,
    this.staticExpression,
    this.staticFrame,
    required this.avatarSize,
    this.poseMode = AvatarPoseMode.standing,
  }) : super(repaint: motionController);

  final AvatarSpriteManifest manifest;
  final Map<String, ui.Image> images;
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

  final Paint _imagePaint = Paint()..filterQuality = FilterQuality.medium;
  final Paint _alphaPaint = Paint()..filterQuality = FilterQuality.medium;
  final Paint _tintPaint = Paint()..filterQuality = FilterQuality.medium;
  final Paint _maskPaint = Paint()
    ..blendMode = BlendMode.dstIn
    ..filterQuality = FilterQuality.medium;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (s <= 0) return;

    final canvasDim = manifest.canvasSize;
    final destRect = Rect.fromLTWH(0, 0, canvasDim, canvasDim);
    final sway = avatarSize.swayHair ? frame.hairSwayOffset : Offset.zero;

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    _applyFraming(canvas, s, canvasDim);

    // 1. Contact shadow
    if (poseMode == AvatarPoseMode.standing && avatarSize != AvatarSize.xs) {
      final lift = (-frame.floatY).clamp(-0.04, 0.06);
      final shadowScale = (1.0 - lift * 2.5).clamp(0.78, 1.10);
      canvas.save();
      canvas.translate(canvasDim * 0.5, canvasDim * 0.94);
      canvas.scale(shadowScale, shadowScale);
      canvas.translate(-canvasDim * 0.5, -canvasDim * 0.94);
      _drawLayer(canvas, 'shadow.png', destRect);
      canvas.restore();
    }

    // Body root transform (float, shake, squash, breathing)
    final bodyPivot = Offset(canvasDim * 0.5, canvasDim * 0.78);
    canvas.save();
    canvas.translate(frame.shakeX * canvasDim, frame.floatY * canvasDim);
    canvas.translate(bodyPivot.dx, bodyPivot.dy);
    canvas.scale(
      frame.squashX * frame.bodyScale,
      frame.squashY * frame.breatheScaleY * frame.bodyScale,
    );
    canvas.translate(-bodyPivot.dx, -bodyPivot.dy);

    // 2 & 3. Back hair & bun behind hoodie
    _drawPivotedLayer(canvas, 'hair_back', 'hair_back.png', destRect, -sway.dx);
    _drawPivotedLayer(canvas, 'hair_bun', 'hair_bun.png', destRect, -sway.dx);

    // 4. Hoodie torso
    _drawLayer(canvas, 'body_hoodie.png', destRect);

    // 5..14. Head & facial stack around headPivot
    final headPivot = manifest.headPivot;
    canvas.save();
    canvas.translate(headPivot.dx, headPivot.dy);
    canvas.rotate(frame.headTiltZ);
    canvas.translate(-headPivot.dx, -headPivot.dy);

    _drawLayer(canvas, 'head_base.png', destRect);
    if (expression.blush > 0.02) {
      _alphaPaint.color = Colors.white.withValues(
        alpha: expression.blush.clamp(0.0, 1.0),
      );
      _drawLayer(canvas, 'blush.png', destRect, paint: _alphaPaint);
    }

    _drawEyesLayer(canvas, destRect);
    _drawBrowsLayer(canvas, destRect, canvasDim);
    _drawMouthLayer(canvas, destRect);

    _drawPivotedLayer(
      canvas,
      'hair_side_left',
      'hair_side_left.png',
      destRect,
      -sway.dx * 0.8,
      defaultPivot: Offset(canvasDim * 0.28, canvasDim * 0.34),
    );
    _drawPivotedLayer(
      canvas,
      'hair_side_right',
      'hair_side_right.png',
      destRect,
      -sway.dx * 0.8,
      defaultPivot: Offset(canvasDim * 0.72, canvasDim * 0.34),
    );
    _drawPivotedLayer(canvas, 'hair_bangs', 'hair_bangs.png', destRect, -sway.dx);
    _drawPivotedLayer(
      canvas,
      'ahoge',
      'ahoge.png',
      destRect,
      sway.dx + (1.0 - expression.ahogePerk) * 0.25,
    );
    _drawStarClipLayer(canvas, destRect);

    canvas.restore();

    // 15. Arms layer
    _drawArmsLayer(canvas, destRect, canvasDim);

    canvas.restore();
    canvas.restore();
  }

  void _applyFraming(Canvas canvas, double s, double canvasDim) {
    final framing = manifest.framing[avatarSize];
    final baseScale = s / canvasDim;
    if (framing == null) {
      canvas.scale(baseScale, baseScale);
      return;
    }
    canvas.translate(s * 0.5, s * 0.5);
    canvas.scale(baseScale * framing.scale, baseScale * framing.scale);
    canvas.translate(-framing.center.dx, -framing.center.dy);
  }

  void _drawEyesLayer(Canvas canvas, Rect destRect) {
    final requested = selectEyeVariant(expression, frame.blinkAmount);
    if (requested != 'open') {
      final resolved = manifest.resolveVariant('eyes', requested);
      final fileName = 'eyes_$resolved.png';
      if (images.containsKey(fileName)) {
        _drawLayer(canvas, fileName, destRect);
        return;
      }
    }

    // Composite open eyes: eye_white + gaze-shifted iris clipped by eye_mask + 30%-lag highlight
    _drawLayer(canvas, 'eye_white.png', destRect);
    final irisImg = images['iris.png'];
    if (irisImg != null) {
      final maxOffset =
          manifest.layers['iris']?.maxOffset ?? const Offset(22, 14);
      final shift = Offset(
        (frame.pupilOffset.dx / 0.035).clamp(-1.0, 1.0) * maxOffset.dx,
        (frame.pupilOffset.dy / 0.035).clamp(-1.0, 1.0) * maxOffset.dy,
      );

      final maskImg = images['eye_mask.png'];
      if (maskImg != null) {
        canvas.saveLayer(destRect, Paint());
        canvas.save();
        canvas.translate(shift.dx, shift.dy);
        _drawImage(canvas, irisImg, destRect, _imagePaint);
        canvas.restore();
        _drawImage(canvas, maskImg, destRect, _maskPaint);
        canvas.restore();
      } else {
        canvas.save();
        canvas.translate(shift.dx, shift.dy);
        _drawImage(canvas, irisImg, destRect, _imagePaint);
        canvas.restore();
      }

      final highlightImg = images['eye_highlight.png'];
      if (highlightImg != null) {
        canvas.save();
        canvas.translate(shift.dx * 0.30, shift.dy * 0.30);
        _drawImage(canvas, highlightImg, destRect, _imagePaint);
        canvas.restore();
      }
    }
  }

  void _drawBrowsLayer(Canvas canvas, Rect destRect, double canvasDim) {
    final requested = selectBrowVariant(expression);
    final resolved = manifest.resolveVariant(
      'brows',
      requested,
      fallback: 'neutral',
    );
    final dy = -expression.browRaise * canvasDim * 0.014;
    canvas.save();
    canvas.translate(0, dy);
    _drawLayer(canvas, 'brows_$resolved.png', destRect);
    canvas.restore();
  }

  void _drawMouthLayer(Canvas canvas, Rect destRect) {
    final requested = selectMouthVariant(expression, frame);
    final resolved = manifest.resolveVariant(
      'mouth',
      requested,
      fallback: 'smile',
    );
    _drawLayer(canvas, 'mouth_$resolved.png', destRect);
  }

  void _drawStarClipLayer(Canvas canvas, Rect destRect) {
    final img = images['star_clip.png'];
    if (img == null) return;
    _tintPaint.colorFilter = ColorFilter.mode(
      expression.accentColor,
      BlendMode.modulate,
    );
    _drawImage(canvas, img, destRect, _tintPaint);
  }

  void _drawArmsLayer(Canvas canvas, Rect destRect, double canvasDim) {
    if (avatarSize == AvatarSize.xs) return;
    final variant = selectArmVariant(expression.armPose, poseMode);
    if (avatarSize == AvatarSize.sm &&
        variant != 'peek' &&
        variant != 'cheer' &&
        variant != 'chin') {
      return;
    }

    final resolved = manifest.resolveVariant('arms', variant, fallback: 'peek');
    final fileName = 'arms_$resolved.png';
    if (!images.containsKey(fileName)) return;

    // Subtle procedural secondary animation on top of static arm pose sprites (§3 Fase C)
    canvas.save();
    if (variant == 'wave') {
      final pivot = Offset(canvasDim * 0.78, canvasDim * 0.62);
      final delta = (frame.rightHandPos.dx - 0.84) * 3.2;
      canvas.translate(pivot.dx, pivot.dy);
      canvas.rotate(delta.clamp(-0.22, 0.22));
      canvas.translate(-pivot.dx, -pivot.dy);
    } else if (variant == 'type') {
      final dy = (frame.leftHandPos.dy - 0.86) * canvasDim * 0.35;
      canvas.translate(0, dy.clamp(-14.0, 14.0));
    } else if (variant == 'cheer') {
      final dy = math.sin(frame.leftHandPos.dy * 12.0) * canvasDim * 0.01;
      canvas.translate(0, dy);
    }
    _drawLayer(canvas, fileName, destRect);
    canvas.restore();
  }

  void _drawPivotedLayer(
    Canvas canvas,
    String layerKey,
    String fallbackFile,
    Rect destRect,
    double swayAngleBase, {
    Offset? defaultPivot,
  }) {
    final cfg = manifest.layers[layerKey];
    final file = cfg?.file ?? fallbackFile;
    final img = images[file];
    if (img == null) return;

    final swayMult = cfg?.sway ?? 1.0;
    final pivot = cfg?.pivot ?? defaultPivot;
    if (pivot == null || swayAngleBase == 0.0) {
      _drawImage(canvas, img, destRect, _imagePaint);
      return;
    }

    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(swayAngleBase * swayMult);
    canvas.translate(-pivot.dx, -pivot.dy);
    _drawImage(canvas, img, destRect, _imagePaint);
    canvas.restore();
  }

  void _drawLayer(
    Canvas canvas,
    String fileName,
    Rect destRect, {
    Paint? paint,
  }) {
    final img = images[fileName];
    if (img == null) return;
    _drawImage(canvas, img, destRect, paint ?? _imagePaint);
  }

  void _drawImage(Canvas canvas, ui.Image image, Rect destRect, Paint paint) {
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    canvas.drawImageRect(image, src, destRect, paint);
  }

  @override
  bool shouldRepaint(covariant SpriteAvatarPainter oldDelegate) {
    if (motionController != null || oldDelegate.motionController != null) {
      return oldDelegate.motionController != motionController ||
          oldDelegate.avatarSize != avatarSize ||
          oldDelegate.poseMode != poseMode ||
          oldDelegate.manifest != manifest;
    }
    return oldDelegate.expression != expression ||
        oldDelegate.frame != frame ||
        oldDelegate.avatarSize != avatarSize ||
        oldDelegate.poseMode != poseMode ||
        oldDelegate.manifest != manifest;
  }
}
