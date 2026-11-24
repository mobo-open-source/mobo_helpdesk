import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/utils/safe_utils.dart';
import '../../../rating/domain/usecases/review_usecase.dart';
import '../../domain/entities/sla_policy_entity.dart';
import '../../domain/usecases/sla_policy_form_usecase.dart';
import '../../domain/usecases/sla_policy_list_usecase.dart';

part 'sla_policy_event.dart';

part 'sla_policy_state.dart';

/// BLoC responsible for managing SLA Policy feature state and events.
///
/// This BLoC handles:
/// - Loading SLA policies (pagination, search, filtering, grouping)
/// - Creating, updating, archiving, and deleting policies
/// - Loading form-related reference data (teams, types, tags, etc.)
/// - Managing UI state such as selections, expansions, and messages
///
/// It acts as the central controller between UI and domain layer
/// using [SlaPolicyListUseCase] and [SlaPolicyFormUseCase].
class SlaPolicyBloc extends Bloc<SlaPolicyEvent, SlaPolicyState> {
  final SlaPolicyListUseCase slaPolicyListUseCase;
  final SlaPolicyFormUseCase slaPolicyFormUseCase;
  final TrackEvent trackEvent;

  SlaPolicyBloc(
    this.slaPolicyListUseCase,
    this.slaPolicyFormUseCase,
    this.trackEvent,
  ) : super(SlaPolicyState()) {
    on<SlaPolicyLoad>(_loadSlaPolicies);
    on<SlaPolicySearch>(_onSlaSearch);
    on<SlaPolicyClearFilters>(_onClearFilter);
    on<ToggleGroupExpansion>(_onToggleGroupExpansion);
    on<ToggleAllGroups>(_onToggleAllGroups);
    on<DeleteSlaPolicy>(_onDeleteSlaPolicy);
    on<ArchiveSlaPolicy>(_onArchiveSlaPolicy);
    on<UnArchiveSlaPolicy>(_onUnArchiveSlaPolicy);

    on<UpdateSlaSelectedTeam>((event, emit) {
      final team = event.team;
      emit(
        team == null
            // The stages on offer and the ones picked belong to the team, so
            // clearing the team leaves nothing valid behind.
            ? state.copyWith(
                selectedTeam: null,
                selectedReachStage: null,
                selectedExcludingStages: [],
                reachStage: [],
                excludingStages: [],
              )
            : state.copyWith(selectedTeam: team),
      );
    });
    on<UpdateSlaSelectedType>((event, emit) {
      emit(state.copyWith(selectedTypes: event.types));
    });
    on<UpdateSelectedCustomer>((event, emit) {
      emit(state.copyWith(selectedCustomers: event.customers));
    });
    on<UpdateSlaTags>((event, emit) {
      emit(state.copyWith(selectedTags: event.tags));
    });
    on<UpdateReachStage>((event, emit) {
      emit(state.copyWith(selectedReachStage: event.stage));
    });
    on<UpdateExcludingStages>((event, emit) {
      emit(state.copyWith(selectedExcludingStages: event.stages));
    });

    on<LoadSinglePolicy>(_onLoadSinglePolicy);
    on<LoadPolicyCreateData>(_onLoadCreateDataItems);
    on<LoadStagesByTeam>(_onLoadStagesByTeam);
    on<CreatePolicy>(_onCreatePolicy);
    on<UpdatePolicy>(_onUpdatePolicy);
    on<ClearSlaMessage>((event, emit) {
      emit(state.copyWith(message: null));
    });
  }

