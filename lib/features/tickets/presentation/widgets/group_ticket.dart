import '../../../../core/utils/group_date_format_utils.dart';
import '../../../../core/utils/safe_utils.dart';
import '../../domain/entities/ticket_entity.dart';
import '../bloc/ticket_bloc.dart';

/// Groups a list of [TicketEntity] based on the selected [groupBy] field.
///
/// This function transforms a flat ticket list into grouped sections
/// that can be used in UI (e.g., Kanban or grouped list view).
///
/// Supported groupBy values:
/// - assigned
/// - helpdesk_team
/// - stage
/// - priority
/// - partner
/// - tags
/// - type
/// - sla
/// - properties
/// - create_date
/// - sla_deadline
///
/// If a value is missing or null, it falls back to "Others" or "None".
List<Map<String, dynamic>> groupTickets(
  List<TicketEntity> tickets,
  String groupBy,
  TicketState state,
) {
  final Map<String, List<TicketEntity>> grouped = {};

  for (var ticket in tickets) {
    String key = "Others";

    switch (groupBy) {
      case 'assigned':
        key = safeGroupValue(ticket.user['name']);
        break;

      case 'helpdesk_team':
        key = safeGroupValue(ticket.team['name']);
        break;

      case 'stage':
        key = safeGroupValue(ticket.stage['name']);
        break;

      case 'priority':
        key = safeGroupValue(ticket.priority);
        break;

      case 'partner':
        key = safeGroupValue(ticket.partner['name']);
        break;

      case 'tags':
        key = ticket.tags.isNotEmpty
            ? safeGroupValue(ticket.tags.first['name'])
            : "None";
        break;

      case 'type':
        key = safeGroupValue(ticket.ticketType['name']);
        break;

      case 'sla':
        key = ticket.slaStatuses.isNotEmpty
            ? safeGroupValue(ticket.slaStatuses.first['name'])
            : "None";
        break;

      case 'properties':
        key = safeGroupValue(ticket.properties);
        break;

      case 'create_date':
        key = safeGroupValue(
          formatDateGroup(ticket.createDate, state.selectedDateUnit ?? 'day'),
        );
        break;

      case 'sla_deadline':
        key = safeGroupValue(
          formatDateGroup(ticket.slaDeadline, state.selectedDateUnit ?? 'day'),
        );
        break;

      default:
        key = "None";
    }

    grouped.putIfAbsent(key, () => []).add(ticket);
  }

  return grouped.entries.map((e) {
    return {"group": e.key, "tickets": e.value};
  }).toList();
}
