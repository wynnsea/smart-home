import '../entities/diff_entities.dart';
import '../repositories/git_diff_repository.dart';

class GetGitDiffSnapshotUseCase {
  const GetGitDiffSnapshotUseCase(this._repository);

  final GitDiffRepository _repository;

  GitDiffSnapshot call() => _repository.getInitialSnapshot();
}

class CommitAndPushUseCase {
  const CommitAndPushUseCase(this._repository);

  final GitDiffRepository _repository;

  Future<GitDiffSnapshot> call({
    required GitDiffSnapshot current,
    required String commitMessage,
    required List<String> filePaths,
    required bool pushToRemote,
  }) {
    return _repository.commitAndPush(
      current: current,
      commitMessage: commitMessage,
      filePaths: filePaths,
      pushToRemote: pushToRemote,
    );
  }
}

class DiscardChangesUseCase {
  const DiscardChangesUseCase(this._repository);

  final GitDiffRepository _repository;

  Future<GitDiffSnapshot> call({required GitDiffSnapshot current}) {
    return _repository.discardAllChanges(current: current);
  }
}

class RevertFileUseCase {
  const RevertFileUseCase(this._repository);

  final GitDiffRepository _repository;

  Future<GitDiffSnapshot> call({
    required GitDiffSnapshot current,
    required String filePath,
  }) {
    return _repository.revertFile(current: current, filePath: filePath);
  }
}
