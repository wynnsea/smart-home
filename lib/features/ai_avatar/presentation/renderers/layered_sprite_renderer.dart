import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/avatar_expression.dart';
import '../../domain/avatar_mood.dart';
import '../controllers/avatar_frame.dart';
import '../painters/avatar_effects_painter.dart';
import '../painters/sprite_avatar_painter.dart';
import 'avatar_renderer.dart';
import 'chibi_procedural_renderer.dart';

const String kDefaultSpriteManifestPath = 'assets/avatar/wynn/manifest.json';

/// Configuration for a single movable sprite layer inside `manifest.json`.
@immutable
class SpriteLayerConfig {
  const SpriteLayerConfig({
    required this.file,
    this.pivot,
    this.sway = 0.0,
    this.maxOffset,
  });

  factory SpriteLayerConfig.fromJson(Map<String, dynamic> json) {
    final file = json['file'];
    if (file is! String || file.trim().isEmpty) {
      throw const FormatException('Layer entry missing non-empty "file".');
    }
    return SpriteLayerConfig(
      file: file,
      pivot: _parseOffsetOrNull(json['pivot']),
      sway: (json['sway'] as num?)?.toDouble() ?? 0.0,
      maxOffset: _parseOffsetOrNull(json['maxOffset']),
    );
  }

  final String file;
  final Offset? pivot;
  final double sway;
  final Offset? maxOffset;
}

/// Framing zoom & center point per [AvatarSize] in sprite canvas coordinates.
@immutable
class SpriteFraming {
  const SpriteFraming({required this.center, required this.scale});

  factory SpriteFraming.fromJson(Map<String, dynamic> json) {
    final center = _parseOffsetOrNull(json['center']);
    final scale = (json['scale'] as num?)?.toDouble();
    if (center == null || scale == null || scale <= 0) {
      throw const FormatException('Invalid framing entry in manifest.');
    }
    return SpriteFraming(center: center, scale: scale);
  }

  final Offset center;
  final double scale;
}

/// Parsed representation of `assets/avatar/wynn/manifest.json` (§4.3).
@immutable
class AvatarSpriteManifest {
  const AvatarSpriteManifest({
    required this.version,
    required this.canvasSize,
    required this.layers,
    required this.variants,
    required this.headPivot,
    required this.framing,
    this.baseDir = 'assets/avatar/wynn',
  });

  factory AvatarSpriteManifest.fromJson(
    Map<String, dynamic> json, {
    String baseDir = 'assets/avatar/wynn',
  }) {
    final version = (json['version'] as num?)?.toInt();
    final canvas = (json['canvas'] as num?)?.toDouble();
    if (version == null || version < 1 || canvas == null || canvas <= 0) {
      throw const FormatException('Invalid manifest "version" or "canvas".');
    }

    final rawLayers = json['layers'];
    if (rawLayers is! Map<String, dynamic>) {
      throw const FormatException('Manifest missing "layers" map.');
    }
    final layers = <String, SpriteLayerConfig>{
      for (final entry in rawLayers.entries)
        if (entry.value is Map<String, dynamic>)
          entry.key: SpriteLayerConfig.fromJson(
            entry.value as Map<String, dynamic>,
          ),
    };

    final rawVariants = json['variants'];
    if (rawVariants is! Map<String, dynamic>) {
      throw const FormatException('Manifest missing "variants" map.');
    }
    final variants = <String, List<String>>{
      for (final entry in rawVariants.entries)
        if (entry.value is List)
          entry.key: [
            for (final item in entry.value as List)
              if (item is String && item.isNotEmpty) item,
          ],
    };

    final headPivot =
        _parseOffsetOrNull(json['headPivot']) ??
        Offset(canvas * 0.5, canvas * 0.55);

    final framing = <AvatarSize, SpriteFraming>{};
    final rawFraming = json['framing'];
    if (rawFraming is Map<String, dynamic>) {
      for (final size in AvatarSize.values) {
        final item = rawFraming[size.name];
        if (item is Map<String, dynamic>) {
          framing[size] = SpriteFraming.fromJson(item);
        }
      }
    }

    return AvatarSpriteManifest(
      version: version,
      canvasSize: canvas,
      layers: layers,
      variants: variants,
      headPivot: headPivot,
      framing: framing,
      baseDir: baseDir,
    );
  }

