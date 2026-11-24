/// Repository contract for Team Form operations.
///
/// Defines all domain-level actions required for creating, updating,
/// and managing team-related configuration data.
///
/// This abstraction ensures the domain layer is independent of
/// data source implementations (e.g., Odoo RPC, REST APIs).
abstract class TeamFormRepo {
  /// Loads full details of a team by [id], including related configuration data.
  Future<List<Map<String, dynamic>>> loadTeamData(int id);

  /// Loads available users who can be assigned as team members.
  Future<List<Map<String, dynamic>>> loadMembers();

  /// Loads partner/customer data for team configuration.
  Future<List<Map<String, dynamic>>> loadPartners();

  /// Loads available website records linked to the system.
  Future<List<Map<String, dynamic>>> loadWebsite();

  /// Loads available resource calendars filtered by [companyId].
  Future<List<Map<String, dynamic>>> loadResourceCalendar(int? companyId);

  /// Loads helpdesk stages available for workflow configuration.
  Future<List<Map<String, dynamic>>> loadStages();

  /// Loads available projects for team integration.
  Future<List<Map<String, dynamic>>> loadProjects();

  /// Loads available alias domains for email routing.
  Future<List<Map<String, dynamic>>> loadAliasDomain();

  /// Loads the email templates usable for the auto-close reminder (Odoo 20).
  Future<List<Map<String, dynamic>>> loadReminderTemplates();

  /// Loads what Odoo fills in for a new team (auto-close period and reminder).
  Future<Map<String, dynamic>> loadTeamDefaults();

  /// The team options among [optionFields] that saving would install an app for.
  Future<List<String>> optionsNeedingInstall(List<String> optionFields);

  /// Whether the server is installing, upgrading or removing apps right now.
  Future<bool> isServerBusyInstalling();

  /// Enables or configures website-related modules for a team by [id].
  Future<void> loadWebsiteModules(int id);

  /// Enables or configures project-related modules for a team by [id].
  Future<void> loadProjectModules(int id);

  /// The ids of the teams called [name], archived ones included.
  Future<List<int>> teamIdsNamed(String name);

  /// Whether the server already holds everything in [data] for team [id].
  Future<bool> holdsSave(int id, Map<String, dynamic> data);

  /// Creates a new team using the provided [data].
  Future<void> createTeam(Map<String, dynamic> data);

  /// Updates an existing team identified by [id] with [data]. [installs]: the
  /// save is meant to install apps, so it is sent even if nothing differs.
  Future<void> updateTeam(
    int id,
    Map<String, dynamic> data, {
    bool installs = false,
  });
}
