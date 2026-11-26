import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/wynn_bridge_client.dart';
import '../../../git_diff/presentation/providers/git_diff_provider.dart';
import '../../data/datasources/mock_workspace_datasource.dart';
import '../../data/repositories/workspace_repository_impl.dart';
import '../../domain/entities/workspace_entities.dart';
import '../../domain/repositories/workspace_repository.dart';
import '../../domain/usecases/get_workspace_overview.dart';

final workspaceRepositoryProvider = Provider<WorkspaceRepository>((ref) {
  return WorkspaceRepositoryImpl(MockWorkspaceDatasource());
});

final getWorkspaceOverviewUseCaseProvider =
    Provider<GetWorkspaceOverviewUseCase>((ref) {
      return GetWorkspaceOverviewUseCase(
        ref.watch(workspaceRepositoryProvider),
      );
    });

class WorkspaceNotifier extends Notifier<WorkspaceOverview> {
  @override
  WorkspaceOverview build() {
    return ref.watch(getWorkspaceOverviewUseCaseProvider).call();
  }

  void updateHostEndpoint({required String address, required int port}) {
    state = state.copyWith(
      hostStatus: state.hostStatus.copyWith(
        hostAddress: address.trim(),
        hostPort: port,
      ),
    );
    ref
        .read(bridgeConfigProvider.notifier)
        .update(hostAddress: address.trim(), hostPort: port);
  }

  Future<int> reconnect() async {
    if (state.hostStatus.connectionState == HostConnectionState.connecting) {
      return state.hostStatus.latencyMs;
    }
    state = state.copyWith(
      hostStatus: state.hostStatus.copyWith(
        connectionState: HostConnectionState.connecting,
      ),
    );

    final bridgeCfg = ref.read(bridgeConfigProvider);
    if (bridgeCfg.isActive) {
      final health = await WynnBridgeClient().fetchHealth(bridgeCfg);
      if (health.ok) {
        state = state.copyWith(
          hostStatus: state.hostStatus.copyWith(
            hostName: health.hostName,
            repoFullName: health.repoFullName,
            branch: health.branch,
            connectionState: HostConnectionState.connected,
            latencyMs: health.latencyMs,
          ),
        );
        await ref.read(gitDiffProvider.notifier).refresh();
        return health.latencyMs;
      }
      state = state.copyWith(
        hostStatus: state.hostStatus.copyWith(
          connectionState: HostConnectionState.disconnected,
          latencyMs: 0,
        ),
      );
      throw Exception(health.errorMessage ?? 'Bridge PC tidak merespons');
    }

    await Future<void>.delayed(const Duration(milliseconds: 1200));
    const measuredLatency = 13;
    state = state.copyWith(
      hostStatus: state.hostStatus.copyWith(
        connectionState: HostConnectionState.connected,
        latencyMs: measuredLatency,
      ),
    );
    return measuredLatency;
  }

  void simulateDisconnect() {
    state = state.copyWith(
      hostStatus: state.hostStatus.copyWith(
        connectionState: HostConnectionState.disconnected,
        latencyMs: 0,
      ),
    );
  }

  Future<void> refresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final fresh = ref.read(getWorkspaceOverviewUseCaseProvider).call();
    state = fresh.copyWith(
      hostStatus: fresh.hostStatus.copyWith(
        hostAddress: state.hostStatus.hostAddress,
        hostPort: state.hostStatus.hostPort,
        connectionState: state.hostStatus.connectionState,
        latencyMs: state.hostStatus.isConnected ? fresh.hostStatus.latencyMs : 0,
      ),
    );
  }
}

final workspaceOverviewProvider =
    NotifierProvider<WorkspaceNotifier, WorkspaceOverview>(
      WorkspaceNotifier.new,
    );
