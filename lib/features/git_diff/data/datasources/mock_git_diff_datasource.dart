import '../../domain/entities/diff_entities.dart';

class MockGitDiffDatasource {
  GitDiffSnapshot loadInitialSnapshot() {
    return const GitDiffSnapshot(
      repoFullName: 'wynnsea/wynndiff',
      branch: 'feat/remote-diff',
      lastCommitHash: 'a4c91f2',
      files: [
        DiffFile(
          path: 'mobile/lib/core/network/sse_client.dart',
          status: DiffFileStatus.modified,
          additions: 48,
          deletions: 14,
          summary: 'Added exponential backoff + Tailscale reconnect guard',
          lines: [
            DiffLine(
              type: DiffLineType.hunkHeader,
              content: '@@ -38,12 +38,24 @@ class BridgeSseClient {',
            ),
            DiffLine(
              type: DiffLineType.context,
              oldLineNumber: 38,
              newLineNumber: 38,
              content: '  Stream<BridgeEvent> streamPrompt(String sessionId) async* {',
            ),
            DiffLine(
              type: DiffLineType.deletion,
              oldLineNumber: 39,
              content: '    final response = await _client.send(request);',
            ),
            DiffLine(
              type: DiffLineType.deletion,
              oldLineNumber: 40,
              content: '    yield* _parseLines(response.stream);',
            ),
            DiffLine(
              type: DiffLineType.addition,
              newLineNumber: 39,
              content: '    var attempt = 0;',
            ),
            DiffLine(
              type: DiffLineType.addition,
              newLineNumber: 40,
              content: '    while (attempt < maxRetries) {',
            ),
            DiffLine(
              type: DiffLineType.addition,
              newLineNumber: 41,
              content: '      try {',
            ),
            DiffLine(
              type: DiffLineType.addition,
              newLineNumber: 42,
              content: '        final response = await _client.send(request).timeout(_handshakeTimeout);',
            ),
            DiffLine(
              type: DiffLineType.addition,
              newLineNumber: 43,
              content: '        yield* _parseLines(response.stream);',
            ),
            DiffLine(
              type: DiffLineType.addition,
              newLineNumber: 44,
              content: '        return;',
            ),
            DiffLine(
              type: DiffLineType.addition,
              newLineNumber: 45,
              content: '      } on SocketException {',
            ),
            DiffLine(
              type: DiffLineType.addition,
              newLineNumber: 46,
              content: '        attempt++;',
            ),
            DiffLine(
              type: DiffLineType.addition,
              newLineNumber: 47,
              content: '        await Future<void>.delayed(Duration(milliseconds: 400 * attempt));',
            ),
            DiffLine(
              type: DiffLineType.addition,
              newLineNumber: 48,
              content: '      }',
            ),
            DiffLine(
              type: DiffLineType.addition,
              newLineNumber: 49,
              content: '    }',
            ),
            DiffLine(
              type: DiffLineType.context,
              oldLineNumber: 41,
              newLineNumber: 50,
              content: '  }',
            ),
          ],
        ),
        DiffFile(
          path: 'bridge/internal/git/diff_parser.go',
          status: DiffFileStatus.modified,
          additions: 52,
          deletions: 11,
          summary: 'Structured unified hunk parser with binary-file skip',
          lines: [
            DiffLine(
              type: DiffLineType.hunkHeader,
              content: '@@ -64,9 +64,18 @@ func ParseUnifiedDiff(raw string) ([]FileDiff, error) {',
            ),
            DiffLine(
              type: DiffLineType.context,
              oldLineNumber: 64,
              newLineNumber: 64,
              content: '    scanner := bufio.NewScanner(strings.NewReader(raw))',
            ),
            DiffLine(
              type: DiffLineType.deletion,
              oldLineNumber: 65,
              content: '    for scanner.Scan() {',
            ),
            DiffLine(
              type: DiffLineType.addition,
              newLineNumber: 65,
              content: '    scanner.Buffer(make([]byte, 0, 64*1024), 4*1024*1024)',
            ),
            DiffLine(
              type: DiffLineType.addition,
              newLineNumber: 66,
              content: '    for scanner.Scan() {',
            ),
            DiffLine(
              type: DiffLineType.addition,
              newLineNumber: 67,
              content: '        line := scanner.Text()',
            ),
            DiffLine(
              type: DiffLineType.addition,
              newLineNumber: 68,
              content: '        if strings.HasPrefix(line, "Binary files ") {',
            ),
            DiffLine(
              type: DiffLineType.addition,
              newLineNumber: 69,
              content: '            current.IsBinary = true',
            ),
            DiffLine(
              type: DiffLineType.addition,
              newLineNumber: 70,
              content: '            continue',
            ),
            DiffLine(
              type: DiffLineType.addition,
              newLineNumber: 71,
              content: '        }',
            ),
            DiffLine(
              type: DiffLineType.context,
              oldLineNumber: 66,
              newLineNumber: 72,
              content: '        appendLineToHunk(&current, line)',
            ),
          ],
        ),
        DiffFile(
          path: 'packages/agent-core/src/token_interceptor.ts',
          status: DiffFileStatus.added,
          additions: 34,
          deletions: 0,
          summary: 'New mutex-locked bearer token refresh interceptor',
          lines: [
            DiffLine(
              type: DiffLineType.hunkHeader,
              content: '@@ -0,0 +1,14 @@',
            ),
            DiffLine(
              type: DiffLineType.addition,
              newLineNumber: 1,
              content: 'export class TokenRefreshInterceptor {',
            ),
            DiffLine(
              type: DiffLineType.addition,
              newLineNumber: 2,
              content: '  private inflight: Promise<string> | null = null;',
            ),
            DiffLine(
              type: DiffLineType.addition,
              newLineNumber: 3,
              content: '',
            ),
            DiffLine(
              type: DiffLineType.addition,
              newLineNumber: 4,
              content: '  async getFreshToken(): Promise<string> {',
            ),
            DiffLine(
              type: DiffLineType.addition,
              newLineNumber: 5,
              content: '    if (!this.inflight) {',
            ),
            DiffLine(
              type: DiffLineType.addition,
              newLineNumber: 6,
              content: '      this.inflight = this.refresh().finally(() => {',
            ),
            DiffLine(
              type: DiffLineType.addition,
              newLineNumber: 7,
              content: '        this.inflight = null;',
            ),
            DiffLine(
              type: DiffLineType.addition,
              newLineNumber: 8,
              content: '      });',
            ),
            DiffLine(
              type: DiffLineType.addition,
              newLineNumber: 9,
              content: '    }',
            ),
            DiffLine(
              type: DiffLineType.addition,
              newLineNumber: 10,
              content: '    return this.inflight;',
            ),
            DiffLine(
              type: DiffLineType.addition,
              newLineNumber: 11,
              content: '  }',
            ),
            DiffLine(
              type: DiffLineType.addition,
              newLineNumber: 12,
              content: '}',
            ),
          ],
        ),
        DiffFile(
          path: 'web/components/legacy_diff_drawer.tsx',
          status: DiffFileStatus.deleted,
          additions: 8,
          deletions: 13,
          summary: 'Removed deprecated polling drawer replaced by SSE stream',
          lines: [
            DiffLine(
              type: DiffLineType.hunkHeader,
              content: '@@ -12,9 +12,4 @@ export const LegacyDiffDrawer = () => {',
            ),
            DiffLine(
              type: DiffLineType.deletion,
              oldLineNumber: 12,
              content: '  useEffect(() => {',
            ),
            DiffLine(
              type: DiffLineType.deletion,
              oldLineNumber: 13,
              content: '    const timer = setInterval(fetchDiffStatus, 2500);',
            ),
            DiffLine(
              type: DiffLineType.deletion,
              oldLineNumber: 14,
              content: '    return () => clearInterval(timer);',
            ),
            DiffLine(
              type: DiffLineType.deletion,
              oldLineNumber: 15,
              content: '  }, []);',
            ),
            DiffLine(
              type: DiffLineType.addition,
              newLineNumber: 12,
              content: '  // Replaced by EventSource stream in BridgeDiffProvider',
            ),
          ],
        ),
      ],
    );
  }

