import '../../domain/entities/workspace_entities.dart';

class MockWorkspaceDatasource {
  WorkspaceOverview fetchOverview() {
    return const WorkspaceOverview(
      hostStatus: HostStatus(
        userName: 'Wynnsea Dev',
        hostName: 'wynnsea-linux · Tailscale',
        hostAddress: '100.84.22.14',
        hostPort: 8787,
        repoFullName: 'wynnsea/wynndiff',
        branch: 'feat/remote-diff',
        connectionState: HostConnectionState.connected,
        latencyMs: 14,
        completedTasks: 15,
        totalTasks: 20,
        statusNote: 'Small clean commits every day lead to reliable releases',
      ),
      availableBranches: [
        'feat/remote-diff',
        'main',
        'ui/ethereal-v2',
      ],
      sampleContextFiles: [
        'pubspec.yaml',
        'lib/app.dart',
        'lib/core/theme/app_colors.dart',
        'bridge/cmd/server/main.go',
      ],
      quickMetrics: [
        QuickMetric(
          id: 'investigate',
          title: 'Investigate',
          subtitle: '3 active threads',
          progressPercent: 78,
          ringLabel: '78%',
          tone: MetricTone.purple,
          actionKey: 'chat',
        ),
        QuickMetric(
          id: 'git_diff',
          title: 'Git Diff',
          subtitle: '4 files modified',
          progressPercent: 85,
          ringLabel: '+142',
          tone: MetricTone.green,
          actionKey: 'diff',
        ),
        QuickMetric(
          id: 'test_suite',
          title: 'Test Suite',
          subtitle: '18 / 20 passed',
          progressPercent: 90,
          ringLabel: '90%',
          tone: MetricTone.amber,
          actionKey: 'logs',
        ),
        QuickMetric(
          id: 'bridge_sync',
          title: 'Bridge Sync',
          subtitle: '14ms · Secure',
          progressPercent: 96,
          ringLabel: '96%',
          tone: MetricTone.blue,
          actionKey: 'hub',
        ),
      ],
      recentSessions: [
        CodingSession(
          id: 'session-auth-refresh',
          title: 'Investigate Token Refresh & Diff Stream',
          repoFullName: 'wynnsea/wynndiff',
          branch: 'feat/remote-diff',
          summary: '4 files changed · SSE reconnect & diff parser ready',
          progressPercent: 80,
          changedFilesCount: 4,
          updatedAtLabel: '2m ago',
          languageTag: 'DART / GO',
        ),
        CodingSession(
          id: 'session-ui-shell',
          title: 'Refine Mobile Diff Sheet & Patch Hunks',
          repoFullName: 'wynnsea/wynndiff',
          branch: 'ui/ethereal-v2',
          summary: '2 files changed · Unified line gutter polish',
          progressPercent: 64,
          changedFilesCount: 2,
          updatedAtLabel: '42m ago',
          languageTag: 'FLUTTER',
        ),
      ],
    );
  }
}
