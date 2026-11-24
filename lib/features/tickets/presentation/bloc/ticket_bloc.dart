import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobo_helpdesk/features/tickets/domain/entities/ticket_entity.dart';
import 'package:mobo_helpdesk/features/tickets/domain/usecases/ticket_form_usecase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/utils/safe_utils.dart';
import '../../../rating/domain/usecases/review_usecase.dart';
import '../../domain/usecases/ticket_list_usecase.dart';

part 'ticket_event.dart';

part 'ticket_state.dart';

/// Business Logic Component (BLoC) for managing Tickets.
///
/// Handles:
/// - Ticket listing with pagination, search, filtering, grouping
/// - Ticket CRUD operations (create, update, delete)
/// - Ticket status actions (archive / unarchive)
/// - Stage updates and templates
/// - Loading ticket form data for create/edit screens
///
/// Acts as the central state manager between UI and domain layer
/// using Clean Architecture (UseCases + Repository pattern).
class TicketBloc extends Bloc<TicketEvent, TicketState> {
  final TicketListUseCase ticketListUseCase;
  final TicketFormUseCase ticketFormUseCase;
  final TrackEvent trackEvent;

  TicketBloc(this.ticketListUseCase, this.ticketFormUseCase, this.trackEvent)
    : super(TicketState()) {
    on<TicketsLoad>(_loadTickets);
    on<TicketsSearch>(_onSearchTickets);
    on<TicketsClearFilters>(_onClearFilter);
    on<ToggleGroupExpansion>(_onToggleGroupExpansion);
    on<ToggleAllGroups>(_onToggleAllGroups);
    on<DeleteTicket>(_onDeleteTicket);
    on<DeleteStage>(_onDeleteStage);
    on<ArchiveTicket>(_onArchiveTicket);
    on<UnArchiveTicket>(_onUnArchiveTicket);
    on<UpdateStage>(_onUpdateStage);
    on<ReorderTicketInStage>(_onReorderTicketInStage);
    on<MoveTicketToStage>(_onMoveTicketToStage);
    on<LoadStageTemplates>(_onLoadStageTemplates);

    on<LoadSingleTicket>(_onLoadSingleTicket);
    on<LoadTicketCreateData>(_onLoadCreateDataItems);

    on<UpdateSelectedTeam>((event, emit) {
      emit(state.copyWith(selectedTeam: event.team));
    });
    on<UpdateSelectedUser>((event, emit) {
      emit(state.copyWith(selectedUser: event.user));
    });
    on<UpdateSelectedType>((event, emit) {
      emit(state.copyWith(selectedType: event.type));
    });
    on<UpdateSelectedPartner>((event, emit) {
      emit(state.copyWith(selectedPartner: event.partner));
    });
    on<UpdateTags>((event, emit) {
      emit(state.copyWith(selectedTags: event.tags));
    });
    on<UpdateSelectedStage>((event, emit) {
      emit(state.copyWith(selectedStage: event.stageId));
    });

    on<CreateTicket>(_onCreateTicket);
    on<UpdateTicket>(_onUpdateTicket);

    on<UpdateSelectedOpportunityCustomer>((event, emit) {
      emit(
        state.copyWith(selectedOpportunityCustomer: event.relatedCustomerId),
      );
    });

    on<UpdateSelectedOpportunityPartner>((event, emit) {
      emit(state.copyWith(selectedOpportunityPartner: event.customerId));
    });

    on<UpdateSelectedOpportunitySalesTeam>((event, emit) {
      emit(state.copyWith(selectedOpportunityTeam: event.teamId));
    });

    on<UpdateSelectedOpportunitySalesPerson>((event, emit) {
      emit(state.copyWith(selectedOpportunitySalesPerson: event.salesPersonId));
    });

    on<ConvertOpportunity>(_onConvertOpportunity);
    on<ScheduleActivity>(_onScheduleActivity);
    on<UpdateActivity>(_onUpdateActivity);
    on<MarkDoneActivity>(_onMarkDoneActivity);

    on<ClearTicketMessage>((event, emit) {
      emit(state.copyWith(message: null));
    });
  }

