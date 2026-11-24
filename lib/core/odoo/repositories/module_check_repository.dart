import '../datasources/module_check_remote_datasource.dart';

/// Repository layer for module-related operations in the Odoo backend.
///
/// This repository abstracts the data source and provides a clean interface
/// for checking whether specific Odoo modules are installed.
///
/// It follows the Clean Architecture pattern by sitting between the Domain layer
/// (UseCases) and the Data layer (Remote DataSource).
class ModuleRepository {
  final ModuleCheckRemoteDataSource remote = ModuleCheckRemoteDataSourceImpl();

  Future<bool> isModuleInstalled(String moduleName) {
    return remote.moduleCheck(moduleName);
  }
}
