import '../../domain/entities/ticket_entity.dart';

/// Data model representing a Helpdesk Ticket.
///
/// Extends [TicketEntity] and maps raw Odoo JSON responses into
/// strongly structured ticket data used in the application.
///
/// Handles:
/// - Relation parsing (many2one fields like team, user, stage)
/// - List parsing (tags, activities, SLA statuses)
/// - Null safety normalization
class TicketModel extends TicketEntity {
  TicketModel({
    required super.id,
    required super.name,
    required super.team,
    required super.user,
    required super.priority,
    required super.ticketType,
    required super.tags,
    required super.partner,
    required super.partnerPhone,
    required super.emailCC,
    required super.description,
    required super.activities,
    required super.slaDeadline,
    required super.stage,
    required super.slaStatuses,
    required super.kanbanState,
    required super.createDate,
    required super.properties,
    required super.slaIds,
    required super.activityIds,
    required super.activityTypeId,
    required super.activityTypeIcon,
  });

  static Map<String, dynamic> parseRelation(dynamic field) {
    if (field is List && field.length >= 2) {
      return {'id': field[0], 'name': field[1]};
    }
    return {'id': 0, 'name': ''};
  }

  static List<Map<String, dynamic>> parseActivities(List response) {
    return response.map((e) {
      return {
        'id': e['id'],
        'name': e['display_name'] ?? '',
        // Odoo sends `false` for a type with no icon.
        'icon': e['icon'] is String ? e['icon'] : '',
        'user_id': e['user_id'],
        'activity_type_id': e['activity_type_id'],
        'date_deadline': e['date_deadline'],
        'summary': e['summary'],
        'note': e['note'],
        'user_name': (e['user_id'] is List && e['user_id'].length > 1)
            ? e['user_id'][1]
            : '',
        // Odoo 20 only: an activity can go to a role instead of a person, and a
        // call carries a phone number.
        'role_id': e['role_id'],
        'role_name': (e['role_id'] is List && e['role_id'].length > 1)
            ? e['role_id'][1]
            : '',
        'phone': e['phone'] is String ? e['phone'] : '',
        'activity_category': e['activity_category'],
        'end_date': e['date_deadline'],
      };
    }).toList();
  }

  static List<Map<String, dynamic>> parseList(List response) {
    return response.map((e) {
      return {'id': e['id'], 'name': e['name'] ?? e['display_name'] ?? ''};
    }).toList();
  }

  static String parseString(dynamic value) {
    if (value == null || value == false) return '';
    return value.toString();
  }

  static List<Map<String, dynamic>> parseTags(List tags) {
    return tags.map((e) {
      return {'id': e['id'], 'name': e['name'] ?? '', 'color': e['color'] ?? 0};
    }).toList();
  }

  factory TicketModel.fromJson(
    Map<String, dynamic> json, {
    List<Map<String, dynamic>> tags = const [],
    List<Map<String, dynamic>> activities = const [],
    List<Map<String, dynamic>> slaStatuses = const [],
    Map<String, dynamic> stageData = const {},
  }) {
    return TicketModel(
      id: json['id'] ?? 0,
      name: parseString(json['name']),

      team: parseRelation(json['team_id']),
      user: parseRelation(json['user_id']),
      priority: parseString(json['priority']),
      ticketType: json.containsKey('ticket_type_id')
          ? parseRelation(json['ticket_type_id'])
          : {'id': 0, 'name': ''},

      tags: TicketModel.parseTags(tags),

      partner: parseRelation(json['partner_id']),
      partnerPhone: parseString(json['partner_phone']),
      emailCC: parseString(json['email_cc']),
      description: parseString(json['description']),

      activities: TicketModel.parseActivities(activities),

      slaDeadline: parseString(json['sla_deadline']),
      stage: stageData.isNotEmpty
          ? {
              'id': stageData['id'],
              'name': stageData['name'],
              'sequence': stageData['sequence'] ?? 0,
            }
          : parseRelation(json['stage_id']),

      slaStatuses: TicketModel.parseList(slaStatuses),

      kanbanState: parseString(json['kanban_state']),

      createDate: parseString(json['create_date']),
      properties: json['properties'],
      slaIds: List<int>.from(json['sla_ids'] ?? []),
      activityIds: List<int>.from(json['activity_ids'] ?? []),

      activityTypeId: parseRelation(json['activity_type_id']),
      activityTypeIcon: parseString(json['activity_type_icon']),
    );
  }
}
