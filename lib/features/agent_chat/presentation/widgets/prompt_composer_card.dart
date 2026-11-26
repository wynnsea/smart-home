import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/liquid_sheet.dart';
import '../../../../core/widgets/motion_widgets.dart';
import '../../../ai_avatar/presentation/providers/avatar_controller.dart';
import '../../../git_diff/presentation/providers/git_diff_provider.dart';
import '../../../git_diff/presentation/widgets/git_diff_bottom_sheet.dart';
import '../../../workspace/domain/entities/workspace_entities.dart';
import '../../../workspace/presentation/providers/workspace_provider.dart';
import '../../domain/entities/ai_gateway_entities.dart';
import '../../domain/entities/chat_entities.dart';
import '../providers/agent_chat_provider.dart';
import '../providers/ai_gateway_provider.dart';

/// Signature dual-layer prompt composer matching the reference design:
/// - Soft lavender top status bar ("Gemini 4 Pro · Agent" | "4 files · Diff")
/// - Crisp white elevated input card ("Ask anything...") with wand, +, mic, and purple send CTA.
class PromptComposerCard extends ConsumerStatefulWidget {
  const PromptComposerCard({
    super.key,
    required this.onSubmitted,
    this.hintText = 'Ask anything about your repo...',
  });

  final ValueChanged<String> onSubmitted;
  final String hintText;

  @override
  ConsumerState<PromptComposerCard> createState() => _PromptComposerCardState();
}

class _PromptComposerCardState extends ConsumerState<PromptComposerCard> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_syncComposerActive);
    _controller.addListener(_syncComposerActive);
  }

  void _syncComposerActive() {
    if (!mounted) return;
    final active = _focusNode.hasFocus || _controller.text.trim().isNotEmpty;
    ref.read(avatarControllerProvider.notifier).setComposerActive(active);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_syncComposerActive);
    _controller.removeListener(_syncComposerActive);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleSend() {
    final hostStatus = ref.read(workspaceOverviewProvider).hostStatus;
    if (!hostStatus.isConnected) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    _controller.clear();
    _focusNode.unfocus();
    ref.read(avatarControllerProvider.notifier).setComposerActive(false);
    widget.onSubmitted(text);
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(agentChatProvider);
    final diffSnapshot = ref.watch(gitDiffProvider).snapshot;
    final hostStatus = ref.watch(workspaceOverviewProvider).hostStatus;
    final isDisconnected =
        hostStatus.connectionState == HostConnectionState.disconnected;
    final isConnecting =
        hostStatus.connectionState == HostConnectionState.connecting;
    final canSend = hostStatus.isConnected && !chatState.isStreaming;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5D46B8).withValues(alpha: 0.14),
            blurRadius: 28,
            spreadRadius: -2,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.64),
                  AppColors.primarySoft.withValues(alpha: 0.42),
                  Colors.white.withValues(alpha: 0.56),
                ],
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.90),
                width: 1.4,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Upper frosted status strip
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 14, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _openModeModelPicker(context),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const PulsingDot(size: 6.5),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '${chatState.selectedModel} · ${chatState.mode.label}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => showGitDiffBottomSheet(context),
                        child: Text(
                          diffSnapshot.hasChanges
                              ? '${diffSnapshot.files.length} files · Diff'
                              : 'Clean tree',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Inner luminous Liquid Glass composer capsule
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 12, 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.86),
                          Colors.white.withValues(alpha: 0.68),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.95),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (chatState.attachedContextFiles.isNotEmpty) ...[
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: chatState.attachedContextFiles.map((
                              file,
                            ) {
                              return Chip(
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                                backgroundColor: AppColors.primarySoft,
                                side: BorderSide.none,
                                label: Text(
                                  file,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                                deleteIcon: const Icon(
                                  Icons.close_rounded,
                                  size: 14,
                                ),
                                onDeleted: () => ref
                                    .read(agentChatProvider.notifier)
                                    .removeContextFile(file),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 6),
                        ],
                        TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          enabled: !isDisconnected,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) {
                            if (canSend) _handleSend();
                          },
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: isDisconnected
                                ? 'Host tidak terhubung'
                                : isConnecting
                                ? 'Menyambungkan ke host…'
                                : widget.hintText,
                            hintStyle: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textMuted,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _ComposerIconButton(
                              icon: Icons.auto_fix_high_rounded,
                              tooltip: 'Mode & Model',
                              onTap: () => _openModeModelPicker(context),
                            ),
                            const SizedBox(width: 6),
                            _ComposerIconButton(
                              icon: Icons.add_rounded,
                              tooltip: 'Attach file context',
                              onTap: () => _openAttachContextSheet(context),
                            ),
                            const SizedBox(width: 6),
                            _ComposerIconButton(
                              icon: Icons.mic_none_rounded,
                              tooltip: 'Input suara',
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Input suara belum tersedia'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                            ),
                            const Spacer(),
                            Tooltip(
                              message: chatState.isStreaming
                                  ? 'Hentikan streaming'
                                  : isDisconnected
                                  ? 'Host tidak terhubung'
                                  : 'Kirim prompt',
                              child: BouncyTap(
                                pressedScale: 0.90,
                                onTap: chatState.isStreaming
                                    ? () => ref
                                          .read(agentChatProvider.notifier)
                                          .stopStreaming()
                                    : (canSend ? _handleSend : null),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: chatState.isStreaming
                                        ? const LinearGradient(
                                            colors: [
                                              Color(0xFFE5484D),
                                              Color(0xFFC02B3A),
                                            ],
                                          )
                                        : canSend
                                        ? AppColors.primaryGradient
                                        : null,
                                    color: !chatState.isStreaming && !canSend
                                        ? AppColors.borderDivider
                                        : null,
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.72,
                                      ),
                                      width: 1.2,
                                    ),
                                    boxShadow: [
                                      if (chatState.isStreaming || canSend)
                                        BoxShadow(
                                          color: (chatState.isStreaming
                                                  ? AppColors.diffDelText
                                                  : AppColors.primary)
                                              .withValues(alpha: 0.34),
                                          blurRadius: 14,
                                          offset: const Offset(0, 5),
                                        ),
                                    ],
                                  ),
                                  child: Icon(
                                    chatState.isStreaming
                                        ? Icons.stop_rounded
                                        : Icons.send_rounded,
                                    color: chatState.isStreaming || canSend
                                        ? Colors.white
                                        : AppColors.textMuted,
                                    size: chatState.isStreaming ? 21 : 19,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openModeModelPicker(BuildContext context) {
    showModeModelPickerSheet(context);
  }

  void _openAttachContextSheet(BuildContext context) {
    showLiquidModalSheet<void>(
      context: context,
      builder: (sheetCtx) => _AttachFilePickerContent(
        onDone: () => Navigator.of(sheetCtx).pop(),
      ),
    );
  }
}

class _AttachFilePickerContent extends ConsumerStatefulWidget {
  const _AttachFilePickerContent({required this.onDone});

  final VoidCallback onDone;

  @override
  ConsumerState<_AttachFilePickerContent> createState() =>
      _AttachFilePickerContentState();
}

class _AttachFilePickerContentState
    extends ConsumerState<_AttachFilePickerContent> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final diffFiles = ref
        .watch(gitDiffProvider)
        .snapshot
        .files
        .map((f) => f.path);
    final mockFiles = ref.watch(workspaceOverviewProvider).sampleContextFiles;
    final attached = ref.watch(agentChatProvider).attachedContextFiles;

    final allFiles = <String>{...diffFiles, ...mockFiles}.toList();
    final filtered = _query.isEmpty
        ? allFiles
        : allFiles
              .where((f) => f.toLowerCase().contains(_query.toLowerCase()))
              .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Lampirkan File Konteks',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            FilledButton(
              onPressed: widget.onDone,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                attached.isEmpty ? 'Selesai' : 'Selesai (${attached.length})',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _searchController,
          onChanged: (val) => setState(() => _query = val.trim()),
          decoration: InputDecoration(
            hintText: 'Cari file...',
            prefixIcon: const Icon(Icons.search_rounded, size: 19),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.85),
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.borderDivider),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'File tidak ditemukan',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          )
        else
          ...filtered.map((path) {
            final fileName = path.split('/').last;
            final isAttached = attached.contains(path);
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                isAttached
                    ? Icons.check_circle_rounded
                    : Icons.description_outlined,
                color: isAttached ? AppColors.primary : AppColors.textSecondary,
              ),
              title: Text(
                fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: isAttached ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              subtitle: Text(
                path,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                ),
              ),
              trailing: Icon(
                isAttached
                    ? Icons.remove_circle_outline_rounded
                    : Icons.add_circle_outline_rounded,
                color: isAttached ? AppColors.diffDelText : AppColors.primary,
              ),
              onTap: () {
                final notifier = ref.read(agentChatProvider.notifier);
                if (isAttached) {
                  notifier.removeContextFile(path);
                } else {
                  notifier.attachContextFile(path);
                }
              },
            );
          }),
      ],
    );
  }
}

