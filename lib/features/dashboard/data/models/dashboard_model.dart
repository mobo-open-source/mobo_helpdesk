import '../../../../core/utils/safe_utils.dart';
import '../../domain/entities/dashboard_entity.dart';

/// Data model representing the dashboard response from the remote source.
///
/// This model extends [DashboardEntity] and is responsible for:
/// - Parsing raw JSON from the API
/// - Mapping nested dashboard structures into domain entities
/// - Converting dynamic values safely using utility helpers like `toInt` and `toDouble`
///
/// The expected JSON structure contains:
/// - `dashboardData` → summary metrics (today, 7 days, priorities, etc.)
/// - `teams` → list of helpdesk team statistics
class DashboardModel extends DashboardEntity {
  DashboardModel({
    required super.id,
    required super.ticketCount,
    required super.highPriority,
    required super.urgent,
    required super.avgOpenHours,
    required super.avgLowPriorityHours,
    required super.avgHighPriorityHours,
    required super.failedTickets,
    required super.failedLowPriority,
    required super.failedHighPriority,
    required super.closedTodayTickets,
    required super.slaSuccessTodayRate,
    required super.avgTodayRating,
    super.slaTicketsToday,
    super.slaTickets7Days,
    required super.closedLast7Days,
    required super.slaSuccess7Days,
    required super.avg7DaysRating,
    required super.targetClosedTicket,
    required super.targetSuccessRate,
    required super.targetRating,

    required super.teams,
    required super.showDemo,
  });

  factory DashboardModel.fromJson(Map<String, dynamic> json) {
    final data = json['dashboardData'] ?? {};
    final today = data['today'] ?? {};
    final last7Days = data['7days'] ?? {};
    final myAll = data['my_all'] ?? {};
    final myHigh = data['my_high'] ?? {};
    final myUrgent = data['my_urgent'] ?? {};

    return DashboardModel(
      id: 0,

      ticketCount: toInt(myAll['count']),
      highPriority: toInt(myHigh['count']),
      urgent: toInt(myUrgent['count']),

      avgOpenHours: toDouble(myAll['hours']),
      avgLowPriorityHours: toDouble(myHigh['hours']),
      avgHighPriorityHours: toDouble(myUrgent['hours']),

      failedTickets: toInt(myAll['failed']),
      failedLowPriority: toInt(myHigh['failed']),
      failedHighPriority: toInt(myUrgent['failed']),

      closedTodayTickets: toInt(today['count']),
      slaSuccessTodayRate: toDouble(today['success']),
      avgTodayRating: toDouble(today['rating']),
      slaTicketsToday: toInt(today['sla_ticket_count']),
      slaTickets7Days: toInt(last7Days['sla_ticket_count']),

      closedLast7Days: toInt(last7Days['count']),
      slaSuccess7Days: toDouble(last7Days['success']),
      avg7DaysRating: toDouble(last7Days['rating']),

      targetClosedTicket: toInt(data['helpdesk_target_closed']),
      targetSuccessRate: toDouble(data['helpdesk_target_success']),
      targetRating: toDouble(data['helpdesk_target_rating']),

      teams: (json['teams'] is List ? json['teams'] as List : const [])
          .map(
            (e) => DashboardTeamEntity(
              id: toInt(e['id']),
              name: e['display_name'] ?? '',
              ticketClosed: toInt(e['ticket_closed']),
              successRate: toDouble(e['success_rate']),
              ratingAvg: toDouble(e['rating_avg']),
              openTicketCount: toInt(e['open_ticket_count']),
              unassignedTickets: toInt(e['unassigned_tickets']),
              urgentTicket: toInt(e['urgent_ticket']),
              slaFailed: toInt(e['sla_failed']),
            ),
          )
          .toList(),

      showDemo: data['show_demo'] ?? false,
    );
  }
}
