import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../../../../core/storage/app_local_storage.dart';
import '../../domain/entities/ai_gateway_entities.dart';
import '../../domain/entities/chat_entities.dart';

/// Parsed result of a single SSE `data:` line from an OpenAI-compatible gateway.
@immutable
class SseDeltaResult {
  const SseDeltaResult({
    this.contentDelta = '',
    this.reasoningDelta = '',
    this.isDone = false,
    this.errorMessage,
  });

  final String contentDelta;
  final String reasoningDelta;
  final bool isDone;
  final String? errorMessage;

  bool get hasText => contentDelta.isNotEmpty || reasoningDelta.isNotEmpty;
}

/// Pure parser for a single OpenAI-compatible SSE line (`data: ...`).
SseDeltaResult parseOpenAiSseDataLine(String rawLine) {
  final line = rawLine.trim();
  if (line.isEmpty || line.startsWith(':')) {
    return const SseDeltaResult();
  }
  if (!line.startsWith('data:')) {
    return const SseDeltaResult();
  }
  final payload = line.substring(5).trim();
  if (payload.isEmpty) {
    return const SseDeltaResult();
  }
  if (payload == '[DONE]') {
    return const SseDeltaResult(isDone: true);
  }

  try {
    final decoded = jsonDecode(payload);
    if (decoded is! Map<String, dynamic>) {
      return const SseDeltaResult();
    }

    final errorObj = decoded['error'];
    if (errorObj is Map<String, dynamic>) {
      final msg = errorObj['message']?.toString() ?? 'AI Gateway error';
      return SseDeltaResult(errorMessage: msg);
    }

    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) {
      return const SseDeltaResult();
    }
    final first = choices.first;
    if (first is! Map<String, dynamic>) {
      return const SseDeltaResult();
    }
    final delta = first['delta'];
    if (delta is! Map<String, dynamic>) {
      return const SseDeltaResult();
    }

    final content = delta['content'] is String ? delta['content'] as String : '';
    final reasoning = delta['reasoning'] is String
        ? delta['reasoning'] as String
        : (delta['reasoning_content'] is String
              ? delta['reasoning_content'] as String
              : '');

    return SseDeltaResult(
      contentDelta: content,
      reasoningDelta: reasoning,
    );
  } catch (_) {
    // Ignore malformed partial keepalive frames without crashing the stream.
    return const SseDeltaResult();
  }
}

/// Builds an OpenAI-compatible `/chat/completions` JSON payload with multi-agent
/// system prompt, execution mode guidance, recent conversation history, and
/// optional attached context filenames.
Map<String, Object?> buildOpenRouterPayload({
  required String prompt,
  required AgentMode mode,
  required String modelName,
  required AiAgentProfile agent,
  List<ChatMessage> history = const [],
  List<String> attachedFiles = const [],
}) {
  final modelId = resolveOpenRouterModelId(modelName);
  final modeInstruction = switch (mode) {
    AgentMode.agent =>
      'Mode aktif: Agent (berikan langkah & kode implementasi yang siap pakai).',
    AgentMode.investigate =>
      'Mode aktif: Investigate (fokus analisa, tracing, dan root-cause secara read-only).',
    AgentMode.plan =>
      'Mode aktif: Plan (susun rencana arsitektur dan langkah kerja terstruktur terlebih dahulu).',
  };

  final contextNote = attachedFiles.isEmpty
      ? ''
      : '\nFile konteks yang dilampirkan pengguna: ${attachedFiles.join(', ')}.';
  final personalMemory = AppLocalStorage.loadPersonaMemory().trim();
  final memoryNote = personalMemory.isEmpty
      ? ''
      : '\nMemori tentang user: $personalMemory';

  final messages = <Map<String, String>>[
    {
      'role': 'system',
      'content':
          '${agent.systemPrompt}\n$kWynnNaturalVoiceGuide$memoryNote\n$modeInstruction$contextNote',
    },
  ];

  // Include up to last 10 non-error messages for multi-turn context
  final validHistory = history
      .where((m) => !m.isError && m.text.trim().isNotEmpty)
      .toList();
  final recent = validHistory.length > 10
      ? validHistory.sublist(validHistory.length - 10)
      : validHistory;
  for (final msg in recent) {
    messages.add({
      'role': msg.isUser ? 'user' : 'assistant',
      'content': msg.text.trim(),
    });
  }

  // Avoid duplicating the current prompt if already appended to session history
  if (messages.isEmpty ||
      messages.last['role'] != 'user' ||
      messages.last['content'] != prompt.trim()) {
    messages.add({
      'role': 'user',
      'content': prompt.trim(),
    });
  }

  return <String, Object?>{
    'model': modelId,
    'stream': true,
    'temperature': 0.75,
    'max_tokens': 2048,
    'messages': messages,
  };
}