Future<void> showModeModelPickerSheet(BuildContext context) {
  return showLiquidModalSheet<void>(
    context: context,
    builder: (sheetCtx) {
      return Consumer(
        builder: (context, ref, _) {
          final state = ref.watch(agentChatProvider);
          final gateway = ref.watch(aiGatewayProvider);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Agent Mode & Model',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: gateway.isConfigured
                          ? AppColors.tintGreenBg
                          : AppColors.tintAmberBg,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      gateway.isConfigured ? 'OpenRouter Live' : 'Mock Mode',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: gateway.isConfigured
                            ? AppColors.tintGreenFg
                            : AppColors.tintAmberFg,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Pilih Agent',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: kBuiltInAgents.map((agent) {
                  final selected = state.selectedAgentId == agent.id;
                  return ChoiceChip(
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      agent.name,
                      style: const TextStyle(fontSize: 12),
                    ),
                    selected: selected,
                    selectedColor: AppColors.primarySoft,
                    onSelected: (_) =>
                        ref.read(agentChatProvider.notifier).setAgent(agent),
                  );
                }).toList(),
              ),
              const SizedBox(height: 4),
              Text(
                state.selectedAgent.tagline,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 11.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Execution Mode',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: AgentMode.values.map((mode) {
                  final selected = state.mode == mode;
                  return ChoiceChip(
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      '${mode.label} · ${mode.description}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    selected: selected,
                    selectedColor: AppColors.primarySoft,
                    onSelected: (_) =>
                        ref.read(agentChatProvider.notifier).setMode(mode),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              Text(
                'Model (AI Gateway)',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              ...kOpenRouterModels.map((model) {
                final selected =
                    state.selectedModel == model.label ||
                    state.selectedModel == model.id;
                return ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(vertical: -3),
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: selected ? AppColors.primary : AppColors.textMuted,
                  ),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          model.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (model.isFree) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.tintGreenBg,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: const Text(
                            'FREE',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.tintGreenFg,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    '${model.provider} · ${model.id}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11),
                  ),
                  onTap: () {
                    ref.read(agentChatProvider.notifier).setModel(model.label);
                    Navigator.of(sheetCtx).pop();
                  },
                );
              }),
            ],
          );
        },
      );
    },
  );
}

class _ComposerIconButton extends StatelessWidget {
  const _ComposerIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

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
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceSubtle,
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
