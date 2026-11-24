import '../../../../core/odoo/repositories/module_check_repository.dart';
import '../repositories/team_form_repo.dart';

/// Use case layer for Team Form operations.
///
/// Acts as an intermediary between the presentation layer (Bloc/UI)
/// and the domain repository ([TeamFormRepo]).
///
/// This class encapsulates all business actions related to team
/// creation and configuration, including:
/// - Loading reference data (members, partners, stages, etc.)
/// - Checking module installation status
/// - Creating and updating teams
/// - Enabling optional features like website and project modules
class TeamFormUseCase {
  final TeamFormRepo teamFormRepo;
  final moduleRepo = ModuleRepository();

  TeamFormUseCase(this.teamFormRepo);

  /// Loads detailed information of a team by [id].
  Future<List<Map<String, dynamic>>> loadTeamData(int id) {
    return teamFormRepo.loadTeamData(id);
  }

  /// Loads available users for assigning as team members.
  Future<List<Map<String, dynamic>>> loadMembers() {
    return teamFormRepo.loadMembers();
  }

  /// Loads available partners/customers for team configuration.
  Future<List<Map<String, dynamic>>> loadPartners() {
    return teamFormRepo.loadPartners();
  }

  /// Loads available websites linked to the system.
  Future<List<Map<String, dynamic>>> loadWebsite() {
    return teamFormRepo.loadWebsite();
  }

  /// Loads available resource calendars filtered by [companyId].
  Future<List<Map<String, dynamic>>> loadResourceCalendar(int? companyId) {
    return teamFormRepo.loadResourceCalendar(companyId);
  }

  /// Loads available helpdesk stages.
  Future<List<Map<String, dynamic>>> loadStages() {
    return teamFormRepo.loadStages();
  }

  /// Loads available projects for team integration.
  Future<List<Map<String, dynamic>>> loadProjects() {
    return teamFormRepo.loadProjects();
  }

  /// Loads available alias domains for email routing.
  Future<List<Map<String, dynamic>>> loadAliasDomain() {
    return teamFormRepo.loadAliasDomain();
  }

  /// Loads the email templates usable for the auto-close reminder (Odoo 20).
  Future<List<Map<String, dynamic>>> loadReminderTemplates() {
    return teamFormRepo.loadReminderTemplates();
  }

  /// Loads what Odoo fills in for a new team (auto-close period and reminder).
  Future<Map<String, dynamic>> loadTeamDefaults() {
    return teamFormRepo.loadTeamDefaults();
  }

  /// The team options among [optionFields] that saving would install an app for.
  Future<List<String>> optionsNeedingInstall(List<String> optionFields) {
    return teamFormRepo.optionsNeedingInstall(optionFields);
  }

  /// Whether the server is installing, upgrading or removing apps right now.
  Future<bool> isServerBusyInstalling() {
    return teamFormRepo.isServerBusyInstalling();
  }

  /// The ids of the teams called [name], archived ones included.
  Future<List<int>> teamIdsNamed(String name) {
    return teamFormRepo.teamIdsNamed(name);
  }

  /// Whether the server already holds everything in [data] for team [id].
  Future<bool> holdsSave(int id, Map<String, dynamic> data) {
    return teamFormRepo.holdsSave(id, data);
  }

  /// Checks whether a module identified by [moduleName] is installed.
  ///
  /// Returns `true` if installed, otherwise `false`.
  Future<bool> installCheck(String moduleName) async {
    return await moduleRepo.isModuleInstalled(moduleName);
  }

  /// Enables website-related modules for a team by [id].
  Future<void> loadWebsiteModules(int id) {
    return teamFormRepo.loadWebsiteModules(id);
  }

  /// Enables project-related modules for a team by [id].
  Future<void> loadProjectModules(int id) {
    return teamFormRepo.loadProjectModules(id);
  }

  /// Creates a new team with the provided [data].
  Future<void> createTeam(Map<String, dynamic> data) async {
    await teamFormRepo.createTeam(data);
  }

  /// Updates an existing team identified by [id] using [data]. [installs]: the
  /// save is meant to install apps, so it is sent even if nothing differs.
  Future<void> updateTeam(
    int id,
    Map<String, dynamic> data, {
    bool installs = false,
  }) async {
    await teamFormRepo.updateTeam(id, data, installs: installs);
  }
}
