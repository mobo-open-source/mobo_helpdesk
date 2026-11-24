/// Repository contract for ticket listing and management operations.
///
/// Handles fetching ticket lists with filtering/pagination,
/// lifecycle actions (delete/archive/unarchive),
/// and stage/template-related operations.
abstract class TicketListRepo {
  /// Loads paginated list of tickets with optional filters, search,
  /// grouping, and date-based filtering.
  Future<Map<String, dynamic>> loadTickets({
    required int limit,
    required int offset,
    String? search,
    List<String>? filters,
    String? groupBy,
    String? dateUnit,
    Map<String, DateTime>? selectedDates,
    List<dynamic>? customDomain,
  });

  /// Fetches available stages.
  Future<List<Map<String, dynamic>>> loadStages();

  /// Fetches available users.
  Future<List<Map<String, dynamic>>> loadUsers();

  /// Fetches available activity types.
  Future<List<Map<String, dynamic>>> loadActivityTypes();

  /// Fetches the roles an activity can be assigned to (Odoo 20 and later).
  Future<List<Map<String, dynamic>>> loadActivityRoles();

  /// Fetches what Odoo prefills for a new activity of the given type.
  Future<Map<String, dynamic>> loadActivityDefaults({
    required int ticketId,
    int? activityTypeId,
    Map<String, dynamic> current = const {},
  });

  /// Permanently deletes a ticket.
  Future<void> deleteTicket(int id);

  /// Permanently deletes a stage.
  Future<void> deleteStage(int id);

  /// Archives a ticket (soft delete / inactive state).
  Future<void> archiveTicket(int id);

  /// Restores an archived ticket back to active state.
  Future<void> unArchiveTicket(int id);

  /// Retrieves stage details for a given stage ID.
  Future<Map<String, dynamic>> getStage(int id);

  /// Loads email templates available for ticket automation/actions.
  Future<List<Map<String, dynamic>>> loadEmailTemplate(int id);

  /// Loads SMS templates available for ticket automation/actions.
  Future<List<Map<String, dynamic>>> loadSmsTemplate(int id);

  /// Updates a ticket stage configuration including templates and sequence.
  Future<void> updateStage(
    dynamic stageId,
    String newName,
    dynamic emailTemplate,
    dynamic smsTemplate,
    int? sequence,
  );

  /// schedule activity for ticket.
  Future<void> scheduleActivity(Map<String, dynamic> data);

  /// update activity for ticket.
  Future<void> updateActivity(int id, Map<String, dynamic> data);

  /// marked as done activity for ticket.
  Future<void> markDoneActivity(int id);

  /// Moves a ticket to a different stage (kanban drag-and-drop).
  Future<void> moveTicketToStage(int ticketId, int stageId);
}
