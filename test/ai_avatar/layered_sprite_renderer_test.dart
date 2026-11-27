import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wynndiff/features/ai_avatar/domain/avatar_expression.dart';
import 'package:wynndiff/features/ai_avatar/domain/avatar_mood.dart';
import 'package:wynndiff/features/ai_avatar/presentation/controllers/avatar_frame.dart';
import 'package:wynndiff/features/ai_avatar/presentation/providers/avatar_renderer_provider.dart';
import 'package:wynndiff/features/ai_avatar/presentation/renderers/avatar_renderer.dart';
import 'package:wynndiff/features/ai_avatar/presentation/renderers/chibi_procedural_renderer.dart';
import 'package:wynndiff/features/ai_avatar/presentation/renderers/layered_sprite_renderer.dart';
import 'package:wynndiff/features/ai_avatar/presentation/renderers/render_3d_avatar_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('avatarRendererProvider resolution', () {
    test('resolves to Render3dAvatarRenderer when 3D figurine assets are bundled', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final renderer = await container.read(avatarRendererProvider.future);
      expect(renderer, isA<Render3dAvatarRenderer>());
      expect(renderer.kind, equals(AvatarRendererKind.glb));
      final r3d = renderer as Render3dAvatarRenderer;
      expect(r3d.assetPathFor(AvatarMood.idle, null), endsWith('/idle.png'));
      expect(r3d.assetPathFor(AvatarMood.error, null), endsWith('/pout.png'));
      expect(r3d.assetPathFor(AvatarMood.success, null), endsWith('/happy.png'));
      expect(r3d.assetPathFor(AvatarMood.thinking, null), endsWith('/thinking.png'));
      expect(r3d.assetPathFor(AvatarMood.streaming, null), endsWith('/talking.png'));
      expect(r3d.assetPathFor(AvatarMood.sleepy, null), endsWith('/sleepy.png'));
    });

    test('resolveAvatarRenderer falls back cleanly on malformed manifest', () async {
      final badBundle = _FakeAssetBundle({
        kDefaultSpriteManifestPath: '{ not-valid-json',
      });

      final renderer = await resolveAvatarRenderer(bundle: badBundle);
      expect(renderer, isA<ChibiProceduralRenderer>());
    });
  });

  group('LayeredSpriteRenderer variant selection', () {
    final base = kMoodExpressions[AvatarMood.idle]!;

    test('selectEyeVariant maps eyeShape, winkRight, and blink/open ranges', () {
      expect(
        selectEyeVariant(base.copyWith(eyeShape: EyeShape.happy), 0.0),
        equals('happy'),
      );
      expect(
        selectEyeVariant(base.copyWith(eyeShape: EyeShape.squeeze), 0.0),
        equals('squeeze'),
      );
      expect(
        selectEyeVariant(base.copyWith(winkRight: true), 0.0),
        equals('wink'),
      );
      expect(
        selectEyeVariant(base.copyWith(eyeOpen: 0.1), 0.0),
        equals('closed'),
      );
      expect(
        selectEyeVariant(base.copyWith(eyeOpen: 1.0), 0.92),
        equals('closed'),
      );
      expect(
        selectEyeVariant(base.copyWith(eyeOpen: 0.45), 0.0),
        equals('half'),
      );
      expect(
        selectEyeVariant(base.copyWith(eyeShape: EyeShape.wide, eyeOpen: 1.0), 0.0),
        equals('wide'),
      );
      expect(
        selectEyeVariant(base.copyWith(eyeShape: EyeShape.normal, eyeOpen: 1.0), 0.0),
        equals('open'),
      );
    });

    test('selectBrowVariant maps browTilt and browRaise to variants', () {
      expect(
        selectBrowVariant(base.copyWith(browTilt: -0.6, browRaise: 0.2)),
        equals('worried'),
      );
      expect(
        selectBrowVariant(base.copyWith(browTilt: 0.45, browRaise: 0.1)),
        equals('focused'),
      );
      expect(
        selectBrowVariant(base.copyWith(browTilt: 0.0, browRaise: 0.5)),
        equals('raised'),
      );
      expect(
        selectBrowVariant(base.copyWith(browTilt: 0.0, browRaise: 0.05)),
        equals('neutral'),
      );
    });

    test('selectMouthVariant maps yawn, talk_a/i, grin, o, frown, flat, cat, smile', () {
      const idleFrame = AvatarFrame();

      expect(
        selectMouthVariant(base, const AvatarFrame(isYawning: true)),
        equals('yawn'),
      );
      expect(
        selectMouthVariant(
          base,
          const AvatarFrame(mouthTalkBoost: 0.22, talkShape: 0.2),
        ),
        equals('talk_a'),
      );
      expect(
        selectMouthVariant(
          base,
          const AvatarFrame(mouthTalkBoost: 0.22, talkShape: 0.8),
        ),
        equals('talk_i'),
      );
      expect(
        selectMouthVariant(
          base.copyWith(mouthCurve: 0.9, mouthOpen: 0.5),
          idleFrame,
        ),
        equals('grin'),
      );
      expect(
        selectMouthVariant(
          base.copyWith(mouthCurve: 0.05, mouthOpen: 0.35),
          idleFrame,
        ),
        equals('o'),
      );
      expect(
        selectMouthVariant(
          base.copyWith(mouthCurve: -0.5, mouthOpen: 0.0),
          idleFrame,
        ),
        equals('frown'),
      );
      expect(
        selectMouthVariant(
          base.copyWith(mouthCurve: 0.0, mouthOpen: 0.0),
          idleFrame,
        ),
        equals('flat'),
      );
      expect(
        selectMouthVariant(
          base.copyWith(mouthCurve: 0.8, mouthOpen: 0.0, blush: 0.85),
          idleFrame,
        ),
        equals('cat'),
      );
      expect(
        selectMouthVariant(
          base.copyWith(mouthCurve: 0.55, mouthOpen: 0.0, blush: 0.35),
          idleFrame,
        ),
        equals('smile'),
      );
    });

    test('selectArmVariant adapts rest to peek in AvatarPoseMode.peek', () {
      expect(
        selectArmVariant(ArmPose.rest, AvatarPoseMode.standing),
        equals('rest'),
      );
      expect(
        selectArmVariant(ArmPose.rest, AvatarPoseMode.peek),
        equals('peek'),
      );
      expect(
        selectArmVariant(ArmPose.coverMouth, AvatarPoseMode.standing),
        equals('cover_mouth'),
      );
      expect(
        selectArmVariant(ArmPose.chin, AvatarPoseMode.peek),
        equals('chin'),
      );
    });
  });

  group('AvatarSpriteManifest parsing & variant fallback', () {
    test('parses valid §4.3 manifest schema and resolves missing variants safely', () {
      final raw = jsonDecode('''
      {
        "version": 1,
        "canvas": 1024,
        "layers": {
          "hair_back":  { "file": "hair_back.png",  "pivot": [512, 300], "sway": 1.0 },
          "hair_bun":   { "file": "hair_bun.png",   "pivot": [430, 170], "sway": 0.7 },
          "hair_bangs": { "file": "hair_bangs.png", "pivot": [512, 260], "sway": 0.6 },
          "ahoge":      { "file": "ahoge.png",      "pivot": [520, 150], "sway": 1.4 },
          "iris":       { "file": "iris.png",       "maxOffset": [22, 14] }
        },
        "variants": {
          "eyes":  ["half", "closed", "happy", "squeeze", "wink", "wide"],
          "brows": ["neutral", "raised", "worried", "focused"],
          "mouth": ["smile", "grin", "o", "talk_a", "talk_i", "frown", "flat", "yawn", "cat"],
          "arms":  ["peek", "chin", "rest", "wave", "cheer", "type", "worry", "cover_mouth"]
        },
        "headPivot": [512, 560],
        "framing": {
          "xs": { "center": [512, 430], "scale": 2.1 },
          "sm": { "center": [512, 470], "scale": 1.6 },
          "md": { "center": [512, 520], "scale": 1.15 },
          "lg": { "center": [512, 540], "scale": 1.0 }
        }
      }
      ''') as Map<String, dynamic>;

      final manifest = AvatarSpriteManifest.fromJson(raw);
      expect(manifest.version, equals(1));
      expect(manifest.canvasSize, equals(1024.0));
      expect(manifest.layers['ahoge']?.sway, equals(1.4));
      expect(manifest.layers['iris']?.maxOffset, equals(const Offset(22, 14)));
      expect(manifest.framing[AvatarSize.xs]?.scale, equals(2.1));

      expect(manifest.resolveVariant('mouth', 'grin'), equals('grin'));
      expect(
        manifest.resolveVariant('mouth', 'nonexistent', fallback: 'smile'),
        equals('smile'),
      );
      expect(
        manifest.resolveVariant('eyes', 'missing_variant'),
        equals('half'),
      );
    });
  });
}

class _FakeAssetBundle extends CachingAssetBundle {
  _FakeAssetBundle(this.files);

  final Map<String, String> files;

  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') {
      final manifestMap = <String, List<Map<String, Object>>>{
        for (final path in files.keys)
          path: [
            {'asset': path},
          ],
      };
      return const StandardMessageCodec().encodeMessage(manifestMap)!;
    }
    final content = files[key];
    if (content == null) {
      throw Exception('Asset not found: $key');
    }
    final bytes = Uint8List.fromList(utf8.encode(content));
    return ByteData.sublistView(bytes);
  }
}