  /// Loads paginated list of tickets from server.
  ///
  /// Supports:
  /// - Pagination (page, offset, limit)
  /// - Search query
  /// - Filters (status, priority, SLA, etc.)
  /// - Grouping and date-based filtering
  /// - Custom domain filters
  Future<void> _loadTickets(
    TicketsLoad event,
    Emitter<TicketState> emit,
  ) async {
    if (event.isActivityLoading) {
      emit(state.copyWith(isScheduleLoading: true));
    }
    const limit = 40;
    final offset = (event.page - 1) * limit;

    final filters = event.filters ?? state.selectedFilters;
    String? groupBy;
    if (event.resetGroupBy == true) {
      groupBy = null;
    } else {
      // Reloads that don't name a group by (e.g. returning from a ticket)
      // keep the one already applied.
      groupBy = event.groupBy ?? state.selectedGroupBy;
    }

    final dateUnit = event.dateUnit ?? state.selectedDateUnit;
    final selectedDates = event.selectedDates ?? state.selectedDates;

    if (event.page == 1 && (state.page == 0 || event.showSkeleton)) {
      // The header shows the new filters and grouping while the skeleton runs.
      emit(
        state.copyWith(
          isLoading: true,
          error: null,
          selectedFilters: filters,
          selectedGroupBy: groupBy,
        ),
      );
    } else {
      emit(state.copyWith(isPaginationLoading: true, error: null));
    }

    try {
      // Stages, users and activity types do not depend on the filters, so they
      // are fetched once and reused; the tickets themselves load alongside.
      final needLookups =
          state.defaultStage == null ||
          state.users == null ||
          state.activityTypes == null;

      final responseFuture = ticketListUseCase.loadTickets(
        limit: limit,
        offset: offset,
        filters: filters,
        groupBy: groupBy,
        dateUnit: dateUnit,
        selectedDates: selectedDates,
        search: state.search,

        customDomain: event.customDomain,
      );
      final lookupsFuture = needLookups
          ? Future.wait([
              safeApiCall(() => ticketListUseCase.loadStages()),
              safeApiCall(() => ticketListUseCase.loadUsers()),
              safeApiCall(() => ticketListUseCase.loadActivityTypes()),
            ])
          : null;

      final response = await responseFuture;
      final lookups = lookupsFuture == null ? null : await lookupsFuture;
      final stages = lookups == null ? null : toMapList(lookups[0]);
      final users = lookups == null ? state.users : toMapList(lookups[1]);
      final activityTypes = lookups == null
          ? state.activityTypes
          : toMapList(lookups[2]);

      final List<TicketEntity> tickets = response['data'];
      final int total = response['total'];
      emit(
        state.copyWith(
          isLoading: false,
          isPaginationLoading: false,
          isScheduleLoading: false,
          data: tickets,
          total: total,
          page: event.page,
          selectedFilters: filters,
          selectedGroupBy: groupBy,
          selectedDateUnit: dateUnit,
          selectedDates: selectedDates,
          groupExpanded: groupBy == null ? {} : state.groupExpanded,
          defaultStage: (stages != null && stages.isNotEmpty)
              ? stages[0]
              : state.defaultStage,
          users: users,
          activityTypes: activityTypes,
        ),
      );
    } catch (e) {
      if (e is Map<String, String>) {
        emit(
          state.copyWith(isLoading: false, error: e, isScheduleLoading: false),
        );
      } else {
        emit(
          state.copyWith(
            isLoading: false,
            isScheduleLoading: false,
            error: {'title': 'Error', 'description': e.toString()},
          ),
        );
      }
    }
  }

  /// Performs ticket search using keyword query.
  ///
  /// Resets pagination and fetches filtered ticket list.
  Future<void> _onSearchTickets(
    TicketsSearch event,
    Emitter<TicketState> emit,
  ) async {
    const limit = 40;

    emit(state.copyWith(isSearchLoading: true));

    try {
      final response = await ticketListUseCase.loadTickets(
        limit: limit,
        offset: 0,
        search: event.query,
        filters: state.selectedFilters,
        selectedDates: state.selectedDates,
        customDomain: event.customDomain,
      );
      emit(
        state.copyWith(
          isSearchLoading: false,
          data: response['data'],
          total: response['total'],
          page: 1,
          // Kept so the next load (retry, page change, refresh) searches the
          // same text instead of silently dropping it.
          search: event.query,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false));
    }
  }

  /// Clears all active filters and reloads tickets from page 1.
  Future<void> _onClearFilter(
    TicketsClearFilters event,
    Emitter<TicketState> emit,
  ) async {
    // The search goes with the filters, so the list shows everything again,
    // matching the screen's emptied search box.
    emit(state.copyWith(search: ''));
    add(
      TicketsLoad(
        1,
        filters: [],
        groupBy: null,
        resetGroupBy: true,
        dateUnit: null,
        selectedDates: {},
        customDomain: event.customDomain,
        showSkeleton: true,
      ),
    );
  }

