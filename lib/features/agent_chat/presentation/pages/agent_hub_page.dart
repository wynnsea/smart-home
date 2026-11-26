import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/ethereal_background.dart';
import '../../../../core/widgets/glass_surface.dart';
import '../../../../core/widgets/liquid_sheet.dart';
import '../../../../core/widgets/motion_widgets.dart';
import '../../../ai_avatar/domain/avatar_mood.dart';
import '../../../ai_avatar/presentation/widgets/wynn_ai_avatar.dart';
import '../../../git_diff/presentation/providers/git_diff_provider.dart';
import '../../../git_diff/presentation/widgets/git_diff_bottom_sheet.dart';
import '../../../workspace/presentation/providers/workspace_provider.dart';
import '../providers/agent_chat_provider.dart';
import '../widgets/prompt_composer_card.dart';
import '../widgets/terminal_logs_sheet.dart';

/// Center Screen from the reference UI with Hero-linked levitating AI Orb,
/// expanding aura rings, and staggered entrance animations.
class AgentHubPage extends ConsumerWidget {
  const AgentHubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatState = ref.watch(agentChatProvider);
    final diffCount = ref.watch(gitDiffProvider).snapshot.files.length;
    final userName = ref.watch(workspaceOverviewProvider).hostStatus.userName;

    void submitAndOpenChat(String prompt) {
      ref.read(agentChatProvider.notifier).sendPrompt(prompt);
      Navigator.of(context).pop('chat');
    }

    return Scaffold(
      body: EtherealBackground(
        intenseCenter: true,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
                child: Row(
                  children: [
                    GlassCircleButton(
                      icon: Icons.chevron_left_rounded,
                      tooltip: 'Kembali',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'WynnDiff Agent',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '${chatState.repoFullName} · ${chatState.branch}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    GlassCircleButton(
                      icon: Icons.more_vert_rounded,
                      tooltip: 'Menu cepat',
                      onTap: () => _openHubMenu(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      const WynnAiAvatar(
                        size: AvatarSize.lg,
                        heroTag: 'wynn-agent-orb',
                        showSpeechBubble: true,
                        preferGreetingBubble: true,
                      ),
                      const SizedBox(height: 12),
                      FadeSlideEntrance(
                        delay: const Duration(milliseconds: 100),
                        child: Text(
                          'Halo, $userName',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      FadeSlideEntrance(
                        delay: const Duration(milliseconds: 170),
                        child: Text(
                          'How Can I help you?',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontSize: 25,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: FadeSlideEntrance(
                              delay: const Duration(milliseconds: 240),
                              child: _HubSuggestionCard(
                                icon: Icons.bug_report_rounded,
                                iconBg: AppColors.tintPurpleBg,
                                iconFg: AppColors.tintPurpleFg,
                                title: 'Investigate Code',
                                subtitle:
                                    'Trace SSE drops & inspect changed modules remotely',
                                onTap: () => submitAndOpenChat(
                                  'Trace potential race conditions in bridge prompt streaming',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FadeSlideEntrance(
                              delay: const Duration(milliseconds: 310),
                              child: _HubSuggestionCard(
                                icon: Icons.difference_rounded,
                                iconBg: AppColors.tintAmberBg,
                                iconFg: AppColors.tintAmberFg,
                                title: 'Review Git Diff',
                                subtitle:
                                    'Inspect $diffCount modified files & approve commit',
                                onTap: () => showGitDiffBottomSheet(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              FadeSlideEntrance(
                delay: const Duration(milliseconds: 340),
                offset: const Offset(0, 24),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      PromptComposerCard(
                        hintText: 'Ask anything about your codebase...',
                        onSubmitted: submitAndOpenChat,
                      ),
                      const Positioned(
                        top: -36,
                        right: 16,
                        child: IgnorePointer(
                          child: WynnAiAvatar(
                            size: AvatarSize.sm,
                            pose: AvatarPoseMode.peek,
                            interactive: false,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openHubMenu(BuildContext context) {
    showLiquidModalSheet<void>(
      context: context,
      builder: (sheetCtx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Menu WynnDiff',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.terminal_rounded,
              color: AppColors.tintBlueFg,
            ),
            title: const Text(
              'Log host',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            onTap: () {
              Navigator.of(sheetCtx).pop();
              showTerminalLogsSheet(context);
            },
          ),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.auto_fix_high_rounded,
              color: AppColors.primary,
            ),
            title: const Text(
              'Ganti mode & model',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            onTap: () {
              Navigator.of(sheetCtx).pop();
              showModeModelPickerSheet(context);
            },
          ),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.difference_rounded,
              color: AppColors.tintGreenFg,
            ),
            title: const Text(
              'Lihat diff',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            onTap: () {
              Navigator.of(sheetCtx).pop();
              showGitDiffBottomSheet(context);
            },
          ),
        ],
      ),
    );
  }
}

class _HubSuggestionCard extends StatelessWidget {
  const _HubSuggestionCard({
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BouncyTap(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(15),
        borderRadius: 22,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 19, color: iconFg),
                ),
                const Spacer(),
                const Icon(
                  Icons.north_east_rounded,
                  size: 17,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 11.8,
                height: 1.38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
