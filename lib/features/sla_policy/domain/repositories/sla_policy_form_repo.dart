/// Repository contract for SLA Policy Form operations.
///
/// This repository defines all required operations for creating,
/// updating, and fetching SLA policy related form data such as:
/// teams, types, tags, customers, and stages.
abstract class SlaPolicyFormRepo {
  /// Fetch detailed SLA policy data by its [id].
  Future<List<Map<String, dynamic>>> loadPolicyData(int id);

  /// Load available Helpdesk teams.
  Future<List<Map<String, dynamic>>> loadHelpdeskTeam();

  /// Load available ticket types.
  Future<List<Map<String, dynamic>>> loadTypes();

  /// Load available tags.
  Future<List<Map<String, dynamic>>> loadTags();

  /// Load available customers (partners).
  Future<List<Map<String, dynamic>>> loadCustomers();

  /// Load stages that can be reached for a given team,
  /// excluding the provided [excludeStageIds].
  Future<List<Map<String, dynamic>>> loadReachStages(
    int teamId,
    List excludeStageIds,
  );

  /// Load stages excluding a specific [stageId] for a team.
  Future<List<Map<String, dynamic>>> loadExcludingStages(
    int teamId,
    int stageId,
  );

  /// Create a new SLA policy using [data].
  Future<void> createPolicy(Map<String, dynamic> data);

  /// Update an existing SLA policy identified by [id] using [data].
  Future<void> updatePolicy(int id, Map<String, dynamic> data);
}
