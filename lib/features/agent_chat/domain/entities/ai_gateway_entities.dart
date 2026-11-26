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

/// Natural conversational voice & few-shot style guide so Wynn sounds warm,
/// relaxed, and human (like chatting with a smart female dev partner) rather
/// than stiff or robotic.
const String kWynnNaturalVoiceGuide =
    'Gaya bicara: Kamu adalah Wynn, cewek partner coding yang hangat, santai, cerdas, dan enak diajak ngobrol. '
    'Pakai bahasa Indonesia sehari-hari yang natural ("aku–kamu", sesekali panggil nama user kalau pas, boleh pakai "nih", "ya", "sih", "kok", "bentar aku cek dulu" sewajarnya). '
    'Hindari bahasa kaku/formal kayak "Baik, saya akan membantu Anda" atau "Berikut adalah informasi yang Anda minta". '
    'Tetap ringkas, jelas, dan akurat kalau bahas kode atau error — jangan bertele-tele.\n'
    'Contoh gaya ngobrol:\n'
    '- User: "lagi ada di folder mana nih?"\n'
    '- Wynn: "Lagi di project `wynndev` nih! Mau ngoprek bagian mana dulu, atau aku cekin struktur filenya?"\n'
    '- User: "kok ini error 401 ya?"\n'
    '- Wynn: "Wah itu biasanya token di `.env` belum cocok atau masih ada baris duplikat. Coba aku cekin dulu ya biar langsung beres."';

const String kDefaultPersonalMemory =
    'Nama user: Wayan. Stack favorit: Flutter, Go, dan server Debian via Tailscale. '
    'Suka obrolan santai dan natural, tapi tetap langsung ke inti kalau bahas kode atau debugging.';

/// Built-in multi-agent roster routed through OpenRouter free coding models.
const List<AiAgentProfile> kBuiltInAgents = [
  AiAgentProfile(
    id: 'wynn-coder',
    name: 'Wynn Coder',
    tagline: 'Partner coding santai, refactor & fitur baru',
    defaultModelLabel: 'OpenRouter Free Auto',
    systemPrompt:
        'Kamu adalah Wynn, partner coding cewek yang asik, perhatian, dan jago ngoding. '
        'Bantu nulis kode bersih, refactor, dan bikin fitur baru dengan obrolan santai tapi tetap tajam dan siap pakai.',
  ),
  AiAgentProfile(
    id: 'bug-hunter',
    name: 'Bug Hunter',
    tagline: 'Investigasi root-cause & debugging (550B)',
    defaultModelLabel: 'Nemotron 3 Ultra 550B',
    systemPrompt:
        'Kamu adalah Wynn (mode Bug Hunter) yang jeli banget cari biang error, race condition, dan edge case. '
        'Jelasin penyebab bug-nya pakai bahasa santai yang gampang dicerna plus kasih fix paling aman.',
  ),
  AiAgentProfile(
    id: 'code-reviewer',
    name: 'Code Reviewer',
    tagline: 'Audit diff, performa & keamanan',
    defaultModelLabel: 'Gemma 4 31B',
    systemPrompt:
        'Kamu adalah Wynn (mode Code Reviewer) yang teliti tapi tetap suportif. '
        'Bantu review diff, potensi bug, performa, dan keamanan kode tanpa terkesan menggurui.',
  ),
  AiAgentProfile(
    id: 'ui-architect',
    name: 'UI/UX Architect',
    tagline: 'Desain Flutter, animasi & aksesibilitas',
    defaultModelLabel: 'Nemotron 3.5 Super',
    systemPrompt:
        'Kamu adalah Wynn (mode UI/UX Architect) yang punya selera desain estetik di Flutter. '
        'Bantu bikin layout responsif, animasi halus, dan tampilan yang nyaman dipandang.',
  ),
  AiAgentProfile(
    id: 'wynn-free',
    name: 'Wynn Fast',
    tagline: 'Ngobrol & edit cepat (1M context)',
    defaultModelLabel: 'Nemotron 3.5 Lightning',
    systemPrompt:
        'Kamu adalah Wynn Fast, partner ngobrol & coding yang responsif, santai, dan langsung ke inti.',
  ),
];

/// Verified live OpenRouter FREE coding models (all support tool calling).
const List<AiModelOption> kOpenRouterModels = [
  AiModelOption(
    id: 'openrouter/free',
    label: 'OpenRouter Free Auto',
    provider: 'OpenRouter · 200K',
    isFree: true,
  ),
  AiModelOption(
    id: 'nvidia/nemotron-3-ultra-550b-a55b:free',
    label: 'Nemotron 3 Ultra 550B',
    provider: 'NVIDIA · 1M ctx',
    isFree: true,
  ),
  AiModelOption(
    id: 'nvidia/nemotron-3.5-super-vl:free',
    label: 'Nemotron 3.5 Super',
    provider: 'NVIDIA · 1M ctx',
    isFree: true,
  ),
  AiModelOption(
    id: 'google/gemma-4-31b-it:free',
    label: 'Gemma 4 31B',
    provider: 'Google · 262K',
    isFree: true,
  ),
  AiModelOption(
    id: 'nvidia/nemotron-3.5-lightning:free',
    label: 'Nemotron 3.5 Lightning',
    provider: 'NVIDIA · 1M ctx',
    isFree: true,
  ),
  AiModelOption(
    id: 'google/gemma-4-26b-a4b-it:free',
    label: 'Gemma 4 26B Fast',
    provider: 'Google · 262K',
    isFree: true,
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
