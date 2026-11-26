import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/agent_chat/domain/entities/ai_gateway_entities.dart';
import '../../features/agent_chat/domain/entities/chat_entities.dart';
import '../../features/agent_chat/domain/entities/token_usage_entities.dart';
import '../network/wynn_bridge_client.dart';

/// Persisted snapshot of chat sessions and active Agent/Model/Mode selections.
class PersistedChatSnapshot {
  const PersistedChatSnapshot({
    required this.sessions,
    required this.activeSessionId,
    required this.mode,
    required this.selectedModel,
    required this.selectedAgentId,
  });

  final List<ChatSession> sessions;
  final String activeSessionId;
  final AgentMode mode;
  final String selectedModel;
  final String selectedAgentId;
}

/// Local persistent storage backed by [SharedPreferences] for:
/// - Server Bridge config (host, port, token, enabled)
/// - AI Gateway config (baseUrl, apiKey, useLiveGateway)
/// - Multi-session chat history, terminal logs, and active Agent/Model/Mode
abstract final class AppLocalStorage {
  static const String _kBridgeConfigKey = 'wynndiff_bridge_config_v1';
  static const String _kGatewayConfigKey = 'wynndiff_ai_gateway_config_v1';
  static const String _kChatSnapshotKey = 'wynndiff_chat_snapshot_v1';
  static const String _kTokenUsageKey = 'wynndiff_token_usage_v1';
  static const String _kDarkModeKey = 'wynndiff_dark_mode_v1';
  static const String _kPersonaMemoryKey = 'wynndiff_persona_memory_v1';

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (_) {
      _prefs = null;
    }
  }

  static void setInstanceForTest(SharedPreferences? prefs) {
    _prefs = prefs;
  }

  static BridgeConfig loadBridgeConfig({required BridgeConfig fallback}) {
    final raw = _prefs?.getString(_kBridgeConfigKey);
    if (raw == null || raw.isEmpty) return fallback;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final savedHost = (map['hostAddress'] as String?)?.trim() ?? '';
      final savedPort = (map['hostPort'] as num?)?.toInt();
      final savedToken = (map['token'] as String?)?.trim();
      final savedEnabled = map['enabled'] as bool?;
      return fallback.copyWith(
        hostAddress: savedHost.isNotEmpty ? savedHost : fallback.hostAddress,
        hostPort: (savedPort != null && savedPort > 0)
            ? savedPort
            : fallback.hostPort,
        token: savedToken ?? fallback.token,
        enabled: savedEnabled ?? fallback.enabled,
      );
    } catch (_) {
      return fallback;
    }
  }

  static Future<void> saveBridgeConfig(BridgeConfig config) async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setString(
      _kBridgeConfigKey,
      jsonEncode({
        'hostAddress': config.hostAddress,
        'hostPort': config.hostPort,
        'token': config.token,
        'enabled': config.enabled,
      }),
    );
  }

  static AiGatewayConfig loadAiGatewayConfig({
    required AiGatewayConfig fallback,
  }) {
    final raw = _prefs?.getString(_kGatewayConfigKey);
    if (raw == null || raw.isEmpty) return fallback;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final savedUrl = (map['baseUrl'] as String?)?.trim() ?? '';
      final savedKey = (map['apiKey'] as String?)?.trim() ?? '';
      final savedLive = map['useLiveGateway'] as bool?;
      return fallback.copyWith(
        baseUrl: savedUrl.isNotEmpty ? savedUrl : fallback.baseUrl,
        apiKey: savedKey.isNotEmpty ? savedKey : fallback.apiKey,
        useLiveGateway: savedLive ?? fallback.useLiveGateway,
      );
    } catch (_) {
      return fallback;
    }
  }

  static Future<void> saveAiGatewayConfig(AiGatewayConfig config) async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setString(
      _kGatewayConfigKey,
      jsonEncode({
        'baseUrl': config.baseUrl,
        'apiKey': config.apiKey,
        'useLiveGateway': config.useLiveGateway,
      }),
    );
  }

  static PersistedChatSnapshot? loadChatSnapshot() {
    final raw = _prefs?.getString(_kChatSnapshotKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final rawSessions = (map['sessions'] as List?) ?? const [];
      final sessions = <ChatSession>[];
      for (final item in rawSessions) {
        if (item is Map<String, dynamic>) {
          sessions.add(_sessionFromJson(item));
        }
      }
      if (sessions.isEmpty) return null;

      final modeName = map['mode']?.toString() ?? AgentMode.agent.name;
      final mode = AgentMode.values.firstWhere(
        (m) => m.name == modeName,
        orElse: () => AgentMode.agent,
      );
      final savedActiveId = map['activeSessionId']?.toString() ?? '';
      final activeId = sessions.any((s) => s.id == savedActiveId)
          ? savedActiveId
          : sessions.first.id;
      final savedModel = map['selectedModel']?.toString().trim() ?? '';
      final validModel = kOpenRouterModels.any(
        (m) => m.label == savedModel || m.id == savedModel,
      )
          ? savedModel
          : kOpenRouterModels.first.label;
      final savedAgentId = map['selectedAgentId']?.toString().trim() ?? '';
      final validAgentId = kBuiltInAgents.any((a) => a.id == savedAgentId)
          ? savedAgentId
          : kBuiltInAgents.first.id;

      return PersistedChatSnapshot(
        sessions: sessions,
        activeSessionId: activeId,
        mode: mode,
        selectedModel: validModel,
        selectedAgentId: validAgentId,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveChatSnapshot({
    required List<ChatSession> sessions,
    required String activeSessionId,
    required AgentMode mode,
    required String selectedModel,
    required String selectedAgentId,
  }) async {
    final prefs = _prefs;
    if (prefs == null) return;
    final trimmedSessions = sessions.take(30).map(_sessionToJson).toList();
    await prefs.setString(
      _kChatSnapshotKey,
      jsonEncode({
        'activeSessionId': activeSessionId,
        'mode': mode.name,
        'selectedModel': selectedModel,
        'selectedAgentId': selectedAgentId,
        'sessions': trimmedSessions,
      }),
    );
  }

  static Map<String, Object?> _sessionToJson(ChatSession s) {
    final msgs = s.messages.length > 80
        ? s.messages.sublist(s.messages.length - 80)
        : s.messages;
    final logs = s.logs.length > 50
        ? s.logs.sublist(s.logs.length - 50)
        : s.logs;
    return {
      'id': s.id,
      'title': s.title,
      'repoFullName': s.repoFullName,
      'branch': s.branch,
      'updatedAt': s.updatedAt,
      'messages': msgs.map(_messageToJson).toList(),
      'logs': logs.map(_logToJson).toList(),
    };
  }

  static ChatSession _sessionFromJson(Map<String, dynamic> map) {
    final rawMsgs = (map['messages'] as List?) ?? const [];
    final rawLogs = (map['logs'] as List?) ?? const [];
    return ChatSession(
      id: map['id']?.toString() ?? 'session-restored',
      title: map['title']?.toString() ?? 'Sesi baru',
      repoFullName: map['repoFullName']?.toString() ?? 'OpenRouter / Remote Host',
      branch: map['branch']?.toString() ?? 'main',
      updatedAt: map['updatedAt']?.toString() ?? 'Tersimpan',
      messages: [
        for (final m in rawMsgs)
          if (m is Map<String, dynamic>) _messageFromJson(m),
      ],
      logs: [
        for (final l in rawLogs)
          if (l is Map<String, dynamic>) _logFromJson(l),
      ],
    );
  }

  static Map<String, Object?> _messageToJson(ChatMessage m) {
    return {
      'id': m.id,
      'isUser': m.isUser,
      'timestampLabel': m.timestampLabel,
      'text': m.text,
      'heading': m.heading,
      'statusBadge': m.statusBadge,
      'fileChips': m.fileChips,
      'isLiked': m.isLiked,
      'isError': m.isError,
      'findings': m.findings
          .map(
            (f) => {
              'number': f.number,
              'title': f.title,
              'bullets': f.bullets,
              'referencedFiles': f.referencedFiles,
            },
          )
          .toList(),
    };
  }

  static ChatMessage _messageFromJson(Map<String, dynamic> map) {
    final rawFindings = (map['findings'] as List?) ?? const [];
    return ChatMessage(
      id: map['id']?.toString() ?? 'msg',
      isUser: map['isUser'] == true,
      timestampLabel: map['timestampLabel']?.toString() ?? '',
      text: map['text']?.toString() ?? '',
      heading: map['heading']?.toString(),
      statusBadge: map['statusBadge']?.toString(),
      fileChips: [
        for (final f in (map['fileChips'] as List?) ?? const []) f.toString(),
      ],
      findings: [
        for (final f in rawFindings)
          if (f is Map<String, dynamic>)
            FindingItem(
              number: (f['number'] as num?)?.toInt() ?? 1,
              title: f['title']?.toString() ?? '',
              bullets: [
                for (final b in (f['bullets'] as List?) ?? const [])
                  b.toString(),
              ],
              referencedFiles: [
                for (final r in (f['referencedFiles'] as List?) ?? const [])
                  r.toString(),
              ],
            ),
      ],
      // Always restore as non-streaming so an interrupted run never freezes UI
      isStreaming: false,
      isLiked: map['isLiked'] == true,
      isError: map['isError'] == true,
    );
  }

  static Map<String, Object?> _logToJson(ExecutionLogEntry l) => {
    'time': l.time,
    'command': l.command,
    'detail': l.detail,
    'isSuccess': l.isSuccess,
  };

  static ExecutionLogEntry _logFromJson(Map<String, dynamic> map) {
    return ExecutionLogEntry(
      time: map['time']?.toString() ?? '',
      command: map['command']?.toString() ?? '',
      detail: map['detail']?.toString() ?? '',
      isSuccess: map['isSuccess'] != false,
    );
  }

  static TokenUsageState loadTokenUsage() {
    final raw = _prefs?.getString(_kTokenUsageKey);
    if (raw == null || raw.isEmpty) return const TokenUsageState();
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final budget = (map['dailyBudget'] as num?)?.toInt() ?? 100000;
      final rawRecords = (map['records'] as List?) ?? const [];
      final records = <TokenUsageRecord>[
        for (final item in rawRecords)
          if (item is Map<String, dynamic>) TokenUsageRecord.fromJson(item),
      ];
      return TokenUsageState(dailyBudget: budget, records: records);
    } catch (_) {
      return const TokenUsageState();
    }
  }

  static Future<void> saveTokenUsage(TokenUsageState state) async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setString(
      _kTokenUsageKey,
      jsonEncode({
        'dailyBudget': state.dailyBudget,
        'records': state.records.take(200).map((r) => r.toJson()).toList(),
      }),
    );
  }

  static bool loadDarkMode() {
    return _prefs?.getBool(_kDarkModeKey) ?? false;
  }

  static Future<void> saveDarkMode(bool isDark) async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setBool(_kDarkModeKey, isDark);
  }

  static String loadPersonaMemory() {
    final saved = _prefs?.getString(_kPersonaMemoryKey);
    if (saved == null) return kDefaultPersonalMemory;
    return saved;
  }

  static Future<void> savePersonaMemory(String memory) async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setString(_kPersonaMemoryKey, memory.trim());
  }
}