  /// Loads SLA policies with pagination, filters, and grouping support.
  Future<void> _loadSlaPolicies(
    SlaPolicyLoad event,
    Emitter<SlaPolicyState> emit,
  ) async {
    const limit = 40;
    final offset = (event.page - 1) * limit;

    final filters = event.filters ?? state.selectedFilters;
    String? groupBy;

    if (event.resetGroupBy == true) {
      groupBy = null;
    } else {
      // Reloads that don't name a group by (e.g. returning from a policy)
      // keep the one already applied.
      final current = state.selectedGroupBy;
      groupBy =
          event.groupBy ?? ((current?.isNotEmpty ?? false) ? current : null);
    }

    if (event.page == 1 && (state.page == 0 || event.showSkeleton)) {
      // The header shows the new filters and grouping while the skeleton runs.
      emit(
        state.copyWith(
          isLoading: true,
          error: null,
          selectedFilters: filters,
          selectedGroupBy: groupBy ?? '',
        ),
      );
    } else {
      emit(state.copyWith(isPaginationLoading: true, error: null));
    }

    try {
      final startTime = DateTime.now();

      final response = await slaPolicyListUseCase.loadPolicies(
        limit: limit,
        offset: offset,
        filters: filters,
        groupBy: groupBy,
        search: state.search,

        customDomain: event.customDomain,
      );

      final List<SlaPolicyEntity> policies = response['data'];
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
          data: policies,
          total: total,
          page: event.page,
          selectedFilters: filters,
          selectedGroupBy: groupBy ?? '',
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

  /// Performs SLA policy search based on query string.
  Future<void> _onSlaSearch(
    SlaPolicySearch event,
    Emitter<SlaPolicyState> emit,
  ) async {
    const limit = 40;

    emit(state.copyWith(isSearchLoading: true));

    try {
      final startTime = DateTime.now();

      final response = await slaPolicyListUseCase.loadPolicies(
        limit: limit,
        offset: 0,
        search: event.query,
        filters: state.selectedFilters,

        customDomain: event.customDomain,
      );
      final elapsed = DateTime.now().difference(startTime);
      if (elapsed.inMilliseconds < 500) {
        await Future.delayed(
          Duration(milliseconds: 500 - elapsed.inMilliseconds),
        );
      }
      emit(
        state.copyWith(
          isSearchLoading: false,
          data: response['data'],
          total: response['total'],
          page: 1,
          search: event.query,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false));
    }
  }

  /// Clears all applied filters and reloads data.
  Future<void> _onClearFilter(
    SlaPolicyClearFilters event,
    Emitter<SlaPolicyState> emit,
  ) async {
    // The search goes with the filters, so the list shows everything again,
    // matching the screen's emptied search box.
    emit(state.copyWith(search: ''));
    add(
      SlaPolicyLoad(
        1,
        filters: [],
        resetGroupBy: true,
        customDomain: event.customDomain,
        showSkeleton: true,
      ),
    );
  }

  /// Toggles expansion state for grouped SLA policies.
  void _onToggleGroupExpansion(
    ToggleGroupExpansion event,
    Emitter<SlaPolicyState> emit,
  ) {
    final current = state;
    final updated = Map<String, bool>.from(current.groupExpanded);
    final currentValue = updated[event.groupName] ?? true;
    updated[event.groupName] = !currentValue;

    emit(current.copyWith(groupExpanded: updated));
  }

  void _onToggleAllGroups(ToggleAllGroups event, Emitter<SlaPolicyState> emit) {
    emit(
      state.copyWith(
        groupExpanded: {for (final n in event.groupNames) n: event.expand},
      ),
    );
  }

  /// Deletes a SLA policy and refreshes list.
  Future<void> _onDeleteSlaPolicy(
    DeleteSlaPolicy event,
    Emitter<SlaPolicyState> emit,
  ) async {
    try {
      await slaPolicyListUseCase.deletePolicy(event.policyId);
      await trackEvent();

      add(
        SlaPolicyLoad(
          1,
          filters: state.selectedFilters,
          groupBy: state.selectedGroupBy,
          showSkeleton: true,
        ),
      );
      emit(
        state.copyWith(
          message: "Sla policy deleted successfully",
          isError: false,
        ),
      );
    } catch (e) {
      final msg = e.toString().replaceFirst("Exception: ", "");

      emit(
        state.copyWith(
          isLoading: false,
          message: msg.isNotEmpty ? msg : "Failed to delete sla policy",
          isError: true,
        ),
      );
    }
  }

  /// Archives a SLA policy.
  Future<void> _onArchiveSlaPolicy(
    ArchiveSlaPolicy event,
    Emitter<SlaPolicyState> emit,
  ) async {
    try {
      await slaPolicyListUseCase.archivePolicy(event.policyId);
      await trackEvent();

      add(
        SlaPolicyLoad(
          1,
          filters: state.selectedFilters,
          groupBy: state.selectedGroupBy,
          showSkeleton: true,
        ),
      );
      emit(
        state.copyWith(
          message: "Sla policy archived successfully",
          isError: false,
        ),
      );
    } catch (e) {
      final msg = e.toString().replaceFirst("Exception: ", "");

      emit(
        state.copyWith(
          isLoading: false,
          message: msg.isNotEmpty ? msg : "Failed to archive sla policy",
          isError: true,
        ),
      );
    }
  }

  /// Unarchives a previously archived SLA policy.
  Future<void> _onUnArchiveSlaPolicy(
    UnArchiveSlaPolicy event,
    Emitter<SlaPolicyState> emit,
  ) async {
    try {
      await slaPolicyListUseCase.unArchivePolicy(event.policyId);
      await trackEvent();

      add(
        SlaPolicyLoad(
          1,
          filters: state.selectedFilters,
          groupBy: state.selectedGroupBy,
          showSkeleton: true,
        ),
      );
      emit(
        state.copyWith(
          message: "Sla policy unarchived successfully",
          isError: false,
        ),
      );
    } catch (e) {
      final msg = e.toString().replaceFirst("Exception: ", "");

      emit(
        state.copyWith(
          isLoading: false,
          message: msg.isNotEmpty ? msg : "Failed to unarchive sla policy",
          isError: true,
        ),
      );
    }
  }

  /// Loads a single SLA policy and prepares all related form data.
  Future<void> _onLoadSinglePolicy(
    LoadSinglePolicy event,
    Emitter<SlaPolicyState> emit,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    int version = int.tryParse(prefs.getString('serverVersion') ?? '') ?? 0;

    emit(state.copyWith(isLoading: true, error: null));

    try {
      final data = await slaPolicyFormUseCase.loadPolicyData(event.policyId);
      // Deleted or no longer visible to this user: say so, instead of failing
      // further down on the first read of the missing record.
      if (data.isEmpty) throw Exception('This SLA policy could not be found.');
      final types = toMapList(
        await safeApiCall(() => slaPolicyFormUseCase.loadTypes()),
      );

      final tags = toMapList(
        await safeApiCall(() => slaPolicyFormUseCase.loadTags()),
      );

      final customers = toMapList(
        await safeApiCall(() => slaPolicyFormUseCase.loadCustomers()),
      );

      final helpdeskTeam = toMapList(
        await safeApiCall(() => slaPolicyFormUseCase.loadHelpdeskTeam()),
      );

      final reachStage = toMapList(
        await safeApiCall(
          () => slaPolicyFormUseCase.loadReachStages(
            data.first['team_id'][0],
            data.first['exclude_stage_ids'],
          ),
        ),
      );

      final excludingStages = toMapList(
        await safeApiCall(
          () => slaPolicyFormUseCase.loadExcludingStages(
            data.first['team_id'][0],
            data.first['stage_id'][0],
          ),
        ),
      );

      final selectedTeam =
          (data.isNotEmpty &&
              data.first['team_id'] is List &&
              data.first['team_id'].length > 1)
          ? {'id': data.first['team_id'][0], 'name': data.first['team_id'][1]}
          : null;

      final selectedReachStage =
          (data.isNotEmpty &&
              data.first['stage_id'] is List &&
              data.first['stage_id'].length > 1)
          ? {'id': data.first['stage_id'][0], 'name': data.first['stage_id'][1]}
          : null;

      final tagIds = (data.first['tag_ids'] as List?) ?? [];
      final selectedTags = tags
          .where((tag) => tagIds.contains(tag['id']))
          .toList();

      final typeIds = version <= 17
          ? (data.first['ticket_type_ids'] as List? ?? [])
          : [];
      final selectedTypes = types
          .where((type) => typeIds.contains(type['id']))
          .toList();

      final customerIds = (data.first['partner_ids'] as List?) ?? [];
      final selectedCustomers = customers
          .where((customer) => customerIds.contains(customer['id']))
          .toList();

      final excludingStageIds =
          (data.first['exclude_stage_ids'] as List?) ?? [];
      final selectedExcludingStages = excludingStages
          .where((stage) => excludingStageIds.contains(stage['id']))
          .toList();

      emit(
        state.copyWith(
          isLoading: false,
          selectedPolicy: data.isNotEmpty ? data.first : null,
          helpdeskTeam: helpdeskTeam,
          types: types,
          tags: tags,
          customers: customers,
          reachStage: reachStage,
          excludingStages: excludingStages,

          selectedTeam: selectedTeam,
          selectedReachStage: selectedReachStage,
          selectedTypes: selectedTypes,
          selectedCustomers: selectedCustomers,
          selectedTags: selectedTags,
          selectedExcludingStages: selectedExcludingStages,
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

  /// Loads reference data required for creating SLA policy.
  Future<void> _onLoadCreateDataItems(
    LoadPolicyCreateData event,
    Emitter<SlaPolicyState> emit,
  ) async {
    emit(state.copyWith(isFormLoading: true));

    try {
      final helpdeskTeam = toMapList(
        await safeApiCall(() => slaPolicyFormUseCase.loadHelpdeskTeam()),
      );
      final types = toMapList(
        await safeApiCall(() => slaPolicyFormUseCase.loadTypes()),
      );

      final tags = toMapList(
        await safeApiCall(() => slaPolicyFormUseCase.loadTags()),
      );

      final customers = toMapList(
        await safeApiCall(() => slaPolicyFormUseCase.loadCustomers()),
      );

      emit(
        state.copyWith(
          isFormLoading: false,
          helpdeskTeam: helpdeskTeam,
          types: types,
          tags: tags,
          customers: customers,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isFormLoading: false));
    }
  }

  /// Loads stages based on selected team.
  Future<void> _onLoadStagesByTeam(
    LoadStagesByTeam event,
    Emitter<SlaPolicyState> emit,
  ) async {
    try {
      emit(state.copyWith(isFormLoading: true));

      final reachStage = toMapList(
        await safeApiCall(
          () => slaPolicyFormUseCase.loadReachStages(event.teamId, []),
        ),
      );

      final excludingStages = toMapList(
        await safeApiCall(
          () => slaPolicyFormUseCase.loadExcludingStages(event.teamId, 0),
        ),
      );

      emit(
        state.copyWith(
          isFormLoading: false,
          reachStage: reachStage,
          excludingStages: excludingStages,

          // Odoo's default target: the first folded stage (e.g. Solved), else
          // the last one. Tickets only count when at or before the target, so
          // an early stage would leave a new policy with no tickets.
          selectedReachStage: reachStage.isEmpty
              ? null
              : reachStage.firstWhere(
                  (stage) => stage['fold'] == true,
                  orElse: () => reachStage.last,
                ),
          selectedExcludingStages: [],
        ),
      );
    } catch (e) {
      emit(state.copyWith(isFormLoading: false));
    }
  }

  /// Creates a new SLA policy.
  Future<void> _onCreatePolicy(
    CreatePolicy event,
    Emitter<SlaPolicyState> emit,
  ) async {
    // A second submit while one is in flight would create a duplicate.
    if (state.isSaving) return;
    try {
      emit(state.copyWith(isSaving: true));
      await slaPolicyFormUseCase.createPolicy(event.data);
      await trackEvent();

      emit(
        state.copyWith(
          isSaving: false,
          message: "SLA Policy created successfully",
          isError: false,
        ),
      );
    } catch (e) {
      final msg = e.toString().replaceFirst("Exception: ", "");

      emit(
        state.copyWith(
          isSaving: false,
          message: msg.isNotEmpty ? msg : "Failed to create policy",
          isError: true,
        ),
      );
    }
  }

  /// Updates an existing SLA policy.
  Future<void> _onUpdatePolicy(
    UpdatePolicy event,
    Emitter<SlaPolicyState> emit,
  ) async {
    if (state.isSaving) return;
    try {
      emit(state.copyWith(isSaving: true));
      await slaPolicyFormUseCase.updatePolicy(event.policyId, event.data);
      await trackEvent();

      emit(
        state.copyWith(
          isSaving: false,
          message: "SLA Policy updated successfully",
          isError: false,
        ),
      );
    } catch (e) {
      final msg = e.toString().replaceFirst("Exception: ", "");

      emit(
        state.copyWith(
          isSaving: false,
          message: msg.isNotEmpty ? msg : "Failed to update policy",
          isError: true,
        ),
      );
    }
  }
}
