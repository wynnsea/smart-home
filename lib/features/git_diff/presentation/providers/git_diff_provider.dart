import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/wynn_bridge_client.dart';
import '../../data/datasources/mock_git_diff_datasource.dart';
import '../../data/repositories/git_diff_repository_impl.dart';
import '../../domain/entities/diff_entities.dart';
import '../../domain/repositories/git_diff_repository.dart';
import '../../domain/usecases/git_diff_usecases.dart';

const Object _unset = Object();

class GitDiffUiState {
  const GitDiffUiState({
    required this.snapshot,
    this.isBusy = false,
    this.selectedFilePath,
    this.previousSnapshot,
  });

  final GitDiffSnapshot snapshot;
  final bool isBusy;
  final String? selectedFilePath;
  final GitDiffSnapshot? previousSnapshot;

  GitDiffUiState copyWith({
    GitDiffSnapshot? snapshot,
    bool? isBusy,
    Object? selectedFilePath = _unset,
    Object? previousSnapshot = _unset,
  }) {
    return GitDiffUiState(
      snapshot: snapshot ?? this.snapshot,
      isBusy: isBusy ?? this.isBusy,
      selectedFilePath: selectedFilePath == _unset
          ? this.selectedFilePath
          : selectedFilePath as String?,
      previousSnapshot: previousSnapshot == _unset
          ? this.previousSnapshot
          : previousSnapshot as GitDiffSnapshot?,
    );
  }
}

final gitDiffRepositoryProvider = Provider<GitDiffRepository>((ref) {
  return GitDiffRepositoryImpl(MockGitDiffDatasource());
});

class GitDiffNotifier extends Notifier<GitDiffUiState> {
  @override
  GitDiffUiState build() {
    final repo = ref.watch(gitDiffRepositoryProvider);
    final initial = GetGitDiffSnapshotUseCase(repo).call();
    return GitDiffUiState(
      snapshot: initial,
      selectedFilePath: initial.files.isNotEmpty
          ? initial.files.first.path
          : null,
    );
  }

  void selectFile(String filePath) {
    state = state.copyWith(selectedFilePath: filePath);
  }

  void addGeneratedPatch(String prompt) {
    final repo = ref.read(gitDiffRepositoryProvider);
    final patch = repo.createMockGeneratedPatch(prompt);
    final existing = state.snapshot.files
        .where((f) => f.path != patch.path)
        .toList();
    final updatedFiles = [patch, ...existing];
    state = state.copyWith(
      snapshot: state.snapshot.copyWith(
        files: updatedFiles,
        lastActionMessage: 'Updated diff: ${patch.fileName}',
      ),
      selectedFilePath: patch.path,
    );
  }

  Future<String> commitAndPush(
    String commitMessage, {
    List<String>? filePaths,
    bool pushToRemote = true,
  }) async {
    final bridgeCfg = ref.read(bridgeConfigProvider);
    if (bridgeCfg.isActive) {
      state = state.copyWith(isBusy: true);
      try {
        final msg = await WynnBridgeClient().commitAndPush(
          bridgeCfg,
          message: commitMessage,
          push: pushToRemote,
        );
        await refresh();
        state = state.copyWith(
          isBusy: false,
          snapshot: state.snapshot.copyWith(lastActionMessage: msg),
        );
        return msg;
      } catch (e) {
        state = state.copyWith(isBusy: false);
        return 'Gagal commit/push: ${e.toString().replaceFirst('Exception: ', '')}';
      }
    }

    final targetPaths =
        filePaths ?? state.snapshot.files.map((f) => f.path).toList();
    state = state.copyWith(isBusy: true);
    final useCase = CommitAndPushUseCase(ref.read(gitDiffRepositoryProvider));
    final updated = await useCase(
      current: state.snapshot,
      commitMessage: commitMessage,
      filePaths: targetPaths,
      pushToRemote: pushToRemote,
    );
    final nextSelected = updated.files.isNotEmpty
        ? (updated.files.any((f) => f.path == state.selectedFilePath)
              ? state.selectedFilePath
              : updated.files.first.path)
        : null;
    state = state.copyWith(
      snapshot: updated,
      isBusy: false,
      selectedFilePath: nextSelected,
      previousSnapshot: null,
    );
    return updated.lastActionMessage ?? 'Committed';
  }

