import '../entities/workspace_entities.dart';
import '../repositories/workspace_repository.dart';

class GetWorkspaceOverviewUseCase {
  const GetWorkspaceOverviewUseCase(this._repository);

  final WorkspaceRepository _repository;

  WorkspaceOverview call() => _repository.getWorkspaceOverview();
}
