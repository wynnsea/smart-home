enum MetricTone { purple, green, amber, blue }

enum HostConnectionState { connected, connecting, disconnected }

class HostStatus {
  const HostStatus({
    required this.userName,
    required this.hostName,
    required this.hostAddress,
    required this.hostPort,
    required this.repoFullName,
    required this.branch,
    required this.connectionState,
    required this.latencyMs,
    required this.completedTasks,
    required this.totalTasks,
    required this.statusNote,
  });

  final String userName;
  final String hostName;
  final String hostAddress;
  final int hostPort;
  final String repoFullName;
  final String branch;
  final HostConnectionState connectionState;
  final int latencyMs;
  final int completedTasks;
  final int totalTasks;
  final String statusNote;

  String get endpointLabel => '$hostAddress:$hostPort';

  bool get isConnected => connectionState == HostConnectionState.connected;

  String get connectionLabel => switch (connectionState) {
    HostConnectionState.connected => 'Terhubung',
    HostConnectionState.connecting => 'Menyambung…',
    HostConnectionState.disconnected => 'Terputus',
  };

  double get progress =>
      totalTasks == 0 ? 0 : (completedTasks / totalTasks).clamp(0.0, 1.0);
  int get progressPercent => (progress * 100).round();

  HostStatus copyWith({
    String? userName,
    String? hostName,
    String? hostAddress,
    int? hostPort,
    String? repoFullName,
    String? branch,
    HostConnectionState? connectionState,
    int? latencyMs,
    int? completedTasks,
    int? totalTasks,
    String? statusNote,
  }) {
    return HostStatus(
      userName: userName ?? this.userName,
      hostName: hostName ?? this.hostName,
      hostAddress: hostAddress ?? this.hostAddress,
      hostPort: hostPort ?? this.hostPort,
      repoFullName: repoFullName ?? this.repoFullName,
      branch: branch ?? this.branch,
      connectionState: connectionState ?? this.connectionState,
      latencyMs: latencyMs ?? this.latencyMs,
      completedTasks: completedTasks ?? this.completedTasks,
      totalTasks: totalTasks ?? this.totalTasks,
      statusNote: statusNote ?? this.statusNote,
    );
  }
}

class QuickMetric {
  const QuickMetric({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.progressPercent,
    required this.ringLabel,
    required this.tone,
    required this.actionKey,
  });

  final String id;
  final String title;
  final String subtitle;
  final int progressPercent;
  final String ringLabel;
  final MetricTone tone;
  final String actionKey;
}

class CodingSession {
  const CodingSession({
    required this.id,
    required this.title,
    required this.repoFullName,
    required this.branch,
    required this.summary,
    required this.progressPercent,
    required this.changedFilesCount,
    required this.updatedAtLabel,
    required this.languageTag,
  });

  final String id;
  final String title;
  final String repoFullName;
  final String branch;
  final String summary;
  final int progressPercent;
  final int changedFilesCount;
  final String updatedAtLabel;
  final String languageTag;
}

class WorkspaceOverview {
  const WorkspaceOverview({
    required this.hostStatus,
    required this.quickMetrics,
    required this.recentSessions,
    required this.availableBranches,
    required this.sampleContextFiles,
  });

  final HostStatus hostStatus;
  final List<QuickMetric> quickMetrics;
  final List<CodingSession> recentSessions;
  final List<String> availableBranches;
  final List<String> sampleContextFiles;

  WorkspaceOverview copyWith({
    HostStatus? hostStatus,
    List<QuickMetric>? quickMetrics,
    List<CodingSession>? recentSessions,
    List<String>? availableBranches,
    List<String>? sampleContextFiles,
  }) {
    return WorkspaceOverview(
      hostStatus: hostStatus ?? this.hostStatus,
      quickMetrics: quickMetrics ?? this.quickMetrics,
      recentSessions: recentSessions ?? this.recentSessions,
      availableBranches: availableBranches ?? this.availableBranches,
      sampleContextFiles: sampleContextFiles ?? this.sampleContextFiles,
    );
  }
}
