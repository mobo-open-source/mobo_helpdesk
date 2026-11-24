import 'package:mobo_helpdesk/features/tickets/domain/repositories/ticket_form_repo.dart';

/// Use case layer for ticket form operations.
///
/// Acts as an intermediary between presentation layer (Bloc/UI)
/// and the repository layer. Handles business logic related to
/// creating and editing tickets and loading reference data.
class TicketFormUseCase {
  final TicketFormRepo ticketFormRepo;

  TicketFormUseCase(this.ticketFormRepo);

  /// Loads full ticket details for editing or viewing.
  Future<List<Map<String, dynamic>>> loadTicketData(int id) {
    return ticketFormRepo.loadTicketData(id);
  }

  /// Loads available helpdesk teams for assignment.
  Future<List<Map<String, dynamic>>> loadHelpdeskTeam() {
    return ticketFormRepo.loadHelpdeskTeam();
  }

  /// Loads available users for assignment or ownership.
  Future<List<Map<String, dynamic>>> loadUsers() {
    return ticketFormRepo.loadUsers();
  }

  /// Loads available ticket types (e.g., bug, feature, support).
  Future<List<Map<String, dynamic>>> loadTypes() {
    return ticketFormRepo.loadTypes();
  }

  /// Loads available tags for categorizing tickets.
  Future<List<Map<String, dynamic>>> loadTags() {
    return ticketFormRepo.loadTags();
  }

  /// Loads available partners/customers.
  Future<List<Map<String, dynamic>>> loadPartners() {
    return ticketFormRepo.loadPartners();
  }

  /// Loads available stages.
  Future<List<Map<String, dynamic>>> loadStages() {
    return ticketFormRepo.loadStages();
  }

  /// Loads available sales team.
  Future<List<Map<String, dynamic>>> loadSalesTeam() {
    return ticketFormRepo.loadSalesTeam();
  }

  /// Creates a new ticket using provided form data.
  Future<void> createTicket(Map<String, dynamic> data) async {
    await ticketFormRepo.createTicket(data);
  }

  /// Updates an existing ticket by ID with modified form data.
  Future<void> updateTicket(int id, Map<String, dynamic> data) async {
    await ticketFormRepo.updateTicket(id, data);
  }

  /// convert to opportunity of an existing ticket by ID.
  Future<void> convertOpportunity(Map<String, dynamic> data) async {
    await ticketFormRepo.convertOpportunity(data);
  }
}
