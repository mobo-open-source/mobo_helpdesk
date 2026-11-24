part of 'dashboard_bloc.dart';

/// Internal sentinel value used to detect "no change" in copyWith.
///
/// This allows distinguishing between:
/// - `null` → explicitly set null
/// - `_noChange` → keep previous value
const _noChange = Object();

/// Represents the complete UI state of the Dashboard feature.
///
/// This state includes:
/// - Dashboard summary data
/// - Ratings list with pagination & filtering
/// - Loading and error states
/// - UI interaction states (search, group expansion, etc.)
class DashboardState extends Equatable {
  final List<DashboardEntity>? dashboard;
  final List<RatingEntity>? ratingData;
  final bool isLoading;
  final Map<String, String>? error;

  final bool isSearchLoading;
  final bool isPaginationLoading;
  final List<String> selectedFilters;

  final int total;
  final int page;
  final String? search;

  final Map<String, bool> groupExpanded;

  final String? selectedGroupBy;
  final String? selectedDateUnit;
  final Map<String, DateTime> selectedDates;

  final String? message;
  final bool isError;

  final Map<String, dynamic>? selectedRating;

  const DashboardState({
    this.dashboard,
    this.ratingData,
    this.isLoading = true,
    this.error,

    this.isSearchLoading = false,
    this.isPaginationLoading = false,
    this.total = 0,
    this.page = 0,

    this.search,
    this.selectedFilters = const [],
    this.selectedGroupBy,
    this.selectedDateUnit,
    this.selectedDates = const {},

    this.groupExpanded = const {},

    this.message,
    this.isError = false,

    this.selectedRating,
  });

  DashboardState copyWith({
    List<DashboardEntity>? dashboard,
    List<RatingEntity>? ratingData,
    bool? isLoading,
    Map<String, String>? error,

    bool? isSearchLoading,
    List<String>? selectedFilters,

    bool? isPaginationLoading,

    int? total,
    int? page,

    String? search,

    Object? selectedGroupBy = _noChange,
    String? selectedDateUnit,
    Map<String, DateTime>? selectedDates,

    Map<String, bool>? groupExpanded,

    String? message,
    bool? isError,

    Map<String, dynamic>? selectedRating,
  }) {
    return DashboardState(
      dashboard: dashboard ?? this.dashboard,
      ratingData: ratingData ?? this.ratingData,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isSearchLoading: isSearchLoading ?? this.isSearchLoading,
      selectedFilters: selectedFilters ?? this.selectedFilters,

      isPaginationLoading: isPaginationLoading ?? this.isPaginationLoading,
      total: total ?? this.total,
      page: page ?? this.page,

      search: search ?? this.search,
      selectedGroupBy: identical(selectedGroupBy, _noChange)
          ? this.selectedGroupBy
          : selectedGroupBy as String?,
      selectedDateUnit: selectedDateUnit ?? this.selectedDateUnit,
      selectedDates: selectedDates ?? this.selectedDates,

      groupExpanded: groupExpanded ?? this.groupExpanded,

      message: message,
      isError: isError ?? false,

      selectedRating: selectedRating ?? this.selectedRating,
    );
  }

  @override
  List<Object?> get props => [
    dashboard,
    ratingData,
    isLoading,
    isSearchLoading,
    isPaginationLoading,
    total,
    page,
    search,
    selectedFilters,
    selectedGroupBy,
    selectedDateUnit,
    selectedDates,
    groupExpanded,
    message,
    isError,
    error,
  ];
}
