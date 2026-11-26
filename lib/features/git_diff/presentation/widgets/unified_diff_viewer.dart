import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/diff_entities.dart';

/// Clean unified git diff viewer with collapsible hunks, Wrap toggle,
/// 300-line pagination guard, and optional per-file Revert action (T4.2 & T4.4).
class UnifiedDiffViewer extends StatefulWidget {
  const UnifiedDiffViewer({
    super.key,
    required this.file,
    this.onRevertFile,
  });

  final DiffFile file;
  final VoidCallback? onRevertFile;

  @override
  State<UnifiedDiffViewer> createState() => _UnifiedDiffViewerState();
}

class _UnifiedDiffViewerState extends State<UnifiedDiffViewer> {
  static const int _initialLineLimit = 300;

  bool _wrapLines = false;
  bool _showAllLines = false;
  final Set<int> _collapsedHunks = {};

  @override
  void didUpdateWidget(covariant UnifiedDiffViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) {
      _collapsedHunks.clear();
      _showAllLines = false;
    }
  }

  List<_DiffHunkGroup> _groupHunks(List<DiffLine> lines) {
    final groups = <_DiffHunkGroup>[];
    DiffLine? currentHeader;
    var currentBody = <DiffLine>[];

    for (final line in lines) {
      if (line.type == DiffLineType.hunkHeader) {
        if (currentHeader != null || currentBody.isNotEmpty) {
          groups.add(_DiffHunkGroup(header: currentHeader, lines: currentBody));
        }
        currentHeader = line;
        currentBody = <DiffLine>[];
      } else {
        currentBody.add(line);
      }
    }
    if (currentHeader != null || currentBody.isNotEmpty) {
      groups.add(_DiffHunkGroup(header: currentHeader, lines: currentBody));
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final totalLines = widget.file.lines.length;
    final truncated = !_showAllLines && totalLines > _initialLineLimit;
    final visibleSource = truncated
        ? widget.file.lines.take(_initialLineLimit).toList()
        : widget.file.lines;
    final hunks = _groupHunks(visibleSource);

    final diffContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < hunks.length; i++) ...[
          if (hunks[i].header != null)
            GestureDetector(
              onTap: () {
                setState(() {
                  if (_collapsedHunks.contains(i)) {
                    _collapsedHunks.remove(i);
                  } else {
                    _collapsedHunks.add(i);
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                color: AppColors.diffHunkBg,
                child: Row(
                  children: [
                    Icon(
                      _collapsedHunks.contains(i)
                          ? Icons.chevron_right_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: AppColors.diffHunkText,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        hunks[i].header!.content,
                        maxLines: _wrapLines ? null : 1,
                        overflow: _wrapLines ? null : TextOverflow.ellipsis,
                        style: AppTheme.monoStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.diffHunkText,
                        ),
                      ),
                    ),
                    if (_collapsedHunks.contains(i))
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          '${hunks[i].lines.length} baris',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.diffHunkText,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (!_collapsedHunks.contains(i))
            ...hunks[i].lines.map(
              (line) => _DiffCodeRow(line: line, wrap: _wrapLines),
            ),
        ],
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderDivider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // File header bar with Wrap toggle & optional Revert button
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            color: AppColors.surfaceSubtle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _StatusBadge(status: widget.file.status),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.file.path,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.monoStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.file.summary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontSize: 11.2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '+${widget.file.additions}',
                      style: AppTheme.monoStyle(
                        fontSize: 11.2,
                        fontWeight: FontWeight.w700,
                        color: AppColors.diffAddText,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '-${widget.file.deletions}',
                      style: AppTheme.monoStyle(
                        fontSize: 11.2,
                        fontWeight: FontWeight.w700,
                        color: AppColors.diffDelText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _HeaderActionChip(
                      icon: Icons.wrap_text_rounded,
                      label: _wrapLines ? 'Wrap: On' : 'Wrap',
                      active: _wrapLines,
                      onTap: () => setState(() => _wrapLines = !_wrapLines),
                    ),
                    if (widget.onRevertFile != null) ...[
                      const SizedBox(width: 8),
                      _HeaderActionChip(
                        icon: Icons.history_rounded,
                        label: 'Revert file ini',
                        destructive: true,
                        onTap: widget.onRevertFile!,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderDivider),
          if (_wrapLines)
            diffContent
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: MediaQuery.sizeOf(context).width - 40,
                ),
                child: IntrinsicWidth(child: diffContent),
              ),
            ),
          if (truncated)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.borderDivider)),
              ),
              alignment: Alignment.center,
              child: TextButton(
                onPressed: () => setState(() => _showAllLines = true),
                child: Text(
                  'Tampilkan semua ($totalLines baris)',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DiffHunkGroup {
  const _DiffHunkGroup({required this.header, required this.lines});

  final DiffLine? header;
  final List<DiffLine> lines;
}

class _HeaderActionChip extends StatelessWidget {
  const _HeaderActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final fg = destructive
        ? AppColors.diffDelText
        : active
        ? AppColors.primaryDark
        : AppColors.textSecondary;
    final bg = destructive
        ? AppColors.diffDelBg
        : active
        ? AppColors.primarySoft
        : Colors.white.withValues(alpha: 0.78);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: destructive
                  ? AppColors.diffDelText.withValues(alpha: 0.25)
                  : active
                  ? AppColors.primary.withValues(alpha: 0.35)
                  : AppColors.borderDivider,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13.5, color: fg),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.2,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final DiffFileStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (status) {
      DiffFileStatus.added => (AppColors.diffAddBg, AppColors.diffAddText, '+'),
      DiffFileStatus.modified => (
        AppColors.tintAmberBg,
        AppColors.tintAmberFg,
        '~',
      ),
      DiffFileStatus.deleted => (
        AppColors.diffDelBg,
        AppColors.diffDelText,
        '-',
      ),
    };

    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: AppTheme.monoStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}

class _DiffCodeRow extends StatelessWidget {
  const _DiffCodeRow({required this.line, required this.wrap});

  final DiffLine line;
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    final (rowBg, gutterBg, fg, prefix) = switch (line.type) {
      DiffLineType.addition => (
        AppColors.diffAddBg,
        AppColors.diffAddGutter,
        AppColors.diffAddText,
        '+',
      ),
      DiffLineType.deletion => (
        AppColors.diffDelBg,
        AppColors.diffDelGutter,
        AppColors.diffDelText,
        '-',
      ),
      DiffLineType.context || DiffLineType.hunkHeader => (
        Colors.white,
        const Color(0xFFF8F7FC),
        AppColors.textPrimary,
        ' ',
      ),
    };

    final codeText = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(
        '$prefix ${line.content}',
        softWrap: wrap,
        style: AppTheme.monoStyle(
          fontSize: 11.5,
          color: fg,
        ),
      ),
    );

    return Container(
      color: rowBg,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 62,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            color: gutterBg,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  line.oldLineNumber?.toString() ?? '',
                  style: AppTheme.monoStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  line.newLineNumber?.toString() ?? '',
                  style: AppTheme.monoStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (wrap) Expanded(child: codeText) else codeText,
        ],
      ),
    );
  }
}
