import 'package:material_ui/material_ui.dart';

import '../../domain/avatar_mood.dart';

enum AvatarParticleKind {
  sparkle,
  heart,
  sweat,
  sleepZ,
  thinkingDot,
}

/// Active visual effect particle rendered in [AvatarEffectsPainter].
@immutable
class AvatarParticle {
  const AvatarParticle({
    required this.kind,
    required this.position,
    required this.velocity,
    required this.age,
    required this.lifetime,
    required this.scale,
    required this.color,
    this.rotation = 0.0,
    this.label,
  });

  /// Normalized position relative to avatar box (0..1, may overflow slightly).
  final Offset position;
  final Offset velocity;
  final AvatarParticleKind kind;
  final double age;
  final double lifetime;
  final double scale;
  final Color color;
  final double rotation;
  final String? label;

  double get progress => lifetime <= 0 ? 1.0 : (age / lifetime).clamp(0.0, 1.0);

  double get opacity {
    final p = progress;
    if (p < 0.15) return (p / 0.15).clamp(0.0, 1.0);
    if (p > 0.72) return ((1.0 - p) / 0.28).clamp(0.0, 1.0);
    return 1.0;
  }

  AvatarParticle copyWith({
    Offset? position,
    Offset? velocity,
    double? age,
    double? scale,
    double? rotation,
  }) {
    return AvatarParticle(
      kind: kind,
      position: position ?? this.position,
      velocity: velocity ?? this.velocity,
      age: age ?? this.age,
      lifetime: lifetime,
      scale: scale ?? this.scale,
      color: color,
      rotation: rotation ?? this.rotation,
      label: label,
    );
  }
}

/// Target normalized hand centers `(leftHand, rightHand)` for each [ArmPose].
(Offset left, Offset right) handTargetsForPose(ArmPose pose) {
  return switch (pose) {
    ArmPose.rest => (const Offset(0.15, 0.72), const Offset(0.85, 0.72)),
    ArmPose.peek => (const Offset(0.25, 0.90), const Offset(0.75, 0.90)),
    ArmPose.chin => (const Offset(0.17, 0.74), const Offset(0.62, 0.75)),
    ArmPose.wave => (const Offset(0.16, 0.73), const Offset(0.85, 0.34)),
    ArmPose.cheer => (const Offset(0.14, 0.31), const Offset(0.86, 0.31)),
    ArmPose.type => (const Offset(0.31, 0.80), const Offset(0.69, 0.80)),
    ArmPose.worry => (const Offset(0.24, 0.65), const Offset(0.76, 0.65)),
  };
}

/// Per-frame kinematic values passed to [AvatarBodyPainter].
@immutable
class AvatarFrame {
  const AvatarFrame({
    this.breatheScaleY = 1.0,
    this.floatY = 0.0,
    this.headTiltZ = 0.0,
    this.shakeX = 0.0,
    this.tilt = Offset.zero,
    this.pupilOffset = Offset.zero,
    this.squashX = 1.0,
    this.squashY = 1.0,
    this.antennaOffset = Offset.zero,
    this.antennaPulse = 1.0,
    this.blinkAmount = 0.0,
    this.mouthTalkBoost = 0.0,
    this.leftHandPos = const Offset(0.15, 0.72),
    this.rightHandPos = const Offset(0.85, 0.72),
    this.bodyScale = 1.0,
  });

  factory AvatarFrame.staticForPose(ArmPose armPose) {
    final (left, right) = handTargetsForPose(armPose);
    return AvatarFrame(
      leftHandPos: left,
      rightHandPos: right,
    );
  }

  final double breatheScaleY;

  /// Normalized vertical float offset (-0.05..+0.05 of size).
  final double floatY;

  /// 2D head tilt around Z axis (radians).
  final double headTiltZ;

  /// Normalized horizontal shake offset (-0.04..+0.04 of size).
  final double shakeX;

  /// 3D drag tilt (-0.35..+0.35 rad) for Matrix4 perspective transform.
  final Offset tilt;

  /// Normalized pupil shift (-0.035..+0.035 of size).
  final Offset pupilOffset;

  final double squashX;
  final double squashY;

  /// Spring-lagged antenna tip offset (normalized -0.10..+0.10 of size).
  final Offset antennaOffset;

  /// Multiplier for antenna orb glow pulse (0.6..1.3).
  final double antennaPulse;

  /// 0.0 = eyes open, 1.0 = eyes fully closed by blink.
  final double blinkAmount;

  /// Extra mouth opening during streaming speech / yawn (0..0.8).
  final double mouthTalkBoost;

  /// Current interpolated normalized hand coordinates.
  final Offset leftHandPos;
  final Offset rightHandPos;

  /// Subtle forward lean scale (e.g. 1.04 when listening).
  final double bodyScale;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AvatarFrame &&
        other.breatheScaleY == breatheScaleY &&
        other.floatY == floatY &&
        other.headTiltZ == headTiltZ &&
        other.shakeX == shakeX &&
        other.tilt == tilt &&
        other.pupilOffset == pupilOffset &&
        other.squashX == squashX &&
        other.squashY == squashY &&
        other.antennaOffset == antennaOffset &&
        other.antennaPulse == antennaPulse &&
        other.blinkAmount == blinkAmount &&
        other.mouthTalkBoost == mouthTalkBoost &&
        other.leftHandPos == leftHandPos &&
        other.rightHandPos == rightHandPos &&
        other.bodyScale == bodyScale;
  }

  @override
  int get hashCode => Object.hash(
    breatheScaleY,
    floatY,
    headTiltZ,
    shakeX,
    tilt,
    pupilOffset,
    squashX,
    squashY,
    antennaOffset,
    antennaPulse,
    blinkAmount,
    mouthTalkBoost,
    leftHandPos,
    rightHandPos,
    bodyScale,
  );
}
