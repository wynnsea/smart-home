import 'package:material_ui/material_ui.dart';

import 'avatar_renderer.dart';
import 'procedural_avatar_renderer.dart';

/// Optional 3D GLB renderer slot for `model_viewer_plus`.
///
/// Because `model_viewer_plus` is intentionally not added in Phases 1–6, this slot
/// always delegates safely to [fallback] ([ProceduralAvatarRenderer]) without crashing.
///
/// ### Performance & integration notes for GLB later:
/// 1. `model_viewer_plus` embeds a WebView + WebGL context, which is noticeably heavier
///    on mid-range Android devices (like OPPO Reno8 4G). Use it **only** for
///    `AvatarSize.lg` on `AgentHubPage`, keeping [ProceduralAvatarRenderer] for
///    `xs` / `sm` / `md` instances.
/// 2. Bundle your `.glb` character model under `assets/avatar/wynn.glb` with these
///    expected named animation clips:
///    - `idle`
///    - `think`
///    - `talk`
///    - `cheer`
///    - `worry`
///    - `sleep`
/// 3. Map `input.mood` to the corresponding `animationName` and keep [fallback] for
///    non-`lg` sizes or when `MediaQuery.disableAnimationsOf(context)` is true.
class GlbAvatarSlot implements AvatarRenderer {
  const GlbAvatarSlot({
    required this.assetPath,
    this.fallback = const ProceduralAvatarRenderer(),
  });

  final String assetPath;
  final AvatarRenderer fallback;

  @override
  AvatarRendererKind get kind => AvatarRendererKind.glb;

  @override
  Widget build(BuildContext context, AvatarRenderInput input) {
    return fallback.build(context, input);
  }
}
