part of 'team_bloc.dart';

/// Base class for all TeamBloc events.
///
/// All team-related actions (load, search, update, delete, etc.)
/// must extend this class.
abstract class TeamEvent extends Equatable {
  const TeamEvent();

  @override
  List<Object?> get props => [];
}

/// Triggers loading of paginated team list.
///
/// Supports pagination and optional filters.
class TeamsLoad extends TeamEvent {
  final int page;
  final List<String>? filters;

  /// Replace the list with the loading skeleton while this page-1 load runs.
  /// For any reload the user should see happen (a filter, clearing it, a
  /// delete, a pull-to-refresh, a company switch).
  final bool showSkeleton;

  const TeamsLoad(this.page, {this.filters, this.showSkeleton = false});

  @override
  List<Object?> get props => [page, filters, showSkeleton];
}

/// Searches teams based on a user-provided query string.
///
/// Used for real-time or manual search filtering.
class TeamSearch extends TeamEvent {
  final String query;

  const TeamSearch(this.query);
}

/// Clears all applied filters and resets team listing state.
///
/// Typically used to restore default listing view.
class TeamClearFilters extends TeamEvent {
  const TeamClearFilters();
}

/// Expands or collapses a grouped section in the UI list.
///
/// Controls UI-only state for grouped team display.
class ToggleGroupExpansion extends TeamEvent {
  final String groupName;

  const ToggleGroupExpansion(this.groupName);

  @override
  List<Object?> get props => [groupName];
}

/// Requests deletion of a team by its ID.
///
/// Permanently removes the team from backend.
class DeleteTeam extends TeamEvent {
  final int teamId;

  const DeleteTeam(this.teamId);

  @override
  List<Object> get props => [teamId];
}

/// Archives a team (soft delete).
///
/// Marks the team as inactive without permanent deletion.
class ArchiveTeam extends TeamEvent {
  final int teamId;

  const ArchiveTeam(this.teamId);

  @override
  List<Object> get props => [teamId];
}

/// Restores an archived team to active state.
class UnarchiveTeam extends TeamEvent {
  final int teamId;

  const UnarchiveTeam(this.teamId);

  @override
  List<Object> get props => [teamId];
}

/// Loads detailed information for a single team.
///
/// Used in view/edit screens.
class LoadSingleTeam extends TeamEvent {
  final int teamId;

  const LoadSingleTeam(this.teamId);

  @override
  List<Object?> get props => [teamId];
}

/// Loads all required reference data for creating a team.
///
/// Includes members, partners, stages, projects, etc.
class LoadTeamCreateData extends TeamEvent {
  final int? companyId;

  const LoadTeamCreateData({this.companyId});

  @override
  List<Object?> get props => [companyId];
}

/// Updates selected visibility setting for team form.
class UpdateSelectedVisibility extends TeamEvent {
  final String? visibility;

  const UpdateSelectedVisibility(this.visibility);
}

/// Updates selected partners for a team.
class UpdateSelectedPartners extends TeamEvent {
  final List<Map<String, dynamic>> partners;

  const UpdateSelectedPartners(this.partners);
}

/// Updates assignment method selection.
class UpdateSelectedAssignment extends TeamEvent {
  final String? assignment;

  const UpdateSelectedAssignment(this.assignment);
}

/// Updates selected team members list.
class UpdateSelectedMembers extends TeamEvent {
  final List<Map<String, dynamic>> members;

  const UpdateSelectedMembers(this.members);
}

/// Updates selected email alias configuration.
class UpdateSelectedAlias extends TeamEvent {
  final Map<String, dynamic>? alias;

  const UpdateSelectedAlias(this.alias);
}

/// Updates alias sender/visibility configuration.
class UpdateSelectedAliasFrom extends TeamEvent {
  final String? aliasFrom;

  const UpdateSelectedAliasFrom(this.aliasFrom);
}

/// Updates selected website configuration for team.
class UpdateSelectedWebsite extends TeamEvent {
  final Map<String, dynamic>? website;

  const UpdateSelectedWebsite(this.website);
}

/// Updates selected project mapping for team.
class UpdateSelectedProject extends TeamEvent {
  final Map<String, dynamic>? project;

  const UpdateSelectedProject(this.project);
}

/// Updates selected resource calendar configuration.
class UpdateSelectedResource extends TeamEvent {
  final Map<String, dynamic>? resource;

  const UpdateSelectedResource(this.resource);
}

/// Updates selected default stage for ticket movement.
class UpdateSelectedMoveStage extends TeamEvent {
  final Map<String, dynamic>? moveStage;

  const UpdateSelectedMoveStage(this.moveStage);
}

/// Updates selected "incoming stages" list for team workflow.
class UpdateInStages extends TeamEvent {
  final List<Map<String, dynamic>> stages;

  const UpdateInStages(this.stages);
}

/// Enables website module features for a specific team.
class LoadInstallWebsite extends TeamEvent {
  final int teamId;

  const LoadInstallWebsite(this.teamId);

  @override
  List<Object> get props => [teamId];
}

/// Enables project module features for a specific team.
class LoadInstallProject extends TeamEvent {
  final int teamId;

  const LoadInstallProject(this.teamId);

  @override
  List<Object> get props => [teamId];
}

/// Creates a new team with provided form data.
class CreateTeam extends TeamEvent {
  final Map<String, dynamic> data;

  /// The save will install Odoo apps on the server (the user was told and
  /// agreed). It then waits for any installation already running, and shows
  /// that apps are being installed rather than a plain "Creating".
  final bool installs;

  const CreateTeam(this.data, {this.installs = false});
}

/// Updates an existing team with new data.
class UpdateTeam extends TeamEvent {
  final int teamId;
  final Map<String, dynamic> data;

  /// See [CreateTeam.installs].
  final bool installs;

  const UpdateTeam(this.teamId, this.data, {this.installs = false});
}

/// Clears success/error message from state.
///
/// Used to reset UI feedback after showing snackbar/dialog.
class ClearTeamMessage extends TeamEvent {}
