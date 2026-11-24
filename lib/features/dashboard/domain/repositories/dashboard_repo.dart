/// Abstract repository contract for dashboard-related operations.
///
/// This repository defines all available dashboard use cases such as:
/// - Fetching dashboard analytics data
/// - Updating team/user target configurations
/// - Loading ratings with filtering and pagination
/// - Deleting rating records
///
/// The implementation of this repository may come from remote APIs,
/// local storage, or a combination of both.
abstract class DashboardRepo {
  /// Loads dashboard analytics data including ticket statistics,
  /// SLA metrics, ratings, and team summaries.
  ///
  /// Returns a raw response map containing dashboard data.
  Future<Map<String, dynamic>> loadDashboard();

  /// Updates a target field for a specific team or user.
  ///
  /// Parameters:
  /// - [teamId]: ID of the team (may not be used directly in backend call)
  /// - [field]: field name to update
  /// - [value]: new value to assign
  Future<void> updateTarget({
    required int teamId,
    required String field,
    required dynamic value,
  });

  /// Loads paginated rating records with optional filters.
  ///
  /// Supports:
  /// - Search query
  /// - Filtering (status, date ranges, etc.)
  /// - Custom domain filters (advanced query conditions)
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
  });

  /// Deletes a rating record by its unique ID.
  ///
  /// Throws an exception if deletion fails.
  Future<void> deleteRating(int ratingId);
}
