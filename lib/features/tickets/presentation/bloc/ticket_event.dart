part of 'ticket_bloc.dart';

/// Base class for all ticket-related events in [TicketBloc].
///
/// All events that trigger ticket operations such as loading,
/// searching, updating, deleting, and filtering extend this class.
abstract class TicketEvent extends Equatable {
  const TicketEvent();

  @override
  List<Object?> get props => [];
}

/// Event to load a paginated list of tickets.
///
/// Supports filtering, grouping, date filtering, and custom domain logic.
class TicketsLoad extends TicketEvent {
  final int page;
  final List<String>? filters;
  final String? groupBy;
  final String? dateUnit;
  final Map<String, DateTime>? selectedDates;
  final bool resetGroupBy;
  final List<dynamic>? customDomain;
  final bool isActivityLoading;

  /// Replace the list with the loading skeleton while this page-1 load runs.
  /// For any reload the user should see happen (a filter, clearing it, a
  /// delete, a pull-to-refresh, a company switch). Left off for reloads that
  /// must keep the screen as it is, such as a card dropped into another stage.
  final bool showSkeleton;

  const TicketsLoad(
    this.page, {
    this.filters,
    this.groupBy,
    this.dateUnit,
    this.selectedDates,
    this.resetGroupBy = false,
    this.customDomain,
    this.isActivityLoading = false,
    this.showSkeleton = false,
  });

  @override
  List<Object?> get props => [
    page,
    filters,
    groupBy,
    dateUnit,
    isActivityLoading,
    showSkeleton,
  ];
}

/// Event to search tickets using a query string.
///
/// Optionally supports a custom domain filter.
class TicketsSearch extends TicketEvent {
  final String query;
  final List<dynamic>? customDomain;

  const TicketsSearch(this.query, this.customDomain);

  @override
  List<Object?> get props => [query, customDomain];
}

/// Event to clear all applied filters and reload tickets.
class TicketsClearFilters extends TicketEvent {
  final List<dynamic>? customDomain;

  const TicketsClearFilters(this.customDomain);
}

/// Event to toggle expansion state of a grouped ticket section.
class ToggleGroupExpansion extends TicketEvent {
  final String groupName;

  const ToggleGroupExpansion(this.groupName);

  @override
  List<Object?> get props => [groupName];
}

/// Event to delete a stage permanently.
class DeleteStage extends TicketEvent {
  final int stageId;

  const DeleteStage(this.stageId);

  @override
  List<Object?> get props => [stageId];
}

/// Event to delete a ticket permanently.
class DeleteTicket extends TicketEvent {
  final int ticketId;

  const DeleteTicket(this.ticketId);

  @override
  List<Object> get props => [ticketId];
}

/// Event to archive a ticket (soft delete / deactivate).
class ArchiveTicket extends TicketEvent {
  final int ticketId;

  const ArchiveTicket(this.ticketId);

  @override
  List<Object> get props => [ticketId];
}

/// Event to restore an archived ticket.
class UnArchiveTicket extends TicketEvent {
  final int ticketId;

  const UnArchiveTicket(this.ticketId);

  @override
  List<Object> get props => [ticketId];
}

/// Event to update a ticket stage and its related metadata.
///
/// Includes optional email/SMS templates and stage sequence.
class UpdateStage extends TicketEvent {
  final dynamic stageId;
  final String newName;
  final dynamic emailTemplate;
  final dynamic smsTemplate;
  final int? sequence;

  const UpdateStage({
    required this.stageId,
    required this.newName,
    this.emailTemplate,
    this.smsTemplate,
    this.sequence,
  });

  @override
  List<Object?> get props => [stageId, newName, emailTemplate, smsTemplate];
}

/// Event to load email and SMS templates for a specific stage.
class LoadStageTemplates extends TicketEvent {
  final int stageId;

  const LoadStageTemplates(this.stageId);
}

/// Event to load full details of a single ticket.
class LoadSingleTicket extends TicketEvent {
  final int ticketId;

  const LoadSingleTicket(this.ticketId);

  @override
  List<Object> get props => [ticketId];
}

/// Event to load all required data for ticket creation form.
///
/// Includes teams, users, types, tags, and partners.
class LoadTicketCreateData extends TicketEvent {
  const LoadTicketCreateData();
}

