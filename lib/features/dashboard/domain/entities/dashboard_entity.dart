/// Core domain entity representing dashboard analytics data.
///
/// This entity is independent of any data source or API format.
/// It contains aggregated metrics for tickets, SLA performance,
/// ratings, and team-level statistics used in the dashboard UI.
class DashboardEntity {
  final int id;
  final int ticketCount;
  final int highPriority;
  final int urgent;
  final double avgOpenHours;
  final double avgLowPriorityHours;
  final double avgHighPriorityHours;
  final int failedTickets;
  final int failedLowPriority;
  final int failedHighPriority;
  final int closedTodayTickets;
  final double slaSuccessTodayRate;
  final double avgTodayRating;
  final int slaTicketsToday;
  final int slaTickets7Days;
  final int closedLast7Days;
  final double slaSuccess7Days;
  final double avg7DaysRating;
  final int targetClosedTicket;
  final double targetSuccessRate;
  final double targetRating;

  final List<DashboardTeamEntity> teams;

  final bool showDemo;

  DashboardEntity({
    required this.id,
    required this.ticketCount,
    required this.highPriority,
    required this.urgent,
    required this.avgOpenHours,
    required this.avgLowPriorityHours,
    required this.avgHighPriorityHours,
    required this.failedTickets,
    required this.failedLowPriority,
    required this.failedHighPriority,
    required this.closedTodayTickets,
    required this.slaSuccessTodayRate,
    required this.avgTodayRating,
    this.slaTicketsToday = 0,
    this.slaTickets7Days = 0,
    required this.closedLast7Days,
    required this.slaSuccess7Days,
    required this.avg7DaysRating,
    required this.targetClosedTicket,
    required this.targetSuccessRate,
    required this.targetRating,
    required this.teams,
    required this.showDemo,
  });
}

/// Domain entity representing analytics for a single helpdesk team.
///
/// Contains performance metrics such as ticket counts, SLA status,
/// success rate, and rating averages.
class DashboardTeamEntity {
  final int id;
  final String name;
  final int ticketClosed;
  final double successRate;
  final double ratingAvg;
  final int openTicketCount;
  final int unassignedTickets;
  final int urgentTicket;
  final int slaFailed;

  DashboardTeamEntity({
    required this.id,
    required this.name,
    required this.ticketClosed,
    required this.successRate,
    required this.ratingAvg,
    required this.openTicketCount,
    required this.unassignedTickets,
    required this.urgentTicket,
    required this.slaFailed,
  });
}
