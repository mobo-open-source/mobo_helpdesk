import '../../domain/entities/team_entity.dart';

/// Data model representing a Helpdesk Team.
///
/// Extends [TeamEntity] and is responsible for converting raw API JSON
/// responses into strongly typed domain objects.
///
/// This model is typically used in the data layer to parse responses
/// from Odoo backend (`helpdesk.team`).
class TeamModel extends TeamEntity {
  TeamModel({
    required super.id,
    required super.name,
    required super.emailAlias,
    required super.emailAliasName,
    required super.companyId,
  });

  /// Safely parses a dynamic value into a non-null String.
  ///
  /// Converts:
  /// - `null` → empty string
  /// - `false` → empty string
  /// - any other value → string representation
  ///
  /// This is used to handle inconsistent API responses from Odoo.
  static String parseString(dynamic value) {
    if (value == null || value == false) return '';
    return value.toString();
  }

  static Map<String, dynamic> parseRelation(dynamic field) {
    if (field is List && field.length >= 2) {
      return {'id': field[0], 'name': field[1]};
    }
    return {'id': 0, 'name': ''};
  }

  /// Creates a [TeamModel] from a JSON map returned by the backend.
  ///
  /// Extracts core team fields such as:
  /// - `id`
  /// - `name`
  /// - `email_alias`
  /// - `alias_name`
  ///
  /// Optional parameters like [tags], [activities], and [slaStatuses]
  /// are reserved for future extensions but currently unused.
  ///
  /// Defaults:
  /// - Missing or invalid string values are converted using [parseString].
  ///
  /// Returns a fully initialized [TeamModel] instance.
  factory TeamModel.fromJson(
    Map<String, dynamic> json, {
    List<Map<String, dynamic>> tags = const [],
    List<Map<String, dynamic>> activities = const [],
    List<Map<String, dynamic>> slaStatuses = const [],
  }) {
    return TeamModel(
      id: json['id'] ?? 0,
      name: parseString(json['name']),
      emailAlias: parseString(json['email_alias']),
      emailAliasName: parseString(json['alias_name']),
      companyId: parseRelation(json['company_id']),
    );
  }
}