  /// Expands or collapses a grouped ticket section in UI.
  void _onToggleGroupExpansion(
    ToggleGroupExpansion event,
    Emitter<TicketState> emit,
  ) {
    final current = state;
    final updated = Map<String, bool>.from(current.groupExpanded);
    final currentValue = updated[event.groupName] ?? true;
    updated[event.groupName] = !currentValue;

    emit(current.copyWith(groupExpanded: updated));
  }

  void _onToggleAllGroups(ToggleAllGroups event, Emitter<TicketState> emit) {
    emit(
      state.copyWith(
        groupExpanded: {for (final n in event.groupNames) n: event.expand},
      ),
    );
  }

  /// Deletes a stage permanently, then reloads the board.
  Future<void> _onDeleteStage(
    DeleteStage event,
    Emitter<TicketState> emit,
  ) async {
    try {
      await ticketListUseCase.deleteStage(event.stageId);
      add(
        TicketsLoad(
          1,
          filters: state.selectedFilters,
          groupBy: state.selectedGroupBy,
          dateUnit: state.selectedDateUnit,
          selectedDates: state.selectedDates,
          showSkeleton: true,
        ),
      );
      emit(
        state.copyWith(message: "Stage deleted successfully", isError: false),
      );
    } catch (e) {
      final msg = e.toString().replaceFirst("Exception: ", "");
      emit(
        state.copyWith(
          message: msg.isNotEmpty ? msg : "Failed to delete stage",
          isError: true,
        ),
      );
    }
  }

  /// Deletes a ticket permanently from the system.
  ///
  /// After deletion:
  /// - Reloads ticket list
  /// - Tracks analytics event
  /// - Emits success or error message
  Future<void> _onDeleteTicket(
    DeleteTicket event,
    Emitter<TicketState> emit,
  ) async {
    try {
      await ticketListUseCase.deleteTicket(event.ticketId);
      await trackEvent();

      add(
        TicketsLoad(
          1,
          filters: state.selectedFilters,
          groupBy: state.selectedGroupBy,
          dateUnit: state.selectedDateUnit,
          selectedDates: state.selectedDates,
          showSkeleton: true,
        ),
      );
      emit(
        state.copyWith(message: "Ticket deleted successfully", isError: false),
      );
    } catch (e) {
      final msg = e.toString().replaceFirst("Exception: ", "");

      emit(
        state.copyWith(
          message: msg.isNotEmpty ? msg : "Failed to delete ticket",
          isError: true,
        ),
      );
    }
  }

  /// Archives a ticket (soft delete / inactive state).
  Future<void> _onArchiveTicket(
    ArchiveTicket event,
    Emitter<TicketState> emit,
  ) async {
    try {
      await ticketListUseCase.archiveTicket(event.ticketId);
      await trackEvent();

      add(
        TicketsLoad(
          1,
          filters: state.selectedFilters,
          groupBy: state.selectedGroupBy,
          dateUnit: state.selectedDateUnit,
          selectedDates: state.selectedDates,
          showSkeleton: true,
        ),
      );

      emit(
        state.copyWith(message: "Ticket archived successfully", isError: false),
      );
    } catch (e) {
      final msg = e.toString().replaceFirst("Exception: ", "");

      emit(
        state.copyWith(
          message: msg.isNotEmpty ? msg : "Failed to archive ticket",
          isError: true,
        ),
      );
    }
  }

  /// Restores an archived ticket to active state.
  Future<void> _onUnArchiveTicket(
    UnArchiveTicket event,
    Emitter<TicketState> emit,
  ) async {
    try {
      await ticketListUseCase.unArchiveTicket(event.ticketId);
      await trackEvent();

      add(
        TicketsLoad(
          1,
          filters: state.selectedFilters,
          groupBy: state.selectedGroupBy,
          dateUnit: state.selectedDateUnit,
          selectedDates: state.selectedDates,
          showSkeleton: true,
        ),
      );
      emit(
        state.copyWith(
          message: "Ticket unarchived successfully",
          isError: false,
        ),
      );
    } catch (e) {
      final msg = e.toString().replaceFirst("Exception: ", "");

      emit(
        state.copyWith(
          message: msg.isNotEmpty ? msg : "Failed to unarchive ticket",
          isError: true,
        ),
      );
    }
  }

