import '../../domain/repositories/ticket_list_repo.dart';
import '../datasources/ticket_list_remote_datasource.dart';

/// Repository implementation for ticket list operations.
///
/// Acts as a bridge between the domain layer and the remote datasource.
/// Handles ticket listing, filtering, lifecycle actions (archive/delete),
/// and stage/template-related operations.
class TicketListRepoImpl implements TicketListRepo {
  final TicketListRemoteDatasource ticketListRemoteDatasource;

  TicketListRepoImpl(this.ticketListRemoteDatasource);

  /// Fetches paginated list of tickets with optional filters, search,
  /// grouping, and date-based filtering.
  ///
  /// Supports:
  /// - Search queries
  /// - Custom filters
  /// - Grouping (kanban/list views)
  /// - Date-based filtering
  /// - Custom domain overrides
  @override
  Future<Map<String, dynamic>> loadTickets({
    required int limit,
    required int offset,
    String? search,
    List<String>? filters,
    String? groupBy,
    String? dateUnit,
    Map<String, DateTime>? selectedDates,
    List<dynamic>? customDomain,
  }) {
    return ticketListRemoteDatasource.loadTickets(
      limit: limit,
      offset: offset,
      search: search,
      filters: filters,
      groupBy: groupBy,
      dateUnit: dateUnit,
      selectedDates: selectedDates,

      customDomain: customDomain,
    );
  }

  /// Fetches list of stages.
  @override
  Future<List<Map<String, dynamic>>> loadStages() {
    return ticketListRemoteDatasource.loadStages();
  }

  /// Fetches list of users.
  @override
  Future<List<Map<String, dynamic>>> loadUsers() {
    return ticketListRemoteDatasource.loadUsers();
  }

  /// Fetches list of activity types.
  @override
  Future<List<Map<String, dynamic>>> loadActivityTypes() {
    return ticketListRemoteDatasource.loadActivityTypes();
  }

  /// Fetches the roles an activity can be assigned to.
  @override
  Future<List<Map<String, dynamic>>> loadActivityRoles() {
    return ticketListRemoteDatasource.loadActivityRoles();
  }

  /// Fetches what Odoo prefills for a new activity of the given type.
  @override
  Future<Map<String, dynamic>> loadActivityDefaults({
    required int ticketId,
    int? activityTypeId,
    Map<String, dynamic> current = const {},
  }) {
    return ticketListRemoteDatasource.loadActivityDefaults(
      ticketId: ticketId,
      activityTypeId: activityTypeId,
      current: current,
    );
  }

  /// Permanently deletes a ticket.
  @override
  Future<void> deleteTicket(int id) {
    return ticketListRemoteDatasource.deleteTicket(id);
  }

  /// Permanently deletes a stage.
  @override
  Future<void> deleteStage(int id) {
    return ticketListRemoteDatasource.deleteStage(id);
  }

  /// Archives a ticket (soft delete / inactive state).
  @override
  Future<void> archiveTicket(int id) {
    return ticketListRemoteDatasource.archiveTicket(id);
  }

  /// Restores an archived ticket back to active state.
  @override
  Future<void> unArchiveTicket(int id) {
    return ticketListRemoteDatasource.unArchiveTicket(id);
  }

  /// Loads available email templates for ticket automation/actions.
  @override
  Future<List<Map<String, dynamic>>> loadEmailTemplate(int id) {
    return ticketListRemoteDatasource.loadEmailTemplate(id);
  }

  /// Retrieves stage details for a given stage ID.
  @override
  Future<Map<String, dynamic>> getStage(int id) {
    return ticketListRemoteDatasource.getStage(id);
  }

  /// Loads available SMS templates for ticket automation/actions.
  @override
  Future<List<Map<String, dynamic>>> loadSmsTemplate(int id) {
    return ticketListRemoteDatasource.loadSmsTemplate(id);
  }

  /// Updates a ticket stage configuration.
  ///
  /// Used for modifying:
  /// - Stage name
  /// - Email template mapping
  /// - SMS template mapping
  /// - Sequence ordering
  @override
  Future<void> updateStage(
    dynamic stageId,
    String newName,
    dynamic emailTemplate,
    dynamic smsTemplate,
    int? sequence,
  ) {
    return ticketListRemoteDatasource.updateStage(
      stageId,
      newName,
      emailTemplate,
      smsTemplate,
      sequence,
    );
  }

  /// Schedule activity for ticket.
  @override
  Future<void> scheduleActivity(Map<String, dynamic> data) {
    return ticketListRemoteDatasource.scheduleActivity(data);
  }

  /// Update activity for ticket.
  @override
  Future<void> updateActivity(int id, Map<String, dynamic> data) {
    return ticketListRemoteDatasource.updateActivity(id, data);
  }

  /// marked as done activity for ticket.
  @override
  Future<void> markDoneActivity(int id) {
    return ticketListRemoteDatasource.markDoneActivity(id);
  }

  /// Moves a ticket to a different stage (kanban drag-and-drop).
  @override
  Future<void> moveTicketToStage(int ticketId, int stageId) {
    return ticketListRemoteDatasource.moveTicketToStage(ticketId, stageId);
  }
}
