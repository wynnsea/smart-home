import 'dart:ui' show lerpDouble;

import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import 'avatar_mood.dart';

/// Interpolatable facial & body expression parameters for chibi "Wynn" v2.
@immutable
class AvatarExpression {
  const AvatarExpression({
    required this.eyeOpen,
    required this.eyeShape,
    required this.browTilt,
    required this.browRaise,
    required this.mouthCurve,
    required this.mouthOpen,
    required this.blush,
    required this.ahogePerk,
    required this.armPose,
    required this.accentColor,
    required this.accentGlow,
    this.headTilt = 0.0,
    this.winkRight = false,
  });

  /// 0.0 (closed line) .. 1.0 (fully open)
  final double eyeOpen;
  final EyeShape eyeShape;

  /// -1.0 (worried / outer down) .. +1.0 (focused / angled inward)
  final double browTilt;

  /// -1.0 (low) .. +1.0 (raised)
  final double browRaise;

  /// -1.0 (frown) .. +1.0 (big smile)
  final double mouthCurve;

  /// 0.0 (closed) .. 1.0 (open "o" / wide grin)
  final double mouthOpen;

  /// 0.0 .. 1.0 blush cheek intensity (> 0.6 draws anime blush lines)
  final double blush;

  /// 0.0 (droopy) .. 1.0 (perky upright ahoge strand)
  final double ahogePerk;

  final ArmPose armPose;

  /// Accent glow color for the star hair clip & ahoge shimmer.
  final Color accentColor;

  /// 0.0 .. 1.0 star clip glow intensity.
  final double accentGlow;

  /// -1.0 .. +1.0 sideways head tilt (e.g. +0.35 for chin/thinking/wink).
  final double headTilt;

  /// True when winking with the right eye closed while left stays open.
  final bool winkRight;

  AvatarExpression copyWith({
    double? eyeOpen,
    EyeShape? eyeShape,
    double? browTilt,
    double? browRaise,
    double? mouthCurve,
    double? mouthOpen,
    double? blush,
    double? ahogePerk,
    ArmPose? armPose,
    Color? accentColor,
    double? accentGlow,
    double? headTilt,
    bool? winkRight,
  }) {
    return AvatarExpression(
      eyeOpen: eyeOpen ?? this.eyeOpen,
      eyeShape: eyeShape ?? this.eyeShape,
      browTilt: browTilt ?? this.browTilt,
      browRaise: browRaise ?? this.browRaise,
      mouthCurve: mouthCurve ?? this.mouthCurve,
      mouthOpen: mouthOpen ?? this.mouthOpen,
      blush: blush ?? this.blush,
      ahogePerk: ahogePerk ?? this.ahogePerk,
      armPose: armPose ?? this.armPose,
      accentColor: accentColor ?? this.accentColor,
      accentGlow: accentGlow ?? this.accentGlow,
      headTilt: headTilt ?? this.headTilt,
      winkRight: winkRight ?? this.winkRight,
    );
  }