  /// Updates ticket stage configuration including:
  /// - Stage name
  /// - Email template
  /// - SMS template
  /// - Sequence order
  Future<void> _onUpdateStage(
    UpdateStage event,
    Emitter<TicketState> emit,
  ) async {
    try {
      await ticketListUseCase.updateStage(
        event.stageId,
        event.newName,
        event.emailTemplate,
        event.smsTemplate,
        event.sequence,
      );
      add(
        TicketsLoad(
          1,
          filters: state.selectedFilters,
          groupBy: state.selectedGroupBy,
          dateUnit: state.selectedDateUnit,
          selectedDates: state.selectedDates,
        ),
      );

      emit(
        state.copyWith(message: "Stage updated successfully", isError: false),
      );
    } catch (e) {
      final msg = e.toString().replaceFirst("Exception: ", "");
      emit(
        state.copyWith(
          message: msg.isNotEmpty ? msg : "Failed to update stage",
          isError: true,
        ),
      );
    }
  }

  /// Reorders a ticket within its current stage column (local state only).
  void _onReorderTicketInStage(
    ReorderTicketInStage event,
    Emitter<TicketState> emit,
  ) {
    final allTickets = List<TicketEntity>.from(state.data ?? []);

    final stageTickets = allTickets
        .where((t) => t.stage['id'] == event.stageId)
        .toList();
    final otherTickets = allTickets
        .where((t) => t.stage['id'] != event.stageId)
        .toList();

    final oldIndex = stageTickets.indexWhere((t) => t.id == event.ticketId);
    if (oldIndex == -1) return;

    final moved = stageTickets.removeAt(oldIndex);
    final clampedIndex = event.newIndex.clamp(0, stageTickets.length);
    stageTickets.insert(clampedIndex, moved);

    // Rebuild the full list preserving relative order of other stages.
    final reordered = <TicketEntity>[];
    int stageIdx = 0;
    int otherIdx = 0;
    for (final t in allTickets) {
      if (t.stage['id'] == event.stageId) {
        reordered.add(stageTickets[stageIdx++]);
      } else {
        reordered.add(otherTickets[otherIdx++]);
      }
    }

    emit(state.copyWith(data: reordered));
  }

  /// Moves a ticket to a new stage (triggered by kanban drag-and-drop).
  ///
  /// Optimistically updates local state so the card moves instantly,
  /// then persists the change to Odoo and reloads to confirm.
  Future<void> _onMoveTicketToStage(
    MoveTicketToStage event,
    Emitter<TicketState> emit,
  ) async {
    // Optimistic update: move the ticket in local state immediately
    final updatedTickets = (state.data ?? []).map((ticket) {
      if (ticket.id == event.ticketId) {
        return ticket.copyWith(
          stage: {'id': event.newStageId, 'name': event.newStageName},
        );
      }
      return ticket;
    }).toList();
    emit(state.copyWith(data: updatedTickets));

    try {
      await ticketListUseCase.moveTicketToStage(
        event.ticketId,
        event.newStageId,
      );
      add(
        TicketsLoad(
          1,
          filters: state.selectedFilters,
          groupBy: state.selectedGroupBy,
          dateUnit: state.selectedDateUnit,
          selectedDates: state.selectedDates,
        ),
      );
    } catch (e) {
      final msg = e.toString().replaceFirst("Exception: ", "");
      emit(
        state.copyWith(
          message: msg.isNotEmpty ? msg : "Failed to move ticket",
          isError: true,
        ),
      );
    }
  }

  /// Loads email and SMS templates for a specific stage.
  Future<void> _onLoadStageTemplates(
    LoadStageTemplates event,
    Emitter<TicketState> emit,
  ) async {
    try {
      final emailTemplateData = await ticketListUseCase.loadEmailTemplate(
        event.stageId,
      );
      final smsTemplateData = await ticketListUseCase.loadSmsTemplate(
        event.stageId,
      );

      emit(
        state.copyWith(
          isLoading: false,
          emailTemplates: emailTemplateData,
          smsTemplates: smsTemplateData,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false));
    }
  }

