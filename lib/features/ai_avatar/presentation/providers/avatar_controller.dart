import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../agent_chat/presentation/providers/agent_chat_provider.dart';
import '../../../git_diff/presentation/providers/git_diff_provider.dart';
import '../../domain/avatar_mood.dart';

const Object _avatarUnset = Object();

@immutable
class AvatarControllerState {
  const AvatarControllerState({
    this.activeReaction,
    this.reactionSeq = 0,
    this.composerActive = false,
    required this.lastInteraction,
    this.chunkPulseSeq = 0,
    this.userMessageSeq = 0,
  });

  final AvatarReaction? activeReaction;
  final int reactionSeq;
  final bool composerActive;
  final DateTime lastInteraction;
  final int chunkPulseSeq;
  final int userMessageSeq;

  AvatarControllerState copyWith({
    Object? activeReaction = _avatarUnset,
    int? reactionSeq,
    bool? composerActive,
    DateTime? lastInteraction,
    int? chunkPulseSeq,
    int? userMessageSeq,
  }) {
    return AvatarControllerState(
      activeReaction: activeReaction == _avatarUnset
          ? this.activeReaction
          : activeReaction as AvatarReaction?,
      reactionSeq: reactionSeq ?? this.reactionSeq,
      composerActive: composerActive ?? this.composerActive,
      lastInteraction: lastInteraction ?? this.lastInteraction,
      chunkPulseSeq: chunkPulseSeq ?? this.chunkPulseSeq,
      userMessageSeq: userMessageSeq ?? this.userMessageSeq,
    );
  }
}

/// Manages transient avatar reactions, composer focus state, interaction
/// timestamp (for sleepy detection), and streaming chunk pulses.
class AvatarController extends Notifier<AvatarControllerState> {
  Timer? _reactionTimer;
  int _diffFilesAtStreamStart = 0;

  @override
  AvatarControllerState build() {
    ref.onDispose(() {
      _reactionTimer?.cancel();
      _reactionTimer = null;
    });

    // Listen to chat stream lifecycle, new user bubbles, and chunk text growth
    ref.listen<AgentChatState>(agentChatProvider, (prev, next) {
      final prevLen = prev?.messages.length ?? 0;
      final nextLen = next.messages.length;

      // User sent a new message → glance toward user bubble
      if (nextLen > prevLen && next.messages.last.isUser) {
        state = state.copyWith(
          userMessageSeq: state.userMessageSeq + 1,
          lastInteraction: DateTime.now(),
        );
      }

      // Stream started → snapshot diff count to detect new patches on completion
      if (!(prev?.isStreaming ?? false) && next.isStreaming) {
        _diffFilesAtStreamStart = ref.read(gitDiffProvider).snapshot.files.length;
      }

      // Streaming agent text grew → kick talking mouth
      if (next.isStreaming) {
        final prevLastAgentText = _lastAgentText(prev);
        final nextLastAgentText = _lastAgentText(next);
        if (nextLastAgentText.length > prevLastAgentText.length) {
          pulseChunk();
        }
      }

      // Stream finished
      if ((prev?.isStreaming ?? false) && !next.isStreaming) {
        final lastAgent = _lastAgentMessage(next);
        if (next.errorMessage != null || (lastAgent?.isError ?? false)) {
          triggerReaction(
            AvatarReaction.errorShake,
            duration: const Duration(milliseconds: 550),
          );
        } else {
          final currentDiffCount =
              ref.read(gitDiffProvider).snapshot.files.length;
          final badge = (lastAgent?.statusBadge ?? '').toLowerCase();
          final hasNewDiff = currentDiffCount > _diffFilesAtStreamStart;
          final isVerified = badge.contains('verified');
          if (hasNewDiff || isVerified) {
            triggerReaction(
              AvatarReaction.success,
              duration: const Duration(milliseconds: 2400),
            );
          } else {
            triggerReaction(
              AvatarReaction.nod,
              duration: const Duration(milliseconds: 550),
            );
          }
        }
      }
    });

    // Listen to git diff commits → celebrate success
    ref.listen<String?>(
      gitDiffProvider.select((s) => s.snapshot.lastActionMessage),
      (prev, next) {
        if (next != null &&
            next != prev &&
            next.toLowerCase().contains('committed')) {
          triggerReaction(
            AvatarReaction.success,
            duration: const Duration(milliseconds: 2400),
          );
        }
      },
    );

    return AvatarControllerState(lastInteraction: DateTime.now());
  }

  static String _lastAgentText(AgentChatState? chat) {
    if (chat == null) return '';
    final msg = _lastAgentMessage(chat);
    if (msg == null) return '';
    return '${msg.heading ?? ''}${msg.text}${msg.findings.length}';
  }

  static dynamic _lastAgentMessage(AgentChatState chat) {
    final idx = chat.messages.lastIndexWhere((m) => !m.isUser);
    return idx == -1 ? null : chat.messages[idx];
  }

  void triggerReaction(
    AvatarReaction reaction, {
    Duration duration = const Duration(milliseconds: 1200),
  }) {
    _reactionTimer?.cancel();
    state = state.copyWith(
      activeReaction: reaction,
      reactionSeq: state.reactionSeq + 1,
      lastInteraction: DateTime.now(),
    );
    _reactionTimer = Timer(duration, () {
      state = state.copyWith(activeReaction: null);
    });
  }

  void setComposerActive(bool active) {
    if (state.composerActive == active) return;
    state = state.copyWith(
      composerActive: active,
      lastInteraction: DateTime.now(),
    );
  }

  void registerInteraction() {
    state = state.copyWith(lastInteraction: DateTime.now());
  }

  void pulseChunk() {
    state = state.copyWith(chunkPulseSeq: state.chunkPulseSeq + 1);
  }
}

final avatarControllerProvider =
    NotifierProvider<AvatarController, AvatarControllerState>(
      AvatarController.new,
    );
