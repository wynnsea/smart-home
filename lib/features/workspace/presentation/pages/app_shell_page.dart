import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/widgets/ethereal_background.dart';
import '../../../agent_chat/presentation/pages/investigation_chat_page.dart';
import '../../../git_diff/presentation/pages/git_diff_page.dart';
import '../../../git_diff/presentation/providers/git_diff_provider.dart';
import '../widgets/dashboard_cards.dart';
import 'home_dashboard_page.dart';
import 'host_settings_page.dart';

/// Root navigation shell with animated living pastel mesh backdrop,
/// fluid AnimatedSwitcher tab transitions, and keyboard-aware floating dock.
class AppShellPage extends ConsumerStatefulWidget {
  const AppShellPage({super.key});

  @override
  ConsumerState<AppShellPage> createState() => _AppShellPageState();
}

class _AppShellPageState extends ConsumerState<AppShellPage> {
  int _tabIndex = 0;

  Widget _buildActivePage() {
    return switch (_tabIndex) {
      0 => HomeDashboardPage(
        key: const ValueKey('tab-home'),
        onNavigateTab: (index) => setState(() => _tabIndex = index),
      ),
      1 => InvestigationChatPage(
        key: const ValueKey('tab-chat'),
        showBackButton: false,
        onBack: () => setState(() => _tabIndex = 0),
      ),
      2 => const GitDiffPage(key: ValueKey('tab-diff')),
      _ => const HostSettingsPage(key: ValueKey('tab-host')),
    };
  }

  void _openChatAi() {
    HapticFeedback.lightImpact();
    setState(() => _tabIndex = 1);
  }

  @override
  Widget build(BuildContext context) {
    final diffCount = ref.watch(gitDiffProvider).snapshot.files.length;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final hideBottomNav = keyboardOpen || _tabIndex == 1;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    return PopScope(
      canPop: _tabIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _tabIndex != 0) {
          setState(() => _tabIndex = 0);
        }
      },
      child: Scaffold(
        extendBody: true,
        body: EtherealBackground(
          child: Stack(
            children: [
              AnimatedSwitcher(
                duration: disableAnimations
                    ? Duration.zero
                    : const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  if (disableAnimations) return child;
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.025),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: _buildActivePage(),
              ),
              if (_tabIndex != 1)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: IgnorePointer(
                    ignoring: hideBottomNav,
                    child: AnimatedSlide(
                      offset: hideBottomNav ? const Offset(0, 1.2) : Offset.zero,
                      duration: disableAnimations
                          ? Duration.zero
                          : const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      child: AnimatedOpacity(
                        opacity: hideBottomNav ? 0.0 : 1.0,
                        duration: disableAnimations
                            ? Duration.zero
                            : const Duration(milliseconds: 180),
                        child: FloatingBottomNav(
                          currentIndex: _tabIndex,
                          diffBadgeCount: diffCount,
                          onSelectTab: (index) {
                            if (index != _tabIndex) {
                              HapticFeedback.lightImpact();
                              setState(() => _tabIndex = index);
                            }
                          },
                          onSparkleFabTap: _openChatAi,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