  /// Loads a single ticket details for edit/view screen.
  ///
  /// Also loads supporting form data:
  /// - Teams
  /// - Users
  /// - Types
  /// - Tags
  /// - Partners
  ///
  /// Prepares selected values for UI form binding.
  Future<void> _onLoadSingleTicket(
    LoadSingleTicket event,
    Emitter<TicketState> emit,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    int version = int.tryParse(prefs.getString('serverVersion') ?? '') ?? 0;

    emit(state.copyWith(isLoading: true, error: null));

    try {
      final data = await ticketFormUseCase.loadTicketData(event.ticketId);
      // Deleted or no longer visible to this user: say so, instead of failing
      // further down on the first read of the missing record.
      if (data.isEmpty) throw Exception('This ticket could not be found.');
      final helpdeskTeam = toMapList(
        await safeApiCall(() => ticketFormUseCase.loadHelpdeskTeam()),
      );
      final users = toMapList(
        await safeApiCall(() => ticketFormUseCase.loadUsers()),
      );
      final types = toMapList(
        await safeApiCall(() => ticketFormUseCase.loadTypes()),
      );
      final tags = toMapList(
        await safeApiCall(() => ticketFormUseCase.loadTags()),
      );
      final partners = toMapList(
        await safeApiCall(() => ticketFormUseCase.loadPartners()),
      );
      final stages = toMapList(
        await safeApiCall(() => ticketFormUseCase.loadStages()),
      );
      final salesTeam = toMapList(
        await safeApiCall(() => ticketFormUseCase.loadSalesTeam()),
      );

      final selectedTeam =
          (data.isNotEmpty &&
              data.first['team_id'] is List &&
              data.first['team_id'].length > 1)
          ? {'id': data.first['team_id'][0], 'name': data.first['team_id'][1]}
          : null;

      final selectedUser =
          (data.isNotEmpty &&
              data.first['user_id'] is List &&
              data.first['user_id'].length > 1)
          ? {'id': data.first['user_id'][0], 'name': data.first['user_id'][1]}
          : null;

      final selectedType =
          (version <= 17 &&
              data.isNotEmpty &&
              data.first['ticket_type_id'] is List &&
              data.first['ticket_type_id'].length > 1)
          ? {
              'id': data.first['ticket_type_id'][0],
              'name': data.first['ticket_type_id'][1],
            }
          : null;

      final selectedPartner =
          (data.isNotEmpty &&
              data.first['partner_id'] is List &&
              data.first['partner_id'].length > 1)
          ? {
              'id': data.first['partner_id'][0],
              'name': data.first['partner_id'][1],
            }
          : null;

      final selectedStage =
          (data.isNotEmpty &&
              data.first['stage_id'] is List &&
              data.first['stage_id'].length > 1)
          ? {'id': data.first['stage_id'][0], 'name': data.first['stage_id'][1]}
          : null;

      final tagIds = (data.first['tag_ids'] as List?) ?? [];

      final selectedTags = tags
          .where((tag) => tagIds.contains(tag['id']))
          .toList();

      emit(
        state.copyWith(
          isLoading: false,
          selectedTicket: data.isNotEmpty ? data.first : null,
          helpdeskTeam: helpdeskTeam,
          users: users,
          types: types,
          tags: tags,
          partners: partners,
          stages: stages,
          salesTeam: salesTeam,

          selectedTeam: selectedTeam,
          selectedUser: selectedUser,
          selectedType: selectedType,
          selectedPartner: selectedPartner,
          selectedStage: selectedStage,
          selectedTags: selectedTags,
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

  /// Loads all required dropdown data for ticket creation form.
  ///
  /// Includes:
  /// - Teams
  /// - Users
  /// - Types
  /// - Tags
  /// - Partners
  Future<void> _onLoadCreateDataItems(
    LoadTicketCreateData event,
    Emitter<TicketState> emit,
  ) async {
    // This bloc is shared with the edit form and with earlier create sessions,
    // so the team, user, partner, tags... left selected by the last ticket
    // opened or created would otherwise show up pre-filled in a new one.
    emit(
      state.copyWith(
        isCreateDataLoading: true,
        selectedTicket: null,
        selectedTeam: null,
        selectedUser: null,
        selectedType: null,
        selectedPartner: null,
        selectedTags: null,
        selectedStage: null,
      ),
    );

    try {
      final helpdeskTeam = toMapList(
        await safeApiCall(() => ticketFormUseCase.loadHelpdeskTeam()),
      );
      final users = toMapList(
        await safeApiCall(() => ticketFormUseCase.loadUsers()),
      );
      final types = toMapList(
        await safeApiCall(() => ticketFormUseCase.loadTypes()),
      );
      final tags = toMapList(
        await safeApiCall(() => ticketFormUseCase.loadTags()),
      );
      final partners = toMapList(
        await safeApiCall(() => ticketFormUseCase.loadPartners()),
      );
      final stages = toMapList(
        await safeApiCall(() => ticketFormUseCase.loadStages()),
      );

      emit(
        state.copyWith(
          isCreateDataLoading: false,
          helpdeskTeam: helpdeskTeam,
          users: users,
          types: types,
          tags: tags,
          partners: partners,
          stages: stages,
          selectedStage: stages.isNotEmpty ? stages.first : null,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isCreateDataLoading: false));
    }
  }

  /// Creates a new ticket using form data.
  ///
  /// On success:
  /// - Emits success message
  /// - Tracks analytics event
  Future<void> _onCreateTicket(
    CreateTicket event,
    Emitter<TicketState> emit,
  ) async {
    // A second submit while one is in flight would create a duplicate.
    if (state.isSaving) return;
    try {
      emit(state.copyWith(isSaving: true));

      await ticketFormUseCase.createTicket(event.data);
      await trackEvent();

      emit(
        state.copyWith(
          isSaving: false,
          message: "Ticket created successfully",
          isError: false,
        ),
      );
    } catch (e) {
      final msg = e.toString().replaceFirst("Exception: ", "");

      emit(
        state.copyWith(
          isSaving: false,
          message: msg.isNotEmpty ? msg : "Failed to create ticket",
          isError: true,
        ),
      );
    }
  }

  /// Updates an existing ticket with new form data.
  ///
  /// On success:
  /// - Emits success message
  /// - Tracks analytics event
  Future<void> _onUpdateTicket(
    UpdateTicket event,
    Emitter<TicketState> emit,
  ) async {
    if (state.isSaving) return;
    try {
      emit(state.copyWith(isSaving: true));

      await ticketFormUseCase.updateTicket(event.ticketId, event.data);
      await trackEvent();

      emit(
        state.copyWith(
          isSaving: false,
          message: "Ticket updated successfully",
          isError: false,
        ),
      );
    } catch (e) {
      final msg = e.toString().replaceFirst("Exception: ", "");
      emit(
        state.copyWith(
          isSaving: false,
          message: msg.isNotEmpty ? msg : "Failed to update ticket",
          isError: true,
        ),
      );
    }
  }

  Future<void> _onConvertOpportunity(
    ConvertOpportunity event,
    Emitter<TicketState> emit,
  ) async {
    try {
      await ticketFormUseCase.convertOpportunity(event.data);
      emit(
        state.copyWith(
          isLoading: false,
          message: "Convert to opportunity successfully",
          isError: false,
        ),
      );
    } catch (e) {
      final msg = e.toString().replaceFirst("Exception: ", "");
      emit(
        state.copyWith(
          message: msg.isNotEmpty ? msg : "Failed to convert opportunity",
          isError: true,
        ),
      );
    }
  }

  Future<void> _onScheduleActivity(
    ScheduleActivity event,
    Emitter<TicketState> emit,
  ) async {
    try {
      emit(state.copyWith(isScheduleLoading: true));
      await ticketListUseCase.scheduleActivity(event.data);
      emit(
        state.copyWith(
          isScheduleLoading: false,
          message: "Activity scheduled successfully",
          isError: false,
        ),
      );
    } catch (e) {
      final msg = e.toString().replaceFirst("Exception: ", "");
      emit(
        state.copyWith(
          message: msg.isNotEmpty ? msg : "Failed to schedule activity",
          isError: true,
          isScheduleLoading: false,
        ),
      );
    }
  }

  Future<void> _onUpdateActivity(
    UpdateActivity event,
    Emitter<TicketState> emit,
  ) async {
    try {
      emit(state.copyWith(isScheduleLoading: true));
      await ticketListUseCase.updateActivity(event.id, event.data);
      emit(
        state.copyWith(
          isScheduleLoading: false,
          message: "Activity updated successfully",
          isError: false,
        ),
      );
    } catch (e) {
      final msg = e.toString().replaceFirst("Exception: ", "");
      emit(
        state.copyWith(
          message: msg.isNotEmpty ? msg : "Failed to update activity",
          isError: true,
          isScheduleLoading: false,
        ),
      );
    }
  }

  Future<void> _onMarkDoneActivity(
    MarkDoneActivity event,
    Emitter<TicketState> emit,
  ) async {
    try {
      await ticketListUseCase.markDoneActivity(event.id);
      emit(
        state.copyWith(
          isLoading: false,
          message: "Activity marked as done successfully",
          isError: false,
        ),
      );
    } catch (e) {
      final msg = e.toString().replaceFirst("Exception: ", "");
      emit(
        state.copyWith(
          message: msg.isNotEmpty ? msg : "Failed to done activity",
          isError: true,
        ),
      );
    }
  }
}
