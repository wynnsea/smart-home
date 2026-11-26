import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/file_chip.dart';
import '../../../../core/widgets/glass_surface.dart';
import '../../../../core/widgets/motion_widgets.dart';
import '../../../git_diff/domain/entities/diff_entities.dart';
import '../../domain/entities/chat_entities.dart';

/// Converts a structured [ChatMessage] into complete readable plain text
/// including heading, summary, numbered findings, sub-bullets, and files.
String toPlainText(ChatMessage message) {
  final buffer = StringBuffer();
  if (message.heading != null && message.heading!.isNotEmpty) {
    buffer.writeln(message.heading);
  }
  if (message.text.isNotEmpty) {
    if (buffer.isNotEmpty) buffer.writeln();
    buffer.writeln(message.text);
  }
  if (message.findings.isNotEmpty) {
    for (final finding in message.findings) {
      buffer.writeln();
      buffer.writeln('${finding.number}. ${finding.title}');
      for (final bullet in finding.bullets) {
        buffer.writeln('   - $bullet');
      }
      if (finding.referencedFiles.isNotEmpty) {
        buffer.writeln('   Files: ${finding.referencedFiles.join(', ')}');
      }
    }
  } else if (message.fileChips.isNotEmpty) {
    buffer.writeln();
    buffer.writeln('Files: ${message.fileChips.join(', ')}');
  }
  return buffer.toString().trim();
}

/// Glossy violet Liquid Glass user bubble with specular rim catch.
class UserMessageBubble extends StatelessWidget {
  const UserMessageBubble({
    super.key,
    required this.message,
    this.onFileChipTap,
  });

  final ChatMessage message;
  final ValueChanged<String>? onFileChipTap;

