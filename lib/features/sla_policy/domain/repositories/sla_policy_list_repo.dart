/// Repository contract for SLA Policy list operations.
///
/// This repository defines all actions related to retrieving,
/// filtering, and managing SLA policies such as archive, unarchive,
/// and delete operations.
abstract class SlaPolicyListRepo {
  /// Fetch paginated SLA policies with optional filters and search.
  ///
  /// - [limit]: number of items per page
  /// - [offset]: pagination offset
  /// - [search]: optional search keyword
  /// - [filters]: optional list of filter keys (e.g., archived)
  /// - [groupBy]: grouping parameter (if applicable)
  /// - [dateUnit]: date grouping unit (day, month, year, etc.)
  /// - [selectedDates]: custom date range filters
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
  });

  /// Permanently deletes an SLA policy by its [id].
  Future<void> deletePolicy(int id);

  /// Archives (disables) an SLA policy by its [id].
  Future<void> archivePolicy(int id);

  /// Restores (enables) an archived SLA policy by its [id].
  Future<void> unArchivePolicy(int id);
}
