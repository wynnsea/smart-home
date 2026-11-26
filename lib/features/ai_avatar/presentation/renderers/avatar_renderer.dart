import 'package:material_ui/material_ui.dart';

import '../../domain/avatar_expression.dart';
import '../../domain/avatar_mood.dart';
import '../controllers/avatar_motion_controller.dart';
import '../painters/avatar_effects_painter.dart';

/// Identifies which rendering backend draws the avatar visual.
enum AvatarRendererKind {
  procedural,
  layeredSprite,
  rive,
  glb,
}

/// Snapshot & live-painter binding delivered to an [AvatarRenderer].
@immutable
class AvatarRenderInput {
  const AvatarRenderInput({
    required this.mood,
    required this.expression,
    required this.tilt,
    required this.lookAt,
    required this.reaction,
    required this.size,
    required this.avatarSize,
    required this.poseMode,
    this.motionController,
    this.bodyPainter,
    this.effectsPainter,
  });

  final AvatarMood mood;
  final AvatarExpression expression;
  final Offset tilt;
  final Offset lookAt;
  final AvatarReaction? reaction;
  final double size;
  final AvatarSize avatarSize;
  final AvatarPoseMode poseMode;
  final AvatarMotionController? motionController;
  final CustomPainter? bodyPainter;
  final AvatarEffectsPainter? effectsPainter;
}

/// Pluggable visual renderer interface so procedural, layered-sprite, Rive,
/// or GLB backends can be swapped without modifying mood derivation or gestures.
abstract interface class AvatarRenderer {
  AvatarRendererKind get kind;

  Widget build(BuildContext context, AvatarRenderInput input);
}
