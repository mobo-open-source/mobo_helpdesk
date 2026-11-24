part of 'ticket_bloc.dart';

const _noChange = Object();

/// Represents the complete UI and business state of the Ticket module.
///
/// This state is managed by [TicketBloc] and includes:
/// - Ticket list data and pagination info
/// - Loading states (initial, search, pagination)
/// - Filters, grouping, and date selection
/// - Ticket form data (teams, users, tags, etc.)
/// - Selected ticket and editing state
/// - Templates and stage-related data
/// - UI messages and error handling
class TicketState extends Equatable {
  final List<TicketEntity>? data;
  final bool isLoading;
  final bool isSaving;
  final bool isCreateDataLoading;
  final bool isScheduleLoading;
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

  final List<Map<String, dynamic>> emailTemplates;
  final List<Map<String, dynamic>> smsTemplates;

  final Map<String, dynamic>? selectedEmailTemplate;
  final Map<String, dynamic>? selectedSmsTemplate;
  final int? selectedSequence;

  final Map<String, dynamic>? selectedTicket;
  final List<Map<String, dynamic>>? helpdeskTeam;
  final List<Map<String, dynamic>>? users;
  final List<Map<String, dynamic>>? activityTypes;
  final List<Map<String, dynamic>>? types;
  final List<Map<String, dynamic>>? tags;
  final List<Map<String, dynamic>>? partners;
  final List<Map<String, dynamic>>? stages;
  final List<Map<String, dynamic>>? salesTeam;

  final Map<String, dynamic>? selectedTeam;
  final Map<String, dynamic>? selectedUser;
  final Map<String, dynamic>? selectedType;
  final Map<String, dynamic>? selectedPartner;
  final List<Map<String, dynamic>>? selectedTags;
  final Map<String, dynamic>? selectedStage;
  final Map<String, dynamic>? defaultStage;

  final String? selectedOpportunityCustomer;
  final Map<String, dynamic>? selectedOpportunityPartner;
  final Map<String, dynamic>? selectedOpportunityTeam;
  final Map<String, dynamic>? selectedOpportunitySalesPerson;

  const TicketState({
    this.data,
    this.isLoading = true,
    this.isSaving = false,
    this.isCreateDataLoading = false,
    this.isScheduleLoading = false,
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

    this.emailTemplates = const [],
    this.smsTemplates = const [],
    this.selectedEmailTemplate,
    this.selectedSmsTemplate,
    this.selectedSequence,

    this.selectedTicket,
    this.helpdeskTeam,
    this.users,
    this.activityTypes,
    this.types,
    this.tags,
    this.partners,
    this.stages,
    this.salesTeam,

    this.selectedTeam,
    this.selectedUser,
    this.selectedType,
    this.selectedPartner,
    this.selectedTags,
    this.selectedStage,
    this.defaultStage,

    this.selectedOpportunityCustomer = "exist",
    this.selectedOpportunityPartner,
    this.selectedOpportunityTeam,
    this.selectedOpportunitySalesPerson,
  });

