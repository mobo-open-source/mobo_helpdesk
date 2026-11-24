/// Repository contract for Team List operations.
///
/// Defines all domain-level actions required for retrieving and managing
/// teams in list view, including pagination, search, filtering, and
/// lifecycle actions such as archive and delete.
///
/// This abstraction ensures the domain layer remains independent of
/// any specific data source implementation (e.g., Odoo RPC, REST API).
abstract class TeamListRepo {
  /// Loads a paginated list of teams.
  ///
  /// [limit] defines the number of items per request.
  /// [offset] defines the pagination offset.
  /// [search] filters teams by name or keyword.
  /// [filters] applies additional filter conditions (e.g., archived teams).
  ///
  /// Returns a map containing:
  /// - `data`: list of teams
  /// - `total`: total number of records
  Future<Map<String, dynamic>> loadTeams({
    required int limit,
    required int offset,
    String? search,
    List<String>? filters,
  });

  /// Permanently deletes a team by [id].
  Future<void> deleteTeam(int id);

  /// Archives (deactivates) a team by [id].
  Future<void> archiveTeam(int id);

  /// Restores (reactivates) an archived team by [id].
  Future<void> unArchiveTeam(int id);
}
