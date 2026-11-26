import 'package:material_ui/material_ui.dart';

import '../controllers/avatar_frame.dart';
import '../painters/avatar_effects_painter.dart';
import '../painters/chibi_body_painter.dart';
import 'avatar_renderer.dart';

/// Default 100% procedural 3D-clay chibi anime girl renderer for "Wynn" v2
/// (zero external assets required; automatically used when layered sprite
/// assets are not bundled).
class ChibiProceduralRenderer implements AvatarRenderer {
  const ChibiProceduralRenderer();

  @override
  AvatarRendererKind get kind => AvatarRendererKind.procedural;

  @override
  Widget build(BuildContext context, AvatarRenderInput input) {
    final bodyPainter =
        input.bodyPainter ??
        ChibiBodyPainter(
          motionController: input.motionController,
          staticExpression: input.expression,
          staticFrame: AvatarFrame.staticForPose(
            input.expression.armPose,
            headTilt: input.expression.headTilt,
          ),
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
