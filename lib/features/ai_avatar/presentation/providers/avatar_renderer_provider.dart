import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../renderers/avatar_renderer.dart';
import '../renderers/chibi_procedural_renderer.dart';
import '../renderers/layered_sprite_renderer.dart';
import '../renderers/render_3d_avatar_renderer.dart';

/// Resolves the active [AvatarRenderer] with priority:
/// 1. [Render3dAvatarRenderer] when 3D figurine PNGs exist in `assets/avatar/wynn_3d/`
/// 2. [LayeredSpriteRenderer] when `assets/avatar/wynn/manifest.json` exists & decodes
/// 3. [ChibiProceduralRenderer] zero-asset procedural fallback
Future<AvatarRenderer> resolveAvatarRenderer({
  AssetBundle? bundle,
  String manifestPath = kDefaultSpriteManifestPath,
}) async {
  // When a custom bundle/manifest is passed (e.g. sprite manifest unit tests),
  // prioritize testing LayeredSpriteRenderer first.
  if (bundle != null || manifestPath != kDefaultSpriteManifestPath) {
    final spriteRenderer = await LayeredSpriteRenderer.tryLoad(
      bundle: bundle,
      manifestPath: manifestPath,
    );
    if (spriteRenderer != null) return spriteRenderer;
  }

  final render3d = await Render3dAvatarRenderer.tryLoad(bundle: bundle);
  if (render3d != null) return render3d;

  final spriteRenderer = await LayeredSpriteRenderer.tryLoad(
    bundle: bundle,
    manifestPath: manifestPath,
  );
  return spriteRenderer ?? const ChibiProceduralRenderer();
}

/// Automatically chooses the highest-fidelity bundled avatar renderer.
final avatarRendererProvider = FutureProvider<AvatarRenderer>((ref) async {
  return resolveAvatarRenderer();
});
