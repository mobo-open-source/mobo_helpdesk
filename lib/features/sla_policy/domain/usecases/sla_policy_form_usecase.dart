import 'package:mobo_helpdesk/features/sla_policy/domain/repositories/sla_policy_form_repo.dart';

/// Use case layer for SLA Policy Form operations.
///
/// This class acts as an intermediary between the presentation layer
/// (Bloc/UI) and the repository layer. It contains business-level
/// operations for managing SLA policy form data such as teams, types,
/// tags, customers, and stage handling.
class SlaPolicyFormUseCase {
  final SlaPolicyFormRepo slaPolicyFormRepo;

  SlaPolicyFormUseCase(this.slaPolicyFormRepo);

  /// Fetch SLA policy details by [id].
  Future<List<Map<String, dynamic>>> loadPolicyData(int id) {
    return slaPolicyFormRepo.loadPolicyData(id);
  }

  /// Fetch all available Helpdesk teams.
  Future<List<Map<String, dynamic>>> loadHelpdeskTeam() {
    return slaPolicyFormRepo.loadHelpdeskTeam();
  }

  /// Fetch available ticket types.
  Future<List<Map<String, dynamic>>> loadTypes() {
    return slaPolicyFormRepo.loadTypes();
  }

  /// Fetch available tags.
  Future<List<Map<String, dynamic>>> loadTags() {
    return slaPolicyFormRepo.loadTags();
  }

  /// Fetch available customers (partners).
  Future<List<Map<String, dynamic>>> loadCustomers() {
    return slaPolicyFormRepo.loadCustomers();
  }

  /// Fetch stages available for a team excluding given stage IDs.
  Future<List<Map<String, dynamic>>> loadReachStages(
    int teamId,
    List excludeStageIds,
  ) {
    return slaPolicyFormRepo.loadReachStages(teamId, excludeStageIds);
  }

  /// Fetch stages excluding a specific stage for a team.
  Future<List<Map<String, dynamic>>> loadExcludingStages(
    int teamId,
    int stageId,
  ) {
    return slaPolicyFormRepo.loadExcludingStages(teamId, stageId);
  }

  /// Create a new SLA policy with the provided [data].
  Future<void> createPolicy(Map<String, dynamic> data) async {
    await slaPolicyFormRepo.createPolicy(data);
  }

  /// Update an existing SLA policy identified by [id] with [data].
  Future<void> updatePolicy(int id, Map<String, dynamic> data) async {
    await slaPolicyFormRepo.updatePolicy(id, data);
  }
}
