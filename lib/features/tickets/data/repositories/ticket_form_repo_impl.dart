import '../../domain/repositories/ticket_form_repo.dart';
import '../datasources/ticket_form_remote_datasource.dart';

/// Repository implementation for ticket form operations.
///
/// Acts as a bridge between the domain layer and the remote datasource.
/// Responsible for delegating ticket-related CRUD and lookup operations
/// to the [TicketFormRemoteDataSource].
class TicketFormRepoImpl implements TicketFormRepo {
  final TicketFormRemoteDataSource ticketFormRemoteDataSource;

  TicketFormRepoImpl(this.ticketFormRemoteDataSource);

  /// Loads full ticket details for a given ticket ID.
  ///
  /// Used when opening a ticket in edit/view mode.
  @override
  Future<List<Map<String, dynamic>>> loadTicketData(int id) {
    return ticketFormRemoteDataSource.loadTicketData(id);
  }

  /// Fetches available helpdesk teams for ticket assignment.
  @override
  Future<List<Map<String, dynamic>>> loadHelpdeskTeam() {
    return ticketFormRemoteDataSource.loadHelpdeskTeam();
  }

  /// Fetches list of users for assignment or ownership selection.
  @override
  Future<List<Map<String, dynamic>>> loadUsers() {
    return ticketFormRemoteDataSource.loadUsers();
  }

  /// Loads ticket types (e.g., bug, feature, support).
  @override
  Future<List<Map<String, dynamic>>> loadTypes() {
    return ticketFormRemoteDataSource.loadTypes();
  }

  /// Loads available tags for categorizing tickets.
  @override
  Future<List<Map<String, dynamic>>> loadTags() {
    return ticketFormRemoteDataSource.loadTags();
  }

  /// Loads partner/customer list for linking tickets.
  @override
  Future<List<Map<String, dynamic>>> loadPartners() {
    return ticketFormRemoteDataSource.loadPartners();
  }

  /// Loads stages list for linking tickets.
  @override
  Future<List<Map<String, dynamic>>> loadStages() {
    return ticketFormRemoteDataSource.loadStages();
  }

  /// Loads sales team for linking tickets.
  @override
  Future<List<Map<String, dynamic>>> loadSalesTeam() {
    return ticketFormRemoteDataSource.loadSalesTeam();
  }

  /// Creates a new helpdesk ticket.
  ///
  /// [data] contains all required ticket fields.
  @override
  Future<void> createTicket(Map<String, dynamic> data) {
    return ticketFormRemoteDataSource.createTicket(data);
  }

  /// Updates an existing ticket by ID.
  ///
  /// [id] is the ticket identifier.
  /// [data] contains fields to update.
  @override
  Future<void> updateTicket(int id, Map<String, dynamic> data) {
    return ticketFormRemoteDataSource.updateTicket(id, data);
  }

  /// Convert to opportunity of an existing ticket by ID.
  ///
  /// [id] is the ticket identifier.
  @override
  Future<void> convertOpportunity(Map<String, dynamic> data) {
    return ticketFormRemoteDataSource.convertOpportunity(data);
  }
}
