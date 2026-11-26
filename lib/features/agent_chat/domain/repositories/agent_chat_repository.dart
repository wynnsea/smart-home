import '../entities/chat_entities.dart';

abstract interface class AgentChatRepository {
  List<ChatMessage> getInitialMessages();
  List<ExecutionLogEntry> getInitialLogs();
  Stream<PromptStreamChunk> streamPromptResponse({
    required String prompt,
    required AgentMode mode,
    required String modelName,
  });
}