  final int version;
  final double canvasSize;
  final Map<String, SpriteLayerConfig> layers;
  final Map<String, List<String>> variants;
  final Offset headPivot;
  final Map<AvatarSize, SpriteFraming> framing;
  final String baseDir;

  String assetPathForFile(String fileName) => '$baseDir/$fileName';

  /// Resolves [requested] variant in [group], falling back to `'default'` or
  /// the first declared variant if [requested] is missing (§3 Fase C).
  String resolveVariant(
    String group,
    String requested, {
    String fallback = 'default',
  }) {
    final available = variants[group];
    if (available == null || available.isEmpty) return requested;
    if (available.contains(requested)) return requested;
    if (available.contains(fallback)) return fallback;
    if (available.contains('default')) return 'default';
    return available.first;
  }

  /// Collects every expected sprite filename declared or implied by §4.2.
  Set<String> collectAssetFiles() {
    final files = <String>{
      'shadow.png',
      'hair_back.png',
      'hair_bun.png',
      'body_hoodie.png',
      'head_base.png',
      'blush.png',
      'eye_mask.png',
      'eye_white.png',
      'iris.png',
      'eye_highlight.png',
      'hair_bangs.png',
      'hair_side_left.png',
      'hair_side_right.png',
      'ahoge.png',
      'star_clip.png',
      'fx_sweat.png',
      'fx_exclaim.png',
      'fx_question.png',
      for (final cfg in layers.values) cfg.file,
    };
    const prefixes = {
      'eyes': 'eyes_',
      'brows': 'brows_',
      'mouth': 'mouth_',
      'arms': 'arms_',
    };
    for (final entry in prefixes.entries) {
      for (final v in variants[entry.key] ?? const <String>[]) {
        files.add('${entry.value}$v.png');
      }
    }
    return files;
  }
}

Offset? _parseOffsetOrNull(Object? raw) {
  if (raw is List && raw.length >= 2 && raw[0] is num && raw[1] is num) {
    return Offset((raw[0] as num).toDouble(), (raw[1] as num).toDouble());
  }
  return null;
}

/// Pure deterministic mapping from continuous [AvatarExpression] + blink to
/// eye sprite variant name (`happy`, `squeeze`, `wink`, `closed`, `half`,
/// `wide`, or `open` for composite sclera+iris+highlight).
String selectEyeVariant(AvatarExpression expr, double blinkAmount) {
  if (expr.eyeShape == EyeShape.happy) return 'happy';
  if (expr.eyeShape == EyeShape.squeeze) return 'squeeze';
  if (expr.winkRight) return 'wink';

  final effectiveOpen = (expr.eyeOpen * (1.0 - blinkAmount)).clamp(0.0, 1.0);
  if (effectiveOpen < 0.15) return 'closed';
  if (effectiveOpen < 0.6) return 'half';
  if (expr.eyeShape == EyeShape.wide) return 'wide';
  return 'open';
}

/// Pure deterministic mapping from brow parameters to brow sprite variant name.
String selectBrowVariant(AvatarExpression expr) {
  if (expr.browTilt <= -0.25) return 'worried';
  if (expr.browTilt >= 0.25) return 'focused';
  if (expr.browRaise >= 0.35) return 'raised';
  return 'neutral';
}

/// Pure deterministic mapping from mouth parameters + frame state to mouth
/// sprite variant name (§2.4 & §3 Fase C).
String selectMouthVariant(AvatarExpression expr, AvatarFrame frame) {
  if (frame.isYawning) return 'yawn';

  final openAmt = (expr.mouthOpen + frame.mouthTalkBoost).clamp(0.0, 1.0);
  if (frame.mouthTalkBoost.abs() > 0.04 || frame.talkShape > 0.01) {
    return frame.talkShape >= 0.5 ? 'talk_i' : 'talk_a';
  }
  if (expr.mouthCurve > 0.5 && openAmt > 0.3) return 'grin';
  if (openAmt > 0.22) return 'o';
  if (expr.mouthCurve < -0.15) return 'frown';
  if (expr.mouthCurve.abs() <= 0.15) return 'flat';
  if (expr.mouthCurve > 0.4 && expr.blush > 0.7) return 'cat';
  return 'smile';
}

