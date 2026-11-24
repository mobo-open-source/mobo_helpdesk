import '../../domain/entities/sla_policy_entity.dart';

/// Data model implementation for SLA Policy entity.
///
/// This class extends [SlaPolicyEntity] and is responsible for converting
/// raw API responses from the Odoo backend into strongly typed domain objects.
///
/// Responsibilities:
/// - Parsing JSON response from `helpdesk.sla` API
/// - Converting relational fields (many2one, many2many) into structured maps
/// - Normalizing inconsistent backend data formats
/// - Providing safe parsing helpers for null/false values
///
/// Key parsing utilities:
/// - [parseRelation]: Converts Odoo many2one fields into `{id, name}` format
/// - [parseList]: Converts list-based relational fields into structured lists
/// - [parseString]: Safely converts dynamic values into strings
///
/// Used in:
/// - SLA Policy list datasource
/// - SLA Policy detail APIs
///
/// Note:
/// This model acts as a transformation layer between raw Odoo responses
/// and domain entities, ensuring UI receives clean and predictable data.
class SlaPolicyModel extends SlaPolicyEntity {
  SlaPolicyModel({
    required super.id,
    required super.name,
    required super.team,
    required super.priority,
    required super.ticketTypes,
    required super.stages,
    required super.time,
    required super.description,
    required super.tags,
    required super.partners,
    required super.excludingStages,
  });

  static Map<String, dynamic> parseRelation(dynamic field) {
    if (field is List && field.length >= 2) {
      return {'id': field[0], 'name': field[1]};
    }
    return {'id': 0, 'name': ''};
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

  factory SlaPolicyModel.fromJson(
    Map<String, dynamic> json, {
    List<Map<String, dynamic>> types = const [],
    List<Map<String, dynamic>> tags = const [],
    List<Map<String, dynamic>> partners = const [],
    List<Map<String, dynamic>> excludingStages = const [],
  }) {
    return SlaPolicyModel(
      id: json['id'] ?? 0,
      name: parseString(json['name']),

      team: parseRelation(json['team_id']),
      priority: parseString(json['priority']),
      ticketTypes: SlaPolicyModel.parseList(types),
      stages: parseRelation(json['stage_id']),
      time: parseString(json['time']),
      description: parseString(json['description']),

      tags: SlaPolicyModel.parseList(tags),
      partners: SlaPolicyModel.parseList(partners),
      excludingStages: SlaPolicyModel.parseList(excludingStages),
    );
  }
}
