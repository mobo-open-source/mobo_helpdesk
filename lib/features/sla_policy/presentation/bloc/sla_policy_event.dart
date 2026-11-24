part of 'sla_policy_bloc.dart';

/// Base class for all SLA Policy events.
///
/// All events extend this class and are used to trigger
/// state changes inside [SlaPolicyBloc].
abstract class SlaPolicyEvent extends Equatable {
  const SlaPolicyEvent();

  @override
  List<Object?> get props => [];
}

/// Event to load paginated SLA policies.
///
/// Supports pagination, filtering, grouping, and custom domain queries.
class SlaPolicyLoad extends SlaPolicyEvent {
  final int page;
  final List<String>? filters;
  final String? groupBy;
  final bool resetGroupBy;
  final List<dynamic>? customDomain;

  /// Replace the list with the loading skeleton while this page-1 load runs.
  /// For any reload the user should see happen (a filter, clearing it, a
  /// delete, a pull-to-refresh, a company switch).
  final bool showSkeleton;

  const SlaPolicyLoad(
    this.page, {
    this.filters,
    this.groupBy,
    this.resetGroupBy = false,
    this.customDomain,
    this.showSkeleton = false,
  });

  @override
  List<Object?> get props => [page, filters, groupBy, showSkeleton];
}

/// Event to search SLA policies by query string.
///
/// Can also include optional custom domain filters.
class SlaPolicySearch extends SlaPolicyEvent {
  final String query;
  final List<dynamic>? customDomain;

  const SlaPolicySearch(this.query, this.customDomain);

  @override
  List<Object?> get props => [query, customDomain];
}

/// Event to clear all applied filters and reload policies.
///
/// Optionally supports custom domain override.
class SlaPolicyClearFilters extends SlaPolicyEvent {
  final List<dynamic>? customDomain;

  const SlaPolicyClearFilters(this.customDomain);
}

/// Event to toggle expansion state of a grouped SLA policy section.
///
/// Used in grouped UI views.
class ToggleGroupExpansion extends SlaPolicyEvent {
  final String groupName;

  const ToggleGroupExpansion(this.groupName);

  @override
  List<Object?> get props => [groupName];
}

/// Event to delete a SLA policy permanently.
class DeleteSlaPolicy extends SlaPolicyEvent {
  final int policyId;

  const DeleteSlaPolicy(this.policyId);

  @override
  List<Object> get props => [policyId];
}

/// Event to archive a SLA policy (mark as inactive).
class ArchiveSlaPolicy extends SlaPolicyEvent {
  final int policyId;

  const ArchiveSlaPolicy(this.policyId);

  @override
  List<Object> get props => [policyId];
}

/// Event to unarchive a previously archived SLA policy.
class UnArchiveSlaPolicy extends SlaPolicyEvent {
  final int policyId;

  const UnArchiveSlaPolicy(this.policyId);

  @override
  List<Object> get props => [policyId];
}

/// Event to load full details of a single SLA policy.
///
/// Typically used in edit/view screen.
class LoadSinglePolicy extends SlaPolicyEvent {
  final int policyId;

  const LoadSinglePolicy(this.policyId);

  @override
  List<Object> get props => [policyId];
}

/// Event to load all required dropdown/master data
/// for SLA policy creation screen.
class LoadPolicyCreateData extends SlaPolicyEvent {
  const LoadPolicyCreateData();
}

/// Event to update selected helpdesk team in state.
class UpdateSlaSelectedTeam extends SlaPolicyEvent {
  final Map<String, dynamic>? team;

  const UpdateSlaSelectedTeam(this.team);
}

/// Event to update selected ticket types.
class UpdateSlaSelectedType extends SlaPolicyEvent {
  final List<Map<String, dynamic>> types;

  const UpdateSlaSelectedType(this.types);
}

/// Event to update selected SLA tags.
class UpdateSlaTags extends SlaPolicyEvent {
  final List<Map<String, dynamic>> tags;

  const UpdateSlaTags(this.tags);
}

/// Event to update selected customers/partners.
class UpdateSelectedCustomer extends SlaPolicyEvent {
  final List<Map<String, dynamic>> customers;

  const UpdateSelectedCustomer(this.customers);
}

/// Event to update selected reach stage.
class UpdateReachStage extends SlaPolicyEvent {
  final Map<String, dynamic>? stage;

  const UpdateReachStage(this.stage);
}

/// Event to update excluded stages list.
class UpdateExcludingStages extends SlaPolicyEvent {
  final List<Map<String, dynamic>> stages;

  const UpdateExcludingStages(this.stages);
}

/// Event to load stages based on selected team.
class LoadStagesByTeam extends SlaPolicyEvent {
  final int teamId;

  const LoadStagesByTeam(this.teamId);
}

/// Event to create a new SLA policy.
///
/// Payload contains all form data required by backend.
class CreatePolicy extends SlaPolicyEvent {
  final Map<String, dynamic> data;

  const CreatePolicy(this.data);
}

/// Event to update an existing SLA policy.
///
/// Requires policy ID and updated payload data.
class UpdatePolicy extends SlaPolicyEvent {
  final int policyId;
  final Map<String, dynamic> data;

  const UpdatePolicy(this.policyId, this.data);
}

/// Event to clear snackbar/message state after showing it to user.
class ClearSlaMessage extends SlaPolicyEvent {}

/// Expands or collapses every group at once ("Expand All" / "Collapse All").
class ToggleAllGroups extends SlaPolicyEvent {
  final List<String> groupNames;
  final bool expand;

  const ToggleAllGroups(this.groupNames, this.expand);

  @override
  List<Object?> get props => [groupNames, expand];
}
