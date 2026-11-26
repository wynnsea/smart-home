import 'package:material_ui/material_ui.dart';

import 'core/theme/app_theme.dart';
import 'features/workspace/presentation/pages/app_shell_page.dart';

class WynnDiffApp extends StatelessWidget {
  const WynnDiffApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WynnDiff',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const AppShellPage(),
    );
  }
}
