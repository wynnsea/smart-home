import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wynndiff/features/agent_chat/domain/entities/chat_entities.dart';
import 'package:wynndiff/features/agent_chat/presentation/providers/agent_chat_provider.dart';
import 'package:wynndiff/features/ai_avatar/domain/avatar_mood.dart';
import 'package:wynndiff/features/ai_avatar/presentation/providers/avatar_controller.dart';
import 'package:wynndiff/features/ai_avatar/presentation/providers/avatar_mood_provider.dart';
import 'package:wynndiff/features/workspace/domain/entities/workspace_entities.dart';
import 'package:wynndiff/features/workspace/presentation/providers/workspace_provider.dart';

class _TestWorkspaceNotifier extends WorkspaceNotifier {
  _TestWorkspaceNotifier(this._initialConnection);
  final HostConnectionState _initialConnection;

  @override
  WorkspaceOverview build() {
    final base = super.build();
    return base.copyWith(
      hostStatus: base.hostStatus.copyWith(connectionState: _initialConnection),
    );
  }
}

class _TestChatNotifier extends AgentChatNotifier {
  _TestChatNotifier({
    this.streaming = false,
    this.errorMsg,
    this.agentMode = AgentMode.agent,
    this.messagesOverride,
  });

  final bool streaming;
  final String? errorMsg;
  final AgentMode agentMode;
  final List<ChatMessage>? messagesOverride;

  @override
  AgentChatState build() {
    final base = super.build();
    final updatedSessions = base.sessions.map((s) {
      if (s.id != base.activeSessionId) return s;
      return s.copyWith(messages: messagesOverride ?? s.messages);
    }).toList();

    return base.copyWith(
      sessions: updatedSessions,
      isStreaming: streaming,
      errorMessage: errorMsg,
      mode: agentMode,
    );
  }
}

void main() {
  group('avatarMoodProvider priority order', () {
    test('offline beats streaming and error', () {
      final container = ProviderContainer(
        overrides: [
          workspaceOverviewProvider.overrideWith(
            () => _TestWorkspaceNotifier(HostConnectionState.disconnected),
          ),
          agentChatProvider.overrideWith(
            () => _TestChatNotifier(streaming: true, errorMsg: 'boom'),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(avatarMoodProvider), equals(AvatarMood.offline));
    });

    test('connecting beats error and streaming', () {
      final container = ProviderContainer(
        overrides: [
          workspaceOverviewProvider.overrideWith(
            () => _TestWorkspaceNotifier(HostConnectionState.connecting),
          ),
          agentChatProvider.overrideWith(
            () => _TestChatNotifier(streaming: true, errorMsg: 'boom'),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(avatarMoodProvider), equals(AvatarMood.connecting));
    });

    test('error beats streaming and listening', () {
      final container = ProviderContainer(
        overrides: [
          agentChatProvider.overrideWith(
            () => _TestChatNotifier(streaming: true, errorMsg: 'HTTP 502'),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(avatarControllerProvider.notifier).setComposerActive(true);

      expect(container.read(avatarMoodProvider), equals(AvatarMood.error));
    });

    test('streaming with empty agent text yields thinking; with text yields streaming', () {
      final emptyStreamContainer = ProviderContainer(
        overrides: [
          agentChatProvider.overrideWith(
            () => _TestChatNotifier(
              streaming: true,
              messagesOverride: const [
                ChatMessage(
                  id: 'a1',
                  isUser: false,
                  timestampLabel: '10:00',
                  text: '',
                  isStreaming: true,
                ),
              ],
            ),
          ),
        ],
      );
      addTearDown(emptyStreamContainer.dispose);
      expect(
        emptyStreamContainer.read(avatarMoodProvider),
        equals(AvatarMood.thinking),
      );

      final textStreamContainer = ProviderContainer(
        overrides: [
          agentChatProvider.overrideWith(
            () => _TestChatNotifier(
              streaming: true,
              messagesOverride: const [
                ChatMessage(
                  id: 'a2',
                  isUser: false,
                  timestampLabel: '10:00',
                  text: 'Scanning symbols...',
                  isStreaming: true,
                ),
              ],
            ),
          ),
        ],
      );
      addTearDown(textStreamContainer.dispose);
      expect(
        textStreamContainer.read(avatarMoodProvider),
        equals(AvatarMood.streaming),
      );
    });

    test('investigate mode while streaming yields thinking', () {
      final container = ProviderContainer(
        overrides: [
          agentChatProvider.overrideWith(
            () => _TestChatNotifier(
              streaming: true,
              agentMode: AgentMode.investigate,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(avatarMoodProvider), equals(AvatarMood.thinking));
    });

    test('composerActive yields listening when idle, and success reaction overrides listening', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(avatarMoodProvider), equals(AvatarMood.idle));

      container.read(avatarControllerProvider.notifier).setComposerActive(true);
      expect(container.read(avatarMoodProvider), equals(AvatarMood.listening));

      container
          .read(avatarControllerProvider.notifier)
          .triggerReaction(AvatarReaction.success);
      expect(container.read(avatarMoodProvider), equals(AvatarMood.success));
    });
  });
}
