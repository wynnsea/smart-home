import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wynndiff/core/config/app_env.dart';
import 'package:wynndiff/features/agent_chat/data/datasources/openrouter_agent_datasource.dart';
import 'package:wynndiff/features/agent_chat/domain/entities/ai_gateway_entities.dart';
import 'package:wynndiff/features/agent_chat/domain/entities/chat_entities.dart';
import 'package:wynndiff/features/agent_chat/presentation/providers/agent_chat_provider.dart';
import 'package:wynndiff/features/agent_chat/presentation/providers/ai_gateway_provider.dart';

void main() {
  group('OpenRouter SSE parser', () {
    test('extracts streaming content deltas and [DONE] sentinel', () {
      final chunk = parseOpenAiSseDataLine(
        'data: {"id":"gen-1","choices":[{"delta":{"content":"Halo "}}]}',
      );
      expect(chunk.contentDelta, equals('Halo '));
      expect(chunk.isDone, isFalse);
      expect(chunk.errorMessage, isNull);

      final done = parseOpenAiSseDataLine('data: [DONE]');
      expect(done.isDone, isTrue);

      final comment = parseOpenAiSseDataLine(': OPENROUTER PROCESSING');
      expect(comment.hasText, isFalse);
      expect(comment.isDone, isFalse);
    });

    test('surfaces gateway error frames cleanly', () {
      final err = parseOpenAiSseDataLine(
        'data: {"error":{"message":"Rate limit exceeded"}}',
      );
      expect(err.errorMessage, equals('Rate limit exceeded'));
    });
  });

  group('Multi-agent OpenRouter payload & model resolution', () {
    test('resolves UI labels and raw OpenRouter slugs accurately', () {
      expect(
        resolveOpenRouterModelId('Claude 4 Sonnet'),
        equals('anthropic/claude-sonnet-4'),
      );
      expect(
        resolveOpenRouterModelId('DeepSeek R1 (Free)'),
        equals('deepseek/deepseek-r1:free'),
      );
      expect(
        resolveOpenRouterModelId('qwen/qwen3-coder:free'),
        equals('qwen/qwen3-coder:free'),
      );
    });

    test('builds system prompt with selected agent persona, mode, and attached files', () {
      final agent = findAgentById('bug-hunter');
      final payload = buildOpenRouterPayload(
        prompt: 'Kenapa stream putus?',
        mode: AgentMode.investigate,
        modelName: 'Claude 4 Sonnet',
        agent: agent,
        attachedFiles: const ['lib/sse_client.dart'],
      );

      expect(payload['model'], equals('anthropic/claude-sonnet-4'));
      expect(payload['stream'], isTrue);
      final messages = payload['messages'] as List<Map<String, String>>;
      expect(messages.first['role'], equals('system'));
      expect(messages.first['content'], contains('Bug Hunter'));
      expect(messages.first['content'], contains('Investigate'));
      expect(messages.first['content'], contains('lib/sse_client.dart'));
      expect(messages.last['role'], equals('user'));
      expect(messages.last['content'], equals('Kenapa stream putus?'));
    });

    test('AiGatewayNotifier and AgentChatNotifier switch agents and gateway config', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(aiGatewayProvider).isConfigured, isFalse);
      container.read(aiGatewayProvider.notifier).updateConfig(
        apiKey: 'sk-or-v1-test-key',
      );
      expect(container.read(aiGatewayProvider).isConfigured, isTrue);
      expect(
        container.read(aiGatewayProvider).chatCompletionsUri.toString(),
        equals('https://openrouter.ai/api/v1/chat/completions'),
      );

      final reviewer = findAgentById('code-reviewer');
      container.read(agentChatProvider.notifier).setAgent(reviewer);
      final chatState = container.read(agentChatProvider);
      expect(chatState.selectedAgentId, equals('code-reviewer'));
      expect(chatState.selectedModel, equals(reviewer.defaultModelLabel));
    });

    test('AppEnv.parse reads KEY=VALUE lines, ignores comments and strips quotes', () {
      final parsed = AppEnv.parse('''
        # comment line
        OPENROUTER_API_KEY="sk-or-v1-abc123"
        AI_GATEWAY_URL='https://openrouter.ai/api/v1'
        EMPTY_LINE_BELOW=
      ''');

      expect(parsed['OPENROUTER_API_KEY'], equals('sk-or-v1-abc123'));
      expect(parsed['AI_GATEWAY_URL'], equals('https://openrouter.ai/api/v1'));
    });
  });
}
