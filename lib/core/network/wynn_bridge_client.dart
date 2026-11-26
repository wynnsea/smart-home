import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/agent_chat/domain/entities/ai_gateway_entities.dart';
import '../../features/agent_chat/domain/entities/chat_entities.dart';
import '../../features/git_diff/domain/entities/diff_entities.dart';
import '../config/app_env.dart';

/// Runtime configuration for connecting WynnDiff mobile to the standalone
/// Go Bridge Server (`wynndiff_bridge`) running on the user's PC.
@immutable
class BridgeConfig {
  const BridgeConfig({
    this.hostAddress = '100.85.100.80',
    this.hostPort = 8787,
    this.token = '',
    this.enabled = false,
  });

  factory BridgeConfig.fromEnvironment() {
    final envHost = AppEnv.bridgeHost;
    final envToken = AppEnv.bridgeToken;
    return BridgeConfig(
      hostAddress: envHost.isNotEmpty ? envHost : '100.85.100.80',
      hostPort: AppEnv.bridgePort,
      token: envToken,
      enabled: envHost.isNotEmpty,
    );
  }

  final String hostAddress;
  final int hostPort;
  final String token;
  final bool enabled;

  bool get isActive => enabled && hostAddress.trim().isNotEmpty;

  Uri uri(String path) => Uri.parse('http://${hostAddress.trim()}:$hostPort$path');

  BridgeConfig copyWith({
    String? hostAddress,
    int? hostPort,
    String? token,
    bool? enabled,
  }) {
    return BridgeConfig(
      hostAddress: hostAddress ?? this.hostAddress,
      hostPort: hostPort ?? this.hostPort,
      token: token ?? this.token,
      enabled: enabled ?? this.enabled,
    );
  }
}

class BridgeConfigNotifier extends Notifier<BridgeConfig> {
  @override
  BridgeConfig build() => BridgeConfig.fromEnvironment();

  void update({
    String? hostAddress,
    int? hostPort,
    String? token,
    bool? enabled,
  }) {
    state = state.copyWith(
      hostAddress: hostAddress?.trim(),
      hostPort: hostPort,
      token: token?.trim(),
      enabled: enabled,
    );
  }
}

final bridgeConfigProvider =
    NotifierProvider<BridgeConfigNotifier, BridgeConfig>(
      BridgeConfigNotifier.new,
    );

@immutable
class BridgeHealthResult {
  const BridgeHealthResult({
    required this.ok,
    required this.latencyMs,
    this.hostName = '',
    this.repoFullName = '',
    this.branch = '',
    this.changedFilesCount = 0,
    this.errorMessage,
  });

  final bool ok;
  final int latencyMs;
  final String hostName;
  final String repoFullName;
  final String branch;
  final int changedFilesCount;
  final String? errorMessage;
}

/// HTTP + SSE client communicating with `wynndiff_bridge` over Tailscale / LAN.
class WynnBridgeClient {
  WynnBridgeClient({HttpClient Function()? httpClientFactory})
    : _httpClientFactory = httpClientFactory ?? HttpClient.new;

  final HttpClient Function() _httpClientFactory;

