import '../repositories/ticket_list_repo.dart';

/// Use case layer for ticket listing and management operations.
///
/// Acts as a bridge between presentation layer (Bloc/UI)
/// and repository layer. Encapsulates business logic for:
/// - Ticket listing with filters and pagination
/// - Ticket lifecycle actions (delete/archive/unarchive)
/// - Stage and template management
class TicketListUseCase {
  final TicketListRepo ticketListRepo;

  TicketListUseCase(this.ticketListRepo);

  /// Loads paginated ticket list with optional filters, search,
  /// grouping, date filters, and custom domain overrides.
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
    return ticketListRepo.loadTickets(
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

  /// Loads available stages.
  Future<List<Map<String, dynamic>>> loadStages() {
    return ticketListRepo.loadStages();
  }

  /// Loads available users.
  Future<List<Map<String, dynamic>>> loadUsers() {
    return ticketListRepo.loadUsers();
  }

  /// Loads available activity types.
  Future<List<Map<String, dynamic>>> loadActivityTypes() {
    return ticketListRepo.loadActivityTypes();
  }

  /// Loads the roles an activity can be assigned to.
  Future<List<Map<String, dynamic>>> loadActivityRoles() {
    return ticketListRepo.loadActivityRoles();
  }

  /// Loads what Odoo prefills for a new activity of the given type.
  Future<Map<String, dynamic>> loadActivityDefaults({
    required int ticketId,
    int? activityTypeId,
    Map<String, dynamic> current = const {},
  }) {
    return ticketListRepo.loadActivityDefaults(
      ticketId: ticketId,
      activityTypeId: activityTypeId,
      current: current,
    );
  }

  /// Deletes a ticket permanently.
  Future<void> deleteTicket(int id) {
    return ticketListRepo.deleteTicket(id);
  }

  Future<void> deleteStage(int id) {
    return ticketListRepo.deleteStage(id);
  }

  /// Archives a ticket (soft delete / inactive state).
  Future<void> archiveTicket(int id) {
    return ticketListRepo.archiveTicket(id);
  }

  /// Restores an archived ticket to active state.
  Future<void> unArchiveTicket(int id) {
    return ticketListRepo.unArchiveTicket(id);
  }

  /// Retrieves stage details by stage ID.
  Future<Map<String, dynamic>> getStage(int id) {
    return ticketListRepo.getStage(id);
  }

  /// Loads available email templates for ticket automation.
  Future<List<Map<String, dynamic>>> loadEmailTemplate(int id) {
    return ticketListRepo.loadEmailTemplate(id);
  }

  /// Loads available SMS templates for ticket automation.
  Future<List<Map<String, dynamic>>> loadSmsTemplate(int id) {
    return ticketListRepo.loadSmsTemplate(id);
  }

  /// Updates ticket stage configuration (name, templates, sequence).
  Future<void> updateStage(
    dynamic stageId,
    String newName,
    dynamic emailTemplate,
    dynamic smsTemplate,
    int? sequence,
  ) {
    return ticketListRepo.updateStage(
      stageId,
      newName,
      emailTemplate,
      smsTemplate,
      sequence,
    );
  }

  /// schedule activity for ticket.
  Future<void> scheduleActivity(Map<String, dynamic> data) async {
    await ticketListRepo.scheduleActivity(data);
  }

  /// Update activity for ticket.
  Future<void> updateActivity(int id, Map<String, dynamic> data) async {
    await ticketListRepo.updateActivity(id, data);
  }

  /// Marked as done activity for ticket.
  Future<void> markDoneActivity(int id) async {
    await ticketListRepo.markDoneActivity(id);
  }

  /// Moves a ticket to a different stage (kanban drag-and-drop).
  Future<void> moveTicketToStage(int ticketId, int stageId) {
    return ticketListRepo.moveTicketToStage(ticketId, stageId);
  }
}
