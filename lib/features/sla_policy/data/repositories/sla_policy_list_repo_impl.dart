import '../../domain/repositories/sla_policy_list_repo.dart';
import '../datasources/sla_policy_list_remote_datasource.dart';

/// Repository implementation for SLA Policy list operations.
///
/// This class acts as a bridge between the domain layer and the remote datasource,
/// delegating all SLA policy list-related operations to
/// [SlaPolicyListRemoteDatasource].
///
/// Responsibilities:
/// - Fetching paginated SLA policy lists with search, filters, and custom domain support
/// - Handling SLA policy deletion
/// - Archiving SLA policies (soft delete)
/// - Unarchiving SLA policies (restore active state)
///
/// Design Role:
/// This repository follows Clean Architecture principles by:
/// - Abstracting API/data source implementation from domain layer
/// - Providing a clean and consistent interface for use cases
/// - Ensuring separation of concerns between data and business logic
///
/// Notes:
/// - Currently acts as a pass-through layer
/// - Can be extended for caching, transformation, or error handling
class SlaPolicyListRepoImpl implements SlaPolicyListRepo {
  final SlaPolicyListRemoteDatasource slaPolicyListRemoteDatasource;

  SlaPolicyListRepoImpl(this.slaPolicyListRemoteDatasource);

  /// Loads paginated SLA policies from the remote datasource.
  ///
  /// Supports:
  /// - Pagination using [limit] and [offset]
  /// - Full-text search via [search]
  /// - Filtering using [filters]
  /// - Advanced filtering using [customDomain]
  /// - Optional grouping and date-based filters
  ///
  /// Parameters:
  /// - [limit]: Number of records per page
  /// - [offset]: Pagination offset
  /// - [search]: Optional search keyword
  /// - [filters]: List of predefined filter keys
  /// - [groupBy]: Field to group results (optional)
  /// - [dateUnit]: Date grouping unit (optional)
  /// - [selectedDates]: Date range filters (optional)
  /// - [customDomain]: Additional Odoo domain filters
  ///
  /// Returns:
  /// - A [Future] containing a map with:
  ///   - `data`: List of SLA policies
  ///   - `total`: Total record count
  @override
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
    return slaPolicyListRemoteDatasource.loadPolicies(
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

  /// Permanently deletes an SLA policy.
  ///
  /// This method removes the SLA policy record from the backend.
  ///
  /// Parameters:
  /// - [id]: ID of the SLA policy to delete
  @override
  Future<void> deletePolicy(int id) {
    return slaPolicyListRemoteDatasource.deletePolicy(id);
  }

  /// Archives an SLA policy (soft delete).
  ///
  /// This sets the policy's `active` field to false, hiding it from active lists
  /// without permanently deleting it.
  ///
  /// Parameters:
  /// - [id]: ID of the SLA policy to archive
  @override
  Future<void> archivePolicy(int id) {
    return slaPolicyListRemoteDatasource.archivePolicy(id);
  }

  /// Restores an archived SLA policy.
  ///
  /// This sets the policy's `active` field to true, making it visible again
  /// in active SLA policy lists.
  ///
  /// Parameters:
  /// - [id]: ID of the SLA policy to restore
  @override
  Future<void> unArchivePolicy(int id) {
    return slaPolicyListRemoteDatasource.unArchivePolicy(id);
  }
}