/// Pure deterministic mapping from [ArmPose] + [AvatarPoseMode] to arm variant name.
String selectArmVariant(ArmPose pose, AvatarPoseMode poseMode) {
  final effective =
      (poseMode == AvatarPoseMode.peek && pose == ArmPose.rest)
      ? ArmPose.peek
      : pose;
  return switch (effective) {
    ArmPose.peek => 'peek',
    ArmPose.chin => 'chin',
    ArmPose.rest => 'rest',
    ArmPose.wave => 'wave',
    ArmPose.cheer => 'cheer',
    ArmPose.type => 'type',
    ArmPose.worry => 'worry',
    ArmPose.coverMouth => 'cover_mouth',
  };
}

/// Optional high-fidelity layered PNG sprite renderer for "Wynn" v2.
///
/// Automatically activated when `assets/avatar/wynn/manifest.json` exists and
/// decodes cleanly; safely falls back to [ChibiProceduralRenderer] otherwise.
class LayeredSpriteRenderer implements AvatarRenderer {
  const LayeredSpriteRenderer({
    required this.manifest,
    required this.images,
    this.fallback = const ChibiProceduralRenderer(),
  });

  final AvatarSpriteManifest manifest;
  final Map<String, ui.Image> images;
  final AvatarRenderer fallback;

  static final Map<String, ui.Image> _imageCache = <String, ui.Image>{};
  static bool _loggedInvalidManifest = false;

  bool get isReady =>
      images.containsKey('head_base.png') &&
      images.containsKey('body_hoodie.png');

  @override
  AvatarRendererKind get kind => AvatarRendererKind.layeredSprite;

  /// Attempts to load [manifestPath] from [bundle] (defaults to [rootBundle]).
  /// Returns `null` silently if the asset is not bundled, or logs once via
  /// [debugPrint] and returns `null` if the manifest is malformed.
  static Future<LayeredSpriteRenderer?> tryLoad({
    AssetBundle? bundle,
    String manifestPath = kDefaultSpriteManifestPath,
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

    if (!bundledAssets.contains(manifestPath)) {
      return null;
    }

    AvatarSpriteManifest parsed;
    try {
      final rawJson = await effectiveBundle.loadString(manifestPath);
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Manifest root must be a JSON object.');
      }
      final lastSlash = manifestPath.lastIndexOf('/');
      final baseDir = lastSlash > 0
          ? manifestPath.substring(0, lastSlash)
          : 'assets/avatar/wynn';
      parsed = AvatarSpriteManifest.fromJson(decoded, baseDir: baseDir);
    } catch (error) {
      _logInvalidManifestOnce(
        'Wynn LayeredSpriteRenderer: invalid manifest ($manifestPath): $error. Falling back to ChibiProceduralRenderer.',
      );
      return null;
    }

    final loaded = <String, ui.Image>{};
    for (final fileName in parsed.collectAssetFiles()) {
      final fullPath = parsed.assetPathForFile(fileName);
      if (!bundledAssets.contains(fullPath)) continue;
      final cached = _imageCache[fullPath];
      if (cached != null) {
        loaded[fileName] = cached;
        continue;
      }
      try {
        final byteData = await effectiveBundle.load(fullPath);
        final image = await decodeImageFromList(byteData.buffer.asUint8List());
        _imageCache[fullPath] = image;
        loaded[fileName] = image;
      } catch (error) {
        _logInvalidManifestOnce(
          'Wynn LayeredSpriteRenderer: failed decoding $fullPath ($error).',
        );
      }
    }

    final renderer = LayeredSpriteRenderer(manifest: parsed, images: loaded);
    if (!renderer.isReady) {
      _logInvalidManifestOnce(
        'Wynn LayeredSpriteRenderer: required layers (head_base.png & body_hoodie.png) missing. Falling back to ChibiProceduralRenderer.',
      );
      return null;
    }
    return renderer;
  }

  static void _logInvalidManifestOnce(String message) {
    if (_loggedInvalidManifest) return;
    _loggedInvalidManifest = true;
    debugPrint(message);
  }

  @override
  Widget build(BuildContext context, AvatarRenderInput input) {
    if (!isReady) {
      return fallback.build(context, input);
    }

    final spritePainter = SpriteAvatarPainter(
      manifest: manifest,
      images: images,
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
        AvatarEffectsPainter(motionController: input.motionController);

    return SizedBox(
      width: input.size,
      height: input.size,
      child: CustomPaint(
        painter: spritePainter,
        foregroundPainter: effectsPainter,
      ),
    );
  }
}
