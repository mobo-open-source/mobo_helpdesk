import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobo_helpdesk/features/dashboard/domain/entities/rating_entity.dart';
import 'package:mobo_helpdesk/features/dashboard/domain/usecases/dashboard_usecase.dart';

import '../../domain/entities/dashboard_entity.dart';

part 'dashboard_event.dart';

part 'dashboard_state.dart';

/// Business Logic Component for Dashboard feature.
///
/// This BLoC manages:
/// - Loading dashboard analytics
/// - Updating team targets
/// - Fetching ratings with filters, pagination, and grouping
/// - Searching and deleting ratings
/// - Handling UI state such as loading, pagination, and group expansion
class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final DashboardUseCase dashboardUseCase;

  DashboardBloc(this.dashboardUseCase) : super(const DashboardState()) {
    on<DashboardReset>((event, emit) {
      emit(DashboardState());
    });
    on<DashboardLoad>(_onDashboardLoad);
    on<UpdateTargetEvent>(_onUpdateTargetValues);
    on<RatingsLoad>(_loadRatings);
    on<DeleteRating>(_loadDeleteRating);
    on<RatingSearch>(_onSearchRating);
    on<RatingClearFilters>(_onClearFilter);
    on<ToggleRatingGroupExpansion>(_onToggleGroupExpansion);
    on<ToggleAllRatingGroups>(_onToggleAllGroups);
  }

  /// Loads dashboard summary data including ticket stats and team metrics.
  ///
  /// Emits:
  /// - [DashboardState.isLoading] while fetching data
  /// - [DashboardState.dashboard] on success
  /// - [DashboardState.error] on failure
  Future<void> _onDashboardLoad(
    DashboardLoad event,
    Emitter<DashboardState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));

    try {
      final result = await dashboardUseCase.loadDashboard();

      final List<DashboardEntity> data = result["data"];

      emit(state.copyWith(isLoading: false, dashboard: data));
    } catch (e) {
      if (e is Map<String, String>) {
        emit(state.copyWith(isLoading: false, error: e));
      } else {
        emit(
          state.copyWith(
            isLoading: false,
            error: {'title': 'Error', 'description': e.toString()},
          ),
        );
      }
    }
  }

  /// Updates a target field for a specific team.
  ///
  /// After successful update, dashboard data is reloaded.
  Future<void> _onUpdateTargetValues(
    UpdateTargetEvent event,
    Emitter<DashboardState> emit,
  ) async {
    try {
      await dashboardUseCase.updateTarget(
        teamId: event.teamId,
        field: event.field,
        value: event.value,
      );

      add(const DashboardLoad());
    } catch (e) {
      if (e is Map<String, String>) {
        emit(state.copyWith(isLoading: false, error: e));
      } else {
        emit(
          state.copyWith(
            isLoading: false,
            error: {'title': 'Error', 'description': e.toString()},
          ),
        );
      }
    }
  }

  /// Loads ratings with pagination, filtering, grouping, and date filters.
  ///
  /// Supports:
  /// - Pagination via [event.page]
  /// - Search and filter combinations
  /// - Grouping and date-based filtering
  /// - Custom domain filters
  Future<void> _loadRatings(
    RatingsLoad event,
    Emitter<DashboardState> emit,
  ) async {
    const limit = 40;
    final offset = (event.page - 1) * limit;

    final filters = event.filters ?? state.selectedFilters;
    String? groupBy;
    if (event.resetGroupBy == true) {
      groupBy = null;
    } else {
      groupBy = event.groupBy;
    }

    final dateUnit = event.dateUnit ?? state.selectedDateUnit;
    final selectedDates = event.selectedDates ?? state.selectedDates;

    if (event.page == 1 && (state.page == 0 || event.showSkeleton)) {
      // The header shows the new filters and grouping while the skeleton runs.
      emit(
        state.copyWith(
          isLoading: true,
          selectedFilters: filters,
          selectedGroupBy: groupBy,
        ),
      );
    } else {
      emit(state.copyWith(isPaginationLoading: true));
    }

    try {
      final startTime = DateTime.now();

      final response = await dashboardUseCase.loadRatings(
        limit: limit,
        offset: offset,
        filters: filters,
        groupBy: groupBy,
        dateUnit: dateUnit,
        selectedDates: selectedDates,
        search: state.search,
        customDomain: event.customDomain,
      );

      final List<RatingEntity> ratings = response['data'];
      final int total = response['total'];
      final elapsed = DateTime.now().difference(startTime);
      if (elapsed.inMilliseconds < 500) {
        await Future.delayed(
          Duration(milliseconds: 500 - elapsed.inMilliseconds),
        );
      }
      emit(
        state.copyWith(
          isLoading: false,
          isPaginationLoading: false,
          ratingData: ratings,
          total: total,
          page: event.page,
          selectedFilters: filters,
          selectedGroupBy: groupBy,
          selectedDateUnit: dateUnit,
          selectedDates: selectedDates,
          groupExpanded: groupBy == null ? {} : state.groupExpanded,
        ),
      );
    } catch (e) {
      if (e is Map<String, String>) {
        emit(state.copyWith(isLoading: false, error: e));
      } else {
        emit(
          state.copyWith(
            isLoading: false,
            error: {'title': 'Error', 'description': e.toString()},
          ),
        );
      }
    }
  }

  /// Deletes a rating and refreshes the ratings list.
  Future<void> _loadDeleteRating(
    DeleteRating event,
    Emitter<DashboardState> emit,
  ) async {
    try {
      await dashboardUseCase.deleteRating(event.ratingId);
      add(
        const RatingsLoad(
          1,
          filters: [],
          groupBy: null,
          dateUnit: null,
          selectedDates: {},
          showSkeleton: true,
        ),
      );
      emit(
        state.copyWith(message: "Rating deleted successfully", isError: false),
      );
    } catch (e) {
      final msg = e.toString().replaceFirst("Exception: ", "");

      emit(
        state.copyWith(
          message: msg.isNotEmpty ? msg : "Failed to delete rating",
          isError: true,
        ),
      );
    }
  }

  /// Searches ratings based on user query.
  ///
  /// Resets pagination and returns filtered results.
  Future<void> _onSearchRating(
    RatingSearch event,
    Emitter<DashboardState> emit,
  ) async {
    const limit = 40;

    emit(state.copyWith(isSearchLoading: true));

    try {
      final startTime = DateTime.now();

      final response = await dashboardUseCase.loadRatings(
        limit: limit,
        offset: 0,
        search: event.query,
        filters: state.selectedFilters,
        selectedDates: state.selectedDates,
      );
      final List<RatingEntity> ratings = response['data'];
      final int total = response['total'];

      final elapsed = DateTime.now().difference(startTime);
      if (elapsed.inMilliseconds < 500) {
        await Future.delayed(
          Duration(milliseconds: 500 - elapsed.inMilliseconds),
        );
      }
      emit(
        state.copyWith(
          isSearchLoading: false,
          ratingData: ratings,
          total: total,
          page: 1,
          search: event.query,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false));
    }
  }

  /// Clears all filters and reloads ratings from page 1.
  Future<void> _onClearFilter(
    RatingClearFilters event,
    Emitter<DashboardState> emit,
  ) async {
    // The search goes with the filters, so the list shows everything again,
    // matching the screen's emptied search box.
    emit(state.copyWith(search: ''));
    add(
      RatingsLoad(
        1,
        filters: [],
        groupBy: null,
        dateUnit: null,
        selectedDates: {},
        showSkeleton: true,
      ),
    );
  }

  /// Toggles expansion state for grouped rating sections.
  void _onToggleAllGroups(
    ToggleAllRatingGroups event,
    Emitter<DashboardState> emit,
  ) {
    emit(
      state.copyWith(
        groupExpanded: {for (final n in event.groupNames) n: event.expand},
      ),
    );
  }

  void _onToggleGroupExpansion(
    ToggleRatingGroupExpansion event,
    Emitter<DashboardState> emit,
  ) {
    final current = state;
    final updated = Map<String, bool>.from(current.groupExpanded);
    final currentValue = updated[event.groupName] ?? true;
    updated[event.groupName] = !currentValue;

    emit(current.copyWith(groupExpanded: updated));
  }
}
