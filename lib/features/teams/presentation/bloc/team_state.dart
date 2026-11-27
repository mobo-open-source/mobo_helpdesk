part of 'team_bloc.dart';

const _noChange = Object();

/// Represents the complete UI state for TeamBloc.
///
/// Holds:
/// - Team list data and pagination info
/// - Loading and error states
/// - Search and filter state
/// - Group expansion state for UI
/// - Team form (create/edit) related data
/// - Selected relational fields (members, partners, projects, etc.)
/// - Module installation flags (website/project)
///
/// This state is immutable and updated via [copyWith].
class TeamState extends Equatable {
  final List<TeamEntity>? data;

  final bool isLoading;
  final bool isFormLoading;
  final bool isSaving;

  /// What the blocking screen says while [isSaving], when more than "Saving":
  /// installing apps, or waiting for another installation. Empty means the
  /// usual text.
  final String savingMessage;
  final String savingHint;

  final bool isModuleInstallLoading;

  final bool isSearchLoading;
  final bool isPaginationLoading;
  final int total;
  final int page;
  final Map<String, bool> groupExpanded;
  final Map<String, String>? error;

  final String? search;
  final List<String> selectedFilters;

  final String? message;
  final bool isError;

  /// A save that ended in an error all the same left its changes on the server
  /// (Odoo saves the team, then installs its apps, and the install failed). The
  /// screen then shows the team as saved instead of letting the user send the
  /// same thing again.
  final bool serverSaved;

  final Map<String, dynamic>? selectedTeam;
  final List<Map<String, dynamic>>? members;
  final List<Map<String, dynamic>>? partners;
  final List<Map<String, dynamic>>? website;
  final List<Map<String, dynamic>>? resources;
  final List<Map<String, dynamic>>? stages;
  final List<Map<String, dynamic>>? projects;
  final List<Map<String, dynamic>>? aliasDomains;

  final String? selectedVisibility;
  final List<Map<String, dynamic>>? selectedPartners;
  final List<Map<String, dynamic>>? selectedMembers;
  final Map<String, dynamic>? selectedWebsite;
  final Map<String, dynamic>? selectedProject;
  final Map<String, dynamic>? selectedResource;
  final Map<String, dynamic>? selectedStage;
  final String? selectedAssignment;
  final Map<String, dynamic>? selectedAlias;
  final String? selectedAliasFrom;
  final List<Map<String, dynamic>>? selectedInStages;

  final bool isWebsiteInstalled;
  final bool isProjectInstalled;

  const TeamState({
    this.data,

    this.isLoading = true,
    this.isFormLoading = false,
    this.isSaving = false,
    this.savingMessage = '',
    this.savingHint = '',
    this.isModuleInstallLoading = false,

    this.isSearchLoading = false,
    this.isPaginationLoading = false,
    this.total = 0,
    this.page = 0,

    this.search,
    this.selectedFilters = const [],
    this.error,

    this.groupExpanded = const {},

    this.message,
    this.isError = false,
    this.serverSaved = false,

    this.selectedTeam,
    this.members,
    this.partners,
    this.website,
    this.resources,
    this.stages,
    this.projects,
    this.aliasDomains,

    this.selectedVisibility,
    this.selectedPartners,
    this.selectedMembers,
    this.selectedWebsite,
    this.selectedProject,
    this.selectedResource,
    this.selectedStage,
    this.selectedAssignment,
    this.selectedAlias,
    this.selectedAliasFrom,
    this.selectedInStages,

    this.isWebsiteInstalled = false,
    this.isProjectInstalled = false,
  });

