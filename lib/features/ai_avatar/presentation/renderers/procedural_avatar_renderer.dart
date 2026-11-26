import 'package:material_ui/material_ui.dart';

import '../controllers/avatar_frame.dart';
import '../painters/avatar_body_painter.dart';
import '../painters/avatar_effects_painter.dart';
import 'avatar_renderer.dart';

/// Default 100% procedural CustomPainter renderer for "Wynn" (zero assets).
class ProceduralAvatarRenderer implements AvatarRenderer {
  const ProceduralAvatarRenderer();

  @override
  AvatarRendererKind get kind => AvatarRendererKind.procedural;

  @override
  Widget build(BuildContext context, AvatarRenderInput input) {
    final bodyPainter =
        input.bodyPainter ??
        AvatarBodyPainter(
          motionController: input.motionController,
          staticExpression: input.expression,
          staticFrame: AvatarFrame.staticForPose(input.expression.armPose),
          avatarSize: input.avatarSize,
          poseMode: input.poseMode,
        );
    final effectsPainter =
        input.effectsPainter ??
        AvatarEffectsPainter(
          motionController: input.motionController,
        );

    return SizedBox(
      width: input.size,
      height: input.size,
      child: CustomPaint(
        painter: bodyPainter,
        foregroundPainter: effectsPainter,
      ),
    );
  }
}
