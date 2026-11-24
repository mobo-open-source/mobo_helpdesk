import '../../domain/repositories/sla_policy_form_repo.dart';
import '../datasources/sla_policy_form_remote_datasource.dart';

/// Repository implementation for SLA Policy Form operations.
///
/// This class acts as a bridge between the domain layer and the remote datasource,
/// delegating all SLA policy form-related operations to
/// [SlaPolicyFormRemoteDatasource].
///
/// Responsibilities:
/// - Fetching SLA policy details by ID
/// - Loading supporting data for form population (teams, types, tags, customers)
/// - Fetching stage data for SLA configuration
/// - Creating new SLA policies
/// - Updating existing SLA policies
///
/// Design Role:
/// This repository follows Clean Architecture principles by:
/// - Abstracting data source implementation details from the domain layer
/// - Providing a clean API for use cases
/// - Keeping business logic outside of data layer
///
/// Note:
/// This implementation currently acts as a pass-through layer.
/// Future enhancements may include:
/// - Caching
/// - Data transformation
/// - Offline support
class SlaPolicyFormRepoImpl implements SlaPolicyFormRepo {
  final SlaPolicyFormRemoteDatasource slaPolicyFormRemoteDatasource;

  SlaPolicyFormRepoImpl(this.slaPolicyFormRemoteDatasource);

  @override
  Future<List<Map<String, dynamic>>> loadPolicyData(int id) {
    return slaPolicyFormRemoteDatasource.loadPolicyData(id);
  }

  @override
  Future<List<Map<String, dynamic>>> loadHelpdeskTeam() {
    return slaPolicyFormRemoteDatasource.loadHelpdeskTeam();
  }

  @override
  Future<List<Map<String, dynamic>>> loadTypes() {
    return slaPolicyFormRemoteDatasource.loadTypes();
  }

  @override
  Future<List<Map<String, dynamic>>> loadTags() {
    return slaPolicyFormRemoteDatasource.loadTags();
  }

  @override
  Future<List<Map<String, dynamic>>> loadCustomers() {
    return slaPolicyFormRemoteDatasource.loadCustomers();
  }

  @override
  Future<List<Map<String, dynamic>>> loadReachStages(
    int teamId,
    List excludeStageIds,
  ) {
    return slaPolicyFormRemoteDatasource.loadReachStages(
      teamId,
      excludeStageIds,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> loadExcludingStages(
    int teamId,
    int stageId,
  ) {
    return slaPolicyFormRemoteDatasource.loadExcludingStages(teamId, stageId);
  }

  @override
  Future<void> createPolicy(Map<String, dynamic> data) {
    return slaPolicyFormRemoteDatasource.createPolicy(data);
  }

  @override
  Future<void> updatePolicy(int id, Map<String, dynamic> data) {
    return slaPolicyFormRemoteDatasource.updatePolicy(id, data);
  }
}