/// Event to update selected helpdesk team in ticket form.
class UpdateSelectedTeam extends TicketEvent {
  final Map<String, dynamic>? team;

  const UpdateSelectedTeam(this.team);
}

/// Event to update selected user in ticket form.
class UpdateSelectedUser extends TicketEvent {
  final Map<String, dynamic>? user;

  const UpdateSelectedUser(this.user);
}

/// Event to update selected ticket type.
class UpdateSelectedType extends TicketEvent {
  final Map<String, dynamic>? type;

  const UpdateSelectedType(this.type);
}

/// Event to update selected partner/customer.
class UpdateSelectedPartner extends TicketEvent {
  final Map<String, dynamic>? partner;

  const UpdateSelectedPartner(this.partner);
}

/// Event to update selected stage.
class UpdateSelectedStage extends TicketEvent {
  final Map<String, dynamic>? stageId;

  const UpdateSelectedStage(this.stageId);
}

/// Event to update selected tags for a ticket.
class UpdateTags extends TicketEvent {
  final List<Map<String, dynamic>> tags;

  const UpdateTags(this.tags);
}

/// Event to update selected related customer for a opportunity.
class UpdateSelectedOpportunityCustomer extends TicketEvent {
  final String? relatedCustomerId;

  const UpdateSelectedOpportunityCustomer(this.relatedCustomerId);
}

/// Event to update selected customer for a opportunity.
class UpdateSelectedOpportunityPartner extends TicketEvent {
  final Map<String, dynamic>? customerId;

  const UpdateSelectedOpportunityPartner(this.customerId);
}

/// Event to update selected team for a opportunity.
class UpdateSelectedOpportunitySalesTeam extends TicketEvent {
  final Map<String, dynamic>? teamId;

  const UpdateSelectedOpportunitySalesTeam(this.teamId);
}

/// Event to update selected user for a opportunity.
class UpdateSelectedOpportunitySalesPerson extends TicketEvent {
  final Map<String, dynamic>? salesPersonId;

  const UpdateSelectedOpportunitySalesPerson(this.salesPersonId);
}

/// Event to create a new ticket with provided payload.
class CreateTicket extends TicketEvent {
  final Map<String, dynamic> data;

  const CreateTicket(this.data);
}

/// Event to update an existing ticket.
class UpdateTicket extends TicketEvent {
  final int ticketId;
  final Map<String, dynamic> data;

  const UpdateTicket(this.ticketId, this.data);
}

/// Event to convert to opportunity for existing ticket.
class ConvertOpportunity extends TicketEvent {
  final Map<String, dynamic> data;

  const ConvertOpportunity(this.data);
}

/// Event to schedule activity for ticket.
class ScheduleActivity extends TicketEvent {
  final Map<String, dynamic> data;

  const ScheduleActivity(this.data);
}

/// Event to schedule activity for ticket.
class UpdateActivity extends TicketEvent {
  final int id;
  final Map<String, dynamic> data;

  const UpdateActivity(this.id, this.data);
}

/// Event to mark as done activity for ticket.
class MarkDoneActivity extends TicketEvent {
  final int id;

  const MarkDoneActivity(this.id);
}

/// Event to reorder a ticket within its current stage column (local state only).
class ReorderTicketInStage extends TicketEvent {
  final int ticketId;
  final int stageId;
  final int newIndex;

  const ReorderTicketInStage({
    required this.ticketId,
    required this.stageId,
    required this.newIndex,
  });

  @override
  List<Object> get props => [ticketId, stageId, newIndex];
}

/// Event to move a ticket to a new stage via kanban drag-and-drop.
class MoveTicketToStage extends TicketEvent {
  final int ticketId;
  final int newStageId;
  final String newStageName;

  const MoveTicketToStage({
    required this.ticketId,
    required this.newStageId,
    required this.newStageName,
  });

  @override
  List<Object> get props => [ticketId, newStageId, newStageName];
}

/// Event to clear temporary success/error message from state.
class ClearTicketMessage extends TicketEvent {}

/// Expands or collapses every group at once ("Expand All" / "Collapse All").
class ToggleAllGroups extends TicketEvent {
  final List<String> groupNames;
  final bool expand;

  const ToggleAllGroups(this.groupNames, this.expand);

  @override
  List<Object?> get props => [groupNames, expand];
}
