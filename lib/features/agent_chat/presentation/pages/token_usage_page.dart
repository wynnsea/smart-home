import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ethereal_background.dart';
import '../../../../core/widgets/glass_surface.dart';
import '../../domain/entities/token_usage_entities.dart';
import '../providers/token_usage_provider.dart';

/// Full-screen AI Token Consumption & Daily Budget Manager.
class TokenUsagePage extends ConsumerWidget {
  const TokenUsagePage({super.key});

  static const _budgetPresets = <int>[50000, 100000, 250000, 500000, 1000000];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usage = ref.watch(tokenUsageProvider);
    final notifier = ref.read(tokenUsageProvider.notifier);
    final byModel = usage.todayByModel.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final recent = usage.records.take(15).toList();
    final barColor = usage.isNearLimit
        ? AppColors.diffDelText
        : AppColors.primary;

    return Scaffold(
      body: EtherealBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
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
                          'Konsumsi Token AI',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Pantau & atur batas penggunaan token harian',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Daily budget overview card
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: usage.isNearLimit
                                ? AppColors.diffDelBg
                                : AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.data_usage_rounded,
                            color: barColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pemakaian Hari Ini',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                '${usage.todayRequestCount} request · Total semua: ${formatTokenCount(usage.allTimeTotalTokens)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: usage.isNearLimit
                                ? AppColors.diffDelBg
                                : AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${usage.budgetPercent}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: barColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Text(
                          '${formatTokenCount(usage.todayTotalTokens)} token',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const Spacer(),
                        Text(
                          'Target: ${formatTokenCount(usage.dailyBudget)} / hari',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: usage.budgetProgress,
                        minHeight: 9,
                        backgroundColor: AppColors.primarySoft,
                        valueColor: AlwaysStoppedAnimation<Color>(barColor),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _TokenPillStat(
                            label: 'Prompt (Input)',
                            value: formatTokenCount(usage.todayPromptTokens),
                            color: AppColors.tintBlueFg,
                            bg: AppColors.tintBlueBg,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _TokenPillStat(
                            label: 'Completion (Output)',
                            value: formatTokenCount(
                              usage.todayCompletionTokens,
                            ),
                            color: AppColors.tintPurpleFg,
                            bg: AppColors.tintPurpleBg,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Daily budget selector
              GlassCard(
                blur: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Batas Budget Harian',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pilih batas token harian agar pemakaian AI tetap terkendali.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _budgetPresets.map((preset) {
                        final selected = usage.dailyBudget == preset;
                        return ChoiceChip(
                          label: Text(formatTokenCount(preset)),
                          selected: selected,
                          selectedColor: AppColors.primarySoft,
                          onSelected: (_) => notifier.setDailyBudget(preset),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: usage.todayTotalTokens == 0
                                ? null
                                : () {
                                    notifier.resetToday();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Counter token hari ini di-reset',
                                        ),
                                      ),
                                    );
                                  },
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Reset Hari Ini'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton(
                          onPressed: usage.records.isEmpty
                              ? null
                              : () {
                                  notifier.resetAll();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Semua riwayat token dihapus',
                                      ),
                                    ),
                                  );
                                },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.diffDelText,
                          ),
                          child: const Text('Hapus Semua'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (byModel.isNotEmpty) ...[
                const SizedBox(height: 14),
                GlassCard(
                  blur: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pemakaian per Model (Hari Ini)',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      ...byModel.map((entry) {
                        final ratio = usage.todayTotalTokens > 0
                            ? (entry.value / usage.todayTotalTokens)
                                  .clamp(0.0, 1.0)
                            : 0.0;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      entry.key,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${formatTokenCount(entry.value)} tok',
                                    style: AppTheme.monoStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(99),
                                child: LinearProgressIndicator(
                                  value: ratio,
                                  minHeight: 6,
                                  backgroundColor: AppColors.primarySoft,
                                  valueColor: const AlwaysStoppedAnimation(
                                    AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Text(
                'Riwayat Request Terbaru',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (recent.isEmpty)
                GlassCard(
                  blur: false,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.bolt_rounded,
                          size: 28,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Belum ada konsumsi token tercatat',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Kirim prompt di Chat AI untuk mulai melacak pemakaian token otomatis.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...recent.map((r) {
                  final dt = r.timestamp;
                  final timeLabel = dt != null
                      ? '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
                      : '';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GlassCard(
                      blur: false,
                      padding: const EdgeInsets.all(12),
                      borderRadius: 16,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.model,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${r.source} · in ${formatTokenCount(r.promptTokens)} / out ${formatTokenCount(r.completionTokens)}',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${formatTokenCount(r.totalTokens)} tok',
                                style: AppTheme.monoStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                              if (timeLabel.isNotEmpty)
                                Text(
                                  timeLabel,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(fontSize: 10.5),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

class _TokenPillStat extends StatelessWidget {
  const _TokenPillStat({
    required this.label,
    required this.value,
    required this.color,
    required this.bg,
  });

  final String label;
  final String value;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.8,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
