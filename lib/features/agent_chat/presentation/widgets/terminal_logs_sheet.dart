import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/glass_surface.dart';
import '../../../workspace/presentation/providers/workspace_provider.dart';
import '../providers/agent_chat_provider.dart';

Future<void> showTerminalLogsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const TerminalLogsSheet(),
  );
}

class TerminalLogsSheet extends ConsumerWidget {
  const TerminalLogsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatState = ref.watch(agentChatProvider);
    final hostName = ref.watch(workspaceOverviewProvider).hostStatus.hostName;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          height: MediaQuery.sizeOf(context).height * 0.62,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.78),
                AppColors.meshBase.withValues(alpha: 0.86),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.95),
                width: 1.5,
              ),
            ),
          ),
          child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 44,
            height: 4.5,
            decoration: BoxDecoration(
              color: AppColors.textMuted.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.tintBlueBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.terminal_rounded,
                    color: AppColors.tintBlueFg,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Host Execution Stream',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '$hostName · ${chatState.logs.length} events recorded',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                GlassCircleButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Tutup log',
                  size: 36,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: chatState.logs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final entry = chatState.logs[index];
                return GlassCard(
                  padding: const EdgeInsets.all(14),
                  borderRadius: 18,
                  blur: false,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        label: entry.isSuccess ? 'Berhasil' : 'Peringatan',
                        child: Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Icon(
                            entry.isSuccess
                                ? Icons.check_circle_rounded
                                : Icons.warning_amber_rounded,
                            size: 17,
                            color: entry.isSuccess
                                ? AppColors.tintGreenFg
                                : AppColors.tintAmberFg,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '\$ ${entry.command}',
                                    style: AppTheme.monoStyle(
                                      fontSize: 11.8,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  entry.time,
                                  style: AppTheme.monoStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              entry.detail,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
        ),
      ),
    );
  }
}
