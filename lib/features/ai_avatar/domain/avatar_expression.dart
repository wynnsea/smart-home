import 'dart:ui' show lerpDouble;

import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import 'avatar_mood.dart';

/// Interpolatable facial & body expression parameters for "Wynn".
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
    required this.earPerk,
    required this.armPose,
    required this.antennaColor,
    required this.antennaGlow,
    this.winkRight = false,
  });

  /// 0.0 (closed line) .. 1.0 (fully open)
  final double eyeOpen;
  final EyeShape eyeShape;

  /// -1.0 (worried / outer down) .. +1.0 (focused / angry inward)
  final double browTilt;

  /// -1.0 (low) .. +1.0 (raised)
  final double browRaise;

  /// -1.0 (frown) .. +1.0 (big smile)
  final double mouthCurve;

  /// 0.0 (closed) .. 1.0 (open "o")
  final double mouthOpen;

  /// 0.0 .. 1.0 blush cheek intensity
  final double blush;

  /// 0.0 .. 1.0 hoodie ear perk lift
  final double earPerk;

  final ArmPose armPose;
  final Color antennaColor;

  /// 0.0 .. 1.0 antenna orb glow strength
  final double antennaGlow;

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
    double? earPerk,
    ArmPose? armPose,
    Color? antennaColor,
    double? antennaGlow,
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
      earPerk: earPerk ?? this.earPerk,
      armPose: armPose ?? this.armPose,
      antennaColor: antennaColor ?? this.antennaColor,
      antennaGlow: antennaGlow ?? this.antennaGlow,
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
      earPerk: lerpDouble(a.earPerk, b.earPerk, clamped)!,
      armPose: clamped < 0.5 ? a.armPose : b.armPose,
      antennaColor: Color.lerp(a.antennaColor, b.antennaColor, clamped)!,
      antennaGlow: lerpDouble(a.antennaGlow, b.antennaGlow, clamped)!,
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
        other.earPerk == earPerk &&
        other.armPose == armPose &&
        other.antennaColor == antennaColor &&
        other.antennaGlow == antennaGlow &&
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
    earPerk,
    armPose,
    antennaColor,
    antennaGlow,
    winkRight,
  );
}

