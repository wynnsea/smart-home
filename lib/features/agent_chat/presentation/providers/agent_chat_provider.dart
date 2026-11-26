import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/wynn_bridge_client.dart';
import '../../../../core/storage/app_local_storage.dart';
import '../../../git_diff/presentation/providers/git_diff_provider.dart';
import '../../data/datasources/mock_agent_chat_datasource.dart';
import '../../data/datasources/openrouter_agent_datasource.dart';
import '../../data/repositories/agent_chat_repository_impl.dart';
import '../../domain/entities/ai_gateway_entities.dart';
import '../../domain/entities/chat_entities.dart';
import '../../domain/repositories/agent_chat_repository.dart';
import '../../domain/usecases/send_coding_prompt.dart';
import 'ai_gateway_provider.dart';
import 'token_usage_provider.dart';

const Object _unset = Object();

class AgentChatState {
  const AgentChatState({
    required this.sessions,
    required this.activeSessionId,
    required this.mode,
    required this.selectedModel,
    this.selectedAgentId = 'wynn-coder',
    this.isStreaming = false,
    this.isVoiceListening = false,
    this.attachedContextFiles = const [],
    this.errorMessage,
  });

  final List<ChatSession> sessions;
  final String activeSessionId;
  final AgentMode mode;
  final String selectedModel;
  final String selectedAgentId;
  final bool isStreaming;
  final bool isVoiceListening;
  final List<String> attachedContextFiles;
  final String? errorMessage;

  AiAgentProfile get selectedAgent => findAgentById(selectedAgentId);

  ChatSession get activeSession => sessions.firstWhere(
    (s) => s.id == activeSessionId,
    orElse: () => sessions.first,
  );

  String get sessionTitle => activeSession.title;
  String get repoFullName => activeSession.repoFullName;
  String get branch => activeSession.branch;
  List<ChatMessage> get messages => activeSession.messages;
  List<ExecutionLogEntry> get logs => activeSession.logs;

