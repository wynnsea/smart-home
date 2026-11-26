import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../agent_chat/domain/entities/chat_entities.dart';
import '../../../agent_chat/presentation/providers/agent_chat_provider.dart';
import '../../../workspace/domain/entities/workspace_entities.dart';
import '../../../workspace/presentation/providers/workspace_provider.dart';
import '../../domain/avatar_mood.dart';
import 'avatar_controller.dart';

/// Pure derived provider selecting only the minimal fields needed to compute
/// Wynn's current [AvatarMood] in strict priority order:
/// offline > connecting > error > success (transient) > streaming > thinking > listening > idle.
/// (Transient touch reactions & sleepy timeout are handled locally in AvatarMotionController.)
final avatarMoodProvider = Provider<AvatarMood>((ref) {
  final connectionState = ref.watch(
    workspaceOverviewProvider.select((w) => w.hostStatus.connectionState),
  );
  final isStreaming = ref.watch(agentChatProvider.select((c) => c.isStreaming));
  final errorMessage = ref.watch(
    agentChatProvider.select((c) => c.errorMessage),
  );
  final mode = ref.watch(agentChatProvider.select((c) => c.mode));
  final lastAgentIsError = ref.watch(
    agentChatProvider.select((c) {
      final idx = c.messages.lastIndexWhere((m) => !m.isUser);
      return idx != -1 && c.messages[idx].isError;
    }),
  );
  final lastAgentHasText = ref.watch(
    agentChatProvider.select((c) {
      final idx = c.messages.lastIndexWhere((m) => !m.isUser);
      if (idx == -1) return false;
      final msg = c.messages[idx];
      return msg.text.trim().isNotEmpty;
    }),
  );
  final activeReaction = ref.watch(
    avatarControllerProvider.select((a) => a.activeReaction),
  );
  final composerActive = ref.watch(
    avatarControllerProvider.select((a) => a.composerActive),
  );

  if (connectionState == HostConnectionState.disconnected) {
    return AvatarMood.offline;
  }
  if (connectionState == HostConnectionState.connecting) {
    return AvatarMood.connecting;
  }
  if (errorMessage != null || lastAgentIsError) {
    return AvatarMood.error;
  }
  if (activeReaction == AvatarReaction.success) {
    return AvatarMood.success;
  }
  if (isStreaming) {
    if (!lastAgentHasText || mode == AgentMode.investigate) {
      return AvatarMood.thinking;
    }
    return AvatarMood.streaming;
  }
  if (composerActive) {
    return AvatarMood.listening;
  }
  return AvatarMood.idle;
});
