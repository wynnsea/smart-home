import '../../domain/entities/diff_entities.dart';
import '../../domain/repositories/git_diff_repository.dart';
import '../datasources/mock_git_diff_datasource.dart';

class GitDiffRepositoryImpl implements GitDiffRepository {
  const GitDiffRepositoryImpl(this._datasource);

  final MockGitDiffDatasource _datasource;

  @override
  GitDiffSnapshot getInitialSnapshot() => _datasource.loadInitialSnapshot();

  @override
  Future<GitDiffSnapshot> commitAndPush({
    required GitDiffSnapshot current,
    required String commitMessage,
    required List<String> filePaths,
    required bool pushToRemote,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 550));
    final selectedSet = filePaths.toSet();
    final remainingFiles = current.files
        .where((f) => !selectedSet.contains(f.path))
        .toList();
    final actionVerb = pushToRemote ? 'Committed & pushed' : 'Committed';
    return current.copyWith(
      lastCommitHash: 'e8f42b9',
      files: remainingFiles,
      lastActionMessage:
          '$actionVerb (${filePaths.length} file): "$commitMessage"',
    );
  }

  @override
  Future<GitDiffSnapshot> discardAllChanges({
    required GitDiffSnapshot current,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    return current.copyWith(
      files: const [],
      lastActionMessage:
          'Working tree reset bersih ke HEAD (${current.lastCommitHash})',
    );
  }

  @override
  Future<GitDiffSnapshot> revertFile({
    required GitDiffSnapshot current,
    required String filePath,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final fileName = filePath.split('/').last;
    final remaining = current.files.where((f) => f.path != filePath).toList();
    return current.copyWith(
      files: remaining,
      lastActionMessage: 'Perubahan di $fileName dikembalikan ke HEAD',
    );
  }

  @override
  DiffFile createMockGeneratedPatch(String prompt) {
    return _datasource.buildPatchForPrompt(prompt);
  }
}
