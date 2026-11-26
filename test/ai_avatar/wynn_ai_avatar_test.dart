import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wynndiff/features/ai_avatar/domain/avatar_mood.dart';
import 'package:wynndiff/features/ai_avatar/presentation/renderers/glb_avatar_slot.dart';
import 'package:wynndiff/features/ai_avatar/presentation/renderers/rive_avatar_slot.dart';
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
}
