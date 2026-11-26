import 'package:material_ui/material_ui.dart';

import 'avatar_renderer.dart';
import 'procedural_avatar_renderer.dart';

/// Optional Rive 2.5D/clay renderer slot (recommended for lightweight rigged clay art).
///
/// Because the `rive` package is intentionally not added in Phases 1–6, this slot
/// always delegates safely to [fallback] ([ProceduralAvatarRenderer]) without crashing.
///
/// ### How to connect Rive later:
/// 1. Add `rive` to `pubspec.yaml` and bundle your `.riv` file under `assets/avatar/wynn.riv`.
/// 2. Export a Rive State Machine named **`"Wynn"`** with these inputs:
///    - `mood` (`SMIInput<double>` / Number) = `input.mood.index.toDouble()`
///    - `tiltX` (`SMIInput<double>` / Number, range `-1.0..1.0`) = `(input.tilt.dx / 0.35).clamp(-1.0, 1.0)`
///    - `tiltY` (`SMIInput<double>` / Number, range `-1.0..1.0`) = `(input.tilt.dy / 0.35).clamp(-1.0, 1.0)`
///    - `lookX` (`SMIInput<double>` / Number, range `-1.0..1.0`) = `(input.lookAt.dx / 0.035).clamp(-1.0, 1.0)`
///    - `lookY` (`SMIInput<double>` / Number, range `-1.0..1.0`) = `(input.lookAt.dy / 0.035).clamp(-1.0, 1.0)`
///    - Triggers (`SMITrigger`): `boop`, `wave`, `celebrate`, `shake`.
/// 3. Swap [build] to render `RiveAnimation.asset(assetPath, stateMachines: ['Wynn'], ...)`
///    and fall back to [fallback] if the asset fails to load.
class RiveAvatarSlot implements AvatarRenderer {
  const RiveAvatarSlot({
    required this.assetPath,
    this.fallback = const ProceduralAvatarRenderer(),
  });

  final String assetPath;
  final AvatarRenderer fallback;

  @override
  AvatarRendererKind get kind => AvatarRendererKind.rive;

  @override
  Widget build(BuildContext context, AvatarRenderInput input) {
    return fallback.build(context, input);
  }
}
