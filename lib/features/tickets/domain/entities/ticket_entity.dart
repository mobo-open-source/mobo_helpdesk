/// Domain entity representing a Helpdesk Ticket.
///
/// This is the core business model used across the application
/// for displaying and managing ticket data in list and detail views.
class TicketEntity {
  final int id;
  final String name;

  final Map<String, dynamic> team;
  final Map<String, dynamic> user;
  final String priority;
  final Map<String, dynamic> ticketType;

  final List<Map<String, dynamic>> tags;

  final Map<String, dynamic> partner;
  final String partnerPhone;
  final String emailCC;
  final String description;

  final List<Map<String, dynamic>> activities;

  final String slaDeadline;
  final Map<String, dynamic> stage;

  final List<Map<String, dynamic>> slaStatuses;

  final String kanbanState;

  final String createDate;
  final dynamic properties;
  final List<int> slaIds;
  final List<int> activityIds;
  final Map<String, dynamic> activityTypeId;
  final String activityTypeIcon;

  TicketEntity({
    required this.id,
    required this.name,
    required this.team,
    required this.user,
    required this.priority,
    required this.ticketType,
    required this.tags,
    required this.partner,
    required this.partnerPhone,
    required this.emailCC,
    required this.description,
    required this.activities,
    required this.slaDeadline,
    required this.stage,
    required this.slaStatuses,
    required this.kanbanState,
    required this.createDate,
    required this.properties,
    required this.slaIds,
    required this.activityIds,
    required this.activityTypeId,
    required this.activityTypeIcon,
  });

  TicketEntity copyWith({Map<String, dynamic>? stage}) {
    return TicketEntity(
      id: id,
      name: name,
      team: team,
      user: user,
      priority: priority,
      ticketType: ticketType,
      tags: tags,
      partner: partner,
      partnerPhone: partnerPhone,
      emailCC: emailCC,
      description: description,
      activities: activities,
      slaDeadline: slaDeadline,
      stage: stage ?? this.stage,
      slaStatuses: slaStatuses,
      kanbanState: kanbanState,
      createDate: createDate,
      properties: properties,
      slaIds: slaIds,
      activityIds: activityIds,
      activityTypeId: activityTypeId,
      activityTypeIcon: activityTypeIcon,
    );
  }
}
