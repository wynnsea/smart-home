import 'package:material_ui/material_ui.dart';

import '../../../../core/config/app_env.dart';

/// Specialized AI agent persona with its own system prompt and default model.
@immutable
class AiAgentProfile {
  const AiAgentProfile({
    required this.id,
    required this.name,
    required this.tagline,
    required this.systemPrompt,
    required this.defaultModelLabel,
  });

  final String id;
  final String name;
  final String tagline;
  final String systemPrompt;
  final String defaultModelLabel;
}

/// Curated OpenRouter model option mapping friendly UI labels to OpenRouter slugs.
@immutable
class AiModelOption {
  const AiModelOption({
    required this.id,
    required this.label,
    required this.provider,
    this.isFree = false,
  });

  /// OpenRouter model slug (e.g. `google/gemini-2.5-flash`).
  final String id;
  final String label;
  final String provider;
  final bool isFree;
}

/// Built-in multi-agent roster routed through the same AI Gateway.
const List<AiAgentProfile> kBuiltInAgents = [
  AiAgentProfile(
    id: 'wynn-coder',
    name: 'Wynn Coder',
    tagline: 'Coding, refactor & fitur baru',
    defaultModelLabel: 'Gemini 2.5 Flash',
    systemPrompt:
        'Kamu adalah Wynn, asisten coding senior yang ramah dan ringkas. '
        'Berikan solusi kode yang bersih, akurat, dan siap pakai dengan penjelasan singkat.',
  ),
  AiAgentProfile(
    id: 'bug-hunter',
    name: 'Bug Hunter',
    tagline: 'Investigasi root-cause & debugging',
    defaultModelLabel: 'Claude 4 Sonnet',
    systemPrompt:
        'Kamu adalah Bug Hunter spesialis root-cause analysis. '
        'Fokus menemukan penyebab bug, race condition, edge case, dan langkah perbaikan minimal yang aman.',
  ),
  AiAgentProfile(
    id: 'code-reviewer',
    name: 'Code Reviewer',
    tagline: 'Audit diff, performa & keamanan',
    defaultModelLabel: 'GPT-4.1 Mini',
    systemPrompt:
        'Kamu adalah Code Reviewer yang teliti. '
        'Tinjau kode untuk potensi bug, celah keamanan, performa, dan keterbacaan secara terstruktur.',
  ),
  AiAgentProfile(
    id: 'ui-architect',
    name: 'UI/UX Architect',
    tagline: 'Desain Flutter, animasi & aksesibilitas',
    defaultModelLabel: 'Gemini 2.5 Pro',
    systemPrompt:
        'Kamu adalah UI/UX Architect spesialis Flutter & desain modern. '
        'Bantu merancang layout responsif, animasi halus, dan pengalaman pengguna yang intuitif.',
  ),
  AiAgentProfile(
    id: 'wynn-free',
    name: 'Wynn Fast',
    tagline: 'Tanya jawab cepat (Model gratis)',
    defaultModelLabel: 'Gemini 2.0 Flash (Free)',
    systemPrompt:
        'Kamu adalah Wynn Fast, asisten serba bisa yang cepat, jelas, dan to-the-point.',
  ),
];

/// OpenRouter model catalog (paid + free tiers + auto router).
const List<AiModelOption> kOpenRouterModels = [
  AiModelOption(
    id: 'google/gemini-2.5-flash',
    label: 'Gemini 2.5 Flash',
    provider: 'Google',
  ),
  AiModelOption(
    id: 'anthropic/claude-sonnet-4',
    label: 'Claude 4 Sonnet',
    provider: 'Anthropic',
  ),
  AiModelOption(
    id: 'google/gemini-2.5-pro',
    label: 'Gemini 2.5 Pro',
    provider: 'Google',
  ),
  AiModelOption(
    id: 'openai/gpt-4.1-mini',
    label: 'GPT-4.1 Mini',
    provider: 'OpenAI',
  ),
  AiModelOption(
    id: 'google/gemini-2.0-flash-exp:free',
    label: 'Gemini 2.0 Flash (Free)',
    provider: 'Google',
    isFree: true,
  ),
  AiModelOption(
    id: 'deepseek/deepseek-r1:free',
    label: 'DeepSeek R1 (Free)',
    provider: 'DeepSeek',
    isFree: true,
  ),
  AiModelOption(
    id: 'openrouter/auto',
    label: 'OpenRouter Auto',
    provider: 'OpenRouter',
  ),
];

/// Resolves a UI model label (e.g. `'Claude 4 Sonnet'`) or raw OpenRouter slug
/// (e.g. `'anthropic/claude-sonnet-4'`) to a valid OpenRouter model ID.
String resolveOpenRouterModelId(String labelOrSlug) {
  final trimmed = labelOrSlug.trim();
  for (final opt in kOpenRouterModels) {
    if (opt.label == trimmed || opt.id == trimmed) {
      return opt.id;
    }
  }
  return trimmed.isEmpty ? kOpenRouterModels.first.id : trimmed;
}

/// Finds an [AiAgentProfile] by [id], falling back to the first built-in agent.
AiAgentProfile findAgentById(String id) {
  for (final agent in kBuiltInAgents) {
    if (agent.id == id) return agent;
  }
  return kBuiltInAgents.first;
}

const String kDefaultOpenRouterBaseUrl = 'https://openrouter.ai/api/v1';

/// Runtime configuration for the OpenAI-compatible AI Gateway (default: OpenRouter).
@immutable
class AiGatewayConfig {
  const AiGatewayConfig({
    this.baseUrl = kDefaultOpenRouterBaseUrl,
    this.apiKey = '',
    this.useLiveGateway = true,
    this.siteTitle = 'WynnDiff Agent',
    this.siteUrl = 'https://github.com/wynnsea/smart-home',
  });

  factory AiGatewayConfig.fromEnvironment() {
    final envUrl = AppEnv.aiGatewayUrl.trim();
    return AiGatewayConfig(
      baseUrl: envUrl.isEmpty ? kDefaultOpenRouterBaseUrl : envUrl,
      apiKey: AppEnv.openRouterApiKey.trim(),
      useLiveGateway: true,
    );
  }

  final String baseUrl;
  final String apiKey;
  final bool useLiveGateway;
  final String siteTitle;
  final String siteUrl;

  /// True when live AI Gateway requests should be sent instead of mock responses.
  bool get isConfigured =>
      useLiveGateway && apiKey.trim().isNotEmpty && baseUrl.trim().isNotEmpty;

  String get _normalizedBaseUrl {
    final trimmed = baseUrl.trim();
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  Uri get chatCompletionsUri => Uri.parse('$_normalizedBaseUrl/chat/completions');

  Uri get modelsUri => Uri.parse('$_normalizedBaseUrl/models');

  AiGatewayConfig copyWith({
    String? baseUrl,
    String? apiKey,
    bool? useLiveGateway,
    String? siteTitle,
    String? siteUrl,
  }) {
    return AiGatewayConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      useLiveGateway: useLiveGateway ?? this.useLiveGateway,
      siteTitle: siteTitle ?? this.siteTitle,
      siteUrl: siteUrl ?? this.siteUrl,
    );
  }
}

/// Result returned when testing connectivity against the AI Gateway.
@immutable
class GatewayTestResult {
  const GatewayTestResult({
    required this.ok,
    required this.message,
    this.latencyMs = 0,
    this.modelCount = 0,
  });

  final bool ok;
  final String message;
  final int latencyMs;
  final int modelCount;
}
