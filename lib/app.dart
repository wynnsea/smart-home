import 'package:material_ui/material_ui.dart';

import 'core/theme/app_theme.dart';
import 'features/workspace/presentation/pages/app_shell_page.dart';
import 'features/workspace/presentation/pages/splash_page.dart';

class WynnDiffApp extends StatelessWidget {
  const WynnDiffApp({super.key, this.showSplash = true});

  final bool showSplash;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WynnDiff',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: showSplash ? const SplashPage() : const AppShellPage(),
    );
  }
}
