import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/openrouter_agent_datasource.dart';
import '../../domain/entities/ai_gateway_entities.dart';

/// Holds the active OpenAI-compatible AI Gateway configuration (default: OpenRouter).
/// Users can configure API Key & Base URL at runtime in HostSettingsPage or
/// via `--dart-define=OPENROUTER_API_KEY=...`.
class AiGatewayNotifier extends Notifier<AiGatewayConfig> {
  @override
  AiGatewayConfig build() => AiGatewayConfig.fromEnvironment();

  void updateConfig({
    String? baseUrl,
    String? apiKey,
    bool? useLiveGateway,
  }) {
    state = state.copyWith(
      baseUrl: baseUrl?.trim(),
      apiKey: apiKey?.trim(),
      useLiveGateway: useLiveGateway,
    );
  }

  void applyGatewayPreset(String baseUrl) {
    state = state.copyWith(baseUrl: baseUrl.trim());
  }

  Future<GatewayTestResult> testConnection() {
    return OpenRouterAgentDatasource().testGatewayConnection(state);
  }
}

final aiGatewayProvider = NotifierProvider<AiGatewayNotifier, AiGatewayConfig>(
  AiGatewayNotifier.new,
);