  TeamState copyWith({
    List<TeamEntity>? data,
    bool? isLoading,
    bool? isFormLoading,
    bool? isSaving,
    String? savingMessage,
    String? savingHint,
    bool? isModuleInstallLoading,
    bool? isSearchLoading,
    bool? isPaginationLoading,
    int? total,
    int? page,

    String? search,
    List<String>? selectedFilters,
    Object? error = _noChange,

    Map<String, bool>? groupExpanded,

    String? message,
    bool? isError,
    bool? serverSaved,

    Map<String, dynamic>? selectedTeam,
    List<Map<String, dynamic>>? members,
    List<Map<String, dynamic>>? partners,
    List<Map<String, dynamic>>? website,
    List<Map<String, dynamic>>? resources,
    List<Map<String, dynamic>>? stages,
    List<Map<String, dynamic>>? projects,
    List<Map<String, dynamic>>? aliasDomains,

    String? selectedVisibility,
    List<Map<String, dynamic>>? selectedPartners,
    List<Map<String, dynamic>>? selectedMembers,
    // Single selections a user can clear: null must mean "none", not "leave
    // as is", so these take the sentinel like [error].
    Object? selectedWebsite = _noChange,
    Object? selectedProject = _noChange,
    Object? selectedResource = _noChange,
    Object? selectedStage = _noChange,
    String? selectedAssignment,
    Object? selectedAlias = _noChange,
    String? selectedAliasFrom,
    List<Map<String, dynamic>>? selectedInStages,

    bool? isWebsiteInstalled,
    bool? isProjectInstalled,
  }) {
    return TeamState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      isFormLoading: isFormLoading ?? this.isFormLoading,
      isSaving: isSaving ?? this.isSaving,
      savingMessage: savingMessage ?? this.savingMessage,
      savingHint: savingHint ?? this.savingHint,
      isModuleInstallLoading:
          isModuleInstallLoading ?? this.isModuleInstallLoading,
      isSearchLoading: isSearchLoading ?? this.isSearchLoading,
      isPaginationLoading: isPaginationLoading ?? this.isPaginationLoading,
      total: total ?? this.total,
      page: page ?? this.page,

      search: search ?? this.search,
      selectedFilters: selectedFilters ?? this.selectedFilters,

      groupExpanded: groupExpanded ?? this.groupExpanded,

      message: message,
      isError: isError ?? false,
      serverSaved: serverSaved ?? false,
      error: identical(error, _noChange)
          ? this.error
          : error as Map<String, String>?,

      selectedTeam: selectedTeam ?? this.selectedTeam,
      members: members ?? this.members,
      partners: partners ?? this.partners,
      website: website ?? this.website,
      resources: resources ?? this.resources,
      stages: stages ?? this.stages,
      projects: projects ?? this.projects,
      aliasDomains: aliasDomains ?? this.aliasDomains,

      selectedVisibility: selectedVisibility ?? this.selectedVisibility,
      selectedPartners: selectedPartners ?? this.selectedPartners,
      selectedMembers: selectedMembers ?? this.selectedMembers,
      selectedWebsite: identical(selectedWebsite, _noChange)
          ? this.selectedWebsite
          : selectedWebsite as Map<String, dynamic>?,
      selectedProject: identical(selectedProject, _noChange)
          ? this.selectedProject
          : selectedProject as Map<String, dynamic>?,
      selectedResource: identical(selectedResource, _noChange)
          ? this.selectedResource
          : selectedResource as Map<String, dynamic>?,
      selectedStage: identical(selectedStage, _noChange)
          ? this.selectedStage
          : selectedStage as Map<String, dynamic>?,
      selectedAssignment: selectedAssignment ?? this.selectedAssignment,
      selectedAlias: identical(selectedAlias, _noChange)
          ? this.selectedAlias
          : selectedAlias as Map<String, dynamic>?,
      selectedAliasFrom: selectedAliasFrom ?? this.selectedAliasFrom,
      selectedInStages: selectedInStages ?? this.selectedInStages,

      isWebsiteInstalled: isWebsiteInstalled ?? this.isWebsiteInstalled,
      isProjectInstalled: isProjectInstalled ?? this.isProjectInstalled,
    );
  }

  @override
  List<Object?> get props => [
    data,
    isLoading,
    isFormLoading,
    isSaving,
    savingMessage,
    savingHint,
    isModuleInstallLoading,
    isSearchLoading,
    isPaginationLoading,
    total,
    page,
    search,
    selectedFilters,
    groupExpanded,
    message,
    isError,
    serverSaved,

    selectedVisibility,
    selectedPartners,
    selectedMembers,
    selectedWebsite,
    selectedProject,
    selectedResource,
    selectedStage,
    selectedAssignment,
    selectedAlias,
    selectedAliasFrom,
    selectedInStages,

    isWebsiteInstalled,
    isProjectInstalled,
  ];
}