  AgentChatState copyWith({
    List<ChatSession>? sessions,
    String? activeSessionId,
    AgentMode? mode,
    String? selectedModel,
    String? selectedAgentId,
    bool? isStreaming,
    bool? isVoiceListening,
    List<String>? attachedContextFiles,
    Object? errorMessage = _unset,
  }) {
    return AgentChatState(
      sessions: sessions ?? this.sessions,
      activeSessionId: activeSessionId ?? this.activeSessionId,
      mode: mode ?? this.mode,
      selectedModel: selectedModel ?? this.selectedModel,
      selectedAgentId: selectedAgentId ?? this.selectedAgentId,
      isStreaming: isStreaming ?? this.isStreaming,
      isVoiceListening: isVoiceListening ?? this.isVoiceListening,
      attachedContextFiles: attachedContextFiles ?? this.attachedContextFiles,
      errorMessage: errorMessage == _unset
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

final agentChatRepositoryProvider = Provider<AgentChatRepository>((ref) {
  return AgentChatRepositoryImpl(
    MockAgentChatDatasource(),
    remoteDatasource: OpenRouterAgentDatasource(),
    configReader: () => ref.read(aiGatewayProvider),
    bridgeClient: WynnBridgeClient(),
    bridgeConfigReader: () => ref.read(bridgeConfigProvider),
  );
});

class AgentChatNotifier extends Notifier<AgentChatState> {
  static final List<String> availableModels = [
    for (final model in kOpenRouterModels) model.label,
  ];

  StreamSubscription<PromptStreamChunk>? _activeSubscription;

  @override
  AgentChatState build() {
    ref.onDispose(() {
      _activeSubscription?.cancel();
      _activeSubscription = null;
    });

    final saved = AppLocalStorage.loadChatSnapshot();
    if (saved != null && saved.sessions.isNotEmpty) {
      return AgentChatState(
        sessions: saved.sessions,
        activeSessionId: saved.activeSessionId,
        mode: saved.mode,
        selectedModel: saved.selectedModel,
        selectedAgentId: saved.selectedAgentId,
      );
    }

    final repo = ref.watch(agentChatRepositoryProvider);
    final initialSessions = [
      ChatSession(
        id: 'session-default',
        title: 'Sesi baru',
        repoFullName: 'OpenRouter / Remote Host',
        branch: 'main',
        messages: repo.getInitialMessages(),
        logs: repo.getInitialLogs(),
        updatedAt: 'Baru saja',
      ),
    ];

    return AgentChatState(
      sessions: initialSessions,
      activeSessionId: initialSessions.first.id,
      mode: AgentMode.agent,
      selectedModel: availableModels.first,
    );
  }

  void _persistState() {
    unawaited(
      AppLocalStorage.saveChatSnapshot(
        sessions: state.sessions,
        activeSessionId: state.activeSessionId,
        mode: state.mode,
        selectedModel: state.selectedModel,
        selectedAgentId: state.selectedAgentId,
      ),
    );
  }

  void _updateActiveSession(ChatSession Function(ChatSession current) updater) {
    final activeId = state.activeSessionId;
    final updatedSessions = state.sessions.map((s) {
      if (s.id == activeId) return updater(s);
      return s;
    }).toList();
    state = state.copyWith(sessions: updatedSessions);
  }

  void setMode(AgentMode mode) {
    state = state.copyWith(mode: mode);
    _persistState();
  }

  void setModel(String model) {
    state = state.copyWith(selectedModel: model);
    _persistState();
  }

  void setAgent(AiAgentProfile agent, {bool applyDefaultModel = true}) {
    state = state.copyWith(
      selectedAgentId: agent.id,
      selectedModel: applyDefaultModel
          ? agent.defaultModelLabel
          : state.selectedModel,
    );
    _persistState();
  }

  void toggleVoiceInput() {
    state = state.copyWith(isVoiceListening: !state.isVoiceListening);
  }

  void attachContextFile(String fileName) {
    if (state.attachedContextFiles.contains(fileName)) return;
    state = state.copyWith(
      attachedContextFiles: [...state.attachedContextFiles, fileName],
    );
  }

  void removeContextFile(String fileName) {
    state = state.copyWith(
      attachedContextFiles: state.attachedContextFiles
          .where((f) => f != fileName)
          .toList(),
    );
  }

  void toggleLike(String messageId) {
    _updateActiveSession((session) {
      final updated = session.messages.map((m) {
        if (m.id == messageId) {
          return m.copyWith(isLiked: !m.isLiked);
        }
        return m;
      }).toList();
      return session.copyWith(messages: updated);
    });
    _persistState();
  }

  void openSessionById(
    String sessionId, {
    String? fallbackTitle,
    String? fallbackRepo,
    String? fallbackBranch,
    String? fallbackSummary,
  }) {
    if (state.isStreaming) stopStreaming();
    final exists = state.sessions.any((s) => s.id == sessionId);
    if (exists) {
      state = state.copyWith(activeSessionId: sessionId, errorMessage: null);
      _persistState();
      return;
    }

    final created = ChatSession(
      id: sessionId,
      title: fallbackTitle ?? 'Sesi baru',
      repoFullName: fallbackRepo ?? state.repoFullName,
      branch: fallbackBranch ?? state.branch,
      messages: fallbackSummary != null && fallbackSummary.isNotEmpty
          ? [
              ChatMessage(
                id: 'summary-$sessionId',
                isUser: false,
                timestampLabel: 'Baru',
                heading: fallbackTitle ?? 'Ringkasan Sesi',
                text: fallbackSummary,
              ),
            ]
          : const [],
      logs: const [],
      updatedAt: 'Baru saja',
    );

    state = state.copyWith(
      sessions: [created, ...state.sessions],
      activeSessionId: created.id,
      errorMessage: null,
    );
    _persistState();
  }

  void newSession({String? repoFullName, String? branch}) {
    if (state.isStreaming) stopStreaming();
    final id = 'session-${DateTime.now().millisecondsSinceEpoch}';
    final created = ChatSession(
      id: id,
      title: 'Sesi baru',
      repoFullName: repoFullName ?? state.repoFullName,
      branch: branch ?? state.branch,
      messages: const [],
      logs: const [],
      updatedAt: 'Baru saja',
    );
    state = state.copyWith(
      sessions: [created, ...state.sessions],
      activeSessionId: created.id,
      attachedContextFiles: const [],
      errorMessage: null,
    );
    _persistState();
  }

  void openOrCreateBranchSession(String branch) {
    if (state.isStreaming) stopStreaming();
    final match = state.sessions.where((s) => s.branch == branch).toList();
    if (match.isNotEmpty) {
      state = state.copyWith(
        activeSessionId: match.first.id,
        errorMessage: null,
      );
      return;
    }
    newSession(repoFullName: state.repoFullName, branch: branch);
  }

  void stopStreaming() {
    _activeSubscription?.cancel();
    _activeSubscription = null;

    if (!state.isStreaming) return;

    final now = DateTime.now();
    final logTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    _updateActiveSession((session) {
      final msgs = [...session.messages];
      final lastAgentIdx = msgs.lastIndexWhere((m) => !m.isUser);
      if (lastAgentIdx != -1 && msgs[lastAgentIdx].isStreaming) {
        msgs[lastAgentIdx] = msgs[lastAgentIdx].copyWith(
          isStreaming: false,
          statusBadge: 'Dihentikan',
        );
      }
      return session.copyWith(
        messages: msgs,
        logs: [
          ...session.logs,
          ExecutionLogEntry(
            time: logTime,
            command: 'SIGINT stream',
            detail: 'Streaming dihentikan oleh pengguna',
            isSuccess: false,
          ),
        ],
        updatedAt: 'Baru saja',
      );
    });

    state = state.copyWith(isStreaming: false, errorMessage: null);
    _persistState();
  }

  Future<void> retryMessage(String agentMessageId) async {
    if (state.isStreaming) return;
    final currentMessages = state.messages;
    final idx = currentMessages.indexWhere((m) => m.id == agentMessageId);
    if (idx == -1) return;

    ChatMessage? precedingUser;
    for (var i = idx - 1; i >= 0; i--) {
      if (currentMessages[i].isUser) {
        precedingUser = currentMessages[i];
        break;
      }
    }
    if (precedingUser == null) return;

    _updateActiveSession((session) {
      final updatedMsgs = [...session.messages]..removeAt(idx);
      return session.copyWith(messages: updatedMsgs);
    });
    state = state.copyWith(errorMessage: null);

    await sendPrompt(
      precedingUser.text,
      contextFilesOverride: precedingUser.fileChips,
      skipAppendingUserMessage: true,
    );
  }

  Future<void> sendPrompt(
    String rawPrompt, {
    List<String>? contextFilesOverride,
    bool skipAppendingUserMessage = false,
  }) async {
    final prompt = rawPrompt.trim();
    if (prompt.isEmpty || state.isStreaming) return;

    await _activeSubscription?.cancel();
    _activeSubscription = null;

    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final attachedFiles = contextFilesOverride ?? state.attachedContextFiles;

    _updateActiveSession((session) {
      final nextMessages = [...session.messages];
      if (!skipAppendingUserMessage) {
        nextMessages.add(
          ChatMessage(
            id: 'user-${now.millisecondsSinceEpoch}',
            isUser: true,
            timestampLabel: timeStr,
            text: prompt,
            fileChips: attachedFiles,
          ),
        );
      }
      final nextTitle = session.title == 'Sesi baru'
          ? (prompt.length > 34 ? '${prompt.substring(0, 34)}…' : prompt)
          : session.title;
      return session.copyWith(
        title: nextTitle,
        messages: nextMessages,
        updatedAt: 'Baru saja',
      );
    });

    state = state.copyWith(
      isStreaming: true,
      isVoiceListening: false,
      attachedContextFiles: contextFilesOverride == null
          ? const []
          : state.attachedContextFiles,
      errorMessage: null,
    );
    _persistState();

    final useCase = SendCodingPromptUseCase(
      ref.read(agentChatRepositoryProvider),
    );
    final targetSessionId = state.activeSessionId;
    final completer = Completer<void>();

    try {
      final stream = useCase(
        prompt: prompt,
        mode: state.mode,
        modelName: state.selectedModel,
        agent: state.selectedAgent,
        history: state.messages,
        attachedFiles: attachedFiles,
      );

      _activeSubscription = stream.listen(
        (chunk) {
          final updatedSessions = state.sessions.map((session) {
            if (session.id != targetSessionId) return session;
            final msgs = [...session.messages];
            final existingIdx = msgs.indexWhere(
              (m) => m.id == chunk.partialMessage.id,
            );
            if (existingIdx == -1) {
              msgs.add(chunk.partialMessage);
            } else {
              msgs[existingIdx] = chunk.partialMessage;
            }
            final updatedLogs = chunk.logEntry != null
                ? [...session.logs, chunk.logEntry!]
                : session.logs;
            return session.copyWith(
              messages: msgs,
              logs: updatedLogs,
              updatedAt: 'Baru saja',
            );
          }).toList();

          state = state.copyWith(
            sessions: updatedSessions,
            isStreaming: chunk.partialMessage.isStreaming,
          );

          if (chunk.tokenUsage != null) {
            final u = chunk.tokenUsage!;
            ref.read(tokenUsageProvider.notifier).recordUsage(
              model: u.model,
              promptTokens: u.promptTokens,
              completionTokens: u.completionTokens,
              totalTokens: u.totalTokens,
              source: u.source,
            );
          }

          if (!chunk.partialMessage.isStreaming) {
            _persistState();
          }

          if (chunk.shouldGenerateDiff) {
            if (ref.read(bridgeConfigProvider).isActive) {
              unawaited(ref.read(gitDiffProvider.notifier).refresh());
            } else {
              ref.read(gitDiffProvider.notifier).addGeneratedPatch(prompt);
            }
          }
        },
        onError: (Object error, StackTrace _) {
          _handleStreamError(error, targetSessionId);
          if (!completer.isCompleted) completer.complete();
        },
        onDone: () {
          _activeSubscription = null;
          if (state.isStreaming) {
            state = state.copyWith(isStreaming: false);
          }
          _persistState();
          if (!completer.isCompleted) completer.complete();
        },
        cancelOnError: true,
      );

      await completer.future;
    } catch (error) {
      _handleStreamError(error, targetSessionId);
    } finally {
      _activeSubscription = null;
      if (state.isStreaming) {
        state = state.copyWith(isStreaming: false);
      }
    }
  }

  void _handleStreamError(Object error, String targetSessionId) {
    final errMsg = error.toString().replaceFirst('Exception: ', '');
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final logTime = '$timeStr:${now.second.toString().padLeft(2, '0')}';

    final updatedSessions = state.sessions.map((session) {
      if (session.id != targetSessionId) return session;
      final msgs = [...session.messages];
      final lastAgentIdx = msgs.lastIndexWhere((m) => !m.isUser);
      if (lastAgentIdx != -1 && msgs[lastAgentIdx].isStreaming) {
        msgs[lastAgentIdx] = msgs[lastAgentIdx].copyWith(
          heading: 'Permintaan gagal diproses',
          text: errMsg,
          statusBadge: 'Gagal — ketuk untuk coba lagi',
          isStreaming: false,
          isError: true,
        );
      } else {
        msgs.add(
          ChatMessage(
            id: 'err-${now.millisecondsSinceEpoch}',
            isUser: false,
            timestampLabel: timeStr,
            heading: 'Permintaan gagal diproses',
            text: errMsg,
            statusBadge: 'Gagal — ketuk untuk coba lagi',
            isStreaming: false,
            isError: true,
          ),
        );
      }
      return session.copyWith(
        messages: msgs,
        logs: [
          ...session.logs,
          ExecutionLogEntry(
            time: logTime,
            command: 'ERR /prompt',
            detail: errMsg,
            isSuccess: false,
          ),
        ],
        updatedAt: 'Baru saja',
      );
    }).toList();

    state = state.copyWith(
      sessions: updatedSessions,
      isStreaming: false,
      errorMessage: errMsg,
    );
    _persistState();
  }
}

final agentChatProvider = NotifierProvider<AgentChatNotifier, AgentChatState>(
  AgentChatNotifier.new,
);
