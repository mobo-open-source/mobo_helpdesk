import 'package:mobo_helpdesk/features/dashboard/data/datasources/dashboard_remote_datasource.dart';

import '../../domain/repositories/dashboard_repo.dart';

/// Implementation of [DashboardRepo].
///
/// This repository acts as a bridge between the domain layer and
/// the remote data source ([DashboardRemoteDatasource]).
///
/// Responsibilities:
/// - Delegates dashboard-related operations to remote datasource
/// - Keeps domain layer independent from API/SDK implementations
class DashboardRepoImpl implements DashboardRepo {
  final DashboardRemoteDatasource dashboardRemoteDatasource;

  DashboardRepoImpl(this.dashboardRemoteDatasource);

  /// Fetches dashboard summary data including teams and metrics.
  @override
  Future<Map<String, dynamic>> loadDashboard() {
    return dashboardRemoteDatasource.loadDashboard();
  }

  /// Updates a specific target field for a given team/user.
  ///
  /// Parameters:
  /// - [teamId]: ID of the team (currently not used directly in API call)
  /// - [field]: field name to update
  /// - [value]: new value for the field
  @override
  Future<void> updateTarget({
    required int teamId,
    required String field,
    required dynamic value,
  }) async {
    await dashboardRemoteDatasource.updateTarget(teamId, field, value);
  }

  /// Loads paginated ratings with optional filters.
  ///
  /// Supports:
  /// - Search query
  /// - Filter list (e.g. rating type, date filters)
  /// - Custom domain filters (advanced Odoo filtering)
  /// - Pagination via [limit] and [offset]
  @override
  Future<Map<String, dynamic>> loadRatings({
    required int limit,
    required int offset,
    String? search,
    List<String>? filters,
    String? groupBy,
    String? dateUnit,
    Map<String, DateTime>? selectedDates,
    List<dynamic>? customDomain,
  }) {
    return dashboardRemoteDatasource.loadRatings(
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

  /// Deletes a rating by its ID.
  ///
  /// Throws an error if deletion fails.
  @override
  Future<void> deleteRating(int ratingId) {
    return dashboardRemoteDatasource.deleteRating(ratingId);
  }
}
