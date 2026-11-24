/// Core domain entity representing a Helpdesk Team.
///
/// This entity is used across the domain and presentation layers
/// to represent a team without depending on API or data-layer models.
///
/// It contains basic team identity and communication configuration
/// such as email alias information.
class TeamEntity {
  final int id;
  final String name;
  final String emailAlias;
  final String emailAliasName;
  final Map<String, dynamic> companyId;

  TeamEntity({
    required this.id,
    required this.name,
    required this.emailAlias,
    required this.emailAliasName,
    required this.companyId,
  });
}
