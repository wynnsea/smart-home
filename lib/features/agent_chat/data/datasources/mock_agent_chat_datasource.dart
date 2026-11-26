import '../../domain/entities/chat_entities.dart';

/// Fallback datasource used only when neither PC Bridge nor OpenRouter API key
/// is configured. Starts completely empty with zero dummy messages or logs.
class MockAgentChatDatasource {
  List<ChatMessage> loadInitialMessages() => const [];

  List<ExecutionLogEntry> loadInitialLogs() => const [];

  Stream<PromptStreamChunk> streamMockResponse({
    required String prompt,
    required AgentMode mode,
    required String modelName,
  }) async* {
    final msgId = 'agent-${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final logTime = '$timeStr:${now.second.toString().padLeft(2, '0')}';

    yield PromptStreamChunk(
      partialMessage: ChatMessage(
        id: msgId,
        isUser: false,
        timestampLabel: timeStr,
        heading: 'Menunggu konfigurasi AI…',
        statusBadge: '${mode.label} · $modelName',
        text: 'Memproses "$prompt"...',
        isStreaming: true,
      ),
      logEntry: ExecutionLogEntry(
        time: logTime,
        command: 'local_fallback [${mode.label.toLowerCase()}]',
        detail: 'Belum ada API Key OpenRouter atau Remote Bridge aktif',
        isSuccess: true,
      ),
    );

    if (prompt.toLowerCase().contains('/fail')) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      throw Exception('Simulasi error stream (/fail)');
    }

    await Future<void>.delayed(const Duration(milliseconds: 400));

    yield PromptStreamChunk(
      partialMessage: ChatMessage(
        id: msgId,
        isUser: false,
        timestampLabel: timeStr,
        heading: 'AI Gateway belum aktif',
        statusBadge: 'Mock Mode',
        text:
            'Isi OPENROUTER_API_KEY di `.env` atau tab Host → AI Gateway (OpenRouter) agar Wynn tersambung ke AI sungguhan.',
        isStreaming: false,
      ),
    );
  }
}
