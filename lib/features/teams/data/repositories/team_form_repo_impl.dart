import '../../domain/repositories/team_form_repo.dart';
import '../datasources/team_form_remote_datasource.dart';

/// Implementation of [TeamFormRepo] for managing Helpdesk Team form operations.
///
/// Acts as a bridge between the domain layer and the remote datasource
/// ([TeamFormRemoteDatasource]).
///
/// This repository delegates all data operations to the remote datasource
/// without additional business logic, ensuring a clean separation of concerns.
class TeamFormRepoImpl implements TeamFormRepo {
  final TeamFormRemoteDatasource teamFormRemoteDatasource;

  TeamFormRepoImpl(this.teamFormRemoteDatasource);

  /// Fetches detailed information for a specific Helpdesk Team.
  ///
  /// Delegates the request to [TeamFormRemoteDatasource.loadTeamData].
  ///
  /// Returns a list of team-related data maps.
  @override
  Future<List<Map<String, dynamic>>> loadTeamData(int id) {
    return teamFormRemoteDatasource.loadTeamData(id);
  }

  /// Loads available system users for team members selection.
  @override
  Future<List<Map<String, dynamic>>> loadMembers() {
    return teamFormRemoteDatasource.loadMembers();
  }

  /// Loads partner records for customer/vendor selection.
  @override
  Future<List<Map<String, dynamic>>> loadPartners() {
    return teamFormRemoteDatasource.loadPartners();
  }

  /// Loads available websites for configuration.
  @override
  Future<List<Map<String, dynamic>>> loadWebsite() {
    return teamFormRemoteDatasource.loadWebsite();
  }

  /// Loads resource calendars for scheduling configuration.
  @override
  Future<List<Map<String, dynamic>>> loadResourceCalendar(int? companyId) {
    return teamFormRemoteDatasource.loadResourceCalendar(companyId);
  }

  /// Loads helpdesk stages for workflow configuration.
  @override
  Future<List<Map<String, dynamic>>> loadStages() {
    return teamFormRemoteDatasource.loadStages();
  }

  /// Loads available projects for team integration.
  @override
  Future<List<Map<String, dynamic>>> loadProjects() {
    return teamFormRemoteDatasource.loadProjects();
  }

  /// Loads alias domains for email routing configuration.
  @override
  Future<List<Map<String, dynamic>>> loadAliasDomain() {
    return teamFormRemoteDatasource.loadAliasDomain();
  }

  /// Loads the email templates usable for the auto-close reminder.
  @override
  Future<List<Map<String, dynamic>>> loadReminderTemplates() {
    return teamFormRemoteDatasource.loadReminderTemplates();
  }

  /// Loads what Odoo fills in for a new team.
  @override
  Future<Map<String, dynamic>> loadTeamDefaults() {
    return teamFormRemoteDatasource.loadTeamDefaults();
  }

  /// The team options that saving would install an app for.
  @override
  Future<List<String>> optionsNeedingInstall(List<String> optionFields) {
    return teamFormRemoteDatasource.optionsNeedingInstall(optionFields);
  }

  /// Whether the server is installing, upgrading or removing apps right now.
  @override
  Future<bool> isServerBusyInstalling() {
    return teamFormRemoteDatasource.isServerBusyInstalling();
  }

  /// Enables project-related features for a team.
  ///
  /// Delegates to remote datasource to update backend configuration.
  @override
  Future<void> loadProjectModules(int id) {
    return teamFormRemoteDatasource.loadProjectModules(id);
  }

  /// Enables website-related features for a team.
  ///
  /// Activates website form support in backend.
  @override
  Future<void> loadWebsiteModules(int id) {
    return teamFormRemoteDatasource.loadWebsiteModules(id);
  }

  /// The ids of the teams called [name], archived ones included.
  @override
  Future<List<int>> teamIdsNamed(String name) {
    return teamFormRemoteDatasource.teamIdsNamed(name);
  }

  /// Whether the server already holds everything in [data] for team [id].
  @override
  Future<bool> holdsSave(int id, Map<String, dynamic> data) {
    return teamFormRemoteDatasource.holdsSave(id, data);
  }

  /// Creates a new Helpdesk Team.
  ///
  /// Sends team configuration data to backend via remote datasource.
  @override
  Future<void> createTeam(Map<String, dynamic> data) {
    return teamFormRemoteDatasource.createTeam(data);
  }

  /// Updates an existing Helpdesk Team.
  ///
  /// Requires team [id] and updated [data].
  @override
  Future<void> updateTeam(
    int id,
    Map<String, dynamic> data, {
    bool installs = false,
  }) {
    return teamFormRemoteDatasource.updateTeam(id, data, installs: installs);
  }
}
