import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/ethereal_background.dart';
import '../../../../core/widgets/glass_surface.dart';
import '../../../../core/widgets/motion_widgets.dart';
import '../../../ai_avatar/domain/avatar_mood.dart';
import '../../../ai_avatar/presentation/widgets/wynn_ai_avatar.dart';
import '../../../git_diff/presentation/providers/git_diff_provider.dart';
import '../../../git_diff/presentation/widgets/git_diff_bottom_sheet.dart';
import '../../../workspace/domain/entities/workspace_entities.dart';
import '../../../workspace/presentation/providers/workspace_provider.dart';
import '../../../workspace/presentation/widgets/server_file_browser_sheet.dart';
import '../providers/agent_chat_provider.dart';
import '../widgets/chat_bubbles.dart';
import '../widgets/prompt_composer_card.dart';
import '../widgets/session_list_sheet.dart';
import '../widgets/terminal_logs_sheet.dart';

/// Right Screen from the reference UI adapted for WynnDiff Investigation Chat:
/// Session switcher top bar, connection status & banner, polite auto-scroll,
/// empty state, and keyboard-aware prompt composer.
class InvestigationChatPage extends ConsumerStatefulWidget {
  const InvestigationChatPage({
    super.key,
    this.showBackButton = false,
    this.onBack,
  });

  final bool showBackButton;
  final VoidCallback? onBack;

  @override
  ConsumerState<InvestigationChatPage> createState() =>
      _InvestigationChatPageState();
}

class _InvestigationChatPageState extends ConsumerState<InvestigationChatPage> {
  final ScrollController _scrollController = ScrollController();
  bool _showNewMessageChip = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _scrollToBottom(immediate: true);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  bool get _isNearBottom {
    if (!_scrollController.hasClients) return true;
    return _scrollController.position.pixels < 80;
  }

  void _onScroll() {
    if (_showNewMessageChip && _isNearBottom) {
      setState(() => _showNewMessageChip = false);
    }
  }

