import '../../../../core/utils/group_date_format_utils.dart';
import '../../../../core/utils/safe_utils.dart';
import '../../domain/entities/ticket_entity.dart';
import '../bloc/ticket_bloc.dart';
import 'group_ticket.dart';

/// Builds a unique, sorted list of ticket stages from the given tickets.
///
/// This function:
/// - Extracts stage information from each ticket
/// - Deduplicates stages using their `id`
/// - Keeps the highest-sequence value per stage
/// - Sorts stages by their `sequence` in ascending order
///
/// Returns a list of maps containing:
/// - `id`: stage id
/// - `name`: stage name
/// - `sequence`: ordering value
List<Map<String, dynamic>> buildStages(List<TicketEntity> tickets) {
  final Map<int, Map<String, dynamic>> map = {};

  for (var t in tickets) {
    final id = t.stage['id'];
    final name = t.stage['name'];
    final sequence = t.stage['sequence'] ?? 0;

    if (id != null && name != null) {
      map[id] = {"id": id, "name": name, "sequence": sequence};
    }
  }

  final stages = map.values.toList();

  stages.sort((a, b) => (a['sequence'] as int).compareTo(b['sequence'] as int));

  return stages;
}

/// Builds grouped column metadata for a kanban-style ticket view.
///
/// This function:
/// - Groups tickets using the provided `groupBy` field
/// - Converts each group into a column representation
/// - Generates a stable `id` using the group's hash
///
/// Each returned map contains:
/// - `id`: unique identifier for the column
/// - `name`: group name
List<Map<String, dynamic>> buildGroupedColumns(
  List<TicketEntity> tickets,
  String groupBy,
  TicketState state,
) {
  final grouped = groupTickets(tickets, groupBy, state);
  return grouped.map((group) {
    return {
      "id": group["group"].toString().hashCode,
      "name": group["group"] as String,
    };
  }).toList();
}

/// Returns the grouping label for a single ticket based on the selected group field.
///
/// Supported groupings:
/// - assigned
/// - helpdesk_team
/// - priority
/// - partner
/// - tags
/// - type
/// - sla
/// - create_date
/// - sla_deadline
/// - properties
/// - stage (default)
///
/// Date-based groupings respect the selected date unit in [TicketState].
///
/// Returns a normalized string used as the grouping key.
String getStageNameForTicket(
  TicketEntity ticket,
  String groupBy,
  TicketState state,
) {
  switch (groupBy) {
    case 'assigned':
      return safeGroupValue(ticket.user['name']);
    case 'helpdesk_team':
      return safeGroupValue(ticket.team['name']);
    case 'priority':
      return safeGroupValue(ticket.priority);
    case 'partner':
      return safeGroupValue(ticket.partner['name']);
    case 'tags':
      return ticket.tags.isNotEmpty
          ? safeGroupValue(ticket.tags.first['name'])
          : "None";
    case 'type':
      return safeGroupValue(ticket.ticketType['name']);
    case 'sla':
      return ticket.slaStatuses.isNotEmpty
          ? safeGroupValue(ticket.slaStatuses.first['name'])
          : "None";
    case 'create_date':
      return state.selectedDateUnit != null
          ? formatDateGroup(ticket.createDate, state.selectedDateUnit ?? 'day')
          : safeGroupValue(ticket.createDate);

    case 'sla_deadline':
      return state.selectedDateUnit != null
          ? formatDateGroup(ticket.slaDeadline, state.selectedDateUnit ?? 'day')
          : safeGroupValue(ticket.slaDeadline);
    case 'properties':
      return safeGroupValue(ticket.properties);
    case 'stage':
    default:
      return safeGroupValue(ticket.stage['name']);
  }
}

/// Returns a stable group identifier for a ticket based on the grouping type.
///
/// - For `stage`, returns the actual stage ID (int-based grouping)
/// - For all other groupings, returns a hash-based ID derived from the group name
///
/// This ensures consistent kanban column mapping across renders.
int getStageIdForTicket(
  TicketEntity ticket,
  String groupBy,
  TicketState state,
) {
  if (groupBy == 'stage') {
    return ticket.stage['id'] ?? 0;
  }
  return getStageNameForTicket(ticket, groupBy, state).hashCode;
}
