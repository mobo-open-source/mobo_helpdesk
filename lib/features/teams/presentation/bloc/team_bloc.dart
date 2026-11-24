import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobo_helpdesk/features/teams/domain/entities/team_entity.dart';
import 'package:mobo_helpdesk/features/teams/domain/usecases/team_form_usecase.dart';

import '../../../../core/utils/odoo_field_resolver.dart';
import '../../../../core/utils/odoo_install_errors.dart';
import '../../../../core/utils/safe_utils.dart';
import '../../../rating/domain/usecases/review_usecase.dart';
import '../../domain/usecases/team_list_usecase.dart';

part 'team_event.dart';

part 'team_state.dart';

/// Bloc responsible for managing all Team feature state and events.
///
/// This Bloc handles:
/// - Team listing (pagination, search, filtering, grouping)
/// - Team lifecycle actions (create, update, delete, archive)
/// - Loading single team details with related configuration data
/// - Managing UI selections for team form (members, partners, stages, etc.)
/// - Handling module installation (website/project)
///
/// It acts as the central coordinator between:
/// - Presentation Layer (UI)
/// - Domain Layer (UseCases)
/// - Tracking/Analytics layer (TrackEvent)
///
/// Uses [TeamListUseCase] for list operations and
/// [TeamFormUseCase] for form-related operations.
class TeamBloc extends Bloc<TeamEvent, TeamState> {
  final TeamListUseCase teamListUseCase;
  final TeamFormUseCase teamFormUseCase;
  final TrackEvent trackEvent;

  TeamBloc(this.teamListUseCase, this.teamFormUseCase, this.trackEvent)
    : super(TeamState()) {
    on<TeamsLoad>(_loadTeams);
    on<TeamSearch>(_onSearchTeams);
    on<TeamClearFilters>(_onClearFilter);
    on<ToggleGroupExpansion>(_onToggleGroupExpansion);
    on<DeleteTeam>(_onDeleteTeam);
    on<ArchiveTeam>(_onArchiveTeam);
    on<UnarchiveTeam>(_onUnArchiveTeam);

    on<LoadSingleTeam>(_onLoadSingleTeam);
    on<LoadTeamCreateData>(_onLoadCreateDataItems);

    on<LoadInstallWebsite>(_onLoadInstallWebsite);
    on<LoadInstallProject>(_onLoadInstallProject);

    on<UpdateSelectedVisibility>((event, emit) {
      emit(state.copyWith(selectedVisibility: event.visibility));
    });
    on<UpdateSelectedAssignment>((event, emit) {
      emit(state.copyWith(selectedAssignment: event.assignment));
    });
    on<UpdateSelectedAlias>((event, emit) {
      emit(state.copyWith(selectedAlias: event.alias));
    });
    on<UpdateSelectedAliasFrom>((event, emit) {
      emit(state.copyWith(selectedAliasFrom: event.aliasFrom));
    });
    on<UpdateSelectedWebsite>((event, emit) {
      emit(state.copyWith(selectedWebsite: event.website));
    });
    on<UpdateSelectedProject>((event, emit) {
      emit(state.copyWith(selectedProject: event.project));
    });
    on<UpdateSelectedResource>((event, emit) {
      emit(state.copyWith(selectedResource: event.resource));
    });
    on<UpdateSelectedMoveStage>((event, emit) {
      emit(state.copyWith(selectedStage: event.moveStage));
    });
    on<UpdateSelectedPartners>((event, emit) {
      emit(state.copyWith(selectedPartners: event.partners));
    });
    on<UpdateSelectedMembers>((event, emit) {
      emit(state.copyWith(selectedMembers: event.members));
    });
    on<UpdateInStages>((event, emit) {
      emit(state.copyWith(selectedInStages: event.stages));
    });

    on<CreateTeam>(_onCreateTeam);
    on<UpdateTeam>(_onUpdateTeam);
    on<ClearTeamMessage>((event, emit) {
      emit(state.copyWith(message: null));
    });
  }