  void _scrollToBottom({bool immediate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      if (immediate || MediaQuery.disableAnimationsOf(context)) {
        _scrollController.jumpTo(0);
      } else {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
      if (_showNewMessageChip && mounted) {
        setState(() => _showNewMessageChip = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(agentChatProvider);
    final diffState = ref.watch(gitDiffProvider);
    final hostStatus = ref.watch(workspaceOverviewProvider).hostStatus;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final diffFilesByPath = {
      for (final f in diffState.snapshot.files) f.path: f,
    };

    final statusColor = switch (hostStatus.connectionState) {
      HostConnectionState.connected => AppColors.tintGreenFg,
      HostConnectionState.connecting => AppColors.tintAmberFg,
      HostConnectionState.disconnected => AppColors.diffDelText,
    };

    ref.listen<AgentChatState>(agentChatProvider, (prev, next) {
      if (prev?.activeSessionId != next.activeSessionId) {
        if (_showNewMessageChip && mounted) {
          setState(() => _showNewMessageChip = false);
        }
        _scrollToBottom(immediate: true);
        return;
      }
      final countChanged = (prev?.messages.length ?? 0) != next.messages.length;
      final streamingUpdated =
          next.isStreaming || (prev?.isStreaming ?? false) != next.isStreaming;
      if (!countChanged && !streamingUpdated) return;

      final newestIsUser =
          next.messages.isNotEmpty && next.messages.last.isUser;
      if (newestIsUser || _isNearBottom) {
        _scrollToBottom();
      } else if (!_showNewMessageChip && mounted) {
        setState(() => _showNewMessageChip = true);
      }
    });

    final hasBackAction = widget.showBackButton || widget.onBack != null;
    final content = SafeArea(
      bottom: true,
      child: Column(
        children: [
          // Top App Bar (tap title to switch session or create new chat — T3.2)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                if (hasBackAction) ...[
                  GlassCircleButton(
                    icon: Icons.chevron_left_rounded,
                    tooltip: 'Kembali',
                    onTap: widget.onBack ?? () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 6),
                ],
                WynnAiAvatar(
                  size: AvatarSize.sm,
                  customSize: 38,
                  semanticLabel: 'Wynn, ketuk untuk buka log host',
                  onTap: () => showTerminalLogsSheet(context),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: GestureDetector(
                    onTap: () => showSessionListSheet(context),
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                chatState.sessionTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15.5,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (hostStatus.connectionState ==
                                HostConnectionState.connecting)
                              const PulsingDot(
                                size: 6,
                                color: AppColors.tintAmberFg,
                              )
                            else
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: statusColor,
                                ),
                              ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text.rich(
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: hostStatus.connectionLabel,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: statusColor,
                                      ),
                                    ),
                                    TextSpan(
                                      text:
                                          ' · ${chatState.repoFullName} · ${chatState.branch}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(fontSize: 11.2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                PopupMenuButton<String>(
                  tooltip: 'Menu Chat',
                  color: AppColors.isDark(context)
                      ? const Color(0xFF1E233D)
                      : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(
                      color: AppColors.adaptiveBorder(context),
                    ),
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case 'logs':
                        showTerminalLogsSheet(context);
                      case 'files':
                        showServerFileBrowserSheet(context);
                      case 'diff':
                        showGitDiffBottomSheet(context);
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'logs',
                      child: Row(
                        children: [
                          Icon(
                            Icons.terminal_rounded,
                            size: 18,
                            color: AppColors.adaptiveTextPrimary(ctx),
                          ),
                          const SizedBox(width: 10),
                          const Text('Log Host'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'files',
                      child: Row(
                        children: [
                          Icon(
                            Icons.folder_copy_outlined,
                            size: 18,
                            color: AppColors.adaptiveTextPrimary(ctx),
                          ),
                          const SizedBox(width: 10),
                          const Text('File Explorer Server'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'diff',
                      child: Row(
                        children: [
                          Icon(
                            Icons.compare_arrows_rounded,
                            size: 18,
                            color: AppColors.adaptiveTextPrimary(ctx),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            diffState.snapshot.hasChanges
                                ? 'Git Diff (${diffState.snapshot.files.length})'
                                : 'Git Diff',
                          ),
                        ],
                      ),
                    ),
                  ],
                  child: IgnorePointer(
                    child: GlassCircleButton(
                      icon: Icons.more_vert_rounded,
                      tooltip: 'Menu Chat',
                      badgeText: diffState.snapshot.hasChanges
                          ? '${diffState.snapshot.files.length}'
                          : null,
                      onTap: () {},
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Disconnected banner (T1.3)
          if (hostStatus.connectionState == HostConnectionState.disconnected)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.diffDelBg.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.diffDelText.withValues(alpha: 0.28),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.wifi_off_rounded,
                      size: 16,
                      color: AppColors.diffDelText,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Host terputus · Sambungkan ulang',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.diffDelText,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => ref
                          .read(workspaceOverviewProvider.notifier)
                          .reconnect(),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.diffDelText,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Sambungkan',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Chat & Investigation Stream with polite auto-scroll chip (T3.5)
          Expanded(
            child: Stack(
              children: [
                if (chatState.messages.isEmpty)
                  _EmptyChatState(
                    repoBranch:
                        '${chatState.repoFullName} · ${chatState.branch}',
                    isConnected: hostStatus.isConnected,
                    onSelectPrompt: (prompt) =>
                        ref.read(agentChatProvider.notifier).sendPrompt(prompt),
                  )
                else
                  ListView.separated(
                    key: ValueKey('chat-list-${chatState.activeSessionId}'),
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
                    itemCount: chatState.messages.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final msgIndex = chatState.messages.length - 1 - index;
                      final message = chatState.messages[msgIndex];
                      if (message.isUser) {
                        return UserMessageBubble(message: message);
                      }
                      final lastAgentIndex = chatState.messages.lastIndexWhere(
                        (m) => !m.isUser,
                      );
                      return InvestigationMessageBubble(
                        message: message,
                        isLatestAgentMessage: msgIndex == lastAgentIndex,
                        diffFilesByPath: diffFilesByPath,
                        onFileTap: (filePath) => showGitDiffBottomSheet(
                          context,
                          initialFilePath: filePath,
                        ),
                        onToggleLike: () => ref
                            .read(agentChatProvider.notifier)
                            .toggleLike(message.id),
                        onOpenDiff: () => showGitDiffBottomSheet(context),
                        onRetry: () => ref
                            .read(agentChatProvider.notifier)
                            .retryMessage(message.id),
                      );
                    },
                  ),
                if (_showNewMessageChip)
                  Positioned(
                    bottom: 10,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: _scrollToBottom,
                        child: LiquidGlassPill(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.arrow_downward_rounded,
                                size: 15,
                                color: AppColors.primary,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Pesan baru',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Bottom Prompt Composer (full-bleed without bottom nav dock)
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              4,
              16,
              keyboardOpen ? 10 : 12,
            ),
            child: PromptComposerCard(
              hintText: 'Ask anything...',
              onSubmitted: (prompt) =>
                  ref.read(agentChatProvider.notifier).sendPrompt(prompt),
            ),
          ),
        ],
      ),
    );

    if (!widget.showBackButton) {
      return content;
    }

    return Scaffold(
      body: EtherealBackground(child: content),
    );
  }
}

class _EmptyChatState extends StatelessWidget {
  const _EmptyChatState({
    required this.repoBranch,
    required this.isConnected,
    required this.onSelectPrompt,
  });

  final String repoBranch;
  final bool isConnected;
  final ValueChanged<String> onSelectPrompt;

  static const _suggestions = [
    'Periksa diff terbaru dan cek potensi bug',
    'Jelaskan alur SSE client & reconnect',
    'Jalankan audit Clean Architecture',
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const WynnAiAvatar(
              size: AvatarSize.md,
              showSpeechBubble: true,
              initialBubbleText:
                  'Halo! Pilih saran di bawah atau tulis prompt untuk mulai ✨',
            ),
            const SizedBox(height: 16),
            Text(
              'Mulai sesi baru',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              repoBranch,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _suggestions.map((prompt) {
                return ActionChip(
                  backgroundColor:
                      Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF232846).withValues(alpha: 0.85)
                      : Colors.white.withValues(alpha: 0.78),
                  side: BorderSide(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.14)
                        : Colors.white.withValues(alpha: 0.95),
                  ),
                  label: Text(
                    prompt,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFF2F3FF)
                          : AppColors.textPrimary,
                    ),
                  ),
                  onPressed: isConnected ? () => onSelectPrompt(prompt) : null,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