  void _applyAuth(HttpHeaders headers, BridgeConfig config) {
    if (config.token.trim().isNotEmpty) {
      headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer ${config.token.trim()}',
      );
    }
  }

  Future<BridgeHealthResult> fetchHealth(BridgeConfig config) async {
    final client = _httpClientFactory()
      ..connectionTimeout = const Duration(seconds: 6);
    final sw = Stopwatch()..start();
    try {
      final req = await client.getUrl(config.uri('/health'));
      _applyAuth(req.headers, config);
      final resp = await req.close().timeout(const Duration(seconds: 8));
      final body = await utf8.decodeStream(resp);
      sw.stop();

      if (resp.statusCode != 200) {
        return BridgeHealthResult(
          ok: false,
          latencyMs: sw.elapsedMilliseconds,
          errorMessage: _extractError(body, resp.statusCode),
        );
      }

      final json = jsonDecode(body) as Map<String, dynamic>;
      return BridgeHealthResult(
        ok: true,
        latencyMs: sw.elapsedMilliseconds,
        hostName: json['hostName']?.toString() ?? 'PC Host',
        repoFullName: json['repoFullName']?.toString() ?? 'local/repo',
        branch: json['branch']?.toString() ?? 'main',
        changedFilesCount: (json['changedFilesCount'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      return BridgeHealthResult(
        ok: false,
        latencyMs: sw.elapsedMilliseconds,
        errorMessage: 'Tidak dapat terhubung ke bridge PC: $e',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<GitDiffSnapshot> fetchGitDiff(BridgeConfig config) async {
    final client = _httpClientFactory()
      ..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client.getUrl(config.uri('/git/diff'));
      _applyAuth(req.headers, config);
      final resp = await req.close().timeout(const Duration(seconds: 12));
      final body = await utf8.decodeStream(resp);
      if (resp.statusCode != 200) {
        throw Exception(_extractError(body, resp.statusCode));
      }
      final json = jsonDecode(body) as Map<String, dynamic>;
      return parseBridgeDiffSnapshot(json);
    } finally {
      client.close(force: true);
    }
  }

  Future<String> commitAndPush(
    BridgeConfig config, {
    required String message,
    required bool push,
  }) async {
    final client = _httpClientFactory()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.postUrl(config.uri('/git/commit'));
      _applyAuth(req.headers, config);
      req.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/json; charset=utf-8',
      );
      req.add(utf8.encode(jsonEncode({'message': message, 'push': push})));
      final resp = await req.close().timeout(const Duration(seconds: 30));
      final body = await utf8.decodeStream(resp);
      if (resp.statusCode != 200) {
        throw Exception(_extractError(body, resp.statusCode));
      }
      return push
          ? 'Committed & pushed ke GitHub: "$message"'
          : 'Committed secara lokal di PC: "$message"';
    } finally {
      client.close(force: true);
    }
  }

  Future<void> resetChanges(BridgeConfig config, {String? filePath}) async {
    final client = _httpClientFactory()
      ..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client.postUrl(config.uri('/git/reset'));
      _applyAuth(req.headers, config);
      req.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/json; charset=utf-8',
      );
      req.add(utf8.encode(jsonEncode({'path': filePath ?? ''})));
      final resp = await req.close().timeout(const Duration(seconds: 15));
      final body = await utf8.decodeStream(resp);
      if (resp.statusCode != 200) {
        throw Exception(_extractError(body, resp.statusCode));
      }
    } finally {
      client.close(force: true);
    }
  }

  Stream<PromptStreamChunk> streamRemotePrompt({
    required BridgeConfig config,
    required String prompt,
    required AgentMode mode,
    required String modelName,
    required AiAgentProfile agent,
    List<ChatMessage> history = const [],
    List<String> attachedFiles = const [],
  }) async* {
    final now = DateTime.now();
    final msgId = 'bridge-${now.millisecondsSinceEpoch}';
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final logTime = '$timeStr:${now.second.toString().padLeft(2, '0')}';
    final modelId = resolveOpenRouterModelId(modelName);

    yield PromptStreamChunk(
      partialMessage: ChatMessage(
        id: msgId,
        isUser: false,
        timestampLabel: timeStr,
        heading: '${agent.name} (PC Bridge)…',
        statusBadge: '$modelName · ${mode.label} · Remote',
        text: '',
        isStreaming: true,
      ),
      logEntry: ExecutionLogEntry(
        time: logTime,
        command: 'POST /prompt [${config.hostAddress}:${config.hostPort}]',
        detail: 'Agent: ${agent.name} · Model: $modelId',
        isSuccess: true,
      ),
    );

    final client = _httpClientFactory()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.postUrl(config.uri('/prompt'));
      _applyAuth(req.headers, config);
      req.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/json; charset=utf-8',
      );
      req.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');

      final historyPayload = history
          .where((m) => !m.isError && m.text.trim().isNotEmpty)
          .map((m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text})
          .toList();

      req.add(
        utf8.encode(
          jsonEncode({
            'prompt': prompt,
            'mode': mode.name,
            'model': modelId,
            'systemPrompt': agent.systemPrompt,
            'attachedFiles': attachedFiles,
            'history': historyPayload,
          }),
        ),
      );

      final resp = await req.close().timeout(const Duration(seconds: 95));
      if (resp.statusCode != 200) {
        final errBody = await utf8.decodeStream(resp);
        throw Exception(_extractError(errBody, resp.statusCode));
      }

      final buffer = StringBuffer();
      var changedFiles = <String>[];
      final lines = resp.transform(utf8.decoder).transform(const LineSplitter());

      await for (final rawLine in lines) {
        final line = rawLine.trim();
        if (!line.startsWith('data:')) continue;
        final payload = line.substring(5).trim();
        if (payload == '[DONE]') break;

        Map<String, dynamic> ev;
        try {
          ev = jsonDecode(payload) as Map<String, dynamic>;
        } catch (_) {
          continue;
        }

        final evType = ev['type']?.toString() ?? '';
        if (evType == 'error') {
          throw Exception(ev['message']?.toString() ?? 'Bridge error');
        } else if (evType == 'log') {
          final tNow = DateTime.now();
          final tStr =
              '${tNow.hour.toString().padLeft(2, '0')}:${tNow.minute.toString().padLeft(2, '0')}:${tNow.second.toString().padLeft(2, '0')}';
          yield PromptStreamChunk(
            partialMessage: ChatMessage(
              id: msgId,
              isUser: false,
              timestampLabel: timeStr,
              heading: '${agent.name} (PC Bridge)',
              statusBadge: '$modelName · ${mode.label} · Running',
              text: buffer.toString(),
              isStreaming: true,
            ),
            logEntry: ExecutionLogEntry(
              time: tStr,
              command: ev['command']?.toString() ?? 'tool',
              detail: ev['detail']?.toString() ?? '',
              isSuccess: ev['success'] != false,
            ),
          );
        } else if (evType == 'delta') {
          final content = ev['content']?.toString() ?? '';
          if (content.isNotEmpty) {
            buffer.write(content);
            yield PromptStreamChunk(
              partialMessage: ChatMessage(
                id: msgId,
                isUser: false,
                timestampLabel: timeStr,
                heading: '${agent.name} (PC Bridge)',
                statusBadge: '$modelName · ${mode.label} · Live',
                text: buffer.toString(),
                isStreaming: true,
              ),
            );
          }
        } else if (evType == 'done') {
          final doneContent = ev['content']?.toString() ?? '';
          if (buffer.isEmpty && doneContent.isNotEmpty) {
            buffer.write(doneContent);
          }
          if (ev['changedFiles'] is List) {
            changedFiles = (ev['changedFiles'] as List)
                .map((e) => e.toString())
                .toList();
          }
        }
      }

      yield PromptStreamChunk(
        partialMessage: ChatMessage(
          id: msgId,
          isUser: false,
          timestampLabel: timeStr,
          heading: '${agent.name} (PC Bridge)',
          statusBadge: changedFiles.isNotEmpty
              ? '${changedFiles.length} file diubah · $modelName'
              : '$modelName · ${mode.label}',
          text: buffer.toString().trim().isEmpty
              ? '(Respons kosong dari bridge PC)'
              : buffer.toString().trim(),
          fileChips: changedFiles,
          isStreaming: false,
        ),
        shouldGenerateDiff: changedFiles.isNotEmpty,
      );
    } finally {
      client.close(force: true);
    }
  }

  String _extractError(String body, int statusCode) {
    try {
      final parsed = jsonDecode(body);
      if (parsed is Map<String, dynamic> && parsed['error'] != null) {
        return parsed['error'].toString();
      }
    } catch (_) {}
    return 'Bridge HTTP $statusCode';
  }
}

