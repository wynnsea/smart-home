import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../renderers/avatar_renderer.dart';
import '../renderers/chibi_procedural_renderer.dart';
import '../renderers/layered_sprite_renderer.dart';

/// Resolves the active [AvatarRenderer]: uses [LayeredSpriteRenderer] if
/// `assets/avatar/wynn/manifest.json` is registered in [AssetManifest] and
/// decodes cleanly; otherwise falls back to [ChibiProceduralRenderer].
Future<AvatarRenderer> resolveAvatarRenderer({
  AssetBundle? bundle,
  String manifestPath = kDefaultSpriteManifestPath,
}) async {
  final spriteRenderer = await LayeredSpriteRenderer.tryLoad(
    bundle: bundle,
    manifestPath: manifestPath,
  );
  return spriteRenderer ?? const ChibiProceduralRenderer();
}

/// Automatically chooses between [LayeredSpriteRenderer] (when bundled PNG
/// sprite layers exist) and [ChibiProceduralRenderer] (zero-asset default).
final avatarRendererProvider = FutureProvider<AvatarRenderer>((ref) async {
  return resolveAvatarRenderer();
});
