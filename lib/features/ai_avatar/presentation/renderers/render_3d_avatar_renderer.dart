import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/avatar_mood.dart';
import '../painters/avatar_effects_painter.dart';
import 'avatar_renderer.dart';

const String kWynn3dAssetBase = 'assets/avatar/wynn_3d';

/// High-fidelity 3D-rendered figurine avatar renderer for Wynn.
///
/// Maps semantic [AvatarMood] and touch [AvatarReaction] to bespoke 3D-rendered
/// transparent PNG expression figurines with live 3D perspective tilt,
/// gentle breathing float, spring squish, and mood particle overlays.
class Render3dAvatarRenderer implements AvatarRenderer {
  const Render3dAvatarRenderer({
    required this.availableAssets,
    this.baseDir = kWynn3dAssetBase,
  });

  final Set<String> availableAssets;
  final String baseDir;

  @override
  AvatarRendererKind get kind => AvatarRendererKind.glb;

  bool get isReady => availableAssets.contains('$baseDir/idle.png');

  static Future<Render3dAvatarRenderer?> tryLoad({
    AssetBundle? bundle,
    String baseDir = kWynn3dAssetBase,
  }) async {
    final effectiveBundle = bundle ?? rootBundle;
    Set<String> bundledAssets;
    try {
      final assetManifest = await AssetManifest.loadFromAssetBundle(
        effectiveBundle,
      );
      bundledAssets = assetManifest.listAssets().toSet();
    } catch (_) {
      return null;
    }

    final found = bundledAssets
        .where((path) => path.startsWith('$baseDir/') && path.endsWith('.png'))
        .toSet();
    if (!found.contains('$baseDir/idle.png')) {
      return null;
    }
    return Render3dAvatarRenderer(availableAssets: found, baseDir: baseDir);
  }

  /// Resolves the best 3D figurine PNG asset path for [mood] and [reaction].
  String assetPathFor(AvatarMood mood, AvatarReaction? reaction) {
    final desiredName = switch (reaction) {
      AvatarReaction.boop ||
      AvatarReaction.errorShake ||
      AvatarReaction.startle => 'pout',
      AvatarReaction.giggle ||
      AvatarReaction.pet ||
      AvatarReaction.success => 'happy',
      AvatarReaction.wave ||
      AvatarReaction.wink ||
      AvatarReaction.nod => 'talking',
      null => switch (mood) {
        AvatarMood.error || AvatarMood.offline => 'pout',
        AvatarMood.success => 'happy',
        AvatarMood.thinking || AvatarMood.connecting => 'thinking',
        AvatarMood.streaming => 'talking',
        AvatarMood.sleepy => 'sleepy',
        AvatarMood.idle || AvatarMood.listening => 'idle',
      },
    };

    final candidate = '$baseDir/$desiredName.png';
    if (availableAssets.contains(candidate)) {
      return candidate;
    }
    return '$baseDir/idle.png';
  }

  @override
  Widget build(BuildContext context, AvatarRenderInput input) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final motion = input.motionController;
    final effectsPainter =
        input.effectsPainter ??
        AvatarEffectsPainter(motionController: input.motionController);

    Widget buildFigurine({
      required String assetPath,
      double floatY = 0,
      double shakeX = 0,
      double tiltX = 0,
      double tiltY = 0,
      double squishX = 1.0,
      double squishY = 1.0,
      double rotZ = 0,
    }) {
      final matrix = Matrix4.identity()
        ..setEntry(3, 2, 0.0022)
        ..rotateY(tiltX * 0.28)
        ..rotateX(-tiltY * 0.18)
        ..rotateZ(rotZ);

      final imageWidget = AnimatedSwitcher(
        duration: disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: Image.asset(
          assetPath,
          key: ValueKey<String>(assetPath),
          width: input.size,
          height: input.size,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
        ),
      );

      final showShadow = input.size >= 56;
      return SizedBox(
        width: input.size,
        height: input.size,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (showShadow)
              Positioned(
                bottom: input.size * 0.02,
                child: Container(
                  width: input.size * 0.50,
                  height: input.size * 0.08,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3E2D6E).withValues(alpha: 0.22),
                        blurRadius: input.size * 0.08,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            Transform.translate(
              offset: Offset(shakeX, floatY),
              child: Transform(
                alignment: Alignment.center,
                transform: matrix,
                child: Transform.scale(
                  scaleX: squishX,
                  scaleY: squishY,
                  child: imageWidget,
                ),
              ),
            ),
            if (input.avatarSize.maxParticles > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: effectsPainter),
                ),
              ),
          ],
        ),
      );
    }

    if (motion == null || disableAnimations) {
      return RepaintBoundary(
        child: buildFigurine(
          assetPath: assetPathFor(input.mood, input.reaction),
        ),
      );
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: motion,
        builder: (context, _) {
          final frame = motion.frame;
          final liveReaction = motion.activeLocalReaction ?? input.reaction;
          final liveMood = motion.effectiveMood;
          final assetPath = assetPathFor(liveMood, liveReaction);
          final bobPx = (frame.floatY * input.size * 0.04).clamp(-6.0, 6.0);
          final shakePx = (frame.shakeX * input.size * 0.05).clamp(-8.0, 8.0);
          return buildFigurine(
            assetPath: assetPath,
            floatY: bobPx,
            shakeX: shakePx,
            tiltX: frame.tilt.dx,
            tiltY: frame.tilt.dy,
            squishX: frame.squashX,
            squishY: frame.squashY * frame.breatheScaleY,
            rotZ: frame.headTiltZ * 0.45,
          );
        },
      ),
    );
  }
}
