import '../../domain/entities/chat_entities.dart';

class MockAgentChatDatasource {
  List<ChatMessage> loadInitialMessages() {
    return const [
      ChatMessage(
        id: 'm1',
        isUser: false,
        timestampLabel: '10:18',
        heading: 'Connected to wynnsea/wynndiff',
        statusBadge: 'Host Ready · Tailscale 14ms',
        text:
            'Workspace synced on branch `feat/remote-diff`. Kirim prompt atau ketuk chip file di bawah untuk inspeksi **git diff** langsung.',
      ),
      ChatMessage(
        id: 'm2',
        isUser: true,
        timestampLabel: '10:19',
        text:
            'Investigate kenapa SSE stream disconnect saat HP pindah Wi-Fi ke 4G dan rapikan parser git diff di bridge.',
      ),
      ChatMessage(
        id: 'm3',
        isUser: false,
        timestampLabel: '10:20',
        heading: 'Investigation & Patch Summary',
        statusBadge: '4 files changed · 12 events',
        text:
            'Root cause found across the mobile SSE client and Go diff parser. Applied minimal fixes and verified unit tests:',
        findings: [
          FindingItem(
            number: 1,
            title: 'Unrecovered SocketException on network handoff',
            bullets: [
              'Added exponential backoff retry loop with 400ms base delay & handshake timeout.',
              'Preserved session cursor so streaming resumes without duplicating chunks.',
            ],
            referencedFiles: ['mobile/lib/core/network/sse_client.dart'],
          ),
          FindingItem(
            number: 2,
            title: 'Large diff buffer overflow & binary file crash',
            bullets: [
              'Expanded bufio.Scanner buffer up to 4MB in the Go bridge parser.',
              'Added explicit guard to skip Binary files lines cleanly.',
            ],
            referencedFiles: ['bridge/internal/git/diff_parser.go'],
          ),
          FindingItem(
            number: 3,
            title: 'Concurrent token refresh race condition',
            bullets: [
              'Introduced a single in-flight mutex promise to coalesce parallel 401 refreshes.',
              'Retired the legacy 2.5s polling drawer in favor of SSE push events.',
            ],
            referencedFiles: [
              'packages/agent-core/src/token_interceptor.ts',
              'web/components/legacy_diff_drawer.tsx',
            ],
          ),
        ],
        fileChips: [
          'mobile/lib/core/network/sse_client.dart',
          'bridge/internal/git/diff_parser.go',
          'packages/agent-core/src/token_interceptor.ts',
          'web/components/legacy_diff_drawer.tsx',
        ],
      ),
    ];
  }

  List<ExecutionLogEntry> loadInitialLogs() {
    return const [
      ExecutionLogEntry(
        time: '10:19:02',
        command: 'git status --porcelain',
        detail: 'Branch feat/remote-diff · clean working tree before run',
        isSuccess: true,
      ),
      ExecutionLogEntry(
        time: '10:19:08',
        command: 'rg "streamPrompt|ParseUnifiedDiff"',
        detail: 'Matched 6 symbols across mobile/ and bridge/internal/git/',
        isSuccess: true,
      ),
      ExecutionLogEntry(
        time: '10:19:21',
        command: 'apply_patch (4 files)',
        detail: '+142 additions / -38 deletions staged for mobile review',
        isSuccess: true,
      ),
      ExecutionLogEntry(
        time: '10:19:34',
        command: 'go test ./internal/git/... && flutter test',
        detail: '18 / 20 checks passed · 2 optional integration specs skipped',
        isSuccess: true,
      ),
    ];
  }

  Stream<PromptStreamChunk> streamMockResponse({
    required String prompt,
    required AgentMode mode,
    required String modelName,
  }) async* {
    final msgId = 'agent-${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final logTime =
        '$timeStr:${now.second.toString().padLeft(2, '0')}';

    final lower = prompt.toLowerCase();
    final isUi = lower.contains('ui') || lower.contains('theme') || lower.contains('color');
    final generatedPath = isUi
        ? 'mobile/lib/features/git_diff/presentation/diff_highlight.dart'
        : 'bridge/internal/prompt/session_guard.go';

    yield PromptStreamChunk(
      partialMessage: ChatMessage(
        id: msgId,
        isUser: false,
        timestampLabel: timeStr,
        heading: 'Scanning repository...',
        statusBadge: '${mode.label} · $modelName · Running',
        text: 'Inspecting symbols and git worktree for "$prompt"...',
        isStreaming: true,
      ),
      logEntry: ExecutionLogEntry(
        time: logTime,
        command: 'POST /prompt [${mode.label.toLowerCase()}]',
        detail: 'Dispatched prompt to host via $modelName',
        isSuccess: true,
      ),
    );

    if (lower.contains('/fail')) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      throw Exception('Bridge host gagal merespons stream (simulasi /fail)');
    }

    await Future<void>.delayed(const Duration(milliseconds: 650));

    yield PromptStreamChunk(
      partialMessage: ChatMessage(
        id: msgId,
        isUser: false,
        timestampLabel: timeStr,
        heading: 'Analyzing impact & preparing patch...',
        statusBadge: '2 events · Tracing AST',
        text: 'Located target module and validating side effects against existing tests.',
        findings: [
          FindingItem(
            number: 1,
            title: 'Context matched in active branch',
            bullets: [
              'Checked current git diff state and isolated clean patch boundary.',
            ],
            referencedFiles: [generatedPath],
          ),
        ],
        isStreaming: true,
      ),
      logEntry: ExecutionLogEntry(
        time: logTime,
        command: 'analyze_symbols $generatedPath',
        detail: 'Verified imports, types, and clean architecture boundaries',
        isSuccess: true,
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 750));

    yield PromptStreamChunk(
      partialMessage: ChatMessage(
        id: msgId,
        isUser: false,
        timestampLabel: timeStr,
        heading: 'Remote Update Ready for Review',
        statusBadge: '1 new file · Verified',
        text:
            'Completed request in ${mode.label} mode. Tap the file chip below or open the Diff sheet to review and commit.',
        findings: [
          FindingItem(
            number: 1,
            title: 'Implemented requested adjustment',
            bullets: [
              'Applied clean scoped changes aligned with your prompt.',
              'No regression detected across existing analyzer rules.',
            ],
            referencedFiles: [generatedPath],
          ),
          FindingItem(
            number: 2,
            title: 'Diff synced to mobile viewer',
            bullets: [
              'Added +21 / -2 lines ready for Commit & Push or Discard.',
            ],
          ),
        ],
        fileChips: [generatedPath],
        isStreaming: false,
      ),
      logEntry: ExecutionLogEntry(
        time: logTime,
        command: 'git diff --stat',
        detail: 'Synced $generatedPath (+21 / -2) to mobile client',
        isSuccess: true,
      ),
      shouldGenerateDiff: true,
    );
  }
}
