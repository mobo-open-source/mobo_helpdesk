import '../repositories/sla_policy_list_repo.dart';

/// Use case layer for SLA Policy list operations.
///
/// This class acts as a bridge between the presentation layer (Bloc/UI)
/// and the repository layer. It provides business-level access to SLA
/// policy list operations such as fetching, deleting, archiving,
/// and unarchiving policies.
class SlaPolicyListUseCase {
  final SlaPolicyListRepo slaPolicyListRepo;

  SlaPolicyListUseCase(this.slaPolicyListRepo);

  /// Fetch paginated SLA policies with optional filters and search.
  ///
  /// - [limit]: number of records per page
  /// - [offset]: pagination offset
  /// - [search]: optional search keyword
  /// - [filters]: optional filter keys (e.g., archived)
  /// - [groupBy]: grouping option
  /// - [dateUnit]: date grouping unit
  /// - [selectedDates]: optional date range filters
  /// - [customDomain]: additional backend domain filters
  Future<Map<String, dynamic>> loadPolicies({
    required int limit,
    required int offset,
    String? search,
    List<String>? filters,
    String? groupBy,
    String? dateUnit,
    Map<String, DateTime>? selectedDates,

    List<dynamic>? customDomain,
  }) {
    return slaPolicyListRepo.loadPolicies(
      limit: limit,
      offset: offset,
      search: search,
      filters: filters,
      groupBy: groupBy,
      dateUnit: dateUnit,
      selectedDates: selectedDates,
      customDomain: customDomain,
    );
  }

  /// Delete an SLA policy permanently by [id].
  Future<void> deletePolicy(int id) {
    return slaPolicyListRepo.deletePolicy(id);
  }

  /// Archive (disable) an SLA policy by [id].
  Future<void> archivePolicy(int id) {
    return slaPolicyListRepo.archivePolicy(id);
  }

  /// Restore (enable) an archived SLA policy by [id].
  Future<void> unArchivePolicy(int id) {
    return slaPolicyListRepo.unArchivePolicy(id);
  }
}
