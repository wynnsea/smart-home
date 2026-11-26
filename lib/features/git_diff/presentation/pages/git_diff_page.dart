import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/network/wynn_bridge_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/glass_surface.dart';
import '../../../../core/widgets/motion_widgets.dart';
import '../../../workspace/presentation/providers/workspace_provider.dart';
import '../../domain/entities/diff_entities.dart';
import '../providers/git_diff_provider.dart';
import '../widgets/git_diff_bottom_sheet.dart';

enum _DiffSubTab { changes, history }

/// Dedicated Diff tab with live working-tree diffs, Recent Commits history,
/// and 1-tap Branch Switcher.
class GitDiffPage extends ConsumerStatefulWidget {
  const GitDiffPage({super.key});

  @override
  ConsumerState<GitDiffPage> createState() => _GitDiffPageState();
}

class _GitDiffPageState extends ConsumerState<GitDiffPage> {
  _DiffSubTab _subTab = _DiffSubTab.changes;
  List<GitCommitItem> _commits = const [];
  bool _loadingCommits = false;
  String? _commitsError;

  Future<void> _loadCommits() async {
    final cfg = ref.read(bridgeConfigProvider);
    if (!cfg.isActive) {
      setState(() {
        _commits = const [];
        _commitsError = 'Aktifkan Server Bridge di tab Host untuk melihat riwayat commit.';
      });
      return;
    }
    setState(() {
      _loadingCommits = true;
      _commitsError = null;
    });
    try {
      final list = await WynnBridgeClient().fetchGitLog(cfg);
      if (!mounted) return;
      setState(() {
        _commits = list;
        _loadingCommits = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _commitsError = e.toString().replaceFirst('Exception: ', '');
        _loadingCommits = false;
      });
    }
  }

  Future<void> _openBranchSwitcher() async {
    final cfg = ref.read(bridgeConfigProvider);
    if (!cfg.isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aktifkan Server Bridge di tab Host untuk ganti branch.'),
        ),
      );
      return;
    }
    try {
      final res = await WynnBridgeClient().fetchGitBranches(cfg);
      if (!mounted) return;
      final picked = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF15192E) : const Color(0xFFF7F7FD),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ganti Branch',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                ...res.branches.map((b) {
                  final active = b == res.active;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      active
                          ? Icons.radio_button_checked_rounded
                          : Icons.call_split_rounded,
                      color: active ? AppColors.primary : AppColors.textSecondary,
                      size: 20,
                    ),
                    title: Text(
                      b,
                      style: AppTheme.monoStyle(
                        fontSize: 13,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        color: Theme.of(ctx).textTheme.bodyMedium?.color ??
                            AppColors.textPrimary,
                      ),
                    ),
                    trailing: active
                        ? const Text(
                            'AKTIF',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.tintGreenFg,
                            ),
                          )
                        : null,
                    onTap: () => Navigator.of(ctx).pop(b),
                  );
                }),
              ],
            ),
          );
        },
      );
      if (picked == null || picked == res.active || !mounted) return;
      await WynnBridgeClient().checkoutBranch(cfg, picked);
      await Future.wait([
        ref.read(workspaceOverviewProvider.notifier).refresh(),
        ref.read(gitDiffProvider.notifier).refresh(),
      ]);
      if (_subTab == _DiffSubTab.history) {
        await _loadCommits();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Berpindah ke branch "$picked"')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final diffState = ref.watch(gitDiffProvider);
    final snapshot = diffState.snapshot;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          await ref.read(gitDiffProvider.notifier).refresh();
          if (_subTab == _DiffSubTab.history) {
            await _loadCommits();
          }
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 116),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Git Diff Review',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${snapshot.repoFullName} · ${snapshot.branch}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                ActionChip(
                  avatar: const Icon(
                    Icons.call_split_rounded,
                    size: 15,
                    color: AppColors.primary,
                  ),
                  label: Text(
                    snapshot.branch,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  backgroundColor: AppColors.primarySoft,
                  onPressed: _openBranchSwitcher,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text('Perubahan (${snapshot.files.length})'),
                  selected: _subTab == _DiffSubTab.changes,
                  selectedColor: AppColors.primarySoft,
                  onSelected: (_) =>
                      setState(() => _subTab = _DiffSubTab.changes),
                ),
                ChoiceChip(
                  label: const Text('Riwayat Commit'),
                  selected: _subTab == _DiffSubTab.history,
                  selectedColor: AppColors.primarySoft,
                  onSelected: (_) {
                    setState(() => _subTab = _DiffSubTab.history);
                    _loadCommits();
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_subTab == _DiffSubTab.history) ...[
              if (_loadingCommits)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_commitsError != null)
                GlassCard(
                  blur: false,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      _commitsError!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                )
              else if (_commits.isEmpty)
                GlassCard(
                  blur: false,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      'Belum ada riwayat commit.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                )
              else
                ..._commits.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GlassCard(
                      blur: false,
                      padding: const EdgeInsets.all(13),
                      borderRadius: 18,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              c.hash,
                              style: AppTheme.monoStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c.subject,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontSize: 13.5),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${c.author} · ${c.relativeTime}',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ] else ...[
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 28,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.tintGreenBg,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.verified_rounded,
                          size: 32,
                          color: AppColors.tintGreenFg,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Working tree bersih',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        snapshot.lastActionMessage ??
                            'Kirim prompt baru untuk melihat perubahan diff.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 14),
                      TextButton.icon(
                        onPressed: () =>
                            ref.read(gitDiffProvider.notifier).refresh(),
                        icon: const Icon(Icons.refresh_rounded, size: 17),
                        label: const Text('Muat Ulang Diff'),
                      ),
                    ],
                  ),
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
