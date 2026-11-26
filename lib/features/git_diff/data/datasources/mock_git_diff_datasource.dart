import '../../domain/entities/diff_entities.dart';

class MockGitDiffDatasource {
  GitDiffSnapshot loadInitialSnapshot() {
    return const GitDiffSnapshot(
      repoFullName: 'Belum terhubung ke repo',
      branch: 'main',
      lastCommitHash: '—',
      files: [],
    );
  }

  DiffFile buildPatchForPrompt(String prompt) {
    return DiffFile(
      path: 'changes/patch.txt',
      status: DiffFileStatus.added,
      additions: 1,
      deletions: 0,
      summary: 'Simulasi patch lokal: "$prompt"',
      lines: [
        const DiffLine(
          type: DiffLineType.hunkHeader,
          content: '@@ -0,0 +1,1 @@',
        ),
        DiffLine(
          type: DiffLineType.addition,
          newLineNumber: 1,
          content: '// $prompt',
        ),
      ],
    );
  }
}
