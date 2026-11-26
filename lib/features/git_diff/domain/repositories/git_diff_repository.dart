import '../entities/diff_entities.dart';

abstract interface class GitDiffRepository {
  GitDiffSnapshot getInitialSnapshot();
  Future<GitDiffSnapshot> commitAndPush({
    required GitDiffSnapshot current,
    required String commitMessage,
    required List<String> filePaths,
    required bool pushToRemote,
  });
  Future<GitDiffSnapshot> discardAllChanges({
    required GitDiffSnapshot current,
  });
  Future<GitDiffSnapshot> revertFile({
    required GitDiffSnapshot current,
    required String filePath,
  });
  DiffFile createMockGeneratedPatch(String prompt);
}
