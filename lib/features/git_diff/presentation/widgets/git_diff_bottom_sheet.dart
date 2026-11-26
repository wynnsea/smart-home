import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/glass_surface.dart';
import '../../domain/entities/diff_entities.dart';
import '../providers/git_diff_provider.dart';
import 'unified_diff_viewer.dart';

/// Opens the Changed Files & Git Diff review sheet, optionally focusing on
/// a specific [initialFilePath] tapped from an inline file chip.
Future<void> showGitDiffBottomSheet(
  BuildContext context, {
  String? initialFilePath,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => GitDiffBottomSheet(initialFilePath: initialFilePath),
  );
}

class GitDiffBottomSheet extends ConsumerStatefulWidget {
  const GitDiffBottomSheet({super.key, this.initialFilePath});

  final String? initialFilePath;

  @override
  ConsumerState<GitDiffBottomSheet> createState() => _GitDiffBottomSheetState();
}

class _GitDiffBottomSheetState extends ConsumerState<GitDiffBottomSheet> {
  @override
  void initState() {
    super.initState();
    if (widget.initialFilePath != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(gitDiffProvider.notifier).selectFile(widget.initialFilePath!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final diffState = ref.watch(gitDiffProvider);
    final snapshot = diffState.snapshot;

    DiffFile? selectedFile;
    if (snapshot.files.isNotEmpty) {
      selectedFile = snapshot.files.firstWhere(
        (f) => f.path == diffState.selectedFilePath,
        orElse: () => snapshot.files.first,
      );
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      minChildSize: 0.52,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.78),
                    AppColors.meshBase.withValues(alpha: 0.86),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(34),
                ),
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Changed Files & Git Diff',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.call_split_rounded,
                                    size: 13,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      '${snapshot.repoFullName} · ${snapshot.branch}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.borderDivider),
                          ),
                          child: Row(
                            children: [
                              Text(
                                '+${snapshot.totalAdditions}',
                                style: AppTheme.monoStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.diffAddText,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '-${snapshot.totalDeletions}',
                                style: AppTheme.monoStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.diffDelText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        GlassCircleButton(
                          icon: Icons.close_rounded,
                          tooltip: 'Tutup diff',
                          size: 36,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: snapshot.files.isEmpty
                        ? _EmptyDiffState(
                            lastAction: snapshot.lastActionMessage,
                            canUndo: diffState.previousSnapshot != null,
                            onUndo: () => ref
                                .read(gitDiffProvider.notifier)
                                .undoLastDiscard(),
                            onRestoreMock: () => ref
                                .read(gitDiffProvider.notifier)
                                .restoreSampleDiffs(),
                          )
                        : ListView(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                            children: [
                              // File selector cards
                              SizedBox(
                                height: 76,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: snapshot.files.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(width: 10),
                                  itemBuilder: (context, index) {
                                    final file = snapshot.files[index];
                                    final isSelected =
                                        file.path == selectedFile?.path;
                                    return _ChangedFilePill(
                                      file: file,
                                      selected: isSelected,
                                      onTap: () => ref
                                          .read(gitDiffProvider.notifier)
                                          .selectFile(file.path),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 14),
                              if (selectedFile != null)
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 260),
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeInCubic,
                                  transitionBuilder: (child, anim) {
                                    return FadeTransition(
                                      opacity: anim,
                                      child: SlideTransition(
                                        position: Tween<Offset>(
                                          begin: const Offset(0, 0.03),
                                          end: Offset.zero,
                                        ).animate(anim),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: UnifiedDiffViewer(
                                    key: ValueKey(selectedFile.path),
                                    file: selectedFile,
                                    onRevertFile: diffState.isBusy
                                        ? null
                                        : () => _confirmRevertFile(
                                            context,
                                            selectedFile!,
                                          ),
                                  ),
                                ),
                            ],
                          ),
                  ),
                  if (snapshot.hasChanges)
                    SafeArea(
                      top: false,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.90),
                          border: const Border(
                            top: BorderSide(color: AppColors.borderDivider),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: diffState.isBusy
                                    ? null
                                    : () => _confirmDiscard(context),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.diffDelText,
                                  side: BorderSide(
                                    color: AppColors.diffDelText.withValues(
                                      alpha: 0.35,
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                icon: const Icon(Icons.undo_rounded, size: 18),
                                label: const Text(
                                  'Discard',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.30,
                                      ),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton.icon(
                                  onPressed: diffState.isBusy
                                      ? null
                                      : () => _confirmCommit(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                  icon: diffState.isBusy
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.cloud_upload_rounded,
                                          size: 18,
                                        ),
                                  label: const Text(
                                    'Commit & Push',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
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
      },
    );
  }

  Future<void> _confirmCommit(BuildContext context) async {
    final snapshot = ref.read(gitDiffProvider).snapshot;
    final initialSuggestion = snapshot.lastActionMessage ?? '';
    final controller = TextEditingController(text: initialSuggestion);
    final selectedPaths = snapshot.files.map((f) => f.path).toSet();
    var pushToRemote = true;

    try {
      final result = await showDialog<
        ({String message, List<String> paths, bool push})
      >(
        context: context,
        builder: (dialogCtx) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Text('Commit Perubahan'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pilih file yang akan di-commit dan tulis pesan commit:',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: controller,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Pesan commit',
                          hintText: 'feat: ...',
                          filled: true,
                          fillColor: AppColors.surfaceSubtle,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'File (${selectedPaths.length}/${snapshot.files.length})',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 4),
                      ...snapshot.files.map((file) {
                        final checked = selectedPaths.contains(file.path);
                        return CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: checked,
                          title: Text(
                            file.fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.monoStyle(
                              fontSize: 11.8,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            '+${file.additions} / -${file.deletions}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          onChanged: (val) {
                            setDialogState(() {
                              if (val == true) {
                                selectedPaths.add(file.path);
                              } else {
                                selectedPaths.remove(file.path);
                              }
                            });
                          },
                        );
                      }),
                      SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Push ke remote',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        value: pushToRemote,
                        onChanged: (val) =>
                            setDialogState(() => pushToRemote = val),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Batal'),
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) {
                    final canSubmit =
                        value.text.trim().isNotEmpty &&
                        selectedPaths.isNotEmpty;
                    return FilledButton(
                      onPressed: canSubmit
                          ? () => Navigator.of(dialogCtx).pop((
                              message: value.text.trim(),
                              paths: selectedPaths.toList(),
                              push: pushToRemote,
                            ))
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                      child: Text(pushToRemote ? 'Commit & Push' : 'Commit'),
                    );
                  },
                ),
              ],
            );
          },
        ),
      );

      if (result == null || !context.mounted) return;
      final msg = await ref
          .read(gitDiffProvider.notifier)
          .commitAndPush(
            result.message,
            filePaths: result.paths,
            pushToRemote: result.push,
          );
      HapticFeedback.mediumImpact();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      controller.dispose();
    }
  }

  Future<void> _confirmRevertFile(BuildContext context, DiffFile file) async {
    final shouldRevert = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Revert file ini?'),
        content: Text(
          'Perubahan pada ${file.fileName} akan dikembalikan ke HEAD.',
          style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.diffDelText,
            ),
            child: const Text('Revert'),
          ),
        ],
      ),
    );

