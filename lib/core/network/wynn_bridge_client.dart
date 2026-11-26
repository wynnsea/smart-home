import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/agent_chat/domain/entities/ai_gateway_entities.dart';
import '../../features/agent_chat/domain/entities/chat_entities.dart';
import '../../features/git_diff/domain/entities/diff_entities.dart';
import '../config/app_env.dart';
import '../storage/app_local_storage.dart';

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

  Uri uri(String path) =>
      Uri.parse('http://${hostAddress.trim()}:$hostPort$path');

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
  BridgeConfig build() {
    return AppLocalStorage.loadBridgeConfig(
      fallback: BridgeConfig.fromEnvironment(),
    );
  }

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
    unawaited(AppLocalStorage.saveBridgeConfig(state));
  }
}

final bridgeConfigProvider =
    NotifierProvider<BridgeConfigNotifier, BridgeConfig>(
      BridgeConfigNotifier.new,
    );

@immutable
class ServerRepoItem {
  const ServerRepoItem({
    required this.name,
    required this.path,
    required this.isGit,
    required this.branch,
    required this.isActive,
    this.lastCommit = '',
    this.lastCommitTime = '',
    this.dirtyCount = 0,
  });

  final String name;
  final String path;
  final bool isGit;
  final String branch;
  final bool isActive;
  final String lastCommit;
  final String lastCommitTime;
  final int dirtyCount;
}

@immutable
class SystemStats {
  const SystemStats({
    this.os = 'linux',
    this.arch = 'amd64',
    this.cpuCores = 0,
    this.cpuPercent = 0,
    this.memUsedGb = 0,
    this.memTotalGb = 0,
    this.memPercent = 0,
    this.diskUsedGb = 0,
    this.diskTotalGb = 0,
    this.diskPercent = 0,
    this.uptimeLabel = '',
    this.loadAvg1 = 0,
  });

  final String os;
  final String arch;
  final int cpuCores;
  final double cpuPercent;
  final double memUsedGb;
  final double memTotalGb;
  final double memPercent;
  final double diskUsedGb;
  final double diskTotalGb;
  final double diskPercent;
  final String uptimeLabel;
  final double loadAvg1;

  bool get hasTelemetry => memTotalGb > 0 || diskTotalGb > 0 || cpuCores > 0;
}

@immutable
class GitCommitItem {
  const GitCommitItem({
    required this.hash,
    required this.subject,
    required this.author,
    required this.relativeTime,
  });

  final String hash;
  final String subject;
  final String author;
  final String relativeTime;
}

@immutable
class GitBranchesResult {
  const GitBranchesResult({required this.active, required this.branches});

  final String active;
  final List<String> branches;
}

@immutable
class ServerFileEntry {
  const ServerFileEntry({
    required this.name,
    required this.path,
    required this.isDir,
    required this.size,
  });

  final String name;
  final String path;
  final bool isDir;
  final int size;
}

@immutable
class ServerFileContent {
  const ServerFileContent({
    required this.path,
    required this.content,
    required this.size,
    required this.truncated,
  });