  TicketState copyWith({
    List<TicketEntity>? data,
    bool? isLoading,
    bool? isSaving,
    bool? isCreateDataLoading,
    bool? isScheduleLoading,
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

    List<Map<String, dynamic>>? emailTemplates,
    List<Map<String, dynamic>>? smsTemplates,
    Map<String, dynamic>? selectedEmailTemplate,
    Map<String, dynamic>? selectedSmsTemplate,
    int? selectedSequence,

    Object? selectedTicket = _noChange,
    List<Map<String, dynamic>>? helpdeskTeam,
    List<Map<String, dynamic>>? users,
    List<Map<String, dynamic>>? activityTypes,
    List<Map<String, dynamic>>? types,
    List<Map<String, dynamic>>? tags,
    List<Map<String, dynamic>>? partners,
    List<Map<String, dynamic>>? stages,
    List<Map<String, dynamic>>? salesTeam,

    // The form's selections: passing null clears one (a dropdown's clear
    // button, or a ticket that has no value for it), omitting it keeps it.
    Object? selectedTeam = _noChange,
    Object? selectedUser = _noChange,
    Object? selectedType = _noChange,
    Object? selectedPartner = _noChange,
    Object? selectedTags = _noChange,
    Object? selectedStage = _noChange,
    Map<String, dynamic>? defaultStage,

    String? selectedOpportunityCustomer,
    Object? selectedOpportunityPartner = _noChange,
    Object? selectedOpportunityTeam = _noChange,
    Object? selectedOpportunitySalesPerson = _noChange,
  }) {
    return TicketState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isCreateDataLoading: isCreateDataLoading ?? this.isCreateDataLoading,
      isScheduleLoading: isScheduleLoading ?? this.isScheduleLoading,
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

      emailTemplates: emailTemplates ?? this.emailTemplates,
      smsTemplates: smsTemplates ?? this.smsTemplates,
      selectedEmailTemplate:
          selectedEmailTemplate ?? this.selectedEmailTemplate,
      selectedSmsTemplate: selectedSmsTemplate ?? this.selectedSmsTemplate,
      selectedSequence: selectedSequence ?? this.selectedSequence,

      selectedTicket: identical(selectedTicket, _noChange)
          ? this.selectedTicket
          : selectedTicket as Map<String, dynamic>?,
      helpdeskTeam: helpdeskTeam ?? this.helpdeskTeam,
      users: users ?? this.users,
      activityTypes: activityTypes ?? this.activityTypes,
      types: types ?? this.types,
      tags: tags ?? this.tags,
      partners: partners ?? this.partners,
      stages: stages ?? this.stages,
      salesTeam: salesTeam ?? this.salesTeam,

      selectedTeam: identical(selectedTeam, _noChange)
          ? this.selectedTeam
          : selectedTeam as Map<String, dynamic>?,
      selectedUser: identical(selectedUser, _noChange)
          ? this.selectedUser
          : selectedUser as Map<String, dynamic>?,
      selectedType: identical(selectedType, _noChange)
          ? this.selectedType
          : selectedType as Map<String, dynamic>?,
      selectedPartner: identical(selectedPartner, _noChange)
          ? this.selectedPartner
          : selectedPartner as Map<String, dynamic>?,
      selectedTags: identical(selectedTags, _noChange)
          ? this.selectedTags
          : selectedTags as List<Map<String, dynamic>>?,
      selectedStage: identical(selectedStage, _noChange)
          ? this.selectedStage
          : selectedStage as Map<String, dynamic>?,
      defaultStage: defaultStage ?? this.defaultStage,

      selectedOpportunityCustomer:
          selectedOpportunityCustomer ?? this.selectedOpportunityCustomer,
      selectedOpportunityPartner: identical(selectedOpportunityPartner, _noChange)
          ? this.selectedOpportunityPartner
          : selectedOpportunityPartner as Map<String, dynamic>?,
      selectedOpportunityTeam: identical(selectedOpportunityTeam, _noChange)
          ? this.selectedOpportunityTeam
          : selectedOpportunityTeam as Map<String, dynamic>?,
      selectedOpportunitySalesPerson:
          identical(selectedOpportunitySalesPerson, _noChange)
          ? this.selectedOpportunitySalesPerson
          : selectedOpportunitySalesPerson as Map<String, dynamic>?,
    );
  }

  @override
  List<Object?> get props => [
    data,
    isLoading,
    isSaving,
    isCreateDataLoading,
    isScheduleLoading,
    isSearchLoading,
    isPaginationLoading,
    total,
    page,
    error,
    search,
    selectedFilters,
    selectedGroupBy,
    selectedDateUnit,
    selectedDates,
    groupExpanded,
    message,
    isError,
    selectedTeam,
    selectedUser,
    selectedType,
    selectedPartner,
    selectedTags,
    selectedStage,

    selectedOpportunityCustomer,
    selectedOpportunityPartner,
    selectedOpportunityTeam,
    selectedOpportunitySalesPerson,
  ];
}
