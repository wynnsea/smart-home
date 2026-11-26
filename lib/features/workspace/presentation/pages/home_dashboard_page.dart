import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_surface.dart';
import '../../../../core/widgets/motion_widgets.dart';
import '../../../agent_chat/presentation/pages/agent_hub_page.dart';
import '../../../agent_chat/presentation/providers/agent_chat_provider.dart';
import '../../../agent_chat/presentation/widgets/session_list_sheet.dart';
import '../../../agent_chat/presentation/widgets/terminal_logs_sheet.dart';
import '../../../git_diff/presentation/providers/git_diff_provider.dart';
import '../../../git_diff/presentation/widgets/git_diff_bottom_sheet.dart';
import '../providers/workspace_provider.dart';
import '../widgets/dashboard_cards.dart';

/// Left Screen from the reference UI with staggered entrance animations:
/// User greeting header, Active Host Hero Card, 2x2 Quick Workspace grid,
/// and Continue Coding recent sessions list.
class HomeDashboardPage extends ConsumerWidget {
  const HomeDashboardPage({
    super.key,
    required this.onNavigateTab,
  });

  final ValueChanged<int> onNavigateTab;

  String _greetingByTime(DateTime now) {
    final hour = now.hour;
    if (hour < 11) return 'Selamat Pagi';
    if (hour < 15) return 'Selamat Siang';
    if (hour < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(workspaceOverviewProvider);
    final diffState = ref.watch(gitDiffProvider);
    final status = overview.hostStatus;
    final greeting = _greetingByTime(DateTime.now());

    Future<void> openAgentHub() async {
      final result = await Navigator.of(context).push<String>(
        EtherealPageRoute<String>(
          builder: (_) => const AgentHubPage(),
        ),
      );
      if (result == 'chat') {
        onNavigateTab(1);
      }
    }

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          await Future.wait([
            ref.read(workspaceOverviewProvider.notifier).refresh(),
            ref.read(gitDiffProvider.notifier).refresh(),
          ]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 118),
        children: [
          FadeSlideEntrance(
            delay: Duration.zero,
            offset: const Offset(0, 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF473E73), Color(0xFF8358FF)],
                    ),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.22),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'WS',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        greeting,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        status.userName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                GlassCircleButton(
                  icon: Icons.terminal_rounded,
                  tooltip: 'Log host',
                  onTap: () => showTerminalLogsSheet(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FadeSlideEntrance(
            delay: const Duration(milliseconds: 70),
            child: HostHeroCard(
              status: status,
              changedFilesCount: diffState.snapshot.files.length,
              onTap: openAgentHub,
            ),
          ),
          const SizedBox(height: 22),
          FadeSlideEntrance(
            delay: const Duration(milliseconds: 140),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Quick Workspace',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: overview.quickMetrics.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.05,
            ),
            itemBuilder: (context, index) {
              final metric = overview.quickMetrics[index];
              return FadeSlideEntrance(
                delay: Duration(milliseconds: 180 + index * 55),
                child: QuickMetricCard(
                  metric: metric,
                  onTap: () {
                    switch (metric.actionKey) {
                      case 'chat':
                        onNavigateTab(1);
                      case 'diff':
                        showGitDiffBottomSheet(context);
                      case 'logs':
                        showTerminalLogsSheet(context);
                      case 'hub':
                        openAgentHub();
                    }
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 22),
          FadeSlideEntrance(
            delay: const Duration(milliseconds: 340),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Continue Coding',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  button: true,
                  label: 'Lihat semua sesi',
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => showSessionListSheet(
                        context,
                        onSessionSelected: () => onNavigateTab(1),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        child: Text(
                          'See All',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(overview.recentSessions.length, (i) {
            final session = overview.recentSessions[i];
            return FadeSlideEntrance(
              delay: Duration(milliseconds: 390 + i * 70),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SessionContinueCard(
                  session: session,
                  onTap: () {
                    ref.read(agentChatProvider.notifier).openSessionById(
                      session.id,
                      fallbackTitle: session.title,
                      fallbackRepo: session.repoFullName,
                      fallbackBranch: session.branch,
                      fallbackSummary: session.summary,
                    );
                    onNavigateTab(1);
                  },
                ),
              ),
            );
          }),
        ],
        ),
      ),
    );
  }
}
