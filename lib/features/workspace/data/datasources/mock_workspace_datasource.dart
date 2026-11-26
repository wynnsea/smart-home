import '../../../../core/config/app_env.dart';
import '../../domain/entities/workspace_entities.dart';

class MockWorkspaceDatasource {
  WorkspaceOverview fetchOverview() {
    final envHost = AppEnv.bridgeHost;
    return WorkspaceOverview(
      hostStatus: HostStatus(
        userName: 'Wayan',
        hostName: envHost.isNotEmpty ? 'PC Bridge ($envHost)' : 'AI Gateway Ready',
        hostAddress: envHost.isNotEmpty ? envHost : '100.85.100.80',
        hostPort: AppEnv.bridgePort,
        repoFullName: 'Belum terhubung ke repo',
        branch: 'main',
        connectionState: HostConnectionState.connected,
        latencyMs: 0,
        completedTasks: 0,
        totalTasks: 0,
        statusNote: 'Hubungkan PC Bridge di tab Host untuk remote coding & Git Diff',
      ),
      availableBranches: const ['main'],
      sampleContextFiles: const [],
      quickMetrics: const [
        QuickMetric(
          id: 'investigate',
          title: 'Chat AI',
          subtitle: 'Mulai sesi baru',
          progressPercent: 0,
          ringLabel: '0',
          tone: MetricTone.purple,
          actionKey: 'chat',
        ),
        QuickMetric(
          id: 'git_diff',
          title: 'Git Diff',
          subtitle: 'Clean tree',
          progressPercent: 0,
          ringLabel: '0',
          tone: MetricTone.green,
          actionKey: 'diff',
        ),
        QuickMetric(
          id: 'test_suite',
          title: 'Log Host',
          subtitle: '0 event',
          progressPercent: 0,
          ringLabel: '0',
          tone: MetricTone.amber,
          actionKey: 'logs',
        ),
        QuickMetric(
          id: 'bridge_sync',
          title: 'Agent Hub',
          subtitle: 'Wynn siap',
          progressPercent: 100,
          ringLabel: 'AI',
          tone: MetricTone.blue,
          actionKey: 'hub',
        ),
      ],
      recentSessions: const [],
    );
  }
}
