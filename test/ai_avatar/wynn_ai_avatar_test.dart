import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wynndiff/features/ai_avatar/domain/avatar_expression.dart';
import 'package:wynndiff/features/ai_avatar/domain/avatar_mood.dart';
import 'package:wynndiff/features/ai_avatar/presentation/controllers/avatar_frame.dart';
import 'package:wynndiff/features/ai_avatar/presentation/painters/chibi_body_painter.dart';
import 'package:wynndiff/features/ai_avatar/presentation/renderers/glb_avatar_slot.dart';
import 'package:wynndiff/features/ai_avatar/presentation/renderers/rive_avatar_slot.dart';
import 'package:wynndiff/features/ai_avatar/presentation/widgets/avatar_debug_page.dart';
import 'package:wynndiff/features/ai_avatar/presentation/widgets/wynn_ai_avatar.dart';

void main() {
  testWidgets('WynnAiAvatar pumps cleanly for every mood x size combination', (
    tester,
  ) async {
    for (final size in AvatarSize.values) {
      for (final mood in AvatarMood.values) {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: Center(
                  child: WynnAiAvatar(
                    size: size,
                    moodOverride: mood,
                    animate: false,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(WynnAiAvatar), findsOneWidget);
      }
    }
  });

  testWidgets('WynnAiAvatar stops ticker under Reduce Motion (disableAnimations: true)', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(400, 800),
              disableAnimations: true,
            ),
            child: Scaffold(
              body: Center(
                child: WynnAiAvatar(
                  size: AvatarSize.lg,
                  moodOverride: AvatarMood.idle,
                  animate: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('WynnAiAvatar supports tap chain, drag tilt, and long press', (
    tester,
  ) async {
    var tapped = 0;
    var longPressed = 0;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: WynnAiAvatar(
                size: AvatarSize.lg,
                moodOverride: AvatarMood.idle,
                onTap: () => tapped++,
                onLongPress: () => longPressed++,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    // Tap 3x (boop -> wink -> giggle)
    await tester.tap(find.byType(WynnAiAvatar));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byType(WynnAiAvatar));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byType(WynnAiAvatar));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tapped, equals(3));

    // Drag tilt & release spring
    await tester.drag(find.byType(WynnAiAvatar), const Offset(36, -24));
    await tester.pump(const Duration(milliseconds: 200));

    // Long press → wave + overlay bubble
    await tester.longPress(find.byType(WynnAiAvatar));
    await tester.pump(const Duration(milliseconds: 200));
    expect(longPressed, equals(1));

    // Advance past 3.5s auto-dismiss timer so no pending timers remain
    await tester.pump(const Duration(milliseconds: 3600));
  });

  testWidgets('RiveAvatarSlot and GlbAvatarSlot safely fall back to procedural renderer', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                WynnAiAvatar(
                  size: AvatarSize.md,
                  moodOverride: AvatarMood.thinking,
                  animate: false,
                  renderer: RiveAvatarSlot(assetPath: 'assets/avatar/wynn.riv'),
                ),
                WynnAiAvatar(
                  size: AvatarSize.md,
                  moodOverride: AvatarMood.success,
                  animate: false,
                  renderer: GlbAvatarSlot(assetPath: 'assets/avatar/wynn.glb'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(WynnAiAvatar), findsNWidgets(2));
  });

  testWidgets('AvatarDebugPage toggles dark background, framing, sliders & reactions cleanly', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: AvatarDebugPage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Toggle light/dark background & xs/sm framing & peek pose
    await tester.tap(find.text('BG: Terang'));
    await tester.pump();
    expect(find.text('BG: Gelap'), findsOneWidget);

    await tester.tap(find.text('Frame: xs'));
    await tester.pump();
    await tester.tap(find.text('Pose: peek'));
    await tester.pump();

    // Trigger wink (reference pose) and startle ("!") reactions
    await tester.tap(find.text('wink'));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tap(find.text('startle'));
    await tester.pump(const Duration(milliseconds: 120));

    // Enable custom sliders and scroll to verify v2 parameters appear
    await tester.tap(find.text('Custom sliders'));
    await tester.pump();
    final listScrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('winkRight'),
      300,
      scrollable: listScrollable,
    );
    expect(find.text('ahogePerk'), findsOneWidget);
    expect(find.text('accentGlow'), findsOneWidget);
    expect(find.text('headTilt'), findsOneWidget);
    expect(find.text('winkRight'), findsOneWidget);
  });

  test('ChibiBodyPainter paints 60 frames at lg (168dp) well within 16ms/frame budget', () {
    final painter = ChibiBodyPainter(
      staticExpression: expressionForReaction(
        AvatarReaction.wink,
        kMoodExpressions[AvatarMood.idle]!,
      ),
      staticFrame: const AvatarFrame(
        hairSwayOffset: Offset(0.06, -0.02),
        headTiltZ: 0.08,
        pupilOffset: Offset(0.015, -0.01),
      ),
      avatarSize: AvatarSize.lg,
      poseMode: AvatarPoseMode.peek,
    );

    final sw = Stopwatch()..start();
    for (var i = 0; i < 60; i++) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(168, 168));
      final picture = recorder.endRecording();
      picture.dispose();
    }
    sw.stop();

    final avgMs = sw.elapsedMicroseconds / 60.0 / 1000.0;
    expect(avgMs, lessThan(16.0));
  });
}
