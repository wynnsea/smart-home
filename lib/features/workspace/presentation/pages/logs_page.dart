import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ethereal_background.dart';
import '../../../../core/widgets/glass_surface.dart';
import '../../../agent_chat/presentation/providers/agent_chat_provider.dart';

enum _LogFilter { all, success, failed }

/// Dedicated full-screen execution & tool-call logs console (opened from Host).
class LogsPage extends ConsumerStatefulWidget {
  const LogsPage({super.key});

  @override
  ConsumerState<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends ConsumerState<LogsPage> {
  _LogFilter _filter = _LogFilter.all;

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(agentChatProvider);
    final allLogs = chatState.logs.reversed.toList();
    final filtered = switch (_filter) {
      _LogFilter.all => allLogs,
      _LogFilter.success => allLogs.where((l) => l.isSuccess).toList(),
      _LogFilter.failed => allLogs.where((l) => !l.isSuccess).toList(),
    };

    return Scaffold(
      body: EtherealBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Row(
                children: [
                  GlassCircleButton(
                    icon: Icons.chevron_left_rounded,
                    tooltip: 'Kembali',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Terminal Logs',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${allLogs.length} event pada sesi "${chatState.sessionTitle}"',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (filtered.isNotEmpty)
                    GlassCircleButton(
                      icon: Icons.copy_rounded,
                      tooltip: 'Salin semua log',
                      onTap: () {
                        final dump = filtered
                            .map((l) => '[${l.time}] ${l.command} — ${l.detail}')
                            .join('\n');
                        Clipboard.setData(ClipboardData(text: dump));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Log disalin ke clipboard'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                ],
              ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: Text('Semua (${allLogs.length})'),
                selected: _filter == _LogFilter.all,
                selectedColor: AppColors.adaptiveChipSelectedBg(context),
                onSelected: (_) => setState(() => _filter = _LogFilter.all),
              ),
              ChoiceChip(
                label: const Text('Sukses'),
                selected: _filter == _LogFilter.success,
                selectedColor: AppColors.tintGreenBg,
                onSelected: (_) => setState(() => _filter = _LogFilter.success),
              ),
              ChoiceChip(
                label: const Text('Gagal'),
                selected: _filter == _LogFilter.failed,
                selectedColor: AppColors.diffDelBg,
                onSelected: (_) => setState(() => _filter = _LogFilter.failed),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (filtered.isEmpty)
            GlassCard(
              blur: false,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.terminal_rounded,
                        size: 26,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Belum ada log eksekusi',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Kirim prompt ke Wynn untuk melihat aktivitas tool & server secara real-time.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            )
          else
            ...filtered.map(
              (log) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  blur: false,
                  padding: const EdgeInsets.all(13),
                  borderRadius: 18,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        log.isSuccess
                            ? Icons.check_circle_rounded
                            : Icons.error_rounded,
                        size: 18,
                        color: log.isSuccess
                            ? AppColors.tintGreenFg
                            : AppColors.diffDelText,
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
                                    log.command,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTheme.monoStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.adaptiveTextPrimary(
                                        context,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  log.time,
                                  style: AppTheme.monoStyle(
                                    fontSize: 10.5,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                            if (log.detail.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                log.detail,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(fontSize: 11.8),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
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