/// Live OpenAI-compatible SSE streaming datasource (default: OpenRouter).
/// Uses Dart's built-in `HttpClient` so zero extra packages are required and
/// cancelling the stream immediately aborts the underlying HTTP connection.
class OpenRouterAgentDatasource {
  OpenRouterAgentDatasource({HttpClient Function()? httpClientFactory})
    : _httpClientFactory = httpClientFactory ?? HttpClient.new;

  final HttpClient Function() _httpClientFactory;

  /// Tests connectivity and API key validity via `GET /models`.
  Future<GatewayTestResult> testGatewayConnection(
    AiGatewayConfig config,
  ) async {
    if (config.apiKey.trim().isEmpty) {
      return const GatewayTestResult(
        ok: false,
        message: 'API Key belum diisi.',
      );
    }

    final client = _httpClientFactory()
      ..connectionTimeout = const Duration(seconds: 10);
    final sw = Stopwatch()..start();
    try {
      final request = await client.getUrl(config.modelsUri);
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer ${config.apiKey.trim()}',
      );
      request.headers.set('HTTP-Referer', config.siteUrl);
      request.headers.set('X-Title', config.siteTitle);

      final response = await request.close().timeout(
        const Duration(seconds: 12),
      );
      final body = await utf8.decodeStream(response);
      sw.stop();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        var count = 0;
        try {
          final parsed = jsonDecode(body);
          if (parsed is Map<String, dynamic> && parsed['data'] is List) {
            count = (parsed['data'] as List).length;
          }
        } catch (_) {}
        return GatewayTestResult(
          ok: true,
          latencyMs: sw.elapsedMilliseconds,
          modelCount: count,
          message: count > 0
              ? 'Terhubung (${sw.elapsedMilliseconds}ms · $count model tersedia)'
              : 'Terhubung (${sw.elapsedMilliseconds}ms)',
        );
      }

