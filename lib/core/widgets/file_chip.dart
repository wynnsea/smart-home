import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Interactive code file chip (e.g., `.dart`, `.ts`, `.tsx`, `.go`)
/// that can be tapped inline inside investigation findings to inspect diffs.
class CodeFileChip extends StatelessWidget {
  const CodeFileChip({
    super.key,
    required this.filePath,
    this.additions,
    this.deletions,
    this.onTap,
    this.compact = false,
  });

  final String filePath;
  final int? additions;
  final int? deletions;
  final VoidCallback? onTap;
  final bool compact;

  String get _fileName => filePath.split('/').last;

  String get _extension {
    final idx = _fileName.lastIndexOf('.');
    if (idx == -1) return 'file';
    return _fileName.substring(idx + 1).toLowerCase();
  }

  ({Color bg, Color fg, String label}) _badgeStyle() {
    return switch (_extension) {
      'dart' => (bg: AppColors.tintBlueBg, fg: AppColors.tintBlueFg, label: 'DART'),
      'ts' => (bg: AppColors.tintPurpleBg, fg: AppColors.tintPurpleFg, label: 'TS'),
      'tsx' => (bg: AppColors.tintPurpleBg, fg: AppColors.tintPurpleFg, label: 'TSX'),
      'go' => (bg: AppColors.tintTealBg, fg: AppColors.tintTealFg, label: 'GO'),
      'py' => (bg: AppColors.tintAmberBg, fg: AppColors.tintAmberFg, label: 'PY'),
      _ => (bg: AppColors.surfaceSubtle, fg: AppColors.textSecondary, label: _extension.toUpperCase()),
    };
  }

  @override
  Widget build(BuildContext context) {
    final style = _badgeStyle();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 10,
            vertical: compact ? 4.5 : 6,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.76),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.95),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: style.fg.withValues(alpha: 0.10),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: style.bg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  style.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                    color: style.fg,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  _fileName,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.monoStyle(
                    fontSize: compact ? 11.2 : 11.8,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (additions != null || deletions != null) ...[
                const SizedBox(width: 6),
                if (additions != null && additions! > 0)
                  Text(
                    '+$additions',
                    style: AppTheme.monoStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.diffAddText,
                    ),
                  ),
                if (deletions != null && deletions! > 0) ...[
                  const SizedBox(width: 3),
                  Text(
                    '-$deletions',
                    style: AppTheme.monoStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.diffDelText,
                    ),
                  ),
                ],
              ],
              if (onTap != null) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.north_east_rounded,
                  size: 13,
                  color: style.fg.withValues(alpha: 0.85),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
