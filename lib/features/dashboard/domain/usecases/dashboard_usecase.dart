import 'package:mobo_helpdesk/features/dashboard/domain/repositories/dashboard_repo.dart';

/// Use case layer for dashboard-related business logic.
///
/// This class acts as an intermediary between the presentation layer
/// (BLoC/UI) and the repository layer.
///
/// It delegates all dashboard operations such as:
/// - Loading dashboard analytics
/// - Updating target configurations
/// - Fetching ratings with filters
/// - Deleting ratings
///
/// This keeps UI decoupled from data sources and repository implementations.
class DashboardUseCase {
  final DashboardRepo dashboardRepo;

  DashboardUseCase(this.dashboardRepo);

  /// Fetches dashboard analytics data.
  ///
  /// Returns a raw map containing dashboard metrics and team data.
  Future<Map<String, dynamic>> loadDashboard() {
    return dashboardRepo.loadDashboard();
  }

  /// Updates a target field for a given team/user.
  ///
  /// Parameters:
  /// - [teamId]: ID of the team (may not be directly used in backend)
  /// - [field]: field name to update
  /// - [value]: new value to assign
  Future<void> updateTarget({
    required int teamId,
    required String field,
    required dynamic value,
  }) {
    return dashboardRepo.updateTarget(
      teamId: teamId,
      field: field,
      value: value,
    );
  }

  /// Loads rating records with optional filters and pagination.
  ///
  /// Supports:
  /// - Search query
  /// - Filters (rating type, date ranges, etc.)
  /// - Grouping and date unit selection
  /// - Custom domain filters
  /// - Pagination via [limit] and [offset]
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
    return dashboardRepo.loadRatings(
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

  /// Deletes a rating by its unique ID.
  ///
  /// Throws an error if deletion fails.
  Future<void> deleteRating(int id) {
    return dashboardRepo.deleteRating(id);
  }
}