/// Base expression preset for each [AvatarMood] following spec Table 1.4.
const Map<AvatarMood, AvatarExpression> kMoodExpressions = {
  AvatarMood.idle: AvatarExpression(
    eyeOpen: 1.0,
    eyeShape: EyeShape.normal,
    browTilt: 0.0,
    browRaise: 0.0,
    mouthCurve: 0.35,
    mouthOpen: 0.0,
    blush: 0.28,
    earPerk: 0.25,
    armPose: ArmPose.rest,
    antennaColor: AppColors.primaryLight,
    antennaGlow: 0.4,
  ),
  AvatarMood.listening: AvatarExpression(
    eyeOpen: 1.0,
    eyeShape: EyeShape.wide,
    browTilt: 0.0,
    browRaise: 0.5,
    mouthCurve: 0.6,
    mouthOpen: 0.15,
    blush: 0.35,
    earPerk: 0.95,
    armPose: ArmPose.peek,
    antennaColor: AppColors.tintBlueFg,
    antennaGlow: 0.6,
  ),
  AvatarMood.thinking: AvatarExpression(
    eyeOpen: 0.8,
    eyeShape: EyeShape.normal,
    browTilt: 0.4,
    browRaise: 0.1,
    mouthCurve: 0.0,
    mouthOpen: 0.0,
    blush: 0.18,
    earPerk: 0.35,
    armPose: ArmPose.chin,
    antennaColor: AppColors.tintBlueFg,
    antennaGlow: 0.72,
  ),
  AvatarMood.streaming: AvatarExpression(
    eyeOpen: 0.9,
    eyeShape: EyeShape.normal,
    browTilt: 0.1,
    browRaise: 0.15,
    mouthCurve: 0.45,
    mouthOpen: 0.32,
    blush: 0.32,
    earPerk: 0.55,
    armPose: ArmPose.type,
    antennaColor: AppColors.primary,
    antennaGlow: 0.85,
  ),
  AvatarMood.success: AvatarExpression(
    eyeOpen: 1.0,
    eyeShape: EyeShape.happy,
    browTilt: 0.0,
    browRaise: 0.6,
    mouthCurve: 1.0,
    mouthOpen: 0.4,
    blush: 0.72,
    earPerk: 1.0,
    armPose: ArmPose.cheer,
    antennaColor: AppColors.tintGreenFg,
    antennaGlow: 1.0,
  ),
  AvatarMood.error: AvatarExpression(
    eyeOpen: 1.0,
    eyeShape: EyeShape.wide,
    browTilt: -0.7,
    browRaise: 0.2,
    mouthCurve: -0.5,
    mouthOpen: 0.2,
    blush: 0.15,
    earPerk: 0.05,
    armPose: ArmPose.worry,
    antennaColor: AppColors.tintAmberFg,
    antennaGlow: 0.75,
  ),
  AvatarMood.offline: AvatarExpression(
    eyeOpen: 0.25,
    eyeShape: EyeShape.normal,
    browTilt: -0.3,
    browRaise: -0.25,
    mouthCurve: -0.1,
    mouthOpen: 0.0,
    blush: 0.08,
    earPerk: 0.0,
    armPose: ArmPose.rest,
    antennaColor: AppColors.textMuted,
    antennaGlow: 0.0,
  ),
  AvatarMood.connecting: AvatarExpression(
    eyeOpen: 0.9,
    eyeShape: EyeShape.normal,
    browTilt: 0.0,
    browRaise: 0.3,
    mouthCurve: 0.05,
    mouthOpen: 0.3,
    blush: 0.2,
    earPerk: 0.5,
    armPose: ArmPose.rest,
    antennaColor: AppColors.tintAmberFg,
    antennaGlow: 0.65,
  ),
  AvatarMood.sleepy: AvatarExpression(
    eyeOpen: 0.2,
    eyeShape: EyeShape.normal,
    browTilt: -0.2,
    browRaise: -0.3,
    mouthCurve: 0.05,
    mouthOpen: 0.0,
    blush: 0.22,
    earPerk: 0.0,
    armPose: ArmPose.rest,
    antennaColor: AppColors.primaryLight,
    antennaGlow: 0.15,
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
      blush: 0.82,
      earPerk: 0.85,
      antennaGlow: 0.85,
    ),
    AvatarReaction.wink => base.copyWith(
      eyeShape: EyeShape.normal,
      eyeOpen: 1.0,
      winkRight: true,
      browRaise: 0.35,
      mouthCurve: 0.85,
      mouthOpen: 0.1,
      blush: 0.72,
      earPerk: 0.8,
      armPose: ArmPose.wave,
      antennaGlow: 0.8,
    ),
    AvatarReaction.giggle => base.copyWith(
      eyeShape: EyeShape.happy,
      eyeOpen: 1.0,
      browRaise: 0.55,
      mouthCurve: 1.0,
      mouthOpen: 0.55,
      blush: 0.9,
      earPerk: 0.95,
      armPose: ArmPose.cheer,
      antennaGlow: 0.95,
    ),
    AvatarReaction.pet => base.copyWith(
      eyeShape: EyeShape.happy,
      eyeOpen: 1.0,
      browTilt: -0.1,
      browRaise: 0.35,
      mouthCurve: 0.95,
      mouthOpen: 0.2,
      blush: 1.0,
      earPerk: 0.7,
      armPose: ArmPose.rest,
      antennaColor: AppColors.avatarBlush,
      antennaGlow: 0.9,
    ),
    AvatarReaction.wave => base.copyWith(
      eyeShape: EyeShape.happy,
      eyeOpen: 1.0,
      browRaise: 0.45,
      mouthCurve: 0.85,
      mouthOpen: 0.22,
      blush: 0.55,
      earPerk: 0.85,
      armPose: ArmPose.wave,
      antennaGlow: 0.75,
    ),
    AvatarReaction.nod => base.copyWith(
      eyeShape: EyeShape.happy,
      eyeOpen: 0.95,
      browRaise: 0.25,
      mouthCurve: 0.7,
      mouthOpen: 0.0,
      blush: 0.45,
      earPerk: 0.6,
      antennaGlow: 0.65,
    ),
    AvatarReaction.success => kMoodExpressions[AvatarMood.success]!,
    AvatarReaction.errorShake => kMoodExpressions[AvatarMood.error]!,
    AvatarReaction.startle => base.copyWith(
      eyeShape: EyeShape.wide,
      eyeOpen: 1.0,
      browTilt: -0.2,
      browRaise: 0.85,
      mouthCurve: 0.0,
      mouthOpen: 0.55,
      blush: 0.4,
      earPerk: 1.0,
      antennaColor: AppColors.tintBlueFg,
      antennaGlow: 0.9,
    ),
  };
}
