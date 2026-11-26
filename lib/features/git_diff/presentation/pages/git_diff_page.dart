import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/glass_surface.dart';
import '../../../../core/widgets/motion_widgets.dart';
import '../../domain/entities/diff_entities.dart';
import '../providers/git_diff_provider.dart';
import '../widgets/git_diff_bottom_sheet.dart';

/// Dedicated Diff tab listing changed files without duplicating full unified
/// diff viewers inline (T3.6); tapping a file opens the Diff Review Sheet.
class GitDiffPage extends ConsumerWidget {
  const GitDiffPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diffState = ref.watch(gitDiffProvider);
    final snapshot = diffState.snapshot;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(gitDiffProvider.notifier).refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 116),
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Git Diff Review',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '${snapshot.repoFullName} · ${snapshot.branch} (${snapshot.lastCommitHash})',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Summary stats card
            GlassCard(
              child: Row(
                children: [
                  _StatBadge(
                    label: 'Files',
                    value: '${snapshot.files.length}',
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 14),
                  _StatBadge(
                    label: 'Added',
                    value: '+${snapshot.totalAdditions}',
                    color: AppColors.diffAddText,
                  ),
                  const SizedBox(width: 14),
                  _StatBadge(
                    label: 'Deleted',
                    value: '-${snapshot.totalDeletions}',
                    color: AppColors.diffDelText,
                  ),
                  const Spacer(),
                  if (snapshot.hasChanges)
                    FilledButton(
                      onPressed: () => showGitDiffBottomSheet(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Review'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (!snapshot.hasChanges)
              GlassCard(
                child: Column(
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      size: 40,
                      color: AppColors.tintGreenFg,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Working tree bersih',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      snapshot.lastActionMessage ??
                          'Kirim prompt baru untuk melihat perubahan diff.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => ref
                          .read(gitDiffProvider.notifier)
                          .restoreSampleDiffs(),
                      child: const Text('Muat Contoh Diff'),
                    ),
                  ],
                ),
              )
            else ...[
              Text(
                'File Berubah (${snapshot.files.length})',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              ...snapshot.files.map(
                (file) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _DiffFileListTile(
                    file: file,
                    onTap: () => showGitDiffBottomSheet(
                      context,
                      initialFilePath: file.path,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DiffFileListTile extends StatelessWidget {
  const _DiffFileListTile({
    required this.file,
    required this.onTap,
  });

  final DiffFile file;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (file.status) {
      DiffFileStatus.added => (AppColors.diffAddBg, AppColors.diffAddText),
      DiffFileStatus.modified => (AppColors.tintAmberBg, AppColors.tintAmberFg),
      DiffFileStatus.deleted => (AppColors.diffDelBg, AppColors.diffDelText),
    };

    return BouncyTap(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        borderRadius: 20,
        blur: false,
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Text(
                file.statusSymbol,
                style: AppTheme.monoStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: fg,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.monoStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    file.path,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    file.summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 11.8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '+${file.additions}',
                      style: AppTheme.monoStyle(
                        fontSize: 11.2,
                        fontWeight: FontWeight.w700,
                        color: AppColors.diffAddText,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '-${file.deletions}',
                      style: AppTheme.monoStyle(
                        fontSize: 11.2,
                        fontWeight: FontWeight.w700,
                        color: AppColors.diffDelText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTheme.monoStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
