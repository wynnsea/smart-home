import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'features/workspace/presentation/pages/app_shell_page.dart';
import 'features/workspace/presentation/pages/splash_page.dart';

class WynnDiffApp extends ConsumerWidget {
  const WynnDiffApp({super.key, this.showSplash = true});

  final bool showSplash;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(darkModeProvider);
    return MaterialApp(
      title: 'WynnDiff',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      home: showSplash ? const SplashPage() : const AppShellPage(),
    );
  }
}
