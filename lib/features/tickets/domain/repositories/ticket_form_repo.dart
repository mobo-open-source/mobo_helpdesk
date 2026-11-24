/// Repository contract for ticket form operations.
///
/// Defines all required actions for creating and editing tickets,
/// along with fetching related reference/master data such as
/// teams, users, types, tags, and partners.
abstract class TicketFormRepo {
  /// Loads full ticket data for editing/viewing a specific ticket.
  Future<List<Map<String, dynamic>>> loadTicketData(int id);

  /// Fetches available helpdesk teams for ticket assignment.
  Future<List<Map<String, dynamic>>> loadHelpdeskTeam();

  /// Fetches available users for assignment or ownership.
  Future<List<Map<String, dynamic>>> loadUsers();

  /// Fetches available ticket types (e.g., bug, feature, support).
  Future<List<Map<String, dynamic>>> loadTypes();

  /// Fetches available tags for categorizing tickets.
  Future<List<Map<String, dynamic>>> loadTags();

  /// Fetches partner/customer list for linking tickets.
  Future<List<Map<String, dynamic>>> loadPartners();

  /// Fetches stages list for linking tickets.
  Future<List<Map<String, dynamic>>> loadStages();

  /// Fetches sales team for linking tickets.
  Future<List<Map<String, dynamic>>> loadSalesTeam();

  /// Creates a new ticket with provided form data.
  Future<void> createTicket(Map<String, dynamic> data);

  /// Updates an existing ticket by ID with modified form data.
  Future<void> updateTicket(int id, Map<String, dynamic> data);

  /// Convert to opportunity of an existing ticket by ID.
  Future<void> convertOpportunity(Map<String, dynamic> data);
}