  final String path;
  final String content;
  final int size;
  final bool truncated;
}

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
        hostName: json['hostName']?.toString() ?? 'Server Host',
        repoFullName: json['repoFullName']?.toString() ?? 'local/repo',
        branch: json['branch']?.toString() ?? 'main',
        changedFilesCount: (json['changedFilesCount'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      return BridgeHealthResult(
        ok: false,
        latencyMs: sw.elapsedMilliseconds,
        errorMessage: 'Tidak dapat terhubung ke Server Bridge: $e',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<List<ServerRepoItem>> fetchRepos(BridgeConfig config) async {
    final client = _httpClientFactory()
      ..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client.getUrl(config.uri('/repos'));
      _applyAuth(req.headers, config);
      final resp = await req.close().timeout(const Duration(seconds: 10));
      final body = await utf8.decodeStream(resp);
      if (resp.statusCode != 200) {
        throw Exception(_extractError(body, resp.statusCode));
      }
      final json = jsonDecode(body) as Map<String, dynamic>;
      final rawList = (json['repos'] as List?) ?? const [];
      return [
        for (final item in rawList)
          if (item is Map<String, dynamic>)
            ServerRepoItem(
              name: item['name']?.toString() ?? '',
              path: item['path']?.toString() ?? '',
              isGit: item['isGit'] == true,
              branch: item['branch']?.toString() ?? '',
              isActive: item['isActive'] == true,
              lastCommit: item['lastCommit']?.toString() ?? '',
              lastCommitTime: item['lastCommitTime']?.toString() ?? '',
              dirtyCount: (item['dirtyCount'] as num?)?.toInt() ?? 0,
            ),
      ];
    } finally {
      client.close(force: true);
    }
  }

  Future<void> selectRepo(BridgeConfig config, String repoName) async {
    final client = _httpClientFactory()
      ..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client.postUrl(config.uri('/repos/select'));
      _applyAuth(req.headers, config);
      req.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/json; charset=utf-8',
      );
      req.add(utf8.encode(jsonEncode({'name': repoName})));
      final resp = await req.close().timeout(const Duration(seconds: 10));
      final body = await utf8.decodeStream(resp);
      if (resp.statusCode != 200) {
        throw Exception(_extractError(body, resp.statusCode));
      }
    } finally {
      client.close(force: true);
    }
  }

  Future<SystemStats> fetchSystemStats(BridgeConfig config) async {
    final client = _httpClientFactory()
      ..connectionTimeout = const Duration(seconds: 6);
    try {
      final req = await client.getUrl(config.uri('/system/stats'));
      _applyAuth(req.headers, config);
      final resp = await req.close().timeout(const Duration(seconds: 8));
      final body = await utf8.decodeStream(resp);
      if (resp.statusCode != 200) {
        throw Exception(_extractError(body, resp.statusCode));
      }
      final json = jsonDecode(body) as Map<String, dynamic>;
      final s = (json['stats'] as Map<String, dynamic>?) ?? const {};
      return SystemStats(
        os: s['os']?.toString() ?? 'linux',
        arch: s['arch']?.toString() ?? 'amd64',
        cpuCores: (s['cpuCores'] as num?)?.toInt() ?? 0,
        cpuPercent: (s['cpuPercent'] as num?)?.toDouble() ?? 0,
        memUsedGb: (s['memUsedGb'] as num?)?.toDouble() ?? 0,
        memTotalGb: (s['memTotalGb'] as num?)?.toDouble() ?? 0,
        memPercent: (s['memPercent'] as num?)?.toDouble() ?? 0,
        diskUsedGb: (s['diskUsedGb'] as num?)?.toDouble() ?? 0,
        diskTotalGb: (s['diskTotalGb'] as num?)?.toDouble() ?? 0,
        diskPercent: (s['diskPercent'] as num?)?.toDouble() ?? 0,
        uptimeLabel: s['uptimeLabel']?.toString() ?? '',
        loadAvg1: (s['loadAvg1'] as num?)?.toDouble() ?? 0,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<String> pullRepo(BridgeConfig config, {String? repoName}) async {
    final client = _httpClientFactory()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.postUrl(config.uri('/repos/pull'));
      _applyAuth(req.headers, config);
      req.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/json; charset=utf-8',
      );
      req.add(utf8.encode(jsonEncode({'name': repoName ?? ''})));
      final resp = await req.close().timeout(const Duration(seconds: 25));
      final body = await utf8.decodeStream(resp);
      if (resp.statusCode != 200) {
        throw Exception(_extractError(body, resp.statusCode));
      }
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['output']?.toString() ?? 'Already up to date.';
    } finally {
      client.close(force: true);
    }
  }

  Future<List<GitCommitItem>> fetchGitLog(BridgeConfig config) async {
    final client = _httpClientFactory()
      ..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client.getUrl(config.uri('/git/log'));
      _applyAuth(req.headers, config);
      final resp = await req.close().timeout(const Duration(seconds: 10));
      final body = await utf8.decodeStream(resp);
      if (resp.statusCode != 200) {
        throw Exception(_extractError(body, resp.statusCode));
      }
      final json = jsonDecode(body) as Map<String, dynamic>;
      final raw = (json['commits'] as List?) ?? const [];
      return [
        for (final item in raw)
          if (item is Map<String, dynamic>)
            GitCommitItem(
              hash: item['hash']?.toString() ?? '',
              subject: item['subject']?.toString() ?? '',
              author: item['author']?.toString() ?? '',
              relativeTime: item['relativeTime']?.toString() ?? '',
            ),
      ];
    } finally {
      client.close(force: true);
    }
  }

  Future<GitBranchesResult> fetchGitBranches(BridgeConfig config) async {
    final client = _httpClientFactory()
      ..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client.getUrl(config.uri('/git/branches'));
      _applyAuth(req.headers, config);
      final resp = await req.close().timeout(const Duration(seconds: 10));
      final body = await utf8.decodeStream(resp);
      if (resp.statusCode != 200) {
        throw Exception(_extractError(body, resp.statusCode));
      }
      final json = jsonDecode(body) as Map<String, dynamic>;
      final branches = [
        for (final b in (json['branches'] as List?) ?? const []) b.toString(),
      ];
      return GitBranchesResult(
        active: json['active']?.toString() ?? 'main',
        branches: branches,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<void> checkoutBranch(BridgeConfig config, String branch) async {
    final client = _httpClientFactory()
      ..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client.postUrl(config.uri('/git/checkout'));
      _applyAuth(req.headers, config);
      req.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/json; charset=utf-8',
      );
      req.add(utf8.encode(jsonEncode({'branch': branch})));
      final resp = await req.close().timeout(const Duration(seconds: 15));
      final body = await utf8.decodeStream(resp);
      if (resp.statusCode != 200) {
        throw Exception(_extractError(body, resp.statusCode));
      }
    } finally {
      client.close(force: true);
    }
  }

  Future<List<ServerFileEntry>> fetchFiles(
    BridgeConfig config, {
    String dir = '.',
  }) async {
    final client = _httpClientFactory()
      ..connectionTimeout = const Duration(seconds: 8);
    try {
      final uri = config.uri('/files').replace(queryParameters: {'dir': dir});
      final req = await client.getUrl(uri);
      _applyAuth(req.headers, config);
      final resp = await req.close().timeout(const Duration(seconds: 10));
      final body = await utf8.decodeStream(resp);
      if (resp.statusCode != 200) {
        throw Exception(_extractError(body, resp.statusCode));
      }
      final json = jsonDecode(body) as Map<String, dynamic>;
      final raw = (json['files'] as List?) ?? const [];
      return [
        for (final item in raw)
          if (item is Map<String, dynamic>)
            ServerFileEntry(
              name: item['name']?.toString() ?? '',
              path: item['path']?.toString() ?? '',
              isDir: item['isDir'] == true,
              size: (item['size'] as num?)?.toInt() ?? 0,
            ),
      ];
    } finally {
      client.close(force: true);
    }
  }

  Future<ServerFileContent> readFile(BridgeConfig config, String path) async {
    final client = _httpClientFactory()
      ..connectionTimeout = const Duration(seconds: 8);
    try {
      final uri = config
          .uri('/files/read')
          .replace(queryParameters: {'path': path});
      final req = await client.getUrl(uri);
      _applyAuth(req.headers, config);
      final resp = await req.close().timeout(const Duration(seconds: 12));
      final body = await utf8.decodeStream(resp);
      if (resp.statusCode != 200) {
        throw Exception(_extractError(body, resp.statusCode));
      }
      final json = jsonDecode(body) as Map<String, dynamic>;
      return ServerFileContent(
        path: json['path']?.toString() ?? path,
        content: json['content']?.toString() ?? '',
        size: (json['size'] as num?)?.toInt() ?? 0,
        truncated: json['truncated'] == true,
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
          : 'Committed secara lokal di Server: "$message"';
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
        heading: '${agent.name} (Server Bridge)…',
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
          .map(
            (m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text},
          )
          .toList();

      final personalMemory = AppLocalStorage.loadPersonaMemory().trim();
      final composedSystemPrompt = personalMemory.isEmpty
          ? '${agent.systemPrompt}\n$kWynnNaturalVoiceGuide'
          : '${agent.systemPrompt}\n$kWynnNaturalVoiceGuide\nMemori tentang user: $personalMemory';

      req.add(
        utf8.encode(
          jsonEncode({
            'prompt': prompt,
            'mode': mode.name,
            'model': modelId,
            'systemPrompt': composedSystemPrompt,
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
      TokenUsageDelta? usageDelta;
      final lines = resp
          .transform(utf8.decoder)
          .transform(const LineSplitter());

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
              heading: '${agent.name} (Server Bridge)',
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
                heading: '${agent.name} (Server Bridge)',
                statusBadge: '$modelName · ${mode.label} · Live',
                text: buffer.toString(),
                isStreaming: true,
              ),
            );
          }
        } else if (evType == 'usage') {
          final p = (ev['promptTokens'] as num?)?.toInt() ?? 0;
          final c = (ev['completionTokens'] as num?)?.toInt() ?? 0;
          final t = (ev['totalTokens'] as num?)?.toInt() ?? (p + c);
          usageDelta = TokenUsageDelta(
            model: modelName,
            promptTokens: p,
            completionTokens: c,
            totalTokens: t,
            source: 'Server Bridge',
          );
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

      usageDelta ??= TokenUsageDelta(
        model: modelName,
        promptTokens: (prompt.length / 4).ceil() + 80,
        completionTokens: (buffer.length / 4).ceil() + 1,
        totalTokens:
            (prompt.length / 4).ceil() + 80 + (buffer.length / 4).ceil() + 1,
        source: 'Server Bridge',
      );

      yield PromptStreamChunk(
        partialMessage: ChatMessage(
          id: msgId,
          isUser: false,
          timestampLabel: timeStr,
          heading: '${agent.name} (Server Bridge)',
          statusBadge: changedFiles.isNotEmpty
              ? '${changedFiles.length} file diubah · $modelName'
              : '$modelName · ${mode.label}',
          text: buffer.toString().trim().isEmpty
              ? '(Respons kosong dari Server Bridge)'
              : buffer.toString().trim(),
          fileChips: changedFiles,
          isStreaming: false,
        ),
        shouldGenerateDiff: changedFiles.isNotEmpty,
        tokenUsage: usageDelta,
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
        summary: '+$additions / -$deletions dari Server',
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
