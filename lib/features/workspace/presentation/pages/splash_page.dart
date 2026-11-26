import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/ethereal_background.dart';
import '../../../../core/widgets/glass_surface.dart';
import '../../../ai_avatar/domain/avatar_mood.dart';
import '../../../ai_avatar/presentation/widgets/wynn_ai_avatar.dart';
import 'app_shell_page.dart';

/// Animated Liquid Glass startup splash featuring Wynn & WynnDiff branding
/// (replaces the default Flutter startup feel with a smooth handoff to Home).
class SplashPage extends StatefulWidget {
  const SplashPage({
    super.key,
    this.duration = const Duration(milliseconds: 1350),
  });

  final Duration duration;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;
  Timer? _navTimer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _scaleAnim = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_navTimer != null || _navigated) return;

    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      _controller.value = 1.0;
      _navTimer = Timer(const Duration(milliseconds: 200), _goToHome);
    } else {
      _controller.forward();
      _navTimer = Timer(widget.duration, _goToHome);
    }
  }

  void _goToHome() {
    if (!mounted || _navigated) return;
    _navigated = true;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 420),
        pageBuilder: (_, _, _) => const AppShellPage(),
        transitionsBuilder: (_, anim, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
          child: child,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: EtherealBackground(
        intenseCenter: true,
        child: SafeArea(
          child: Center(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: ScaleTransition(
                scale: _scaleAnim,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GlassCard(
                      padding: const EdgeInsets.all(20),
                      borderRadius: 42,
                      child: const WynnAiAvatar(
                        size: AvatarSize.lg,
                        customSize: 132,
                        moodOverride: AvatarMood.idle,
                        interactive: false,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'WynnDiff',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'AI Remote Coding Agent',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