  @override
  Widget build(BuildContext context) {
    const bubbleRadius = BorderRadius.only(
      topLeft: Radius.circular(24),
      topRight: Radius.circular(24),
      bottomLeft: Radius.circular(24),
      bottomRight: Radius.circular(8),
    );

    return FadeSlideEntrance(
      duration: const Duration(milliseconds: 340),
      offset: const Offset(20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: bubbleRadius,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.28),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: bubbleRadius,
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * 0.84,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    gradient: AppColors.userBubbleGradient,
                    borderRadius: bubbleRadius,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.48),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (message.fileChips.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: message.fileChips.map((f) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Text(
                                f,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Structured AI investigation card with "Wynn" avatar,
/// numbered findings, sub-bullets, tappable inline file chips, and action bar.
class InvestigationMessageBubble extends StatelessWidget {
  const InvestigationMessageBubble({
    super.key,
    required this.message,
    required this.diffFilesByPath,
    required this.onFileTap,
    required this.onToggleLike,
    required this.onOpenDiff,
    required this.onRetry,
    this.isLatestAgentMessage = false,
  });

  final ChatMessage message;
  final Map<String, DiffFile> diffFilesByPath;
  final ValueChanged<String> onFileTap;
  final VoidCallback onToggleLike;
  final VoidCallback onOpenDiff;
  final VoidCallback onRetry;
  final bool isLatestAgentMessage;

  @override
  Widget build(BuildContext context) {
    return FadeSlideEntrance(
      duration: const Duration(milliseconds: 380),
      offset: const Offset(-16, 12),
      child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GlassCard(
                padding: const EdgeInsets.all(15),
                borderRadius: 24,
                blur: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.statusBadge != null &&
                        (message.isError || message.isStreaming)) ...[
                      GestureDetector(
                        onTap: message.isError ? onRetry : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: message.isError
                                ? AppColors.diffDelBg
                                : AppColors.tintBlueBg,
                            borderRadius: BorderRadius.circular(10),
                            border: message.isError
                                ? Border.all(
                                    color: AppColors.diffDelText.withValues(
                                      alpha: 0.35,
                                    ),
                                  )
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (message.isError)
                                const Padding(
                                  padding: EdgeInsets.only(right: 5),
                                  child: Icon(
                                    Icons.error_outline_rounded,
                                    size: 13,
                                    color: AppColors.diffDelText,
                                  ),
                                )
                              else
                                const Padding(
                                  padding: EdgeInsets.only(right: 6),
                                  child: TypingWaveDots(
                                    color: AppColors.tintBlueFg,
                                  ),
                                ),
                              Flexible(
                                child: Text(
                                  message.isError
                                      ? 'Gagal — ketuk untuk coba lagi'
                                      : message.statusBadge!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: message.isError
                                        ? AppColors.diffDelText
                                        : AppColors.tintBlueFg,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (message.isError && message.heading != null) ...[
                      Text(
                        message.heading!,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (message.text.isNotEmpty)
                      _RichAgentText(text: message.text),
                    if (message.findings.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ...message.findings.map(
                        (finding) => _FindingBlock(
                          finding: finding,
                          diffFilesByPath: diffFilesByPath,
                          onFileTap: onFileTap,
                        ),
                      ),
                    ],
                    if (message.fileChips.isNotEmpty &&
                        message.findings.isEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: message.fileChips.map((path) {
                          final diff = diffFilesByPath[path];
                          return CodeFileChip(
                            filePath: path,
                            additions: diff?.additions,
                            deletions: diff?.deletions,
                            compact: true,
                            onTap: () => onFileTap(path),
                          );
                        }).toList(),
                      ),
                    ],
                    if (!message.isError &&
                        !message.isStreaming &&
                        message.statusBadge != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 11,
                            color: AppColors.adaptiveTextSecondary(context)
                                .withValues(alpha: 0.78),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              message.statusBadge!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.adaptiveTextSecondary(context)
                                    .withValues(alpha: 0.82),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Subtle bottom utility row with >= 48px touch targets (T5.2)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    _MiniActionIcon(
                      icon: Icons.copy_rounded,
                      tooltip: 'Salin isi',
                      onTap: () {
                        Clipboard.setData(
                          ClipboardData(text: toPlainText(message)),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Isi pesan berhasil disalin'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                    _MiniActionIcon(
                      icon: message.isLiked
                          ? Icons.thumb_up_rounded
                          : Icons.thumb_up_outlined,
                      tooltip: 'Bermanfaat',
                      color: message.isLiked ? AppColors.primary : null,
                      onTap: onToggleLike,
                    ),
                    _MiniActionIcon(
                      icon: Icons.difference_outlined,
                      tooltip: 'Lihat diff',
                      onTap: onOpenDiff,
                    ),
                    const Spacer(),
                    _MiniActionIcon(
                      icon: Icons.refresh_rounded,
                      tooltip: 'Ulangi',
                      onTap: onRetry,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
    );
  }
}

class _FindingBlock extends StatelessWidget {
  const _FindingBlock({
    required this.finding,
    required this.diffFilesByPath,
    required this.onFileTap,
  });

  final FindingItem finding;
  final Map<String, DiffFile> diffFilesByPath;
  final ValueChanged<String> onFileTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 20,
                height: 20,
                margin: const EdgeInsets.only(top: 1),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  '${finding.number}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  finding.title,
                  style: const TextStyle(
                    fontSize: 13.2,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ...finding.bullets.map(
            (bullet) => Padding(
              padding: const EdgeInsets.only(left: 28, bottom: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '• ',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      bullet,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (finding.referencedFiles.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: finding.referencedFiles.map((path) {
                  final diff = diffFilesByPath[path];
                  return CodeFileChip(
                    filePath: path,
                    additions: diff?.additions,
                    deletions: diff?.deletions,
                    compact: true,
                    onTap: () => onFileTap(path),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RichAgentText extends StatelessWidget {
  const _RichAgentText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final fenceRegex = RegExp(r'```(\w*)\n?([\s\S]*?)```');
    final matches = fenceRegex.allMatches(text).toList();
    if (matches.isEmpty) {
      return _buildInlineMarkdown(context, text);
    }

    final blocks = <Widget>[];
    var cursor = 0;
    for (final match in matches) {
      if (match.start > cursor) {
        final prose = text.substring(cursor, match.start).trim();
        if (prose.isNotEmpty) {
          blocks.add(_buildInlineMarkdown(context, prose));
          blocks.add(const SizedBox(height: 8));
        }
      }
      final lang = match.group(1)?.trim() ?? '';
      final code = (match.group(2) ?? '').trimRight();
      blocks.add(_CodeBlockBox(language: lang, code: code));
      blocks.add(const SizedBox(height: 8));
      cursor = match.end;
    }
    if (cursor < text.length) {
      final tail = text.substring(cursor).trim();
      if (tail.isNotEmpty) {
        blocks.add(_buildInlineMarkdown(context, tail));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: blocks,
    );
  }

  Widget _buildInlineMarkdown(BuildContext context, String raw) {
    final baseStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: AppColors.textSecondary,
    );
    final inlineRegex = RegExp(r'(\*\*[^*]+\*\*|`[^`]+`)');
    final spans = <InlineSpan>[];
    var cursor = 0;

    for (final m in inlineRegex.allMatches(raw)) {
      if (m.start > cursor) {
        spans.add(TextSpan(text: raw.substring(cursor, m.start)));
      }
      final token = m.group(0)!;
      if (token.startsWith('**') && token.endsWith('**')) {
        spans.add(
          TextSpan(
            text: token.substring(2, token.length - 2),
            style: baseStyle?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.adaptiveTextPrimary(context),
            ),
          ),
        );
      } else if (token.startsWith('`') && token.endsWith('`')) {
        final isDark = AppColors.isDark(context);
        spans.add(
          TextSpan(
            text: ' ${token.substring(1, token.length - 1)} ',
            style: AppTheme.monoStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.primaryLight : AppColors.primaryDark,
            ).copyWith(
              backgroundColor: isDark
                  ? const Color(0xFF282E4E)
                  : AppColors.surfaceSubtle,
            ),
          ),
        );
      }
      cursor = m.end;
    }
    if (cursor < raw.length) {
      spans.add(TextSpan(text: raw.substring(cursor)));
    }

    return Text.rich(TextSpan(style: baseStyle, children: spans));
  }
}

class _CodeBlockBox extends StatelessWidget {
  const _CodeBlockBox({required this.language, required this.code});

  final String language;
  final String code;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF12162A) : AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.adaptiveBorder(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
            color: isDark
                ? const Color(0xFF1D223D)
                : Colors.white.withValues(alpha: 0.65),
            child: Row(
              children: [
                Text(
                  language.isEmpty ? 'CODE' : language.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.adaptiveTextSecondary(context),
                  ),
                ),
                const Spacer(),
                Semantics(
                  button: true,
                  label: 'Salin kode',
                  child: IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 15),
                    tooltip: 'Salin kode',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Kode disalin'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Text(
              code,
              style: AppTheme.monoStyle(
                fontSize: 11.8,
                color: AppColors.adaptiveTextPrimary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniActionIcon extends StatelessWidget {
  const _MiniActionIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            child: Center(
              child: Icon(
                icon,
                size: 16.5,
                color: color ?? AppColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
