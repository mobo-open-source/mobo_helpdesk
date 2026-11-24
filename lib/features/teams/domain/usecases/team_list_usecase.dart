import '../repositories/team_list_repo.dart';

/// Use case layer for Team List operations.
///
/// Acts as an intermediary between the presentation layer (Bloc/UI)
/// and the domain repository ([TeamListRepo]).
///
/// This class encapsulates all business logic related to:
/// - Fetching paginated team lists
/// - Searching and filtering teams
/// - Managing team lifecycle actions (archive, unarchive, delete)
class TeamListUseCase {
  final TeamListRepo teamListRepo;

  TeamListUseCase(this.teamListRepo);

  /// Loads a paginated list of teams.
  ///
  /// [limit] defines the number of items per page.
  /// [offset] defines the pagination offset.
  /// [search] filters teams by name or keyword.
  /// [filters] applies additional filter conditions such as archived state.
  ///
  /// Returns a map containing:
  /// - `data`: list of teams
  /// - `total`: total number of teams
  Future<Map<String, dynamic>> loadTeams({
    required int limit,
    required int offset,
    String? search,
    List<String>? filters,
  }) {
    return teamListRepo.loadTeams(
      limit: limit,
      offset: offset,
      search: search,
      filters: filters,
    );
  }

  /// Permanently deletes a team by [id].
  Future<void> deleteTeam(int id) {
    return teamListRepo.deleteTeam(id);
  }

  /// Archives (deactivates) a team by [id].
  Future<void> archiveTeam(int id) {
    return teamListRepo.archiveTeam(id);
  }

  /// Restores an archived team by [id].
  Future<void> unArchiveTeam(int id) {
    return teamListRepo.unArchiveTeam(id);
  }
}
