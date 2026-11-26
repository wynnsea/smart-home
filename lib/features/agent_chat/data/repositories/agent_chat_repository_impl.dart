import '../../domain/entities/ai_gateway_entities.dart';
import '../../domain/entities/chat_entities.dart';
import '../../domain/repositories/agent_chat_repository.dart';
import '../datasources/mock_agent_chat_datasource.dart';
import '../datasources/openrouter_agent_datasource.dart';

/// Repository routing prompt streams to [OpenRouterAgentDatasource] when an
/// AI Gateway API key is configured, and falling back cleanly to
/// [MockAgentChatDatasource] when running offline / without an API key.
class AgentChatRepositoryImpl implements AgentChatRepository {
  AgentChatRepositoryImpl(
    this._mockDatasource, {
    OpenRouterAgentDatasource? remoteDatasource,
    AiGatewayConfig Function()? configReader,
  }) : _remoteDatasource = remoteDatasource ?? OpenRouterAgentDatasource(),
       _configReader = configReader ?? AiGatewayConfig.fromEnvironment;

  final MockAgentChatDatasource _mockDatasource;
  final OpenRouterAgentDatasource _remoteDatasource;
  final AiGatewayConfig Function() _configReader;

  @override
  List<ChatMessage> getInitialMessages() => _mockDatasource.loadInitialMessages();

  @override
  List<ExecutionLogEntry> getInitialLogs() => _mockDatasource.loadInitialLogs();

  @override
  Stream<PromptStreamChunk> streamPromptResponse({
    required String prompt,
    required AgentMode mode,
    required String modelName,
    AiAgentProfile? agent,
    List<ChatMessage> history = const [],
    List<String> attachedFiles = const [],
  }) {
    final config = _configReader();
    if (config.isConfigured) {
      return _remoteDatasource.streamChatCompletion(
        config: config,
        prompt: prompt,
        mode: mode,
        modelName: modelName,
        agent: agent ?? kBuiltInAgents.first,
        history: history,
        attachedFiles: attachedFiles,
      );
    }

    return _mockDatasource.streamMockResponse(
      prompt: prompt,
      mode: mode,
      modelName: modelName,
    );
  }
}
