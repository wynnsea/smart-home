enum AgentMode {
  agent('Agent', 'Edit & verify'),
  investigate('Investigate', 'Read-only trace'),
  plan('Plan', 'Architecture first');

  const AgentMode(this.label, this.description);
  final String label;
  final String description;
}

class FindingItem {
  const FindingItem({
    required this.number,
    required this.title,
    required this.bullets,
    this.referencedFiles = const [],
  });

  final int number;
  final String title;
  final List<String> bullets;
  final List<String> referencedFiles;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.isUser,
    required this.timestampLabel,
    this.text = '',
    this.heading,
    this.statusBadge,
    this.findings = const [],
    this.fileChips = const [],
    this.isStreaming = false,
    this.isLiked = false,
    this.isError = false,
  });

  final String id;
  final bool isUser;
  final String timestampLabel;
  final String text;
  final String? heading;
  final String? statusBadge;
  final List<FindingItem> findings;
  final List<String> fileChips;
  final bool isStreaming;
  final bool isLiked;
  final bool isError;

  ChatMessage copyWith({
    String? text,
    String? heading,
    String? statusBadge,
    List<FindingItem>? findings,
    List<String>? fileChips,
    bool? isStreaming,
    bool? isLiked,
    bool? isError,
  }) {
    return ChatMessage(
      id: id,
      isUser: isUser,
      timestampLabel: timestampLabel,
      text: text ?? this.text,
      heading: heading ?? this.heading,
      statusBadge: statusBadge ?? this.statusBadge,
      findings: findings ?? this.findings,
      fileChips: fileChips ?? this.fileChips,
      isStreaming: isStreaming ?? this.isStreaming,
      isLiked: isLiked ?? this.isLiked,
      isError: isError ?? this.isError,
    );
  }
}

class ExecutionLogEntry {
  const ExecutionLogEntry({
    required this.time,
    required this.command,
    required this.detail,
    required this.isSuccess,
  });

  final String time;
  final String command;
  final String detail;
  final bool isSuccess;
}

class ChatSession {
  const ChatSession({
    required this.id,
    required this.title,
    required this.repoFullName,
    required this.branch,
    required this.messages,
    required this.logs,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String repoFullName;
  final String branch;
  final List<ChatMessage> messages;
  final List<ExecutionLogEntry> logs;
  final String updatedAt;

  ChatSession copyWith({
    String? title,
    String? repoFullName,
    String? branch,
    List<ChatMessage>? messages,
    List<ExecutionLogEntry>? logs,
    String? updatedAt,
  }) {
    return ChatSession(
      id: id,
      title: title ?? this.title,
      repoFullName: repoFullName ?? this.repoFullName,
      branch: branch ?? this.branch,
      messages: messages ?? this.messages,
      logs: logs ?? this.logs,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class TokenUsageDelta {
  const TokenUsageDelta({
    required this.model,
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
    required this.source,
  });

  final String model;
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
  final String source;
}

class PromptStreamChunk {
  const PromptStreamChunk({
    required this.partialMessage,
    this.logEntry,
    this.shouldGenerateDiff = false,
    this.tokenUsage,
  });

  final ChatMessage partialMessage;
  final ExecutionLogEntry? logEntry;
  final bool shouldGenerateDiff;
  final TokenUsageDelta? tokenUsage;
}
