import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/app_local_storage.dart';
import '../../data/datasources/openrouter_agent_datasource.dart';
import '../../domain/entities/ai_gateway_entities.dart';

/// Holds the active OpenAI-compatible AI Gateway configuration (default: OpenRouter).
/// Automatically restores saved settings from [AppLocalStorage] and persists updates.
class AiGatewayNotifier extends Notifier<AiGatewayConfig> {
  @override
  AiGatewayConfig build() {
    return AppLocalStorage.loadAiGatewayConfig(
      fallback: AiGatewayConfig.fromEnvironment(),
    );
  }

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
    unawaited(AppLocalStorage.saveAiGatewayConfig(state));
  }

  void applyGatewayPreset(String baseUrl) {
    state = state.copyWith(baseUrl: baseUrl.trim());
    unawaited(AppLocalStorage.saveAiGatewayConfig(state));
  }

  Future<GatewayTestResult> testConnection() {
    return OpenRouterAgentDatasource().testGatewayConnection(state);
  }
}

final aiGatewayProvider = NotifierProvider<AiGatewayNotifier, AiGatewayConfig>(
  AiGatewayNotifier.new,
);
