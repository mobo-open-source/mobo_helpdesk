part of 'sla_policy_bloc.dart';

const _noChange = Object();

/// Represents the complete UI state of SLA Policy feature.
///
/// This state manages:
/// - Policy list data & pagination
/// - Search & filters
/// - Group expansion state
/// - CRUD operations feedback
/// - Form data (teams, types, tags, etc.)
class SlaPolicyState extends Equatable {
  final List<SlaPolicyEntity>? data;
  final bool isLoading;
  final bool isSaving;
  final bool isFormLoading;
  final bool isSearchLoading;
  final bool isPaginationLoading;
  final int total;
  final int page;
  final Map<String, bool> groupExpanded;
  final Map<String, String>? error;

  final String? search;
  final List<String> selectedFilters;
  final String? selectedGroupBy;
  final String? selectedDateUnit;
  final Map<String, DateTime> selectedDates;

  final String? message;
  final bool isError;

  final Map<String, dynamic>? selectedPolicy;
  final List<Map<String, dynamic>>? helpdeskTeam;
  final List<Map<String, dynamic>>? types;
  final List<Map<String, dynamic>>? tags;
  final List<Map<String, dynamic>>? customers;
  final List<Map<String, dynamic>>? reachStage;
  final List<Map<String, dynamic>>? excludingStages;

  final Map<String, dynamic>? selectedTeam;
  final List<Map<String, dynamic>>? selectedTypes;
  final List<Map<String, dynamic>>? selectedTags;
  final List<Map<String, dynamic>>? selectedCustomers;
  final Map<String, dynamic>? selectedReachStage;
  final List<Map<String, dynamic>>? selectedExcludingStages;

  const SlaPolicyState({
    this.data,
    this.isLoading = true,
    this.isSaving = false,
    this.isFormLoading = false,
    this.isSearchLoading = false,
    this.isPaginationLoading = false,
    this.total = 0,
    this.page = 0,
    this.error,

    this.search,
    this.selectedFilters = const [],
    this.selectedGroupBy,
    this.selectedDateUnit,
    this.selectedDates = const {},

    this.groupExpanded = const {},

    this.message,
    this.isError = false,

    this.selectedPolicy,
    this.helpdeskTeam,
    this.types,
    this.tags,
    this.customers,
    this.reachStage,
    this.excludingStages,

    this.selectedTeam,
    this.selectedTypes,
    this.selectedTags,
    this.selectedCustomers,
    this.selectedReachStage,
    this.selectedExcludingStages,
  });

  SlaPolicyState copyWith({
    List<SlaPolicyEntity>? data,
    bool? isLoading,
    bool? isSaving,
    bool? isFormLoading,
    bool? isSearchLoading,
    bool? isPaginationLoading,
    int? total,
    int? page,
    Object? error = _noChange,

    String? search,
    List<String>? selectedFilters,
    Object? selectedGroupBy = _noChange,
    String? selectedDateUnit,
    Map<String, DateTime>? selectedDates,

    Map<String, bool>? groupExpanded,

    String? message,
    bool? isError,

    Map<String, dynamic>? selectedPolicy,
    List<Map<String, dynamic>>? helpdeskTeam,
    List<Map<String, dynamic>>? types,
    List<Map<String, dynamic>>? tags,
    List<Map<String, dynamic>>? customers,
    List<Map<String, dynamic>>? reachStage,
    List<Map<String, dynamic>>? excludingStages,

    // Single selections a user can clear: null must mean "none", not "leave
    // as is", so these take the sentinel like [error].
    Object? selectedTeam = _noChange,
    List<Map<String, dynamic>>? selectedTypes,
    List<Map<String, dynamic>>? selectedTags,
    List<Map<String, dynamic>>? selectedCustomers,
    Object? selectedReachStage = _noChange,
    List<Map<String, dynamic>>? selectedExcludingStages,
  }) {
    return SlaPolicyState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isFormLoading: isFormLoading ?? this.isFormLoading,
      isSearchLoading: isSearchLoading ?? this.isSearchLoading,
      isPaginationLoading: isPaginationLoading ?? this.isPaginationLoading,
      total: total ?? this.total,
      page: page ?? this.page,
      error: identical(error, _noChange)
          ? this.error
          : error as Map<String, String>?,

      search: search ?? this.search,
      selectedFilters: selectedFilters ?? this.selectedFilters,
      selectedGroupBy: identical(selectedGroupBy, _noChange)
          ? this.selectedGroupBy
          : selectedGroupBy as String?,
      selectedDateUnit: selectedDateUnit ?? this.selectedDateUnit,
      selectedDates: selectedDates ?? this.selectedDates,

      groupExpanded: groupExpanded ?? this.groupExpanded,

      message: message,
      isError: isError ?? false,

      selectedPolicy: selectedPolicy ?? this.selectedPolicy,
      helpdeskTeam: helpdeskTeam ?? this.helpdeskTeam,
      types: types ?? this.types,
      tags: tags ?? this.tags,
      customers: customers ?? this.customers,
      reachStage: reachStage ?? this.reachStage,
      excludingStages: excludingStages ?? this.excludingStages,

      selectedTeam: identical(selectedTeam, _noChange)
          ? this.selectedTeam
          : selectedTeam as Map<String, dynamic>?,
      selectedTypes: selectedTypes ?? this.selectedTypes,
      selectedTags: selectedTags ?? this.selectedTags,
      selectedCustomers: selectedCustomers ?? this.selectedCustomers,
      selectedReachStage: identical(selectedReachStage, _noChange)
          ? this.selectedReachStage
          : selectedReachStage as Map<String, dynamic>?,
      selectedExcludingStages:
          selectedExcludingStages ?? this.selectedExcludingStages,
    );
  }

  @override
  List<Object?> get props => [
    data,
    isLoading,
    isSaving,
    isFormLoading,
    isSearchLoading,
    isPaginationLoading,
    total,
    page,
    search,
    error,
    selectedFilters,
    selectedGroupBy,
    selectedDateUnit,
    selectedDates,
    groupExpanded,
    message,
    isError,
    selectedTeam,
    selectedTypes,
    selectedCustomers,
    selectedTags,
    selectedReachStage,
    selectedExcludingStages,
  ];
}
