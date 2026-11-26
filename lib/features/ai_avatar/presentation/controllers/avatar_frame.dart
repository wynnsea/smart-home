import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/avatar_mood.dart';

enum AvatarParticleKind {
  sparkle,
  heart,
  sweat,
  sleepZ,
  thinkingDot,
  exclamation,
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
    ArmPose.rest => (const Offset(0.24, 0.84), const Offset(0.76, 0.84)),
    ArmPose.peek => (const Offset(0.42, 0.90), const Offset(0.68, 0.88)),
    ArmPose.chin => (const Offset(0.42, 0.90), const Offset(0.66, 0.59)),
    ArmPose.wave => (const Offset(0.26, 0.84), const Offset(0.84, 0.44)),
    ArmPose.cheer => (const Offset(0.16, 0.42), const Offset(0.84, 0.42)),
    ArmPose.type => (const Offset(0.35, 0.86), const Offset(0.65, 0.86)),
    ArmPose.worry => (const Offset(0.33, 0.65), const Offset(0.67, 0.65)),
    ArmPose.coverMouth => (const Offset(0.44, 0.64), const Offset(0.56, 0.64)),
  };
}

/// Per-frame kinematic values passed to [ChibiBodyPainter] & [SpriteAvatarPainter].
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
    this.hairSwayOffset = Offset.zero,
    this.accentPulse = 1.0,
    this.blinkAmount = 0.0,
    this.mouthTalkBoost = 0.0,
    this.talkShape = 0.0,
    this.isYawning = false,
    this.isQuestionAhoge = false,
    this.leftHandPos = const Offset(0.42, 0.90),
    this.rightHandPos = const Offset(0.68, 0.88),
    this.bodyScale = 1.0,
  });

  factory AvatarFrame.staticForPose(
    ArmPose armPose, {
    double headTilt = 0.0,
    bool isQuestionAhoge = false,
  }) {
    final (left, right) = handTargetsForPose(armPose);
    return AvatarFrame(
      headTiltZ: headTilt * 0.24,
      isQuestionAhoge: isQuestionAhoge,
      leftHandPos: left,
      rightHandPos: right,
    );
  }

  final double breatheScaleY;
  final double floatY;
  final double headTiltZ;
  final double shakeX;
  final Offset tilt;
  final Offset pupilOffset;
  final double squashX;
  final double squashY;

  /// Spring-lagged secondary motion vector shared by back hair (1.0),
  /// side strands (0.8), bun (0.7), bangs (0.6), and ahoge (1.4).
  final Offset hairSwayOffset;

  /// Multiplier for star clip glow pulse (0.5..1.3).
  final double accentPulse;

  final double blinkAmount;
  final double mouthTalkBoost;

  /// 0..1 alternating vowel blend during streaming speech (0 = "a", 1 = "i").
  final double talkShape;

  final bool isYawning;

  /// True in error mood so ahoge curls playfully into a "?" shape.
  final bool isQuestionAhoge;

  final Offset leftHandPos;
  final Offset rightHandPos;
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
        other.hairSwayOffset == hairSwayOffset &&
        other.accentPulse == accentPulse &&
        other.blinkAmount == blinkAmount &&
        other.mouthTalkBoost == mouthTalkBoost &&
        other.talkShape == talkShape &&
        other.isYawning == isYawning &&
        other.isQuestionAhoge == isQuestionAhoge &&
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
    hairSwayOffset,
    accentPulse,
    blinkAmount,
    mouthTalkBoost,
    talkShape,
    isYawning,
    isQuestionAhoge,
    leftHandPos,
    rightHandPos,
    bodyScale,
  );
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
        position: Offset(0.80, 0.34),
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
        position: Offset(0.84, 0.24),
        velocity: Offset.zero,
        age: 0.3,
        lifetime: 1.0,
        scale: 0.95,
        color: AppColors.textSecondary,
        label: 'zZ',
      ),
    ],
    _ => const [],
  };
}
