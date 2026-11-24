part of 'dashboard_bloc.dart';

/// Base class for all Dashboard events.
///
/// Every event in the Dashboard feature must extend this class.
/// It enables equality comparison using [Equatable].
abstract class DashboardEvent extends Equatable {
  const DashboardEvent();

  @override
  List<Object?> get props => [];
}

/// Resets the entire dashboard state to its initial values.
class DashboardReset extends DashboardEvent {}

/// Triggers loading of dashboard summary data.
///
/// Used on initial screen load or manual refresh.
class DashboardLoad extends DashboardEvent {
  const DashboardLoad();

  @override
  List<Object?> get props => [];
}

/// Refreshes dashboard data.
///
/// Similar to [DashboardLoad] but can be used for pull-to-refresh actions.
class DashboardRefresh extends DashboardEvent {
  const DashboardRefresh();

  @override
  List<Object?> get props => [];
}

/// Updates a specific target value for a team.
///
/// Example:
/// - field: "target_closed_ticket"
/// - value: 50
class UpdateTargetEvent extends DashboardEvent {
  final int teamId;
  final String field;
  final dynamic value;

  const UpdateTargetEvent({
    required this.teamId,
    required this.field,
    required this.value,
  });
}

/// Loads ratings with pagination, filtering, grouping, and date filters.
///
/// Supports:
/// - Pagination via [page]
/// - Optional filters
/// - Grouping (groupBy)
/// - Date unit filtering
/// - Custom domain queries
class RatingsLoad extends DashboardEvent {
  final int page;
  final List<String>? filters;
  final String? groupBy;
  final String? dateUnit;
  final Map<String, DateTime>? selectedDates;
  final bool resetGroupBy;
  final List<dynamic>? customDomain;

  /// Replace the list with the loading skeleton while this page-1 load runs.
  /// For any reload the user should see happen (a filter, clearing it, a
  /// delete).
  final bool showSkeleton;

  const RatingsLoad(
    this.page, {
    this.filters,
    this.groupBy,
    this.dateUnit,
    this.selectedDates,
    this.resetGroupBy = false,
    this.customDomain,
    this.showSkeleton = false,
  });

  @override
  List<Object?> get props => [page, filters, groupBy, dateUnit, showSkeleton];
}

/// Searches ratings using a text query.
///
/// Resets pagination and filters results based on [query].
class RatingSearch extends DashboardEvent {
  final String query;

  const RatingSearch(this.query);

  @override
  List<Object?> get props => [query];
}

/// Clears all applied rating filters and reloads default data.
class RatingClearFilters extends DashboardEvent {
  const RatingClearFilters();
}

/// Toggles expansion state of a grouped rating section.
///
/// Example:
/// - groupName: "High Priority"
class ToggleRatingGroupExpansion extends DashboardEvent {
  final String groupName;

  const ToggleRatingGroupExpansion(this.groupName);

  @override
  List<Object?> get props => [groupName];
}

/// Deletes a rating by its ID.
///
/// After deletion, ratings list is refreshed.
class DeleteRating extends DashboardEvent {
  final int ratingId;

  const DeleteRating(this.ratingId);

  @override
  List<Object> get props => [ratingId];
}

/// Loads a single rating by ID.
///
/// Used when viewing rating details.
class LoadSingleRating extends DashboardEvent {
  final int ratingId;

  const LoadSingleRating(this.ratingId);

  @override
  List<Object> get props => [ratingId];
}

/// Clears any success/error messages in the state.
///
/// Used after showing snackbars or UI notifications.
class ClearRatingMessage extends DashboardEvent {}

/// Expands or collapses every group at once ("Expand All" / "Collapse All").
class ToggleAllRatingGroups extends DashboardEvent {
  final List<String> groupNames;
  final bool expand;

  const ToggleAllRatingGroups(this.groupNames, this.expand);

  @override
  List<Object?> get props => [groupNames, expand];
}
