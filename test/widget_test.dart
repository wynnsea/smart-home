import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wynndiff/app.dart';
import 'package:wynndiff/features/agent_chat/presentation/pages/investigation_chat_page.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets(
    'WynnDiff renders Home, Chat, Diff Sheet, Mode Picker, Sessions & Agent Hub on 412dp',
    (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const ProviderScope(child: WynnDiffApp()));
      await tester.pump(const Duration(milliseconds: 250));

      // Home Dashboard (dynamic greeting, no hardcoded Good Morning)
      expect(find.textContaining('Selamat '), findsOneWidget);
      expect(find.text('Active Host Session'), findsOneWidget);
      expect(find.text('Quick Workspace'), findsOneWidget);

      await tester.drag(find.byType(ListView).first, const Offset(0, -240));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Continue Coding'), findsOneWidget);

      // Navigate to Chat tab
      await tester.tap(find.byIcon(Icons.chat_bubble_outline_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Investigate Auth & Diff'), findsOneWidget);
      expect(find.text('Investigation & Patch Summary'), findsOneWidget);

      // Scroll chat stream and open Diff Sheet via inline file chip
      final chatList = find.descendant(
        of: find.byType(InvestigationChatPage),
        matching: find.byType(ListView),
      );
      await tester.drag(chatList, const Offset(0, -560));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('sse_client.dart'), findsOneWidget);

      await tester.tap(find.text('sse_client.dart'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));

      expect(find.text('Changed Files & Git Diff'), findsOneWidget);
      expect(find.text('Commit & Push'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));

      // Open Mode & Model picker
      await tester.tap(find.byIcon(Icons.auto_fix_high_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      expect(find.text('Agent Mode & Model'), findsOneWidget);

      await tester.tap(find.text('Claude 4 Sonnet'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));

      // Open Session List Sheet and create a new session → Empty state
      await tester.tap(find.text('Investigate Auth & Diff'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      expect(find.text('Daftar Sesi'), findsOneWidget);

      await tester.tap(find.text('Sesi baru'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      expect(find.text('Mulai sesi baru'), findsOneWidget);

      // Open Agent Hub via purple Sparkle FAB
      await tester.tap(find.byIcon(Icons.auto_awesome_rounded).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));

      expect(find.text('WynnDiff Agent'), findsOneWidget);
      expect(find.text('Halo, Wynnsea Dev'), findsOneWidget);
      expect(find.text('How Can I help you?'), findsOneWidget);
    },
  );

  testWidgets(
    'Host disconnect shows banner in Chat, /fail triggers error bubble, and 360dp + textScale 1.3 + Reduce Motion has no overflow',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MediaQuery(
            data: MediaQueryData(
              size: Size(360, 780),
              textScaler: TextScaler.linear(1.3),
              disableAnimations: true,
            ),
            child: WynnDiffApp(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Active Host Session'), findsOneWidget);

      // Switch to Host tab and disconnect
      await tester.tap(find.byIcon(Icons.dns_outlined));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Tes koneksi'), findsOneWidget);

      await tester.tap(find.text('Putuskan'));
      await tester.pump(const Duration(milliseconds: 100));

      // Switch to Chat tab → disconnected banner & locked composer
      await tester.tap(find.byIcon(Icons.chat_bubble_outline_rounded));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Host terputus · Sambungkan ulang'), findsOneWidget);

      // Reconnect from banner
      await tester.tap(find.text('Sambungkan'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pump();
      expect(find.text('Host terputus · Sambungkan ulang'), findsNothing);

      // Switch to a fresh empty session so error bubble is immediately visible
      await tester.tap(find.text('Investigate Auth & Diff'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('Sesi baru'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Mulai sesi baru'), findsOneWidget);

      // Trigger /fail prompt error handling
      await tester.enterText(find.byType(TextField), '/fail test stream');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 450));
      await tester.pump();

      expect(find.text('Gagal — ketuk untuk coba lagi'), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    },
  );
}
