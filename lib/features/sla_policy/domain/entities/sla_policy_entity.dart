/// Represents an SLA Policy in the Helpdesk module.
///
/// This entity is used across the domain layer to define
/// service level agreements including team, priority, stages,
/// time rules, and related metadata like tags and partners.
class SlaPolicyEntity {
  final int id;
  final String name;

  final Map<String, dynamic> team;
  final String priority;
  final List<Map<String, dynamic>> ticketTypes;
  final Map<String, dynamic> stages;
  final String time;
  final String description;

  final List<Map<String, dynamic>> tags;

  final List<Map<String, dynamic>> partners;
  final List<Map<String, dynamic>> excludingStages;

  SlaPolicyEntity({
    required this.id,
    required this.name,
    required this.team,
    required this.priority,
    required this.ticketTypes,
    required this.stages,
    required this.time,
    required this.description,
    required this.tags,
    required this.partners,
    required this.excludingStages,
  });
}