/// Pure JSON-to-[GitDiffSnapshot] parser for `GET /git/diff` from `wynndiff_bridge`.
GitDiffSnapshot parseBridgeDiffSnapshot(Map<String, dynamic> json) {
  final rawFiles = (json['files'] as List?) ?? const [];
  final files = <DiffFile>[];
  for (final item in rawFiles) {
    if (item is! Map<String, dynamic>) continue;
    final path = item['path']?.toString() ?? '';
    final statusStr = item['status']?.toString() ?? 'modified';
    final status = switch (statusStr) {
      'added' => DiffFileStatus.added,
      'deleted' => DiffFileStatus.deleted,
      _ => DiffFileStatus.modified,
    };
    final additions = (item['additions'] as num?)?.toInt() ?? 0;
    final deletions = (item['deletions'] as num?)?.toInt() ?? 0;
    final lines = <DiffLine>[];

    final rawHunks = (item['hunks'] as List?) ?? const [];
    for (final hunk in rawHunks) {
      if (hunk is! Map<String, dynamic>) continue;
      final header = hunk['header']?.toString() ?? '';
      if (header.isNotEmpty) {
        lines.add(DiffLine(type: DiffLineType.hunkHeader, content: header));
      }
      final rawLines = (hunk['lines'] as List?) ?? const [];
      for (final l in rawLines) {
        if (l is! Map<String, dynamic>) continue;
        final lType = switch (l['type']?.toString()) {
          'add' => DiffLineType.addition,
          'remove' => DiffLineType.deletion,
          _ => DiffLineType.context,
        };
        lines.add(
          DiffLine(
            type: lType,
            content: l['content']?.toString() ?? '',
            oldLineNumber: (l['oldLine'] as num?)?.toInt(),
            newLineNumber: (l['newLine'] as num?)?.toInt(),
          ),
        );
      }
    }

    files.add(
      DiffFile(
        path: path,
        status: status,
        additions: additions,
        deletions: deletions,
        summary: '+$additions / -$deletions dari PC host',
        lines: lines,
      ),
    );
  }

  return GitDiffSnapshot(
    repoFullName: json['repoFullName']?.toString() ?? 'local/repo',
    branch: json['branch']?.toString() ?? 'main',
    lastCommitHash: 'HEAD',
    files: files,
  );
}
