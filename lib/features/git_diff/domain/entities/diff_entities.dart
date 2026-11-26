enum DiffFileStatus { added, modified, deleted }

enum DiffLineType { context, addition, deletion, hunkHeader }

const Object _diffUnset = Object();

class DiffLine {
  const DiffLine({
    required this.type,
    required this.content,
    this.oldLineNumber,
    this.newLineNumber,
  });

  final DiffLineType type;
  final String content;
  final int? oldLineNumber;
  final int? newLineNumber;
}

class DiffFile {
  const DiffFile({
    required this.path,
    required this.status,
    required this.additions,
    required this.deletions,
    required this.summary,
    required this.lines,
  });

  final String path;
  final DiffFileStatus status;
  final int additions;
  final int deletions;
  final String summary;
  final List<DiffLine> lines;

  String get fileName => path.split('/').last;

  String get statusSymbol => switch (status) {
    DiffFileStatus.added => '+',
    DiffFileStatus.modified => '~',
    DiffFileStatus.deleted => '-',
  };
}

class GitDiffSnapshot {
  const GitDiffSnapshot({
    required this.repoFullName,
    required this.branch,
    required this.lastCommitHash,
    required this.files,
    this.lastActionMessage,
  });

  final String repoFullName;
  final String branch;
  final String lastCommitHash;
  final List<DiffFile> files;
  final String? lastActionMessage;

  int get totalAdditions => files.fold(0, (sum, f) => sum + f.additions);
  int get totalDeletions => files.fold(0, (sum, f) => sum + f.deletions);
  bool get hasChanges => files.isNotEmpty;

  GitDiffSnapshot copyWith({
    String? repoFullName,
    String? branch,
    String? lastCommitHash,
    List<DiffFile>? files,
    Object? lastActionMessage = _diffUnset,
  }) {
    return GitDiffSnapshot(
      repoFullName: repoFullName ?? this.repoFullName,
      branch: branch ?? this.branch,
      lastCommitHash: lastCommitHash ?? this.lastCommitHash,
      files: files ?? this.files,
      lastActionMessage: lastActionMessage == _diffUnset
          ? this.lastActionMessage
          : lastActionMessage as String?,
    );
  }
}
