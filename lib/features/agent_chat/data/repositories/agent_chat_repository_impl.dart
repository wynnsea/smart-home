import '../../../../core/network/wynn_bridge_client.dart';
import '../../domain/entities/ai_gateway_entities.dart';
import '../../domain/entities/chat_entities.dart';
import '../../domain/repositories/agent_chat_repository.dart';
import '../datasources/mock_agent_chat_datasource.dart';
import '../datasources/openrouter_agent_datasource.dart';

/// Repository routing prompt streams with 3-tier priority:
/// 1. Live PC Bridge (`wynndiff_bridge`) when Remote Bridge mode is active
/// 2. Direct OpenRouter AI Gateway when an API key is configured
/// 3. Local MockAgentChatDatasource fallback when offline / unconfigured
class AgentChatRepositoryImpl implements AgentChatRepository {
  AgentChatRepositoryImpl(
    this._mockDatasource, {
    OpenRouterAgentDatasource? remoteDatasource,
    AiGatewayConfig Function()? configReader,
    WynnBridgeClient? bridgeClient,
    BridgeConfig Function()? bridgeConfigReader,
  }) : _remoteDatasource = remoteDatasource ?? OpenRouterAgentDatasource(),
       _configReader = configReader ?? AiGatewayConfig.fromEnvironment,
       _bridgeClient = bridgeClient ?? WynnBridgeClient(),
       _bridgeConfigReader = bridgeConfigReader ?? BridgeConfig.fromEnvironment;

  final MockAgentChatDatasource _mockDatasource;
  final OpenRouterAgentDatasource _remoteDatasource;
  final AiGatewayConfig Function() _configReader;
  final WynnBridgeClient _bridgeClient;
  final BridgeConfig Function() _bridgeConfigReader;

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
    final bridgeConfig = _bridgeConfigReader();
    if (bridgeConfig.isActive) {
      return _bridgeClient.streamRemotePrompt(
        config: bridgeConfig,
        prompt: prompt,
        mode: mode,
        modelName: modelName,
        agent: agent ?? kBuiltInAgents.first,
        history: history,
        attachedFiles: attachedFiles,
      );
    }

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