  Future<String> discardAllChanges() async {
    final bridgeCfg = ref.read(bridgeConfigProvider);
    if (bridgeCfg.isActive) {
      state = state.copyWith(isBusy: true);
      try {
        await WynnBridgeClient().resetChanges(bridgeCfg);
        await refresh();
        state = state.copyWith(isBusy: false);
        return 'Semua perubahan di Server dibuang';
      } catch (e) {
        state = state.copyWith(isBusy: false);
        return 'Gagal discard: ${e.toString().replaceFirst('Exception: ', '')}';
      }
    }

    final backup = state.snapshot;
    state = state.copyWith(isBusy: true);
    final useCase = DiscardChangesUseCase(ref.read(gitDiffRepositoryProvider));
    final updated = await useCase(current: state.snapshot);
    state = state.copyWith(
      snapshot: updated,
      isBusy: false,
      selectedFilePath: null,
      previousSnapshot: backup,
    );
    return updated.lastActionMessage ?? 'Perubahan dibuang';
  }

  Future<String> revertFile(String filePath) async {
    final bridgeCfg = ref.read(bridgeConfigProvider);
    if (bridgeCfg.isActive) {
      state = state.copyWith(isBusy: true);
      try {
        await WynnBridgeClient().resetChanges(bridgeCfg, filePath: filePath);
        await refresh();
        state = state.copyWith(isBusy: false);
        return 'File $filePath dikembalikan di Server';
      } catch (e) {
        state = state.copyWith(isBusy: false);
        return 'Gagal revert: ${e.toString().replaceFirst('Exception: ', '')}';
      }
    }

    final backup = state.snapshot;
    state = state.copyWith(isBusy: true);
    final useCase = RevertFileUseCase(ref.read(gitDiffRepositoryProvider));
    final updated = await useCase(
      current: state.snapshot,
      filePath: filePath,
    );
    final nextSelected = updated.files.isNotEmpty
        ? updated.files.first.path
        : null;
    state = state.copyWith(
      snapshot: updated,
      isBusy: false,
      selectedFilePath: nextSelected,
      previousSnapshot: backup,
    );
    return updated.lastActionMessage ?? 'File dikembalikan';
  }

  void undoLastDiscard() {
    final backup = state.previousSnapshot;
    if (backup == null) return;
    state = state.copyWith(
      snapshot: backup,
      selectedFilePath: backup.files.isNotEmpty ? backup.files.first.path : null,
      previousSnapshot: null,
    );
  }

  void restoreSampleDiffs() {
    final repo = ref.read(gitDiffRepositoryProvider);
    final initial = GetGitDiffSnapshotUseCase(repo).call();
    state = GitDiffUiState(
      snapshot: initial,
      selectedFilePath: initial.files.isNotEmpty
          ? initial.files.first.path
          : null,
    );
  }

  Future<void> refresh() async {
    final bridgeCfg = ref.read(bridgeConfigProvider);
    if (bridgeCfg.isActive) {
      try {
        final fresh = await WynnBridgeClient().fetchGitDiff(bridgeCfg);
        final keepSelected =
            fresh.files.any((f) => f.path == state.selectedFilePath)
            ? state.selectedFilePath
            : (fresh.files.isNotEmpty ? fresh.files.first.path : null);
        state = GitDiffUiState(
          snapshot: fresh,
          selectedFilePath: keepSelected,
        );
        return;
      } catch (_) {
        // Keep current snapshot on transient bridge error
        return;
      }
    }

    await Future<void>.delayed(const Duration(milliseconds: 600));
    final repo = ref.read(gitDiffRepositoryProvider);
    final fresh = GetGitDiffSnapshotUseCase(repo).call();
    final keepSelected = fresh.files.any((f) => f.path == state.selectedFilePath)
        ? state.selectedFilePath
        : (fresh.files.isNotEmpty ? fresh.files.first.path : null);
    state = GitDiffUiState(
      snapshot: fresh,
      selectedFilePath: keepSelected,
    );
  }
}

final gitDiffProvider = NotifierProvider<GitDiffNotifier, GitDiffUiState>(
  GitDiffNotifier.new,
);
