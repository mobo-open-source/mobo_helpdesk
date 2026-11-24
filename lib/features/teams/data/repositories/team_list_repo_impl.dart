import '../../domain/repositories/team_list_repo.dart';
import '../datasources/team_list_remote_datasource.dart';

/// Repository implementation for managing Team List operations.
///
/// Acts as a bridge between the domain layer ([TeamListRepo])
/// and the data layer ([TeamListRemoteDatasource]).
///
/// This class delegates all operations to the remote datasource,
/// ensuring separation of concerns and keeping the domain layer
/// independent of API implementation details.
class TeamListRepoImpl implements TeamListRepo {
  final TeamListRemoteDatasource teamListRemoteDatasource;

  TeamListRepoImpl(this.teamListRemoteDatasource);

  /// Loads a paginated list of teams from the remote source.
  ///
  /// [limit] defines number of items per page.
  /// [offset] defines pagination offset.
  /// [search] is used to filter teams by name.
  /// [filters] contains optional filter keys like archived state.
  ///
  /// Returns a map containing:
  /// - `data`: list of teams
  /// - `total`: total count of teams
  @override
  Future<Map<String, dynamic>> loadTeams({
    required int limit,
    required int offset,
    String? search,
    List<String>? filters,
  }) {
    return teamListRemoteDatasource.loadTeams(
      limit: limit,
      offset: offset,
      search: search,
      filters: filters,
    );
  }

  /// Deletes a team permanently by its [id].
  @override
  Future<void> deleteTeam(int id) {
    return teamListRemoteDatasource.deleteTeam(id);
  }

  /// Archives a team (sets it inactive) by its [id].
  @override
  Future<void> archiveTeam(int id) {
    return teamListRemoteDatasource.archiveTeam(id);
  }

  /// Restores an archived team (sets it active) by its [id].
  @override
  Future<void> unArchiveTeam(int id) {
    return teamListRemoteDatasource.unArchiveTeam(id);
  }
}