  /// Loads paginated list of teams from the server.
  ///
  /// Fetches teams based on pagination, search, and selected filters.
  /// Updates state with loading, pagination, and error handling support.
  ///
  /// Emits:
  /// - [isLoading] when loading first page
  /// - [isPaginationLoading] for subsequent pages
  /// - [data] list of [TeamEntity]
  /// - [total] total count of teams
  Future<void> _loadTeams(TeamsLoad event, Emitter<TeamState> emit) async {
    const limit = 40;
    final offset = (event.page - 1) * limit;

    final filters = event.filters ?? state.selectedFilters;

    if (event.page == 1 && (state.page == 0 || event.showSkeleton)) {
      // The header shows the new filters while the skeleton runs.
      emit(
        state.copyWith(isLoading: true, error: null, selectedFilters: filters),
      );
    } else {
      emit(state.copyWith(isPaginationLoading: true, error: null));
    }

    try {
      final startTime = DateTime.now();

      final response = await teamListUseCase.loadTeams(
        limit: limit,
        offset: offset,
        filters: filters,
        search: state.search,
      );

      final List<TeamEntity> teams = response['data'];
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
          data: teams,
          total: total,
          page: event.page,
          selectedFilters: filters,
        ),
      );
    } catch (e) {
      // isPaginationLoading is on for a pull-to-refresh, which is what a
      // failed refresh would otherwise leave it as.
      if (e is Map<String, String>) {
        emit(
          state.copyWith(isLoading: false, isPaginationLoading: false, error: e),
        );
      } else {
        emit(
          state.copyWith(
            isLoading: false,
            isPaginationLoading: false,
            error: {'title': 'Error', 'description': e.toString()},
          ),
        );
      }
    }
  }

  /// Searches teams based on user input query.
  ///
  /// Resets pagination and fetches filtered results from server.
  /// Applies debounce-friendly search handling.
  ///
  /// Emits:
  /// - [isSearchLoading] while searching
  /// - updated [data] and [total]
  Future<void> _onSearchTeams(TeamSearch event, Emitter<TeamState> emit) async {
    const limit = 40;

    emit(state.copyWith(isSearchLoading: true));

    try {
      final startTime = DateTime.now();

      final response = await teamListUseCase.loadTeams(
        limit: limit,
        offset: 0,
        search: event.query,
        filters: state.selectedFilters,
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

  /// Clears all applied filters and reloads team list.
  ///
  /// Triggers a fresh reload of teams with default filter state.
  Future<void> _onClearFilter(
    TeamClearFilters event,
    Emitter<TeamState> emit,
  ) async {
    // The search goes with the filters, so the list shows everything again,
    // matching the screen's emptied search box.
    emit(state.copyWith(search: ''));
    add(const TeamsLoad(1, filters: [], showSkeleton: true));
  }

  /// Toggles expand/collapse state of a grouped UI section.
  ///
  /// Updates local UI state for grouped team list display.
  void _onToggleGroupExpansion(
    ToggleGroupExpansion event,
    Emitter<TeamState> emit,
  ) {
    final current = state;
    final updated = Map<String, bool>.from(current.groupExpanded);
    final currentValue = updated[event.groupName] ?? true;
    updated[event.groupName] = !currentValue;

    emit(current.copyWith(groupExpanded: updated));
  }

  /// Deletes a team permanently from the system.
  ///
  /// Calls API to delete team, refreshes list, and emits success/failure message.
  /// Also triggers analytics tracking event.
  Future<void> _onDeleteTeam(DeleteTeam event, Emitter<TeamState> emit) async {
    try {
      await teamListUseCase.deleteTeam(event.teamId);
      await trackEvent();

      add(
        TeamsLoad(1, filters: state.selectedFilters, showSkeleton: true),
      );

      emit(
        state.copyWith(message: "Team deleted successfully", isError: false),
      );
    } catch (e) {
      final msg = e.toString().replaceFirst("Exception: ", "");

      emit(
        state.copyWith(
          isLoading: false,
          message: msg.isNotEmpty ? msg : "Failed to delete team",
          isError: true,
        ),
      );
    }
  }

  /// Archives a team (sets active = false).
  ///
  /// Removes team from active list and refreshes data.
  /// Emits success or error message.
  Future<void> _onArchiveTeam(
    ArchiveTeam event,
    Emitter<TeamState> emit,
  ) async {
    try {
      await teamListUseCase.archiveTeam(event.teamId);
      await trackEvent();

      add(
        TeamsLoad(1, filters: state.selectedFilters, showSkeleton: true),
      );

      emit(
        state.copyWith(message: "Team archived successfully", isError: false),
      );
    } catch (e) {
      final msg = e.toString().replaceFirst("Exception: ", "");

      emit(
        state.copyWith(
          isLoading: false,
          message: msg.isNotEmpty ? msg : "Failed to archive team",
          isError: true,
        ),
      );
    }
  }

  /// Restores an archived team (sets active = true).
  ///
  /// Re-includes team in active listing and refreshes state.
  Future<void> _onUnArchiveTeam(
    UnarchiveTeam event,
    Emitter<TeamState> emit,
  ) async {
    try {
      await teamListUseCase.unArchiveTeam(event.teamId);
      await trackEvent();

      add(
        TeamsLoad(1, filters: state.selectedFilters, showSkeleton: true),
      );

      emit(
        state.copyWith(message: "Team unarchived successfully", isError: false),
      );
    } catch (e) {
      final msg = e.toString().replaceFirst("Exception: ", "");

      emit(
        state.copyWith(
          isLoading: false,
          message: msg.isNotEmpty ? msg : "Failed to unarchive team",
          isError: true,
        ),
      );
    }
  }

  /// Loads full details of a single team for edit/view screen.
  ///
  /// Fetches:
  /// - Team details
  /// - Members, partners, stages, projects
  /// - Alias, website, calendar data
  /// - Installed module checks (website/project)
  ///
  /// Also maps selected relational fields into UI-ready formats.
  Future<void> _onLoadSingleTeam(
    LoadSingleTeam event,
    Emitter<TeamState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));

    try {
      final data = await teamFormUseCase.loadTeamData(event.teamId);
      // Deleted or no longer visible to this user: say so, instead of failing
      // further down on the first read of the missing record.
      if (data.isEmpty) throw Exception('This team could not be found.');
      final companyId = (data.isNotEmpty &&
              data.first['company_id'] is List &&
              (data.first['company_id'] as List).isNotEmpty)
          ? (data.first['company_id'] as List).first as int?
          : null;
      final members = toMapList(
        await safeApiCall(() => teamFormUseCase.loadMembers()),
      );
      final partners = toMapList(
        await safeApiCall(() => teamFormUseCase.loadPartners()),
      );
      final website = toMapList(
        await safeApiCall(() => teamFormUseCase.loadWebsite()),
      );
      final resources = toMapList(
        await safeApiCall(() => teamFormUseCase.loadResourceCalendar(companyId)),
      );
      final stages = toMapList(
        await safeApiCall(() => teamFormUseCase.loadStages()),
      );
      final projects = toMapList(
        await safeApiCall(() => teamFormUseCase.loadProjects()),
      );
      final aliasDomains = toMapList(
        await safeApiCall(() => teamFormUseCase.loadAliasDomain()),
      );

      final selectedVisibility = data.isNotEmpty
          ? data.first['privacy_visibility']
          : null;

      final selectedAssignment = data.isNotEmpty
          ? data.first['assign_method']
          : null;

      final selectedAliasDomain =
          (data.isNotEmpty &&
              data.first['alias_domain_id'] is List &&
              data.first['alias_domain_id'].length > 1)
          ? {
              'id': data.first['alias_domain_id'][0],
              'name': data.first['alias_domain_id'][1],
            }
          : null;

      final selectedAliasFrom = data.isNotEmpty
          ? data.first['alias_contact']
          : null;

      final selectedWebsite =
          (data.isNotEmpty &&
              data.first['website_id'] is List &&
              data.first['website_id'].length > 1)
          ? {
              'id': data.first['website_id'][0],
              'name': data.first['website_id'][1],
            }
          : null;
      final selectedProject =
          (data.isNotEmpty &&
              data.first['project_id'] is List &&
              data.first['project_id'].length > 1)
          ? {
              'id': data.first['project_id'][0],
              'name': data.first['project_id'][1],
            }
          : null;
      final selectedWorkedHours =
          (data.isNotEmpty &&
              data.first['resource_calendar_id'] is List &&
              data.first['resource_calendar_id'].length > 1)
          ? {
              'id': data.first['resource_calendar_id'][0],
              'name': data.first['resource_calendar_id'][1],
            }
          : null;
      final selectedMoveStage =
          (data.isNotEmpty &&
              data.first['to_stage_id'] is List &&
              data.first['to_stage_id'].length > 1)
          ? {
              'id': data.first['to_stage_id'][0],
              'name': data.first['to_stage_id'][1],
            }
          : null;

      final partnerIds = (data.first['message_partner_ids'] as List?) ?? [];
      final selectedPartners = partners
          .where((partner) => partnerIds.contains(partner['id']))
          .toList();

      final memberIds = (data.first['member_ids'] as List?) ?? [];
      final selectedMembers = members
          .where((member) => memberIds.contains(member['id']))
          .toList();

      final inStageIds = (data.first['from_stage_ids'] as List?) ?? [];
      final selectedStages = stages
          .where((stage) => inStageIds.contains(stage['id']))
          .toList();

      bool? isWebsiteInstalled = await teamFormUseCase.installCheck('website');
      bool? isProjectInstalled = await teamFormUseCase.installCheck('project');

      emit(
        state.copyWith(
          isLoading: false,
          selectedTeam: data.isNotEmpty ? data.first : null,
          members: members,
          partners: partners,
          website: website,
          resources: resources,
          stages: stages,
          projects: projects,
          aliasDomains: aliasDomains,

          selectedVisibility: selectedVisibility,
          selectedAssignment: selectedAssignment,
          selectedAlias: selectedAliasDomain,
          selectedAliasFrom: selectedAliasFrom,
          selectedWebsite: selectedWebsite,
          selectedProject: selectedProject,
          selectedResource: selectedWorkedHours,
          selectedStage: selectedMoveStage,
          selectedPartners: selectedPartners,
          selectedMembers: selectedMembers,
          selectedInStages: selectedStages,

          isWebsiteInstalled: isWebsiteInstalled,
          isProjectInstalled: isProjectInstalled,
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

  /// Loads all required reference data for creating a team.
  ///
  /// Includes members, partners, stages, projects, alias domains,
  /// and checks installed modules.
  ///
  /// Sets default form values for create mode.
  Future<void> _onLoadCreateDataItems(
    LoadTeamCreateData event,
    Emitter<TeamState> emit,
  ) async {
    emit(state.copyWith(isFormLoading: true));

    try {
      final members = toMapList(
        await safeApiCall(() => teamFormUseCase.loadMembers()),
      );
      final partners = toMapList(
        await safeApiCall(() => teamFormUseCase.loadPartners()),
      );
      final website = toMapList(
        await safeApiCall(() => teamFormUseCase.loadWebsite()),
      );
      final resources = toMapList(
        await safeApiCall(() => teamFormUseCase.loadResourceCalendar(event.companyId)),
      );
      final stages = toMapList(
        await safeApiCall(() => teamFormUseCase.loadStages()),
      );
      final projects = toMapList(
        await safeApiCall(() => teamFormUseCase.loadProjects()),
      );
      final aliasDomains = toMapList(
        await safeApiCall(() => teamFormUseCase.loadAliasDomain()),
      );

      bool? isWebsiteInstalled = await teamFormUseCase.installCheck('website');
      bool? isProjectInstalled = await teamFormUseCase.installCheck('project');

      final selectedVisibility = 'portal';
      final selectedAssignment = 'balanced';
      final selectedAliasFrom = 'everyone';

      emit(
        state.copyWith(
          isFormLoading: false,
          members: members,
          partners: partners,
          website: website,
          resources: resources,
          stages: stages,
          projects: projects,
          aliasDomains: aliasDomains,
          isWebsiteInstalled: isWebsiteInstalled,
          isProjectInstalled: isProjectInstalled,

          selectedAssignment: selectedAssignment,
          selectedAliasFrom: selectedAliasFrom,
          selectedVisibility: selectedVisibility,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isFormLoading: false));
    }
  }

  /// Enables website module features for a team.
  ///
  /// Updates backend configuration to activate website-related options
  /// and refreshes UI state accordingly.
  Future<void> _onLoadInstallWebsite(
    LoadInstallWebsite event,
    Emitter<TeamState> emit,
  ) async {
    try {
      emit(state.copyWith(isModuleInstallLoading: true));
      await teamFormUseCase.loadWebsiteModules(event.teamId);
      await trackEvent();

      emit(
        state.copyWith(
          message: "Website Installed Successfully",
          isError: false,
          isModuleInstallLoading: false,
        ),
      );
    } catch (e) {
      final msg = e.toString().replaceFirst("Exception: ", "");

      emit(
        state.copyWith(
          message: msg.isNotEmpty ? msg : "Failed to install website",
          isError: true,
        ),
      );
    }
  }

  /// Enables project module features for a team.
  ///
  /// Activates project-related functionality in backend and updates state.
  Future<void> _onLoadInstallProject(
    LoadInstallProject event,
    Emitter<TeamState> emit,
  ) async {
    try {
      emit(state.copyWith(isModuleInstallLoading: true));
      await teamFormUseCase.loadProjectModules(event.teamId);
      await trackEvent();

      emit(
        state.copyWith(
          message: "Project installed successfully",
          isError: false,
          isModuleInstallLoading: false,
        ),
      );
    } catch (e) {
      final msg = e.toString().replaceFirst("Exception: ", "");

      emit(
        state.copyWith(
          message: msg.isNotEmpty ? msg : "Failed to install project",
          isError: true,
          isModuleInstallLoading: false,
        ),
      );
    }
  }

  /// How often a save that installs apps looks at whether the server has
  /// finished an installation that was already running, and how many times.
  @visibleForTesting
  static Duration installPollInterval = const Duration(seconds: 3);
  static const int _installPollLimit = 60;

  static const String _installingMessage = 'Installing apps';
  static const String _installingHint =
      'This can take a few minutes and the server reloads when it is done. '
      'Keep the app open until it finishes.';

  /// Holds the save until the server has finished any installation already
  /// running. Odoo refuses to start another one meanwhile, and saves sent in the
  /// meantime fail with an error meant for administrators.
  Future<void> _waitForServerToBeFree(
    Emitter<TeamState> emit, {
    String message = _installingMessage,
    String hint = _installingHint,
  }) async {
    var waited = false;
    for (var i = 0; i < _installPollLimit; i++) {
      if (!await teamFormUseCase.isServerBusyInstalling()) break;
      if (!waited) {
        waited = true;
        emit(
          state.copyWith(
            savingMessage: 'Waiting for the server',
            savingHint:
                'Another installation is still running. Your team is saved as '
                'soon as it finishes.',
          ),
        );
      }
      await Future.delayed(installPollInterval);
    }
    if (waited) {
      emit(
        state.copyWith(
          isSaving: true,
          savingMessage: message,
          savingHint: hint,
        ),
      );
    }
  }

  static const String _checkingMessage = 'Checking what the server saved';
  static const String _checkingHint =
      'The installation did not finish normally. Making sure nothing is lost.';

  /// The options of a save that are switched on: the ones the server may need
  /// an app for.
  List<String> _optionsOn(Map<String, dynamic> data) => [
    for (final entry in data.entries)
      if (entry.key.startsWith('use_') && entry.value == true) entry.key,
  ];

  /// How [error] reads to the user once the server is known to have kept the
  /// save: what stopped the installation, not that "the team could not be
  /// created".
  String _installFailureReason(Object error) => error is OdooConnectionLost
      ? 'The connection to the server dropped before the installation '
            'finished.'
      : error.toString().replaceFirst('Exception: ', '');

  /// Looks at what the server holds after a save that installs apps ended in
  /// an error, and says so.
  ///
  /// Odoo saves the team first and installs its apps afterwards, so an
  /// installation that fails (or a connection that drops while it runs) leaves
  /// the team on the server although the app was told the save failed. Showing
  /// only the error then leaves the team missing from the list and invites a
  /// second, duplicate save. Instead the answer is read from the server:
  ///
  /// * saved and its apps installed: a success, as if nothing had happened;
  /// * saved but its apps are missing: the team is kept (`serverSaved`) and the
  ///   user is told why the apps are not installed;
  /// * not saved: the original error, and the form stays for another try.
  ///
  /// [saved] says whether the server holds the save, [onlyApps] returns the
  /// options still waiting for an app.
  Future<void> _reconcileFailedInstallSave(
    Emitter<TeamState> emit, {
    required Object error,
    required Future<bool> Function() saved,
    required Map<String, dynamic> data,
    required String savedWhat,
    required String doneMessage,
    required String fallback,
  }) async {
    emit(
      state.copyWith(
        isSaving: true,
        savingMessage: _checkingMessage,
        savingHint: _checkingHint,
      ),
    );

    // A dropped connection says nothing about the server: it may still be
    // installing. Asking it things meanwhile would only get in its way.
    if (error is OdooConnectionLost) {
      await _waitForServerToBeFree(
        emit,
        message: _checkingMessage,
        hint: _checkingHint,
      );
    }

    var isSaved = false;
    var stillNeeds = <String>[];
    try {
      isSaved = await saved();
      if (isSaved) {
        stillNeeds = await teamFormUseCase.optionsNeedingInstall(
          _optionsOn(data),
        );
      }
    } catch (_) {
      isSaved = false; // cannot tell: the original error stands
    }

    if (!isSaved) {
      emit(
        state.copyWith(
          isSaving: false,
          savingMessage: '',
          savingHint: '',
          message: fallback,
          isError: true,
        ),
      );
      return;
    }

    OdooFieldResolver.clearCache();
    if (stillNeeds.isEmpty) {
      emit(
        state.copyWith(
          isSaving: false,
          savingMessage: '',
          savingHint: '',
          message: doneMessage,
          isError: false,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        isSaving: false,
        savingMessage: '',
        savingHint: '',
        message:
            '$savedWhat, but the apps it needs could not be installed.\n\n'
            '${_installFailureReason(error)}\n\n'
            'The options stay switched on. You can switch them off and save, or '
            'save again once the server is fixed.',
        isError: true,
        serverSaved: true,
      ),
    );
  }

  /// Creates a new team in the system.
  ///
  /// Sends form data to backend and refreshes state on success.
  /// Emits success or failure message.
  Future<void> _onCreateTeam(CreateTeam event, Emitter<TeamState> emit) async {
    // A second submit while one is in flight would create a duplicate.
    if (state.isSaving) return;
    final name = '${event.data['name'] ?? ''}';
    // The teams of this name that exist before anything is sent, so that if
    // the save ends in an error the new ones can be told from the old.
    List<int>? idsBefore;
    try {
      emit(
        state.copyWith(
          isSaving: true,
          savingMessage: event.installs ? _installingMessage : '',
          savingHint: event.installs ? _installingHint : '',
        ),
      );
      if (event.installs) {
        try {
          idsBefore = await teamFormUseCase.teamIdsNamed(name);
        } catch (_) {
          // Without it a failed save cannot be checked; it is still sent.
        }
        await _waitForServerToBeFree(emit);
      }

      await teamFormUseCase.createTeam(event.data);
      await trackEvent();
      // New apps add fields; what was learned about the server is out of date.
      if (event.installs) OdooFieldResolver.clearCache();

      emit(
        state.copyWith(
          isSaving: false,
          savingMessage: '',
          savingHint: '',
          message: event.installs
              ? "Team created and apps installed successfully"
              : "Team created successfully",
          isError: false,
        ),
      );
    } catch (e) {
      final msg = e.toString().replaceFirst("Exception: ", "");
      final fallback = msg.isNotEmpty ? msg : "Failed to create team";

      if (event.installs && idsBefore != null) {
        final before = idsBefore;
        await _reconcileFailedInstallSave(
          emit,
          error: e,
          saved: () async => (await teamFormUseCase.teamIdsNamed(
            name,
          )).any((id) => !before.contains(id)),
          data: event.data,
          savedWhat: 'The team "$name" was created',
          doneMessage: 'Team created and apps installed successfully',
          fallback: fallback,
        );
        return;
      }

      emit(
        state.copyWith(
          isSaving: false,
          savingMessage: '',
          savingHint: '',
          message: fallback,
          isError: true,
        ),
      );
    }
  }

  /// Updates an existing team with new data.
  ///
  /// Sends updated fields to backend and refreshes UI state.
  /// Emits success or error feedback.
  Future<void> _onUpdateTeam(UpdateTeam event, Emitter<TeamState> emit) async {
    if (state.isSaving) return;
    try {
      emit(
        state.copyWith(
          isSaving: true,
          savingMessage: event.installs ? _installingMessage : '',
          savingHint: event.installs ? _installingHint : '',
        ),
      );
      if (event.installs) await _waitForServerToBeFree(emit);

      await teamFormUseCase.updateTeam(
        event.teamId,
        event.data,
        installs: event.installs,
      );
      await trackEvent();
      if (event.installs) OdooFieldResolver.clearCache();

      emit(
        state.copyWith(
          isSaving: false,
          savingMessage: '',
          savingHint: '',
          message: event.installs
              ? "Team updated and apps installed successfully"
              : "Team updated successfully",
          isError: false,
        ),
      );
    } catch (e) {
      final msg = e.toString().replaceFirst("Exception: ", "");
      final fallback = msg.isNotEmpty ? msg : "Failed to update team";

      if (event.installs) {
        await _reconcileFailedInstallSave(
          emit,
          error: e,
          saved: () => teamFormUseCase.holdsSave(event.teamId, event.data),
          data: event.data,
          savedWhat: 'Your changes were saved',
          doneMessage: 'Team updated and apps installed successfully',
          fallback: fallback,
        );
        return;
      }

      emit(
        state.copyWith(
          isSaving: false,
          savingMessage: '',
          savingHint: '',
          message: fallback,
          isError: true,
        ),
      );
    }
  }
}