      return GatewayTestResult(
        ok: false,
        latencyMs: sw.elapsedMilliseconds,
        message: _friendlyHttpError(response.statusCode, body),
      );
    } on SocketException catch (e) {
      return GatewayTestResult(
        ok: false,
        message: 'Gagal menjangkau gateway: ${e.message}',
      );
    } on TimeoutException {
      return const GatewayTestResult(
        ok: false,
        message: 'Koneksi ke AI Gateway timeout.',
      );
    } catch (e) {
      return GatewayTestResult(
        ok: false,
        message: 'Gagal mengetes gateway: $e',
      );
    } finally {
      client.close(force: true);
    }
  }

  /// Streams real-time tokens from OpenRouter (or any OpenAI-compatible gateway).
  Stream<PromptStreamChunk> streamChatCompletion({
    required AiGatewayConfig config,
    required String prompt,
    required AgentMode mode,
    required String modelName,
    required AiAgentProfile agent,
    List<ChatMessage> history = const [],
    List<String> attachedFiles = const [],
  }) async* {
    final now = DateTime.now();
    final msgId = 'agent-${now.millisecondsSinceEpoch}';
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final logTime = '$timeStr:${now.second.toString().padLeft(2, '0')}';
    final modelId = resolveOpenRouterModelId(modelName);

    yield PromptStreamChunk(
      partialMessage: ChatMessage(
        id: msgId,
        isUser: false,
        timestampLabel: timeStr,
        heading: '${agent.name} sedang berpikir…',
        statusBadge: '$modelName · ${mode.label} · Streaming',
        text: '',
        isStreaming: true,
      ),
      logEntry: ExecutionLogEntry(
        time: logTime,
        command: 'POST /chat/completions [$modelId]',
        detail: 'Agent: ${agent.name} · Mode: ${mode.label}',
        isSuccess: true,
      ),
    );

    final client = _httpClientFactory()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.postUrl(config.chatCompletionsUri);
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/json; charset=utf-8',
      );
      request.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer ${config.apiKey.trim()}',
      );
      request.headers.set('HTTP-Referer', config.siteUrl);
      request.headers.set('X-Title', config.siteTitle);

      final payload = buildOpenRouterPayload(
        prompt: prompt,
        mode: mode,
        modelName: modelName,
        agent: agent,
        history: history,
        attachedFiles: attachedFiles,
      );
      request.add(utf8.encode(jsonEncode(payload)));

      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final errBody = await utf8.decodeStream(response);
        throw Exception(_friendlyHttpError(response.statusCode, errBody));
      }

      final buffer = StringBuffer();
      final lines = response
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      var lastEmitMs = 0;

      await for (final line in lines) {
        final parsed = parseOpenAiSseDataLine(line);
        if (parsed.errorMessage != null) {
          throw Exception(parsed.errorMessage);
        }
        if (parsed.isDone) break;

        if (parsed.contentDelta.isNotEmpty) {
          buffer.write(parsed.contentDelta);
          final nowMs = DateTime.now().millisecondsSinceEpoch;
          if (nowMs - lastEmitMs >= 36) {
            lastEmitMs = nowMs;
            yield PromptStreamChunk(
              partialMessage: ChatMessage(
                id: msgId,
                isUser: false,
                timestampLabel: timeStr,
                heading: agent.name,
                statusBadge: '$modelName · ${mode.label} · Live',
                text: buffer.toString(),
                isStreaming: true,
              ),
            );
          }
        }
      }

      final finalText = buffer.toString().trim();
      final doneNow = DateTime.now();
      final doneLogTime =
          '${doneNow.hour.toString().padLeft(2, '0')}:${doneNow.minute.toString().padLeft(2, '0')}:${doneNow.second.toString().padLeft(2, '0')}';

      final estPromptTokens = (prompt.length / 4).ceil() + 120;
      final estCompletionTokens = (finalText.length / 4).ceil() + 1;

      yield PromptStreamChunk(
        partialMessage: ChatMessage(
          id: msgId,
          isUser: false,
          timestampLabel: timeStr,
          heading: agent.name,
          statusBadge: '$modelName · ${mode.label}',
          text: finalText.isEmpty
              ? '(AI mengembalikan respons kosong)'
              : finalText,
          isStreaming: false,
        ),
        logEntry: ExecutionLogEntry(
          time: doneLogTime,
          command: '200 OK [$modelId]',
          detail: 'Selesai menerima ${finalText.length} karakter dari gateway',
          isSuccess: true,
        ),
        tokenUsage: TokenUsageDelta(
          model: modelName,
          promptTokens: estPromptTokens,
          completionTokens: estCompletionTokens,
          totalTokens: estPromptTokens + estCompletionTokens,
          source: 'OpenRouter',
        ),
      );
    } on SocketException catch (e) {
      throw Exception('Koneksi internet / AI Gateway terputus (${e.message})');
    } on TimeoutException {
      throw Exception('AI Gateway terlalu lama merespons (timeout).');
    } finally {
      client.close(force: true);
    }
  }

  String _friendlyHttpError(int statusCode, String rawBody) {
    String? detail;
    try {
      final decoded = jsonDecode(rawBody);
      if (decoded is Map<String, dynamic>) {
        final err = decoded['error'];
        if (err is Map<String, dynamic>) {
          detail = err['message']?.toString();
        } else if (err is String) {
          detail = err;
        }
      }
    } catch (_) {}

    final suffix = (detail != null && detail.isNotEmpty) ? ': $detail' : '';
    return switch (statusCode) {
      401 => 'API Key OpenRouter tidak valid (401)$suffix',
      402 => 'Kredit OpenRouter habis — coba pilih model (Free) (402)$suffix',
      404 => 'Model atau endpoint gateway tidak ditemukan (404)$suffix',
      429 => 'Rate limit tercapai, tunggu sebentar lalu coba lagi (429)$suffix',
      >= 500 => 'Server AI Gateway sedang bermasalah ($statusCode)$suffix',
      _ => 'HTTP $statusCode$suffix',
    };
  }
}