  DiffFile buildPatchForPrompt(String prompt) {
    final lower = prompt.toLowerCase();
    final isUi = lower.contains('ui') || lower.contains('theme') || lower.contains('color');
    final filePath = isUi
        ? 'mobile/lib/features/git_diff/presentation/diff_highlight.dart'
        : 'bridge/internal/prompt/session_guard.go';

    return DiffFile(
      path: filePath,
      status: DiffFileStatus.added,
      additions: 21,
      deletions: 2,
      summary: 'Auto-generated patch for: "$prompt"',
      lines: [
        DiffLine(
          type: DiffLineType.hunkHeader,
          content: isUi
              ? '@@ -1,4 +1,11 @@ class DiffHighlightConfig {'
              : '@@ -1,4 +1,11 @@ func ValidatePromptSession(ctx context.Context) error {',
        ),
        const DiffLine(
          type: DiffLineType.deletion,
          oldLineNumber: 2,
          content: '  // TODO: guard concurrent prompt mutations',
        ),
        DiffLine(
          type: DiffLineType.addition,
          newLineNumber: 2,
          content: isUi
              ? '  final bool emphasizeInlineFileChips = true;'
              : '  if err := repoLock.Acquire(ctx); err != nil {',
        ),
        DiffLine(
          type: DiffLineType.addition,
          newLineNumber: 3,
          content: isUi
              ? '  final double borderRadius = 22.0;'
              : '      return fmt.Errorf("workspace busy: %w", err)',
        ),
        DiffLine(
          type: DiffLineType.addition,
          newLineNumber: 4,
          content: isUi ? '  final Duration streamFade = const Duration(milliseconds: 220);' : '  }',
        ),
        DiffLine(
          type: DiffLineType.addition,
          newLineNumber: 5,
          content: isUi ? '  // Applied from mobile remote prompt' : '  defer repoLock.Release()',
        ),
      ],
    );
  }
}
