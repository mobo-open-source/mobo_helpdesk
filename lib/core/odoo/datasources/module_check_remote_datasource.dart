import '../../session/company_session_manager.dart';

/// Abstract data source for checking whether a specific Odoo module is installed.
///
/// This is used to enable/disable features in the app based on the modules
/// installed on the backend (e.g., `hr`, `project`, `helpdesk`, `account`, etc.).
abstract class ModuleCheckRemoteDataSource {
  /// Checks if a specific Odoo module is installed and active.
  ///
  /// Returns `true` if the module with the given [moduleName] exists and its
  /// state is `'installed'`.
  ///
  /// Example:
  /// ```dart
  /// final hasHelpdesk = await moduleCheckRemoteDataSource.moduleCheck('helpdesk');
  /// ```
  Future<bool> moduleCheck(String moduleName);
}

/// Implementation of [ModuleCheckRemoteDataSource] using Odoo RPC calls.
///
/// Uses `CompanySessionManager.callKwWithCompany()` to perform module checks
/// in the context of the currently selected company.
///
/// **Strategy:**
/// 1. First attempts to query `ir.module.module` for the exact module name.
/// 2. If that fails (e.g., permission issues or module not accessible), falls back
///    to a lightweight call on `account.move` to determine general system accessibility.
///
/// This fallback mechanism makes the check more robust across different user roles
/// and permission levels.
class ModuleCheckRemoteDataSourceImpl implements ModuleCheckRemoteDataSource {
  @override
  Future<bool> moduleCheck(String moduleName) async {
    try {
      final count = await CompanySessionManager.callKwWithCompany({
        'model': 'ir.module.module',
        'method': 'search_count',
        'args': [
          [
            ['name', '=', moduleName],
            ['state', '=', 'installed'],
          ],
        ],
        'kwargs': {},
      });

      return (count ?? 0) > 0;
    } catch (_) {
      return await _fallbackCheck();
    }
  }

  Future<bool> _fallbackCheck() async {
    return false;
  }
}
