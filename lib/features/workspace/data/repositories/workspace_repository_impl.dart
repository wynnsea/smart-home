import '../../domain/entities/workspace_entities.dart';
import '../../domain/repositories/workspace_repository.dart';
import '../datasources/mock_workspace_datasource.dart';

class WorkspaceRepositoryImpl implements WorkspaceRepository {
  const WorkspaceRepositoryImpl(this._datasource);

  final MockWorkspaceDatasource _datasource;

  @override
  WorkspaceOverview getWorkspaceOverview() => _datasource.fetchOverview();
}
