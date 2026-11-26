import '../../domain/entities/chat_entities.dart';
import '../../domain/repositories/agent_chat_repository.dart';
import '../datasources/mock_agent_chat_datasource.dart';

class AgentChatRepositoryImpl implements AgentChatRepository {
  const AgentChatRepositoryImpl(this._datasource);

  final MockAgentChatDatasource _datasource;

  @override
  List<ChatMessage> getInitialMessages() => _datasource.loadInitialMessages();

  @override
  List<ExecutionLogEntry> getInitialLogs() => _datasource.loadInitialLogs();

  @override
  Stream<PromptStreamChunk> streamPromptResponse({
    required String prompt,
    required AgentMode mode,
    required String modelName,
  }) {
    return _datasource.streamMockResponse(
      prompt: prompt,
      mode: mode,
      modelName: modelName,
    );
  }
}