    if (shouldRevert != true || !context.mounted) return;
    final msg = await ref.read(gitDiffProvider.notifier).revertFile(file.path);
    if (!context.mounted) return;
    _showUndoSnackBar(context, msg);
  }

  Future<void> _confirmDiscard(BuildContext context) async {
    HapticFeedback.heavyImpact();
    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Discard All Changes?'),
        content: const Text(
          'Semua modifikasi yang belum di-commit di worktree host akan direset ke HEAD.',
          style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.diffDelText,
            ),
            child: const Text('Discard Changes'),
          ),
        ],
      ),
    );

    if (shouldDiscard != true || !context.mounted) return;
    final msg = await ref.read(gitDiffProvider.notifier).discardAllChanges();
    if (!context.mounted) return;
    _showUndoSnackBar(context, msg);
  }

  void _showUndoSnackBar(BuildContext context, String message) {
    final notifier = ref.read(gitDiffProvider.notifier);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          content: Text(message),
          action: SnackBarAction(
            label: 'Urungkan',
            onPressed: notifier.undoLastDiscard,
          ),
        ),
      );
  }
}

class _ChangedFilePill extends StatelessWidget {
  const _ChangedFilePill({
    required this.file,
    required this.selected,
    required this.onTap,
  });

  final DiffFile file;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (file.status) {
      DiffFileStatus.added => AppColors.diffAddText,
      DiffFileStatus.modified => AppColors.tintAmberFg,
      DiffFileStatus.deleted => AppColors.diffDelText,
    };

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 196,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.borderDivider,
            width: selected ? 1.6 : 1.0,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.14),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  file.statusSymbol,
                  style: AppTheme.monoStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    file.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.monoStyle(
                      fontSize: 11.8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  '+${file.additions}',
                  style: AppTheme.monoStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.diffAddText,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '-${file.deletions}',
                  style: AppTheme.monoStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.diffDelText,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: selected ? AppColors.primary : AppColors.textMuted,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyDiffState extends StatelessWidget {
  const _EmptyDiffState({
    required this.lastAction,
    required this.canUndo,
    required this.onUndo,
    required this.onRestoreMock,
  });

  final String? lastAction;
  final bool canUndo;
  final VoidCallback onUndo;
  final VoidCallback onRestoreMock;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.tintGreenBg,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.tintGreenFg,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Working Tree Clean',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              lastAction ?? 'No uncommitted modifications on host repository.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              alignment: WrapAlignment.center,
              children: [
                if (canUndo)
                  FilledButton.icon(
                    onPressed: onUndo,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    icon: const Icon(Icons.undo_rounded, size: 17),
                    label: const Text('Urungkan'),
                  ),
                TextButton.icon(
                  onPressed: onRestoreMock,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Muat Contoh Diff'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