  static AvatarExpression lerp(
    AvatarExpression a,
    AvatarExpression b,
    double t,
  ) {
    final clamped = t.clamp(0.0, 1.0);
    if (clamped == 0.0) return a;
    if (clamped == 1.0) return b;
    return AvatarExpression(
      eyeOpen: lerpDouble(a.eyeOpen, b.eyeOpen, clamped)!,
      eyeShape: clamped < 0.5 ? a.eyeShape : b.eyeShape,
      browTilt: lerpDouble(a.browTilt, b.browTilt, clamped)!,
      browRaise: lerpDouble(a.browRaise, b.browRaise, clamped)!,
      mouthCurve: lerpDouble(a.mouthCurve, b.mouthCurve, clamped)!,
      mouthOpen: lerpDouble(a.mouthOpen, b.mouthOpen, clamped)!,
      blush: lerpDouble(a.blush, b.blush, clamped)!,
      ahogePerk: lerpDouble(a.ahogePerk, b.ahogePerk, clamped)!,
      armPose: clamped < 0.5 ? a.armPose : b.armPose,
      accentColor: Color.lerp(a.accentColor, b.accentColor, clamped)!,
      accentGlow: lerpDouble(a.accentGlow, b.accentGlow, clamped)!,
      headTilt: lerpDouble(a.headTilt, b.headTilt, clamped)!,
      winkRight: clamped < 0.5 ? a.winkRight : b.winkRight,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AvatarExpression &&
        other.eyeOpen == eyeOpen &&
        other.eyeShape == eyeShape &&
        other.browTilt == browTilt &&
        other.browRaise == browRaise &&
        other.mouthCurve == mouthCurve &&
        other.mouthOpen == mouthOpen &&
        other.blush == blush &&
        other.ahogePerk == ahogePerk &&
        other.armPose == armPose &&
        other.accentColor == accentColor &&
        other.accentGlow == accentGlow &&
        other.headTilt == headTilt &&
        other.winkRight == winkRight;
  }

  @override
  int get hashCode => Object.hash(
    eyeOpen,
    eyeShape,
    browTilt,
    browRaise,
    mouthCurve,
    mouthOpen,
    blush,
    ahogePerk,
    armPose,
    accentColor,
    accentGlow,
    headTilt,
    winkRight,
  );
}

/// Base expression preset for each [AvatarMood] following Wynn v2 spec §2.7.
const Map<AvatarMood, AvatarExpression> kMoodExpressions = {
  AvatarMood.idle: AvatarExpression(
    eyeOpen: 1.0,
    eyeShape: EyeShape.normal,
    browTilt: 0.0,
    browRaise: 0.05,
    mouthCurve: 0.55,
    mouthOpen: 0.0,
    blush: 0.38,
    ahogePerk: 0.55,
    armPose: ArmPose.peek,
    accentColor: AppColors.avatarStarClip,
    accentGlow: 0.45,
    headTilt: 0.04,
  ),
  AvatarMood.listening: AvatarExpression(
    eyeOpen: 1.0,
    eyeShape: EyeShape.wide,
    browTilt: 0.0,
    browRaise: 0.5,
    mouthCurve: 0.55,
    mouthOpen: 0.24,
    blush: 0.45,
    ahogePerk: 1.0,
    armPose: ArmPose.peek,
    accentColor: AppColors.tintBlueFg,
    accentGlow: 0.72,
    headTilt: 0.08,
  ),
  AvatarMood.thinking: AvatarExpression(
    eyeOpen: 0.85,
    eyeShape: EyeShape.normal,
    browTilt: 0.4,
    browRaise: 0.1,
    mouthCurve: -0.05,
    mouthOpen: 0.05,
    blush: 0.24,
    ahogePerk: 0.45,
    armPose: ArmPose.chin,
    accentColor: AppColors.tintBlueFg,
    accentGlow: 0.75,
    headTilt: 0.35,
  ),
  AvatarMood.streaming: AvatarExpression(
    eyeOpen: 0.92,
    eyeShape: EyeShape.normal,
    browTilt: 0.12,
    browRaise: 0.18,
    mouthCurve: 0.5,
    mouthOpen: 0.34,
    blush: 0.4,
    ahogePerk: 0.75,
    armPose: ArmPose.type,
    accentColor: AppColors.primary,
    accentGlow: 0.9,
    headTilt: 0.0,
  ),
  AvatarMood.success: AvatarExpression(
    eyeOpen: 1.0,
    eyeShape: EyeShape.happy,
    browTilt: 0.0,
    browRaise: 0.65,
    mouthCurve: 1.0,
    mouthOpen: 0.58,
    blush: 0.78,
    ahogePerk: 1.0,
    armPose: ArmPose.cheer,
    accentColor: AppColors.tintGreenFg,
    accentGlow: 1.0,
    headTilt: -0.08,
  ),
  AvatarMood.error: AvatarExpression(
    eyeOpen: 1.0,
    eyeShape: EyeShape.wide,
    browTilt: -0.75,
    browRaise: 0.25,
    mouthCurve: -0.55,
    mouthOpen: 0.16,
    blush: 0.22,
    ahogePerk: 0.6,
    armPose: ArmPose.worry,
    accentColor: AppColors.tintAmberFg,
    accentGlow: 0.8,
    headTilt: -0.14,
  ),
  AvatarMood.offline: AvatarExpression(
    eyeOpen: 0.18,
    eyeShape: EyeShape.normal,
    browTilt: -0.3,
    browRaise: -0.25,
    mouthCurve: -0.15,
    mouthOpen: 0.0,
    blush: 0.14,
    ahogePerk: 0.0,
    armPose: ArmPose.rest,
    accentColor: AppColors.textMuted,
    accentGlow: 0.0,
    headTilt: -0.18,
  ),
  AvatarMood.connecting: AvatarExpression(
    eyeOpen: 0.92,
    eyeShape: EyeShape.normal,
    browTilt: 0.0,
    browRaise: 0.3,
    mouthCurve: 0.05,
    mouthOpen: 0.32,
    blush: 0.28,
    ahogePerk: 0.6,
    armPose: ArmPose.rest,
    accentColor: AppColors.tintAmberFg,
    accentGlow: 0.7,
    headTilt: 0.05,
  ),
  AvatarMood.sleepy: AvatarExpression(
    eyeOpen: 0.2,
    eyeShape: EyeShape.normal,
    browTilt: -0.22,
    browRaise: -0.32,
    mouthCurve: 0.05,
    mouthOpen: 0.0,
    blush: 0.3,
    ahogePerk: 0.05,
    armPose: ArmPose.rest,
    accentColor: AppColors.avatarStarClip,
    accentGlow: 0.15,
    headTilt: 0.22,
  ),
};

/// Returns the target expression for a given [mood], adapting arm pose when
/// [poseMode] is [AvatarPoseMode.peek].
AvatarExpression expressionForMood(
  AvatarMood mood, {
  AvatarPoseMode poseMode = AvatarPoseMode.standing,
}) {
  final base = kMoodExpressions[mood]!;
  if (poseMode == AvatarPoseMode.peek &&
      (mood == AvatarMood.idle ||
          mood == AvatarMood.listening ||
          mood == AvatarMood.sleepy ||
          mood == AvatarMood.offline ||
          mood == AvatarMood.connecting)) {
    return base.copyWith(armPose: ArmPose.peek);
  }
  return base;
}

/// Applies transient [reaction] expression overrides onto a [base] expression.
AvatarExpression expressionForReaction(
  AvatarReaction reaction,
  AvatarExpression base,
) {
  return switch (reaction) {
    AvatarReaction.boop => base.copyWith(
      eyeShape: EyeShape.squeeze,
      eyeOpen: 0.85,
      browRaise: 0.25,
      mouthCurve: 0.65,
      mouthOpen: 0.15,
      blush: 0.92,
      ahogePerk: 1.0,
      accentGlow: 0.9,
      headTilt: -0.1,
    ),
    // Reference signature pose: wink + hand supporting cheek!
    AvatarReaction.wink => base.copyWith(
      eyeShape: EyeShape.normal,
      eyeOpen: 1.0,
      winkRight: true,
      browRaise: 0.35,
      mouthCurve: 0.9,
      mouthOpen: 0.44,
      blush: 0.72,
      ahogePerk: 0.85,
      armPose: ArmPose.chin,
      headTilt: 0.34,
      accentGlow: 0.88,
    ),
    AvatarReaction.giggle => base.copyWith(
      eyeShape: EyeShape.happy,
      eyeOpen: 1.0,
      browRaise: 0.55,
      mouthCurve: 1.0,
      mouthOpen: 0.48,
      blush: 0.9,
      ahogePerk: 0.95,
      armPose: ArmPose.coverMouth,
      headTilt: 0.16,
      accentGlow: 0.95,
    ),
    AvatarReaction.pet => base.copyWith(
      eyeShape: EyeShape.happy,
      eyeOpen: 1.0,
      browTilt: -0.1,
      browRaise: 0.35,
      mouthCurve: 0.95,
      mouthOpen: 0.14,
      blush: 1.0,
      ahogePerk: 0.8,
      armPose: ArmPose.peek,
      accentColor: AppColors.avatarBlush,
      accentGlow: 0.92,
      headTilt: 0.18,
    ),
    AvatarReaction.wave => base.copyWith(
      eyeShape: EyeShape.happy,
      eyeOpen: 1.0,
      browRaise: 0.45,
      mouthCurve: 0.85,
      mouthOpen: 0.36,
      blush: 0.58,
      ahogePerk: 0.85,
      armPose: ArmPose.wave,
      headTilt: -0.1,
      accentGlow: 0.82,
    ),
    AvatarReaction.nod => base.copyWith(
      eyeShape: EyeShape.happy,
      eyeOpen: 0.95,
      browRaise: 0.25,
      mouthCurve: 0.72,
      mouthOpen: 0.0,
      blush: 0.48,
      ahogePerk: 0.65,
      accentGlow: 0.7,
    ),
    AvatarReaction.success => kMoodExpressions[AvatarMood.success]!,
    AvatarReaction.errorShake => kMoodExpressions[AvatarMood.error]!,
    AvatarReaction.startle => base.copyWith(
      eyeShape: EyeShape.wide,
      eyeOpen: 1.0,
      browTilt: -0.2,
      browRaise: 0.9,
      mouthCurve: 0.0,
      mouthOpen: 0.55,
      blush: 0.42,
      ahogePerk: 1.0,
      accentColor: AppColors.tintBlueFg,
      accentGlow: 0.95,
      headTilt: 0.0,
    ),
  };
}
